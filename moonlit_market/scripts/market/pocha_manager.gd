extends Node
## PochaManager — 내 포장마차 영업 (플레이어가 직접 요리하고 서빙한다).
##
## 흐름
##   손님 착석 → 주문 말풍선
##   [요리] 메뉴 버튼 → 화구 → 딱 좋을 때 탭 → 서빙대에 올라감 (서빙대가 가득이면 못 꺼냄)
##   [음료] 꾹 눌러 따르기 → 선에 맞추면 완벽 → 서빙대
##   [서빙] 손님 탭 → 사장님이 서빙대에서 쟁반에 담아 걸어가서 전달
##   [치우기] 손님이 떠난 테이블(빈 그릇 + 팁) 탭 → 치워야 다음 손님이 앉음
## 완벽한 서빙을 이어 가면 콤보 → 팁 보너스.

const KitchenScript := preload("res://scripts/market/kitchen.gd")
const MarketScript := preload("res://scripts/market/market_manager.gd")

signal changed
signal seats_changed
signal served(seat: int, menu_id: String, quality: float, price: int, pos: Vector2)
signal feedback(pos: Vector2, text: String, color: Color, size: int)
signal tip_collected(pos: Vector2, amount: int)

const SEAT_FREE := "free"
const SEAT_OCCUPIED := "occupied"
const SEAT_DIRTY := "dirty"

var market
var server
var kitchen = KitchenScript.new()
var rng := RandomNumberGenerator.new()
var seats: Array = [] ## 손님 또는 null
var seat_state: Array = [] ## {"state", "tip", "table": [menu ids]}
var waiting: Array = []
var orders: Array = [] ## 아직 나가지 않은 주문 {id, customer, menu, t}
var pass_items: Array = [] ## 서빙대 위 완성 음식 {menu, quality, age}
var next_order_id: int = 1
var fx: Dictionary = {}
var pair: Dictionary = {}
var auto_burner: int = -1
var auto_drink_t: float = 0.0
var auto_serve_t: float = 0.0
var elapsed: float = 0.0
var combo: int = 0
var best_combo: int = 0
var is_open: bool = false


func _ready() -> void:
	rng.randomize()
	kitchen.setup(2)


func level_def() -> Dictionary:
	return DataManager.get_pocha_level(GameManager.state.pocha_level())


func begin() -> void:
	var lv := level_def()
	seats = []
	seat_state = []
	for i in int(lv.get("seats", 3)):
		seats.append(null)
		seat_state.append({"state": SEAT_FREE, "tip": 0, "table": []})
	waiting = []
	orders = []
	pass_items = []
	elapsed = 0.0
	combo = 0
	best_combo = 0
	kitchen.setup(int(lv.get("burners", 2)), float(DataManager.pocha.get("too_early_ratio", 0.8)))
	fx = GameManager.staff.pocha_effects()
	pair = GameManager.synergy_cache.get("effects", {})
	auto_burner = kitchen.burners.size() - 1 if float(fx.get("auto_cook", 0.0)) > 0.0 else -1
	is_open = true
	if server:
		server.reset()
	seats_changed.emit()
	changed.emit()


func waiting_spots() -> int:
	return int(DataManager.pocha.get("waiting_spots", 3))


func pass_capacity() -> int:
	return int(DataManager.pocha.get("pass_capacity", 4))


func pass_space() -> int:
	return pass_capacity() - pass_items.size()


func free_seat() -> int:
	for i in seats.size():
		if (seats[i] == null or not is_instance_valid(seats[i])) and seat_state[i]["state"] == SEAT_FREE:
			seats[i] = null
			return i
	return -1


func choice_queue_len() -> int:
	return 0 if free_seat() >= 0 else waiting.size() + 1


func choice_queue_cap() -> int:
	return waiting_spots() + 1


func cook_speed() -> float:
	return 1.0 + float(fx.get("cook_speed", 0.0))


func seat_count() -> int:
	return seats.size()


# ───────── 손님 ─────────

func request_entry(c) -> bool:
	if not is_open:
		return false
	var s := free_seat()
	if s >= 0:
		_seat(c, s)
		return true
	if waiting.size() < waiting_spots():
		waiting.append(c)
		c.go_to_wait(waiting.size() - 1, market.wait_pos(waiting.size() - 1))
		return true
	return false


func _seat(c, s: int) -> void:
	seats[s] = c
	seat_state[s] = {"state": SEAT_OCCUPIED, "tip": 0, "table": []}
	c.go_to_seat(s, market.seat_pos(s, seats.size()))
	changed.emit()


func _promote_waiting() -> void:
	for c in waiting.duplicate():
		if not is_instance_valid(c):
			waiting.erase(c)
	while not waiting.is_empty():
		var s := free_seat()
		if s < 0:
			break
		_seat(waiting.pop_front(), s)
	for k in waiting.size():
		waiting[k].go_to_wait(k, market.wait_pos(k))


## prefs: 메뉴별 익힘 요청 ("" / "well" / "rare"), items 와 같은 순서
func place_order(c, items: Array, prefs: Array = []) -> void:
	for k in items.size():
		var pref: String = str(prefs[k]) if k < prefs.size() else ""
		orders.append({"id": next_order_id, "customer": c, "menu": str(items[k]), "pref": pref, "t": elapsed})
		next_order_id += 1
	changed.emit()


func is_drink_menu(menu_id: String) -> bool:
	return str(DataManager.get_menu(menu_id).get("station", "")) in ["drink", "mix"]


## 서빙대/쟁반 음식의 품질 (손님 요청 반영, 식은 만큼 감소)
func item_quality(item: Dictionary, pref: String = "") -> float:
	var q := float(item.get("quality", 80.0))
	if item.has("r"):
		var base: float = KitchenScript.quality_for_pref(float(item["r"]), float(item["pe"]), float(item["burn"]), pref, kitchen.too_early)
		if base < 0.0:
			base = 45.0
		q = base * float(item.get("flip_mul", 1.0)) - float(item.get("flip_sub", 0.0)) + float(item.get("bonus", 0.0))
	return clampf(q - float(item.get("decay", 0.0)), 30.0, 100.0)


func seat_of(c) -> int:
	return seats.find(c)


func orders_of(c) -> Array:
	var out: Array = []
	for o in orders:
		if o["customer"] == c:
			out.append(o)
	return out


## 손님이 떠남. dirty=true 면 테이블에 빈 그릇과 팁이 남는다 (치워야 다음 손님 착석)
func customer_left(c, tip: int = 0, dirty: bool = false) -> void:
	var s := seats.find(c)
	if s >= 0:
		seats[s] = null
		if dirty:
			seat_state[s] = {"state": SEAT_DIRTY, "tip": maxi(0, tip), "table": seat_state[s].get("table", [])}
		else:
			seat_state[s] = {"state": SEAT_FREE, "tip": 0, "table": []}
	if waiting.has(c):
		waiting.erase(c)
	for o in orders.duplicate():
		if o["customer"] == c:
			orders.erase(o)
	if server:
		server.forget_customer(c)
	_promote_waiting()
	changed.emit()


# ───────── 주방 ─────────

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


func _grill_pos(i: int) -> Vector2:
	return MarketScript.GRILL_POS + Vector2(-60 + 44 * i, 30)


## 화구 탭 → 서빙대로. 서빙대가 가득이면 꺼낼 수 없다.
func tap_burner(i: int) -> Dictionary:
	if i == auto_burner:
		return _fail("요리사가 맡은 화구예요")
	if i < 0 or i >= kitchen.burners.size() or not kitchen.is_busy(i):
		return _fail("비어 있는 화구예요")
	var st: String = kitchen.stage(i)
	if kitchen.needs_flip(i) and kitchen.ratio(i) < 1.0:
		var fr: Dictionary = kitchen.try_flip(i)
		match str(fr.get("result", "")):
			"early":
				feedback.emit(_grill_pos(i), "뒤집기엔 아직 일러요", Color("#FFF5E9"), 20)
				return {"ok": false, "too_early": true, "error": "뒤집기엔 아직 일러요"}
			"good":
				feedback.emit(_grill_pos(i), "뒤집기!", Color("#65C99A"), 22)
			"bad":
				feedback.emit(_grill_pos(i), "앗, 찢어졌어요", Color("#E97858"), 20)
		changed.emit()
		return {"ok": true, "flipped": true, "flip": fr.get("result", "")}
	if st == KitchenScript.STAGE_RAW:
		feedback.emit(_grill_pos(i), "아직 덜 익었어요", Color("#FFF5E9"), 20)
		return {"ok": false, "too_early": true, "error": "아직 덜 익었어요"}
	if st != KitchenScript.STAGE_BURNT and pass_space() <= 0:
		return _fail("서빙대가 가득 찼어요! 먼저 서빙하세요")
	var r: Dictionary = kitchen.collect(i)
	if r.get("burnt", false):
		GameManager.economy.record_waste(str(r["menu"]), true)
		combo = 0
		feedback.emit(_grill_pos(i), "탔어요!", Color("#E5564A"), 24)
		changed.emit()
		return r
	if r.get("flip_missed", false):
		feedback.emit(_grill_pos(i), "한쪽만 익었어요", Color("#E97858"), 20)
	elif r.get("stage", "") == "almost":
		feedback.emit(_grill_pos(i), "조금 덜 익음", Color("#FFD27A"), 20)
	elif r.get("stage", "") == "over":
		feedback.emit(_grill_pos(i), "조금 탐", Color("#E97858"), 20)
	_to_pass_cooked(r)
	changed.emit()
	return r


## 음료 따르기 시작: 재료 1개 사용. 서빙대 자리가 있어야 한다.
func pour_start(menu_id: String) -> Dictionary:
	if not is_open:
		return _fail("영업 중이 아닙니다.")
	if pass_space() <= 0:
		return _fail("서빙대가 가득 찼어요!")
	if not GameManager.economy.consume_stock(menu_id):
		return _fail("%s 재고가 없어요" % DataManager.get_menu(menu_id).get("name", ""))
	return {"ok": true}


## 음료 따르기 끝: level(0~1+) 로 품질 결정. 넘치면 버림.
func pour_finish(menu_id: String, level: float) -> Dictionary:
	var pc: Dictionary = DataManager.pocha.get("pour", {})
	var q: float = KitchenScript.pour_quality(level, float(pc.get("target_min", 0.78)), float(pc.get("target_max", 0.92)), float(pc.get("overflow", 1.0)))
	var pos := MarketScript.DRINK_POS + Vector2(0, 20)
	if q < 0.0:
		GameManager.economy.record_waste(menu_id, false)
		combo = 0
		feedback.emit(pos, "넘쳤어요!", Color("#E5564A"), 24)
		changed.emit()
		return {"ok": false, "spilled": true, "error": "넘쳤어요!"}
	if q >= 99.0:
		feedback.emit(pos, "딱 맞게!", Color("#65C99A"), 22)
	elif level < float(pc.get("target_min", 0.78)):
		feedback.emit(pos, "조금 모자라요", Color("#FFD27A"), 20)
	_to_pass(menu_id, q)
	changed.emit()
	return {"ok": true, "quality": q}


func _quality_with_bonus(menu_id: String, q: float) -> float:
	var sp: Dictionary = fx.get("special_menus", {})
	if sp.has(menu_id):
		q += float(sp[menu_id].get("quality_bonus", 0.0))
	return clampf(q, 0.0, 100.0)


func _to_pass(menu_id: String, quality: float) -> void:
	pass_items.append({"menu": menu_id, "quality": quality, "age": 0.0, "decay": 0.0})


func _to_pass_cooked(r: Dictionary) -> void:
	var menu_id := str(r["menu"])
	var bonus := 0.0
	var sp: Dictionary = fx.get("special_menus", {})
	if sp.has(menu_id):
		bonus = float(sp[menu_id].get("quality_bonus", 0.0))
	pass_items.append({"menu": menu_id, "quality": clampf(float(r["quality"]) + bonus, 0.0, 100.0), "age": 0.0, "decay": 0.0,
		"r": float(r["r"]), "pe": float(r["pe"]), "burn": float(r["burn"]),
		"flip_mul": float(r.get("flip_mul", 1.0)), "flip_sub": float(r.get("flip_sub", 0.0)), "bonus": bonus})


## 소맥: 소주 → 맥주 두 단계 따르기
func pour_finish_mix(menu_id: String, soju: float, beer: float) -> Dictionary:
	var mx: Dictionary = DataManager.get_menu(menu_id).get("mix", {})
	var pos := MarketScript.DRINK_POS + Vector2(0, 20)
	var smin := float(mx.get("soju_min", 0.22))
	var smax := float(mx.get("soju_max", 0.34))
	var q1: float = KitchenScript.pour_quality(soju / maxf(0.01, smax) * 0.92, smin / smax * 0.92, 0.92, 1.25)
	if q1 < 0.0:
		q1 = 45.0
	var q2: float = KitchenScript.pour_quality(beer, float(mx.get("beer_min", 0.8)), float(mx.get("beer_max", 0.93)), 1.0)
	if q2 < 0.0:
		GameManager.economy.record_waste(menu_id, false)
		combo = 0
		feedback.emit(pos, "넘쳤어요!", Color("#E5564A"), 24)
		changed.emit()
		return {"ok": false, "spilled": true, "error": "넘쳤어요!"}
	var q := (q1 + q2) / 2.0
	if q >= 99.0:
		feedback.emit(pos, "황금 비율!", Color("#65C99A"), 22)
	elif q1 < 90.0:
		feedback.emit(pos, "비율이 아쉬워요", Color("#FFD27A"), 20)
	_to_pass(menu_id, q)
	changed.emit()
	return {"ok": true, "quality": q}


## 이 손님의 아직 쟁반에 없는 주문들
func _open_orders_for(c, already: Array) -> Array:
	var list: Array = orders_of(c)
	var out: Array = []
	var held: Array = []
	for it in already:
		held.append(it["menu"])
	for o in list:
		if held.has(o["menu"]):
			held.erase(o["menu"])
			continue
		out.append(o)
	return out


## 서빙대에서 이 손님 주문에 가장 잘 맞는 음식을 꺼낸다 (최대 n개)
func pass_take_for(c, n: int, already: Array) -> Array:
	var taken: Array = []
	for o in _open_orders_for(c, already):
		if taken.size() >= n:
			break
		var best = null
		var best_q := -1.0
		for p in pass_items:
			if p["menu"] == o["menu"]:
				var q := item_quality(p, str(o.get("pref", "")))
				if q > best_q:
					best_q = q
					best = p
		if best != null:
			pass_items.erase(best)
			taken.append(best)
	if taken.size() > 0:
		changed.emit()
	return taken


func pass_has_for(c, already: Array) -> bool:
	for o in _open_orders_for(c, already):
		for p in pass_items:
			if p["menu"] == o["menu"]:
				return true
	return false


## 쟁반의 음식을 손님에게 전달 (요청에 가장 잘 맞는 주문에)
func serve_item(c, item: Dictionary) -> bool:
	var best = null
	var best_q := -1.0
	for o in orders:
		if o["customer"] == c and o["menu"] == item["menu"]:
			var q := item_quality(item, str(o.get("pref", "")))
			if q > best_q:
				best_q = q
				best = o
	if best == null:
		return false
	_serve(best, best_q)
	return true


func _serve(o: Dictionary, quality: float) -> void:
	orders.erase(o)
	var c = o["customer"]
	var menu_id: String = o["menu"]
	var price: int = GameManager.economy.unit_price(menu_id)
	if not GameManager.economy.record_sale(menu_id, price, quality):
		return
	if quality >= 99.0:
		combo += 1
		best_combo = maxi(best_combo, combo)
	else:
		combo = 0
	var s := seats.find(c)
	if s >= 0:
		(seat_state[s]["table"] as Array).append(menu_id)
	c.on_item_served(menu_id, quality, price)
	served.emit(s, menu_id, quality, price, c.position)
	changed.emit()


## 손님 / 테이블 탭
func tap_seat(i: int) -> Dictionary:
	if i < 0 or i >= seats.size():
		return _fail("")
	var st: Dictionary = seat_state[i]
	if st["state"] == SEAT_DIRTY:
		server.enqueue_clear(i)
		return {"ok": true, "action": "clear"}
	var c = seats[i]
	if c == null or not is_instance_valid(c):
		return _fail("빈 자리")
	if c.doze_t > 0.0:
		c.wake_up()
		feedback.emit(c.position + Vector2(0, -90), "일어나세요~", Color("#B9C4E8"), 18)
		return {"ok": true, "action": "wake"}
	if not c.can_receive():
		feedback.emit(c.position + Vector2(0, -90), "먹는 중" if c.state_name() == "EATING" else "아직 주문 전", Color("#B9B5B0"), 18)
		return _fail("")
	if not pass_has_for(c, server.tray) and not server.tray_has_for(c):
		feedback.emit(c.position + Vector2(0, -90), "서빙대에 음식이 없어요", Color("#FFD27A"), 18)
		return _fail("서빙대에 음식이 없어요")
	server.enqueue_serve(c)
	return {"ok": true, "action": "serve"}


## 테이블 치우기 → 팁 수령
func clear_seat(i: int) -> void:
	if i < 0 or i >= seat_state.size() or seat_state[i]["state"] != SEAT_DIRTY:
		return
	var tip := int(seat_state[i]["tip"])
	seat_state[i] = {"state": SEAT_FREE, "tip": 0, "table": []}
	if tip > 0:
		GameManager.economy.record_tip(tip)
		tip_collected.emit(market.seat_pos(i, seats.size()), tip)
	_promote_waiting()
	changed.emit()


func tick(delta: float) -> void:
	if not is_open:
		return
	elapsed += delta
	kitchen.tick(delta)
	var decay := float(DataManager.pocha.get("pass_decay_time", 22.0))
	for p in pass_items.duplicate():
		p["age"] = float(p["age"]) + delta
		p["decay"] = float(p.get("decay", 0.0)) + delta * 1.2
		if float(p["age"]) > decay:
			pass_items.erase(p)
			GameManager.economy.record_waste(str(p["menu"]), false)
			feedback.emit(MarketScript.PASS_POS + Vector2(0, 40), "식어서 버렸어요", Color("#E97858"), 18)
			changed.emit()
	if server:
		server.tick(delta)
	_auto_cook()
	_auto_drink(delta)
	_auto_serve(delta)


func _auto_cook() -> void:
	if auto_burner < 0 or auto_burner >= kitchen.burners.size():
		return
	if kitchen.is_busy(auto_burner):
		if kitchen.needs_flip(auto_burner):
			var f: Dictionary = kitchen.burners[auto_burner]["flip"]
			if kitchen.ratio(auto_burner) >= (float(f.get("good_min", 0.3)) + float(f.get("good_max", 0.9))) / 2.0:
				kitchen.try_flip(auto_burner)
		elif kitchen.auto_ready(auto_burner) and pass_space() > 0:
			var r: Dictionary = kitchen.collect(auto_burner)
			if r.get("ok", false):
				_to_pass(str(r["menu"]), _quality_with_bonus(str(r["menu"]), float(fx.get("auto_quality", 80.0))))
				changed.emit()
		return
	var menu_id := _unclaimed_demand("grill")
	if menu_id != "" and GameManager.economy.consume_stock(menu_id):
		kitchen.start(auto_burner, DataManager.get_menu(menu_id), cook_speed(), true)
		changed.emit()


## 아직 화구/서빙대/쟁반 어디에도 없는 주문 (station 별)
func _unclaimed_demand(station: String) -> String:
	var need := {}
	for o in orders:
		var st: String = str(DataManager.get_menu(o["menu"]).get("station", ""))
		if st == station or (station == "drink" and st == "mix"):
			need[o["menu"]] = int(need.get(o["menu"], 0)) + 1
	for b in kitchen.burners:
		if b["menu"] != "" and need.has(b["menu"]):
			need[b["menu"]] = int(need[b["menu"]]) - 1
	for p in pass_items:
		if need.has(p["menu"]):
			need[p["menu"]] = int(need[p["menu"]]) - 1
	if server:
		for it in server.tray:
			if need.has(it["menu"]):
				need[it["menu"]] = int(need[it["menu"]]) - 1
	for o in orders:
		var m: String = o["menu"]
		if int(need.get(m, 0)) > 0 and GameManager.state.stock_of(m) > 0:
			return m
	return ""


func _auto_drink(delta: float) -> void:
	if float(fx.get("auto_drink", 0.0)) <= 0.0:
		return
	auto_drink_t += delta
	if auto_drink_t < 1.8:
		return
	auto_drink_t = 0.0
	var m := _unclaimed_demand("drink")
	if m != "" and pass_space() > 0 and GameManager.economy.consume_stock(m):
		_to_pass(m, 90.0)
		changed.emit()


## 알바(재빠른 직원): 서빙대 음료를 손님에게 나르고, 빈 테이블을 치운다
func _auto_serve(delta: float) -> void:
	if float(fx.get("auto_serve", 0.0)) <= 0.0:
		return
	auto_serve_t += delta
	if auto_serve_t < 2.2:
		return
	auto_serve_t = 0.0
	for i in seat_state.size():
		if seat_state[i]["state"] == SEAT_DIRTY and not server.is_task_for_seat(i):
			clear_seat(i)
			return
	for p in pass_items:
		if not is_drink_menu(str(p["menu"])):
			continue
		for o in orders:
			if o["menu"] == p["menu"] and o["customer"].can_receive():
				pass_items.erase(p)
				_serve(o, item_quality(p, str(o.get("pref", ""))))
				return


func pending_count(menu_id: String) -> int:
	var n := 0
	for o in orders:
		if o["menu"] == menu_id and is_instance_valid(o["customer"]) and o["customer"].can_receive():
			n += 1
	return n


func dirty_count() -> int:
	var n := 0
	for st in seat_state:
		if st["state"] == SEAT_DIRTY:
			n += 1
	return n


## 영업 종료: 남은 팁은 자동 수령, 화구/서빙대/쟁반 음식은 폐기
func close() -> void:
	if not is_open:
		return
	for i in seat_state.size():
		if seat_state[i]["state"] == SEAT_DIRTY:
			clear_seat(i)
	is_open = false
	for m in kitchen.clear():
		GameManager.economy.record_waste(str(m), false)
	for p in pass_items:
		GameManager.economy.record_waste(str(p["menu"]), false)
	pass_items.clear()
	if server:
		for it in server.tray:
			GameManager.economy.record_waste(str(it["menu"]), false)
		server.reset()
	orders.clear()
	for i in seats.size():
		seats[i] = null
		seat_state[i] = {"state": SEAT_FREE, "tip": 0, "table": []}
	waiting.clear()
	changed.emit()


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
