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

type Category = "FOOD" | "CAFE" | "BAR" | "ACTIVITY" | "EXHIBITION";

const AREAS: Record<string, [number, number]> = {
  성수: [37.5446, 127.0557], 연남: [37.5621, 126.9235], 망원: [37.5560, 126.9040], 을지로: [37.5662, 126.9910],
  익선동: [37.5742, 126.9899], 삼청: [37.5810, 126.9815], 서촌: [37.5800, 126.9700], 한남: [37.5370, 126.9990],
  용산: [37.5260, 126.9780], 신사: [37.5220, 127.0270], 삼성: [37.5115, 127.0590], 잠실: [37.5105, 127.1030],
  여의도: [37.5265, 126.9300], 문래: [37.5155, 126.8950], 대학로: [37.5815, 127.0030], 건대: [37.5410, 127.0690],
  반포: [37.5080, 126.9970], 홍대: [37.5563, 126.9236], 이태원: [37.5345, 126.9940], 강남: [37.4979, 127.0276],
};

/** 동네 하나당 카테고리별 최대 저장 수 */
const CAP: Record<Category, number> = { FOOD: 180, CAFE: 140, BAR: 70, ACTIVITY: 70, EXHIBITION: 30 };

/** 알려진 체인점 이름. 그 밖에 같은 반경 안에 같은 상호가 여러 개면 체인으로 본다 */
const CHAINS = /스타벅스|이디야|투썸|메가(엠지씨|MGC)?커피|빽다방|컴포즈|할리스|파스쿠찌|커피빈|엔제리너스|탐앤탐스|폴바셋|배스킨|던킨|파리바게|뚜레쥬르|맥도날드|버거킹|롯데리아|KFC|맘스터치|서브웨이|써브웨이|도미노|피자헛|파파존스|BBQ|비비큐|BHC|교촌|굽네|네네|처갓집|김밥천국|본죽|이삭토스트|홍콩반점|새마을식당|역전할머니|한신포차|코인노래|GS25|CU|세븐일레븐|이마트|노브랜드|다이소|올리브영/i;

interface Store {
  bizesId: string; bizesNm: string; brchNm?: string;
  indsLclsNm?: string; indsMclsNm?: string; indsSclsNm?: string;
  rdnmAdr?: string; lnoAdr?: string; lon: string | number; lat: string | number;
}

interface Classified { category: Category; sub: string; tags: string[]; price: [number, number]; duration: number; hours: Record<string, unknown> }

const daily = (open: string, close: string) => ({ daily: { open, close } });

function classify(s: Store): Classified | null {
  const l = s.indsLclsNm ?? "", m = s.indsMclsNm ?? "", sc = s.indsSclsNm ?? "", name = s.bizesNm ?? "";
  const text = `${m} ${sc} ${name}`;
  const act = (sub: string, tags: string[], price: [number, number], duration: number): Classified =>
    ({ category: "ACTIVITY", sub, tags: ["FUN", ...tags], price, duration, hours: daily("11:00", "23:00") });

  // 놀거리 (업종 대분류와 무관하게 이름/업종으로 판단)
  if (/방탈출/.test(text)) return act("방탈출", ["GROUP", "DATE"], [20000, 26000], 80);
  if (/보드\s?게임/.test(text)) return act("보드게임", ["GROUP", "KIDS", "CHEAP"], [8000, 12000], 90);
  if (/만화\s?카페|만화방/.test(text)) return act("만화카페", ["SOLO_FRIENDLY", "QUIET", "DATE"], [8000, 12000], 90);
  if (/볼링/.test(text)) return act("볼링", ["GROUP", "ACTIVE"], [8000, 12000], 90);
  if (/노래(방|연습장)/.test(text)) return act("노래방", ["GROUP", "CHEAP", "NIGHT"], [3000, 10000], 60);
  if (/클라이밍|암장|볼더링/.test(text)) return act("클라이밍", ["ACTIVE", "GROUP", "TRENDY"], [20000, 28000], 120);
  if (/스크린\s?(야구|골프)|야구연습|사격|양궁|VR|오락실|게임센터/.test(text)) return act("체험 오락", ["GROUP", "ACTIVE"], [10000, 20000], 60);
  if (/공방|원데이|도자기|향수|캔들/.test(text)) return act("공방 체험", ["DATE", "ART", "ROMANTIC"], [30000, 50000], 120);
  if (/셀프\s?사진|포토\s?부스|사진관|스튜디오/.test(text) && /사진|포토/.test(text)) return act("셀프사진", ["INSTAGRAM", "DATE"], [8000, 20000], 30);
  if (/갤러리|화랑|미술관/.test(text)) {
    return { category: "EXHIBITION", sub: "갤러리", tags: ["ART", "QUIET", "INSTAGRAM"], price: [0, 5000], duration: 40, hours: daily("11:00", "19:00") };
  }

  if (!/음식/.test(l)) return null;
  if (/구내식당|출장|케이터링|배달|도시락|급식/.test(text)) return null;

  // 카페·디저트
  if (/카페|커피|제과|베이커리|빵|디저트|아이스크림|빙수|찻집|전통차|차 전문|도넛|케이크/.test(text)) {
    const dessert = /제과|베이커리|빵|디저트|아이스크림|빙수|도넛|케이크/.test(text);
    return {
      category: "CAFE", sub: dessert ? "디저트" : "카페",
      tags: dessert ? ["INSTAGRAM", "TRENDY", "DATE"] : ["QUIET", "SOLO_FRIENDLY"],
      price: dessert ? [7000, 13000] : [5000, 9000], duration: 45, hours: daily("10:00", "22:00"),
    };
  }
  // 술집
  if (/주점|호프|맥주|와인|칵테일|이자카야|포차|바\b|펍|위스키/.test(text)) {
    const mood = /와인|칵테일|위스키|바\b/.test(text);
    return {
      category: "BAR", sub: mood ? "바" : "주점",
      tags: mood ? ["ROMANTIC", "DATE", "NIGHT", "QUIET"] : ["GROUP", "FUN", "NIGHT"],
      price: mood ? [20000, 35000] : [12000, 20000], duration: 70, hours: daily("17:00", "01:00"),
    };
  }
  // 식당
  const food = (sub: string, tags: string[], price: [number, number]): Classified =>
    ({ category: "FOOD", sub, tags: ["FOODIE", ...tags], price, duration: 60, hours: daily("11:00", "21:30") });
  if (/양식|파스타|이탈리|스테이크|피자|브런치|프렌치|레스토랑/.test(text)) return food("양식", ["DATE", "ROMANTIC", "INSTAGRAM"], [18000, 30000]);
  if (/일식|초밥|스시|라멘|돈까스|돈가스|우동|오마카세/.test(text)) return food("일식", ["DATE", "SOLO_FRIENDLY"], [13000, 25000]);
  if (/중식|중국|마라|딤섬/.test(text)) return food("중식", ["GROUP"], [10000, 18000]);
  if (/베트남|태국|동남아|인도|멕시|외국식/.test(text)) return food("세계음식", ["TRENDY", "DATE"], [12000, 20000]);
  if (/분식|김밥|떡볶이|토스트/.test(text)) return food("분식", ["CHEAP", "KIDS"], [5000, 9000]);
  if (/고기|구이|갈비|삼겹|곱창|닭갈비|족발|보쌈/.test(text)) return food("고기", ["GROUP", "LOCAL"], [15000, 25000]);
  if (/한식|국밥|찌개|냉면|국수|칼국수|한정식|백반/.test(text)) return food("한식", ["LOCAL", "KIDS"], [9000, 15000]);
  return food(sc || m || "맛집", ["LOCAL"], [10000, 18000]);
}

async function fetchStores(key: string, lat: number, lng: number, radius: number, maxPages: number): Promise<Store[]> {
  const out: Store[] = [];
  for (let page = 1; page <= maxPages; page++) {
    const url = new URL("https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius");
    url.search = new URLSearchParams({
      serviceKey: key, pageNo: String(page), numOfRows: "1000", radius: String(radius),
      cx: String(lng), cy: String(lat), type: "json",
    }).toString();
    const res = await fetch(url);
    const text = await res.text();
    let body: any;
    try {
      body = JSON.parse(text);
    } catch {
      throw new Error(`상가정보 API가 JSON이 아닌 응답을 보냈습니다 (활용신청/키 확인): ${text.slice(0, 200)}`);
    }
    const header = body?.header ?? body?.response?.header;
    if (header?.resultCode === "03") break; // 데이터 없음
    if (header?.resultCode && header.resultCode !== "00") throw new Error(`상가정보 API 오류: ${header.resultMsg}`);
    const items = body?.body?.items ?? body?.response?.body?.items;
    const list: Store[] = Array.isArray(items) ? items : Array.isArray(items?.item) ? items.item : items?.item ? [items.item] : [];
    out.push(...list);
    const total = Number(body?.body?.totalCount ?? body?.response?.body?.totalCount ?? 0);
    if (list.length < 1000 || out.length >= total) break;
  }
  return out;
}

const norm = (s: string) => s.replace(/[\s·()]/g, "").toLowerCase();

function metersBetween(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

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
