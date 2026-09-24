// PHASE 9: 확정된 코스를 2문장으로 "설명"만 하는 Edge Function.
// AI는 장소를 검색/추천하지 않는다. 앱이 보낸 confirmed_places 밖의 사실은 쓰지 않는다.
//
// 배포:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy generate-plan-explanation
import Anthropic from "npm:@anthropic-ai/sdk";
import { corsHeaders, json } from "../_shared/cors.ts";

const MODEL = "claude-opus-5";

// 명세 3.4 system_prompt
const SYSTEM_PROMPT =
  "너는 현명하고 감각적인 데이트/나들이 코스 가이드다. 전달받은 [CONFIRMED_PLACES]와 [CONSTRAINTS] 정보만을 바탕으로 " +
  "코스의 매력 포인트를 2문장으로 설명하라. 데이터에 없는 장소나 없는 사실을 절대로 지어내지 마라(Zero-Hallucination). " +
  "영업시간, 메뉴, 가격 등 입력에 없는 정보는 언급하지 말고, 장소 이름은 입력 그대로 쓴다. " +
  "친근한 해요체로, 설명 문장만 출력한다.";

interface ConfirmedPlace {
  sequence: number;
  name: string;
  category: string;
  duration: string;
  cost: number;
}

interface ExplanationRequest {
  constraints: { companion: string; total_budget: number; area: string; mood?: string };
  confirmed_places: ConfirmedPlace[];
}

function validate(body: unknown): ExplanationRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  const places = b.confirmed_places;
  const constraints = b.constraints;
  if (!Array.isArray(places) || places.length === 0 || places.length > 6) return null;
  if (typeof constraints !== "object" || constraints === null) return null;
  for (const p of places) {
    if (typeof p?.name !== "string" || typeof p?.category !== "string") return null;
  }
  return body as ExplanationRequest;
}

/** 모델이 입력에 없는 장소명을 만들어냈는지 가볍게 검사 (따옴표로 감싼 고유명사 기준) */
function mentionsOnlyConfirmed(text: string, places: ConfirmedPlace[]): boolean {
  const quoted = [...text.matchAll(/[『「"']([^』」"']{2,30})[』」"']/g)].map((m) => m[1]);
  return quoted.every((q) => places.some((p) => p.name.includes(q) || q.includes(p.name)));
}

const client = new Anthropic(); // ANTHROPIC_API_KEY 환경변수 사용

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  let payload: ExplanationRequest | null;
  try {
    payload = validate(await req.json());
  } catch {
    payload = null;
  }
  if (!payload) return json({ error: "invalid payload" }, 400);

  const userInput = JSON.stringify(
    { CONSTRAINTS: payload.constraints, CONFIRMED_PLACES: payload.confirmed_places },
    null,
    2,
  );

  try {
    const response = await client.beta.messages.create({
      model: MODEL,
      max_tokens: 2000,
      betas: ["server-side-fallback-2026-07-01"],
      // 정책상 거절 시 서버가 적절한 모델로 자동 재시도
      // deno-lint-ignore no-explicit-any
      ...({ fallbacks: "default" } as any),
      output_config: { effort: "low" },
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userInput }],
    });

    if (response.stop_reason === "refusal") {
      return json({ summary: null, reason: "refusal" }, 200);
    }
    const summary = response.content
      .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text")
      .map((b) => b.text)
      .join("")
      .trim();

    if (!summary || !mentionsOnlyConfirmed(summary, payload.confirmed_places)) {
      return json({ summary: null, reason: "rejected" }, 200);
    }
    return json({ summary, model: response.model });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
    if (error instanceof Anthropic.AuthenticationError) return json({ error: "server_misconfigured" }, 500);
    if (error instanceof Anthropic.APIError) return json({ error: `upstream_${error.status}` }, 502);
    return json({ error: "unexpected" }, 500);
  }
});
