// 소상공인시장진흥공단 상가(상권)정보 공통 로직 (ingest-store-data, ingest-naver-popular 공용)
export type Category = "FOOD" | "CAFE" | "BAR" | "ACTIVITY" | "EXHIBITION";


/** 알려진 체인점 이름. 그 밖에 같은 반경 안에 같은 상호가 여러 개면 체인으로 본다 */
export const CHAINS = /스타벅스|이디야|투썸|메가(엠지씨|MGC)?커피|빽다방|컴포즈|할리스|파스쿠찌|커피빈|엔제리너스|탐앤탐스|폴바셋|배스킨|던킨|파리바게|뚜레쥬르|맥도날드|버거킹|롯데리아|KFC|맘스터치|서브웨이|써브웨이|도미노|피자헛|파파존스|BBQ|비비큐|BHC|교촌|굽네|네네|처갓집|김밥천국|본죽|이삭토스트|홍콩반점|새마을식당|역전할머니|한신포차|코인노래|GS25|CU|세븐일레븐|이마트|노브랜드|다이소|올리브영/i;

export interface Store {
  bizesId: string; bizesNm: string; brchNm?: string;
  indsLclsNm?: string; indsMclsNm?: string; indsSclsNm?: string;
  rdnmAdr?: string; lnoAdr?: string; lon: string | number; lat: string | number;
}

export interface Classified { category: Category; sub: string; tags: string[]; price: [number, number]; duration: number; hours: Record<string, unknown> }

const daily = (open: string, close: string) => ({ daily: { open, close } });

export function classify(s: Store): Classified | null {
  const l = s.indsLclsNm ?? "", m = s.indsMclsNm ?? "", sc = s.indsSclsNm ?? "", name = s.bizesNm ?? "";
  const text = `${m} ${sc} ${name}`;
  // 유흥·단란주점 등 성인 업소는 추천하지 않는다
  if (/유흥|단란|무도|나이트|카바레|룸살롱|성인/.test(`${sc} ${name}`)) return null;
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
  if (!/음식/.test(l) && /공방|원데이|도자기|향수|캔들/.test(text)) return act("공방 체험", ["DATE", "ART", "ROMANTIC"], [30000, 50000], 120);
  // 사진촬영업은 대부분 웨딩·프로필 스튜디오라 셀프사진관 이름일 때만 넣는다
  if (/셀프|포토|인생네컷|네컷|부스|필름|photo/i.test(name) && /사진|포토/.test(text)) return act("셀프사진", ["INSTAGRAM", "DATE"], [8000, 20000], 30);
  if (/갤러리|화랑|미술관|아트/.test(name) && /예술품|전시|미술|박물/.test(`${m} ${sc}`)) {
    return { category: "EXHIBITION", sub: "갤러리", tags: ["ART", "QUIET", "INSTAGRAM"], price: [0, 5000], duration: 40, hours: daily("11:00", "19:00") };
  }

  if (!/음식/.test(l)) return null;
  if (/구내식당|출장|케이터링|배달|도시락|급식/.test(text)) return null;

  // 카페·디저트
  if (!/주점/.test(sc) && /카페|커피|제과|베이커리|빵|디저트|아이스크림|빙수|찻집|전통차|차 전문|도넛|케이크/.test(text)) {
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

export async function fetchStores(key: string, lat: number, lng: number, radius: number, maxPages: number): Promise<Store[]> {
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

export const norm = (s: string) => s.replace(/[\s·()]/g, "").toLowerCase();

export function metersBetween(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

