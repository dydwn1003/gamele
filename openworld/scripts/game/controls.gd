extends Node
## 입력 통합 관리 (자동 로드: Controls)
## 터치 HUD(가상 조이스틱/버튼)와 키보드 입력을 하나로 합쳐서
## 플레이어·카메라·봉화가 같은 방식으로 읽을 수 있게 한다.

const ACTIONS := ["jump", "attack", "dodge", "sprint", "interact"]

## 가상 조이스틱 값 (-1..1). y가 +면 뒤쪽(화면 아래)
var move_touch := Vector2.ZERO
## 이번 프레임까지 쌓인 카메라 회전량(픽셀)
var look_delta := Vector2.ZERO
## 봉화 근처 등에서 HUD에 띄울 상호작용 안내 문구 (빈 문자열이면 숨김)
var interact_hint := ""

var _pending := {}
var _held := {}


func _ready() -> void:
	# 다른 노드의 _physics_process가 끝난 뒤 눌림 상태를 비우도록 마지막에 실행
	process_physics_priority = 100
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE])
	_add_keys("attack", [KEY_J, KEY_ENTER])
	_add_keys("dodge", [KEY_K, KEY_CTRL])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("interact", [KEY_E, KEY_F])


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		for a in ACTIONS:
			if event.is_action_pressed(a):
				_pending[a] = true


func _physics_process(_delta: float) -> void:
	_pending.clear()


## 터치 버튼이 눌렸을 때 HUD가 호출
func press(action: String) -> void:
	_pending[action] = true
	_held[action] = true


func release(action: String) -> void:
	_held[action] = false


## 이번 틱에 새로 눌렸으면 true를 돌려주고 소모한다
func consume(action: String) -> bool:
	if _pending.get(action, false):
		_pending.erase(action)
		return true
	return false


func held(action: String) -> bool:
	return bool(_held.get(action, false)) or Input.is_action_pressed(action)


## 이동 입력 (x: 오른쪽 +, y: 뒤쪽 +)
func get_move() -> Vector2:
	if move_touch.length() > 0.08:
		return move_touch
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d
