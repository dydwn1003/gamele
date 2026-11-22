extends RefCounted
## 공용 UI 스타일: 어두운 나무 + 금테 판타지 톤. 모든 메뉴가 이 테마를 쓴다.

const Fx = preload("res://scripts/game/fx.gd")

const GOLD := Color(0.86, 0.7, 0.38)
const GOLD_DIM := Color(0.55, 0.45, 0.28)
const BG := Color(0.09, 0.075, 0.065, 0.97)
const BG2 := Color(0.18, 0.14, 0.11, 1.0)
const BG3 := Color(0.25, 0.19, 0.14, 1.0)
const TEXT := Color(0.96, 0.92, 0.84)
const TEXT_DIM := Color(0.7, 0.65, 0.58)
const GOOD := Color(0.5, 0.9, 0.45)
const BAD := Color(1.0, 0.45, 0.4)

static var _theme: Theme


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 10, border_w := 0, margin := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


## 그림 파일로 9-slice 스타일 (모서리는 그대로, 가운데만 늘어남)
static func tex_box(path: String, margin: float, content: Vector2, modulate := Color.WHITE) -> StyleBox:
	if not ResourceLoader.exists(path):
		return null
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.set_texture_margin_all(margin)
	s.content_margin_left = content.x
	s.content_margin_right = content.x
	s.content_margin_top = content.y
	s.content_margin_bottom = content.y
	s.modulate_color = modulate
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Fx.font()
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", box(BG, GOLD, 14, 3, 18))
	var panel_tex := tex_box("res://art/ui/panel.png", 44.0, Vector2(30, 28))
	if panel_tex:
		t.set_stylebox("panel", "PanelContainer", panel_tex)
	t.set_stylebox("panel", "Panel", box(BG2, GOLD_DIM, 10, 2, 10))
	t.set_stylebox("normal", "Button", box(BG2, GOLD_DIM, 9, 2, 10))
	t.set_stylebox("hover", "Button", box(BG3, GOLD, 9, 2, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.42, 0.31, 0.17), GOLD, 9, 2, 10))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.42, 0.31, 0.17), GOLD, 9, 2, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.12, 0.1, 0.09), Color(0.3, 0.27, 0.22), 9, 2, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var btn := tex_box("res://art/ui/button_normal.png", 24.0, Vector2(18, 8))
	if btn:
		t.set_stylebox("normal", "Button", btn)
		t.set_stylebox("hover", "Button", tex_box("res://art/ui/button_normal.png", 24.0, Vector2(18, 8), Color(1.25, 1.18, 1.05)))
		t.set_stylebox("pressed", "Button", tex_box("res://art/ui/button_pressed.png", 24.0, Vector2(18, 8), Color(1.3, 1.15, 0.9)))
		t.set_stylebox("hover_pressed", "Button", tex_box("res://art/ui/button_pressed.png", 24.0, Vector2(18, 8), Color(1.4, 1.25, 1.0)))
		t.set_stylebox("disabled", "Button", tex_box("res://art/ui/button_normal.png", 24.0, Vector2(18, 8), Color(0.45, 0.42, 0.4)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.6))
	t.set_color("font_hover_pressed_color", "Button", Color(1, 0.9, 0.6))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.38))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.6), GOLD_DIM, 4, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.85, 0.22, 0.2), Color(0, 0, 0, 0), 3, 0, 0))
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.6), GOLD_DIM, 4, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", box(GOLD_DIM, Color(0, 0, 0, 0), 4, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 4, 0, 4))
	_theme = t
	return t


static func button(text: String, min_size := Vector2(0, 52), font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", 0.0))
	return b


static func label(text: String, size := 22, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
