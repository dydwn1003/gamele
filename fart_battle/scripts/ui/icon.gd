extends Control
## 벡터로 그리는 UI 아이콘 (이모지/외부 이미지 미사용)
## kind: coin, rep, gem, settings, market, staff, deco, shop, clock, sun, rain, cloud,
##       people, heart, lock, check, star, build, close, speed, stock, event

var kind: String = "coin":
	set(v):
		kind = v
		queue_redraw()
var tint: Color = Color(0, 0, 0, 0):
	set(v):
		tint = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _col(default_color: Color) -> Color:
	return tint if tint.a > 0.0 else default_color


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.45
	match kind:
		"coin":
			draw_circle(c, r, _col(Color("#FFB45C")))
			draw_circle(c, r * 0.72, Color("#E8973A"))
			draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.5, Color("#FFD08A"))
			draw_arc(c, r, 0, TAU, 32, Color("#9A5A1C"), maxf(1.5, s * 0.05), true)
		"rep":
			# 초승달 + 별 (평판)
			draw_circle(c, r, _col(Color("#C9A0FF")))
			draw_circle(c + Vector2(r * 0.38, -r * 0.25), r * 0.82, Color("#3A2F55"))
			_star(c + Vector2(r * 0.35, r * 0.1), r * 0.32, Color("#FFF1B8"))
		"gem":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.85, -r * 0.2)])
			draw_colored_polygon(pts, _col(Color("#6FD3E8")))
			draw_line(c + Vector2(-r * 0.85, -r * 0.2), c + Vector2(r * 0.85, -r * 0.2), Color(1, 1, 1, 0.6), 2.0)
		"settings":
			var col := _col(Color("#FFF5E9"))
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2.from_angle(a) * r * 0.55, c + Vector2.from_angle(a) * r, col, s * 0.16)
			draw_circle(c, r * 0.62, col)
			draw_circle(c, r * 0.28, Color("#252A35"))
		"market":
			var col := _col(Color("#FFB45C"))
			var roof := PackedVector2Array([c + Vector2(-r, -r * 0.1), c + Vector2(0, -r * 0.85), c + Vector2(r, -r * 0.1)])
			draw_colored_polygon(roof, col)
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.1), Vector2(r * 1.5, r * 0.95)), col.darkened(0.25))
			draw_rect(Rect2(c + Vector2(-r * 0.25, r * 0.25), Vector2(r * 0.5, r * 0.6)), Color("#252A35"))
		"staff":
			var col := _col(Color("#FFF5E9"))
			draw_circle(c + Vector2(0, -r * 0.4), r * 0.38, col)
			var body := PackedVector2Array([c + Vector2(-r * 0.75, r), c + Vector2(-r * 0.55, r * 0.15), c + Vector2(r * 0.55, r * 0.15), c + Vector2(r * 0.75, r)])
			draw_colored_polygon(body, col)
			draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.95), Vector2(r * 0.9, r * 0.25)), Color("#FFB45C"))
		"deco":
			var col := _col(Color("#E5483A"))
			draw_line(c + Vector2(0, -r), c + Vector2(0, -r * 0.6), Color("#B9B5B0"), 2.0)
			draw_circle(c + Vector2(0, r * 0.05), r * 0.62, col)
			draw_rect(Rect2(c + Vector2(-r * 0.35, -r * 0.7), Vector2(r * 0.7, r * 0.18)), Color("#2A1A0C"))
			draw_rect(Rect2(c + Vector2(-r * 0.35, r * 0.6), Vector2(r * 0.7, r * 0.18)), Color("#2A1A0C"))
			draw_circle(c + Vector2(-r * 0.15, -r * 0.1), r * 0.18, Color(1, 0.9, 0.6, 0.7))
		"shop":
			var col := _col(Color("#FFF5E9"))
			var bag := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r * 0.65, r), c + Vector2(-r * 0.65, r)])
			draw_colored_polygon(bag, col)
			draw_arc(c + Vector2(0, -r * 0.3), r * 0.42, PI, TAU, 16, col, s * 0.08, true)
			draw_circle(c + Vector2(0, r * 0.3), r * 0.18, Color("#FFB45C"))
		"clock":
			var col := _col(Color("#FFF5E9"))
			draw_arc(c, r * 0.9, 0, TAU, 32, col, s * 0.09, true)
			draw_line(c, c + Vector2(0, -r * 0.55), col, s * 0.08)
			draw_line(c, c + Vector2(r * 0.4, 0), col, s * 0.08)
		"sun":
			var col := _col(Color("#FFD27A"))
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2.from_angle(a) * r * 0.62, c + Vector2.from_angle(a) * r, col, s * 0.08)
			draw_circle(c, r * 0.48, col)
		"cloud":
			var col := _col(Color("#C9CDD8"))
			_cloud(c, r, col)
		"rain":
			var col := _col(Color("#8EB7E8"))
			_cloud(c + Vector2(0, -r * 0.2), r * 0.85, Color("#A7AFC0"))
			for i in 3:
				var x := (i - 1) * r * 0.45
				draw_line(c + Vector2(x, r * 0.35), c + Vector2(x - r * 0.12, r * 0.85), col, s * 0.07)
		"people":
			var col := _col(Color("#FFF5E9"))
			draw_circle(c + Vector2(-r * 0.35, -r * 0.3), r * 0.28, col)
			draw_circle(c + Vector2(r * 0.4, -r * 0.2), r * 0.24, col.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, r * 0.9), c + Vector2(-r * 0.6, r * 0.05), c + Vector2(-r * 0.1, r * 0.05), c + Vector2(r * 0.15, r * 0.9)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.05, r * 0.9), c + Vector2(r * 0.2, r * 0.15), c + Vector2(r * 0.6, r * 0.15), c + Vector2(r * 0.85, r * 0.9)]), col.darkened(0.15))
		"heart":
			var col := _col(Color("#FF6F8E"))
			draw_circle(c + Vector2(-r * 0.32, -r * 0.2), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.32, -r * 0.2), r * 0.42, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.72, -r * 0.02), c + Vector2(r * 0.72, -r * 0.02), c + Vector2(0, r * 0.85)]), col)
		"lock":
			var col := _col(Color("#B9B5B0"))
			draw_arc(c + Vector2(0, -r * 0.15), r * 0.42, PI, TAU, 16, col, s * 0.1, true)
			draw_line(c + Vector2(-r * 0.42, -r * 0.15), c + Vector2(-r * 0.42, r * 0.05), col, s * 0.1)
			draw_line(c + Vector2(r * 0.42, -r * 0.15), c + Vector2(r * 0.42, r * 0.05), col, s * 0.1)
			draw_rect(Rect2(c + Vector2(-r * 0.65, 0), Vector2(r * 1.3, r * 0.9)), col)
		"check":
			var col := _col(Color("#65C99A"))
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(-r * 0.15, r * 0.45), c + Vector2(r * 0.65, -r * 0.45)]), col, s * 0.14, true)
		"star":
			_star(c, r, _col(Color("#FFD27A")))
		"build":
			var col := _col(Color("#FFF5E9"))
			draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.3, -r * 0.3), col, s * 0.14)
			draw_rect(Rect2(c + Vector2(r * 0.05, -r * 0.85), Vector2(r * 0.8, r * 0.45)), col)
		"close":
			var col := _col(Color("#FFF5E9"))
			draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, r * 0.55), col, s * 0.12)
			draw_line(c + Vector2(r * 0.55, -r * 0.55), c + Vector2(-r * 0.55, r * 0.55), col, s * 0.12)
		"speed":
			var col := _col(Color("#FFF5E9"))
			for k in 2:
				var o := Vector2((k - 0.5) * r * 0.8, 0)
				draw_colored_polygon(PackedVector2Array([c + o + Vector2(-r * 0.4, -r * 0.6), c + o + Vector2(r * 0.4, 0), c + o + Vector2(-r * 0.4, r * 0.6)]), col)
		"stock":
			var col := _col(Color("#E8C27A"))
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.4), Vector2(r * 1.6, r * 1.2)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.65), Vector2(r * 1.8, r * 0.3)), col.darkened(0.2))
			draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.8), col.darkened(0.35), 2.0)
		"event":
			var col := _col(Color("#FFB45C"))
			_star(c, r, col)
			draw_circle(c, r * 0.25, Color("#FFF5E9"))
		_:
			draw_circle(c, r, _col(Color("#FFB45C")))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(a) * rr)
	draw_colored_polygon(pts, col)


func _cloud(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.4, r * 0.1), r * 0.42, col)
	draw_circle(c + Vector2(r * 0.1, -r * 0.15), r * 0.55, col)
	draw_circle(c + Vector2(r * 0.55, r * 0.15), r * 0.38, col)
	draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.1), Vector2(r * 0.95, r * 0.42)), col)
