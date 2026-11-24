extends Node
## CustomerManager — 손님 생성(스폰), 내 포차 vs 경쟁 노점 선택, 포차 주문/추가 주문/만족도/팁 계산.

const CustomerScene := preload("res://scenes/customer/customer.tscn")
const CustomerAI := preload("res://scripts/customer/customer_ai.gd")
const MarketScript := preload("res://scripts/market/market_manager.gd")

signal customer_spawned(customer)
signal walkout_feedback(world_pos: Vector2)

var market
var rival_manager
var pocha_manager
var world: Node2D
var customers: Array = []
var market_mods: Dictionary = {}
var event_mods: Dictionary = {}
var spawning: bool = false
var spawn_timer: float = 0.0
var next_uid: int = 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func begin(p_market_mods: Dictionary) -> void:
	market_mods = p_market_mods
	event_mods = {}
	spawning = true
	spawn_timer = 0.5


func stop_spawning() -> void:
	spawning = false


func active_count() -> int:
	return customers.size()


func spawn_interval() -> float:
	var base := float(DataManager.bal("spawn_interval", 2.6))
	var mult := float(market_mods.get("visitor_mult", 1.0)) * float(event_mods.get("spawn_mult", 1.0))
	return base / maxf(0.2, mult)


func tick(delta: float) -> void:
	if spawning:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval() * rng.randf_range(0.7, 1.3)
			if customers.size() < int(DataManager.bal("max_customers", 30)):
				spawn_customer()
	for c in customers.duplicate():
		if is_instance_valid(c):
			c.tick(delta)


func spawn_customer(type_id: String = ""):
	if type_id == "":
		var tourist_mult := float(market_mods.get("tourist_mult", 1.0)) * float(event_mods.get("tourist_mult", 1.0))
		type_id = CustomerAI.pick_type(DataManager.customers, tourist_mult, rng, float(event_mods.get("office_mult", 1.0)))
	if type_id == "":
		return null
	var c = CustomerScene.instantiate()
	world.add_child(c)
	c.setup(self, next_uid, type_id, rng, market.spawn_point(rng))
	next_uid += 1
	customers.append(c)
	GameManager.economy.record_visit()
	customer_spawned.emit(c)
	return c


func choice_context(c) -> Dictionary:
	return {
		"price_ratio": 1.0, "price_tolerance": float(event_mods.get("price_tolerance", 0.0)),
		"stall_rep": 10.0, "market_rep": float(GameManager.state.reputation),
		"queue_len": 0, "queue_cap": 4, "distance": 0.0,
		"weather": DataManager.get_weather(GameManager.state.today_weather),
		"trend_menu": str(event_mods.get("trend_menu", "")),
		"trend_mult": float(event_mods.get("trend_mult", 1.0)),
		"appeal": 0.0, "budget": c.budget, "sold_out": false, "visited": false,
	}


## 내 포차 손님이 고를 수 있는 메뉴 (재고 있음). station: "grill" / "drink"
func pocha_menus(station: String) -> Array:
	var out: Array = []
	for id in GameManager.state.enabled_menus():
		var m: Dictionary = DataManager.get_menu(id).duplicate()
		if str(m.get("station", "")) != station or GameManager.state.stock_of(id) <= 0:
			continue
		m["id"] = id
		m["_ratio"] = float(GameManager.state.menu_entry(id).get("price_ratio", 1.0))
		out.append(m)
	return out


## 내 포차 점수: 메뉴 중 가장 끌리는 것 기준 + 앉아서 먹는 포차 분위기 보너스
func pocha_score(c) -> float:
	if not pocha_manager.is_open:
		return 0.0
	var best := 0.0
	var fx: Dictionary = pocha_manager.fx
	var sp: Dictionary = fx.get("special_menus", {})
	for m in pocha_menus("grill") + pocha_menus("drink"):
		var ctx := choice_context(c)
		ctx["price_ratio"] = float(m["_ratio"])
		ctx["price_tolerance"] = float(ctx["price_tolerance"]) + float(fx.get("price_tolerance", 0.0))
		ctx["stall_rep"] = float(GameManager.state.pocha.get("rep", 10.0))
		ctx["queue_len"] = pocha_manager.choice_queue_len()
		ctx["queue_cap"] = pocha_manager.choice_queue_cap()
		ctx["distance"] = c.position.distance_to(MarketScript.POCHA_POS)
		ctx["appeal"] = float(DataManager.get_pocha_level(GameManager.state.pocha_level()).get("appeal", 0.0)) \
			+ float(sp.get(m["id"], {}).get("attraction", 0.0))
		var s := CustomerAI.stall_score(c.ctype, m, ctx)
		if str(m.get("station", "")) == "drink":
			s *= 0.6 # 음료만 보고 들어오는 손님은 적다
		best = maxf(best, s)
	return best * 1.7 # 앉아서 먹는 포차 분위기 + 플레이어 가게 존재감


func rival_score(c, id: String) -> float:
	var ctx := choice_context(c)
	var menu_id: String = rival_manager.best_menu_for(id, c, ctx)
	ctx["price_ratio"] = rival_manager.price_ratio(id, event_mods)
	ctx["stall_rep"] = rival_manager.reputation(id)
	ctx["queue_len"] = rival_manager.queue_len(id)
	ctx["queue_cap"] = rival_manager.queue_capacity(id)
	ctx["distance"] = c.position.distance_to(market.rival_queue_spot(id, 0))
	return CustomerAI.stall_score(c.ctype, DataManager.get_menu(menu_id), ctx)


## 반환: "pocha" / 경쟁 노점 id / "" (아무것도 안 삼)
func choose_target(c) -> String:
	var candidates: Array = []
	var ps := pocha_score(c)
	if ps > 0.0:
		candidates.append({"slot": 0, "score": ps})
	var ids: Array = rival_manager.runtime.keys()
	for i in ids.size():
		var s := rival_score(c, ids[i])
		if s > 0.0:
			candidates.append({"slot": i + 1, "score": s})
	var pick := CustomerAI.choose(candidates, float(DataManager.bal("no_choice_weight", 0.35)), rng)
	if pick < 0:
		return ""
	if pick == 0:
		return "pocha"
	return str(ids[pick - 1])


func _pair_fx() -> Dictionary:
	return pocha_manager.pair


func pick_pocha_order(c, reorder: bool) -> Array:
	var ctx := choice_context(c)
	ctx["price_tolerance"] = float(ctx["price_tolerance"]) + float(pocha_manager.fx.get("price_tolerance", 0.0))
	var foods := pocha_menus("grill")
	var drinks := pocha_menus("drink")
	var fx := _pair_fx()
	var drink_bonus := float(fx.get("drink_chance", 0.0))
	var items: Array
	if reorder:
		# 추가 주문은 술/음료 위주, 가끔 안주
		if drinks.size() > 0 and rng.randf() < 0.65:
			items = CustomerAI.pick_order(c.ctype, [], drinks, ctx, 1.0, rng)
		else:
			items = CustomerAI.pick_order(c.ctype, foods, [], ctx, 0.0, rng)
	else:
		items = CustomerAI.pick_order(c.ctype, foods, drinks, ctx, drink_bonus, rng)
	# 예산 확인
	var total := 0
	var out: Array = []
	for m in items:
		var p: int = GameManager.economy.unit_price(m)
		if total + p <= c.budget:
			out.append(m)
			total += p
	return out


func wants_reorder(c) -> bool:
	if c.rounds >= 3:
		return false
	var cheapest := 99999
	for id in GameManager.state.enabled_menus():
		if GameManager.state.stock_of(id) > 0:
			cheapest = mini(cheapest, GameManager.economy.unit_price(id))
	if c.budget < cheapest:
		return false
	var chance := float(c.ctype.get("reorder_chance", 0.2)) + float(_pair_fx().get("reorder_chance", 0.0)) \
		+ float(pocha_manager.fx.get("reorder_chance", 0.0))
	chance *= clampf(c.avg_quality() / 85.0, 0.4, 1.2)
	return rng.randf() < chance


func pocha_satisfaction(c) -> float:
	var ctx := choice_context(c)
	var pref := 1.0
	var ratio := 1.0
	if c.served_items.size() > 0:
		var first: String = c.served_items[0]["menu"]
		pref = CustomerAI.preference(c.ctype, DataManager.get_menu(first), ctx)
		var rs := 0.0
		for it in c.served_items:
			rs += float(GameManager.state.menu_entry(it["menu"]).get("price_ratio", 1.0))
		ratio = rs / c.served_items.size()
	var fx := _pair_fx()
	var bonus := float(pocha_manager.fx.get("satisfaction", 0.0)) + float(fx.get("satisfaction", 0.0)) \
		+ float(market_mods.get("satisfaction", 0.0)) + float(event_mods.get("satisfaction", 0.0))
	if c.type_id in ["family", "student"]:
		bonus += float(fx.get("satisfaction_family", 0.0))
	return CustomerAI.pocha_satisfaction(c.ctype, c.avg_quality(), pref, ratio, c.total_wait / maxf(1.0, c.rounds), bonus,
		float(DataManager.bal("satisfaction_base", 68.0)), float(DataManager.bal("satisfaction_wait_penalty", 0.9)))


func tip_for(c, sat: float) -> int:
	var threshold := float(DataManager.bal("tip_threshold", 80.0))
	var q: float = c.avg_quality()
	if q < threshold or sat < 70.0:
		return 0
	var k := clampf((q - threshold) / maxf(1.0, 100.0 - threshold), 0.0, 1.0)
	return int(round(c.spent * float(DataManager.bal("tip_rate", 0.25)) * k * (1.0 + float(_pair_fx().get("tip_mult", 0.0)))))


func on_tip_feedback(c, tip: int) -> void:
	market.spawn_float_text(c.position + Vector2(0, -96), "팁 +%d" % tip, Color("#65C99A"), 22)


func on_walkout_feedback(c) -> void:
	walkout_feedback.emit(c.position)


func on_customer_finished(c) -> void:
	customers.erase(c)
	if is_instance_valid(c):
		c.queue_free()


## 영업 마감: 남은 손님 모두 퇴장
func dismiss_all() -> void:
	for c in customers:
		if is_instance_valid(c):
			c.force_leave()


func clear_immediately() -> void:
	for c in customers:
		if is_instance_valid(c):
			c.queue_free()
	customers.clear()
