extends Control
## MainHUD — 상단(시장 이름/코인/평판/설정), 영업 중 정보, 이벤트 배너, 하단(영업 버튼 + 메뉴 4개).

const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal main_button_pressed
signal nav_pressed(id: String)
signal settings_pressed
signal speed_pressed
signal cancel_mode_pressed

var ui
var top_bar: PanelContainer
var top_margin: MarginContainer
var bottom_bar: PanelContainer
var bottom_margin: MarginContainer
var name_label: Label
var stage_label: Label
var coin_chip: HBoxContainer
var rep_chip: HBoxContainer
var rep_progress: ProgressBar
var rep_next_label: Label
var weather_icon
var weather_label: Label
var main_button: Button
var session_card: PanelContainer
var timer_label: Label
var timer_bar: ProgressBar
var stats_label: Label
var speed_button: Button
var event_card: PanelContainer
var event_title: Label
var event_desc: Label
var mode_card: PanelContainer
var mode_label: Label
var nav_buttons: Dictionary = {}
var _safe_top: float = 0.0
var _safe_bottom: float = 0.0
var _shown_coins: float = 0.0
var _target_coins: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_session()
	_build_bottom()
	GameManager.currency_changed.connect(_on_currency)
	GameManager.state_changed.connect(refresh)
	GameManager.session_phase_changed.connect(_on_phase)
	_shown_coins = GameManager.state.coins
	refresh()
	_on_phase("idle")


func _build_top() -> void:
	top_bar = PanelContainer.new()
	var sb := UIKit.box(Color(UIKit.PANEL, 0.94), 0, 0)
	sb.corner_radius_bottom_left = 26
	sb.corner_radius_bottom_right = 26
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	top_bar.add_theme_stylebox_override("panel", sb)
	add_child(top_bar)
	top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 22)
	top_margin.add_theme_constant_override("margin_right", 22)
	top_margin.add_theme_constant_override("margin_bottom", 14)
	top_bar.add_child(top_margin)
	var col := UIKit.vbox(10)
	top_margin.add_child(col)
	var row1 := UIKit.hbox(12)
	col.add_child(row1)
	var title_box := UIKit.vbox(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title_box)
	name_label = UIKit.label("달빛장터", "title", UIKit.ACCENT)
	title_box.add_child(name_label)
	stage_label = UIKit.label("", "caption")
	stage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(stage_label)
	var wbox := UIKit.vbox(0)
	wbox.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(wbox)
	weather_icon = UIKit.icon("cloud", 40)
	weather_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wbox.add_child(weather_icon)
	weather_label = UIKit.label("흐림", "caption")
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wbox.add_child(weather_label)
	var settings := UIKit.button("", "secondary", 76)
	settings.custom_minimum_size = Vector2(76, 76)
	var gear := UIKit.icon("settings", 36)
	gear.position = Vector2(20, 20)
	settings.add_child(gear)
	settings.pressed.connect(func(): settings_pressed.emit())
	row1.add_child(settings)
	var row2 := UIKit.hbox(12)
	col.add_child(row2)
	var coin_card := UIKit.card(UIKit.PANEL_DARK, 10)
	coin_card.custom_minimum_size = Vector2(250, 0)
	coin_chip = UIKit.currency("coin", GameManager.state.coins, "number")
	coin_card.add_child(coin_chip)
	row2.add_child(coin_card)
	var rep_card := UIKit.card(UIKit.PANEL_DARK, 10)
	rep_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rep_box := UIKit.hbox(10)
	rep_card.add_child(rep_box)
	rep_chip = UIKit.currency("rep", GameManager.state.reputation, "number")
	rep_box.add_child(rep_chip)
	var rp := UIKit.vbox(2)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.alignment = BoxContainer.ALIGNMENT_CENTER
	rep_box.add_child(rp)
	rep_next_label = UIKit.label("", "caption")
	rep_next_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rp.add_child(rep_next_label)
	rep_progress = UIKit.progress_bar(0, 1, UIKit.REP, 10)
	rp.add_child(rep_progress)
	row2.add_child(rep_card)


func _build_session() -> void:
	session_card = UIKit.card(Color(UIKit.PANEL_DARK, 0.92), 14)
	add_child(session_card)
	var col := UIKit.vbox(8)
	session_card.add_child(col)
	var row := UIKit.hbox(12)
	col.add_child(row)
	row.add_child(UIKit.icon("clock", 34))
	timer_label = UIKit.label("04:00", "number")
	row.add_child(timer_label)
	stats_label = UIKit.label("", "caption", UIKit.TEXT)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(stats_label)
	speed_button = UIKit.button("x1", "secondary", 62)
	speed_button.custom_minimum_size = Vector2(92, 62)
	speed_button.pressed.connect(func(): speed_pressed.emit())
	row.add_child(speed_button)
	timer_bar = UIKit.progress_bar(240, 240, UIKit.ACCENT, 10)
	col.add_child(timer_bar)
	event_card = UIKit.card(Color("#6A4A22"), 14)
	add_child(event_card)
	var ecol := UIKit.vbox(2)
	event_card.add_child(ecol)
	var erow := UIKit.hbox(10)
	ecol.add_child(erow)
	erow.add_child(UIKit.icon("event", 30))
	event_title = UIKit.label("", "section")
	erow.add_child(event_title)
	event_desc = UIKit.label("", "caption", UIKit.TEXT)
	ecol.add_child(event_desc)
	event_card.visible = false
	mode_card = UIKit.card(Color("#6A4A22"), 14)
	add_child(mode_card)
	var mrow := UIKit.hbox(12)
	mode_card.add_child(mrow)
	mode_label = UIKit.label("", "body")
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mrow.add_child(mode_label)
	var cancel := UIKit.button("취소", "secondary", 70)
	cancel.custom_minimum_size = Vector2(120, 70)
	cancel.pressed.connect(func(): cancel_mode_pressed.emit())
	mrow.add_child(cancel)
	mode_card.visible = false


func _build_bottom() -> void:
	bottom_bar = PanelContainer.new()
	var sb := UIKit.box(Color(UIKit.PANEL, 0.96), 0, 0)
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	bottom_bar.add_theme_stylebox_override("panel", sb)
	add_child(bottom_bar)
	bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 18)
	bottom_margin.add_theme_constant_override("margin_right", 18)
	bottom_margin.add_theme_constant_override("margin_top", 14)
	bottom_bar.add_child(bottom_margin)
	var col := UIKit.vbox(12)
	bottom_margin.add_child(col)
	main_button = UIKit.button("영업 준비", "primary", 96)
	main_button.add_theme_font_size_override("font_size", 32)
	main_button.pressed.connect(func(): main_button_pressed.emit())
	col.add_child(main_button)
	var nav := UIKit.hbox(10)
	col.add_child(nav)
	for item in [["market", "market", "시장 관리"], ["staff", "staff", "상인"], ["build", "deco", "건설·장식"], ["shop", "shop", "상점"]]:
		var b := UIKit.button("", "ghost", 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIKit.vbox(2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var ic := UIKit.icon(item[1], 40)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UIKit.label(item[2], "caption", UIKit.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		var id: String = item[0]
		b.pressed.connect(func(): nav_pressed.emit(id))
		nav.add_child(b)
		nav_buttons[id] = b


func apply_layout(safe_top: float, safe_bottom: float) -> void:
	_safe_top = safe_top
	_safe_bottom = safe_bottom
	top_margin.add_theme_constant_override("margin_top", 14 + int(safe_top))
	bottom_margin.add_theme_constant_override("margin_bottom", 14 + int(safe_bottom))
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = top_height()
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -bottom_height()
	var y := top_height() + 10
	for card in [session_card, event_card, mode_card]:
		card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		card.offset_left = 18
		card.offset_right = -18
		card.offset_top = y
		card.offset_bottom = y
	_stack_banners()


func _stack_banners() -> void:
	var y := top_height() + 10
	for card in [session_card, mode_card, event_card]:
		if card.visible:
			card.offset_top = y
			card.offset_bottom = y
			y += card.get_combined_minimum_size().y + 8


func top_height() -> float:
	return 166.0 + _safe_top


## 영업 정보 카드가 시장(맨 윗줄 노점)을 가리지 않도록 확보하는 높이
func banner_space() -> float:
	return 126.0


func bottom_height() -> float:
	return 238.0 + _safe_bottom


func _process(delta: float) -> void:
	# 코인 숫자 증가 연출
	if absf(_shown_coins - _target_coins) > 0.5:
		_shown_coins = lerpf(_shown_coins, _target_coins, clampf(delta * 8.0, 0.0, 1.0))
		if absf(_shown_coins - _target_coins) < 1.0:
			_shown_coins = _target_coins
		UIKit.set_currency(coin_chip, int(round(_shown_coins)))


func _on_currency(coins: int, rep: int) -> void:
	_target_coins = coins
	UIKit.set_currency(rep_chip, rep)
	_update_rep_progress()


func refresh() -> void:
	var st: Dictionary = GameManager.progression.current_stage()
	stage_label.text = "%d단계 · %s · %d일차" % [GameManager.state.market_level, st.get("name", ""), GameManager.state.day]
	var w: Dictionary = DataManager.get_weather(GameManager.state.today_weather)
	weather_label.text = str(w.get("name", ""))
	var wid := str(GameManager.state.today_weather)
	weather_icon.kind = "sun" if wid == "sunny" else ("rain" if wid == "rain" else "cloud")
	_target_coins = GameManager.state.coins
	UIKit.set_currency(rep_chip, GameManager.state.reputation)
	_update_rep_progress()
	_update_main_button()


func _update_rep_progress() -> void:
	var nxt: Dictionary = GameManager.progression.next_stage()
	if nxt.is_empty():
		rep_next_label.text = "최고 단계 달성"
		rep_progress.max_value = 1
		rep_progress.value = 1
		return
	var cur_req := int(GameManager.progression.current_stage().get("required_reputation", 0))
	var need := int(nxt.get("required_reputation", 0))
	rep_next_label.text = "다음: %s (%d)" % [nxt.get("name", ""), need]
	rep_progress.max_value = maxf(1.0, need - cur_req)
	rep_progress.value = clampf(GameManager.state.reputation - cur_req, 0, need - cur_req)


func _update_main_button() -> void:
	if GameManager.is_operating:
		main_button.text = "영업 중..."
		UIKit.set_enabled(main_button, false)
	elif GameManager.economy.has_unclaimed_result():
		main_button.text = "정산 받기"
		UIKit.set_enabled(main_button, true)
	else:
		main_button.text = "영업 준비"
		UIKit.set_enabled(main_button, true)


func _on_phase(phase: String) -> void:
	var running := phase == "open" or phase == "closing"
	session_card.visible = running
	if not running:
		event_card.visible = false
	for id in nav_buttons.keys():
		UIKit.set_enabled(nav_buttons[id], not running or id == "shop")
	_update_main_button()
	_stack_banners()


func update_session(remaining: float, stats: Dictionary) -> void:
	var sec := int(ceil(remaining))
	timer_label.text = "%02d:%02d" % [sec / 60, sec % 60]
	timer_bar.max_value = float(DataManager.bal("session_duration", 240.0))
	timer_bar.value = remaining
	if stats.get("phase", "") == "closing":
		timer_label.text = "마감 중"
	stats_label.text = "방문 %d · 판매 %d · 이탈 %d\n매출 %s" % [stats.get("visitors", 0), stats.get("sales", 0), stats.get("walkouts", 0), UIKit.fmt(int(stats.get("revenue", 0)))]
	speed_button.text = "x%d" % int(stats.get("speed", 1.0))


func show_event(ev: Dictionary) -> void:
	event_card.add_theme_stylebox_override("panel", UIKit.box(Color(DataManager.color(ev.get("color", "#FFB45C")).darkened(0.55), 0.95), UIKit.RADIUS, 14))
	event_title.text = str(ev.get("name", "이벤트"))
	var desc := str(ev.get("desc", ""))
	if ev.has("trend_name"):
		desc += " (유행: %s)" % ev["trend_name"]
	event_desc.text = desc
	event_card.visible = true
	_stack_banners()


func hide_event() -> void:
	event_card.visible = false
	_stack_banners()


func show_mode(text: String) -> void:
	mode_label.text = text
	mode_card.visible = text != ""
	_stack_banners()
