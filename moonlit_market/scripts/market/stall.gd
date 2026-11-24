extends Node2D
## Stall — 거리 건너편 경쟁 노점 가게 정면 (원점 = 가게 앞 바닥 가운데).
## 로직은 RivalManager 가 담당하고 이 노드는 그리기만 한다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")

var rival_id: String = ""
var market
var facing: int = 1
var anim_t: float = 0.0


func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()


func _draw() -> void:
	var rival: Dictionary = DataManager.get_rival(rival_id)
	if rival.is_empty():
		return
	var def: Dictionary = DataManager.get_stall(str(rival.get("stall_type", "skewer")))
	var base_col := DataManager.color(def.get("color", "#E97858"))
	var roof_col := DataManager.color(def.get("roof_color", "#B8443A"))
	var rm = market.rival_manager if market else null
	var menus: Array = rival.get("menus", [])
	var w := 62.0
	var phase_seed := float(rival_id.length())
	# 건물 벽
	draw_rect(Rect2(Vector2(-w, -150), Vector2(w * 2, 150)), Color("#3A3242"))
	draw_rect(Rect2(Vector2(-w, -150), Vector2(w * 2, 6)), Color("#2A2430"))
	# 간판 (네온)
	var sign_rect := Rect2(Vector2(-w + 4, -146), Vector2(w * 2 - 8, 30))
	var neon := 0.75 + 0.25 * sin(anim_t * 3.0 + phase_seed)
	DrawUtil.rounded_rect(self, sign_rect.grow(4), 10, Color(base_col.lightened(0.2), 0.35 * neon))
	DrawUtil.rounded_rect(self, sign_rect, 8, Color("#1D1424"))
	DrawUtil.text_center(self, sign_rect.get_center(), str(rival.get("name", "노점")), 17, Color(base_col.lightened(0.45), 0.8 + 0.2 * neon), 0)
	# 줄무늬 차양
	var stripes := 8
	for k in stripes:
		var x0 := -w - 6 + k * ((w + 6) * 2.0 / stripes)
		var x1 := x0 + (w + 6) * 2.0 / stripes
		var col := roof_col if k % 2 == 0 else Color("#FFF5E9")
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4, -112), Vector2(x1 + 4, -112), Vector2(x1, -92), Vector2(x0, -92)]), col)
		draw_circle(Vector2((x0 + x1) / 2.0, -90), 5.0, col.darkened(0.15))
	# 가게 안 (따뜻한 빛) + 사장님
	draw_rect(Rect2(Vector2(-w + 8, -88), Vector2(w * 2 - 16, 56)), Color("#FFB45C").darkened(0.35))
	DrawUtil.glow(self, Vector2(0, -60), 70, Color(1.0, 0.7, 0.35, 0.25), 2)
	var ep := Vector2(sin(anim_t * 1.1 + phase_seed) * 18.0, -40)
	draw_rect(Rect2(ep + Vector2(-10, -24), Vector2(20, 24)), base_col.darkened(0.3))
	draw_circle(ep + Vector2(0, -32), 10, Color("#F6D7B8"))
	draw_rect(Rect2(ep + Vector2(-11, -44), Vector2(22, 6)), Color("#FFF5E9"))
	draw_circle(ep + Vector2(-3.5, -32), 1.6, Color("#2A1A0C"))
	draw_circle(ep + Vector2(3.5, -32), 1.6, Color("#2A1A0C"))
	# 판매대 + 진열 음식
	draw_rect(Rect2(Vector2(-w + 2, -34), Vector2(w * 2 - 4, 34)), base_col.darkened(0.2))
	draw_rect(Rect2(Vector2(-w, -40), Vector2(w * 2, 8)), Color("#D8B48A"))
	for k in 3:
		var m: Dictionary = DataManager.get_menu(str(menus[k % maxi(1, menus.size())])) if menus.size() > 0 else {}
		DrawUtil.menu_icon(self, m, Vector2(-34 + 34 * k, -48), 9)
	# 등불
	for sx in [-w - 2, w + 2]:
		var lp := Vector2(sx, -100)
		DrawUtil.glow(self, lp, 20, Color(1, 0.6, 0.3, 0.7 * neon))
		DrawUtil.ellipse(self, lp, 6, 8, Color("#E5483A"))
	# 판매 진행
	if rm and rm.is_serving(rival_id):
		var t: float = rm.serve_progress(rival_id)
		var cp := Vector2(w - 14, -62)
		draw_circle(cp, 12, Color(0, 0, 0, 0.55))
		draw_arc(cp, 10, -PI / 2, -PI / 2 + TAU * t, 20, Color("#B9B5B0"), 4.0, true)
	# 할인 행사
	if market and market.customer_manager and float(market.customer_manager.event_mods.get("rival_price_mult", 1.0)) < 1.0:
		DrawUtil.rounded_rect(self, Rect2(Vector2(-30, -176), Vector2(60, 24)), 8, Color("#E5564A"))
		DrawUtil.text_center(self, Vector2(0, -164), "할인!", 16, Color("#FFF5E9"), 0)
	# 평판
	DrawUtil.text_center(self, Vector2(0, -18), "평판 %d" % int(rm.reputation(rival_id) if rm else float(rival.get("reputation", 20))), 13, Color(1, 1, 1, 0.7), 3)
