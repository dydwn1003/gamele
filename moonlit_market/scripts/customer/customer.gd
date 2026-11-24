extends Node2D
## Customer — 시장에 입장해 노점을 고르고, 사서 먹고, 퇴장하는 손님.
##
## 경쟁 노점 손님: ENTERING → BROWSING → SELECTING → QUEUING → SERVING → EATING(테이블/벤치) → LEAVING
## 내 포차 손님:   ENTERING → BROWSING → SELECTING → (QUEUING 대기줄) → SEATED(주문·대기)
##                 → EATING(카운터에서 먹기) → [추가 주문 → SEATED ...] → LEAVING(계산·팁)

const DrawUtil := preload("res://scripts/market/draw_util.gd")
const CustomerAI := preload("res://scripts/customer/customer_ai.gd")
const MarketScript := preload("res://scripts/market/market_manager.gd")

enum State { ENTERING, BROWSING, SELECTING, QUEUING, SERVING, SEATED, EATING, LEAVING }
const STATE_NAMES := ["ENTERING", "BROWSING", "SELECTING", "QUEUING", "SERVING", "SEATED", "EATING", "LEAVING"]

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
var favorite_category: String = ""

var state: int = State.ENTERING
var waypoints: Array = []
var target: String = "" ## "pocha" 또는 경쟁 노점 id
var rival_menu: String = ""
var queue_index: int = -1
var arrived: bool = false
var ordered: bool = false
var pending: Array = [] ## 아직 안 나온 주문 메뉴
var served_items: Array = [] ## [{menu, quality, price}]
var rounds: int = 0
var wait_time: float = 0.0
var total_wait: float = 0.0
var purchases: int = 0
var spent: int = 0
var satisfaction: float = 60.0
var eat_t: float = 0.0
var eat_total: float = 6.0
var eating_item: String = ""
var eat_spot: int = -1
var pending_tip: int = 0
var facing_back: bool = false
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
	var best := 0.0
	var prefs: Dictionary = ctype.get("category_pref", {})
	for k in prefs.keys():
		if float(prefs[k]) > best:
			best = float(prefs[k])
			favorite_category = str(k)
	lane_offset = rng.randf_range(-10.0, 10.0)
	position = spawn
	anim_t = rng.randf() * 10.0
	waypoints = [manager.market.browse_point(rng)]
	state = State.ENTERING


func state_name() -> String:
	return STATE_NAMES[state]


func is_at_pocha() -> bool:
	return target == "pocha"


# ───────── 매 프레임 ─────────

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
				var rate := 0.5 if is_at_pocha() else 1.0
				patience_left -= delta * rate / maxf(0.1, _patience_mult())
				if patience_left <= 0.0:
					_give_up()
		State.SEATED:
			if arrived and not ordered:
				_order()
			elif ordered and not pending.is_empty():
				wait_time += delta
				total_wait += delta
				patience_left -= delta / maxf(0.1, _patience_mult())
				if patience_left <= 0.0:
					_give_up()
		State.EATING:
			if arrived:
				eat_t += delta
				if eat_t >= eat_total:
					_finish_eating()
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
	if is_at_pocha():
		m *= 1.0 + float(manager.pocha_manager.fx.get("patience", 0.0))
	return m


func _move(delta: float) -> void:
	moving = false
	if waypoints.is_empty():
		return
	var tgt: Vector2 = waypoints[0]
	var step := speed * delta
	var to := tgt - position
	if to.length() <= step:
		position = tgt
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
		State.QUEUING, State.SEATED, State.EATING:
			arrived = true
			pass


func in_pocha() -> bool:
	return position.y > MarketScript.ENTRANCE.y - 10.0


## 거리 위 목적지 (가게 앞 / 드럼통 테이블)
func _street_path(dest: Vector2) -> Array:
	var path: Array = []
	if in_pocha():
		path.append_array(_exit_pocha_path())
	path.append(Vector2(dest.x, MarketScript.STREET_Y + lane_offset * 0.3))
	path.append(dest)
	return path


## 포차 안 목적지 (대기 자리 / 좌석)
func _pocha_path(dest: Vector2) -> Array:
	var path: Array = []
	if not in_pocha():
		path.append(Vector2(MarketScript.ENTRANCE.x + lane_offset, MarketScript.STREET_Y))
		path.append(MarketScript.ENTRANCE)
	if dest.y > 420.0:
		path.append(Vector2(dest.x, 420.0))
	path.append(dest)
	return path


func _exit_pocha_path() -> Array:
	return [Vector2(position.x, 420.0), MarketScript.ENTRANCE, Vector2(MarketScript.ENTRANCE.x - lane_offset, MarketScript.STREET_Y)]


# ───────── 선택 ─────────

func _select() -> void:
	state = State.SELECTING
	var choice: String = manager.choose_target(self)
	if choice == "":
		_leave("no_choice")
		return
	if choice == "pocha":
		target = "pocha"
		if not manager.pocha_manager.request_entry(self):
			target = ""
			_leave("queue_full")
		return
	target = choice
	rival_menu = manager.rival_manager.best_menu_for(choice, self, manager.choice_context(self))
	if manager.rival_manager.enqueue(choice, self) < 0:
		target = ""
		_leave("queue_full")


## 경쟁 노점 대기 순번 변경
func set_queue_slot(k: int, spot: Vector2) -> void:
	queue_index = k
	if state == State.SELECTING:
		waypoints = _street_path(spot)
		arrived = false
	elif state == State.QUEUING:
		waypoints = [spot]
		arrived = false


func is_ready_at_counter() -> bool:
	return state == State.QUEUING and arrived and queue_index == 0 and waypoints.is_empty()


func begin_serving() -> void:
	state = State.SERVING


# ───────── 내 포차 ─────────

func go_to_wait(k: int, pos: Vector2) -> void:
	var first := state != State.QUEUING
	state = State.QUEUING
	queue_index = k
	if first:
		waypoints = _pocha_path(pos)
		wait_time = 0.0
	else:
		waypoints = [pos]
	arrived = false


func go_to_seat(_i: int, pos: Vector2) -> void:
	var from_line := state == State.QUEUING
	state = State.SEATED
	ordered = false
	arrived = false
	facing_back = false
	waypoints = _pocha_path(pos)
	patience_left = patience_max


func can_receive() -> bool:
	return state == State.SEATED and arrived and ordered and not pending.is_empty()


func _order() -> void:
	var items: Array = manager.pick_pocha_order(self, rounds > 0)
	if items.is_empty():
		_react("soldout")
		if rounds == 0:
			_give_up()
		else:
			_leave_pocha()
		return
	ordered = true
	pending = items.duplicate()
	rounds += 1
	wait_time = 0.0
	patience_left = patience_max
	manager.pocha_manager.place_order(self, items)


func on_item_served(menu_id: String, quality: float, price: int) -> void:
	pending.erase(menu_id)
	served_items.append({"menu": menu_id, "quality": quality, "price": price})
	spent += price
	budget -= price
	if purchases == 0:
		GameManager.economy.record_buyer()
	purchases += 1
	_react("heart" if quality >= 95.0 else ("smile" if quality >= 70.0 else "meh"))
	if pending.is_empty():
		state = State.EATING
		arrived = true
		eat_t = 0.0
		eat_total = 0.0
		eating_item = menu_id
		for it in served_items.slice(maxi(0, served_items.size() - 2)):
			eat_total += float(DataManager.get_menu(it["menu"]).get("eat_time", 6.0))
			if str(DataManager.get_menu(it["menu"]).get("station", "")) == "grill":
				eating_item = it["menu"]
		eat_total = clampf(eat_total * 0.7, 3.0, 14.0) / maxf(0.3, float(ctype.get("eat_speed", 1.0)))


func _finish_eating() -> void:
	if is_at_pocha():
		if manager.wants_reorder(self):
			state = State.SEATED
			ordered = false
			arrived = true
			return
		_leave_pocha()
		return
	manager.market.release_eat_spot(eat_spot)
	eat_spot = -1
	_leave("done")


func avg_quality() -> float:
	if served_items.is_empty():
		return 0.0
	var s := 0.0
	for it in served_items:
		s += float(it["quality"])
	return s / served_items.size()


## 계산하고 떠남: 만족도 기록, 팁
func _leave_pocha() -> void:
	if not exit_counted and purchases > 0:
		satisfaction = manager.pocha_satisfaction(self)
		GameManager.economy.record_satisfaction(satisfaction)
		pending_tip = manager.tip_for(self, satisfaction)
		_react("heart" if satisfaction >= 75.0 else ("smile" if satisfaction >= 50.0 else "meh"))
		exit_counted = true
	# 빈 그릇과 팁은 테이블에 남는다 → 사장님이 치워야 다음 손님이 앉는다
	manager.pocha_manager.customer_left(self, pending_tip, purchases > 0)
	_leave("done")


# ───────── 경쟁 노점 구매 후 ─────────

func on_rival_purchase(_rival_id: String, price: int, quality: float) -> void:
	purchases += 1
	spent += price
	budget -= price
	satisfaction = clampf(quality, 0.0, 100.0)
	exit_counted = true
	eating_item = rival_menu
	_react("smile")
	state = State.EATING
	eat_t = 0.0
	eat_total = float(DataManager.bal("rival_eat_time", 6.0)) / maxf(0.3, float(ctype.get("eat_speed", 1.0)))
	eat_spot = manager.market.claim_eat_spot(self, rng)
	if eat_spot >= 0:
		var spot: Vector2 = MarketScript.EAT_SPOTS[eat_spot]
		waypoints = _street_path(spot)
		arrived = false
	else:
		# 자리가 없으면 서서 먹는다
		arrived = true
		waypoints = []


# ───────── 이탈 / 퇴장 ─────────

func on_rejected_price() -> void:
	_react("expensive")
	target = ""
	_leave("expensive")


func _give_up() -> void:
	_react("angry")
	if is_at_pocha():
		if purchases > 0 and not exit_counted:
			satisfaction = manager.pocha_satisfaction(self) - 25.0
			GameManager.economy.record_satisfaction(satisfaction)
			exit_counted = true
		manager.pocha_manager.customer_left(self, 0, purchases > 0)
	elif target != "":
		manager.rival_manager.remove_customer(target, self)
	_leave("walkout")


## 영업 마감 시 강제 퇴장 (아무것도 안 산 손님은 이탈로 집계하지 않음)
func force_leave() -> void:
	if state == State.LEAVING:
		return
	if is_at_pocha():
		if purchases > 0 and not exit_counted:
			satisfaction = manager.pocha_satisfaction(self)
			GameManager.economy.record_satisfaction(satisfaction)
		exit_counted = true
		manager.pocha_manager.customer_left(self, 0, false)
	elif target != "" and purchases == 0:
		manager.rival_manager.remove_customer(target, self)
	manager.market.release_eat_spot(eat_spot)
	eat_spot = -1
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
	facing_back = false
	var path: Array = []
	if in_pocha():
		path.append_array(_exit_pocha_path())
	else:
		path.append(Vector2(position.x, MarketScript.STREET_Y + lane_offset * 0.3))
	var from: Vector2 = path[path.size() - 1]
	path.append(manager.market.exit_point(from if rng.randf() < 0.7 else Vector2(720.0 - from.x, from.y)))
	waypoints = path


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
	var head_top := Vector2(0, -56 + bob)
	# 먹는 중: 음식 들고 냠냠
	if state == State.EATING and eating_item != "" and arrived:
		var m: Dictionary = DataManager.get_menu(eating_item)
		var left := clampf(1.0 - eat_t / maxf(0.1, eat_total), 0.25, 1.0)
		var hand := Vector2(14, -30 + bob + sin(anim_t * 6.0) * 2.0)
		DrawUtil.menu_icon(self, m, hand, 9.0 * left + 3.0)
		if fmod(anim_t, 1.6) < 0.5 and reaction_timer <= 0.0:
			DrawUtil.text_center(self, head_top + Vector2(16, -6), "냠", 15, Color("#FFF5E9"), 4)
	if reaction_timer > 0.0:
		_draw_reaction(head_top + Vector2(0, -6))
	elif state == State.SEATED and ordered and not pending.is_empty() and arrived:
		# 주문 말풍선 (나오지 않은 메뉴) + 인내심
		var n := mini(2, pending.size())
		var w := 30.0 + 26.0 * n
		DrawUtil.bubble(self, head_top, w, 32)
		for k in n:
			var pm: Dictionary = DataManager.get_menu(pending[k])
			DrawUtil.menu_icon(self, pm, head_top + Vector2(-13.0 * (n - 1) + 26.0 * k, -16), 9)
		var ratio := clampf(patience_left / maxf(1.0, patience_max), 0.0, 1.0)
		draw_rect(Rect2(head_top + Vector2(-w / 2.0 + 4, -40), Vector2(w - 8, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(head_top + Vector2(-w / 2.0 + 4, -40), Vector2((w - 8) * ratio, 5)), Color("#65C99A").lerp(Color("#E5564A"), 1.0 - ratio))
	elif state == State.BROWSING:
		DrawUtil.bubble(self, head_top, 34, 28)
		DrawUtil.food_icon(self, favorite_category, head_top + Vector2(0, -14), 9)
	elif state == State.QUEUING and arrived:
		var ratio2 := clampf(patience_left / maxf(1.0, patience_max), 0.0, 1.0)
		draw_rect(Rect2(head_top + Vector2(-16, -8), Vector2(32, 6)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(head_top + Vector2(-16, -8), Vector2(32 * ratio2, 6)), Color("#65C99A").lerp(Color("#E5564A"), 1.0 - ratio2))
	elif state == State.SERVING:
		var dots := int(anim_t * 3.0) % 3 + 1
		DrawUtil.bubble(self, head_top, 34, 24)
		for k in dots:
			draw_circle(head_top + Vector2(-8 + k * 8, -12), 2.5, Color("#2A1A0C"))


func _draw_body(o: Vector2, col: Color, accent: Color, skin: Color, s: float) -> void:
	DrawUtil.rounded_rect(self, Rect2(o + Vector2(-12, -30) * s, Vector2(24, 28) * s), 10 * s, col)
	var head := o + Vector2(0, -40) * s
	draw_circle(head, 12 * s, skin)
	if facing_back:
		# 뒷모습 (포차 카운터에 앉아 있음)
		draw_circle(head + Vector2(0, -1) * s, 12 * s, Color("#3A2A22"))
		draw_circle(head + Vector2(-11, 2) * s, 2.5 * s, skin)
		draw_circle(head + Vector2(11, 2) * s, 2.5 * s, skin)
		if type_id == "student":
			draw_arc(head + Vector2(0, -3) * s, 12 * s, PI, TAU, 12, accent, 7 * s, true)
		elif type_id == "tourist":
			DrawUtil.ellipse(self, head + Vector2(0, -9) * s, 18 * s, 5 * s, Color("#F2D48A"))
		return
	draw_arc(head, 12 * s, PI * 1.05, TAU * 0.98, 12, Color("#3A2A22"), 6 * s, true)
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
