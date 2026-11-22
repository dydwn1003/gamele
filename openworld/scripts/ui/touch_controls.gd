extends Control
## 모바일 터치 조작.
## 화면 왼쪽: 손가락을 댄 곳에 생기는 가상 조이스틱
## 화면 오른쪽: 드래그로 카메라 회전 + 공격/점프/회피/질주/상호작용 버튼
## 여러 손가락을 동시에 추적한다 (이동하면서 공격·카메라 회전 가능).

const JOY_RADIUS := 85.0

var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _button_touch := {}  # 손가락 index -> action


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _buttons() -> Array:
	var s := size
	var list := [
		{"action": "attack", "label": "공격", "pos": Vector2(s.x - 135, s.y - 135), "r": 72.0, "color": Color(0.85, 0.3, 0.25)},
		{"action": "jump", "label": "점프\n활공", "pos": Vector2(s.x - 275, s.y - 85), "r": 50.0, "color": Color(0.3, 0.6, 0.9)},
		{"action": "dodge", "label": "구르기", "pos": Vector2(s.x - 120, s.y - 290), "r": 50.0, "color": Color(0.55, 0.45, 0.85)},
		{"action": "sprint", "label": "질주", "pos": Vector2(s.x - 255, s.y - 225), "r": 44.0, "color": Color(0.35, 0.7, 0.4)},
	]
	list.append({"action": "potion", "label": "물약\n%d" % GameState.heal_item_total(), "pos": Vector2(s.x - 395, s.y - 80), "r": 42.0, "color": Color(0.75, 0.2, 0.3)})
	if Controls.interact_hint != "":
		list.append({"action": "interact", "label": "확인", "pos": Vector2(s.x - 330, s.y - 340), "r": 50.0, "color": Color(0.95, 0.7, 0.2)})
	return list


func _button_at(p: Vector2) -> String:
	for b in _buttons():
		if p.distance_to(b["pos"]) <= float(b["r"]) + 10.0:
			return b["action"]
	return ""


## HUD 의 메뉴 버튼 같은 UI 위를 누른 터치는 조이스틱/카메라로 쓰지 않는다
func _blocked(p: Vector2) -> bool:
	var list: Array = get_tree().get_nodes_in_group("touch_block")
	for c in list:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = make_input_local(event)
		if e.pressed:
			if _blocked(e.position):
				return
			var act := _button_at(e.position)
			if act != "":
				_button_touch[e.index] = act
				Controls.press(act)
			elif e.position.x < size.x * 0.42 and _joy_index == -1:
				_joy_index = e.index
				_joy_origin = e.position
				_joy_pos = e.position
			elif _look_index == -1:
				_look_index = e.index
		else:
			if _button_touch.has(e.index):
				Controls.release(_button_touch[e.index])
				_button_touch.erase(e.index)
			if e.index == _joy_index:
				_joy_index = -1
				Controls.move_touch = Vector2.ZERO
			if e.index == _look_index:
				_look_index = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var e: InputEventScreenDrag = make_input_local(event)
		if e.index == _joy_index:
			_joy_pos = e.position
			var v := (_joy_pos - _joy_origin) / JOY_RADIUS
			if v.length() > 1.0:
				v = v.normalized()
			Controls.move_touch = v
			queue_redraw()
		elif e.index == _look_index:
			Controls.look_delta += e.relative


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	# 조이스틱
	var base := _joy_origin if _joy_index != -1 else Vector2(170, size.y - 170)
	var knob := base + Controls.move_touch * JOY_RADIUS if _joy_index != -1 else base
	var alpha := 0.55 if _joy_index != -1 else 0.25
	draw_circle(base, JOY_RADIUS, Color(1, 1, 1, alpha * 0.35))
	draw_arc(base, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, alpha), 3.0, true)
	draw_circle(knob, 36.0, Color(1, 1, 1, alpha + 0.15))

	for b in _buttons():
		var pressed := _button_touch.values().has(b["action"]) or Controls.held(b["action"])
		var c: Color = b["color"]
		var pos: Vector2 = b["pos"]
		var r: float = b["r"]
		var art: Texture2D = _art(b["action"])
		if art:
			# 디자인 그림 버튼: 누르면 살짝 작아지고 밝아진다
			var rr := r * (0.92 if pressed else 1.0)
			draw_texture_rect(art, Rect2(pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false,
				Color(1.25, 1.2, 1.1, 1.0) if pressed else Color(1, 1, 1, 0.88))
			if b["action"] == "potion":  # 남은 개수 배지
				var bp := pos + Vector2(r * 0.62, r * 0.62)
				draw_circle(bp, 16, Color(0.75, 0.15, 0.15))
				draw_string(font, bp + Vector2(-16, 7), str(GameState.heal_item_total()), HORIZONTAL_ALIGNMENT_CENTER, 32, 19, Color.WHITE)
			continue
		draw_circle(pos, r, Color(c.r, c.g, c.b, 0.8 if pressed else 0.45))
		draw_arc(pos, r, 0, TAU, 40, Color(1, 1, 1, 0.7), 3.0, true)
		var lines: PackedStringArray = String(b["label"]).split("\n")
		var fs := 24 if r > 60 else 20
		var y0 := pos.y - (lines.size() - 1) * fs * 0.55 + fs * 0.35
		for i in lines.size():
			draw_string(font, Vector2(pos.x - r, y0 + i * fs * 1.1), lines[i], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1))


var _art_cache := {}


func _art(action: String) -> Texture2D:
	if not _art_cache.has(action):
		var path := "res://art/ui/btn_%s.png" % action
		_art_cache[action] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[action]
