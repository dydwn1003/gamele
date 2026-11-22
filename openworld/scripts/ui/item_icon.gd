extends Control
## 아이템 칸. 아이템 종류별 아이콘을 코드로 그린다 (검·갑옷·반지·물약·고기·가죽·광석 등).

const Items = preload("res://scripts/game/items.gd")

signal clicked(item_id: String)

var item_id := ""
var count := 0
var selected := false
var equipped := false
var enhance := 0

static var _tex_cache := {}


## res://art/ 아래 그림을 읽어온다 (없으면 null)
static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _init() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_item(id: String, n := 0) -> void:
	item_id = id
	count = n
	enhance = GameState.enhance_level(id) if id != "" else 0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item_id != "":
			Sfx.play("ui_click", 0.0)
			clicked.emit(item_id)
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rc := Items.rarity_color(item_id) if item_id != "" else Color(0.4, 0.35, 0.3)
	var slot := tex("res://art/ui/slot.png")
	if slot:
		draw_texture_rect(slot, r, false, Color(1, 1, 1, 1) if item_id != "" else Color(0.75, 0.75, 0.75))
		if item_id != "":
			draw_rect(r.grow(-3), Color(rc.r, rc.g, rc.b, 0.12))
			draw_style_box(_sb(Color(0, 0, 0, 0), rc, 3 if selected else 2), r.grow(-1))
	else:
		var bg := Color(0.14, 0.11, 0.09)
		if item_id != "":
			bg = bg.lerp(rc, 0.12)
		draw_style_box(_sb(bg, rc if item_id != "" else Color(0.3, 0.26, 0.2), 3 if selected else 2), r)
	if selected:
		draw_rect(r.grow(-2), Color(1, 0.9, 0.5, 0.15))
	if item_id == "":
		return
	var art := tex("res://art/icons/items/%s.png" % item_id)
	if art:
		draw_texture_rect(art, r.grow(-minf(size.x, size.y) * 0.1), false)
	else:
		draw_icon(self, item_id, r.get_center(), minf(size.x, size.y) * 0.36)
	var font := get_theme_default_font()
	if count > 1:
		draw_string_outline(font, Vector2(4, size.y - 6), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 18, 4, Color.BLACK)
		draw_string(font, Vector2(4, size.y - 6), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 18, Color.WHITE)
	if enhance > 0:
		draw_string_outline(font, Vector2(5, 20), "+%d" % enhance, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
		draw_string(font, Vector2(5, 20), "+%d" % enhance, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.85, 0.3))
	if equipped:
		draw_circle(Vector2(size.x - 13, 13), 10, Color(0.2, 0.55, 0.25))
		draw_string(font, Vector2(size.x - 23, 19), "E", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color.WHITE)


func _sb(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(8)
	return s


## 다른 화면(HUD 등)에서도 쓰는 아이콘 그리기
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var it := Items.get_item(id)
	var icon: String = it.get("icon", "")
	var col: Color = it.get("color", it.get("blade", it.get("tint", Color(0.8, 0.8, 0.8))))
	var dark := Color(0.15, 0.1, 0.08)
	match icon:
		"sword":
			var blade: Color = it.get("blade", Color(0.8, 0.8, 0.85))
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y, -d.x)
			var tip := c + d * s * 1.05
			var base := c - d * s * 0.35
			ci.draw_colored_polygon(PackedVector2Array([base + n * s * 0.14, tip, base - n * s * 0.14]), blade)
			ci.draw_line(base + n * s * 0.4, base - n * s * 0.4, Color(0.9, 0.7, 0.3), s * 0.14)
			ci.draw_line(base, c - d * s * 0.9, Color(0.4, 0.25, 0.15), s * 0.14)
			ci.draw_circle(c - d * s * 0.95, s * 0.1, Color(0.9, 0.7, 0.3))
		"armor":
			var tint: Color = it.get("tint", Color(0.5, 0.2, 0.2))
			var pts := PackedVector2Array([c + Vector2(-0.9, -0.7) * s, c + Vector2(-0.35, -0.85) * s, c + Vector2(0, -0.6) * s,
				c + Vector2(0.35, -0.85) * s, c + Vector2(0.9, -0.7) * s, c + Vector2(0.7, -0.2) * s,
				c + Vector2(0.6, 0.9) * s, c + Vector2(-0.6, 0.9) * s, c + Vector2(-0.7, -0.2) * s])
			ci.draw_colored_polygon(pts, tint.lightened(0.15))
			if it.get("plate", false):
				ci.draw_rect(Rect2(c + Vector2(-0.45, -0.45) * s, Vector2(0.9, 0.8) * s), Color(0.78, 0.8, 0.84))
			ci.draw_line(c + Vector2(-0.6, 0.55) * s, c + Vector2(0.6, 0.55) * s, Color(0.3, 0.2, 0.12), s * 0.14)
		"ring":
			ci.draw_arc(c + Vector2(0, 0.15) * s, s * 0.55, 0, TAU, 24, col, s * 0.2, true)
			ci.draw_circle(c + Vector2(0, -0.45) * s, s * 0.25, Color(0.6, 0.9, 1.0) if id != "ring_ember" else Color(1, 0.45, 0.2))
		"amulet":
			ci.draw_arc(c + Vector2(0, -0.3) * s, s * 0.6, PI * 0.1, PI * 0.9, 16, Color(0.6, 0.45, 0.3), s * 0.1, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, 0.2) * s, c + Vector2(0.2, 0.2) * s, c + Vector2(0, 0.95) * s]), col)
		"potion":
			ci.draw_circle(c + Vector2(0, 0.25) * s, s * 0.62, col)
			ci.draw_circle(c + Vector2(-0.2, 0.05) * s, s * 0.15, Color(1, 1, 1, 0.5))
			ci.draw_rect(Rect2(c + Vector2(-0.2, -0.85) * s, Vector2(0.4, 0.55) * s), Color(0.75, 0.85, 0.9, 0.9))
			ci.draw_rect(Rect2(c + Vector2(-0.26, -1.0) * s, Vector2(0.52, 0.22) * s), Color(0.55, 0.38, 0.22))
		"meat":
			ci.draw_circle(c + Vector2(0.15, -0.1) * s, s * 0.6, col)
			ci.draw_line(c + Vector2(-0.3, 0.3) * s, c + Vector2(-0.9, 0.9) * s, Color(0.95, 0.92, 0.85), s * 0.2)
			ci.draw_circle(c + Vector2(-0.9, 0.9) * s, s * 0.15, Color(0.95, 0.92, 0.85))
		"ear":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.6, 0.6) * s, c + Vector2(0.9, -0.9) * s, c + Vector2(0.3, 0.7) * s]), col)
		"pelt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, -0.6) * s, c + Vector2(0, -0.8) * s, c + Vector2(0.8, -0.6) * s,
				c + Vector2(0.6, 0.8) * s, c + Vector2(0, 0.6) * s, c + Vector2(-0.6, 0.8) * s]), col)
		"tusk":
			ci.draw_arc(c + Vector2(0.3, 0.3) * s, s * 0.8, PI, PI * 1.6, 16, col, s * 0.28, true)
		"bone":
			ci.draw_line(c + Vector2(-0.6, 0.6) * s, c + Vector2(0.6, -0.6) * s, col, s * 0.25)
			for p in [Vector2(-0.7, 0.45), Vector2(-0.45, 0.7), Vector2(0.7, -0.45), Vector2(0.45, -0.7)]:
				ci.draw_circle(c + p * s, s * 0.18, col)
		"herb":
			for a in [-0.6, 0.0, 0.6]:
				var d := Vector2(sin(a), -cos(a))
				ci.draw_line(c + Vector2(0, 0.8) * s, c + d * s * 0.7, Color(0.3, 0.6, 0.25), s * 0.18)
				ci.draw_circle(c + d * s * 0.75, s * 0.18, Color(0.95, 0.3, 0.4))
		"ore":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, 0.5) * s, c + Vector2(-0.4, -0.6) * s, c + Vector2(0.5, -0.7) * s,
				c + Vector2(0.85, 0.3) * s, c + Vector2(0.2, 0.75) * s]), Color(0.45, 0.42, 0.42))
			ci.draw_circle(c + Vector2(0.1, -0.1) * s, s * 0.2, Color(0.95, 0.75, 0.35))
			ci.draw_circle(c + Vector2(-0.35, 0.25) * s, s * 0.13, Color(0.95, 0.75, 0.35))
		"core":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.9) * s, c + Vector2(0.7, 0) * s, c + Vector2(0, 0.9) * s, c + Vector2(-0.7, 0) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.45) * s, c + Vector2(0.35, 0) * s, c + Vector2(0, 0.45) * s, c + Vector2(-0.35, 0) * s]), Color(1, 1, 1, 0.7))
		"horn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, 0.8) * s, c + Vector2(0.1, 0.8) * s, c + Vector2(0.8, -0.9) * s]), col)
		_:
			ci.draw_circle(c, s * 0.6, col)
	if icon == "":
		ci.draw_circle(c, s * 0.3, dark)
