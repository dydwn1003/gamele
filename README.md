# 뭐하지? (What To Do Today)

누구와, 얼마나, 얼마로, 어떤 기분으로 — 다섯 가지 질문에 답하면 **지금 바로 갈 수 있는 코스 3개**를 골라주는 결정형 추천 앱.
추천은 AI가 아닌 순수 알고리즘(점수 공식 + 동선 조합)으로 만들고, AI는 확정된 코스를 두 문장으로 **설명만** 합니다.

## 실행

```bash
flutter pub get
flutter run                       # 기기/에뮬레이터 (Mock 데이터 모드)
flutter run -d chrome             # 웹
flutter test                      # 추천 엔진 단위 테스트 + 입력 폼 위젯 테스트
```

기본으로 뭐하지 Supabase 프로젝트(`lib/core/constants/app_config.dart`)에 연결됩니다. 다른 프로젝트를 쓰거나 샘플 데이터로만 실행하려면:

```bash
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key>
flutter run --dart-define=SUPABASE_URL=     # 샘플 데이터만
```

DB 데이터에는 샘플 데이터가 항상 보강되고(같은 장소는 DB 쪽만 사용), DB 연결에 실패하면 `assets/mock/places.json`(서울 17개 동네, 샘플 175곳)으로 자동 전환됩니다.

## 구조

```
lib/
  core/            theme(디자인 토큰) · constants · utils(Haversine, 포맷) · network(Supabase, 날씨) · router
  features/
    situation/     화면 1 — 대화형 상황 입력 (Progressive Form, 위치 권한/직접 선택)
    recommendation/화면 2 — 점수 엔진 · 코스 조합기 · 결과 리스트
    plan/          화면 3 — 타임라인 · 지도 · 길안내 딥링크 · 저장/피드백 · AI 총평
  shared_widgets/  Pressable, GradientButton, InfoBadge, PlaceCover
supabase/
  migrations/      00001 스키마·RLS·RPC(get_places_near_location), 00002 신선도 정리(pg_cron)
  seed.sql         샘플 장소
  functions/       generate-plan-explanation (Claude), ingest-tour-data (TourAPI + 서울시),
                   ingest-store-data (소상공인 상가정보: 동네별 카페·맛집·술집·놀거리),
                   ingest-naver-places (네이버 지역검색 '리뷰 많은 순' → 장소 DB, 기본 데이터 출처)
```

## 추천 알고리즘 (명세 3장)

1. **Hard Filter** — 반경(d_max), 방문 시간대 영업 여부, 1인 예산, 동행자 제약(가족 → 바 제외)
2. **Scoring** — `S = 0.25·거리 + 0.20·예산 + 0.20·동행 + 0.15·날씨 + 0.10·인기 + 0.10·참신성`
3. **Route Combinator** — 카테고리 플로우(공원/전시/팝업 → 식당 → 카페, 액티비티 → 식당 → 카페/바)를
   DFS로 조합하고 `Σ체류 + Σ이동 ≤ T_user`, `Σ비용 ≤ 예산`, 영업시간을 모두 만족하는 코스만 남김
4. **Top 3** — 베스트(기본 가중치) · 색다르게(참신성 0.40) · 가성비(예산 0.45 + 최저가)

시간에 따라 2곳(1~2시간) / 3곳(반나절) / 4곳(하루종일) 코스를 만들고, 체류시간은 최대 25%까지 줄여 시간에 맞춥니다.

## Supabase 배포

```bash
supabase link --project-ref <ref>
supabase db push                       # 스키마 + RLS + RPC
psql "$DB_URL" -f supabase/seed.sql    # (선택) 샘플 데이터

supabase secrets set ANTHROPIC_API_KEY=... TOUR_API_KEY=... SEOUL_API_KEY=... INGEST_SECRET=...
supabase functions deploy generate-plan-explanation
supabase functions deploy ingest-tour-data --no-verify-jwt
supabase functions deploy ingest-store-data --no-verify-jwt   # 공공데이터포털에서 '소상공인시장진흥공단_상가(상권)정보' 활용신청 필요
```

`ingest-store-data`는 동네마다 반경 1km 안의 가게를 받아 체인점(지점명이 있는 업소 포함)을 빼고, 카페·디저트 / 식당 / 술집 / 놀거리(방탈출·보드게임·볼링·노래방·공방 등) / 갤러리로 분류해 동네당 최대 490곳을 저장합니다.
무료 플랜의 계산 한도에 걸리지 않도록 한 번에 2개 동네만 처리하고, 남은 동네를 `remaining`으로 돌려줍니다. 체인점은 알려진 브랜드 목록과 "같은 반경 안에 같은 상호가 2곳 이상"으로 판단합니다.

- 비회원 플랜은 앱이 보내는 `x-session-id` 헤더와 일치하는 행만 읽을 수 있도록 RLS를 강화했습니다.
- `plan_items`는 `places` FK가 있어서 DB 장소로만 이루어진 코스만 저장되고, 샘플 데이터 코스는 기기에만 저장됩니다.

## 장소 데이터: 네이버 지역검색

장소 DB는 `ingest-naver-places`로 채웁니다. 동네 20곳 × 검색어 약 46개(맛집·카페·술집·놀거리·전시·공원)를
네이버 지역검색 **리뷰 많은 순**으로 조회해 저장하고, 여러 검색어에 나오거나 1~2위인 곳에 `POPULAR`(🔥 인기) 표시를 붙입니다.
유흥업소는 제외하고, 영업시간·가격은 업종별 예상값입니다. 앱은 각 장소에 '네이버 지도에서 보기' 버튼과 출처를 표시합니다.

```bash
supabase secrets set NAVER_CLIENT_ID=... NAVER_CLIENT_SECRET=...     # 기존 개발자센터 키 (2027-06-30까지)
# 또는 NAVER API HUB: supabase secrets set NCP_APIGW_API_KEY_ID=... NCP_APIGW_API_KEY=...
supabase functions deploy ingest-naver-places --no-verify-jwt
# 두 동네씩 실행 (remaining 에 남은 동네가 돌아옴)
curl -X POST "$SUPABASE_URL/functions/v1/ingest-naver-places" -H "x-ingest-secret: $INGEST_SECRET" -d '{"areas":["성수","연남"]}'
```

기존 공공데이터 장소를 지우려면 네이버 수집 후 `supabase/sql/reset_to_naver_only.sql`을 SQL Editor에서 실행합니다.

> ⚠️ 네이버 검색 결과를 DB에 저장하는 것이 네이버 오픈 API 이용약관상 허용되는지 출시 전에 확인하세요.
> 관광공사·소상공인 수집 함수(`ingest-tour-data`, `ingest-store-data`)는 공공데이터 대안으로 남겨 두었습니다.

## 명세와 다르게 구현한 부분

| 명세 | 구현 | 이유 |
|---|---|---|
| Freezed / json_serializable | 직접 작성한 불변 모델 + `fromJson/toJson` | 코드 생성 단계 없이 바로 빌드 |
| Riverpod `StateNotifier` | Riverpod 3 `Notifier` / `AsyncNotifier` | StateNotifier는 Riverpod 3에서 legacy |
| google_maps_flutter | flutter_map + CARTO 타일 | API 키 없이 동작, 오프라인이면 종이 지도 배경으로 표시 |
| Lottie 로딩 | CustomPainter 동선 애니메이션 | 별도 애니메이션 파일 없이 동일한 연출 |
| S_pop 미정의 | `평점/5 × min(1, log10(리뷰+1)/4)` | 리뷰가 적은 고평점 장소 과대평가 방지 |
| 폰트 (명세 없음) | Pretendard (SIL OFL, `assets/fonts`) | 요즘 앱에서 많이 쓰는 한글 폰트, 한글 2,350자로 줄여 번들 |

샘플 데이터는 실제 명소·시장·골목을 바탕으로 정리했지만 좌표는 근사치이고, 가격·영업시간은 카테고리 기본값이라 실제와 다를 수 있습니다. 평점·리뷰 수는 확인할 수 없어 비워 두었고, 점수 계산에서는 중립값(0.5)으로 처리합니다. 대량의 실제 데이터는 `ingest-tour-data`(TourAPI·서울시 API 키 필요)로 채우세요.
