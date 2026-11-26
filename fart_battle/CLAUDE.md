# 방귀 대결 (Godot 4) 작업 지침

- 규칙은 scripts/core/battle_logic.gd(순수 로직), 화면은 scripts/battle. 수치는 data/*.json.
- class_name 대신 preload, := 로 Variant 추론 금지.
- 테스트: bash tools/test.sh · 화면 확인: bash tools/screenshots.sh · 웹: bash tools/build_web.sh
- 실행해 보지 않은 것을 테스트했다고 기록하지 않는다.
