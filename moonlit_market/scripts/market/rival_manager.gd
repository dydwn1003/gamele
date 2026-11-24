extends Node
## RivalManager — 주변 경쟁 노점 시뮬레이션 (플레이어가 조작할 수 없음).
## 각 노점은 대기열과 고정된 서비스 시간으로 손님을 받고, 판매 기록은 경쟁 순위에 쓰인다.
## 시장 단계가 오를수록 라이벌의 품질·평판이 성장한다 (rivals.json growth).

const CustomerAI := preload("res://scripts/customer/customer_ai.gd")

signal rival_sale(rival_id: String, price: int)

var market
var runtime: Dictionary = {} ## rival_id -> {queue, serving, t, total}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func reset_runtime() -> void:
	runtime = {}
	for id in market.rival_ids():
		runtime[id] = {"queue": [], "serving": null, "t": 0.0, "total": 1.0}


func def_of(id: String) -> Dictionary:
	return DataManager.get_rival(id)


## 시장 단계 성장을 반영한 품질 (0~100)
func quality(id: String) -> float:
	var d := def_of(id)
	var g: Dictionary = d.get("growth", {})
	return clampf(float(d.get("quality", 70)) + float(g.get("quality", 0)) * (GameManager.state.market_level - 1), 0.0, 100.0)


func reputation(id: String) -> float:
	var d := def_of(id)
	var base := float(d.get("reputation", 20))
	if GameManager.state.rivals.has(id):
		base = float(GameManager.state.rivals[id].get("rep", base))
	var g: Dictionary = d.get("growth", {})
	return clampf(base + float(g.get("reputation", 0)) * (GameManager.state.market_level - 1), 0.0, 100.0)


func price_ratio(id: String, event_mods: Dictionary) -> float:
	return float(def_of(id).get("price_ratio", 1.0)) * float(event_mods.get("rival_price_mult", 1.0))


func price_of(id: String, menu_id: String, event_mods: Dictionary) -> int:
	return maxi(1, int(round(float(DataManager.get_menu(menu_id).get("price", 100)) * price_ratio(id, event_mods))))


func queue_len(id: String) -> int:
	return (runtime[id]["queue"] as Array).size() if runtime.has(id) else 0


func queue_capacity(id: String) -> int:
	return int(def_of(id).get("queue_capacity", 4))


## 이 손님이 고를 메뉴 (노점 메뉴 중 가장 끌리는 것)
func best_menu_for(id: String, c, ctx: Dictionary) -> String:
	var best := ""
	var best_score := -1.0
	for m in def_of(id).get("menus", []):
		var s := CustomerAI.preference(c.ctype, DataManager.get_menu(m), ctx)
		if s > best_score:
			best_score = s
			best = str(m)
	return best


func enqueue(id: String, c) -> int:
	if not runtime.has(id):
		return -1
	var q: Array = runtime[id]["queue"]
	if q.size() >= queue_capacity(id):
		return -1
	q.append(c)
	_reflow(id)
	return q.size() - 1


func remove_customer(id: String, c) -> void:
	if not runtime.has(id):
		return
	var rt: Dictionary = runtime[id]
	(rt["queue"] as Array).erase(c)
	if rt["serving"] == c:
		rt["serving"] = null
	_reflow(id)


func _reflow(id: String) -> void:
	var q: Array = runtime[id]["queue"]
	for k in q.size():
		if is_instance_valid(q[k]):
			q[k].set_queue_slot(k, market.rival_queue_spot(id, k))


func tick(delta: float, event_mods: Dictionary) -> void:
	for id in runtime.keys():
		var rt: Dictionary = runtime[id]
		var q: Array = rt["queue"]
		for c in q.duplicate():
			if not is_instance_valid(c):
				q.erase(c)
		if rt["serving"] != null:
			if not is_instance_valid(rt["serving"]):
				rt["serving"] = null
				continue
			rt["t"] = float(rt["t"]) + delta
			if float(rt["t"]) >= float(rt["total"]):
				_complete(id, event_mods)
			continue
		if q.is_empty():
			continue
		var front = q[0]
		if front.is_ready_at_counter():
			var ratio := price_ratio(id, event_mods)
			var p := CustomerAI.purchase_probability(front.ctype, ratio, float(event_mods.get("price_tolerance", 0.0)), 1.0,
				float(DataManager.bal("purchase_base_chance", 0.97)), float(DataManager.bal("purchase_price_penalty", 1.3)))
			var price := price_of(id, front.rival_menu, event_mods)
			if front.budget < price:
				p = 0.0
			if rng.randf() > p:
				remove_customer(id, front)
				front.on_rejected_price()
				continue
			rt["serving"] = front
			rt["t"] = 0.0
			rt["total"] = float(def_of(id).get("service_time", 5.0)) * rng.randf_range(0.85, 1.15)
			front.begin_serving()


func _complete(id: String, event_mods: Dictionary) -> void:
	var rt: Dictionary = runtime[id]
	var c = rt["serving"]
	rt["serving"] = null
	(rt["queue"] as Array).erase(c)
	_reflow(id)
	if c == null or not is_instance_valid(c):
		return
	var price := price_of(id, c.rival_menu, event_mods)
	GameManager.economy.record_rival_sale(id, price)
	rival_sale.emit(id, price)
	c.on_rival_purchase(id, price, quality(id))


func is_serving(id: String) -> bool:
	return runtime.has(id) and runtime[id]["serving"] != null


func serve_progress(id: String) -> float:
	if not is_serving(id):
		return 0.0
	return clampf(float(runtime[id]["t"]) / maxf(0.01, float(runtime[id]["total"])), 0.0, 1.0)


func clear_all() -> void:
	for id in runtime.keys():
		runtime[id]["queue"] = []
		runtime[id]["serving"] = null
