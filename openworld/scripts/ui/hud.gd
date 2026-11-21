extends CanvasLayer
## 플레이 화면 UI: 체력/기력/경험치, 메뉴 버튼, 퀘스트 추적, 레이더, 획득 알림,
## 큰 배너(레벨업·퀘스트 완료·장소 발견), 피격 효과, 보스 체력바, 터치 조작, 사망 화면.

const UI = preload("res://scripts/ui/ui_kit.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const Radar = preload("res://scripts/ui/radar.gd")
const Items = preload("res://scripts/game/items.gd")
const Quests = preload("res://scripts/game/quests.gd")

var player  # player.gd
var camera_rig  # camera_rig.gd
var beacons: Array = []
var menu  # game_menu.gd
var main  # main.gd

var _root: Control
var _hp_bar: ProgressBar
var _st_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _hp_label: Label
var _buff_label: Label
var _quest_box: PanelContainer
var _quest_title: Label
var _quest_prog: Label
var _clock: Label
var _message: Label
var _hint: Label
var _death: Label
var _feed: VBoxContainer
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _vignette: ColorRect
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _fps: Label
var _msg_tween: Tween
var _banner_tween: Tween
var _banner_queue: Array = []


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)

	# --- 왼쪽 위: 상태
	var box := UI.vbox(5)
	box.position = Vector2(20, 14)
	box.custom_minimum_size = Vector2(330, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var row := UI.hbox(8)
	box.add_child(row)
	_level_label = _label("", 26)
	row.add_child(_level_label)
	_hp_label = _label("", 18)
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_hp_label)
	_hp_bar = _bar(Color(0.85, 0.22, 0.2), 18)
	box.add_child(_hp_bar)
	_st_bar = _bar(Color(0.95, 0.78, 0.25), 10)
	box.add_child(_st_bar)
	_xp_bar = _bar(Color(0.4, 0.7, 1.0), 6)
	box.add_child(_xp_bar)
	_buff_label = _label("", 16)
	_buff_label.modulate = Color(0.75, 0.9, 1.0)
	box.add_child(_buff_label)

	# 퀘스트 추적 (누르면 퀘스트 창)
	_quest_box = PanelContainer.new()
	_quest_box.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.45), Color(0.86, 0.7, 0.38, 0.5), 8, 1, 10))
	_quest_box.custom_minimum_size = Vector2(330, 0)
	_quest_box.add_to_group("touch_block")
	_quest_box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and menu:
			menu.open_menu(2))
	box.add_child(_quest_box)
	var qv := UI.vbox(2)
	qv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_box.add_child(qv)
	_quest_title = _label("", 19)
	_quest_title.modulate = Color(1, 0.85, 0.45)
	qv.add_child(_quest_title)
	_quest_prog = _label("", 17)
	_quest_prog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_prog.custom_minimum_size = Vector2(310, 0)
	qv.add_child(_quest_prog)

	# 획득 알림
	_feed = UI.vbox(2)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_feed, 0.0, 0.5, 20, -40, 360, 200)
	_root.add_child(_feed)

	# --- 위 가운데: 메뉴 버튼들
	var btns := UI.hbox(8)
	_place(btns, 0.5, 0.0, -230, 12, 460, 56)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_to_group("touch_block")
	_root.add_child(btns)
	for b in [["가방", 0], ["장비", 1], ["퀘스트", 2], ["지도", 3], ["설정", 4]]:
		var bt := UI.button(b[0], Vector2(84, 50), 19)
		bt.pressed.connect(func() -> void:
			if menu:
				menu.open_menu(b[1]))
		btns.add_child(bt)

	# 보스 체력바
	_boss_box = UI.vbox(2)
	_place(_boss_box, 0.5, 0.0, -260, 74, 520, 50)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	_boss_name = _label("", 20)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.modulate = Color(1, 0.8, 0.4)
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color(0.75, 0.15, 0.15), 14)
	_boss_bar.custom_minimum_size = Vector2(520, 14)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false

	# --- 오른쪽 위: 레이더 + 시계
	var radar := Radar.new()
	radar.player = player
	radar.camera_rig = camera_rig
	radar.beacons = beacons
	radar.main = main
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(radar, 1.0, 0.0, -184, 14, 164, 164)
	_root.add_child(radar)
	_clock = _label("", 17)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_clock, 1.0, 0.0, -204, 182, 204, 52)
	_root.add_child(_clock)
	_fps = _label("", 16)
	_place(_fps, 1.0, 1.0, -120, -30, 110, 24)
	_root.add_child(_fps)

	# --- 가운데
	_message = _label("", 26)
	_place(_message, 0.5, 0.0, -420, 130, 840, 44)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_root.add_child(_message)

	_banner = UI.vbox(0)
	_place(_banner, 0.5, 0.5, -400, -150, 800, 120)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_title = _label("", 50)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.modulate = Color(1, 0.85, 0.4)
	_banner_title.add_theme_constant_override("outline_size", 14)
	_banner.add_child(_banner_title)
	_banner_sub = _label("", 26)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)

	_hint = _label("", 24)
	_place(_hint, 0.5, 0.5, -300, 110, 600, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_death = _label("쓰러졌다…\n마지막으로 밝힌 봉화(없으면 마을)에서 다시 일어난다", 32)
	_death.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.modulate = Color(1, 0.7, 0.65)
	_death.visible = false
	_root.add_child(_death)

	var touch := TouchControls.new()
	_root.add_child(touch)

	GameState.message.connect(show_message)
	GameState.banner.connect(show_banner)
	GameState.item_gained.connect(_on_item_gained)
	GameState.stats_changed.connect(_refresh_static)
	GameState.quests_changed.connect(_refresh_quest)
	GameState.inventory_changed.connect(_refresh_quest)
	if player:
		player.hurt.connect(_on_hurt)
	_refresh_static()
	_refresh_quest()


func _place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(330, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.55), Color(0.95, 0.85, 0.6, 0.6), 4, 2, 0))
	b.add_theme_stylebox_override("fill", UI.box(color, Color(0, 0, 0, 0), 3, 0, 0))
	return b


func _refresh_static() -> void:
	_level_label.text = "Lv.%d  카엘" % GameState.level
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp


func _refresh_quest() -> void:
	var id := GameState.tracked_quest
	if id == "" or not GameState.quests.has(id) or GameState.quest_state(id) == "done":
		_quest_box.visible = false
		return
	_quest_box.visible = true
	var q := Quests.get_quest(id)
	_quest_title.text = ("★ " if q.get("main", false) else "◆ ") + String(q["title"])
	var st := GameState.quest_state(id)
	if st == "ready":
		_quest_prog.text = "완료! %s에게 보고하자" % Quests.NPC_NAMES.get(q["turn_in"], "")
	else:
		var goal := ""
		match q["type"]:
			"talk":
				goal = "%s와 대화하기" % Quests.NPC_NAMES.get(q["target"], "")
			"beacon":
				goal = "봉화 밝히기"
			"kill":
				goal = "처치"
			"collect":
				goal = Items.item_name(q["target"]) + " 모으기"
			"chest":
				goal = "보물상자 열기"
		_quest_prog.text = "%s  %d / %d" % [goal, mini(GameState.quest_progress(id), int(q["count"])), int(q["count"])]


func _process(delta: float) -> void:
	if player == null:
		return
	_hp_bar.max_value = GameState.max_hp()
	_hp_bar.value = player.hp
	_st_bar.max_value = GameState.max_stamina()
	_st_bar.value = player.stamina
	_hp_label.text = "%d / %d   %dG" % [roundi(player.hp), roundi(GameState.max_hp()), GameState.gold]
	_hint.text = Controls.interact_hint
	_death.visible = player.dead
	# 체력이 낮으면 화면 가장자리가 붉게 맥동
	var low: float = player.hp / GameState.max_hp()
	if low < 0.3 and not player.dead:
		var pulse := 0.12 + 0.08 * sin(Time.get_ticks_msec() / 180.0)
		_vignette.color.a = maxf(_vignette.color.a * 0.95, pulse)
	else:
		_vignette.color.a = maxf(0.0, _vignette.color.a - delta * 0.8)
	# 버프
	var parts: PackedStringArray = []
	if GameState.buffs.has("atk"):
		parts.append("공격력 강화 %ds" % ceili(GameState.buffs["atk"]))
	if GameState.buffs.has("stamina"):
		parts.append("무한 기력 %ds" % ceili(GameState.buffs["stamina"]))
	_buff_label.text = "   ".join(parts)
	# 시계
	var t := GameState.time_of_day
	var hour := int(t * 24.0)
	var night := t < 0.22 or t > 0.78
	_clock.text = "%s %02d:%02d\n%s" % ["밤" if night else "낮", hour, int(fmod(t * 24.0, 1.0) * 60.0), _nearest_region()]
	_fps.visible = bool(GameState.settings.get("show_fps", false))
	if _fps.visible:
		_fps.text = "FPS %d" % Engine.get_frames_per_second()
	_update_boss()


func _update_boss() -> void:
	var best = null
	var best_d := 35.0
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in list:
		if e.is_boss() and e.hp < e.max_hp:
			var d: float = e.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = e
	_boss_box.visible = best != null
	if best:
		_boss_name.text = "%s  Lv.%d" % [best.display_name(), best.level]
		_boss_bar.max_value = best.max_hp
		_boss_bar.value = best.hp


func _nearest_region() -> String:
	if Vector2(player.global_position.x, player.global_position.z).length() < 45.0:
		return "새벽 마을"
	var best := ""
	var best_d := 1e9
	for b in beacons:
		var d: float = b.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = b.display_name()
	if best_d < 160.0:
		return best
	return "%s 방면 %dm" % [best, roundi(best_d)]


func show_message(text: String) -> void:
	_message.text = text
	if _msg_tween:
		_msg_tween.kill()
	_message.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.4)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


func show_banner(title: String, sub: String) -> void:
	_banner_queue.append([title, sub])
	if _banner_tween == null or not _banner_tween.is_running():
		_next_banner()


func _next_banner() -> void:
	if _banner_queue.is_empty():
		return
	var b: Array = _banner_queue.pop_front()
	_banner_title.text = b[0]
	_banner_sub.text = b[1]
	_banner.scale = Vector2(0.8, 0.8)
	_banner.pivot_offset = Vector2(400, 60)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(1.6)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.chain().tween_callback(_next_banner)


func _on_item_gained(id: String, n: int) -> void:
	var text := ""
	var col := Color(1, 0.85, 0.35)
	if id == "":
		text = "+ %d G" % n
	else:
		text = "+ %s x%d" % [Items.item_name(id), n]
		col = Items.rarity_color(id)
	var l := _label(text, 20)
	l.modulate = col
	_feed.add_child(l)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_hurt(amount: float) -> void:
	_vignette.color.a = clampf(0.15 + amount / GameState.max_hp(), 0.15, 0.45)
