extends RefCounted
## 시장 월드용 공통 드로잉 헬퍼 (도형 기반 Stylized 그래픽)

const UIKit := preload("res://scripts/ui/ui_kit.gd")


static func ellipse(ci: CanvasItem, pos: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 24
	for i in n:
		var a := TAU * i / n
		pts.append(pos + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func glow(ci: CanvasItem, pos: Vector2, r: float, col: Color, layers: int = 4) -> void:
	for i in layers:
		var rr := r * (1.0 - float(i) / layers * 0.75)
		ci.draw_circle(pos, rr, Color(col, col.a * 0.14))
	ci.draw_circle(pos, r * 0.22, Color(col, minf(1.0, col.a)))


## 아이소메트릭 마름모 (중심, 반폭, 반높이)
static func diamond(center: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -hh), center + Vector2(hw, 0), center + Vector2(0, hh), center + Vector2(-hw, 0)])


static func text_center(ci: CanvasItem, center: Vector2, text: String, size: int, col: Color, outline: int = 0, outline_col: Color = Color(0, 0, 0, 0.75), bold: bool = true) -> void:
	var f: Font = UIKit.bold_font() if bold else UIKit.font()
	var w := 400.0
	var pos := Vector2(center.x - w / 2.0, center.y + size * 0.36)
	if outline > 0:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, outline_col)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


static func rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	ci.draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - 2 * r, rect.size.y)), col)
	ci.draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - 2 * r)), col)
	ci.draw_circle(rect.position + Vector2(r, r), r, col)
	ci.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, col)
	ci.draw_circle(rect.position + Vector2(r, rect.size.y - r), r, col)
	ci.draw_circle(rect.position + rect.size - Vector2(r, r), r, col)


## 메뉴 카테고리 아이콘 (손님 말풍선/노점 카운터용)
static func food_icon(ci: CanvasItem, category: String, pos: Vector2, r: float, col: Color = Color("#E97858")) -> void:
	match category:
		"meal":
			# 그릇 + 김
			var bowl := PackedVector2Array([pos + Vector2(-r, -r * 0.1), pos + Vector2(r, -r * 0.1), pos + Vector2(r * 0.6, r * 0.7), pos + Vector2(-r * 0.6, r * 0.7)])
			ci.draw_colored_polygon(bowl, Color("#F4F1EA"))
			ci.draw_rect(Rect2(pos + Vector2(-r, -r * 0.3), Vector2(r * 2, r * 0.25)), col)
			ci.draw_line(pos + Vector2(-r * 0.3, -r * 0.5), pos + Vector2(-r * 0.2, -r), Color(1, 1, 1, 0.7), 2.0)
			ci.draw_line(pos + Vector2(r * 0.25, -r * 0.5), pos + Vector2(r * 0.35, -r), Color(1, 1, 1, 0.7), 2.0)
		"snack":
			# 꼬치/떡
			ci.draw_line(pos + Vector2(-r, r), pos + Vector2(r, -r), Color("#C9A36B"), maxf(2.0, r * 0.18))
			for k in 3:
				ci.draw_circle(pos + Vector2(-r * 0.45 + k * r * 0.45, r * 0.45 - k * r * 0.45), r * 0.32, col)
		"drink":
			var cup := PackedVector2Array([pos + Vector2(-r * 0.6, -r * 0.6), pos + Vector2(r * 0.6, -r * 0.6), pos + Vector2(r * 0.45, r), pos + Vector2(-r * 0.45, r)])
			ci.draw_colored_polygon(cup, col)
			ci.draw_rect(Rect2(pos + Vector2(-r * 0.7, -r * 0.75), Vector2(r * 1.4, r * 0.2)), Color("#F4F1EA"))
			ci.draw_line(pos + Vector2(r * 0.1, -r * 0.75), pos + Vector2(r * 0.35, -r * 1.2), Color("#F4F1EA"), 2.0)
		"dessert":
			var cone := PackedVector2Array([pos + Vector2(-r * 0.5, 0), pos + Vector2(r * 0.5, 0), pos + Vector2(0, r)])
			ci.draw_colored_polygon(cone, Color("#D9A35A"))
			ci.draw_circle(pos + Vector2(0, -r * 0.2), r * 0.55, col)
		_:
			ci.draw_circle(pos, r * 0.7, col)


## 말풍선
static func bubble(ci: CanvasItem, pos: Vector2, w: float, h: float, col: Color = Color("#FFF5E9")) -> void:
	rounded_rect(ci, Rect2(pos - Vector2(w / 2.0, h), Vector2(w, h)), h * 0.45, col)
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-6, -1), pos + Vector2(6, -1), pos + Vector2(0, 8)]), col)
