extends Node2D
## Stall — 경쟁 노점 외형 (아이소메트릭 도형). 로직은 RivalManager 가 담당하고 이 노드는 그리기만 한다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")

const HW := 92.0
const HH := 46.0
const H := 56.0
const ROOF_BASE := 78.0
const ROOF_H := 62.0

var rival_id: String = ""
var market
var facing: int = 1 ## 1: 오른쪽(통로)을 봄, -1: 왼쪽
var anim_t: float = 0.0


func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()


func _up(p: Vector2, h: float) -> Vector2:
	return p - Vector2(0, h)


func _draw() -> void:
	var rival: Dictionary = DataManager.get_rival(rival_id)
	if rival.is_empty():
		return
	var def: Dictionary = DataManager.get_stall(str(rival.get("stall_type", "skewer")))
	var menus: Array = rival.get("menus", [])
	var menu: Dictionary = DataManager.get_menu(str(menus[0])) if menus.size() > 0 else {}
	var rm = market.rival_manager if market else null
	var quality: float = rm.quality(rival_id) if rm else float(rival.get("quality", 70))
	var level := clampi(int(round(quality / 20.0)), 1, 5)
	var slot_index := rival_id.length()
	var base_col := DataManager.color(def.get("color", "#E97858"))
	var roof_col := DataManager.color(def.get("roof_color", "#B8443A"))
	var wood := Color("#8A5A3C")
	var N := Vector2(0, -HH)
	var E := Vector2(HW, 0)
	var S := Vector2(0, HH)
	var W := Vector2(-HW, 0)

	# 그림자
	DrawUtil.ellipse(self, Vector2(0, 8), HW * 1.05, HH * 0.9, Color(0, 0, 0, 0.35))
	# 카운터 박스
	draw_colored_polygon(PackedVector2Array([W, S, _up(S, H), _up(W, H)]), wood.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([S, E, _up(E, H), _up(S, H)]), wood.darkened(0.05))
	# 판매 창구 (통로 쪽 면)
	var face_a := S if facing > 0 else W
	var face_b := E if facing > 0 else S
	var inset := PackedVector2Array([
		face_a.lerp(face_b, 0.15) - Vector2(0, H * 0.25), face_a.lerp(face_b, 0.85) - Vector2(0, H * 0.25),
		face_a.lerp(face_b, 0.85) - Vector2(0, H * 0.8), face_a.lerp(face_b, 0.15) - Vector2(0, H * 0.8)])
	draw_colored_polygon(inset, base_col)
	# 상판
	draw_colored_polygon(DrawUtil.diamond(Vector2(0, -H), HW, HH), Color("#D8B48A"))
	draw_colored_polygon(DrawUtil.diamond(Vector2(0, -H), HW * 0.8, HH * 0.8), Color("#C99E70"))
	# 사장님
	var ep := Vector2(-facing * 18, -H - HH * 0.35)
	draw_rect(Rect2(ep + Vector2(-11, -26), Vector2(22, 26)), base_col.darkened(0.35))
	draw_circle(ep + Vector2(0, -36), 11, Color("#F6D7B8"))
	draw_rect(Rect2(ep + Vector2(-12, -50), Vector2(24, 7)), Color("#FFF5E9"))
	draw_circle(ep + Vector2(-4, -36), 1.8, Color("#2A1A0C"))
	draw_circle(ep + Vector2(4, -36), 1.8, Color("#2A1A0C"))
	# 진열 음식
	var cat := str(menu.get("category", "snack"))
	var mcol := DataManager.color(menu.get("color", "#E97858"))
	var goods_center := Vector2(facing * 26, -H + 8)
	for k in 3:
		DrawUtil.menu_icon(self, menu, goods_center + Vector2(facing * (k - 1) * 18, -k * 4), 10, mcol)
	# 기둥
	for p in [W, S, E]:
		draw_line(_up(p, H), _up(p * 1.02, H + ROOF_BASE), Color("#5A3A28"), 5.0)
	# 지붕 (줄무늬 천막)
	var apex := Vector2(0, -(H + ROOF_BASE + ROOF_H))
	var rW := _up(W * 1.12, H + ROOF_BASE)
	var rS := _up(S * 1.12 + Vector2(0, 6), H + ROOF_BASE)
	var rE := _up(E * 1.12, H + ROOF_BASE)
	var stripes := 4
	for side in 2:
		var p0 := rW if side == 0 else rS
		var p1 := rS if side == 0 else rE
		for k in stripes:
			var a0 := p0.lerp(p1, float(k) / stripes)
			var a1 := p0.lerp(p1, float(k + 1) / stripes)
			var col := roof_col if k % 2 == 0 else Color("#FFF5E9")
			if side == 0:
				col = col.darkened(0.18)
			draw_colored_polygon(PackedVector2Array([apex, a0, a1]), col)
		# 가장자리 술 장식
		for k in stripes * 2:
			var q := p0.lerp(p1, (k + 0.5) / (stripes * 2))
			draw_circle(q + Vector2(0, 3), 5.5, roof_col.darkened(0.1) if side == 1 else roof_col.darkened(0.3))
	# 등불 (레벨에 따라 증가)
	var lantern_pts := [rW, rE, rS]
	var lamp_count := clampi(level, 1, 3)
	for k in lamp_count:
		var lp: Vector2 = lantern_pts[k] + Vector2(0, 18)
		var fl := 0.85 + 0.15 * sin(anim_t * 5.0 + k * 1.7 + slot_index)
		DrawUtil.glow(self, lp, 26, Color(1.0, 0.68, 0.3, 0.9 * fl))
		draw_circle(lp, 8, Color("#E5483A"))
		draw_circle(lp + Vector2(-2, -2), 3, Color(1, 0.85, 0.6))
	# 간판
	var sign_w := 168.0
	var sign_rect := Rect2(apex + Vector2(-sign_w / 2.0, -46), Vector2(sign_w, 40))
	var neon := Color(base_col.lightened(0.3), 0.55 + 0.25 * sin(anim_t * 4.0 + slot_index))
	if level >= 3:
		DrawUtil.rounded_rect(self, sign_rect.grow(6), 14, Color(neon, 0.35))
	DrawUtil.rounded_rect(self, sign_rect.grow(2), 12, neon if level >= 2 else Color("#5A3A28"))
	DrawUtil.rounded_rect(self, sign_rect, 10, Color("#2A1E2E"))
	DrawUtil.text_center(self, sign_rect.get_center(), str(rival.get("name", "노점")), 20, Color("#FFF5E9"), 0)
	# 레벨 별
	for k in level:
		var sx := (k - (level - 1) / 2.0) * 15.0
		_star(apex + Vector2(sx, -58), 6.5, Color("#FFD27A"))
	# 판매 중 표시
	if rm and rm.is_serving(rival_id):
		var t: float = rm.serve_progress(rival_id)
		var cp := Vector2(facing * 50, -H - 30)
		draw_circle(cp, 17, Color(0, 0, 0, 0.55))
		draw_arc(cp, 14, -PI / 2, -PI / 2 + TAU * t, 24, Color("#B9B5B0"), 5.0, true)
	# 할인 행사 배지
	if market and market.customer_manager and float(market.customer_manager.event_mods.get("rival_price_mult", 1.0)) < 1.0:
		var bp := apex + Vector2(0, -78)
		DrawUtil.rounded_rect(self, Rect2(bp - Vector2(40, 16), Vector2(80, 30)), 10, Color("#E5564A"))
		DrawUtil.text_center(self, bp, "할인!", 20, Color("#FFF5E9"), 0)
	# 경쟁 표시 (평판)
	DrawUtil.text_center(self, Vector2(0, HH + 22), "평판 %d" % int(rm.reputation(rival_id) if rm else float(rival.get("reputation", 20))), 18, Color("#B9B5B0"), 4)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
