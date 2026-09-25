// 네이버 지역검색(리뷰 많은 순)으로 동네별 맛집·카페·술집·놀거리·전시·공원을 수집해 places에 저장한다.
//
// 키 (둘 중 하나):
//   기존 개발자센터 키  NAVER_CLIENT_ID / NAVER_CLIENT_SECRET  (2027-06-30까지)
//   NAVER API HUB 키   NCP_APIGW_API_KEY_ID / NCP_APIGW_API_KEY
//
// 배포:  supabase functions deploy ingest-naver-places --no-verify-jwt --use-api
// 실행:  curl -X POST "$SUPABASE_URL/functions/v1/ingest-naver-places" \
//          -H "x-ingest-secret: $INGEST_SECRET" -H "Content-Type: application/json" -d '{"areas":["성수","연남"]}'
//
// ⚠️ 네이버 검색 결과를 저장하는 것이 이용약관상 허용되는 범위인지 출시 전에 확인할 것.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

type Category = "FOOD" | "CAFE" | "BAR" | "ACTIVITY" | "EXHIBITION" | "PARK" | "POPUP";

export const AREAS: Record<string, { center: [number, number]; aliases: string[] }> = {
  성수: { center: [37.5446, 127.0557], aliases: ["성수", "서울숲"] },
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
  잠실: { center: [37.5105, 127.1030], aliases: ["송리단길", "잠실"] },
  여의도: { center: [37.5265, 126.9300], aliases: ["여의도", "여의나루"] },
  문래: { center: [37.5155, 126.8950], aliases: ["문래동", "영등포"] },
  대학로: { center: [37.5815, 127.0030], aliases: ["대학로", "혜화"] },
  건대: { center: [37.5410, 127.0690], aliases: ["건대", "건대입구"] },
  반포: { center: [37.5080, 126.9970], aliases: ["반포", "서래마을"] },
  홍대: { center: [37.5563, 126.9236], aliases: ["홍대", "합정"] },
  이태원: { center: [37.5345, 126.9940], aliases: ["이태원", "해방촌"] },
  강남: { center: [37.4979, 127.0276], aliases: ["강남역", "신논현"] },
};

/** 검색어와, 네이버 분류로 판단이 안 될 때 쓸 기본 카테고리 */
const KEYWORDS: [string, Category][] = [
  ["맛집", "FOOD"], ["파스타", "FOOD"], ["이탈리안", "FOOD"], ["한식", "FOOD"], ["한정식", "FOOD"],
  ["일식", "FOOD"], ["오마카세", "FOOD"], ["라멘", "FOOD"], ["돈까스", "FOOD"], ["고깃집", "FOOD"],
  ["브런치", "FOOD"], ["중식", "FOOD"], ["태국음식", "FOOD"], ["베트남음식", "FOOD"], ["버거", "FOOD"],
  ["피자", "FOOD"], ["데이트 맛집", "FOOD"], ["가성비 맛집", "FOOD"],
  ["카페", "CAFE"], ["디저트", "CAFE"], ["베이커리", "CAFE"], ["대형카페", "CAFE"], ["루프탑카페", "CAFE"], ["케이크", "CAFE"],
  ["와인바", "BAR"], ["칵테일바", "BAR"], ["이자카야", "BAR"], ["술집", "BAR"], ["포차", "BAR"], ["루프탑바", "BAR"],
  ["방탈출", "ACTIVITY"], ["보드게임카페", "ACTIVITY"], ["공방", "ACTIVITY"], ["원데이클래스", "ACTIVITY"],
  ["셀프사진관", "ACTIVITY"], ["볼링장", "ACTIVITY"], ["노래방", "ACTIVITY"], ["클라이밍", "ACTIVITY"], ["만화카페", "ACTIVITY"],
  ["전시", "EXHIBITION"], ["미술관", "EXHIBITION"], ["갤러리", "EXHIBITION"], 
  ["공원", "PARK"], ["산책", "PARK"], ["가볼만한곳", "PARK"],
];

const ADULT = /유흥|단란|룸살롱|룸싸롱|나이트|카바레|호스트|노래주점|성인/;

/** '리뷰 많은 순' 상위를 차지하는 대형 프랜차이즈는 제외 */
export const CHAINS = /스타벅스|이디야|투썸|메가(엠지씨|MGC)?커피|빽다방|컴포즈|할리스|파스쿠찌|커피빈|엔제리너스|탐앤탐스|폴바셋|배스킨|던킨|파리바게|뚜레쥬르|맥도날드|버거킹|롯데리아|KFC|맘스터치|서브웨이|써브웨이|도미노|피자헛|파파존스|BBQ|비비큐|BHC|교촌|굽네|네네치킨|처갓집|김밥천국|본죽|이삭토스트|홍콩반점|새마을식당|역전할머니|한신포차|아웃백|빕스|애슐리|공차|설빙|쥬씨|요거프레소|더벤티|매머드|드롭탑|카페베네|커피나무|달콤커피|하삼동|텐퍼센트|블루샥|벌툰|코인노래|수퍼스타코인|럭키코인/i;

interface NaverItem {
  title: string; link: string; category: string; description: string;
  telephone: string; address: string; roadAddress: string; mapx: string; mapy: string;
}

const daily = (open: string, close: string) => ({ daily: { open, close } });

interface Classified {
  category: Category; sub: string; tags: string[]; price: [number, number];
  duration: number; io: "INDOOR" | "OUTDOOR" | "MIXED"; hours: Record<string, unknown>;
}

/**
 * 세부 업종별 '보통' 영업시간. 네이버 검색 API는 영업시간을 주지 않으므로 추정치다.
 * 위에서부터 처음 맞는 규칙을 쓴다. (migrations/00009와 같은 규칙)
 */
const TYPICAL_HOURS: [Category, RegExp, string, string][] = [
  ["FOOD", /브런치/, "09:00", "17:00"],
  ["FOOD", /오마카세|스시|초밥/, "12:00", "22:00"],
  ["FOOD", /고기|육류|삼겹|갈비|곱창|구이/, "11:30", "23:00"],
  ["CAFE", /베이커리|제과|베이글|도넛/, "08:00", "21:00"],
  ["BAR", /와인|칵테일|위스키|바\(BAR\)/, "18:00", "02:00"],
  ["BAR", /이자카야|포장마차|포차|호프|요리주점/, "17:00", "02:00"],
  ["ACTIVITY", /방탈출/, "10:00", "24:00"],
  ["ACTIVITY", /보드게임|보드카페|만화카페|만화방/, "11:00", "24:00"],
  ["ACTIVITY", /노래/, "13:00", "02:00"],
  ["ACTIVITY", /셀프사진|포토부스|스티커사진/, "10:00", "24:00"],
  ["ACTIVITY", /사진관|포토스튜디오/, "11:00", "20:00"],
  ["ACTIVITY", /공방|공예|클래스|도자기|향수|캔들/, "11:00", "21:00"],
  ["ACTIVITY", /볼링/, "11:00", "24:00"],
  ["ACTIVITY", /클라이밍|볼더링/, "10:00", "23:00"],
  ["EXHIBITION", /미술관|박물관|기념관/, "10:00", "18:00"],
  ["EXHIBITION", /갤러리/, "11:00", "19:00"],
];

export function typicalHours(cls: Classified, naverCategory: string, name: string): Record<string, unknown> {
  const text = `${naverCategory} ${name}`;
  const rule = TYPICAL_HOURS.find(([cat, re]) => cat === cls.category && re.test(text));
  return rule ? daily(rule[2], rule[3]) : cls.hours;
}

/** 네이버 분류("음식점>이탈리아음식", "카페,디저트>베이커리" 등) → 내부 카테고리 */
export function classify(naverCategory: string, name: string, fallback: Category): Classified | null {
  const c = naverCategory;
  const sub = c.split(">").pop()?.trim() || c;
  // 이름으로도 놀거리를 판단하되, 음식점·쇼핑 분류면 분류만 본다 (예: 이름에 "향수"가 든 마라탕집)
  const has = (re: RegExp) => re.test(c) || (!/음식점|한식|양식|일식|중식|카페,디저트|술집|쇼핑|유통|화장품/.test(c) && re.test(name));
  if (ADULT.test(c) || ADULT.test(name)) return null;
  if (CHAINS.test(name)) return null;
  // 기간 정보가 없어 이미 끝난 팝업이 섞이므로 팝업은 수집하지 않는다
  if (/팝업/.test(c) || /팝업|pop-?up/i.test(name)) return null;
  // PC방·용품점·체육센터는 코스 장소가 아니다
  if (/PC방|용품|체육센터|헬스|피트니스|세탁|부동산|병원|의원|약국|학원/.test(c)) return null;
  if (/체육관/.test(c) && !/클라이밍|볼더링|암장/.test(name)) return null;
  const isFoodOrShop = /음식점|한식|양식|일식|중식|카페,디저트|술집|쇼핑|유통|화장품/.test(c);

  const act = (tags: string[], price: [number, number], duration: number): Classified =>
    ({ category: "ACTIVITY", sub, tags: ["FUN", ...tags], price, duration, io: "INDOOR", hours: daily("11:00", "23:00") });
  if (has(/방탈출/)) return act(["GROUP", "DATE"], [20000, 26000], 80);
  if (has(/보드게임|보드카페/)) return act(["GROUP", "KIDS", "CHEAP"], [8000, 12000], 90);
  if (has(/만화카페|만화방/)) return act(["SOLO_FRIENDLY", "QUIET", "DATE"], [8000, 12000], 90);
  if (has(/볼링/)) return act(["GROUP", "ACTIVE"], [8000, 12000], 90);
  if (has(/노래방|노래연습장|코인노래/)) return act(["GROUP", "CHEAP", "NIGHT"], [3000, 10000], 60);
  if (has(/클라이밍|볼더링/)) return act(["ACTIVE", "GROUP", "TRENDY"], [20000, 28000], 120);
  // 쇼핑 분류(도자기·향수 가게)는 이름에 '공방/클래스'가 있을 때만 체험으로 본다
  if (isFoodOrShop ? /공방|클래스/.test(name) && !/음식점|카페|술집/.test(c) : /공방|공예|원데이클래스|도자기|향수|캔들/.test(`${c} ${name}`)) {
    return act(["DATE", "ART", "ROMANTIC"], [30000, 50000], 120);
  }
  if (has(/셀프사진|포토부스|사진관|포토스튜디오/)) return act(["INSTAGRAM", "DATE"], [8000, 20000], 30);
  if (/스포츠|오락|레저|체험/.test(c)) return act(["ACTIVE"], [10000, 25000], 90);

  if (!isFoodOrShop && /미술관|갤러리|전시|박물관|기념관|문화,예술/.test(c)) {
    return { category: "EXHIBITION", sub, tags: ["ART", "QUIET", "INSTAGRAM"], price: [0, 15000], duration: 70, io: "INDOOR", hours: daily("10:00", "19:00") };
  }
  if (/공원|숲|산책|하천|호수|한강|정원|둘레길|궁|명소|관광|전망/.test(c)) {
    return { category: "PARK", sub, tags: ["HEALING", "NATURE", "SPACIOUS", "VIEW"], price: [0, 0], duration: 60, io: "OUTDOOR", hours: daily("00:00", "24:00") };
  }
  if (/카페|디저트|베이커리|제과|케이크|아이스크림|빙수|찻집|전통찻집|도넛/.test(c)) {
    const dessert = /디저트|베이커리|제과|케이크|아이스크림|빙수|도넛/.test(c);
    return {
      category: "CAFE", sub, tags: dessert ? ["INSTAGRAM", "TRENDY", "DATE"] : ["QUIET", "SOLO_FRIENDLY", "INSTAGRAM"],
      price: dessert ? [7000, 14000] : [5000, 10000], duration: 50, io: "INDOOR", hours: daily("10:00", "22:00"),
    };
  }
  if (/술집|주점|바\(BAR\)|와인|칵테일|이자카야|포장마차|호프|맥주|펍|위스키|요리주점/.test(c)) {
    const mood = /와인|칵테일|바\(BAR\)|위스키/.test(c);
    return {
      category: "BAR", sub, tags: mood ? ["ROMANTIC", "DATE", "NIGHT", "QUIET"] : ["GROUP", "FUN", "NIGHT"],
      price: mood ? [20000, 40000] : [15000, 25000], duration: 80, io: "INDOOR", hours: daily("17:00", "01:00"),
    };
  }
  if (/음식점|식당|요리|한식|양식|일식|중식|분식|고기|국수|찌개|레스토랑/.test(c)) {
    const food = (tags: string[], price: [number, number]): Classified =>
      ({ category: "FOOD", sub, tags: ["FOODIE", ...tags], price, duration: 60, io: "INDOOR", hours: daily("11:00", "21:30") });
    if (/이탈리아|양식|스테이크|프랑스|스페인|브런치|파스타|피자/.test(c)) return food(["DATE", "ROMANTIC", "INSTAGRAM"], [18000, 32000]);
    if (/오마카세|초밥|스시|일식|라멘|돈가스|돈까스|우동|덮밥/.test(c)) return food(["DATE", "SOLO_FRIENDLY"], [13000, 30000]);
    if (/태국|베트남|인도|멕시코|아시아|동남아/.test(c)) return food(["TRENDY", "DATE"], [13000, 22000]);
    if (/중식|중국/.test(c)) return food(["GROUP"], [10000, 20000]);
    if (/고기|육류|삼겹|갈비|곱창|구이/.test(c)) return food(["GROUP", "LOCAL"], [16000, 28000]);
    if (/분식|떡볶이|김밥|햄버거|버거/.test(c)) return food(["CHEAP", "KIDS"], [7000, 14000]);
    return food(["LOCAL", "KIDS"], [10000, 18000]);
  }
  // 네이버 분류가 비어 있을 때만 검색어의 카테고리를 쓴다 (음식·카페·술집만)
  if (!c.trim() && (fallback === "FOOD" || fallback === "CAFE" || fallback === "BAR")) {
    const byKeyword = { FOOD: "음식점>맛집", CAFE: "카페,디저트>카페", BAR: "술집>주점" }[fallback];
    return classify(byKeyword, name, "PARK");
  }
  return null;
}

function apiConfig(): { url: string; headers: Record<string, string> } | null {
  const id = Deno.env.get("NAVER_CLIENT_ID"), secret = Deno.env.get("NAVER_CLIENT_SECRET");
  if (id && secret) return { url: "https://openapi.naver.com/v1/search/local.json", headers: { "X-Naver-Client-Id": id, "X-Naver-Client-Secret": secret } };
  const hubId = Deno.env.get("NCP_APIGW_API_KEY_ID"), hubKey = Deno.env.get("NCP_APIGW_API_KEY");
  if (hubId && hubKey) return { url: "https://naverapihub.apigw.ntruss.com/search/v1/local", headers: { "X-NCP-APIGW-API-KEY-ID": hubId, "X-NCP-APIGW-API-KEY": hubKey } };
  return null;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const MIN_INTERVAL_MS = 150;
let lastCall = 0;

async function search(api: { url: string; headers: Record<string, string> }, query: string): Promise<NaverItem[]> {
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
    if (res.status === 401 || res.status === 403) throw new Error(`네이버 API 인증 실패(${res.status} ${err.errorCode ?? ""})`);
    if (res.status === 429) {
      if (err.errorCode === "012") throw new Error("네이버 API 하루 호출 한도를 모두 썼습니다(012). 내일 다시 실행하세요");
      await sleep(1000 * (attempt + 1));
      continue;
    }
    return [];
  }
  throw new Error("네이버 API 호출 한도 초과(429)가 계속됩니다. 잠시 후 다시 실행하세요");
}

const toDeg = (v: string) => { const n = Number(v); return Math.abs(n) > 1000 ? n / 1e7 : n; };
const stripTags = (s: string) =>
  s.replace(/<[^>]+>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
const norm = (s: string) => s.replace(/[\s·()\-_.,&'"]/g, "").toLowerCase();

function metersBetween(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

interface Collected { item: NaverItem; name: string; lat: number; lng: number; bestRank: number; hits: number; fallback: Category }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const secret = Deno.env.get("INGEST_SECRET");
  if (!secret || req.headers.get("x-ingest-secret") !== secret) return json({ error: "unauthorized" }, 401);
  const api = apiConfig();
  if (!api) return json({ error: "NAVER_CLIENT_ID/NAVER_CLIENT_SECRET 또는 NCP_APIGW_API_KEY_ID/NCP_APIGW_API_KEY가 없습니다" }, 500);

  const body = await req.json().catch(() => ({}));
  const requested: string[] = Array.isArray(body.areas) && body.areas.length ? body.areas : Object.keys(AREAS);
  const perCall = Math.min(Math.max(Number(body.perCall) || 2, 1), 3);
  const names = requested.slice(0, perCall);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const done: Record<string, unknown> = {};

  for (const [idx, name] of names.entries()) {
    const area = AREAS[name.replace("서울 ", "")];
    if (!area) { done[name] = "unknown area"; continue; }
    const [cLat, cLng] = area.center;

    // 1) 검색: 같은 가게는 이름+좌표로 하나로 합치고, 최고 순위와 등장 횟수를 기록
    const collected = new Map<string, Collected>();
    let queries = 0;
    let stopError: string | null = null;
    try {
      for (const alias of area.aliases) {
        for (const [kw, fallback] of KEYWORDS) {
          queries++;
          const items = await search(api, `${alias} ${kw}`);
          items.forEach((item, rank) => {
            const nm = stripTags(item.title);
            const lat = toDeg(item.mapy), lng = toDeg(item.mapx);
            if (!nm || !lat || !lng) return;
            // 동네 중심에서 3km 넘게 떨어진 결과(동명이인 지역 등)는 버린다
            if (metersBetween(cLat, cLng, lat, lng) > 3000) return;
            const key = `${norm(nm)}@${lat.toFixed(4)},${lng.toFixed(4)}`;
            const prev = collected.get(key);
            if (prev) { prev.hits++; prev.bestRank = Math.min(prev.bestRank, rank + 1); }
            else collected.set(key, { item, name: nm, lat, lng, bestRank: rank + 1, hits: 1, fallback });
          });
        }
      }
    } catch (e) {
      stopError = String(e instanceof Error ? e.message : e); // 그때까지 모은 것은 저장한다
    }

    // 2) 분류 후 저장
    const counts: Record<string, number> = {};
    const rows = [];
    for (const [key, c] of collected) {
      const cls = classify(c.item.category ?? "", c.name, c.fallback);
      if (!cls) continue;
      counts[cls.category] = (counts[cls.category] ?? 0) + 1;
      // 검색어 하나에서 1위였거나 3개 이상의 검색어에 등장한 곳만 인기 표시
      const popular = c.bestRank === 1 || c.hits >= 3;
      rows.push({
        name: c.name,
        category: cls.category,
        subcategory: cls.sub,
        description: c.item.category || null,
        address: c.item.roadAddress || c.item.address || "",
        location: `SRID=4326;POINT(${c.lng} ${c.lat})`,
        latitude: c.lat,
        longitude: c.lng,
        phone: c.item.telephone || null,
        website_url: c.item.link || null,
        price_min: cls.price[0],
        price_max: cls.price[1],
        duration_minutes: cls.duration,
        indoor_outdoor: cls.io,
        tags: popular ? [...cls.tags, "POPULAR"] : cls.tags,
        opening_hours: typicalHours(cls, c.item.category ?? "", c.name),
        source: "NAVER",
        source_id: key.slice(0, 250),
        is_active: true,
        last_verified_at: new Date().toISOString(),
      });
    }
    let errors = 0;
    for (let i = 0; i < rows.length; i += 200) {
      const { error } = await supabase.from("places").upsert(rows.slice(i, i + 200), { onConflict: "source,source_id" });
      if (error) errors++;
    }
    done[name] = { queries, found: collected.size, saved: rows.length, popular: rows.filter((r) => r.tags.includes("POPULAR")).length, byCategory: counts, errors };

    if (stopError) {
      return json({ ok: false, error: stopError, done, remaining: requested.slice(idx) }, 502);
    }
  }

  return json({ ok: true, done, remaining: requested.slice(perCall) });
});
