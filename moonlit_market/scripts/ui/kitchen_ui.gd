extends PanelContainer
## KitchenUI — 영업 중 화면 하단의 주방. 플레이어가 직접 요리한다.
##  1) 주문서: 앉은 손님이 기다리는 메뉴와 인내심
##  2) 화구: 메뉴를 올리면 익어 간다. 링이 초록색(딱 좋음)일 때 탭해서 꺼내면 완벽!
##  3) 메뉴 버튼: 탭하면 빈 화구에 올라간다 (재료 1개 사용)
##  4) 음료 버튼: 주문한 손님이 있으면 바로 따라서 서빙
## 실제 규칙은 PochaManager/Kitchen 이 처리하고, 이 화면은 입력과 표시만 담당한다.

const UIKit := preload("res://scripts/ui/ui_kit.gd")
const DrawUtil := preload("res://scripts/market/draw_util.gd")
const KitchenScript := preload("res://scripts/market/kitchen.gd")


## 화구 하나 (원형 게이지 + 음식)
class BurnerView extends Control:
	signal tapped(index: int)
	var index: int = 0
	var pocha
	var t: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(150, 150)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			tapped.emit(index)
			accept_event()

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.44
		var font: Font = UIKit.bold_font()
		draw_circle(c, r + 6, Color("#1D212B"))
		draw_circle(c, r - 10, Color("#2E2A2A"))
		for k in 5:
			draw_line(c + Vector2(-r * 0.6, -r * 0.4 + k * r * 0.2), c + Vector2(r * 0.6, -r * 0.4 + k * r * 0.2), Color("#4A4040"), 3.0)
		if pocha == null or index >= pocha.kitchen.burners.size():
			return
		var b: Dictionary = pocha.kitchen.burners[index]
		var is_auto: bool = index == pocha.auto_burner
		if b["menu"] == "":
			_label(c + Vector2(0, r * 0.05), "요리사 담당" if is_auto else "빈 화구", 18, Color("#B9B5B0"), font)
			return
		var pe := float(b["perfect_end"])
		var burn := float(b["burn"])
		var full := burn * 1.12
		var early: float = pocha.kitchen.too_early
		# 구간 링: 덜 익음(회색) / 거의(노랑) / 딱 좋음(초록) / 탐(주황) / 숯(빨강)
		var zones := [[0.0, early, Color("#6B6F7A")], [early, 1.0, Color("#E8C547")], [1.0, pe, Color("#65C99A")],
			[pe, burn, Color("#E97858")], [burn, full, Color("#8E2F2F")]]
		for z in zones:
			var a0 := -PI / 2 + TAU * float(z[0]) / full
			var a1 := -PI / 2 + TAU * float(z[1]) / full
			draw_arc(c, r, a0, a1, 24, z[2], 12.0, true)
		var ratio: float = pocha.kitchen.ratio(index)
		var ang := -PI / 2 + TAU * clampf(ratio, 0.0, full) / full
		draw_line(c + Vector2.from_angle(ang) * (r - 16), c + Vector2.from_angle(ang) * (r + 10), Color("#FFF5E9"), 5.0)
		var stage: String = pocha.kitchen.stage(index)
		var m: Dictionary = DataManager.get_menu(str(b["menu"]))
		var fc := DataManager.color(m.get("color", "#E97858"))
		if stage == KitchenScript.STAGE_BURNT:
			fc = Color("#2A2220")
		elif stage == KitchenScript.STAGE_OVER:
			fc = fc.darkened(0.4)
		elif stage == KitchenScript.STAGE_RAW:
			fc = fc.lightened(0.35)
		var wobble := sin(t * 14.0) * 2.0 if stage == KitchenScript.STAGE_PERFECT else 0.0
		DrawUtil.menu_icon(self, m, c + Vector2(wobble, -10), r * 0.38, fc)
		var txt := "익는 중"
		var col := Color("#FFF5E9")
		match stage:
			KitchenScript.STAGE_ALMOST:
				txt = "곧 완성"
				col = Color("#E8C547")
			KitchenScript.STAGE_PERFECT:
				txt = "지금!"
				col = Color("#65C99A")
			KitchenScript.STAGE_OVER:
				txt = "타기 직전"
				col = Color("#E97858")
			KitchenScript.STAGE_BURNT:
				txt = "탔음 (버리기)"
				col = Color("#E5564A")
		if is_auto:
			txt = "요리사 담당"
			col = Color("#B9B5B0")
		_label(c + Vector2(0, r * 0.42), str(m.get("name", "")), 17, Color("#FFF5E9"), font)
		_label(c + Vector2(0, r * 0.72), txt, 19, col, font)
		if stage == KitchenScript.STAGE_PERFECT and not is_auto:
			draw_arc(c, r + 10, 0, TAU, 40, Color(0.4, 0.8, 0.6, 0.5 + 0.4 * sin(t * 10.0)), 4.0, true)

	func _label(p: Vector2, text: String, fs: int, col: Color, font: Font) -> void:
		var w := size.x
		draw_string_outline(font, Vector2(p.x - w / 2.0, p.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(p.x - w / 2.0, p.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)


var pocha ## PochaManager
var status_label: Label
var tickets_box: HBoxContainer
var burners_box: HBoxContainer
var food_box: HBoxContainer
var drink_box: HBoxContainer
var pass_label: Label
var ticket_bars: Array = []
var menu_buttons: Dictionary = {}
var _status_t: float = 0.0
var _dirty: bool = true


func _ready() -> void:
	var sb := UIKit.box(Color("#20242E"), 0, 0)
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	sb.border_color = Color("#3B4252")
	sb.border_width_top = 2
	add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var col := UIKit.vbox(8)
	margin.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	head.add_child(UIKit.label("주문", "section", UIKit.ACCENT))
	status_label = UIKit.label("", "caption", UIKit.TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(status_label)
	tickets_box = UIKit.hbox(8)
	tickets_box.custom_minimum_size = Vector2(0, 104)
	col.add_child(tickets_box)
	burners_box = UIKit.hbox(10)
	burners_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(burners_box)
	pass_label = UIKit.label("", "caption", UIKit.TEXT_SUB)
	pass_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pass_label)
	food_box = UIKit.hbox(8)
	col.add_child(food_box)
	drink_box = UIKit.hbox(8)
	col.add_child(drink_box)


func bind(p_pocha) -> void:
	if pocha and pocha.changed.is_connected(_mark_dirty):
		pocha.changed.disconnect(_mark_dirty)
	pocha = p_pocha
	pocha.changed.connect(_mark_dirty)
	_dirty = true


func _mark_dirty() -> void:
	_dirty = true


func show_message(text: String, good: bool = false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", UIKit.SUCCESS if good else UIKit.SECONDARY)
	_status_t = 1.8


func _process(delta: float) -> void:
	if not visible or pocha == null:
		return
	if _dirty:
		_dirty = false
		_rebuild()
	_update_live()
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0:
			status_label.text = "초록색일 때 화구를 탭!"
			status_label.add_theme_color_override("font_color", UIKit.TEXT_SUB)


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _rebuild() -> void:
	# 화구
	if burners_box.get_child_count() != pocha.kitchen.burners.size():
		_clear(burners_box)
		for i in pocha.kitchen.burners.size():
			var bv := BurnerView.new()
			bv.index = i
			bv.pocha = pocha
			bv.tapped.connect(_on_burner)
			burners_box.add_child(bv)
	# 주문서 (좌석 순서)
	_clear(tickets_box)
	ticket_bars = []
	var shown := 0
	for s in pocha.seats.size():
		var c = pocha.seats[s]
		if c == null or not is_instance_valid(c):
			continue
		var list: Array = pocha.orders_of(c)
		if list.is_empty():
			continue
		shown += 1
		var card := UIKit.card(UIKit.PANEL_LIGHT, 8)
		card.custom_minimum_size = Vector2(112, 0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := UIKit.vbox(2)
		card.add_child(v)
		var t := UIKit.label("%d번 · %s" % [s + 1, c.ctype.get("name", "")], "caption", UIKit.TEXT_SUB)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		t.add_theme_font_size_override("font_size", 16)
		v.add_child(t)
		for o in list:
			var nm := UIKit.label(str(DataManager.get_menu(o["menu"]).get("name", "")), "body", UIKit.TEXT)
			nm.autowrap_mode = TextServer.AUTOWRAP_OFF
			nm.add_theme_font_size_override("font_size", 19)
			v.add_child(nm)
		var bar := UIKit.progress_bar(1, 1, UIKit.SUCCESS, 8)
		v.add_child(bar)
		ticket_bars.append([bar, c])
		tickets_box.add_child(card)
	if shown == 0:
		var empty := UIKit.label("손님 주문을 기다리는 중…", "caption")
		empty.autowrap_mode = TextServer.AUTOWRAP_OFF
		tickets_box.add_child(empty)
	# 메뉴/음료 버튼
	_clear(food_box)
	_clear(drink_box)
	menu_buttons = {}
	for id in GameManager.state.enabled_menus():
		var m: Dictionary = DataManager.get_menu(id)
		var station := str(m.get("station", ""))
		if station != "grill" and station != "drink":
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 76 if station == "grill" else 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_font_override("font", UIKit.bold_font())
		var menu_id: String = id
		if station == "grill":
			b.pressed.connect(func(): _on_cook(menu_id))
			food_box.add_child(b)
		else:
			b.pressed.connect(func(): _on_pour(menu_id))
			drink_box.add_child(b)
		menu_buttons[id] = b
	_update_live()


func _update_live() -> void:
	for pair in ticket_bars:
		var bar: ProgressBar = pair[0]
		var c = pair[1]
		if is_instance_valid(c):
			bar.max_value = maxf(1.0, c.patience_max)
			bar.value = c.patience_left
	for id in menu_buttons.keys():
		var b: Button = menu_buttons[id]
		var m: Dictionary = DataManager.get_menu(id)
		var stock: int = GameManager.state.stock_of(id)
		var want: int = pocha.pending_count(id)
		b.text = "%s\n재고 %d%s" % [m.get("name", ""), stock, ("  ·  주문 %d" % want) if want > 0 else ""]
		var hot := want > 0 and stock > 0
		var base := UIKit.ACCENT if hot else (UIKit.PANEL_LIGHT if stock > 0 else Color("#3A3F4A"))
		if str(m.get("station", "")) == "drink" and hot:
			base = Color("#7FD4E8")
		b.add_theme_stylebox_override("normal", UIKit.box(base, 14, 6))
		b.add_theme_stylebox_override("hover", UIKit.box(base.lightened(0.08), 14, 6))
		b.add_theme_stylebox_override("pressed", UIKit.box(base.darkened(0.2), 14, 6))
		var fg := UIKit.TEXT_DARK if hot else (UIKit.TEXT if stock > 0 else UIKit.TEXT_SUB)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, fg)
	var parts: Array = []
	for p in pocha.pass_items:
		parts.append("%s(%d)" % [DataManager.get_menu(p["menu"]).get("name", ""), int(p["quality"])])
	pass_label.text = ("완성 대기: " + ", ".join(parts)) if parts.size() > 0 else ""
	pass_label.visible = parts.size() > 0


func _on_burner(i: int) -> void:
	var r: Dictionary = pocha.tap_burner(i)
	if not r.get("ok", false):
		if r.has("error"):
			show_message(str(r["error"]))
		return
	if r.get("burnt", false):
		show_message("탔어요! 재료를 버렸습니다")
		GameManager.vibrate(40)
		return
	var q := int(round(float(r.get("quality", 0))))
	show_message("%s 완성 · 품질 %d" % [DataManager.get_menu(str(r["menu"])).get("name", ""), q], q >= 90)


func _on_cook(menu_id: String) -> void:
	var r: Dictionary = pocha.cook(menu_id)
	if not r.get("ok", false):
		show_message(str(r.get("error", "")))


func _on_pour(menu_id: String) -> void:
	var r: Dictionary = pocha.pour(menu_id)
	if not r.get("ok", false):
		show_message(str(r.get("error", "")))
	else:
		show_message("%s 서빙!" % DataManager.get_menu(menu_id).get("name", ""), true)
