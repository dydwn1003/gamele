# 에버린: 잊힌 봉화

모바일용 로우폴리 오픈월드 액션 RPG입니다. Godot 4.5로 만들었습니다.
기획과 캐릭터 디자인은 [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)에 있습니다.

외부 모델이나 텍스처 파일 없이 **지형·캐릭터·나무·건물을 전부 코드로 생성**하기 때문에, 프로젝트를 열면 바로 실행됩니다.

## 실행하기 (PC)
1. [Godot 4.5](https://godotengine.org/download)를 설치합니다. 표준 버전이면 되고, .NET 버전은 필요 없습니다.
2. Godot을 실행하고 **가져오기(Import)** → 이 폴더의 `project.godot`를 선택합니다.
3. 오른쪽 위 ▶ 버튼(F5)을 누릅니다.

PC에서는 마우스로 터치를 흉내 냅니다. 화면 왼쪽을 드래그하면 이동, 오른쪽을 드래그하면 카메라가 돌아가고, 버튼은 클릭하면 됩니다.
키보드도 쓸 수 있습니다: WASD 이동, Space 점프/활공, J 공격, K 구르기, Shift 질주, E 상호작용, Q 물약, Tab/I 메뉴, M 지도.

## 자동 플레이 테스트 (Claude Code / 리눅스)
```bash
openworld/tools/run_playtest.sh
```
- Godot이 없으면 `~/.cache/godot`에 공식 빌드를 내려받습니다.
- 먼저 스크립트 오류를 검사합니다.
- 그다음 가상 화면에서 게임을 자동으로 플레이하고 장면별 스크린샷을 `openworld/.playtest/`에 저장합니다.
- 자동 플레이 순서: 시작 → 카엘 클로즈업 → 봉화 이동 → 골렘 전투 → 봉화 점화 → 활공
- 테스트 내용은 `tools/playtest.gd`에서 바꿀 수 있습니다.

## 휴대폰에서 실행하기 (안드로이드)
### APK 만들기
```bash
openworld/tools/build_apk.sh      # → openworld/build/everin.apk
```
- Android SDK나 Android Studio가 없어도 됩니다.
- 필요한 것(Godot, 내보내기 템플릿, 서명 도구)은 처음 한 번만 `~/.cache/godot`에 받습니다. 템플릿이 약 1.3GB라 처음에는 오래 걸립니다.
- 서명 키도 `~/.cache/godot/everin.keystore`에 처음 한 번 만듭니다. 키가 바뀌면 폰에서 기존 앱을 지운 뒤 새로 설치해야 합니다.

### 폰에 설치하기
1. `everin.apk`를 폰으로 옮깁니다. 카카오톡 나에게 보내기, 구글 드라이브, USB 중 편한 방법을 쓰면 됩니다.
2. 폰에서 파일을 누르면 "출처를 알 수 없는 앱" 경고가 뜹니다. **설정 → 이 출처 허용**을 켭니다.
3. 설치를 누릅니다. Play 프로텍트 경고가 뜨면 **무시하고 설치**를 누릅니다. 직접 만든 앱이라 뜨는 경고입니다.

Godot 에디터에서 직접 내보내려면 **편집기 설정 → 내보내기 → Android**에 실제 Android SDK 경로를 지정하고, **프로젝트 → 내보내기 → Android**를 사용하면 됩니다.

iOS는 Mac과 Xcode가 있어야 합니다.

## 폴더 구조
```
openworld/
├─ project.godot              프로젝트 설정 (모바일 렌더러, 가로 화면)
├─ scenes/main.tscn           시작 씬 (main.gd 하나만 붙어 있음)
├─ audio/                     효과음·배경음악 (tools/gen_audio.py 로 합성)
├─ art/                       디자인 그림 (Gemini 로 제작)
│  ├─ icons/items/<아이템 id>.png   아이템 아이콘 28종 (파일명 = items.gd 의 id)
│  ├─ ui/                     로고, 앱 아이콘, 패널·버튼(9-slice), 터치 버튼, 메뉴 아이콘
│  └─ concept/                스타일 가이드, 캐릭터 컨셉
├─ docs/GAME_DESIGN.md        기획서 · 캐릭터 디자인
└─ scripts/
   ├─ main.gd                 하늘·조명·낮밤·월드·플레이어·UI 조립, 부활 처리
   ├─ game/
   │  ├─ game_state.gd        레벨·인벤토리·장비·강화·퀘스트·봉화·저장 (자동 로드)
   │  ├─ controls.gd          터치 + 키보드 입력 통합 (자동 로드)
   │  ├─ sfx.gd               효과음·배경음악 (자동 로드)
   │  ├─ items.gd             아이템 28종, 제작 레시피, 상점 목록
   │  ├─ quests.gd            퀘스트 13개
   │  └─ fx.gd                데미지 숫자, 한글 폰트
   ├─ models/
   │  ├─ low_poly.gd          로우폴리 메시 생성기 (상자·원기둥·구 → 플랫 셰이딩)
   │  ├─ humanoid_model.gd    카엘 / 고블린 / 골렘 모델 + 관절 애니메이션
   │  └─ wolf_model.gd        늑대 모델 + 네 발 애니메이션
   ├─ world/
   │  ├─ terrain.gd           섬 지형 공식 (노이즈), 지형 색, 봉화 위치
   │  ├─ chunk.gd             48m 지형 조각: 메시·충돌·나무/바위 배치
   │  ├─ world.gd             청크 스트리밍 + 바다
   │  ├─ props.gd             나무·바위·덤불·꽃 메시
   │  ├─ beacon.gd            봉화탑, 수호자 소환, 점화
   │  ├─ village.gd / npc.gd  새벽 마을과 NPC 4명
   │  ├─ camp.gd / chest.gd   몬스터 거점 13곳과 보물상자
   │  ├─ resource_node.gd     약초·철광맥 채집
   │  ├─ pickup.gd            떨어진 전리품
   │  └─ interaction.gd       '확인' 버튼 상호작용 (대화·채집·상자·봉화)
   ├─ player/
   │  ├─ player.gd            이동·질주·점프·활공·구르기·콤보·수영
   │  └─ camera_rig.gd        3인칭 카메라
   ├─ enemies/
   │  ├─ enemy.gd             적 AI (배회 → 추적 → 예고 → 공격)
   │  └─ enemy_spawner.gd     주변 적 생성·정리
   └─ ui/
      ├─ title_screen.gd      타이틀 화면
      ├─ hud.gd               체력·기력, 메뉴 버튼, 퀘스트 추적, 배너, 보스 체력바
      ├─ game_menu.gd         가방·장비·퀘스트·지도·설정
      ├─ dialog_ui.gd         NPC 대화, 상점, 대장간
      ├─ item_icon.gd         아이템 아이콘 (코드로 그림)
      ├─ ui_kit.gd            공용 UI 테마
      ├─ touch_controls.gd    가상 조이스틱 + 버튼 (멀티터치)
      └─ radar.gd             레이더/나침반
```

## 자주 바꿀 만한 값
- 맵 모양: `scripts/main.gd`의 `WORLD_SEED`를 바꾸면 완전히 다른 섬이 됩니다.
- 시야 거리와 성능: `scripts/world/world.gd`의 `view_radius`(기본 4 → 약 190m). 저사양 폰이라면 3으로 낮추세요.
- 섬 크기: `scripts/world/terrain.gd`의 `WORLD_RADIUS`
- 적 능력치: `scripts/enemies/enemy.gd`의 `TYPES`
- 플레이어 속도와 콤보: `scripts/player/player.gd` 위쪽의 상수들

## 알려진 한계 (프로토타입)
- 애니메이션은 관절을 코드로 돌리는 방식이라 단순합니다. 나중에 Mixamo 애니메이션이 들어간 .glb 모델로 바꿀 수 있습니다.
- 한글은 기기의 시스템 폰트를 사용합니다. 글자가 깨지면 Noto Sans KR 같은 폰트 파일을 프로젝트에 넣고 `scripts/game/fx.gd`에서 지정하세요.

## 디자인 그림 교체하기
- 그림 파일이 있으면 그림을 쓰고, 없으면 코드로 그린 기본 모양을 씁니다. 그래서 같은 이름으로 파일을 덮어쓰기만 하면 바로 바뀝니다.
- 아이템 아이콘: `art/icons/items/<id>.png` (정사각형, 투명 배경)
- 터치 버튼: `art/ui/btn_<attack|jump|dodge|sprint|potion|interact>.png` (원형, 투명 배경)
- 메뉴 아이콘: `art/ui/tab_<bag|equip|quest|map|settings>.png`
- 패널·버튼: `art/ui/panel.png`, `button_normal.png`, `button_pressed.png` (모서리 장식은 늘어나지 않는 9-slice)
