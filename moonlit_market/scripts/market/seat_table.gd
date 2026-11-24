extends Node2D
## SeatTable — 바 위 한 자리 (원점 = 음식이 놓이는 곳). 손님보다 앞에 그려진다.
## 나온 음식, 다 먹은 빈 그릇과 팁(치우기 필요), 좌석 번호를 표시한다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")

var index: int = 0
var market
var vertical: bool = false ## 세로 바 자리
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
	var base := Vector2(0, -42) if not vertical else Vector2(0, -8)
	if state == "occupied" and table_items.size() > 0:
		var left := 1.0
		if cust != null and is_instance_valid(cust) and cust.state_name() == "EATING":
			left = clampf(1.0 - cust.eat_t / maxf(0.1, cust.eat_total), 0.3, 1.0)
		var shown := table_items.slice(maxi(0, table_items.size() - 2))
		for k in shown.size():
			var m: Dictionary = DataManager.get_menu(str(shown[k]))
			var p := base + (Vector2((k - (shown.size() - 1) / 2.0) * 22.0, 0) if not vertical else Vector2(0, (k - (shown.size() - 1) / 2.0) * 18.0))
			DrawUtil.ellipse(self, p + Vector2(0, 4), 11, 4, Color("#F4F1EA"))
			DrawUtil.menu_icon(self, m, p, 8.0 * left + 2.0)
	elif state == "dirty":
		for k in 2:
			var dp := base + (Vector2(-11 + 22 * k, 0) if not vertical else Vector2(0, -8 + 16 * k))
			DrawUtil.ellipse(self, dp, 10, 4, Color("#E8E2D6"))
			DrawUtil.ellipse(self, dp + Vector2(0, -1), 6, 2.5, Color("#C9B8A0"))
		if tip > 0:
			for k in mini(4, 1 + tip / 15):
				var cp := base + Vector2(10 + k * 3, -6 - k * 3)
				draw_circle(cp, 5, Color("#FFB45C"))
				draw_arc(cp, 5, 0, TAU, 10, Color("#9A5A1C"), 1.2, true)
		var pulse := 0.6 + 0.4 * sin(anim_t * 6.0)
		var tag := base + (Vector2(0, -34) if not vertical else Vector2(52, -30))
		DrawUtil.rounded_rect(self, Rect2(tag - Vector2(30, 12), Vector2(60, 24)), 9, Color(0.9, 0.55, 0.2, 0.85 * pulse + 0.15))
		DrawUtil.text_center(self, tag, "치우기", 15, Color("#FFF5E9"), 0)
	# 좌석 번호
	var np := Vector2(0, 14) if not vertical else Vector2(-30, 0)
	DrawUtil.text_center(self, np, "%d" % (index + 1), 13, Color(1, 1, 1, 0.35), 0)
