extends Node2D
## MarketManager — 시장 월드 루트 (디자인 좌표 720x760).
##
##  ┌ 거리 (y 0~270) ─ 밤하늘, 경쟁 노점 가게 5칸, 손님이 좌우로 걷는 길, 드럼통 테이블
##  └ 포차 내부 (y 270~760) ─ 천막 천장/뒷벽 메뉴판, 손님 테이블 줄, 사장님이 걷는 통로,
##                              맨 앞 카운터(화구 · 서빙대 · 술 냉장고)
##
## 레이아웃(고정 좌표), 노드 생성, 터치 입력(손님/테이블 탭 → 서빙/치우기), 연출을 담당한다.

const StallScene := preload("res://scenes/market/stall.tscn")
const PochaScene := preload("res://scenes/market/pocha.tscn")
const TableScene := preload("res://scenes/market/seat_table.tscn")
const BarScene := preload("res://scenes/market/bar_counter.tscn")
const ServerScene := preload("res://scenes/market/server.tscn")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal pocha_tapped
signal rival_tapped(rival_id: String)

const DESIGN_SIZE := Vector2(720, 760)
const SKY_CROP := 30.0
# ── 거리 ──
const STOREFRONT_X := [76.0, 218.0, 360.0, 502.0, 644.0]
const STOREFRONT_Y := 206.0 ## 가게 앞 (대기줄 발 위치)
const STREET_Y := 238.0 ## 걷는 길 (발 위치)
const STREET_LEFT := 10.0
const STREET_RIGHT := 710.0
const STREET_TABLES := [Vector2(150, 258), Vector2(570, 258)]
const EAT_SPOTS := [Vector2(118, 262), Vector2(182, 262), Vector2(538, 262), Vector2(602, 262),
	Vector2(30, 258), Vector2(690, 258)]
# ── 포차 ──
const ENTRANCE := Vector2(360, 300)
## 자리가 없으면 포차 입구 밖 거리에 줄을 선다
const WAIT_SPOTS := [Vector2(318, 252), Vector2(292, 256), Vector2(266, 260), Vector2(240, 264)]
## ㄱ자 바: 가로 바(메뉴판 아래, 손님은 정면) + 오른쪽 세로 바(손님은 바깥쪽)
const SEAT_Y := 478.0
const BAR_FRONT_Y := 500.0
const BAR_LEFT := 30.0
const BAR_CORNER_X := 606.0 ## 세로 바 왼쪽 끝
const BAR_LEG_BOTTOM := 664.0
const H_SEAT_X0 := 66.0
const H_SEAT_STEP := 66.0
const H_SEATS := 8
const V_SEAT_X := 684.0
const V_SEAT_Y := [536.0, 588.0, 640.0]
const AISLE_Y := 572.0
const PASS_POS := Vector2(360, 600)
const GRILL_POS := Vector2(130, 600)
const DRINK_POS := Vector2(526, 600)
const COUNTER_Y := 690.0
const POCHA_POS := Vector2(360, 690) ## 앞 카운터 노드 위치 (이전 버전 호환 이름)
const DECO_SPOTS := [Vector2(40, 330), Vector2(680, 330), Vector2(40, 560), Vector2(680, 560)]
const TAP_SLOP := 24.0

@onready var ground: Node2D = $Ground
@onready var world: Node2D = $World
@onready var overhead: Node2D = $Overhead
@onready var effects: Node2D = $Effects
@onready var rival_manager = $RivalManager
@onready var pocha_manager = $PochaManager
@onready var customer_manager = $CustomerManager
@onready var operating = $OperatingManager

var pocha_node ## 앞 카운터 (화구·서빙대·냉장고)
var server ## 사장님 아바타
var table_nodes: Array = []
var rival_nodes: Dictionary = {}
var rival_slots: Dictionary = {}
var eat_spot_owner: Array = []
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false


class FloatText extends Node2D:
	var text: String = ""
	var color: Color = Color.WHITE
	var size: int = 26
	var life: float = 1.2
	var t: float = 0.0
	var rise: float = 46.0
	var font: Font

	func _process(delta: float) -> void:
		t += delta
		position.y -= rise * delta
		var k := t / life
		scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 0.15 - t) / 0.15)
		modulate.a = clampf(1.0 - k * k, 0.0, 1.0)
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var w := 320.0
		var p := Vector2(-w / 2.0, 0)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 7, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)


## 동전 튀는 연출
class CoinBurst extends Node2D:
	var t: float = 0.0
	var coins: Array = []

	func setup(n: int, rng: RandomNumberGenerator) -> void:
		for i in n:
			coins.append({"v": Vector2(rng.randf_range(-90, 90), rng.randf_range(-260, -160)), "p": Vector2.ZERO})

	func _process(delta: float) -> void:
		t += delta
		for c in coins:
			c["v"].y += 620.0 * delta
			c["p"] += c["v"] * delta
		modulate.a = clampf(1.4 - t * 1.6, 0.0, 1.0)
		if t > 0.9:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for c in coins:
			draw_circle(c["p"], 7, Color("#FFB45C"))
			draw_circle(c["p"] + Vector2(-1.5, -1.5), 3.5, Color("#FFE0A0"))
			draw_arc(c["p"], 7, 0, TAU, 12, Color("#9A5A1C"), 1.5, true)


func _ready() -> void:
	ground.market = self
	overhead.market = self
	pocha_node = PochaScene.instantiate()
	pocha_node.position = POCHA_POS
	pocha_node.market = self
	world.add_child(pocha_node)
	server = ServerScene.instantiate()
	server.market = self
	server.position = PASS_POS
	world.add_child(server)
	rival_manager.market = self
	pocha_manager.market = self
	pocha_manager.server = server
	server.pocha = pocha_manager
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
	pocha_manager.tip_collected.connect(_on_tip)
	pocha_manager.seats_changed.connect(_rebuild_tables)
	customer_manager.walkout_feedback.connect(_on_walkout)
	refresh()


## 단계에 맞는 경쟁 노점/테이블 노드 구성
func refresh() -> void:
	var ids: Array = GameManager.progression.active_rivals()
	for id in rival_nodes.keys():
		if not ids.has(id):
			rival_nodes[id].queue_free()
			rival_nodes.erase(id)
			rival_slots.erase(id)
	# 등장 순서대로 가게 자리 배정 (가운데부터 바깥으로)
	var order := [1, 3, 0, 4, 2]
	for i in ids.size():
		var id: String = ids[i]
		if not rival_nodes.has(id) and i < order.size():
			var slot: int = order[i]
			var n = StallScene.instantiate()
			n.position = Vector2(STOREFRONT_X[slot], STOREFRONT_Y)
			n.rival_id = id
			n.market = self
			world.add_child(n)
			rival_nodes[id] = n
			rival_slots[id] = slot
	_rebuild_tables()


var bar_node


func _rebuild_tables() -> void:
	if bar_node == null:
		bar_node = BarScene.instantiate()
		bar_node.market = self
		bar_node.position = Vector2(0, BAR_FRONT_Y)
		world.add_child(bar_node)
	var n := seat_count()
	if table_nodes.size() == n:
		return
	for t in table_nodes:
		t.queue_free()
	table_nodes = []
	for i in n:
		var t = TableScene.instantiate()
		t.index = i
		t.market = self
		t.vertical = is_vertical_seat(i)
		t.position = place_pos(i)
		world.add_child(t)
		table_nodes.append(t)


func seat_count() -> int:
	if pocha_manager and pocha_manager.is_open:
		return pocha_manager.seats.size()
	return int(DataManager.get_pocha_level(GameManager.state.pocha_level()).get("seats", 3))


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
	return Vector2(STOREFRONT_X[int(rival_slots.get(rival_id, 0))], STOREFRONT_Y)


func rival_queue_spot(rival_id: String, k: int) -> Vector2:
	var p := rival_pos(rival_id)
	var dir := 1.0 if p.x < 360.0 else -1.0
	return Vector2(p.x + dir * (8.0 + 22.0 * k), STOREFRONT_Y + 4.0 + 3.0 * k)


func max_seats() -> int:
	return H_SEATS + V_SEAT_Y.size()


func is_vertical_seat(i: int) -> bool:
	return i >= H_SEATS


func seat_x(i: int, _count: int = 0) -> float:
	return V_SEAT_X if is_vertical_seat(i) else H_SEAT_X0 + H_SEAT_STEP * i


## 손님이 앉는 자리 (발 위치)
func seat_pos(i: int, _count: int = 0) -> Vector2:
	if is_vertical_seat(i):
		return Vector2(V_SEAT_X, V_SEAT_Y[clampi(i - H_SEATS, 0, V_SEAT_Y.size() - 1)])
	return Vector2(seat_x(i), SEAT_Y)


## 바 위에 음식이 놓이는 자리 (y-sort 상 손님보다 앞)
func place_pos(i: int) -> Vector2:
	if is_vertical_seat(i):
		return Vector2(BAR_CORNER_X + 22.0, seat_pos(i).y + 2.0)
	return Vector2(seat_x(i), BAR_FRONT_Y + 2.0)


## 사장님이 서빙할 때 서는 자리
func serve_pos(i: int, _count: int = 0) -> Vector2:
	if is_vertical_seat(i):
		return Vector2(BAR_CORNER_X - 34.0, seat_pos(i).y)
	return Vector2(seat_x(i), AISLE_Y)


func wait_pos(k: int) -> Vector2:
	return WAIT_SPOTS[clampi(k, 0, WAIT_SPOTS.size() - 1)]


func spawn_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(STREET_LEFT if rng.randf() < 0.5 else STREET_RIGHT, STREET_Y + rng.randf_range(-4, 4))


func browse_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(140, 580), STREET_Y + rng.randf_range(-3, 3))


func exit_point(from: Vector2) -> Vector2:
	return Vector2(STREET_LEFT if from.x < 360.0 else STREET_RIGHT, STREET_Y)


## 먹을 자리 배정 (없으면 -1 → 서서 먹기)
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

## 터치는 Android 에서 마우스 이벤트로도 전달되므로 마우스 버튼만 처리.
## 영업 중: 손님/테이블 탭 → 사장님이 서빙/치우기. 평소: 포차/경쟁 노점 정보.
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
	if handle_tap(pos):
		get_viewport().set_input_as_handled()


func handle_tap(pos: Vector2) -> bool:
	if pocha_manager.is_open:
		var seat := seat_at(pos)
		if seat >= 0:
			pocha_manager.tap_seat(seat)
			return true
		return false
	if pos.y > 280.0:
		pocha_tapped.emit()
		return true
	for id in rival_nodes.keys():
		var p := rival_pos(id)
		if Rect2(p + Vector2(-66, -150), Vector2(132, 160)).has_point(pos):
			rival_tapped.emit(id)
			return true
	return false


func seat_at(pos: Vector2) -> int:
	var n := seat_count()
	for i in n:
		var sp := seat_pos(i)
		var r := Rect2(Vector2(sp.x - H_SEAT_STEP / 2.0, sp.y - 120), Vector2(H_SEAT_STEP, 160))
		if is_vertical_seat(i):
			r = Rect2(Vector2(BAR_CORNER_X - 10, sp.y - 48), Vector2(130, 52))
		if r.has_point(pos):
			return i
	return -1


# ───────── 연출 ─────────

func spawn_float_text(pos: Vector2, text: String, color: Color, size: int = 26) -> void:
	var ft := FloatText.new()
	ft.text = text
	ft.color = color
	ft.size = size
	ft.font = UIKit.bold_font()
	ft.position = pos
	effects.add_child(ft)


func spawn_coins(pos: Vector2, n: int) -> void:
	var cb := CoinBurst.new()
	cb.setup(clampi(n, 3, 10), pocha_manager.rng)
	cb.position = pos
	effects.add_child(cb)


func _on_served(_seat: int, _menu: String, quality: float, price: int, pos: Vector2) -> void:
	spawn_float_text(pos + Vector2(0, -86), "+%d" % price, Color("#FFD27A"), 26)
	if quality >= 99.0:
		var combo: int = pocha_manager.combo
		spawn_float_text(pos + Vector2(0, -116), "완벽!" if combo < 2 else "완벽! 콤보 x%d" % combo, Color("#65C99A"), 22)


func _on_tip(pos: Vector2, amount: int) -> void:
	spawn_coins(pos + Vector2(0, -20), amount / 10 + 3)
	spawn_float_text(pos + Vector2(0, -60), "팁 +%d" % amount, Color("#65C99A"), 24)


func _on_walkout(pos: Vector2) -> void:
	spawn_float_text(pos + Vector2(0, -70), "이탈", Color("#E5564A"), 20)
