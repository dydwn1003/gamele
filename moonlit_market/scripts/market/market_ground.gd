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
	draw_polygon(PackedVector2Array([Vector2(-800, -1200), Vector2(1520, -1200), Vector2(1520, 140), Vector2(-800, 140)]),
		PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	for s in stars:
		var a := 0.35 + 0.35 * sin(anim_t * 1.5 + s.z)
		draw_circle(Vector2(s.x, s.y), 1.6, Color(1, 0.97, 0.9, a))
	# 달
	DrawUtil.glow(self, Vector2(612, 58), 90, Color(1.0, 0.95, 0.75, 0.5))
	draw_circle(Vector2(612, 58), 30, Color("#FFF1B8"))
	draw_circle(Vector2(602, 52), 6, Color(0.9, 0.85, 0.65, 0.5))
	# 한옥 지붕 실루엣
	var roof_col := Color("#191C2A")
	for i in 7:
		var cx := -60.0 + i * 140.0
		var top := 92.0 + (i % 2) * 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 90, top + 30), Vector2(cx - 60, top + 8), Vector2(cx, top),
			Vector2(cx + 60, top + 8), Vector2(cx + 90, top + 30), Vector2(cx + 70, top + 26), Vector2(cx + 70, 150), Vector2(cx - 70, 150), Vector2(cx - 70, top + 26)]), roof_col)
		# 창문 불빛
		draw_rect(Rect2(Vector2(cx - 20, top + 36), Vector2(14, 12)), Color(1, 0.75, 0.4, 0.35))
		draw_rect(Rect2(Vector2(cx + 8, top + 36), Vector2(14, 12)), Color(1, 0.75, 0.4, 0.25))
	# 광장 바닥
	var ground_col := Color("#2A2430")
	draw_rect(Rect2(Vector2(-800, 140), Vector2(2320, 1400)), ground_col)
	# 아이소메트릭 타일 격자
	var grid_col := Color(1, 1, 1, 0.045)
	var step := 64.0
	for i in range(-14, 26):
		var x0 := i * step
		draw_line(Vector2(x0 - 600, 140 - 300), Vector2(x0 + 1400, 140 + 700), grid_col, 2.0)
		draw_line(Vector2(x0 + 600, 140 - 300), Vector2(x0 - 1400, 140 + 700), grid_col, 2.0)
	# 조명 웅덩이 (노점 주변 따뜻한 빛)
	if market:
		for i in MarketScript.SLOT_POSITIONS.size():
			var p: Vector2 = MarketScript.SLOT_POSITIONS[i]
			DrawUtil.ellipse(self, p + Vector2(0, 10), 170, 90, Color(1.0, 0.6, 0.25, 0.06))
			DrawUtil.ellipse(self, p + Vector2(0, 10), 120, 62, Color(1.0, 0.65, 0.3, 0.06))
	# 중앙 통로
	var px0 := 282.0
	var px1 := 438.0
	draw_rect(Rect2(Vector2(px0, 150), Vector2(px1 - px0, 820)), Color("#3B3240"))
	var tile_h := 40.0
	for row in 21:
		var y := 150.0 + row * tile_h
		for col in 4:
			var cx := px0 + 19.5 + col * 39.0
			var shade := Color("#463C4B") if (row + col) % 2 == 0 else Color("#40364A")
			draw_colored_polygon(DrawUtil.diamond(Vector2(cx, y + tile_h / 2.0), 18, tile_h / 2.0 - 2), shade)
	draw_line(Vector2(px0, 150), Vector2(px0, 970), Color("#5A4A50"), 4.0)
	draw_line(Vector2(px1, 150), Vector2(px1, 970), Color("#5A4A50"), 4.0)
	# 손님 대기 구역 표시 (노점 앞 바닥 선)
	if market:
		for i in MarketScript.SLOT_POSITIONS.size():
			var q0: Vector2 = market.queue_spot(i, 0)
			var q1: Vector2 = market.queue_spot(i, 4)
			draw_line(q0 + Vector2(0, 14), q1 + Vector2(0, 14), Color(1, 0.71, 0.36, 0.12), 26.0)
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
	var rows := [218.0, 408.0, 598.0]
	for ri in rows.size():
		var y: float = rows[ri]
		var a := Vector2(196, y)
		var b := Vector2(524, y)
		var pts := PackedVector2Array()
		var n := 14
		for k in n + 1:
			var t := float(k) / n
			var sag := sin(t * PI) * 34.0
			pts.append(a.lerp(b, t) + Vector2(0, sag))
		draw_polyline(pts, Color("#1A1418"), 2.0, true)
		for k in range(1, n):
			var colors := [Color("#FFB45C"), Color("#FF6F8E"), Color("#FFE08A"), Color("#7FD4E8")]
			var c: Color = colors[(k + ri) % colors.size()]
			var fl := 0.7 + 0.3 * sin(anim_t * 3.0 + k * 1.3 + ri)
			DrawUtil.glow(self, pts[k] + Vector2(0, 6), 18, Color(c, 0.55 * fl), 3)
			draw_circle(pts[k] + Vector2(0, 6), 4.5, Color(c.lightened(0.3), fl))
	# 메인 입구 (게이트 + 시장 간판)
	var gy := 905.0
	var pillar := Color("#7A2E2A")
	for x in [262.0, 458.0]:
		draw_rect(Rect2(Vector2(x - 9, gy - 120), Vector2(18, 120)), pillar)
		draw_rect(Rect2(Vector2(x - 13, gy - 8), Vector2(26, 10)), Color("#3A2A2A"))
	# 기와 지붕
	var roof := PackedVector2Array([Vector2(226, gy - 112), Vector2(250, gy - 132), Vector2(360, gy - 142), Vector2(470, gy - 132),
		Vector2(494, gy - 112), Vector2(470, gy - 118), Vector2(360, gy - 126), Vector2(250, gy - 118)])
	draw_colored_polygon(roof, Color("#2C3346"))
	draw_rect(Rect2(Vector2(250, gy - 118), Vector2(220, 10)), Color("#4E2A2A"))
	# 간판
	var sign_rect := Rect2(Vector2(286, gy - 104), Vector2(148, 46))
	var fl2 := 0.8 + 0.2 * sin(anim_t * 2.2)
	DrawUtil.rounded_rect(self, sign_rect.grow(7), 14, Color(1.0, 0.7, 0.36, 0.25 * fl2))
	DrawUtil.rounded_rect(self, sign_rect.grow(2), 10, Color("#FFB45C"))
	DrawUtil.rounded_rect(self, sign_rect, 8, Color("#2A1E2E"))
	DrawUtil.text_center(self, sign_rect.get_center() + Vector2(0, -6), "달빛장터", 24, Color("#FFF1B8"), 0)
	DrawUtil.text_center(self, sign_rect.get_center() + Vector2(0, 14), "MOONLIT MARKET", 11, Color("#FFB45C"), 0)
	# 입구 등불
	for x in [262.0, 458.0]:
		var lp := Vector2(x, gy - 92)
		DrawUtil.glow(self, lp, 30, Color(1, 0.6, 0.3, 0.8))
		DrawUtil.ellipse(self, lp, 9, 11, Color("#E5483A"))
