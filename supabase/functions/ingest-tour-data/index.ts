// PHASE 10: TourAPI(한국관광공사) + 서울시 문화행사 Open API 수집 → 정규화 → 중복 제거 → Upsert
//
// 배포:
//   supabase secrets set TOUR_API_KEY=... SEOUL_API_KEY=... INGEST_SECRET=...
//   supabase functions deploy ingest-tour-data --no-verify-jwt
// 실행:
//   curl -X POST "$SUPABASE_URL/functions/v1/ingest-tour-data" \
//     -H "x-ingest-secret: $INGEST_SECRET" -d '{"areaCode":1,"pages":2}'
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

type Category = "PARK" | "EXHIBITION" | "POPUP" | "ACTIVITY" | "FOOD" | "CAFE";
type Source = "TOUR_API" | "SEOUL_DATA";

interface NormalizedPlace {
  name: string;
  category: Category;
  subcategory: string;
  description: string | null;
  address: string;
  latitude: number;
  longitude: number;
  phone: string | null;
  website_url: string | null;
  image_urls: string[];
  price_min: number;
  price_max: number;
  duration_minutes: number;
  indoor_outdoor: "INDOOR" | "OUTDOOR" | "MIXED";
  tags: string[];
  source: Source;
  source_id: string;
}

// ── 명세 4.2 데이터 정규화 매핑 테이블 ────────────────────────────────
const CATEGORY_DEFAULTS: Record<Category, { sub: string; duration: number; cost: number }> = {
  PARK: { sub: "공원/자연", duration: 60, cost: 0 },
  EXHIBITION: { sub: "전시/관람", duration: 90, cost: 15000 },
  POPUP: { sub: "팝업/행사", duration: 60, cost: 10000 },
  ACTIVITY: { sub: "액티비티", duration: 120, cost: 25000 },
  FOOD: { sub: "맛집", duration: 60, cost: 18000 },
  CAFE: { sub: "카페", duration: 50, cost: 8000 },
};

/** TourAPI contentTypeId(+cat3) → 내부 카테고리 */
function mapTourCategory(contentTypeId: string, cat3: string): Category | null {
  if (cat3 === "A05020900") return "CAFE"; // 카페/전통찻집
  switch (contentTypeId) {
    case "12": return "PARK"; // 관광지
    case "14": return "EXHIBITION"; // 문화시설 (미술관/박물관)
    case "15": return "POPUP"; // 축제/공연/행사
    case "28": return "ACTIVITY"; // 레포츠
    case "39": return "FOOD"; // 음식점
    default: return null;
  }
}

function tagsFor(category: Category): string[] {
  switch (category) {
    case "PARK": return ["HEALING", "NATURE", "SPACIOUS", "KIDS"];
    case "EXHIBITION": return ["ART", "QUIET", "INSTAGRAM"];
    case "POPUP": return ["TRENDY", "FUN", "INSTAGRAM"];
    case "ACTIVITY": return ["ACTIVE", "FUN", "GROUP"];
    case "FOOD": return ["FOODIE"];
    case "CAFE": return ["QUIET", "INSTAGRAM"];
  }
}

function normalize(
  base: Omit<NormalizedPlace, "subcategory" | "price_min" | "price_max" | "duration_minutes" | "tags" | "indoor_outdoor">,
  overrides: Partial<NormalizedPlace> = {},
): NormalizedPlace {
  const d = CATEGORY_DEFAULTS[base.category];
  return {
    ...base,
    subcategory: d.sub,
    price_min: d.cost,
    price_max: d.cost,
    duration_minutes: d.duration,
    indoor_outdoor: base.category === "PARK" ? "OUTDOOR" : "INDOOR",
    tags: tagsFor(base.category),
    ...overrides,
  };
}

// ── 중복 제거: 50m 이내 & Levenshtein 유사도 ≥ 0.85 ─────────────────
function levenshtein(a: string, b: string): number {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: n + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i++) {
    let prev = dp[0];
    dp[0] = i;
    for (let j = 1; j <= n; j++) {
      const tmp = dp[j];
      dp[j] = Math.min(dp[j] + 1, dp[j - 1] + 1, prev + (a[i - 1] === b[j - 1] ? 0 : 1));
      prev = tmp;
    }
  }
  return dp[n];
}

export function similarity(a: string, b: string): number {
  const x = a.replace(/\s+/g, "").toLowerCase();
  const y = b.replace(/\s+/g, "").toLowerCase();
  if (!x.length && !y.length) return 1;
  return 1 - levenshtein(x, y) / Math.max(x.length, y.length);
}

// ── Fetchers ────────────────────────────────────────────────────────
async function fetchTourApi(key: string, areaCode: number, pages: number): Promise<NormalizedPlace[]> {
  const out: NormalizedPlace[] = [];
  for (const contentTypeId of ["12", "14", "15", "28", "39"]) {
    for (let page = 1; page <= pages; page++) {
      const url = new URL("https://apis.data.go.kr/B551011/KorService2/areaBasedList2");
      url.search = new URLSearchParams({
        serviceKey: key, MobileOS: "ETC", MobileApp: "mwohaji", _type: "json",
        areaCode: String(areaCode), contentTypeId, numOfRows: "100", pageNo: String(page), arrange: "Q",
      }).toString();
      const res = await fetch(url);
      if (!res.ok) break;
      const body = await res.json().catch(() => null);
      const items = body?.response?.body?.items?.item;
      if (!Array.isArray(items) || items.length === 0) break;
      for (const it of items) {
        const category = mapTourCategory(String(it.contenttypeid), String(it.cat3 ?? ""));
        const lat = Number(it.mapy), lng = Number(it.mapx);
        if (!category || !lat || !lng || !it.title) continue;
        out.push(normalize({
          name: String(it.title).trim(),
          category,
          description: null,
          address: [it.addr1, it.addr2].filter(Boolean).join(" "),
          latitude: lat,
          longitude: lng,
          phone: it.tel || null,
          website_url: null,
          image_urls: [it.firstimage, it.firstimage2].filter(Boolean),
          source: "TOUR_API",
          source_id: String(it.contentid),
        }));
      }
    }
  }
  return out;
}

interface SeoulEvent { place: NormalizedPlace; title: string; start: string; end: string; price: number; url: string | null; image: string | null; }

async function fetchSeoulEvents(key: string): Promise<SeoulEvent[]> {
  const res = await fetch(`http://openapi.seoul.go.kr:8088/${key}/json/culturalEventInfo/1/300/`);
  if (!res.ok) return [];
  const body = await res.json().catch(() => null);
  const rows = body?.culturalEventInfo?.row;
  if (!Array.isArray(rows)) return [];
  const out: SeoulEvent[] = [];
  for (const r of rows) {
    // 서울시 API는 LAT/LOT 표기가 뒤바뀐 경우가 있어 범위로 보정
    let lat = Number(r.LAT), lng = Number(r.LOT);
    if (lat > 90) [lat, lng] = [lng, lat];
    if (!lat || !lng || !r.PLACE) continue;
    const free = String(r.IS_FREE ?? "").includes("무료");
    const fee = free ? 0 : CATEGORY_DEFAULTS.POPUP.cost;
    out.push({
      place: normalize({
        name: String(r.PLACE).trim(),
        category: r.CODENAME?.includes("전시") ? "EXHIBITION" : "POPUP",
        description: r.CODENAME ?? null,
        address: `${r.GUNAME ?? ""} ${r.PLACE}`.trim(),
        latitude: lat,
        longitude: lng,
        phone: null,
        website_url: r.ORG_LINK || null,
        image_urls: r.MAIN_IMG ? [r.MAIN_IMG] : [],
        source: "SEOUL_DATA",
        source_id: `place:${r.PLACE}`,
      }, { price_min: fee, price_max: fee }),
      title: String(r.TITLE),
      start: String(r.STRTDATE ?? r.DATE?.split("~")[0]),
      end: String(r.END_DATE ?? r.DATE?.split("~")[1]),
      price: fee,
      url: r.ORG_LINK || r.HMPG_ADDR || null,
      image: r.MAIN_IMG || null,
    });
  }
  return out;
}

// ── Main ────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const secret = Deno.env.get("INGEST_SECRET");
  if (!secret || req.headers.get("x-ingest-secret") !== secret) return json({ error: "unauthorized" }, 401);

  const { areaCode = 1, pages = 1 } = await req.json().catch(() => ({}));
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const stats = { fetched: 0, inserted: 0, deduplicated: 0, events: 0, errors: 0 };

  const tourKey = Deno.env.get("TOUR_API_KEY");
  const seoulKey = Deno.env.get("SEOUL_API_KEY");
  const places = tourKey ? await fetchTourApi(tourKey, areaCode, pages) : [];
  const events = seoulKey ? await fetchSeoulEvents(seoulKey) : [];
  stats.fetched = places.length + events.length;

  /** 중복이면 기존 id 반환(last_verified_at 갱신), 아니면 upsert 후 id 반환 */
  async function upsertPlace(p: NormalizedPlace): Promise<string | null> {
    const { data: nearby } = await supabase.rpc("get_places_near_location", {
      lat: p.latitude, lng: p.longitude, radius_meters: 50, category_filter: [p.category],
    });
    const dup = (nearby ?? []).find((n: { name: string }) => similarity(n.name, p.name) >= 0.85);
    if (dup) {
      await supabase.from("places").update({ last_verified_at: new Date().toISOString(), is_active: true }).eq("id", dup.id);
      stats.deduplicated++;
      return dup.id;
    }
    const { data, error } = await supabase
      .from("places")
      .upsert(
        { ...p, location: `SRID=4326;POINT(${p.longitude} ${p.latitude})`, last_verified_at: new Date().toISOString(), is_active: true },
        { onConflict: "source,source_id" },
      )
      .select("id")
      .single();
    if (error) { stats.errors++; return null; }
    stats.inserted++;
    return data.id;
  }

  for (const p of places) await upsertPlace(p);

  for (const e of events) {
    const placeId = await upsertPlace(e.place);
    if (!placeId) continue;
    const { error } = await supabase.from("events").upsert({
      place_id: placeId,
      title: e.title,
      start_at: new Date(e.start).toISOString(),
      end_at: new Date(e.end).toISOString(),
      price: e.price,
      reservation_url: e.url,
      image_url: e.image,
      source: "SEOUL_DATA",
      source_id: `${e.title}|${e.start}`.slice(0, 250),
    }, { onConflict: "source,source_id" });
    if (error) stats.errors++; else stats.events++;
  }

  // 신선도 정책 (명세 4.3)
  await supabase.rpc("cleanup_stale_data");

  return json({ ok: true, stats });
});
