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

Supabase를 연결하려면:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

값이 없거나 DB 연결에 실패하면 `assets/mock/places.json`(성수·연남 샘플 38곳)으로 자동 전환됩니다.

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
  functions/       generate-plan-explanation (Claude), ingest-tour-data (TourAPI + 서울시)
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
```

- 비회원 플랜은 앱이 보내는 `x-session-id` 헤더와 일치하는 행만 읽을 수 있도록 RLS를 강화했습니다.
- `plan_items`는 `places` FK가 있어서 DB 장소로만 이루어진 코스만 저장되고, 샘플 데이터 코스는 기기에만 저장됩니다.

## 명세와 다르게 구현한 부분

| 명세 | 구현 | 이유 |
|---|---|---|
| Freezed / json_serializable | 직접 작성한 불변 모델 + `fromJson/toJson` | 코드 생성 단계 없이 바로 빌드 |
| Riverpod `StateNotifier` | Riverpod 3 `Notifier` / `AsyncNotifier` | StateNotifier는 Riverpod 3에서 legacy |
| google_maps_flutter | flutter_map + CARTO 타일 | API 키 없이 동작, 오프라인이면 종이 지도 배경으로 표시 |
| Lottie 로딩 | CustomPainter 동선 애니메이션 | 별도 애니메이션 파일 없이 동일한 연출 |
| S_pop 미정의 | `평점/5 × min(1, log10(리뷰+1)/4)` | 리뷰가 적은 고평점 장소 과대평가 방지 |

샘플 데이터의 장소·가격·영업시간은 데모용이며 실제 정보와 다를 수 있습니다.
