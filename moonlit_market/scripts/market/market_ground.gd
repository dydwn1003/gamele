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
	# ── 거리 ──
	var sky_top := Color("#0F1220")
	var sky_bottom := Color("#262338")
	draw_polygon(PackedVector2Array([Vector2(-800, -1200), Vector2(1520, -1200), Vector2(1520, 200), Vector2(-800, 200)]),
		PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	for s in stars:
		var a := 0.35 + 0.35 * sin(anim_t * 1.5 + s.z)
		draw_circle(Vector2(s.x, 6 + s.y * 0.15 + 40), 1.5, Color(1, 0.97, 0.9, a))
	DrawUtil.glow(self, Vector2(640, 36), 70, Color(1.0, 0.95, 0.75, 0.45))
	draw_circle(Vector2(640, 36), 20, Color("#FFF1B8"))
	# 먼 건물 실루엣
	for i in 9:
		var bx := -40.0 + i * 92.0
		var bh := 60.0 + float((i * 37) % 40)
		draw_rect(Rect2(Vector2(bx, 70 - bh * 0.4), Vector2(80, bh)), Color("#1B1E2C"))
		for k in 3:
			draw_rect(Rect2(Vector2(bx + 12 + k * 22, 80 - bh * 0.4 + 8), Vector2(10, 8)), Color(1, 0.75, 0.4, 0.25 + 0.1 * (k % 2)))
	# 보도 + 길
	draw_rect(Rect2(Vector2(-800, 200), Vector2(2320, 80)), Color("#3B3240"))
	for i in 24:
		var x := -60.0 + i * 36.0
		draw_line(Vector2(x, 200), Vector2(x - 14, 280), Color(1, 1, 1, 0.05), 2.0)
	draw_line(Vector2(-800, 212), Vector2(1520, 212), Color(1, 1, 1, 0.08), 2.0)
	# 드럼통 테이블 (경쟁 노점 손님이 먹는 곳)
	for t in MarketScript.STREET_TABLES:
		DrawUtil.ellipse(self, t + Vector2(0, 6), 26, 8, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(t + Vector2(-17, -22), Vector2(34, 26)), Color("#4D6C8A"))
		for k in 3:
			draw_line(t + Vector2(-17, -15 + k * 8), t + Vector2(17, -15 + k * 8), Color("#3A5570"), 2.0)
		DrawUtil.ellipse(self, t + Vector2(0, -22), 21, 7, Color("#6B8BAA"))
	# ── 포차 내부 ──
	# 뒷벽 (천막 안쪽)
	draw_rect(Rect2(Vector2(-800, 280), Vector2(2320, 180)), Color("#5A2E1C"))
	draw_rect(Rect2(Vector2(-800, 280), Vector2(2320, 180)), Color(1.0, 0.55, 0.2, 0.18))
	for i in 18:
		draw_line(Vector2(-20 + i * 44, 280), Vector2(-20 + i * 44, 460), Color(0, 0, 0, 0.08), 3.0)
	# 메뉴판 (메뉴판에 올린 메뉴와 가격)
	var menus: Array = GameManager.state.enabled_menus()
	var n := menus.size()
	for i in n:
		var mx := 360.0 + (i - (n - 1) / 2.0) * minf(84.0, 640.0 / maxf(1, n))
		var r := Rect2(Vector2(mx - 36, 322), Vector2(72, 92))
		draw_line(Vector2(mx, 304), r.position + Vector2(36, 0), Color("#3A2418"), 2.0)
		DrawUtil.rounded_rect(self, r, 6, Color("#E8C99A"))
		DrawUtil.rounded_rect(self, r.grow(-4), 4, Color("#F4E2C0"))
		var m: Dictionary = DataManager.get_menu(str(menus[i]))
		DrawUtil.menu_icon(self, m, r.position + Vector2(36, 26), 12)
		DrawUtil.text_center(self, r.position + Vector2(36, 56), str(m.get("name", "")), 13, Color("#3A2418"), 0)
		DrawUtil.text_center(self, r.position + Vector2(36, 76), "%d" % GameManager.economy.unit_price(str(menus[i])), 15, Color("#B8443A"), 0)
	# 바닥
	draw_rect(Rect2(Vector2(-800, 456), Vector2(2320, 400)), Color("#463A3A"))
	for i in 16:
		var y := 470.0 + i * 22.0
		draw_line(Vector2(-800, y), Vector2(1520, y), Color(0, 0, 0, 0.06), 2.0)
	DrawUtil.ellipse(self, Vector2(360, 560), 380, 120, Color(1.0, 0.7, 0.35, 0.10))
	# 통로 표시
	draw_rect(Rect2(Vector2(-800, 582), Vector2(2320, 36)), Color(0, 0, 0, 0.10))
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
			if false:
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
	# 거리 줄 조명
	var pa := Vector2(-20, 150)
	var pb := Vector2(740, 150)
	var pts := PackedVector2Array()
	var n := 22
	for k in n + 1:
		var t := float(k) / n
		pts.append(pa.lerp(pb, t) + Vector2(0, sin(t * PI * 3.0) * 10.0 + 8))
	draw_polyline(pts, Color("#1A1418"), 2.0, true)
	var colors := [Color("#FFB45C"), Color("#FF6F8E"), Color("#FFE08A"), Color("#7FD4E8")]
	for k in range(1, n):
		var c: Color = colors[k % colors.size()]
		var fl := 0.7 + 0.3 * sin(anim_t * 3.0 + k * 1.3)
		DrawUtil.glow(self, pts[k] + Vector2(0, 5), 14, Color(c, 0.45 * fl), 3)
		draw_circle(pts[k] + Vector2(0, 5), 3.5, Color(c.lightened(0.3), fl))
	# 포차 천막 앞 처마 (입구 가운데)
	var tarp := Color("#E8742E")
	draw_rect(Rect2(Vector2(-800, 268), Vector2(2320, 16)), tarp.darkened(0.25))
	for k in 30:
		var x0 := -40.0 + k * 28.0
		if absf(x0 + 14.0 - 360.0) < 44.0:
			continue
		var col := tarp if k % 2 == 0 else Color("#F7C04A")
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 282), Vector2(x0 + 28, 282), Vector2(x0 + 25, 304), Vector2(x0 + 3, 304)]), col)
	# 입구 비닐 커튼
	for k in 4:
		var cx := 326.0 + k * 22.0
		draw_rect(Rect2(Vector2(cx, 284), Vector2(16, 22)), Color(0.85, 0.92, 1.0, 0.18))
	# 포차 간판
	var sign_rect := Rect2(Vector2(290, 236), Vector2(140, 34))
	var fl2 := 0.8 + 0.2 * sin(anim_t * 2.4)
	DrawUtil.rounded_rect(self, sign_rect.grow(6), 12, Color(1.0, 0.6, 0.3, 0.3 * fl2))
	DrawUtil.rounded_rect(self, sign_rect.grow(2), 9, Color("#FFB45C"))
	DrawUtil.rounded_rect(self, sign_rect, 7, Color("#2A1E2E"))
	DrawUtil.text_center(self, sign_rect.get_center(), "달빛포차 Lv.%d" % GameManager.state.pocha_level(), 18, Color("#FFF1B8"), 0)
	# 포차 안 전구 줄
	var bulbs: int = 9 + GameManager.state.pocha_level() * 2
	for k in bulbs:
		var t2 := float(k) / (bulbs - 1)
		var p := Vector2(lerpf(20, 700, t2), 316 + sin(t2 * PI * 2.0) * 6)
		var f := 0.75 + 0.25 * sin(anim_t * 3.0 + k)
		DrawUtil.glow(self, p, 16, Color(1.0, 0.8, 0.45, 0.55 * f), 3)
		draw_circle(p, 4, Color(1.0, 0.92, 0.7, f))
