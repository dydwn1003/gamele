extends Control
## MainHUD — 상단(시장 이름/코인/평판·영업 시간/설정), 이벤트 배너,
## 하단: 평소엔 [영업 준비 + 메뉴 5개], 영업 중엔 [주방 KitchenUI].

const UIKit := preload("res://scripts/ui/ui_kit.gd")
const KitchenScript := preload("res://scripts/ui/kitchen_ui.gd")

signal main_button_pressed
signal nav_pressed(id: String)
signal settings_pressed
signal speed_pressed

var ui
var kitchen
var top_bar: PanelContainer
var top_margin: MarginContainer
var bottom_bar: PanelContainer
var bottom_margin: MarginContainer
var name_label: Label
var stage_label: Label
var coin_chip: HBoxContainer
var rep_card: PanelContainer
var rep_chip: HBoxContainer
var rep_progress: ProgressBar
var rep_next_label: Label
var session_card: PanelContainer
var timer_label: Label
var stats_label: Label
var speed_button: Button
var weather_icon
var weather_label: Label
var main_button: Button
var event_card: PanelContainer
var event_title: Label
var event_desc: Label
var nav_buttons: Dictionary = {}
var running: bool = false
var _safe_top: float = 0.0
var _safe_bottom: float = 0.0
var _shown_coins: float = 0.0
var _target_coins: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_event()
	_build_bottom()
	kitchen = KitchenScript.new()
	kitchen.visible = false
	add_child(kitchen)
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
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_bar.add_child(top_margin)
	var col := UIKit.vbox(6)
	top_margin.add_child(col)
	var row1 := UIKit.hbox(12)
	col.add_child(row1)
	var title_box := UIKit.vbox(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title_box)
	name_label = UIKit.label("달빛장터", "title", UIKit.ACCENT)
	name_label.add_theme_font_size_override("font_size", 30)
	title_box.add_child(name_label)
	stage_label = UIKit.label("", "caption")
	stage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(stage_label)
	var wbox := UIKit.vbox(0)
	wbox.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(wbox)
	weather_icon = UIKit.icon("cloud", 32)
	weather_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wbox.add_child(weather_icon)
	weather_label = UIKit.label("흐림", "caption")
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wbox.add_child(weather_label)
	var settings := UIKit.button("", "secondary", 64)
	settings.custom_minimum_size = Vector2(64, 64)
	var gear := UIKit.icon("settings", 32)
	gear.position = Vector2(16, 16)
	settings.add_child(gear)
	settings.pressed.connect(func(): settings_pressed.emit())
	row1.add_child(settings)
	var row2 := UIKit.hbox(12)
	col.add_child(row2)
	var coin_card := UIKit.card(UIKit.PANEL_DARK, 10)
	coin_card.custom_minimum_size = Vector2(230, 0)
	coin_chip = UIKit.currency("coin", GameManager.state.coins, "number")
	coin_card.add_child(coin_chip)
	row2.add_child(coin_card)
	# 평소: 평판 / 영업 중: 남은 시간·통계·배속
	rep_card = UIKit.card(UIKit.PANEL_DARK, 10)
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
	rep_next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rp.add_child(rep_next_label)
	rep_progress = UIKit.progress_bar(0, 1, UIKit.REP, 10)
	rp.add_child(rep_progress)
	row2.add_child(rep_card)
	session_card = UIKit.card(UIKit.PANEL_DARK, 8)
	session_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var srow := UIKit.hbox(8)
	session_card.add_child(srow)
	srow.add_child(UIKit.icon("clock", 30))
	timer_label = UIKit.label("04:00", "number")
	timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	srow.add_child(timer_label)
	stats_label = UIKit.label("", "caption", UIKit.TEXT)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 17)
	srow.add_child(stats_label)
	speed_button = UIKit.button("x1", "secondary", 56)
	speed_button.custom_minimum_size = Vector2(72, 56)
	speed_button.pressed.connect(func(): speed_pressed.emit())
	srow.add_child(speed_button)
	session_card.visible = false
	row2.add_child(session_card)


func _build_event() -> void:
	event_card = UIKit.card(Color("#6A4A22"), 8)
	event_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(event_card)
	var ecol := UIKit.vbox(2)
	event_card.add_child(ecol)
	var erow := UIKit.hbox(10)
	ecol.add_child(erow)
	erow.add_child(UIKit.icon("event", 28))
	event_title = UIKit.label("", "section")
	event_title.add_theme_font_size_override("font_size", 20)
	event_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	erow.add_child(event_title)
	event_desc = UIKit.label("", "caption", UIKit.TEXT)
	event_desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	event_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ecol.add_child(event_desc)
	event_card.visible = false


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
	bottom_margin.add_theme_constant_override("margin_left", 14)
	bottom_margin.add_theme_constant_override("margin_right", 14)
	bottom_margin.add_theme_constant_override("margin_top", 14)
	bottom_bar.add_child(bottom_margin)
	var col := UIKit.vbox(12)
	bottom_margin.add_child(col)
	main_button = UIKit.button("영업 준비", "primary", 96)
	main_button.add_theme_font_size_override("font_size", 32)
	main_button.pressed.connect(func(): main_button_pressed.emit())
	col.add_child(main_button)
	var nav := UIKit.hbox(8)
	col.add_child(nav)
	for item in [["pocha", "market", "내 포차"], ["staff", "staff", "상인"], ["rivals", "people", "시장"], ["deco", "deco", "장식"], ["shop", "shop", "상점"]]:
		var b := UIKit.button("", "ghost", 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIKit.vbox(2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var ic := UIKit.icon(item[1], 38)
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
	top_margin.add_theme_constant_override("margin_top", 8 + int(safe_top))
	bottom_margin.add_theme_constant_override("margin_bottom", 14 + int(safe_bottom))
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = top_height()
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -(238.0 + _safe_bottom)
	kitchen.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	kitchen.offset_top = -kitchen_height()
	event_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	event_card.offset_left = 18
	event_card.offset_right = -18
	event_card.offset_top = top_height() + 8
	event_card.offset_bottom = top_height() + 8


func top_height() -> float:
	return maxf(144.0, top_bar.get_combined_minimum_size().y if top_bar else 144.0) + _safe_top * 0.0


func kitchen_height() -> float:
	return 412.0 + _safe_bottom


func bottom_height() -> float:
	return kitchen_height() if running else 238.0 + _safe_bottom


func banner_space() -> float:
	return 0.0


func _process(delta: float) -> void:
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
	if GameManager.economy.has_unclaimed_result():
		main_button.text = "정산 받기"
	else:
		main_button.text = "영업 준비"
	UIKit.set_enabled(main_button, not GameManager.is_operating)


func _on_phase(phase: String) -> void:
	var was_running := running
	running = phase == "open" or phase == "closing"
	if phase == "open" and not was_running:
		if GameManager.goals.is_showdown_today():
			show_banner("대결의 밤! vs %s" % DataManager.get_rival(str(GameManager.state.showdown["rival"])).get("name", ""), UIKit.SECONDARY)
		else:
			show_banner("%d일차 영업 시작!" % GameManager.state.day)
	elif phase == "closing":
		show_banner("마감 시간!", UIKit.SECONDARY)
	session_card.visible = running
	rep_card.visible = not running
	bottom_bar.visible = not running
	kitchen.visible = running
	if not running:
		event_card.visible = false
	_update_main_button()
	if ui:
		ui.call_deferred("_on_viewport_resized")


func update_session(remaining: float, stats: Dictionary) -> void:
	var sec := int(ceil(remaining))
	timer_label.text = "%d:%02d" % [sec / 60, sec % 60]
	if stats.get("phase", "") == "closing":
		timer_label.text = "마감"
	var sd: Dictionary = stats.get("showdown", {})
	if not sd.is_empty():
		var ahead: bool = int(sd["mine"]) >= int(sd["theirs"])
		stats_label.text = "대결 %s : %s %s" % [UIKit.fmt(int(sd["mine"])), UIKit.fmt(int(sd["theirs"])), "앞섬!" if ahead else "뒤짐"]
		stats_label.add_theme_color_override("font_color", UIKit.SUCCESS if ahead else UIKit.SECONDARY)
	else:
		stats_label.text = "손님 %d · 판매 %d · 팁 %s" % [stats.get("buyers", 0), stats.get("sales", 0), UIKit.fmt(int(stats.get("tips", 0)))]
	speed_button.text = "x%d" % int(stats.get("speed", 1.0))


func show_event(ev: Dictionary) -> void:
	event_card.add_theme_stylebox_override("panel", UIKit.box(Color(DataManager.color(ev.get("color", "#FFB45C")).darkened(0.55), 0.85), UIKit.RADIUS, 8))
	event_title.text = str(ev.get("name", "이벤트"))
	var desc := str(ev.get("desc", ""))
	if ev.has("trend_name"):
		desc = "유행 메뉴: %s" % ev["trend_name"]
	event_desc.text = desc
	event_desc.visible = false
	event_title.text = "%s  ·  %s" % [ev.get("name", "이벤트"), desc]
	event_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_card.visible = true


func hide_event() -> void:
	event_card.visible = false


## 화면 가운데 큰 배너 (영업 시작/마감)
func show_banner(text: String, color: Color = UIKit.ACCENT) -> void:
	var l := UIKit.label(text, "title", color)
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	l.anchor_right = 1.0
	l.offset_top = -200
	l.offset_bottom = -120
	l.pivot_offset = Vector2(size.x / 2.0, 40)
	l.scale = Vector2(0.6, 0.6)
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


## 이전 버전 호환 (배치 모드 제거됨)
func show_mode(_text: String) -> void:
	pass
