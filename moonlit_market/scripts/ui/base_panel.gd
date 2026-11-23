extends Control
## BasePanel — 모든 화면 패널의 공통 틀 (바텀 시트 + 제목 + 닫기 + 스크롤 본문 + 하단 버튼 영역).
## 하위 패널은 build() 만 구현한다. 상태가 바뀌면 refresh() 로 다시 그린다.

const UIKit := preload("res://scripts/ui/ui_kit.gd")

var panel_id: String = ""
var ui ## ui_manager
var args: Dictionary = {}
var title_text: String = ""
var sheet_ratio: float = 0.84 ## 화면 높이 대비 시트 높이 (1.0 = 전체)
var auto_refresh: bool = true
var dismiss_on_dim: bool = true
var centered: bool = false

var dim: ColorRect
var sheet: PanelContainer
var title_label: Label
var close_button: Button
var scroll: ScrollContainer
var content: VBoxContainer
var footer: HBoxContainer
var _margin: MarginContainer
var _refresh_queued: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_configure()
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	sheet = PanelContainer.new()
	var sb := UIKit.box(UIKit.PANEL, 28, 0)
	if not centered:
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 18
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	_margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 24)
	sheet.add_child(_margin)
	var col := UIKit.vbox(14)
	_margin.add_child(col)
	var header := UIKit.hbox(12)
	col.add_child(header)
	title_label = UIKit.label(title_text, "title")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title_label)
	close_button = UIKit.button("", "secondary", 72)
	close_button.custom_minimum_size = Vector2(72, 72)
	var x := UIKit.icon("close", 30)
	close_button.add_child(x)
	x.position = Vector2(21, 21)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	close_button.visible = dismiss_on_dim
	col.add_child(UIKit.separator())
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_deadzone = 14
	col.add_child(scroll)
	content = UIKit.vbox(16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	footer = UIKit.hbox(12)
	col.add_child(footer)
	if auto_refresh:
		GameManager.state_changed.connect(queue_refresh)
	refresh()
	_layout_sheet()
	# 등장 애니메이션
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


## 하위 클래스에서 title_text / sheet_ratio 등을 설정
func _configure() -> void:
	pass


## 하위 클래스에서 content / footer 를 채운다
func build() -> void:
	pass


func queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_do_refresh")


func _do_refresh() -> void:
	_refresh_queued = false
	if is_inside_tree():
		refresh()


func refresh() -> void:
	var y := scroll.scroll_vertical
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	for c in footer.get_children():
		footer.remove_child(c)
		c.queue_free()
	title_label.text = title_text
	build()
	footer.visible = footer.get_child_count() > 0
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = y


func apply_safe_area(top: float, bottom: float) -> void:
	if _margin == null:
		await ready
	_margin.add_theme_constant_override("margin_bottom", 24 + int(bottom))
	_layout_sheet(top)


func _layout_sheet(top: float = 0.0) -> void:
	if sheet == null:
		return
	if centered:
		sheet.anchor_left = 0.0
		sheet.anchor_right = 1.0
		sheet.anchor_top = 0.5
		sheet.anchor_bottom = 0.5
		sheet.offset_left = 36
		sheet.offset_right = -36
		sheet.offset_top = -260
		sheet.offset_bottom = 260
		sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		sheet.anchor_left = 0.0
		sheet.anchor_right = 1.0
		sheet.anchor_top = clampf(1.0 - sheet_ratio, 0.0, 1.0)
		sheet.anchor_bottom = 1.0
		sheet.offset_left = 0
		sheet.offset_right = 0
		sheet.offset_top = maxf(0.0, top + 8.0) if sheet_ratio >= 0.99 else 0.0
		sheet.offset_bottom = 0


func _on_dim_input(event: InputEvent) -> void:
	if not dismiss_on_dim:
		return
	# 터치는 기본적으로 마우스 이벤트로도 전달되므로 마우스 버튼 해제만 처리
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		close()


func close() -> void:
	if ui:
		ui.close_panel(self)
	else:
		queue_free()


# ───────── 공통 위젯 헬퍼 ─────────

func section(text: String) -> Label:
	var l := UIKit.label(text, "section", UIKit.ACCENT)
	content.add_child(l)
	return l


func info_row(parent: Container, key: String, value: String, value_color: Color = UIKit.TEXT) -> HBoxContainer:
	var h := UIKit.hbox(8)
	var k := UIKit.label(key, "body", UIKit.TEXT_SUB)
	k.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(k)
	h.add_child(UIKit.spacer())
	var v := UIKit.label(value, "body", value_color)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	parent.add_child(h)
	return h


func footer_button(text: String, variant: String, cb: Callable, enabled: bool = true) -> Button:
	var b := UIKit.button(text, variant, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	UIKit.set_enabled(b, enabled)
	footer.add_child(b)
	return b
