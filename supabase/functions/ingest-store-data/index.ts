// 소상공인시장진흥공단 상가(상권)정보 → 동네별 카페·맛집·술집·놀거리 수집
//
// 공공데이터포털에서 "소상공인시장진흥공단_상가(상권)정보" 활용신청 후 같은 인증키(TOUR_API_KEY)를 쓴다.
// 다른 키를 쓰려면 SEMAS_API_KEY 를 등록한다.
//
// 배포:  supabase functions deploy ingest-store-data --no-verify-jwt --use-api
// 실행:  curl -X POST "$SUPABASE_URL/functions/v1/ingest-store-data" \
//          -H "x-ingest-secret: $INGEST_SECRET" -H "Content-Type: application/json" \
//          -d '{"areas":["성수","연남"]}'        # 생략하면 전체 동네
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";
import { type Category, CHAINS, type Classified, classify, fetchStores, metersBetween, norm, type Store } from "../_shared/semas.ts";

const AREAS: Record<string, [number, number]> = {
  성수: [37.5446, 127.0557], 연남: [37.5621, 126.9235], 망원: [37.5560, 126.9040], 을지로: [37.5662, 126.9910],
  익선동: [37.5742, 126.9899], 삼청: [37.5810, 126.9815], 서촌: [37.5800, 126.9700], 한남: [37.5370, 126.9990],
  용산: [37.5260, 126.9780], 신사: [37.5220, 127.0270], 삼성: [37.5115, 127.0590], 잠실: [37.5105, 127.1030],
  여의도: [37.5265, 126.9300], 문래: [37.5155, 126.8950], 대학로: [37.5815, 127.0030], 건대: [37.5410, 127.0690],
  반포: [37.5080, 126.9970], 홍대: [37.5563, 126.9236], 이태원: [37.5345, 126.9940], 강남: [37.4979, 127.0276],
};
/** 동네 하나당 카테고리별 최대 저장 수 */
const CAP: Record<Category, number> = { FOOD: 180, CAFE: 140, BAR: 70, ACTIVITY: 70, EXHIBITION: 30 };

/** 같은 업종 안에서 순서를 고르게 섞어 특정 세부업종만 몰리지 않게 한다 */
function spread<T extends { sub: string; id: string }>(items: T[], cap: number): T[] {
  const bySub = new Map<string, T[]>();
  for (const it of [...items].sort((a, b) => a.id.localeCompare(b.id))) {
    if (!bySub.has(it.sub)) bySub.set(it.sub, []);
    bySub.get(it.sub)!.push(it);
  }
  const queues = [...bySub.values()];
  const out: T[] = [];
  while (out.length < cap && queues.some((q) => q.length)) {
    for (const q of queues) if (q.length && out.length < cap) out.push(q.shift()!);
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const secret = Deno.env.get("INGEST_SECRET");
  if (!secret || req.headers.get("x-ingest-secret") !== secret) return json({ error: "unauthorized" }, 401);

  const key = Deno.env.get("SEMAS_API_KEY") ?? Deno.env.get("TOUR_API_KEY");
  if (!key) return json({ error: "SEMAS_API_KEY 또는 TOUR_API_KEY가 없습니다" }, 500);

  const body = await req.json().catch(() => ({}));
  // 무료 플랜의 계산 한도(WORKER_RESOURCE_LIMIT)를 넘지 않도록 한 번에 최대 2개 동네만 처리한다
  const requested: string[] = Array.isArray(body.areas) && body.areas.length ? body.areas : Object.keys(AREAS);
  const perCall = Math.min(Math.max(Number(body.perCall) || 2, 1), 4);
  const names = requested.slice(0, perCall);
  const radius = Math.min(Number(body.radius) || 1000, 2000);
  const maxPages = Math.min(Number(body.maxPages) || 8, 20);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const started = Date.now();
  const done: Record<string, unknown> = {};
  const remaining: string[] = requested.slice(perCall);

  for (const name of names) {
    const center = AREAS[name.replace("서울 ", "")];
    if (!center) { done[name] = "unknown area"; continue; }
    // Edge Function 실행 시간 제한(약 150초) 전에 멈추고 남은 동네를 알려준다
    if (Date.now() - started > 100_000) { remaining.push(name); continue; }

    const [lat, lng] = center;
    let stores: Store[];
    try {
      stores = await fetchStores(key, lat, lng, radius, maxPages);
    } catch (e) {
      return json({ ok: false, error: String(e instanceof Error ? e.message : e), done }, 502);
    }

    // 이미 있는 장소(관광공사·샘플)와 겹치는 가게는 건너뛴다
    const { data: existing } = await supabase.rpc("get_places_near_location", {
      lat, lng, radius_meters: radius + 200, category_filter: null,
    });
    // 이전 실행에서 넣은 상가정보(SEMAS)는 upsert로 갱신되므로 비교 대상에서 뺀다
    const known = ((existing ?? []) as { name: string; latitude: number; longitude: number; source: string }[])
      .filter((k) => k.source !== "SEMAS")
      .map((k) => ({ ...k, key: norm(k.name) }));

    // 같은 상호가 반경 안에 2곳 이상이면 체인점으로 간주
    const nameCount = new Map<string, number>();
    for (const s of stores) {
      const n = norm(s.bizesNm ?? "");
      nameCount.set(n, (nameCount.get(n) ?? 0) + 1);
    }

    const candidates: (Classified & { id: string; store: Store })[] = [];
    for (const s of stores) {
      const sLat = Number(s.lat), sLng = Number(s.lon);
      if (!s.bizesNm || !sLat || !sLng) continue;
      // 상호 미등록('업소명없음')·숫자뿐인 이름·한 글자 이름은 제외
      if (/없음|미상/.test(s.bizesNm) || /^[\d\s\-]+$/.test(s.bizesNm) || s.bizesNm.trim().length < 2) continue;
      const key = norm(s.bizesNm);
      if (CHAINS.test(s.bizesNm) || (nameCount.get(key) ?? 0) > 1) continue;
      const c = classify(s);
      if (!c) continue;
      // 좌표 차이로 먼저 거른 뒤(저렴) 거리·이름을 비교한다
      const dup = known.some((k) =>
        Math.abs(k.latitude - sLat) < 0.001 && Math.abs(k.longitude - sLng) < 0.0012 &&
        metersBetween(k.latitude, k.longitude, sLat, sLng) < 80 &&
        (k.key.includes(key) || key.includes(k.key)));
      if (dup) continue;
      candidates.push({ ...c, id: s.bizesId, store: s });
    }

    const counts: Record<string, number> = {};
    const rows = [];
    for (const cat of Object.keys(CAP) as Category[]) {
      const picked = spread(candidates.filter((c) => c.category === cat), CAP[cat]);
      counts[cat] = picked.length;
      for (const c of picked) {
        const sLat = Number(c.store.lat), sLng = Number(c.store.lon);
        rows.push({
          name: c.store.bizesNm.trim(),
          category: c.category,
          subcategory: c.sub,
          description: [c.store.indsSclsNm, c.store.indsMclsNm].filter(Boolean)[0] ?? null,
          address: c.store.rdnmAdr || c.store.lnoAdr || "",
          location: `SRID=4326;POINT(${sLng} ${sLat})`,
          latitude: sLat,
          longitude: sLng,
          price_min: c.price[0],
          price_max: c.price[1],
          duration_minutes: c.duration,
          indoor_outdoor: "INDOOR",
          tags: c.tags,
          opening_hours: c.hours,
          source: "SEMAS",
          source_id: c.id,
          is_active: true,
          last_verified_at: new Date().toISOString(),
        });
      }
    }

    let errors = 0;
    for (let i = 0; i < rows.length; i += 200) {
      const { error } = await supabase.from("places").upsert(rows.slice(i, i + 200), { onConflict: "source,source_id" });
      if (error) errors++;
    }
    done[name] = { fetched: stores.length, saved: rows.length, byCategory: counts, errors };
  }

  return json({ ok: true, done, remaining });
});
