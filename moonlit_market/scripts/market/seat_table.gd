extends Node2D
## SeatTable — 손님 앞 테이블 (손님보다 앞에 그려져 다리를 가린다).
## 나온 음식, 다 먹은 빈 그릇과 팁(치우기 필요), 좌석 번호를 표시한다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")

var index: int = 0
var market
var anim_t: float = 0.0


func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()


func _draw() -> void:
	var pm = market.pocha_manager if market else null
	var state := "free"
	var table_items: Array = []
	var tip := 0
	var cust = null
	if pm and pm.is_open and index < pm.seat_state.size():
		state = str(pm.seat_state[index]["state"])
		table_items = pm.seat_state[index]["table"]
		tip = int(pm.seat_state[index]["tip"])
		cust = pm.seats[index]
	var w := 40.0
	# 다리
	draw_line(Vector2(-w + 6, -22), Vector2(-w + 4, 6), Color("#8E9AA8"), 4.0)
	draw_line(Vector2(w - 6, -22), Vector2(w - 4, 6), Color("#8E9AA8"), 4.0)
	DrawUtil.ellipse(self, Vector2(0, 8), w + 4, 6, Color(0, 0, 0, 0.3))
	# 상판 (스테인리스 원탁 느낌)
	DrawUtil.ellipse(self, Vector2(0, -24), w + 2, 12, Color("#6E7C8C"))
	DrawUtil.ellipse(self, Vector2(0, -27), w, 11, Color("#B8C4D0"))
	DrawUtil.ellipse(self, Vector2(-8, -29), w * 0.5, 4, Color(1, 1, 1, 0.25))
	# 음식
	if state == "occupied" and table_items.size() > 0:
		var left := 1.0
		if cust != null and is_instance_valid(cust) and cust.state_name() == "EATING":
			left = clampf(1.0 - cust.eat_t / maxf(0.1, cust.eat_total), 0.3, 1.0)
		var shown := table_items.slice(maxi(0, table_items.size() - 2))
		for k in shown.size():
			var m: Dictionary = DataManager.get_menu(str(shown[k]))
			var p := Vector2((k - (shown.size() - 1) / 2.0) * 26.0, -32)
			DrawUtil.ellipse(self, p + Vector2(0, 4), 12, 4, Color("#F4F1EA"))
			DrawUtil.menu_icon(self, m, p, 9.0 * left + 2.0)
	elif state == "dirty":
		# 빈 그릇 + 동전 → 치우기
		for k in 2:
			DrawUtil.ellipse(self, Vector2(-14 + 26 * k, -30), 11, 4, Color("#E8E2D6"))
			DrawUtil.ellipse(self, Vector2(-14 + 26 * k, -31), 7, 2.5, Color("#C9B8A0"))
		if tip > 0:
			for k in mini(4, 1 + tip / 15):
				draw_circle(Vector2(4 + k * 3, -36 - k * 3), 5, Color("#FFB45C"))
				draw_arc(Vector2(4 + k * 3, -36 - k * 3), 5, 0, TAU, 10, Color("#9A5A1C"), 1.2, true)
		var pulse := 0.6 + 0.4 * sin(anim_t * 6.0)
		DrawUtil.rounded_rect(self, Rect2(Vector2(-34, -78), Vector2(68, 26)), 10, Color(0.9, 0.55, 0.2, 0.85 * pulse + 0.15))
		DrawUtil.text_center(self, Vector2(0, -65), "치우기", 17, Color("#FFF5E9"), 0)
	# 좌석 번호
	DrawUtil.text_center(self, Vector2(0, 22), "%d" % (index + 1), 15, Color(1, 1, 1, 0.35), 0)
