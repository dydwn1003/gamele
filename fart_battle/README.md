# 방귀 대결! 뿌앙 리그

엉덩이를 맞댄 동물들이 무지개빛 **방귀 빔**을 쏘아 가운데서 맞부딪히는 코믹 대전 게임.
Godot 4.4 (GDScript, 2D, GL Compatibility), 세로 720x1280, 그래픽·효과음 모두 코드로 생성.

## 플레이
- **뿡 버튼**을 꾹 누르면 압력이 차고, 떼면 방귀 빔! 게이지가 **초록 구간**일 때 떼면 「완벽한 뿡」(파워 ×1.6, 무지개 빔)
- 너무 오래 참으면 **삐끗** → 기절 + 빔이 나에게 밀려옴
- **코 막기**: 상대 빔 대부분을 막음. 상대가 뀌기 직전(0.3초 이내)에 막으면 **튕겨내기**
- 경기 중 나오는 **음식**을 탭: 매운 고추(불꽃 빔), 고구마(파워), 콩(가스), 삶은 계란(냄새 지속),
  탄산음료(빨리 참), 양배추(가스 충전 2배), 우유(초강력 아니면 배탈)
- 빔이 부딪히는 지점을 **상대 엉덩이까지 밀면 라운드 승리**, 3판 2선승
- 모드: **혼자 하기**(상대 5명 리그: 꼬마 다람쥐 → 멧돼지 할매 → 헬스 고릴라 → 스컹크 박사 → 하마 대왕),
  **둘이서 대결**(폰 하나를 위아래로 잡고, 멀티터치)

## 실행 / 테스트 / 빌드
```bash
cd fart_battle
bash tools/test.sh          # 헤드리스 테스트 (Godot 자동 설치)
bash tools/screenshots.sh   # 자동 플레이 스크린샷 → screenshots/
bash tools/build_web.sh     # build/web (일반 호스팅), build/artifact (claude.ai 아티팩트용)
```
PC 에서는 마우스 클릭이 터치로 동작하고, 스페이스 = 뿡, B = 코 막기.

## 구조
- `scripts/core/battle_logic.gd` 규칙(순수 로직) · `scripts/ai/ai_controller.gd` 컴퓨터 상대
- `scripts/battle/` 대결장(arena), 동물(critter), 조작부(pad), 대결 흐름(battle)
- `scripts/audio/fart_synth.gd` 방귀 효과음 합성 · `scripts/core/save.gd` 리그 진행/전적 저장
- `data/*.json` 캐릭터·음식·밸런스 수치 (코드 수정 없이 조정)

## HTML 버전 (Godot 없이 바로 실행)

`web/fart_battle.html` 하나만 브라우저로 열면 됩니다 (인터넷 없으면 기본 글꼴로 표시).
규칙은 `scripts/core/battle_logic.gd` 를 JavaScript 로 옮긴 것이고, 수치는 `data/*.json` 에서 가져옵니다.
수치나 `web/template.html` 을 고치면 `bash tools/build_html.sh` 로 다시 만드세요.

### HTML 버전 전용 (아직 Godot 버전에는 없음)
- 필살 게이지: 완벽한 뿡 +34, 맞히기 +8, 튕겨내기 +25. 꽉 찬 뒤 다음 완벽한 뿡이 필살기
  (파워 ×2, 튕겨내기 불가, 막아도 절반만 줄어듦, 컷인 연출). 수치는 `data/balance.json` 의 `special_*`.
- 이펙트: 나선이 감기는 물줄기형 빔, 모으기 오라·완벽 구간 반짝임, 충돌 섬광·물보라, 충격파 고리,
  큰 방귀 타격 경직·줌, KO 슬로모션, 탄산 먹으면 파란 거품 빔.
