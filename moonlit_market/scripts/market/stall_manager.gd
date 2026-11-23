extends Node
## StallManager — 영업 중 노점 런타임(대기열, 조리, 판매) 처리.
## 영구 상태(재고/레벨/가격)는 GameState 에 있고, 판매 기록은 EconomyManager 가 한다.

const CustomerAI := preload("res://scripts/customer/customer_ai.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")

signal sale_made(slot_idx: int, price: int, satisfaction: float)

var market ## market_manager
var runtime: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	reset_runtime()


func reset_runtime() -> void:
	runtime = []
	for i in GameStateScript.SLOT_COUNT:
		runtime.append({"queue": [], "cooking": false, "cook_t": 0.0, "cook_total": 1.0, "serving": null, "sold_out": false})


func get_runtime(i: int) -> Dictionary:
	if i < 0 or i >= runtime.size():
		return {}
	return runtime[i]


func queue_capacity(i: int) -> int:
	var s: Dictionary = GameManager.state.get_slot(i)
	return int(DataManager.get_stall(str(s.get("type", ""))).get("queue_capacity", 4))


func queue_len(i: int) -> int:
	return (runtime[i]["queue"] as Array).size() if i >= 0 and i < runtime.size() else 0


func is_sold_out(i: int) -> bool:
	return int(GameManager.state.get_slot(i).get("stock", 0)) <= 0


## 대기열 등록. 반환: 대기 순번 (가득 찼으면 -1)
func enqueue(i: int, customer) -> int:
	if not GameManager.state.is_stall(i) or is_sold_out(i):
		return -1
	var q: Array = runtime[i]["queue"]
	if q.size() >= queue_capacity(i):
		return -1
	q.append(customer)
	_reflow(i)
	return q.size() - 1


func remove_customer(i: int, customer) -> void:
	if i < 0 or i >= runtime.size():
		return
	var rt: Dictionary = runtime[i]
	var q: Array = rt["queue"]
	var idx := q.find(customer)
	if idx < 0:
		return
	q.remove_at(idx)
	if rt["serving"] == customer:
		rt["serving"] = null
		rt["cooking"] = false
	_reflow(i)


func _reflow(i: int) -> void:
	var q: Array = runtime[i]["queue"]
	for k in q.size():
		var c = q[k]
		if is_instance_valid(c):
			c.set_queue_slot(k, market.queue_spot(i, k))


func tick(delta: float, event_mods: Dictionary) -> void:
	for i in runtime.size():
		if not GameManager.state.is_stall(i):
			continue
		var rt: Dictionary = runtime[i]
		var q: Array = rt["queue"]
		# 유효하지 않은 손님 정리
		for c in q.duplicate():
			if not is_instance_valid(c):
				q.erase(c)
		if rt["cooking"]:
			rt["cook_t"] = float(rt["cook_t"]) + delta
			if float(rt["cook_t"]) >= float(rt["cook_total"]):
				_complete(i)
			continue
		if q.is_empty():
			continue
		if is_sold_out(i):
			_handle_sold_out(i)
			continue
		var front = q[0]
		if front.is_ready_at_counter():
			_try_start(i, front, event_mods)
	_update_sold_out_flags()


func _try_start(i: int, customer, event_mods: Dictionary) -> void:
	var mods: Dictionary = GameManager.slot_modifiers(i)
	var s: Dictionary = GameManager.state.get_slot(i)
	var ratio := float(s.get("price_ratio", 1.0))
	var tol := float(mods.get("price_tolerance", 0.0)) + float(event_mods.get("price_tolerance", 0.0))
	var p := CustomerAI.purchase_probability(customer.ctype, ratio, tol, float(mods.get("sales_efficiency", 1.0)),
		float(DataManager.bal("purchase_base_chance", 0.97)), float(DataManager.bal("purchase_price_penalty", 1.3)))
	if customer.budget < GameManager.economy.unit_price(i):
		p = 0.0
	if rng.randf() > p:
		remove_customer(i, customer)
		customer.on_rejected_price()
		return
	var menu: Dictionary = GameManager.economy.menu_for_slot(i)
	var rt: Dictionary = runtime[i]
	rt["cooking"] = true
	rt["cook_t"] = 0.0
	rt["cook_total"] = maxf(0.5, float(menu.get("cook_time", 6.0)) / maxf(0.1, float(mods.get("cook_speed", 1.0))))
	rt["serving"] = customer
	customer.begin_serving()


func _complete(i: int) -> void:
	var rt: Dictionary = runtime[i]
	var customer = rt["serving"]
	rt["cooking"] = false
	rt["serving"] = null
	var q: Array = rt["queue"]
	if customer != null and q.has(customer):
		q.erase(customer)
	_reflow(i)
	if customer == null or not is_instance_valid(customer):
		return
	var price: int = GameManager.economy.unit_price(i)
	var sat: float = customer.compute_satisfaction(i)
	if GameManager.economy.record_sale(i, price, sat):
		sale_made.emit(i, price, sat)
		customer.on_purchased(i, price, sat)
	else:
		customer.on_sold_out()


func _handle_sold_out(i: int) -> void:
	var rt: Dictionary = runtime[i]
	var q: Array = rt["queue"]
	var waiting := q.duplicate()
	q.clear()
	for c in waiting:
		if is_instance_valid(c):
			c.on_sold_out()


func _update_sold_out_flags() -> void:
	for i in runtime.size():
		runtime[i]["sold_out"] = GameManager.state.is_stall(i) and is_sold_out(i)


## 영업 종료 시 대기열 정리
func clear_all() -> void:
	for rt in runtime:
		rt["queue"] = []
		rt["cooking"] = false
		rt["serving"] = null
		rt["cook_t"] = 0.0
