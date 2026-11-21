extends CanvasLayer
## 화면 UI: 체력/기력/경험치, 레이더, 봉화 진행도, 알림 메시지, 터치 조작, 사망 화면.

const Fx = preload("res://scripts/game/fx.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const Radar = preload("res://scripts/ui/radar.gd")

var player  # player.gd
var camera_rig  # camera_rig.gd
var beacons: Array = []

var _root: Control
var _hp_bar: ProgressBar
var _st_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _hp_label: Label
var _beacon_label: Label
var _region_label: Label
var _message: Label
var _hint: Label
var _death: Label
var _msg_tween: Tween


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = Fx.font()
	theme.default_font_size = 22
	_root.theme = theme
	add_child(_root)

	# --- 왼쪽 위: 상태
	var box := VBoxContainer.new()
	box.position = Vector2(24, 18)
	box.custom_minimum_size = Vector2(330, 0)
	box.add_theme_constant_override("separation", 6)
	_root.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	_level_label = _label("Lv.1  카엘", 26)
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

	# --- 오른쪽 위: 레이더 + 봉화 진행도
	var radar := Radar.new()
	radar.player = player
	radar.camera_rig = camera_rig
	radar.beacons = beacons
	_place(radar, 1.0, 0.0, -194, 18, 170, 170)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(radar)
	_beacon_label = _label("", 20)
	_place(_beacon_label, 1.0, 0.0, -214, 194, 210, 30)
	_beacon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_beacon_label)
	_region_label = _label("", 16)
	_place(_region_label, 1.0, 0.0, -214, 222, 210, 26)
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.modulate = Color(1, 1, 1, 0.8)
	_root.add_child(_region_label)

	# --- 가운데: 알림, 상호작용 안내, 사망 화면
	_message = _label("", 30)
	_place(_message, 0.5, 0.0, -400, 90, 800, 50)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_root.add_child(_message)

	_hint = _label("", 24)
	_place(_hint, 0.5, 0.5, -300, 110, 600, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_death = _label("쓰러졌다…\n마지막으로 밝힌 봉화에서 다시 일어난다", 34)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.modulate = Color(1, 0.7, 0.65)
	_death.visible = false
	_root.add_child(_death)

	var touch := TouchControls.new()
	_root.add_child(touch)

	GameState.message.connect(show_message)
	GameState.stats_changed.connect(_refresh_static)
	_refresh_static()


## 화면 가장자리 기준(anchor)으로 위치 고정 → 화면 비율이 달라도 제자리
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
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.95, 0.85, 0.6, 0.6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _refresh_static() -> void:
	_level_label.text = "Lv.%d  카엘" % GameState.level
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp
	_beacon_label.text = "봉화  %d / %d" % [GameState.lit_beacons.size(), GameState.BEACON_COUNT]


func _process(_delta: float) -> void:
	if player == null:
		return
	_hp_bar.max_value = GameState.max_hp()
	_hp_bar.value = player.hp
	_st_bar.max_value = GameState.max_stamina()
	_st_bar.value = player.stamina
	_hp_label.text = "%d / %d   %dG" % [roundi(player.hp), roundi(GameState.max_hp()), GameState.gold]
	_hint.text = Controls.interact_hint
	_death.visible = player.dead
	_region_label.text = _nearest_region()


func _nearest_region() -> String:
	var best := ""
	var best_d := 1e9
	for b in beacons:
		var d: float = b.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = b.display_name()
	if best_d < 160.0:
		return best
	return "%s 방면  %dm" % [best, roundi(best_d)]


func show_message(text: String) -> void:
	_message.text = text
	if _msg_tween:
		_msg_tween.kill()
	_message.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.4)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.8)
