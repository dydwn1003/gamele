# 달빛장터 (MOONLIT MARKET)

한국 야시장 경영 · 타이쿤 · 하이브리드 방치형 모바일 게임 프로토타입.
Godot 4.x (GDScript, 2D, GL Compatibility 렌더러), 세로형 720x1280 기준.

> 외부 이미지/유료 리소스 없이 실행됩니다. 모든 그래픽은 Godot 2D 도형으로 그리고,
> 효과음은 코드로 합성합니다.

## 실행 방법

1. Godot **4.4 이상** (4.1+ 필요: `static var` 사용) 을 설치합니다.
2. Godot 프로젝트 매니저에서 `moonlit_market/project.godot` 를 가져와 실행(F5)합니다.
   - 데스크톱 창은 405x720 으로 열리며 마우스 클릭이 터치로 동작합니다.
3. 테스트(헤드리스) — Godot 이 없으면 자동으로 내려받아 설치합니다:
   ```bash
   cd moonlit_market
   bash tools/test.sh          # 종료 코드 0 = 전체 통과
   bash tools/screenshots.sh   # Xvfb 에서 자동 플레이하며 screenshots/ 에 PNG 저장
   ```
   직접 실행하려면 `godot --headless --path . res://tests/test_runner.tscn -- --test`.
   `--test` 인자가 있으면 `user://_test_saves` 를 사용하므로 실제 세이브를 건드리지 않습니다.

### Claude Code (클라우드 세션)에서 실행
- 클라우드 환경 설정 스크립트가 새 세션마다 Godot 4.4.1 을 `/usr/local/bin/godot` 에 설치합니다.
  설정이 없는 환경이어도 `tools/setup_godot.sh` 가 자동 설치하므로 `bash tools/test.sh` 만 실행하면 됩니다.
- 화면 확인은 `bash tools/screenshots.sh` → 새 게임, 노점 설치, 영업 준비, 영업 중(3배속),
  정산, 상인, 시너지 화면 8장을 저장합니다.

### 웹(HTML5) 빌드
```bash
bash tools/build_web.sh                       # 웹 템플릿 자동 설치(1회, 약 1.2GB 다운로드) 후 내보내기
cd build/web && python3 -m http.server 8000   # 브라우저에서 http://localhost:8000
```
- 스레드를 쓰지 않는 빌드라 특별한 서버 헤더 없이 어떤 정적 호스팅(GitHub Pages, itch.io 등)에서도 동작합니다.
- `build/artifact/` 는 claude.ai 아티팩트용입니다. 파일당 크기 제한 때문에 엔진(wasm 약 44MB)을
  14MB 조각으로 나누고, 페이지의 로더가 받아서 합칩니다.
- 웹에서는 OS 글꼴을 쓸 수 없어 `assets/fonts/` 의 Noto Sans KR(OFL, 상용 한글 2,350자 + 게임 문자로 축소)을 사용합니다.
- 저장 데이터는 브라우저(IndexedDB)에 남습니다.

### Android 빌드
Godot 에디터 → Project → Install Android Build Template, Export → Android 프리셋 추가
(Android SDK/JDK 필요). 화면 방향은 세로(Portrait), 렌더러는 Compatibility 로 설정되어 있습니다.

### 한국어 글꼴
`assets/fonts/main.ttf`, `main_bold.ttf` 에 Noto Sans KR(SIL Open Font License, `assets/fonts/OFL.txt`)을
축소해서 넣었습니다 (상용 한글 2,350자 + 게임에 쓰인 문자). 게임 텍스트에 새 한자/특수문자를 쓰면
글꼴을 다시 축소해야 합니다. 파일이 없으면 OS 시스템 글꼴로 대체됩니다.

## 플레이 흐름

1. 접속 → 지난 영업 정산 / 오프라인 수익 확인
2. 빈 자리(+)를 눌러 노점·시설 설치 (6개 고정 슬롯, 이웃 조합 시너지)
3. **영업 준비**: 메뉴 선택, 가격(80~130%), 재고 구매, 상인 배치, 예상 매출 확인
4. **영업 시작**: 240초 동안 손님이 입구 → 통로 → 노점 대기열 → 구매 → 출구로 실제 이동
5. 정산: 방문/구매/이탈, 총매출/원가/순수익, 만족도, 인기 노점, 획득 평판 → **정산 받기(1회)**
6. 평판으로 시장 단계(작은 노점 → 골목 시장 → 인기 야시장) 상승, 노점/상인/장식 해금

## 폴더 구조

```
project.godot
scenes/   main/ market/(market, market_slot, stall) customer/ ui/(main_hud + 패널 10종)
scripts/
  core/     game_manager(Autoload) game_state save_manager(Autoload) economy_manager
            progression_manager offline_manager data_manager(Autoload)
  market/   market_manager stall_manager synergy_manager operating_manager
            market_slot stall market_ground draw_util
  customer/ customer customer_manager customer_ai
  staff/    staff_manager
  ui/       ui_manager market_hud base_panel ui_kit(디자인 시스템) icon + 패널 스크립트
  services/ rewarded_ad_service purchase_service sfx_player
  main/     main
data/       stalls menus customers employees decorations weather events synergies
            progression balance bm (.json)
tests/      run_tests economy_test save_test customer_test (+ test_runner.tscn)
```

### 설계 원칙
- **데이터 중심**: 모든 수치/밸런스는 `data/*.json` (`balance.json` 에 경제·영업·오프라인 상수).
  키가 누락되면 DataManager 가 기본값으로 채우고 경고를 남깁니다.
- **UI ↔ 로직 분리**: UI 는 `GameManager` 의 행동 API(build_structure, restock, set_menu …)만
  호출하고, 상태 변경 결과는 시그널로 받습니다.
- **Autoload 최소화**: DataManager, SaveManager, GameManager 3개.
  경제/성장/오프라인/상인/시너지는 GameManager 가 소유하는 RefCounted 객체입니다.

## 핵심 규칙 요약

| 항목 | 규칙 |
|---|---|
| 시작 | 코인 500, 평판 0, 꼬치 전문점 1개(Lv1, 재고 20), 기본 상인 1명, 슬롯 6개 |
| 매출 | 총매출 = 판매 수량 × 실제 판매 가격 (판매 즉시 코인 지급) |
| 원가 | 재고 구매 시 원가 선결제. 정산의 재료 원가 = 판매 수량 × 메뉴 원가 |
| 순수익 | 총매출 − 재료 원가 − 기타 비용(영업 후 남은 재고 15% 손실) |
| 정산 보상 | 평판 + 만족도 보너스(평균 70 이상 시 매출의 5%) — session_id 로 1회만 지급 |
| 가격 | 기준가 80~130%. 비쌀수록 선택/구매 확률·만족도↓, 개당 이익↑ (손님 유형별 민감도 다름) |
| 손님 선택 | 취향 × 가격 × 노점 평판 × 대기열 × 거리 × 날씨/이벤트 → 가중 확률 선택 (구매 안 함 포함) |
| 오프라인 | 최근 정상 영업 분당 순수익 × 분 × 0.35, 최대 240분, 시간 역행 감지, 1회 수령 |
| 저장 | JSON, 버전 2, tmp→검증→백업→교체, 손상 시 tmp/백업 복구, 30초 자동 저장 + 행동 직후 + 백그라운드 |

## 구현 상태

구현: 아이소메트릭 시장(6슬롯, 입구 간판, 통로, 조명), 노점 4종 × 5레벨, 메뉴 8종, 가격/재고/메뉴 변경,
손님 4종 실시간 이동·선택·대기열·구매·이탈·반응, 240초 영업 + 배속 + 날씨 3종 + 이벤트 5종,
정산 화면, 상인 7명(기본 1 + 고용 6) 고용/레벨/배치, 시너지 4종(시각 표시 포함), 시설 2종,
장식 5종, 시장 3단계, 오프라인 수익, 저장/백업/마이그레이션, 설정, 상점(비활성), 안전 영역 대응.

TODO (미구현):
- 실제 광고/결제 SDK 연동 (`RewardedAdService`, `PurchaseService` 에 연결 지점 표시, 서버 영수증 검증)
- 배경 음악 에셋 (설정 값만 저장됨)
- 영업 도중 앱 종료 시 진행 중 세션 복원 (판매로 받은 코인/재고는 저장되지만 세션은 이어지지 않음)
- 시각 앞당기기 악용은 로컬만으로 완전 차단 불가 → 서버 시간 검증
- 카메라 줌, 자유 배치, 퀘스트 시스템(현재는 평판/영업 횟수/누적 판매 조건으로 해금)
- 시너지 연계 이동 전용 이펙트
