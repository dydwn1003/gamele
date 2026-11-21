extends CanvasLayer
## 타이틀 화면: 이어하기 / 새 게임. 뒤에서는 카메라가 마을 주변을 천천히 돈다.

const UI = preload("res://scripts/ui/ui_kit.gd")

var main
var _root: Control
var _confirm: Control
var _angle := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.05, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var v := UI.vbox(14)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -300
	v.offset_right = 300
	v.offset_top = -250
	v.offset_bottom = 250
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(v)
	var title := UI.label("에버린", 120, Color(1.0, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.02))
	v.add_child(title)
	var sub := UI.label("— 잊힌 봉화 —", 36, Color(1.0, 0.95, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_constant_override("outline_size", 10)
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	if GameState.has_save():
		var cont := UI.button("이어하기", Vector2(340, 70), 30)
		cont.pressed.connect(_continue)
		v.add_child(cont)
	var newg := UI.button("새 게임", Vector2(340, 70), 30)
	newg.pressed.connect(_new_game_pressed)
	v.add_child(newg)
	var hint := UI.label("터치: 왼쪽 드래그 이동 · 오른쪽 드래그 카메라", 18, Color(1, 1, 1, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	for c in v.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ver := UI.label("v0.2  ·  Godot 4", 16, Color(1, 1, 1, 0.5))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 16
	ver.offset_top = -34
	_root.add_child(ver)
	Sfx.play_music("title")


func _process(delta: float) -> void:
	# 마을 위를 천천히 도는 카메라
	_angle += delta * 0.08
	if main and main.rig:
		main.rig.yaw = _angle
		main.rig.pitch = -0.42
		main.rig.spring.spring_length = 16.0
		main.rig.spring.collision_mask = 0  # 지붕에 걸리지 않게
		main.rig.spring.process_mode = Node.PROCESS_MODE_ALWAYS  # 게임이 멈춰 있어도 카메라 팔은 움직이게
		main.rig.rotation = Vector3(main.rig.pitch, main.rig.yaw, 0)


func _continue() -> void:
	Sfx.play("quest")
	main.start_game()
	queue_free()


func _new_game_pressed() -> void:
	if GameState.has_save() and _confirm == null:
		_confirm = PanelContainer.new()
		_confirm.anchor_left = 0.5
		_confirm.anchor_right = 0.5
		_confirm.anchor_top = 0.5
		_confirm.anchor_bottom = 0.5
		_confirm.offset_left = -280
		_confirm.offset_right = 280
		_confirm.offset_top = -120
		_confirm.offset_bottom = 120
		_root.add_child(_confirm)
		var v := UI.vbox(16)
		_confirm.add_child(v)
		v.add_child(UI.label("새 게임을 시작하면 기존 저장 기록이 지워집니다.", 22, UI.TEXT, true))
		var h := UI.hbox(12)
		v.add_child(h)
		var yes := UI.button("새로 시작", Vector2(200, 60))
		yes.pressed.connect(_start_new)
		h.add_child(yes)
		var no := UI.button("취소", Vector2(160, 60))
		no.pressed.connect(func() -> void:
			_confirm.queue_free()
			_confirm = null)
		h.add_child(no)
		return
	_start_new()


func _start_new() -> void:
	GameState.new_game()
	GameState.skip_title = true
	get_tree().paused = false
	get_tree().reload_current_scene()
