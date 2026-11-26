extends Control
## 타이틀 — 배경에서 컴퓨터끼리 방귀 대결 데모가 돌아간다.

const LogicScript := preload("res://scripts/core/battle_logic.gd")
const AIScript := preload("res://scripts/ai/ai_controller.gd")
const ArenaScript := preload("res://scripts/battle/arena.gd")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal league_pressed
signal versus_pressed

var logic
var ais: Array = []
var arena
var sound_btn: Button
var t: float = 0.0
var title_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.build_theme()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 데모 대결
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var opp: Dictionary = Data.opponent(rng.randi() % Data.opponents.size())
	logic = LogicScript.new()
	logic.setup(Data.player, opp, Data.balance, Data.foods)
	for side in 2:
		var a = AIScript.new()
		a.setup(logic, side)
		a.def = {"ai_reaction": 0.3, "ai_accuracy": 0.1, "ai_aggression": 0.9, "ai_block": 0.3, "ai_greed": 0.8}
		ais.append(a)
	logic.start_round()
	arena = ArenaScript.new()
	add_child(arena)
	arena.setup(logic, Data.player, opp)
	var col := UIKit.vbox(16)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 60
	col.offset_bottom = -50
	title_label = UIKit.label("방귀 대결!", "title", UIKit.ACCENT)
	title_label.add_theme_font_size_override("font_size", 84)
	title_label.add_theme_constant_override("outline_size", 22)
	title_label.add_theme_color_override("font_outline_color", Color("#5A1F5A"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_label)
	var sub := UIKit.label("뿌앙 리그", "section", UIKit.SECONDARY)
	sub.add_theme_font_size_override("font_size", 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sp)
	var league := UIKit.button("혼자 하기 · 리그 도전", "primary", 104)
	league.add_theme_font_size_override("font_size", 34)
	league.pressed.connect(func():
		Sfx.play_fart("medium")
		league_pressed.emit()
	)
	col.add_child(league)
	var versus := UIKit.button("둘이서 대결 (폰 하나로)", "secondary", 96)
	versus.add_theme_font_size_override("font_size", 30)
	versus.pressed.connect(func():
		Sfx.play_fart("big")
		versus_pressed.emit()
	)
	col.add_child(versus)
	sound_btn = UIKit.button("", "ghost", 72)
	sound_btn.pressed.connect(func():
		Save.sound = not Save.sound
		Save.save_game()
		_update_sound()
	)
	col.add_child(sound_btn)
	_update_sound()
	var rec := UIKit.label("전적 %d승 %d패 · 완벽한 뿡 %d번" % [int(Save.stats["match_wins"]), int(Save.stats["matches"]) - int(Save.stats["match_wins"]), int(Save.stats["perfect"])], "caption")
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rec)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _update_sound() -> void:
	sound_btn.text = "소리 켜짐" if Save.sound else "소리 꺼짐"


func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / ArenaScript.SIZE.x, 1.2)
	arena.scale = Vector2(s, s)
	arena.base_position = Vector2((vp.x - ArenaScript.SIZE.x * s) / 2.0, vp.y * 0.24)
	arena.position = arena.base_position


func _process(delta: float) -> void:
	t += delta
	title_label.rotation = sin(t * 2.0) * 0.03
	title_label.pivot_offset = title_label.size / 2.0
	for a in ais:
		a.tick(delta)
	logic.tick(delta)
	for ev in logic.take_events():
		arena.handle_event(ev)
	if logic.round_over:
		if logic.match_over:
			logic.setup(logic.fighters[0]["def"], logic.fighters[1]["def"], Data.balance, Data.foods)
		logic.start_round()
		arena.reset_moods()
