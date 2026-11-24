extends Node
## PochaManager — 내 포장마차 영업 (플레이어가 직접 요리한다).
## 손님 좌석/대기줄, 주문서, 화구(Kitchen), 완성 대기 접시(pass), 직원 자동화를 관리한다.
##
## 흐름: 손님 착석 → 주문 → [플레이어] 메뉴 탭 → 화구에서 익음 → 제때 탭해서 꺼냄
##       → 가장 오래 기다린 같은 메뉴 주문에 자동으로 서빙 → 판매 기록
##       음료는 탭하면 바로 따라서 서빙. 태우면 재료 손실.

const KitchenScript := preload("res://scripts/market/kitchen.gd")
const MarketScript := preload("res://scripts/market/market_manager.gd")

signal changed
signal served(seat: int, menu_id: String, quality: float, price: int, pos: Vector2)
signal feedback(pos: Vector2, text: String, color: Color, size: int)

var market
var kitchen = KitchenScript.new()
var seats: Array = []
var waiting: Array = []
var orders: Array = [] ## 아직 나가지 않은 주문만 {id, customer, menu, t}
var pass_items: Array = [] ## 주문이 없어 대기 중인 완성 요리 {menu, quality, age}
var next_order_id: int = 1
var fx: Dictionary = {}
var pair: Dictionary = {}
var auto_burner: int = -1
var auto_drink_t: float = 0.0
var elapsed: float = 0.0
var is_open: bool = false


func _ready() -> void:
	kitchen.setup(2)


func level_def() -> Dictionary:
	return DataManager.get_pocha_level(GameManager.state.pocha_level())


func begin() -> void:
	var lv := level_def()
	seats = []
	for i in int(lv.get("seats", 3)):
		seats.append(null)
	waiting = []
	orders = []
	pass_items = []
	elapsed = 0.0
	kitchen.setup(int(lv.get("burners", 2)), float(DataManager.pocha.get("too_early_ratio", 0.8)))
	fx = GameManager.staff.pocha_effects()
	pair = GameManager.synergy_cache.get("effects", {})
	auto_burner = kitchen.burners.size() - 1 if float(fx.get("auto_cook", 0.0)) > 0.0 else -1
	is_open = true
	changed.emit()


func waiting_spots() -> int:
	return int(DataManager.pocha.get("waiting_spots", 3))


func free_seat() -> int:
	for i in seats.size():
		if seats[i] == null or not is_instance_valid(seats[i]):
			seats[i] = null
			return i
	return -1


func occupied_seats() -> int:
	var n := 0
	for c in seats:
		if c != null and is_instance_valid(c):
			n += 1
	return n


## 손님 선택 계산용 대기열 길이/수용량
func choice_queue_len() -> int:
	return 0 if free_seat() >= 0 else waiting.size() + 1


func choice_queue_cap() -> int:
	return waiting_spots() + 1


func cook_speed() -> float:
	return 1.0 + float(fx.get("cook_speed", 0.0))


# ───────── 손님 ─────────

func request_entry(c) -> bool:
	if not is_open:
		return false
	var s := free_seat()
	if s >= 0:
		seats[s] = c
		c.go_to_seat(s, market.seat_pos(s, seats.size()))
		changed.emit()
		return true
	if waiting.size() < waiting_spots():
		waiting.append(c)
		c.go_to_wait(waiting.size() - 1, market.wait_pos(waiting.size() - 1))
		return true
	return false


func _promote_waiting() -> void:
	for c in waiting.duplicate():
		if not is_instance_valid(c):
			waiting.erase(c)
	while not waiting.is_empty():
		var s := free_seat()
		if s < 0:
			break
		var c = waiting.pop_front()
		seats[s] = c
		c.go_to_seat(s, market.seat_pos(s, seats.size()))
	for k in waiting.size():
		waiting[k].go_to_wait(k, market.wait_pos(k))


func place_order(c, items: Array) -> void:
	for m in items:
		orders.append({"id": next_order_id, "customer": c, "menu": str(m), "t": elapsed})
		next_order_id += 1
	_match_pass()
	changed.emit()


func seat_of(c) -> int:
	return seats.find(c)


func orders_of(c) -> Array:
	var out: Array = []
	for o in orders:
		if o["customer"] == c:
			out.append(o)
	return out


func customer_left(c) -> void:
	var s := seats.find(c)
	if s >= 0:
		seats[s] = null
	waiting.erase(c)
	for o in orders.duplicate():
		if o["customer"] == c:
			orders.erase(o)
	_promote_waiting()
	changed.emit()


# ───────── 주방 (플레이어 조작) ─────────

## 메뉴를 빈 화구에 올린다 (재료 1개 사용)
func cook(menu_id: String) -> Dictionary:
	if not is_open:
		return _fail("영업 중이 아닙니다.")
	var m: Dictionary = DataManager.get_menu(menu_id)
	if str(m.get("station", "")) != "grill":
		return _fail("화구 요리가 아닙니다.")
	var i: int = kitchen.free_burner(false, auto_burner)
	if i < 0:
		return _fail("빈 화구가 없어요")
	if not GameManager.economy.consume_stock(menu_id):
		return _fail("%s 재료가 떨어졌어요" % m.get("name", ""))
	kitchen.start(i, m, cook_speed())
	changed.emit()
	return {"ok": true, "burner": i}


## 화구를 탭해서 꺼낸다
func tap_burner(i: int) -> Dictionary:
	if i == auto_burner:
		return _fail("요리사가 맡은 화구예요")
	var r: Dictionary = kitchen.collect(i)
	if r.get("empty", false):
		return _fail("비어 있는 화구예요")
	var pos: Vector2 = MarketScript.POCHA_POS + Vector2(-60 + 40 * i, -120)
	if r.get("too_early", false):
		feedback.emit(pos, "아직 덜 익었어요", Color("#FFF5E9"), 20)
		return r
	if r.get("burnt", false):
		GameManager.economy.record_waste(str(r["menu"]), true)
		feedback.emit(pos, "탔어요!", Color("#E5564A"), 24)
		changed.emit()
		return r
	var stage := str(r.get("stage", ""))
	if stage == "almost":
		feedback.emit(pos, "조금 덜 익음", Color("#FFD27A"), 20)
	elif stage == "over":
		feedback.emit(pos, "조금 탐", Color("#E97858"), 20)
	deliver(str(r["menu"]), float(r["quality"]))
	changed.emit()
	return r


## 음료: 주문한 손님이 있을 때만 따른다
func pour(menu_id: String) -> Dictionary:
	if not is_open:
		return _fail("영업 중이 아닙니다.")
	var o := _oldest_order(menu_id)
	if o.is_empty():
		return _fail("%s 주문한 손님이 없어요" % DataManager.get_menu(menu_id).get("name", ""))
	if not GameManager.economy.consume_stock(menu_id):
		return _fail("%s 재고가 없어요" % DataManager.get_menu(menu_id).get("name", ""))
	_serve(o, 100.0)
	changed.emit()
	return {"ok": true}


func _quality_with_bonus(menu_id: String, q: float) -> float:
	var sp: Dictionary = fx.get("special_menus", {})
	if sp.has(menu_id):
		q += float(sp[menu_id].get("quality_bonus", 0.0))
	return clampf(q, 0.0, 100.0)


## 완성 요리를 가장 오래 기다린 같은 메뉴 주문에 낸다. 주문이 없으면 완성 대기 접시로.
func deliver(menu_id: String, quality: float) -> void:
	var q := _quality_with_bonus(menu_id, quality)
	var o := _oldest_order(menu_id)
	if not o.is_empty():
		_serve(o, q)
		return
	pass_items.append({"menu": menu_id, "quality": q, "age": 0.0})
	var cap := int(DataManager.pocha.get("pass_capacity", 3))
	while pass_items.size() > cap:
		var old: Dictionary = pass_items.pop_front()
		GameManager.economy.record_waste(str(old["menu"]), false)


func _oldest_order(menu_id: String) -> Dictionary:
	for o in orders:
		if o["menu"] == menu_id and is_instance_valid(o["customer"]) and o["customer"].can_receive():
			return o
	return {}


func _serve(o: Dictionary, quality: float) -> void:
	orders.erase(o)
	var c = o["customer"]
	var menu_id: String = o["menu"]
	var price: int = GameManager.economy.unit_price(menu_id)
	if not GameManager.economy.record_sale(menu_id, price, quality):
		return
	c.on_item_served(menu_id, quality, price)
	served.emit(seat_of(c), menu_id, quality, price, c.position)


func _match_pass() -> void:
	for p in pass_items.duplicate():
		var o := _oldest_order(str(p["menu"]))
		if not o.is_empty():
			pass_items.erase(p)
			_serve(o, float(p["quality"]))


func tick(delta: float) -> void:
	if not is_open:
		return
	elapsed += delta
	kitchen.tick(delta)
	# 완성 대기 접시: 식으면서 품질 하락, 오래되면 폐기
	var decay := float(DataManager.pocha.get("pass_decay_time", 18.0))
	for p in pass_items.duplicate():
		p["age"] = float(p["age"]) + delta
		p["quality"] = maxf(40.0, float(p["quality"]) - delta * 1.5)
		if float(p["age"]) > decay:
			pass_items.erase(p)
			GameManager.economy.record_waste(str(p["menu"]), false)
			changed.emit()
	_match_pass()
	_auto_cook()
	_auto_drink(delta)


func _auto_cook() -> void:
	if auto_burner < 0 or auto_burner >= kitchen.burners.size():
		return
	if kitchen.is_busy(auto_burner):
		if kitchen.auto_ready(auto_burner):
			var r: Dictionary = kitchen.collect(auto_burner)
			if r.get("ok", false):
				deliver(str(r["menu"]), float(fx.get("auto_quality", 80.0)))
				changed.emit()
		return
	var menu_id := _auto_demand()
	if menu_id != "" and GameManager.economy.consume_stock(menu_id):
		kitchen.start(auto_burner, DataManager.get_menu(menu_id), cook_speed(), true)
		changed.emit()


## 아직 아무도 만들고 있지 않은 화구 요리 주문
func _auto_demand() -> String:
	var need := {}
	for o in orders:
		if str(DataManager.get_menu(o["menu"]).get("station", "")) == "grill":
			need[o["menu"]] = int(need.get(o["menu"], 0)) + 1
	for b in kitchen.burners:
		if b["menu"] != "" and need.has(b["menu"]):
			need[b["menu"]] = int(need[b["menu"]]) - 1
	for p in pass_items:
		if need.has(p["menu"]):
			need[p["menu"]] = int(need[p["menu"]]) - 1
	for o in orders:
		var m: String = o["menu"]
		if int(need.get(m, 0)) > 0 and GameManager.state.stock_of(m) > 0:
			return m
	return ""


func _auto_drink(delta: float) -> void:
	if float(fx.get("auto_drink", 0.0)) <= 0.0:
		return
	auto_drink_t += delta
	if auto_drink_t < 1.6:
		return
	auto_drink_t = 0.0
	for o in orders:
		var m: String = o["menu"]
		if str(DataManager.get_menu(m).get("station", "")) == "drink" and o["customer"].can_receive() and GameManager.state.stock_of(m) > 0:
			pour(m)
			return


## 메뉴별 미처리 주문 수 (주방 UI 표시용)
func pending_count(menu_id: String) -> int:
	var n := 0
	for o in orders:
		if o["menu"] == menu_id and is_instance_valid(o["customer"]) and o["customer"].can_receive():
			n += 1
	return n


## 영업 종료: 화구/접시에 남은 음식은 폐기 처리
func close() -> void:
	if not is_open:
		return
	is_open = false
	for m in kitchen.clear():
		GameManager.economy.record_waste(str(m), false)
	for p in pass_items:
		GameManager.economy.record_waste(str(p["menu"]), false)
	pass_items.clear()
	orders.clear()
	for i in seats.size():
		seats[i] = null
	waiting.clear()
	changed.emit()


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
