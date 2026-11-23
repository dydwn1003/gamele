extends Node2D
## MarketManager — 시장 월드의 루트. 레이아웃(고정 좌표), 슬롯 생성, 터치 입력, 배치/이동 모드,
## 판매 연출을 담당한다. 디자인 좌표계는 720x960 이며 fit_to_rect() 로 화면에 맞춘다.

const SlotScene := preload("res://scenes/market/market_slot.tscn")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal slot_tapped(idx: int)
signal mode_changed(mode: String)

const DESIGN_SIZE := Vector2(720, 960)
## 슬롯 0~2: 통로 왼쪽(위→아래), 3~5: 통로 오른쪽(위→아래). 인접 관계는 synergies.json
const SLOT_POSITIONS := [Vector2(172, 300), Vector2(172, 490), Vector2(172, 680),
	Vector2(548, 300), Vector2(548, 490), Vector2(548, 680)]
const DECO_SPOTS := [Vector2(84, 868), Vector2(636, 868), Vector2(306, 170), Vector2(414, 170)]
const LANE_IN_X := 346.0
const LANE_OUT_X := 380.0
const SPAWN_POINT := Vector2(350, 948)
const EXIT_POINT := Vector2(380, 952)
const TAP_SLOP := 24.0

@onready var ground: Node2D = $Ground
@onready var world: Node2D = $World
@onready var overhead: Node2D = $Overhead
@onready var effects: Node2D = $Effects
@onready var stall_manager = $StallManager
@onready var customer_manager = $CustomerManager
@onready var operating = $OperatingManager

var slot_nodes: Array = []
var mode: String = "normal" ## normal / place / move
var place_type: String = ""
var move_from: int = -1
var selected_slot: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_index: int = -1


class FloatText extends Node2D:
	var text: String = ""
	var color: Color = Color.WHITE
	var size: int = 26
	var life: float = 1.2
	var t: float = 0.0
	var font: Font

	func _process(delta: float) -> void:
		t += delta
		position.y -= 46.0 * delta
		modulate.a = clampf(1.0 - (t / life) * (t / life), 0.0, 1.0)
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var w := 300.0
		var p := Vector2(-w / 2.0, 0)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 6, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)


func _ready() -> void:
	ground.market = self
	overhead.market = self
	for i in SLOT_POSITIONS.size():
		var n = SlotScene.instantiate()
		n.slot_index = i
		n.facing = 1 if i < 3 else -1
		n.position = SLOT_POSITIONS[i]
		world.add_child(n)
		slot_nodes.append(n)
	stall_manager.market = self
	customer_manager.market = self
	customer_manager.stall_manager = stall_manager
	customer_manager.world = world
	operating.stall_manager = stall_manager
	operating.customer_manager = customer_manager
	GameManager.slots_changed.connect(refresh_slots)
	GameManager.state_changed.connect(refresh_slots)
	stall_manager.sale_made.connect(_on_sale)
	customer_manager.walkout_feedback.connect(_on_walkout)
	refresh_slots()


func _process(_delta: float) -> void:
	if operating.is_running():
		refresh_slots()


func refresh_slots() -> void:
	if slot_nodes.is_empty():
		return
	for i in slot_nodes.size():
		var s: Dictionary = GameManager.state.get_slot(i)
		slot_nodes[i].update_data(s, stall_manager.get_runtime(i), GameManager.slot_synergies(i),
			GameManager.economy.stock_max(i), GameManager.is_operating)
	_update_highlights()


## 화면의 사용 가능 영역(HUD 사이)에 시장 전체가 보이도록 배치
func fit_to_rect(rect: Rect2) -> void:
	var s := minf(rect.size.x / DESIGN_SIZE.x, rect.size.y / DESIGN_SIZE.y)
	s = clampf(s, 0.4, 1.3)
	scale = Vector2(s, s)
	position = rect.position + (rect.size - DESIGN_SIZE * s) / 2.0


# ───────── 레이아웃 ─────────

func queue_spot(slot_idx: int, k: int) -> Vector2:
	if slot_idx < 0 or slot_idx >= SLOT_POSITIONS.size():
		return SPAWN_POINT
	var p: Vector2 = SLOT_POSITIONS[slot_idx]
	if slot_idx < 3:
		return p + Vector2(92, 40) + Vector2(14, 24) * k
	return p + Vector2(-92, 40) + Vector2(-14, 24) * k


func spawn_point(rng: RandomNumberGenerator) -> Vector2:
	return SPAWN_POINT + Vector2(rng.randf_range(-10, 10), rng.randf_range(-4, 4))


func browse_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(LANE_IN_X + rng.randf_range(-22, 22), rng.randf_range(790, 840))


func slot_world_pos(idx: int) -> Vector2:
	return SLOT_POSITIONS[idx]


# ───────── 입력 ─────────

## 터치는 Android 에서 마우스 이벤트로도 전달(emulate_mouse_from_touch)되므로
## 마우스 버튼만 처리한다. GUI 컨트롤 위의 입력은 GUI 가 먼저 소비하므로
## 버튼 영역과 시장 터치 영역이 겹쳐 동시에 눌리는 일이 없다.
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local_event = make_input_local(mb)
	var pos: Vector2 = local_event.position
	if mb.pressed:
		_press_pos = pos
		_press_index = 1
		return
	if _press_index != 1:
		return
	_press_index = -1
	if pos.distance_to(_press_pos) > TAP_SLOP / maxf(0.1, scale.x):
		return
	var idx := slot_at(pos)
	if idx >= 0:
		get_viewport().set_input_as_handled()
		slot_tapped.emit(idx)


func slot_at(local_pos: Vector2) -> int:
	# 아래쪽(앞쪽) 슬롯이 위에 그려지므로 역순으로 검사
	var order := [2, 5, 1, 4, 0, 3]
	for i in order:
		if slot_nodes[i].hit_rect().has_point(local_pos):
			return i
	return -1


# ───────── 모드 ─────────

func enter_place_mode(structure_type: String) -> void:
	mode = "place"
	place_type = structure_type
	move_from = -1
	_update_highlights()
	mode_changed.emit(mode)


func enter_move_mode(from_idx: int) -> void:
	mode = "move"
	move_from = from_idx
	place_type = ""
	_update_highlights()
	mode_changed.emit(mode)


func cancel_mode() -> void:
	mode = "normal"
	place_type = ""
	move_from = -1
	_update_highlights()
	mode_changed.emit(mode)


func set_selected(idx: int) -> void:
	selected_slot = idx
	_update_highlights()


func _update_highlights() -> void:
	for i in slot_nodes.size():
		var h := ""
		match mode:
			"place":
				if GameManager.state.is_slot_empty(i):
					h = "place"
			"move":
				if i == move_from:
					h = "move_source"
				else:
					h = "move_target"
			_:
				if i == selected_slot:
					h = "selected"
		slot_nodes[i].set_highlight(h)


# ───────── 연출 ─────────

func spawn_float_text(pos: Vector2, text: String, color: Color, size: int = 26) -> void:
	var ft := FloatText.new()
	ft.text = text
	ft.color = color
	ft.size = size
	ft.font = UIKit.bold_font()
	ft.position = pos
	effects.add_child(ft)


func _on_sale(slot_idx: int, price: int, _sat: float) -> void:
	slot_nodes[slot_idx].flash()
	var p: Vector2 = SLOT_POSITIONS[slot_idx] + Vector2(0, -150)
	spawn_float_text(p, "+%d" % price, Color("#FFD27A"), 28)


func _on_walkout(pos: Vector2) -> void:
	spawn_float_text(pos + Vector2(0, -70), "이탈", Color("#E5564A"), 20)
