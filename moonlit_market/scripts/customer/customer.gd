extends Node2D
## Customer — 시장에 실제로 입장해 노점을 고르고, 줄을 서고, 구매하고, 퇴장하는 손님.
## 상태: ENTERING → BROWSING → SELECTING(노점까지 이동) → QUEUING → SERVING → LEAVING
## 고정 경로(입구 → 중앙 통로 → 노점 대기 지점 → 출구)만 사용한다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")
const CustomerAI := preload("res://scripts/customer/customer_ai.gd")
const MarketScript := preload("res://scripts/market/market_manager.gd")

enum State { ENTERING, BROWSING, SELECTING, QUEUING, SERVING, LEAVING }
const STATE_NAMES := ["ENTERING", "BROWSING", "SELECTING", "QUEUING", "SERVING", "LEAVING"]

var manager ## customer_manager
var uid: int = 0
var type_id: String = ""
var ctype: Dictionary = {}
var display_name: String = ""
var purpose: String = ""
var budget: float = 200.0
var spend_tendency: float = 0.6
var patience_max: float = 30.0
var patience_left: float = 30.0
var speed: float = 110.0
var satisfaction: float = 60.0
var favorite_category: String = ""

var state: int = State.ENTERING
var waypoints: Array = []
var target_slot: int = -1
var queue_index: int = -1
var arrived: bool = false
var wait_time: float = 0.0
var purchases: int = 0
var spent: int = 0
var visited_slots: Array = []
var reselect_count: int = 0
var exit_counted: bool = false
var done: bool = false

var browse_timer: float = 0.0
var reaction: String = ""
var reaction_timer: float = 0.0
var anim_t: float = 0.0
var moving: bool = false
var fade: float = 0.0
var lane_offset: float = 0.0
var rng: RandomNumberGenerator


func setup(p_manager, p_uid: int, p_type_id: String, p_rng: RandomNumberGenerator, spawn: Vector2) -> void:
	manager = p_manager
	uid = p_uid
	type_id = p_type_id
	rng = p_rng
	ctype = DataManager.get_customer_type(type_id).duplicate(true)
	ctype["id"] = type_id
	var names: Array = ctype.get("names", ["손님"])
	display_name = str(names[rng.randi() % names.size()]) if names.size() > 0 else "손님"
	var purposes: Array = ctype.get("purposes", ["구경"])
	purpose = str(purposes[rng.randi() % purposes.size()]) if purposes.size() > 0 else "구경"
	budget = rng.randf_range(float(ctype.get("budget_min", 100)), float(ctype.get("budget_max", 300)))
	spend_tendency = float(ctype.get("spend_tendency", 0.6))
	patience_max = float(ctype.get("patience", 30.0)) * rng.randf_range(0.85, 1.15)
	patience_left = patience_max
	speed = float(ctype.get("speed", 110.0)) * rng.randf_range(0.9, 1.1)
	# 가장 좋아하는 카테고리 (말풍선 표시용)
	var best := 0.0
	var prefs: Dictionary = ctype.get("category_pref", {})
	for k in prefs.keys():
		if float(prefs[k]) > best:
			best = float(prefs[k])
			favorite_category = str(k)
	lane_offset = rng.randf_range(-12.0, 12.0)
	position = spawn
	anim_t = rng.randf() * 10.0
	var browse: Vector2 = manager.market.browse_point(rng)
	waypoints = [Vector2(MarketScript.LANE_IN_X + lane_offset, spawn.y - 40), browse]
	state = State.ENTERING


func state_name() -> String:
	return STATE_NAMES[state]


func tick(delta: float) -> void:
	anim_t += delta
	if reaction_timer > 0.0:
		reaction_timer -= delta
	if state != State.LEAVING:
		fade = minf(1.0, fade + delta * 3.0)
	_move(delta)
	match state:
		State.BROWSING:
			browse_timer -= delta
			if browse_timer <= 0.0:
				_select()
		State.QUEUING:
			if arrived:
				wait_time += delta
				patience_left -= delta / maxf(0.1, _patience_mult())
				if patience_left <= 0.0:
					_give_up()
		State.LEAVING:
			if waypoints.is_empty():
				fade -= delta * 2.5
				if fade <= 0.0 and not done:
					done = true
					manager.on_customer_finished(self)
	modulate.a = clampf(fade, 0.0, 1.0)
	queue_redraw()


func _patience_mult() -> float:
	var m := float(manager.market_mods.get("patience_mult", 1.0)) * float(manager.market_mods.get("stay_mult", 1.0))
	if target_slot >= 0:
		m *= float(GameManager.slot_modifiers(target_slot).get("patience_mult", 1.0))
	return m


func _move(delta: float) -> void:
	moving = false
	if waypoints.is_empty():
		return
	var target: Vector2 = waypoints[0]
	var step := speed * delta
	var to := target - position
	if to.length() <= step:
		position = target
		waypoints.pop_front()
		if waypoints.is_empty():
			_on_arrive()
	else:
		position += to.normalized() * step
		moving = true


func _on_arrive() -> void:
	match state:
		State.ENTERING:
			state = State.BROWSING
			browse_timer = rng.randf_range(float(DataManager.bal("browse_time_min", 0.6)), float(DataManager.bal("browse_time_max", 1.8)))
			browse_timer *= float(manager.market_mods.get("stay_mult", 1.0))
		State.SELECTING:
			state = State.QUEUING
			arrived = true
		State.QUEUING:
			arrived = true


func _select() -> void:
	state = State.SELECTING
	var slot: int = manager.choose_stall(self)
	if slot < 0:
		_leave("no_choice")
		return
	var idx: int = manager.stall_manager.enqueue(slot, self)
	if idx < 0:
		_leave("queue_full")
		return
	target_slot = slot
	wait_time = 0.0
	patience_left = patience_max


## StallManager 가 대기 순번이 바뀔 때마다 호출
func set_queue_slot(k: int, spot: Vector2) -> void:
	queue_index = k
	if state == State.SELECTING:
		# 통로를 따라 이동 후 대기 지점으로
		var lane_x: float = MarketScript.LANE_IN_X + lane_offset
		waypoints = [Vector2(lane_x, position.y), Vector2(lane_x, spot.y), spot]
		if absf(position.x - lane_x) < 4.0:
			waypoints.pop_front()
		arrived = false
	elif state == State.QUEUING:
		waypoints = [spot]
		arrived = false


func is_ready_at_counter() -> bool:
	return state == State.QUEUING and arrived and queue_index == 0 and waypoints.is_empty()


func begin_serving() -> void:
	state = State.SERVING


func compute_satisfaction(slot: int) -> float:
	var menu: Dictionary = GameManager.economy.menu_for_slot(slot)
	var s: Dictionary = GameManager.state.get_slot(slot)
	var ctx: Dictionary = manager.choice_context(self, slot)
	var pref := CustomerAI.preference(ctype, menu, ctx)
	var mods: Dictionary = GameManager.slot_modifiers(slot)
	var bonus := float(mods.get("satisfaction", 0.0)) + float(manager.market_mods.get("satisfaction", 0.0)) + float(manager.event_mods.get("satisfaction", 0.0))
	return CustomerAI.satisfaction(ctype, pref, float(s.get("price_ratio", 1.0)), wait_time, bonus,
		float(DataManager.bal("satisfaction_base", 68.0)), float(DataManager.bal("satisfaction_wait_penalty", 0.9)))


func on_purchased(slot: int, price: int, sat: float) -> void:
	purchases += 1
	spent += price
	budget -= price
	if purchases == 1:
		GameManager.economy.record_buyer()
		satisfaction = sat
	else:
		satisfaction = (satisfaction * (purchases - 1) + sat) / purchases
	visited_slots.append(slot)
	_react("heart" if sat >= 70.0 else ("smile" if sat >= 45.0 else "meh"))
	manager.on_purchase_feedback(self, slot, price, sat)
	target_slot = -1
	queue_index = -1
	# 추가 구매: 시너지 연계(예: 꼬치 → 옆 음료) 우선, 그다음 일반 추가 구매
	var mods: Dictionary = GameManager.slot_modifiers(slot)
	for f in mods.get("follow_ups", []):
		var partner := int(f["partner"])
		if not visited_slots.has(partner) and rng.randf() < float(f["value"]) and budget >= GameManager.economy.unit_price(partner):
			if manager.stall_manager.enqueue(partner, self) >= 0:
				state = State.SELECTING
				target_slot = partner
				wait_time = 0.0
				patience_left = patience_max
				# 대기열 등록 시 set_queue_slot 이 SELECTING 이전에 호출되므로 경로 재설정
				set_queue_slot(queue_index, manager.market.queue_spot(partner, queue_index))
				manager.on_synergy_follow(self, slot, partner)
				return
	var extra := float(ctype.get("extra_purchase_chance", 0.2)) * spend_tendency * 1.4 + float(mods.get("extra_purchase_chance", 0.0))
	extra *= float(manager.market_mods.get("stay_mult", 1.0))
	if purchases < 3 and budget > 80.0 and rng.randf() < extra:
		state = State.BROWSING
		browse_timer = 0.6
		waypoints = [Vector2(MarketScript.LANE_IN_X + lane_offset, position.y + 10)]
		return
	_leave("done")


func on_rejected_price() -> void:
	_react("expensive")
	target_slot = -1
	_leave("expensive")


func on_sold_out() -> void:
	_react("soldout")
	if target_slot >= 0:
		manager.stall_manager.remove_customer(target_slot, self)
	target_slot = -1
	queue_index = -1
	if reselect_count < 1 and rng.randf() < 0.6:
		reselect_count += 1
		state = State.BROWSING
		browse_timer = 0.4
		waypoints = [Vector2(MarketScript.LANE_IN_X + lane_offset, position.y)]
		return
	_leave("walkout")


func _give_up() -> void:
	_react("angry")
	if target_slot >= 0:
		manager.stall_manager.remove_customer(target_slot, self)
	target_slot = -1
	_leave("walkout")


## 영업 마감 시 강제 퇴장 (통계에는 이탈로 집계하지 않음)
func force_leave() -> void:
	if state == State.LEAVING:
		return
	if target_slot >= 0:
		manager.stall_manager.remove_customer(target_slot, self)
	target_slot = -1
	exit_counted = true
	_leave("closing")


func _leave(reason: String) -> void:
	if not exit_counted:
		exit_counted = true
		if purchases == 0:
			if reason in ["walkout", "queue_full"]:
				GameManager.economy.record_walkout()
				manager.on_walkout_feedback(self)
			else:
				GameManager.economy.record_browser()
	state = State.LEAVING
	var out_x: float = MarketScript.LANE_OUT_X + lane_offset * 0.5
	waypoints = [Vector2(out_x, position.y), Vector2(out_x, MarketScript.EXIT_POINT.y)]


func _react(kind: String) -> void:
	reaction = kind
	reaction_timer = 1.6


# ───────── 그리기 ─────────

func _draw() -> void:
	var col := DataManager.color(ctype.get("color", "#B9B5B0"))
	var accent := DataManager.color(ctype.get("accent", "#555555"))
	var skin := Color("#F6D7B8")
	var bob := -absf(sin(anim_t * 11.0)) * 3.0 if moving else sin(anim_t * 2.0) * 0.8
	DrawUtil.ellipse(self, Vector2.ZERO, 14, 6, Color(0, 0, 0, 0.35))
	if type_id == "family":
		_draw_body(Vector2(-9, bob), col, accent, skin, 1.0)
		_draw_body(Vector2(12, bob * 0.7 + 2), col.lightened(0.2), accent, skin, 0.62)
	else:
		_draw_body(Vector2(0, bob), col, accent, skin, 1.0)
	# 상태 표시
	var head_top := Vector2(0, -56 + bob)
	if reaction_timer > 0.0:
		_draw_reaction(head_top + Vector2(0, -6))
	elif state == State.BROWSING or (state == State.SELECTING and not waypoints.is_empty() and target_slot < 0):
		DrawUtil.bubble(self, head_top, 34, 28)
		DrawUtil.food_icon(self, favorite_category, head_top + Vector2(0, -14), 9)
	elif state == State.QUEUING and arrived:
		var ratio := clampf(patience_left / maxf(1.0, patience_max), 0.0, 1.0)
		var bar_col := Color("#65C99A").lerp(Color("#E5564A"), 1.0 - ratio)
		draw_rect(Rect2(head_top + Vector2(-16, -8), Vector2(32, 6)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(head_top + Vector2(-16, -8), Vector2(32 * ratio, 6)), bar_col)
	elif state == State.SERVING:
		var dots := int(anim_t * 3.0) % 3 + 1
		DrawUtil.bubble(self, head_top, 34, 24)
		for k in dots:
			draw_circle(head_top + Vector2(-8 + k * 8, -12), 2.5, Color("#2A1A0C"))


func _draw_body(o: Vector2, col: Color, accent: Color, skin: Color, s: float) -> void:
	# 몸통 (둥근 형태)
	DrawUtil.rounded_rect(self, Rect2(o + Vector2(-12, -30) * s, Vector2(24, 28) * s), 10 * s, col)
	# 머리
	var head := o + Vector2(0, -40) * s
	draw_circle(head, 12 * s, skin)
	# 머리카락
	draw_arc(head, 12 * s, PI * 1.05, TAU * 0.98, 12, Color("#3A2A22"), 6 * s, true)
	# 눈 & 볼
	draw_circle(head + Vector2(-4, 1) * s, 1.8 * s, Color("#2A1A0C"))
	draw_circle(head + Vector2(4, 1) * s, 1.8 * s, Color("#2A1A0C"))
	draw_circle(head + Vector2(-7, 5) * s, 2.2 * s, Color(1, 0.55, 0.55, 0.5))
	draw_circle(head + Vector2(7, 5) * s, 2.2 * s, Color(1, 0.55, 0.55, 0.5))
	match type_id:
		"office_worker":
			draw_colored_polygon(PackedVector2Array([o + Vector2(-3, -29) * s, o + Vector2(3, -29) * s, o + Vector2(0, -14) * s]), accent)
			draw_rect(Rect2(o + Vector2(10, -20) * s, Vector2(10, 12) * s), Color("#3A3F4E"))
		"student":
			draw_rect(Rect2(o + Vector2(-16, -28) * s, Vector2(6, 18) * s), accent)
			draw_arc(head + Vector2(0, -3) * s, 12 * s, PI, TAU, 12, accent, 7 * s, true)
			draw_line(head + Vector2(0, -6) * s, head + Vector2(16, -6) * s, accent, 4 * s)
		"family":
			draw_rect(Rect2(o + Vector2(-12, -14) * s, Vector2(24, 4) * s), accent)
		"tourist":
			DrawUtil.ellipse(self, head + Vector2(0, -9) * s, 18 * s, 5 * s, Color("#F2D48A"))
			draw_circle(head + Vector2(0, -12) * s, 8 * s, Color("#F2D48A"))
			draw_rect(Rect2(o + Vector2(-6, -24) * s, Vector2(12, 8) * s), Color("#2A2A2A"))
			draw_circle(o + Vector2(0, -20) * s, 2.5 * s, Color("#7FD4E8"))


func _draw_reaction(p: Vector2) -> void:
	match reaction:
		"heart":
			DrawUtil.bubble(self, p, 34, 30)
			var c := p + Vector2(0, -15)
			draw_circle(c + Vector2(-4, -2), 5, Color("#FF6F8E"))
			draw_circle(c + Vector2(4, -2), 5, Color("#FF6F8E"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8.5, 0), c + Vector2(8.5, 0), c + Vector2(0, 9)]), Color("#FF6F8E"))
		"smile":
			DrawUtil.bubble(self, p, 34, 30)
			var c2 := p + Vector2(0, -15)
			draw_arc(c2, 8, 0.2, PI - 0.2, 10, Color("#2A1A0C"), 2.5, true)
			draw_circle(c2 + Vector2(-4, -4), 2, Color("#2A1A0C"))
			draw_circle(c2 + Vector2(4, -4), 2, Color("#2A1A0C"))
		"meh":
			DrawUtil.bubble(self, p, 34, 30)
			var c3 := p + Vector2(0, -15)
			draw_line(c3 + Vector2(-6, 4), c3 + Vector2(6, 4), Color("#2A1A0C"), 2.5)
			draw_circle(c3 + Vector2(-4, -3), 2, Color("#2A1A0C"))
			draw_circle(c3 + Vector2(4, -3), 2, Color("#2A1A0C"))
		"angry":
			DrawUtil.bubble(self, p, 34, 30, Color("#E5564A"))
			var c4 := p + Vector2(0, -15)
			draw_line(c4 + Vector2(-6, -6), c4 + Vector2(6, 6), Color("#FFF5E9"), 3.0)
			draw_line(c4 + Vector2(6, -6), c4 + Vector2(-6, 6), Color("#FFF5E9"), 3.0)
		"soldout":
			DrawUtil.bubble(self, p, 52, 28, Color("#B9B5B0"))
			DrawUtil.text_center(self, p + Vector2(0, -14), "품절", 16, Color("#2A1A0C"), 0)
		"expensive":
			DrawUtil.bubble(self, p, 52, 28, Color("#FFB45C"))
			DrawUtil.text_center(self, p + Vector2(0, -14), "비싸", 16, Color("#2A1A0C"), 0)
