# 달빛장터 (Godot 4) 작업 지침

- Godot 4.4+, GDScript. 렌더러는 GL Compatibility (모바일 우선).
- 수치는 코드가 아닌 `data/*.json` 에서 조정한다. 새 키를 추가하면 `DataManager` 기본값도 추가.
- UI 는 상태를 직접 바꾸지 말고 `GameManager` 행동 API 를 거친다. 새 화면은 `base_panel.gd` 상속 +
  `UIKit` 컴포넌트만 사용 (화면별 임의 스타일 금지, 이모지 금지).
- `class_name` 대신 `preload` 상수를 쓴다 (헤드리스 테스트에서 글로벌 클래스 캐시 의존 방지).
- `:=` 로 Variant(딕셔너리 값 등) 타입 추론 금지 → `var x: int = d["k"]` 처럼 명시.
- 재화 변경은 `EconomyManager.spend/earn` 으로만. 정산/오프라인 보상은 중복 지급 방지 로직 유지.
- 테스트: `bash tools/test.sh` (Godot 자동 설치) · 화면 확인: `bash tools/screenshots.sh`
- UI 를 바꾸면 screenshots.sh 로 실제 화면을 확인한다. 실행해 보지 않은 것을 테스트했다고 기록하지 않는다.
