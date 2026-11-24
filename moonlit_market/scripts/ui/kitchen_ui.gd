extends PanelContainer
## KitchenUI — 영업 중 화면 하단의 주방 조작부. 플레이어가 직접 요리한다.
##  1) 화구: 메뉴를 올리면 익어 간다. 링이 초록색(지금!)일 때 탭 → 서빙대로
##  2) 메뉴 버튼: 탭하면 빈 화구에 올라간다 (재료 1개 사용)
##  3) 음료 탭: 꾹 눌러 잔을 채우고, 초록 선 안에서 떼면 완벽 → 서빙대로 (넘치면 버림)
##  서빙은 시장 화면에서 손님을 탭 → 사장님이 걸어가서 전달. 빈 테이블도 탭해서 치운다.
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
		custom_minimum_size = Vector2(140, 140)
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
		var needs_flip: bool = pocha.kitchen.needs_flip(index)
		var f: Dictionary = b.get("flip", {})
		if needs_flip:
			var fa0 := -PI / 2 + TAU * float(f.get("good_min", 0.3)) / full
			var fa1 := -PI / 2 + TAU * float(f.get("good_max", 0.9)) / full
			draw_arc(c, r - 15, fa0, fa1, 20, Color("#5FA8E8"), 6.0, true)
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
		if needs_flip:
			var in_window := ratio >= float(f.get("good_min", 0.3)) and ratio <= float(f.get("good_max", 0.9))
			if ratio >= float(f.get("min", 0.3)) and ratio < 1.0:
				txt = "뒤집기!" if in_window else "지금 뒤집기?"
				col = Color("#5FA8E8") if in_window else Color("#B9C4E8")
		elif not f.is_empty() and stage == KitchenScript.STAGE_RAW:
			txt = "뒤집음 · 익는 중"
		if is_auto:
			txt = "요리사 담당"
			col = Color("#B9B5B0")
		_label(c + Vector2(0, r * 0.42), str(m.get("name", "")), 17, Color("#FFF5E9"), font)
		_label(c + Vector2(0, r * 0.72), txt, 19, col, font)
		if needs_flip and ratio >= float(f.get("good_min", 0.3)) and ratio <= float(f.get("good_max", 0.9)) and not is_auto:
			draw_arc(c, r + 10, 0, TAU, 40, Color(0.37, 0.66, 0.91, 0.5 + 0.4 * sin(t * 10.0)), 4.0, true)
		elif stage == KitchenScript.STAGE_PERFECT and not is_auto:
			draw_arc(c, r + 10, 0, TAU, 40, Color(0.4, 0.8, 0.6, 0.5 + 0.4 * sin(t * 10.0)), 4.0, true)

	func _label(p: Vector2, text: String, fs: int, col: Color, font: Font) -> void:
		var w := size.x
		draw_string_outline(font, Vector2(p.x - w / 2.0, p.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(p.x - w / 2.0, p.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)


## 음료 따르기 (꾹 누르기)
class DrinkTap extends Control:
	signal pour_started(menu_id: String)
	signal pour_released(menu_id: String)
	var menu_id: String = ""
	var level: float = 0.0
	var pouring: bool = false
	var is_mix: bool = false
	var mix_stage: int = 0 ## 소맥: 0 = 소주 차례, 1 = 맥주 차례
	var soju_level: float = 0.0
	var hot: bool = false
	var stock: int = 0
	var t: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 104)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and not pouring:
			pour_started.emit(menu_id)
		elif not mb.pressed and pouring:
			pour_released.emit(menu_id)
		accept_event()

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var font: Font = UIKit.bold_font()
		var m: Dictionary = DataManager.get_menu(menu_id)
		var bg := Color("#7FD4E8") if hot else (UIKit.PANEL_LIGHT if stock > 0 else Color("#3A3F4A"))
		draw_style_box(UIKit.box(bg if not pouring else bg.lightened(0.15), 14, 0), Rect2(Vector2.ZERO, size))
		var fg := UIKit.TEXT_DARK if hot else (UIKit.TEXT if stock > 0 else UIKit.TEXT_SUB)
		# 잔
		var gw := 34.0
		var gh := 70.0
		var gp := Vector2(16, (size.y - gh) / 2.0)
		var pc: Dictionary = DataManager.pocha.get("pour", {})
		var tmin := float(pc.get("target_min", 0.78))
		var tmax := float(pc.get("target_max", 0.92))
		draw_rect(Rect2(gp, Vector2(gw, gh)), Color(1, 1, 1, 0.25))
		var fill := clampf(level, 0.0, 1.0)
		var liquid := DataManager.color(m.get("color", "#F2C14E"))
		if not (is_mix and mix_stage == 0):
			draw_rect(Rect2(gp + Vector2(3, gh * (1.0 - fill)), Vector2(gw - 6, gh * fill - 3)), liquid)
		if fill > 0.05 and str(m.get("icon", "")) == "beer":
			draw_rect(Rect2(gp + Vector2(3, gh * (1.0 - fill) - 5), Vector2(gw - 6, 6)), Color("#FFF8E6"))
		if is_mix:
			var mx: Dictionary = m.get("mix", {})
			tmin = float(mx.get("beer_min", 0.8))
			tmax = float(mx.get("beer_max", 0.93))
			var smin := float(mx.get("soju_min", 0.22))
			var smax := float(mx.get("soju_max", 0.34))
			var sf := clampf(soju_level if mix_stage == 1 else level, 0.0, 1.0)
			if mix_stage == 1 or pouring:
				draw_rect(Rect2(gp + Vector2(3, gh * (1.0 - sf)), Vector2(gw - 6, gh * sf - 3)), Color("#DDEBF0"))
			draw_rect(Rect2(gp + Vector2(-4, gh * (1.0 - smax)), Vector2(gw + 8, gh * (smax - smin))), Color(0.37, 0.66, 0.91, 0.5))
		draw_rect(Rect2(gp + Vector2(-4, gh * (1.0 - tmax)), Vector2(gw + 8, gh * (tmax - tmin))), Color(0.4, 0.85, 0.6, 0.45))
		draw_rect(Rect2(gp, Vector2(gw, gh)), Color(1, 1, 1, 0.7), false, 2.0)
		if level >= 1.0:
			draw_circle(gp + Vector2(gw / 2.0, -4 + sin(t * 20.0) * 2.0), 5, liquid)
		var tx := gp.x + gw + 12
		var tw := size.x - tx - 6
		draw_string(font, Vector2(tx, 40), str(m.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, tw, 20, fg)
		var want: int = 0
		var sub := "재고 %d" % stock
		draw_string(font, Vector2(tx, 66), sub, HORIZONTAL_ALIGNMENT_LEFT, tw, 16, fg)
		var hint := "꾹 눌러 따르기" if not pouring else "선에서 떼기!"
		if is_mix:
			hint = ("① 소주: 파란 선" if mix_stage == 0 else "② 맥주: 초록 선") if not pouring else ("소주 따르는 중" if mix_stage == 0 else "맥주 따르는 중")
		draw_string(font, Vector2(tx, 92), hint, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, fg if not pouring else Color("#2E7A55"))


var pocha ## PochaManager
var status_label: Label
var tickets_box: HBoxContainer
var burners_box: HBoxContainer
var food_box: HBoxContainer
var drink_box: HBoxContainer
var pass_label: Label
var combo_label: Label
var ticket_bars: Array = []
var menu_buttons: Dictionary = {}
var drink_taps: Dictionary = {}
var pouring_menu: String = ""
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
	var head := UIKit.hbox(10)
	col.add_child(head)
	pass_label = UIKit.label("", "body", UIKit.ACCENT)
	pass_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(pass_label)
	combo_label = UIKit.label("", "body", UIKit.SUCCESS)
	combo_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(combo_label)
	status_label = UIKit.label("", "caption", UIKit.TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(status_label)
	tickets_box = UIKit.hbox(0)
	burners_box = UIKit.hbox(10)
	burners_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(burners_box)
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
			status_label.text = "손님을 탭하면 서빙!"
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
	# 메뉴/음료 버튼
	_clear(food_box)
	_clear(drink_box)
	menu_buttons = {}
	drink_taps = {}
	for id in GameManager.state.enabled_menus():
		var m: Dictionary = DataManager.get_menu(id)
		var station := str(m.get("station", ""))
		if station != "grill" and station != "drink" and station != "mix":
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 70 if station == "grill" else 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_font_override("font", UIKit.bold_font())
		var menu_id: String = id
		if station == "grill":
			b.pressed.connect(func(): _on_cook(menu_id))
			food_box.add_child(b)
			menu_buttons[id] = b
		else:
			b.queue_free()
			var tap := DrinkTap.new()
			tap.menu_id = menu_id
			tap.is_mix = station == "mix"
			tap.pour_started.connect(_on_pour_start)
			tap.pour_released.connect(_on_pour_release)
			drink_box.add_child(tap)
			drink_taps[id] = tap
	_update_live()


func _update_live() -> void:
	for id in drink_taps.keys():
		var tap = drink_taps[id]
		tap.stock = GameManager.state.stock_of(id)
		tap.hot = pocha.pending_count(id) > 0 and tap.stock > 0
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
	pass_label.text = "서빙대 %d/%d" % [pocha.pass_items.size(), pocha.pass_capacity()]
	pass_label.add_theme_color_override("font_color", UIKit.DANGER if pocha.pass_space() <= 0 else UIKit.ACCENT)
	combo_label.text = ("콤보 x%d" % pocha.combo) if pocha.combo >= 2 else ""
	if pocha.dirty_count() > 0 and _status_t <= 0.0:
		status_label.text = "빈 테이블 %d곳을 탭해서 치우세요" % pocha.dirty_count()
	# 음료 따르기 진행
	if pouring_menu != "" and drink_taps.has(pouring_menu):
		var tap = drink_taps[pouring_menu]
		var fill_time := float(DataManager.pocha.get("pour", {}).get("fill_time", 1.6))
		tap.level += get_process_delta_time() / maxf(0.2, fill_time)
		if tap.level >= float(DataManager.pocha.get("pour", {}).get("overflow", 1.0)) + 0.08:
			_on_pour_release(pouring_menu)


func _on_burner(i: int) -> void:
	var r: Dictionary = pocha.tap_burner(i)
	if not r.get("ok", false):
		if r.has("error"):
			show_message(str(r["error"]))
		return
	if r.get("flipped", false):
		if r.get("flip", "") == "good":
			show_message("뒤집기 성공! 이제 익기를 기다려요", true)
		else:
			show_message("타이밍이 아쉬워요 (품질 감소)")
		return
	if r.get("burnt", false):
		show_message("탔어요! 재료를 버렸습니다")
		GameManager.vibrate(40)
		return
	var q := int(round(float(r.get("quality", 0))))
	show_message("%s 완성 · 품질 %d → 손님을 탭!" % [DataManager.get_menu(str(r["menu"])).get("name", ""), q], q >= 90)


func _on_cook(menu_id: String) -> void:
	var r: Dictionary = pocha.cook(menu_id)
	if not r.get("ok", false):
		show_message(str(r.get("error", "")))


func _on_pour_start(menu_id: String) -> void:
	if pouring_menu != "":
		return
	var tap = drink_taps[menu_id]
	if tap.is_mix and tap.mix_stage == 1:
		# 소맥 두 번째 단계: 소주 위에 맥주
		pouring_menu = menu_id
		tap.level = tap.soju_level
		tap.pouring = true
		return
	var r: Dictionary = pocha.pour_start(menu_id)
	if not r.get("ok", false):
		show_message(str(r.get("error", "")))
		return
	pouring_menu = menu_id
	tap.level = 0.0
	tap.pouring = true


func _on_pour_release(menu_id: String) -> void:
	if pouring_menu != menu_id or not drink_taps.has(menu_id):
		return
	var tap = drink_taps[menu_id]
	if tap.is_mix and tap.mix_stage == 0:
		tap.soju_level = tap.level
		tap.mix_stage = 1
		tap.pouring = false
		pouring_menu = ""
		show_message("이제 맥주를 꾹! 초록 선까지", true)
		return
	var r: Dictionary
	if tap.is_mix:
		r = pocha.pour_finish_mix(menu_id, tap.soju_level, tap.level)
		tap.mix_stage = 0
		tap.soju_level = 0.0
	else:
		r = pocha.pour_finish(menu_id, tap.level)
	tap.pouring = false
	pouring_menu = ""
	if r.get("ok", false):
		var q := int(round(float(r.get("quality", 0))))
		show_message("%s 완성 · 품질 %d → 손님을 탭!" % [DataManager.get_menu(menu_id).get("name", ""), q], q >= 99)
	else:
		show_message(str(r.get("error", "")))
	var tw := create_tween()
	tw.tween_property(tap, "level", 0.0, 0.25)


## 테스트/자동 플레이용: 정해진 양만큼 따르기
func pour_amount(menu_id: String, level: float) -> Dictionary:
	var r: Dictionary = pocha.pour_start(menu_id)
	if not r.get("ok", false):
		return r
	if str(DataManager.get_menu(menu_id).get("station", "")) == "mix":
		return pocha.pour_finish_mix(menu_id, 0.28, level)
	return pocha.pour_finish(menu_id, level)
