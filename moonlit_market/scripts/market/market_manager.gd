extends Node2D
## MarketManager — 시장 월드 루트. 레이아웃(고정 좌표), 내 포차/경쟁 노점 노드, 먹는 자리 배정,
## 터치 입력, 연출을 담당한다. 디자인 좌표계 720x720, fit_to_rect() 로 화면에 맞춘다.
##
## 배치: 위쪽 입구 → 중앙 통로(가운데 먹자 테이블) → 양옆 경쟁 노점 → 맨 아래 내 포장마차

const StallScene := preload("res://scenes/market/stall.tscn")
const PochaScene := preload("res://scenes/market/pocha.tscn")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal pocha_tapped
signal rival_tapped(rival_id: String)

const DESIGN_SIZE := Vector2(720, 720)
const SKY_CROP := 20.0
## 경쟁 노점 자리 (등장 순서대로 사용)
const RIVAL_POSITIONS := [Vector2(132, 262), Vector2(588, 262), Vector2(112, 440), Vector2(608, 440), Vector2(636, 598)]
const RIVAL_SCALE := 0.78
const POCHA_POS := Vector2(360, 600)
const LANE_IN_X := 300.0
const LANE_OUT_X := 420.0
const SPAWN_POINT := Vector2(330, 88)
const EXIT_POINT := Vector2(392, 84)
## 먹자 테이블 / 벤치 (테이블 중심, 손님이 서는 자리)
const TABLES := [Vector2(360, 232), Vector2(360, 318)]
const EAT_SPOTS := [Vector2(326, 243), Vector2(394, 243), Vector2(360, 258),
	Vector2(326, 329), Vector2(394, 329), Vector2(360, 344),
	Vector2(60, 640), Vector2(96, 656), Vector2(48, 560), Vector2(84, 572)]
const DECO_SPOTS := [Vector2(236, 120), Vector2(484, 120), Vector2(28, 470), Vector2(692, 470)]
const TAP_SLOP := 24.0

@onready var ground: Node2D = $Ground
@onready var world: Node2D = $World
@onready var overhead: Node2D = $Overhead
@onready var effects: Node2D = $Effects
@onready var rival_manager = $RivalManager
@onready var pocha_manager = $PochaManager
@onready var customer_manager = $CustomerManager
@onready var operating = $OperatingManager

var pocha_node
var rival_nodes: Dictionary = {} ## rival_id -> node
var rival_slots: Dictionary = {} ## rival_id -> position index
var eat_spot_owner: Array = []
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false


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
	pocha_node = PochaScene.instantiate()
	pocha_node.position = POCHA_POS
	pocha_node.market = self
	world.add_child(pocha_node)
	rival_manager.market = self
	pocha_manager.market = self
	customer_manager.market = self
	customer_manager.rival_manager = rival_manager
	customer_manager.pocha_manager = pocha_manager
	customer_manager.world = world
	operating.rival_manager = rival_manager
	operating.pocha_manager = pocha_manager
	operating.customer_manager = customer_manager
	for i in EAT_SPOTS.size():
		eat_spot_owner.append(null)
	GameManager.state_changed.connect(refresh)
	pocha_manager.served.connect(_on_served)
	pocha_manager.feedback.connect(spawn_float_text)
	customer_manager.walkout_feedback.connect(_on_walkout)
	refresh()


## 단계에 맞는 경쟁 노점 노드를 만들고, 상태를 다시 그린다
func refresh() -> void:
	var ids: Array = GameManager.progression.active_rivals()
	for id in rival_nodes.keys():
		if not ids.has(id):
			rival_nodes[id].queue_free()
			rival_nodes.erase(id)
			rival_slots.erase(id)
	for i in ids.size():
		var id: String = ids[i]
		if not rival_nodes.has(id) and i < RIVAL_POSITIONS.size():
			var n = StallScene.instantiate()
			n.position = RIVAL_POSITIONS[i]
			n.scale = Vector2(RIVAL_SCALE, RIVAL_SCALE)
			n.facing = 1 if RIVAL_POSITIONS[i].x < 360 else -1
			n.rival_id = id
			n.market = self
			world.add_child(n)
			rival_nodes[id] = n
			rival_slots[id] = i
	if pocha_node:
		pocha_node.queue_redraw()


func rival_ids() -> Array:
	return rival_nodes.keys()


## 화면의 사용 가능 영역에 시장 전체가 보이도록 배치
func fit_to_rect(rect: Rect2) -> void:
	var content := Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - SKY_CROP)
	var s := minf(rect.size.x / content.x, rect.size.y / content.y)
	s = clampf(s, 0.3, 1.4)
	scale = Vector2(s, s)
	position = rect.position + (rect.size - content * s) / 2.0 - Vector2(0, SKY_CROP * s)


# ───────── 레이아웃 ─────────

func rival_pos(rival_id: String) -> Vector2:
	return RIVAL_POSITIONS[int(rival_slots.get(rival_id, 0))]


func rival_queue_spot(rival_id: String, k: int) -> Vector2:
	var p := rival_pos(rival_id)
	var s := RIVAL_SCALE
	if p.x < 360:
		return p + Vector2(92, 40) * s + Vector2(12, 20) * k
	return p + Vector2(-92, 40) * s + Vector2(-12, 20) * k


func seat_pos(i: int, count: int) -> Vector2:
	var spacing := 48.0
	var x0 := POCHA_POS.x - spacing * (count - 1) / 2.0
	return Vector2(x0 + spacing * i, POCHA_POS.y + 58)


func wait_pos(k: int) -> Vector2:
	return Vector2(206 - 26 * k, POCHA_POS.y + 74 + 10 * k)


func spawn_point(rng: RandomNumberGenerator) -> Vector2:
	return SPAWN_POINT + Vector2(rng.randf_range(-10, 10), rng.randf_range(-4, 4))


func browse_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(LANE_IN_X + rng.randf_range(-12, 12), rng.randf_range(140, 168))


## 먹을 자리 배정 (없으면 -1 → 걸으면서 먹기)
func claim_eat_spot(customer, rng: RandomNumberGenerator) -> int:
	var free: Array = []
	for i in eat_spot_owner.size():
		if eat_spot_owner[i] == null or not is_instance_valid(eat_spot_owner[i]):
			free.append(i)
	if free.is_empty():
		return -1
	var idx: int = free[rng.randi() % free.size()]
	eat_spot_owner[idx] = customer
	return idx


func release_eat_spot(idx: int) -> void:
	if idx >= 0 and idx < eat_spot_owner.size():
		eat_spot_owner[idx] = null


func release_all_spots() -> void:
	for i in eat_spot_owner.size():
		eat_spot_owner[i] = null


# ───────── 입력 ─────────

## 터치는 Android 에서 마우스 이벤트로도 전달(emulate_mouse_from_touch)되므로 마우스 버튼만 처리.
## GUI 위의 입력은 GUI 가 먼저 소비하므로 버튼과 시장 탭이 겹치지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local_event = make_input_local(mb)
	var pos: Vector2 = local_event.position
	if mb.pressed:
		_press_pos = pos
		_pressing = true
		return
	if not _pressing:
		return
	_pressing = false
	if pos.distance_to(_press_pos) > TAP_SLOP / maxf(0.1, scale.x):
		return
	if Rect2(POCHA_POS + Vector2(-165, -250), Vector2(330, 330)).has_point(pos):
		get_viewport().set_input_as_handled()
		pocha_tapped.emit()
		return
	for id in rival_nodes.keys():
		var p := rival_pos(id)
		if Rect2(p + Vector2(-80, -180), Vector2(160, 220)).has_point(pos):
			get_viewport().set_input_as_handled()
			rival_tapped.emit(id)
			return


# ───────── 연출 ─────────

func spawn_float_text(pos: Vector2, text: String, color: Color, size: int = 26) -> void:
	var ft := FloatText.new()
	ft.text = text
	ft.color = color
	ft.size = size
	ft.font = UIKit.bold_font()
	ft.position = pos
	effects.add_child(ft)


func _on_served(_seat: int, _menu: String, quality: float, price: int, pos: Vector2) -> void:
	pocha_node.flash()
	spawn_float_text(pos + Vector2(0, -80), "+%d" % price, Color("#FFD27A"), 26)
	if quality >= 99.0:
		spawn_float_text(pos + Vector2(0, -110), "완벽!", Color("#65C99A"), 22)


func _on_walkout(pos: Vector2) -> void:
	spawn_float_text(pos + Vector2(0, -70), "이탈", Color("#E5564A"), 20)
