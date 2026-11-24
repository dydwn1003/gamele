extends Node2D
## 시장 배경/구조물 드로잉.
## layer = "ground": 밤하늘, 지붕 실루엣, 광장 타일, 중앙 통로, 조명 웅덩이, 장식
## layer = "overhead": 줄 조명, 메인 입구(간판) — 손님보다 위에 그려진다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")
const MarketScript := preload("res://scripts/market/market_manager.gd")

@export var layer: String = "ground"

var market ## market_manager
var anim_t: float = 0.0
var stars: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		stars.append(Vector3(rng.randf_range(-200, 920), rng.randf_range(-300, 110), rng.randf_range(0, TAU)))


func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()


func _draw() -> void:
	if layer == "ground":
		_draw_ground()
	else:
		_draw_overhead()


func _draw_ground() -> void:
	# 하늘 (화면 비율이 달라도 빈 곳이 없도록 넓게)
	var sky_top := Color("#0F1220")
	var sky_bottom := Color("#232236")
	draw_polygon(PackedVector2Array([Vector2(-800, -1200), Vector2(1520, -1200), Vector2(1520, 110), Vector2(-800, 110)]),
		PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	for s in stars:
		var a := 0.35 + 0.35 * sin(anim_t * 1.5 + s.z)
		draw_circle(Vector2(s.x, s.y * 0.6), 1.6, Color(1, 0.97, 0.9, a))
	DrawUtil.glow(self, Vector2(632, 40), 80, Color(1.0, 0.95, 0.75, 0.5))
	draw_circle(Vector2(632, 40), 24, Color("#FFF1B8"))
	# 한옥 지붕 실루엣
	var roof_col := Color("#191C2A")
	for i in 7:
		var cx := -60.0 + i * 140.0
		var top := 62.0 + (i % 2) * 12.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 90, top + 28), Vector2(cx - 60, top + 8), Vector2(cx, top),
			Vector2(cx + 60, top + 8), Vector2(cx + 90, top + 28), Vector2(cx + 70, top + 24), Vector2(cx + 70, 120), Vector2(cx - 70, 120), Vector2(cx - 70, top + 24)]), roof_col)
		draw_rect(Rect2(Vector2(cx - 20, top + 32), Vector2(14, 10)), Color(1, 0.75, 0.4, 0.35))
	# 광장 바닥
	draw_rect(Rect2(Vector2(-800, 110), Vector2(2320, 1400)), Color("#2A2430"))
	var grid_col := Color(1, 1, 1, 0.045)
	for i in range(-14, 26):
		var x0 := i * 64.0
		draw_line(Vector2(x0 - 600, -190), Vector2(x0 + 1400, 810), grid_col, 2.0)
		draw_line(Vector2(x0 + 600, -190), Vector2(x0 - 1400, 810), grid_col, 2.0)
	# 경쟁 노점 주변 빛
	for p in MarketScript.RIVAL_POSITIONS:
		DrawUtil.ellipse(self, p + Vector2(0, 10), 140, 72, Color(1.0, 0.6, 0.25, 0.05))
	# 중앙 광장 길
	draw_rect(Rect2(Vector2(262, 110), Vector2(196, 700)), Color("#3B3240"))
	for row in 18:
		var y := 110.0 + row * 40.0
		for col in 5:
			var cx := 262.0 + 19.6 + col * 39.2
			var shade := Color("#463C4B") if (row + col) % 2 == 0 else Color("#40364A")
			draw_colored_polygon(DrawUtil.diamond(Vector2(cx, y + 20), 18, 18), shade)
	# 먹자 테이블 (드럼통 테이블)
	for t in MarketScript.TABLES:
		DrawUtil.ellipse(self, t + Vector2(0, 14), 30, 12, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(t + Vector2(-20, -18), Vector2(40, 30)), Color("#4D6C8A"))
		for k in 3:
			draw_line(t + Vector2(-20, -10 + k * 9), t + Vector2(20, -10 + k * 9), Color("#3A5570"), 2.0)
		DrawUtil.ellipse(self, t + Vector2(0, -18), 24, 9, Color("#6B8BAA"))
		DrawUtil.ellipse(self, t + Vector2(0, -18), 18, 6, Color("#5A7898"))
	# 벤치
	for b in [Vector2(78, 668), Vector2(66, 590)]:
		draw_colored_polygon(DrawUtil.diamond(b, 40, 12), Color("#8A5A3C"))
		draw_line(b + Vector2(-28, 2), b + Vector2(-28, 14), Color("#5A3A28"), 4.0)
		draw_line(b + Vector2(28, 2), b + Vector2(28, 14), Color("#5A3A28"), 4.0)
	# 장식
	_draw_decorations()


func _draw_decorations() -> void:
	if market == null:
		return
	var spots: Array = MarketScript.DECO_SPOTS
	var usable: int = GameManager.progression.deco_spot_count()
	for i in spots.size():
		var p: Vector2 = spots[i]
		var id := ""
		if i < GameManager.state.deco_spots.size():
			id = str(GameManager.state.deco_spots[i])
		if id == "" or i >= usable:
			if i < usable and not GameManager.is_operating:
				DrawUtil.ellipse(self, p, 30, 15, Color(1, 1, 1, 0.05))
				var ring := PackedVector2Array()
				for k in 17:
					ring.append(p + Vector2(cos(TAU * k / 16.0) * 30, sin(TAU * k / 16.0) * 15))
				draw_polyline(ring, Color(1, 1, 1, 0.15), 2.0)
			continue
		_draw_deco(id, p)


func _draw_deco(id: String, p: Vector2) -> void:
	var def: Dictionary = DataManager.get_decoration(id)
	var col := DataManager.color(def.get("color", "#FFB45C"))
	DrawUtil.ellipse(self, p + Vector2(0, 4), 34, 14, Color(0, 0, 0, 0.35))
	match id:
		"lantern_row":
			draw_line(p, p + Vector2(0, -110), Color("#5A3A28"), 5.0)
			draw_line(p + Vector2(0, -105), p + Vector2(34, -100), Color("#5A3A28"), 3.0)
			for k in 3:
				var lp := p + Vector2(0, -88 + k * 26) + Vector2(sin(anim_t * 2.0 + k) * 2, 0)
				DrawUtil.glow(self, lp, 26, Color(1, 0.5, 0.35, 0.7))
				DrawUtil.ellipse(self, lp, 10, 12, col)
				draw_rect(Rect2(lp + Vector2(-6, -13), Vector2(12, 3)), Color("#2A1A0C"))
		"flower_pots":
			for k in 2:
				var fp := p + Vector2(-16 + k * 32, 0)
				draw_colored_polygon(PackedVector2Array([fp + Vector2(-13, -20), fp + Vector2(13, -20), fp + Vector2(9, 0), fp + Vector2(-9, 0)]), Color("#B5653A"))
				draw_circle(fp + Vector2(0, -30), 14, col)
				draw_circle(fp + Vector2(-6, -34), 5, Color("#FF8FA3"))
				draw_circle(fp + Vector2(6, -28), 5, Color("#FFD27A"))
		"neon_sign":
			draw_line(p, p + Vector2(0, -60), Color("#555A66"), 4.0)
			var r := Rect2(p + Vector2(-46, -112), Vector2(92, 50))
			var fl := 0.75 + 0.25 * sin(anim_t * 7.0)
			DrawUtil.rounded_rect(self, r.grow(8), 16, Color(col, 0.25 * fl))
			DrawUtil.rounded_rect(self, r.grow(2), 12, Color(col, fl))
			DrawUtil.rounded_rect(self, r, 10, Color("#1D1424"))
			DrawUtil.text_center(self, r.get_center(), "야시장", 22, Color(col.lightened(0.4), fl), 0)
		"bench":
			var seat := DrawUtil.diamond(p + Vector2(0, -18), 40, 14)
			draw_colored_polygon(seat, col)
			draw_line(p + Vector2(-30, -14), p + Vector2(-30, 0), Color("#5A3A28"), 4.0)
			draw_line(p + Vector2(30, -14), p + Vector2(30, 0), Color("#5A3A28"), 4.0)
			draw_line(p + Vector2(-40, -18), p + Vector2(-40, -40), col.darkened(0.2), 5.0)
			draw_line(p + Vector2(-40, -40), p + Vector2(0, -54), col.darkened(0.2), 5.0)
		"moon_lamp":
			draw_line(p, p + Vector2(0, -120), Color("#555A66"), 6.0)
			DrawUtil.glow(self, p + Vector2(0, -140), 80, Color(1.0, 0.95, 0.7, 0.6 + 0.1 * sin(anim_t * 2.0)))
			draw_circle(p + Vector2(0, -140), 26, col)
		_:
			draw_circle(p + Vector2(0, -20), 18, col)


func _draw_overhead() -> void:
	# 줄 조명
	var rows := [190.0, 372.0]
	for ri in rows.size():
		var y: float = rows[ri]
		var pa := Vector2(200, y)
		var pb := Vector2(520, y)
		var pts := PackedVector2Array()
		var n := 14
		for k in n + 1:
			var t := float(k) / n
			pts.append(pa.lerp(pb, t) + Vector2(0, sin(t * PI) * 30.0))
		draw_polyline(pts, Color("#1A1418"), 2.0, true)
		var colors := [Color("#FFB45C"), Color("#FF6F8E"), Color("#FFE08A"), Color("#7FD4E8")]
		for k in range(1, n):
			var c: Color = colors[(k + ri) % colors.size()]
			var fl := 0.7 + 0.3 * sin(anim_t * 3.0 + k * 1.3 + ri)
			DrawUtil.glow(self, pts[k] + Vector2(0, 6), 16, Color(c, 0.5 * fl), 3)
			draw_circle(pts[k] + Vector2(0, 6), 4.0, Color(c.lightened(0.3), fl))
	# 메인 입구 (위쪽) + 시장 간판
	var gy := 112.0
	for x in [272.0, 448.0]:
		draw_rect(Rect2(Vector2(x - 8, gy - 70), Vector2(16, 72)), Color("#7A2E2A"))
	var roof := PackedVector2Array([Vector2(238, gy - 64), Vector2(260, gy - 82), Vector2(360, gy - 90), Vector2(460, gy - 82),
		Vector2(482, gy - 64), Vector2(460, gy - 70), Vector2(360, gy - 76), Vector2(260, gy - 70)])
	draw_colored_polygon(roof, Color("#2C3346"))
	var sign_rect := Rect2(Vector2(296, gy - 62), Vector2(128, 38))
	var fl2 := 0.8 + 0.2 * sin(anim_t * 2.2)
	DrawUtil.rounded_rect(self, sign_rect.grow(6), 12, Color(1.0, 0.7, 0.36, 0.25 * fl2))
	DrawUtil.rounded_rect(self, sign_rect.grow(2), 9, Color("#FFB45C"))
	DrawUtil.rounded_rect(self, sign_rect, 7, Color("#2A1E2E"))
	DrawUtil.text_center(self, sign_rect.get_center() + Vector2(0, -5), "달빛장터", 20, Color("#FFF1B8"), 0)
	DrawUtil.text_center(self, sign_rect.get_center() + Vector2(0, 12), "MOONLIT MARKET", 9, Color("#FFB45C"), 0)
