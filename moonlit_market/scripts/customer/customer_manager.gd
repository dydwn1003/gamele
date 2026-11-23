extends Node
## CustomerManager — 손님 생성(스폰), 노점 선택 계산, 피드백 연출 연결, 정리.

const CustomerScene := preload("res://scenes/customer/customer.tscn")
const CustomerAI := preload("res://scripts/customer/customer_ai.gd")

signal customer_spawned(customer)
signal purchase_feedback(slot_idx: int, price: int, satisfaction: float, world_pos: Vector2)
signal walkout_feedback(world_pos: Vector2)

var market ## market_manager
var stall_manager
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
	var base := float(DataManager.bal("spawn_interval", 2.4))
	var mult := float(market_mods.get("visitor_mult", 1.0)) * float(event_mods.get("spawn_mult", 1.0))
	return base / maxf(0.2, mult)


func tick(delta: float) -> void:
	if spawning:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval() * rng.randf_range(0.7, 1.3)
			if customers.size() < int(DataManager.bal("max_customers", 34)):
				spawn_customer()
	for c in customers.duplicate():
		if is_instance_valid(c):
			c.tick(delta)


func spawn_customer(type_id: String = ""):
	if type_id == "":
		var tourist_mult := float(market_mods.get("tourist_mult", 1.0)) * float(event_mods.get("tourist_mult", 1.0))
		type_id = CustomerAI.pick_type(DataManager.customers, tourist_mult, rng)
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


## 노점 선택을 위한 상황 정보
func choice_context(c, slot: int) -> Dictionary:
	var s: Dictionary = GameManager.state.get_slot(slot)
	var mods: Dictionary = GameManager.slot_modifiers(slot)
	return {
		"price_ratio": float(s.get("price_ratio", 1.0)),
		"price_tolerance": float(mods.get("price_tolerance", 0.0)) + float(event_mods.get("price_tolerance", 0.0)),
		"stall_rep": float(s.get("rep", 10.0)),
		"market_rep": float(GameManager.state.reputation),
		"queue_len": stall_manager.queue_len(slot),
		"queue_cap": stall_manager.queue_capacity(slot),
		"distance": c.position.distance_to(market.queue_spot(slot, 0)),
		"weather": DataManager.get_weather(GameManager.state.today_weather),
		"trend_menu": str(event_mods.get("trend_menu", "")),
		"trend_mult": float(event_mods.get("trend_mult", 1.0)),
		"appeal": float(mods.get("appeal", 0.0)),
		"budget": c.budget,
		"sold_out": stall_manager.is_sold_out(slot),
		"visited": c.visited_slots.has(slot),
	}


func choose_stall(c) -> int:
	var candidates: Array = []
	for i in GameManager.state.slots.size():
		if not GameManager.state.is_stall(i):
			continue
		var menu: Dictionary = GameManager.economy.menu_for_slot(i)
		var score := CustomerAI.stall_score(c.ctype, menu, choice_context(c, i))
		if score > 0.0:
			candidates.append({"slot": i, "score": score})
	var no_choice := float(DataManager.bal("no_choice_weight", 0.35))
	if c.purchases > 0:
		no_choice *= 1.5
	return CustomerAI.choose(candidates, no_choice, rng)


func on_purchase_feedback(c, slot: int, price: int, sat: float) -> void:
	purchase_feedback.emit(slot, price, sat, c.position)


func on_walkout_feedback(c) -> void:
	walkout_feedback.emit(c.position)


func on_synergy_follow(_c, _from_slot: int, _to_slot: int) -> void:
	pass # 시각 효과는 노점 시너지 배지로 표현 (TODO: 연계 이동 시 전용 이펙트)


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
