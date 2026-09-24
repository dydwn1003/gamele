// 네이버 지역검색 '리뷰 많은 순'(sort=comment)으로 동네별 인기 가게를 찾아,
// 우리 DB에 이미 있는 공공데이터 장소 중 일치하는 곳에 'POPULAR' 태그만 붙인다.
// 네이버 검색 결과(상호·주소·링크 등) 자체는 저장하지 않는다.
//
// 키 (둘 중 하나):
//   기존 개발자센터 키  NAVER_CLIENT_ID / NAVER_CLIENT_SECRET  (2027-06-30까지)
//   NAVER API HUB 키   NCP_APIGW_API_KEY_ID / NCP_APIGW_API_KEY
//
// 배포:  supabase functions deploy ingest-naver-popular --no-verify-jwt --use-api
// 실행:  curl -X POST "$SUPABASE_URL/functions/v1/ingest-naver-popular" \
//          -H "x-ingest-secret: $INGEST_SECRET" -H "Content-Type: application/json" -d '{"areas":["성수","연남"]}'
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

/** 동네 중심 좌표와 검색에 쓸 지명(별칭) */
const AREAS: Record<string, { center: [number, number]; aliases: string[] }> = {
  성수: { center: [37.5446, 127.0557], aliases: ["성수", "성수동", "서울숲"] },
  연남: { center: [37.5621, 126.9235], aliases: ["연남동", "연트럴파크"] },
  망원: { center: [37.5560, 126.9040], aliases: ["망원동", "망리단길"] },
  을지로: { center: [37.5662, 126.9910], aliases: ["을지로", "힙지로"] },
  익선동: { center: [37.5742, 126.9899], aliases: ["익선동", "종로3가"] },
  삼청: { center: [37.5810, 126.9815], aliases: ["삼청동", "북촌"] },
  서촌: { center: [37.5800, 126.9700], aliases: ["서촌", "경복궁역"] },
  한남: { center: [37.5370, 126.9990], aliases: ["한남동", "한강진"] },
  용산: { center: [37.5260, 126.9780], aliases: ["용리단길", "신용산"] },
  신사: { center: [37.5220, 127.0270], aliases: ["가로수길", "신사동"] },
  삼성: { center: [37.5115, 127.0590], aliases: ["삼성동", "코엑스"] },
  잠실: { center: [37.5105, 127.1030], aliases: ["송리단길", "석촌호수"] },
  여의도: { center: [37.5265, 126.9300], aliases: ["여의도"] },
  문래: { center: [37.5155, 126.8950], aliases: ["문래동", "문래창작촌"] },
  대학로: { center: [37.5815, 127.0030], aliases: ["대학로", "혜화"] },
  건대: { center: [37.5410, 127.0690], aliases: ["건대", "건대입구"] },
  반포: { center: [37.5080, 126.9970], aliases: ["반포", "서래마을"] },
  홍대: { center: [37.5563, 126.9236], aliases: ["홍대", "합정"] },
  이태원: { center: [37.5345, 126.9940], aliases: ["이태원", "해방촌"] },
  강남: { center: [37.4979, 127.0276], aliases: ["강남역", "신논현"] },
};

/** 카테고리별 검색어 (지명 뒤에 붙인다) */
const KEYWORDS = [
  "맛집", "파스타", "한식", "일식", "고깃집", "브런치", "중식", "분위기 좋은 식당",
  "카페", "디저트 카페", "베이커리", "대형카페",
  "와인바", "칵테일바", "이자카야", "술집",
  "방탈출", "보드게임카페", "공방", "셀프사진관", "볼링장",
  "갤러리", "전시",
];

interface NaverItem { title: string; category: string; mapx: string; mapy: string }

function naverHeaders(): { url: string; headers: Record<string, string> } | null {
  const id = Deno.env.get("NAVER_CLIENT_ID"), secret = Deno.env.get("NAVER_CLIENT_SECRET");
  if (id && secret) {
    return { url: "https://openapi.naver.com/v1/search/local.json", headers: { "X-Naver-Client-Id": id, "X-Naver-Client-Secret": secret } };
  }
  const hubId = Deno.env.get("NCP_APIGW_API_KEY_ID"), hubKey = Deno.env.get("NCP_APIGW_API_KEY");
  if (hubId && hubKey) {
    return { url: "https://naverapihub.apigw.ntruss.com/search/v1/local", headers: { "X-NCP-APIGW-API-KEY-ID": hubId, "X-NCP-APIGW-API-KEY": hubKey } };
  }
  return null;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** 네이버 검색 API는 초당 호출 수 제한이 있어 호출 사이에 간격을 둔다 */
const MIN_INTERVAL_MS = 150;
let lastCall = 0;

async function searchPopular(api: { url: string; headers: Record<string, string> }, query: string): Promise<NaverItem[]> {
  const url = new URL(api.url);
  url.search = new URLSearchParams({ query, display: "5", start: "1", sort: "comment" }).toString();
  for (let attempt = 0; attempt < 4; attempt++) {
    const wait = lastCall + MIN_INTERVAL_MS - Date.now();
    if (wait > 0) await sleep(wait);
    lastCall = Date.now();
    const res = await fetch(url, { headers: api.headers });
    if (res.ok) {
      const body = await res.json().catch(() => null);
      return Array.isArray(body?.items) ? body.items : [];
    }
    const err = await res.json().catch(() => ({}));
    if (res.status === 401 || res.status === 403) {
      throw new Error(`네이버 API 인증 실패(${res.status} ${err.errorCode ?? ""}) — 키와 '검색' API 사용 설정을 확인하세요`);
    }
    if (res.status === 429) {
      // 012 = 하루 호출 한도 소진 → 더 시도해도 소용없음
      if (err.errorCode === "012") throw new Error("네이버 API 하루 호출 한도를 모두 썼습니다(012). 내일 다시 실행하세요");
      await sleep(1000 * (attempt + 1)); // 초당 제한 → 잠시 쉬고 재시도
      continue;
    }
    return [];
  }
  throw new Error("네이버 API 호출 한도 초과(429)가 계속됩니다. 잠시 후 다시 실행하세요");
}

/** 네이버 좌표: 현재는 WGS84 × 1e7 정수 문자열 */
function toDeg(v: string): number {
  const n = Number(v);
  return Math.abs(n) > 1000 ? n / 1e7 : n;
}

const stripTags = (s: string) => s.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").trim();
const norm = (s: string) => s.replace(/[\s·()\-_.,&'"]/g, "").toLowerCase();

function metersBetween(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

function levenshtein(a: string, b: string): number {
  const dp = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    let prev = dp[0];
    dp[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const tmp = dp[j];
      dp[j] = Math.min(dp[j] + 1, dp[j - 1] + 1, prev + (a[i - 1] === b[j - 1] ? 0 : 1));
      prev = tmp;
    }
  }
  return dp[b.length];
}

/** 이름이 같은 가게인지: 포함 관계이거나 유사도 0.7 이상 */
export function sameName(a: string, b: string): boolean {
  const x = norm(a), y = norm(b);
  if (x.length < 2 || y.length < 2) return false;
  if (x === y) return true;
  // '김밥' ⊂ '김밥천국' 같은 짧은 일반명사 오탐을 막기 위해 포함 관계는 3글자 이상일 때만
  if (Math.min(x.length, y.length) >= 3 && (x.includes(y) || y.includes(x))) return true;
  return 1 - levenshtein(x, y) / Math.max(x.length, y.length) >= 0.7;
}

interface KnownPlace { id: string; name: string; latitude: number; longitude: number; tags: string[] | null }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const secret = Deno.env.get("INGEST_SECRET");
  if (!secret || req.headers.get("x-ingest-secret") !== secret) return json({ error: "unauthorized" }, 401);

  const api = naverHeaders();
  if (!api) return json({ error: "NAVER_CLIENT_ID/NAVER_CLIENT_SECRET 또는 NCP_APIGW_API_KEY_ID/NCP_APIGW_API_KEY가 없습니다" }, 500);

  const body = await req.json().catch(() => ({}));
  const requested: string[] = Array.isArray(body.areas) && body.areas.length ? body.areas : Object.keys(AREAS);
  const perCall = Math.min(Math.max(Number(body.perCall) || 2, 1), 4);
  const names = requested.slice(0, perCall);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const done: Record<string, unknown> = {};

  for (const name of names) {
    const area = AREAS[name.replace("서울 ", "")];
    if (!area) { done[name] = "unknown area"; continue; }
    const [lat, lng] = area.center;

    // 매칭 대상: 동네 주변(약 ±2.7km)의 활성 장소 전체. API가 한 번에 1000행까지만 주므로 나눠 받는다.
    const known: KnownPlace[] = [];
    for (let from = 0; from < 50000; from += 1000) {
      const { data, error } = await supabase
        .from("places")
        .select("id,name,latitude,longitude,tags")
        .eq("is_active", true)
        .gte("latitude", lat - 0.025).lte("latitude", lat + 0.025)
        .gte("longitude", lng - 0.03).lte("longitude", lng + 0.03)
        .order("id")
        .range(from, from + 999);
      if (error || !data?.length) break;
      known.push(...(data as KnownPlace[]));
      if (data.length < 1000) break;
    }

    const hits = new Map<string, KnownPlace>();
    let queries = 0, results = 0, unmatched = 0;
    let stopError: string | null = null;
    try {
      for (const alias of area.aliases) {
        for (const kw of KEYWORDS) {
          queries++;
          for (const item of await searchPopular(api, `${alias} ${kw}`)) {
            results++;
            const title = stripTags(item.title);
            const iLat = toDeg(item.mapy), iLng = toDeg(item.mapx);
            if (!iLat || !iLng) { unmatched++; continue; }
            const match = known.find((k) =>
              Math.abs(k.latitude - iLat) < 0.0012 && Math.abs(k.longitude - iLng) < 0.0015 &&
              metersBetween(k.latitude, k.longitude, iLat, iLng) < 120 && sameName(k.name, title));
            if (match) hits.set(match.id, match); else unmatched++;
          }
        }
      }
    } catch (e) {
      // 그때까지 찾은 인기 가게는 저장하고 멈춘다
      stopError = String(e instanceof Error ? e.message : e);
    }

    let tagged = 0, errors = 0;
    for (const p of hits.values()) {
      const tags = Array.from(new Set([...(p.tags ?? []), "POPULAR"]));
      if (tags.length === (p.tags ?? []).length) continue; // 이미 표시됨
      const { error } = await supabase.from("places").update({ tags }).eq("id", p.id);
      if (error) errors++; else tagged++;
    }
    done[name] = { queries, results, matched: hits.size, newlyTagged: tagged, unmatched, errors };
    if (stopError) {
      return json({ ok: false, error: stopError, done, remaining: requested.slice(requested.indexOf(name)) }, 502);
    }
  }

  return json({ ok: true, done, remaining: requested.slice(perCall) });
});
