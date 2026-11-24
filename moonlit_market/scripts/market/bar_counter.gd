extends Node2D
## BarCounter — ㄱ자 바 테이블 (원점 y = 가로 바 앞면).
## 가로 바: 손님이 메뉴판 쪽에 앉아 정면을 본다 (바가 다리를 가림)
## 세로 바: 오른쪽으로 꺾여 내려오고, 손님은 바깥쪽(오른쪽)에 앉는다.
## 포차 레벨로 아직 안 열린 자리는 "Lv.N" 표시.

const DrawUtil := preload("res://scripts/market/draw_util.gd")

var market
var anim_t: float = 0.0


func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()


func _seat_unlock_level(i: int) -> int:
	for lv in DataManager.max_stall_level():
		if int(DataManager.get_pocha_level(lv + 1).get("seats", 0)) > i:
			return lv + 1
	return 99


func _draw() -> void:
	if market == null:
		return
	var left: float = market.BAR_LEFT
	var corner: float = market.BAR_CORNER_X
	var leg_bottom: float = market.BAR_LEG_BOTTOM - position.y
	var top_y := -48.0
	var wood_top := Color("#D9B07A")
	var wood_edge := Color("#B8864E")
	var panel := Color("#6B3F28")
	var right := corner + 46.0
	# ── 세로 바 (뒤에서 앞으로) ──
	draw_rect(Rect2(Vector2(corner - 8, top_y), Vector2(10, leg_bottom - top_y)), panel.darkened(0.25))
	draw_rect(Rect2(Vector2(corner, top_y), Vector2(right - corner, leg_bottom - top_y)), wood_top)
	draw_rect(Rect2(Vector2(right - 4, top_y), Vector2(4, leg_bottom - top_y)), wood_edge)
	for k in 6:
		draw_line(Vector2(corner + 6, top_y + 30 + k * 34), Vector2(right - 8, top_y + 30 + k * 34), Color(0, 0, 0, 0.06), 2.0)
	draw_rect(Rect2(Vector2(corner - 8, leg_bottom), Vector2(right - corner + 8, 30)), panel)
	draw_rect(Rect2(Vector2(corner - 8, leg_bottom), Vector2(right - corner + 8, 5)), wood_edge)
	# ── 가로 바 ──
	draw_rect(Rect2(Vector2(left, top_y), Vector2(right - left, 20)), wood_top)
	draw_rect(Rect2(Vector2(left, top_y + 16), Vector2(right - left, 6)), wood_edge)
	draw_rect(Rect2(Vector2(left, top_y + 22), Vector2(corner - left, 46)), panel)
	for k in int((corner - left) / 40.0):
		draw_line(Vector2(left + 20 + k * 40, top_y + 24), Vector2(left + 20 + k * 40, top_y + 66), Color(0, 0, 0, 0.12), 2.0)
	# 발 받침 (황동)
	draw_line(Vector2(left + 6, top_y + 58), Vector2(corner - 4, top_y + 58), Color("#C9A24A"), 4.0)
	# 바 위 조명 반사
	DrawUtil.ellipse(self, Vector2(320, top_y + 6), 260, 6, Color(1, 0.9, 0.7, 0.12))
	# ── 자리 표시 (종이 매트 / 잠김) ──
	var open_n: int = market.seat_count()
	for i in market.max_seats():
		var pp: Vector2 = market.place_pos(i) - position
		var mat := Vector2(pp.x, top_y + 8) if not market.is_vertical_seat(i) else Vector2(pp.x, pp.y - 6)
		if i < open_n:
			DrawUtil.ellipse(self, mat, 18 if not market.is_vertical_seat(i) else 14, 5, Color(1, 1, 1, 0.18))
		else:
			var lv := _seat_unlock_level(i)
			DrawUtil.rounded_rect(self, Rect2(mat - Vector2(22, 9), Vector2(44, 18)), 6, Color(0.1, 0.08, 0.12, 0.6))
			DrawUtil.text_center(self, mat, "Lv.%d" % lv, 12, Color(1, 1, 1, 0.6), 0)
