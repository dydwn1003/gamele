extends Control
## UIManager — UI 루트. 테마 적용, 안전 영역 계산, 패널 스택, 토스트, 확인 대화상자.
## UI 는 표시와 입력만 담당하고 실제 변경은 GameManager 의 행동 API 를 호출한다.

const UIKit := preload("res://scripts/ui/ui_kit.gd")
const HudScene := preload("res://scenes/ui/main_hud.tscn")
const PANELS := {
	"pocha": preload("res://scenes/ui/pocha_panel.tscn"),
	"employee": preload("res://scenes/ui/employee_panel.tscn"),
	"preparation": preload("res://scenes/ui/preparation_panel.tscn"),
	"result": preload("res://scenes/ui/result_panel.tscn"),
	"settings": preload("res://scenes/ui/settings_panel.tscn"),
	"build": preload("res://scenes/ui/build_panel.tscn"),
	"shop": preload("res://scenes/ui/shop_panel.tscn"),
	"offline": preload("res://scenes/ui/offline_panel.tscn"),
	"market": preload("res://scenes/ui/market_panel.tscn"),
	"dialog": preload("res://scenes/ui/dialog_panel.tscn"),
}

signal layout_changed

var main ## main.gd
var hud
var panel_layer: Control
var toast_layer: VBoxContainer
var panels: Array = []
var safe_top: float = 0.0
var safe_bottom: float = 0.0


func _ready() -> void:
	theme = UIKit.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = HudScene.instantiate()
	hud.ui = self
	add_child(hud)
	panel_layer = Control.new()
	panel_layer.name = "Panels"
	panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_layer)
	panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_layer = UIKit.vbox(8)
	toast_layer.name = "Toasts"
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)
	get_viewport().size_changed.connect(_on_viewport_resized)
	GameManager.toast.connect(show_toast)
	call_deferred("_on_viewport_resized")


func _on_viewport_resized() -> void:
	_compute_safe_area()
	_place_toasts()
	if hud:
		hud.apply_layout(safe_top, safe_bottom)
	for p in panels:
		if is_instance_valid(p):
			p.apply_safe_area(safe_top, safe_bottom)
	layout_changed.emit()


## 노치/펀치홀/제스처 바 영역을 뷰포트 좌표로 변환
func _compute_safe_area() -> void:
	safe_top = 0.0
	safe_bottom = 0.0
	if not OS.has_feature("mobile"):
		return
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return
	var vp := get_viewport_rect().size
	var k := vp.y / float(win.y)
	safe_top = maxf(0.0, safe.position.y * k)
	safe_bottom = maxf(0.0, (win.y - (safe.position.y + safe.size.y)) * k)


func market_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var top: float = (hud.top_height() + hud.banner_space()) if hud else 260.0
	var bottom: float = hud.bottom_height() if hud else 220.0
	return Rect2(Vector2(0, top), Vector2(vp.x, maxf(200.0, vp.y - top - bottom)))


# ───────── 패널 ─────────

func open(panel_name: String, args: Dictionary = {}):
	if not PANELS.has(panel_name):
		push_warning("알 수 없는 패널: " + panel_name)
		return null
	# 같은 패널이 열려 있으면 교체
	for p in panels.duplicate():
		if is_instance_valid(p) and p.panel_id == panel_name and panel_name != "dialog":
			close_panel(p)
	var panel = PANELS[panel_name].instantiate()
	panel.panel_id = panel_name
	panel.ui = self
	panel.args = args
	panel_layer.add_child(panel)
	panel.apply_safe_area(safe_top, safe_bottom)
	panels.append(panel)
	return panel


func close_panel(p) -> void:
	panels.erase(p)
	if is_instance_valid(p):
		p.queue_free()


func close_all(except_dialogs: bool = true) -> void:
	for p in panels.duplicate():
		if is_instance_valid(p) and (not except_dialogs or p.panel_id != "dialog"):
			close_panel(p)


func top_panel():
	for i in range(panels.size() - 1, -1, -1):
		if is_instance_valid(panels[i]):
			return panels[i]
	return null


func is_open(panel_name: String) -> bool:
	for p in panels:
		if is_instance_valid(p) and p.panel_id == panel_name:
			return true
	return false


func get_open(panel_name: String):
	for p in panels:
		if is_instance_valid(p) and p.panel_id == panel_name:
			return p
	return null


## 확인 대화상자. buttons: [{"text": "...", "variant": "primary", "callback": Callable}]
func dialog(title: String, message: String, buttons: Array, dismissable: bool = true):
	return open("dialog", {"title": title, "message": message, "buttons": buttons, "dismissable": dismissable})


func confirm(title: String, message: String, ok_text: String, on_ok: Callable, danger: bool = false):
	return dialog(title, message, [
		{"text": "취소", "variant": "secondary", "callback": Callable()},
		{"text": ok_text, "variant": "danger" if danger else "primary", "callback": on_ok},
	])


# ───────── 토스트 ─────────

## 토스트는 하단 버튼 바로 위에 표시 (패널 제목을 가리지 않도록)
func _place_toasts() -> void:
	var bottom: float = hud.bottom_height() if hud else 240.0
	toast_layer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_layer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_layer.offset_left = 40
	toast_layer.offset_right = -40
	toast_layer.offset_bottom = -(bottom + 12.0)
	toast_layer.offset_top = toast_layer.offset_bottom


func show_toast(text: String, kind: String = "info") -> void:
	var col := UIKit.PANEL_LIGHT
	match kind:
		"success":
			col = Color("#2F5E48")
		"error":
			col = Color("#6A2E2E")
		"event":
			col = Color("#6A4A22")
	var card := UIKit.card(Color(col, 0.96), 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, "body")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(l)
	toast_layer.add_child(card)
	while toast_layer.get_child_count() > 3:
		var old := toast_layer.get_child(0)
		toast_layer.remove_child(old)
		old.queue_free()
	_place_toasts.call_deferred()
	var tw := card.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(card.queue_free)
	tw.tween_callback(_place_toasts.call_deferred)


func handle_back() -> bool:
	var p = top_panel()
	if p != null:
		if p.panel_id == "dialog" and not p.args.get("dismissable", true):
			return true
		close_panel(p)
		return true
	return false
