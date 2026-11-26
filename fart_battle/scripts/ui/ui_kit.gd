extends RefCounted
## UIKit — 방귀 대결 디자인 시스템 (색/글꼴/버튼/패널 공통).
## 모든 화면은 이 파일의 색상/글꼴/버튼/패널/재화 칩을 재사용한다 (화면별 임의 디자인 금지).

const IconScript := preload("res://scripts/ui/icon.gd")

# ── 색상 토큰 ──
const BG := Color("#2A2138")
const PANEL := Color("#3A2E4F")
const PANEL_LIGHT := Color("#4A3D63")
const PANEL_DARK := Color("#221A2E")
const ACCENT := Color("#FFD25F")
const ACCENT_DARK := Color("#D9A62F")
const SECONDARY := Color("#FF5FD2")
const SUCCESS := Color("#7BE85F")
const DANGER := Color("#E5564A")
const TEXT := Color("#FFF5E9")
const TEXT_SUB := Color("#B9B5B0")
const TEXT_DARK := Color("#2A1A0C")
const LINE := Color("#55476E")
const REP := Color("#5FE8FF")

# ── 텍스트 계층 (기준 해상도 720x1280) ──
const FS_TITLE := 36
const FS_SECTION := 29
const FS_BODY := 25
const FS_CAPTION := 21
const FS_NUMBER := 30

const RADIUS := 18
const BUTTON_HEIGHT := 84

static var _font: Font = null
static var _bold: Font = null


## 한국어 글꼴: assets/fonts 에 TTF/OTF 가 있으면 사용, 없으면 OS 시스템 글꼴(Noto Sans CJK 등).
static func font() -> Font:
	if _font == null:
		_font = _make_font(400)
	return _font


static func bold_font() -> Font:
	if _bold == null:
		_bold = _make_font(700)
	return _bold


static func _make_font(weight: int) -> Font:
	for p in ["res://assets/fonts/main_bold.ttf" if weight >= 700 else "res://assets/fonts/main.ttf",
			"res://assets/fonts/main.ttf", "res://assets/fonts/main.otf"]:
		if ResourceLoader.exists(p):
			var f = load(p)
			if f is Font:
				return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo",
		"Malgun Gothic", "NanumGothic", "NanumBarunGothic", "Source Han Sans KR", "Droid Sans Fallback", "sans-serif"])
	sf.font_weight = weight
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	sf.allow_system_fallback = true
	return sf


static func box(color: Color, radius: int = RADIUS, margin: int = 16, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	return sb


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FS_BODY
	# Label
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FS_BODY)
	# Button
	var normal := box(ACCENT, RADIUS, 14)
	var hover := box(ACCENT.lightened(0.08), RADIUS, 14)
	var pressed := box(ACCENT_DARK, RADIUS, 14)
	var disabled := box(Color("#4A4F5C"), RADIUS, 14)
	var focus := box(Color(0, 0, 0, 0), RADIUS, 14, TEXT, 2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT_DARK)
	t.set_color("font_hover_color", "Button", TEXT_DARK)
	t.set_color("font_pressed_color", "Button", TEXT_DARK)
	t.set_color("font_focus_color", "Button", TEXT_DARK)
	t.set_color("font_disabled_color", "Button", Color("#9A9BA2"))
	t.set_font_size("font_size", "Button", FS_BODY)
	t.set_font("font", "Button", bold_font())
	# Panel
	t.set_stylebox("panel", "PanelContainer", box(PANEL, RADIUS, 18))
	t.set_stylebox("panel", "Panel", box(PANEL, RADIUS, 0))
	# OptionButton / PopupMenu
	t.set_stylebox("normal", "OptionButton", box(PANEL_LIGHT, 12, 12))
	t.set_stylebox("hover", "OptionButton", box(PANEL_LIGHT.lightened(0.06), 12, 12))
	t.set_stylebox("pressed", "OptionButton", box(PANEL_DARK, 12, 12))
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), 12, 12, ACCENT, 2))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", TEXT)
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_color("font_focus_color", "OptionButton", TEXT)
	t.set_font_size("font_size", "OptionButton", FS_BODY)
	t.set_stylebox("panel", "PopupMenu", box(PANEL_LIGHT, 12, 10))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT, 8, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT_DARK)
	t.set_font_size("font_size", "PopupMenu", FS_BODY)
	t.set_constant("v_separation", "PopupMenu", 18)
	# Slider
	t.set_stylebox("slider", "HSlider", box(PANEL_DARK, 8, 6))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT_DARK, 8, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 8, 6))
	t.set_icon("grabber", "HSlider", _circle_texture(34, ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(38, ACCENT.lightened(0.15)))
	# CheckButton 대체: 토글 버튼 사용. ScrollContainer 스크롤바
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.15), 6, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.18), 6, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.3), 6, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, 6, 0))
	# 툴팁
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_LIGHT, 10, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t


static func _circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if d <= r - 1.0:
				img.set_pixel(x, y, color)
			elif d <= r:
				img.set_pixel(x, y, Color(color, r - d))
	return ImageTexture.create_from_image(img)


# ───────── 컴포넌트 ─────────

static func label(text: String, level: String = "body", color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	match level:
		"title":
			l.add_theme_font_size_override("font_size", FS_TITLE)
			l.add_theme_font_override("font", bold_font())
		"section":
			l.add_theme_font_size_override("font_size", FS_SECTION)
			l.add_theme_font_override("font", bold_font())
		"caption":
			l.add_theme_font_size_override("font_size", FS_CAPTION)
			if color == TEXT:
				l.add_theme_color_override("font_color", TEXT_SUB)
		"number":
			l.add_theme_font_size_override("font_size", FS_NUMBER)
			l.add_theme_font_override("font", bold_font())
		_:
			l.add_theme_font_size_override("font_size", FS_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if level in ["body", "caption"] else TextServer.AUTOWRAP_OFF
	return l


## variant: primary / secondary / success / danger / ghost
static func button(text: String, variant: String = "primary", min_height: int = BUTTON_HEIGHT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var base := ACCENT
	var fg := TEXT_DARK
	match variant:
		"secondary":
			base = PANEL_LIGHT
			fg = TEXT
		"success":
			base = SUCCESS
			fg = TEXT_DARK
		"danger":
			base = DANGER
			fg = TEXT
		"ghost":
			base = Color(1, 1, 1, 0.06)
			fg = TEXT
	if variant != "primary":
		b.add_theme_stylebox_override("normal", box(base, RADIUS, 14))
		b.add_theme_stylebox_override("hover", box(base.lightened(0.08), RADIUS, 14))
		b.add_theme_stylebox_override("pressed", box(base.darkened(0.2), RADIUS, 14))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, fg)
	# 중복 클릭 방지: 누른 직후 잠시 비활성화
	b.pressed.connect(func(): _debounce(b))
	return b


static func _debounce(b: Button) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	var was_disabled := b.disabled
	b.disabled = true
	var tree := b.get_tree()
	await tree.create_timer(0.35).timeout
	if is_instance_valid(b) and not was_disabled and not b.has_meta("keep_disabled"):
		b.disabled = false


## 버튼의 활성 상태를 설정 (debounce 와 충돌하지 않도록)
static func set_enabled(b: Button, enabled: bool) -> void:
	if enabled:
		b.remove_meta("keep_disabled")
	else:
		b.set_meta("keep_disabled", true)
	b.disabled = not enabled


static func card(color: Color = PANEL_LIGHT, margin: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, RADIUS, margin))
	return p


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func icon(kind: String, size: int = 36, color: Color = Color(0, 0, 0, 0)) -> Control:
	var ic = IconScript.new()
	ic.kind = kind
	ic.custom_minimum_size = Vector2(size, size)
	if color.a > 0.0:
		ic.tint = color
	return ic


## 재화 표시 공통 컴포넌트 (코인/평판/가격)
static func currency(kind: String, amount: int, size: String = "body") -> HBoxContainer:
	var h := hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	var icon_size := 34 if size == "number" else 28
	h.add_child(icon(kind, icon_size))
	var l := label(fmt(amount), size, REP if kind == "rep" else ACCENT)
	l.name = "Amount"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


static func set_currency(chip: HBoxContainer, amount: int) -> void:
	var l := chip.get_node_or_null("Amount") as Label
	if l:
		l.text = fmt(amount)


static func fmt(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + out


static func pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


static func separator() -> Control:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(0, 2)
	return c


## 진행 막대
static func progress_bar(value: float, max_value: float, color: Color = ACCENT, height: int = 14) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = maxf(1.0, max_value)
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.add_theme_stylebox_override("background", box(PANEL_DARK, height / 2, 0))
	p.add_theme_stylebox_override("fill", box(color, height / 2, 0))
	return p
