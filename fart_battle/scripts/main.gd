extends Node
## Main — 화면 전환 (타이틀 → 상대 고르기 → 대결)

const TitleScript := preload("res://scripts/ui/title.gd")
const SelectScript := preload("res://scripts/ui/select.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")

var current: Node = null
var layer: CanvasLayer


func _ready() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	show_title()


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	layer.add_child(n)


func show_title() -> void:
	var t = TitleScript.new()
	t.league_pressed.connect(show_select)
	t.versus_pressed.connect(func():
		var r := RandomNumberGenerator.new()
		r.randomize()
		start_battle("versus", r.randi() % Data.opponents.size())
	)
	_swap(t)


func show_select() -> void:
	var s = SelectScript.new()
	s.picked.connect(func(i: int): start_battle("league", i))
	s.back.connect(show_title)
	_swap(s)


func start_battle(mode: String, opp: int):
	var b = BattleScript.new()
	b.setup(mode, opp)
	b.exit_requested.connect(show_title if mode == "versus" else show_select)
	b.next_requested.connect(func(i: int): start_battle(mode, i))
	_swap(b)
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current and current.get_script() != TitleScript:
			show_title()
