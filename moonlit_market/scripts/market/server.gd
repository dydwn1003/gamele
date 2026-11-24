extends Node2D
## Server — 사장님 아바타. 통로를 걸어 다니며 서빙과 테이블 치우기를 한다.
## 할 일(task)을 순서대로 처리한다:
##   serve: (필요하면) 서빙대로 가서 이 손님 음식을 쟁반에 담기 → 테이블로 가서 전달
##   clear: 테이블로 가서 빈 그릇 치우고 팁 수령

const DrawUtil := preload("res://scripts/market/draw_util.gd")

var market
var pocha
var tray: Array = [] ## [{menu, quality, age}]
var tasks: Array = []
var cur: Dictionary = {}
var phase: String = ""
var target: Vector2 = Vector2.ZERO
var action_t: float = 0.0
var anim_t: float = 0.0
var moving: bool = false
var facing: float = 1.0
var serve_flash: float = 0.0


func reset() -> void:
	tray = []
	tasks = []
	cur = {}
	phase = ""
	if market:
		position = market.PASS_POS
		target = position


func speed() -> float:
	return float(DataManager.pocha.get("server_speed", 300.0))


func tray_capacity() -> int:
	return int(DataManager.get_pocha_level(GameManager.state.pocha_level()).get("tray", 2))


func tray_has_for(c) -> bool:
	for it in tray:
		if c.pending.has(it["menu"]):
			return true
	return false


func is_task_for_seat(seat: int) -> bool:
	if cur.get("type", "") == "clear" and int(cur.get("seat", -1)) == seat:
		return true
	for t in tasks:
		if t["type"] == "clear" and int(t["seat"]) == seat:
			return true
	return false


func enqueue_serve(c) -> void:
	if cur.get("customer") == c:
		return
	for t in tasks:
		if t.get("customer") == c:
			return
	tasks.append({"type": "serve", "customer": c})


func enqueue_clear(seat: int) -> void:
	if is_task_for_seat(seat):
		return
	tasks.append({"type": "clear", "seat": seat})


func forget_customer(c) -> void:
	for t in tasks.duplicate():
		if t.get("customer") == c:
			tasks.erase(t)
	if cur.get("customer") == c:
		cur = {}
		phase = ""


func busy() -> bool:
	return not cur.is_empty() or not tasks.is_empty()


func tick(delta: float) -> void:
	anim_t += delta
	serve_flash = maxf(0.0, serve_flash - delta * 3.0)
	for it in tray:
		it["age"] = float(it.get("age", 0.0)) + delta
		it["quality"] = maxf(40.0, float(it["quality"]) - delta * 1.2)
	if cur.is_empty() and not tasks.is_empty():
		cur = tasks.pop_front()
		_begin()
	_move(delta)
	if phase == "clearing":
		action_t -= delta
		if action_t <= 0.0:
			pocha.clear_seat(int(cur["seat"]))
			cur = {}
			phase = ""
	queue_redraw()


func _move(delta: float) -> void:
	moving = false
	if phase == "" or phase == "clearing":
		return
	var to := target - position
	var step := speed() * delta
	if absf(to.x) > 1.0:
		facing = signf(to.x)
	if to.length() <= step:
		position = target
		_arrive()
	else:
		position += to.normalized() * step
		moving = true


func _seat_index(c) -> int:
	return pocha.seat_of(c) if c != null and is_instance_valid(c) else -1


func _begin() -> void:
	match str(cur.get("type", "")):
		"serve":
			var c = cur.get("customer")
			var s := _seat_index(c)
			if s < 0 or not c.can_receive():
				cur = {}
				return
			if tray.size() < tray_capacity() and pocha.pass_has_for(c, tray):
				phase = "to_pass"
				target = market.PASS_POS
			elif tray_has_for(c):
				phase = "to_seat"
				target = market.serve_pos(s, pocha.seat_count())
			else:
				cur = {}
		"clear":
			phase = "to_clear"
			target = market.serve_pos(int(cur["seat"]), pocha.seat_count())
		_:
			cur = {}


func _arrive() -> void:
	match phase:
		"to_pass":
			var c = cur.get("customer")
			var s := _seat_index(c)
			if s < 0:
				cur = {}
				phase = ""
				return
			tray.append_array(pocha.pass_take_for(c, tray_capacity() - tray.size(), tray))
			if tray_has_for(c):
				phase = "to_seat"
				target = market.serve_pos(s, pocha.seat_count())
			else:
				cur = {}
				phase = ""
		"to_seat":
			var c = cur.get("customer")
			if c != null and is_instance_valid(c) and c.can_receive():
				for it in tray.duplicate():
					if c.pending.has(it["menu"]) and pocha.serve_item(c, it):
						tray.erase(it)
						serve_flash = 1.0
			cur = {}
			phase = ""
		"to_clear":
			phase = "clearing"
			action_t = float(DataManager.pocha.get("clear_time", 0.5))
		_:
			phase = ""


func _draw() -> void:
	var bob := -absf(sin(anim_t * 12.0)) * 3.0 if moving else sin(anim_t * 2.2) * 1.0
	DrawUtil.ellipse(self, Vector2.ZERO, 18, 7, Color(0, 0, 0, 0.35))
	var o := Vector2(0, bob)
	# 다리 (걷기)
	var swing := sin(anim_t * 12.0) * 5.0 if moving else 0.0
	draw_line(o + Vector2(-6, -16), o + Vector2(-6 + swing, 0), Color("#2A2A3A"), 6.0)
	draw_line(o + Vector2(6, -16), o + Vector2(6 - swing, 0), Color("#2A2A3A"), 6.0)
	# 몸통: 흰 티 + 남색 앞치마
	DrawUtil.rounded_rect(self, Rect2(o + Vector2(-16, -52), Vector2(32, 38)), 12, Color("#FFF5E9"))
	draw_rect(Rect2(o + Vector2(-13, -38), Vector2(26, 24)), Color("#2F3E66"))
	draw_line(o + Vector2(-10, -50), o + Vector2(-10, -38), Color("#2F3E66"), 3.0)
	draw_line(o + Vector2(10, -50), o + Vector2(10, -38), Color("#2F3E66"), 3.0)
	# 머리 + 머리띠
	var head := o + Vector2(0, -66)
	draw_circle(head, 15, Color("#F6D7B8"))
	draw_arc(head, 15, PI * 1.05, TAU * 0.98, 12, Color("#2A1A0C"), 8, true)
	draw_rect(Rect2(head + Vector2(-15, -10), Vector2(30, 6)), Color("#E5483A"))
	draw_line(head + Vector2(-facing * 14, -8), head + Vector2(-facing * 24, -14), Color("#E5483A"), 4.0)
	draw_circle(head + Vector2(facing * 4 - 4, 1), 2.0, Color("#2A1A0C"))
	draw_circle(head + Vector2(facing * 4 + 4, 1), 2.0, Color("#2A1A0C"))
	draw_arc(head + Vector2(facing * 3, 6), 4, 0.3, PI - 0.3, 6, Color("#9A5A3C"), 2.0, true)
	# 쟁반 + 음식
	if not tray.is_empty():
		var tp := o + Vector2(facing * 22, -48)
		DrawUtil.ellipse(self, tp, 22, 6, Color("#C9C2B8"))
		for k in tray.size():
			var m: Dictionary = DataManager.get_menu(str(tray[k]["menu"]))
			DrawUtil.menu_icon(self, m, tp + Vector2((k - (tray.size() - 1) / 2.0) * 16, -10), 9)
	if serve_flash > 0.0:
		DrawUtil.glow(self, o + Vector2(0, -40), 50, Color(1.0, 0.9, 0.5, serve_flash * 0.5))
	# 할 일 대기 수
	if tasks.size() > 0:
		DrawUtil.text_center(self, head + Vector2(0, -30), "+%d" % tasks.size(), 16, Color("#FFD27A"), 4)
