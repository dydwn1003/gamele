extends Node3D
## 보물상자. 주변 야영지의 적을 모두 쓰러뜨리면 열 수 있다. 연 상자는 저장된다.

const LowPoly = preload("res://scripts/models/low_poly.gd")
const Pickup = preload("res://scripts/world/pickup.gd")

const LOOT := [
	["potion_s", "potion_l", "iron_ore", "herb", "stamina_potion"],
	["potion_l", "iron_ore", "stamina_potion", "elixir"],
]
const GEAR := [["sword_iron", "armor_leather", "ring_copper"], ["sword_knight", "armor_chain", "amulet_wolf"], ["ring_ember", "armor_knight", "sword_flame"]]

var chest_id := ""
var tier := 0
var camp  # camp.gd (적이 남아있는지 확인)
var player
var interact_radius := 2.8
var opened := false
var _lid: Node3D


func _ready() -> void:
	add_to_group("interactable")
	opened = GameState.opened_chests.has(chest_id)
	var gold := Color(0.9, 0.72, 0.25)
	var wood := Color(0.5, 0.32, 0.18) if tier < 2 else Color(0.3, 0.25, 0.35)
	var lp := LowPoly.new()
	lp.box(Vector3(0, 0.3, 0), Vector3(1.1, 0.6, 0.7), wood)
	lp.box(Vector3(0, 0.3, -0.355), Vector3(1.12, 0.1, 0.02), gold)
	lp.box(Vector3(-0.45, 0.3, 0), Vector3(0.08, 0.62, 0.72), gold)
	lp.box(Vector3(0.45, 0.3, 0), Vector3(0.08, 0.62, 0.72), gold)
	add_child(lp.instance())
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, 0.35)
	add_child(_lid)
	var l := LowPoly.new()
	l.box(Vector3(0, 0.12, -0.35), Vector3(1.12, 0.24, 0.72), wood.lightened(0.1))
	l.box(Vector3(0, 0.05, -0.72), Vector3(0.16, 0.18, 0.04), gold)  # 자물쇠
	_lid.add_child(l.instance())
	if opened:
		_lid.rotation.x = -1.9
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.1, 0.8, 0.7)
	cs.shape = bx
	cs.position.y = 0.4
	body.add_child(cs)
	add_child(body)


func interact_text() -> String:
	if opened:
		return ""
	if camp and camp.alive_count() > 0:
		return "적이 상자를 지키고 있다 (%d)" % camp.alive_count()
	return "보물상자 열기"


func interact() -> void:
	if opened or (camp and camp.alive_count() > 0):
		Sfx.play("error")
		return
	opened = true
	GameState.open_chest(chest_id)
	Sfx.play("chest")
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -1.9, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drops := [["", randi_range(30, 70) * (tier + 1)]]
	var pool: Array = LOOT[mini(tier, LOOT.size() - 1)]
	for i in 2 + tier:
		drops.append([pool[randi() % pool.size()], 1])
	if randf() < 0.35 + tier * 0.25:
		var g: Array = GEAR[mini(tier, GEAR.size() - 1)]
		drops.append([g[randi() % g.size()], 1])
	for d in drops:
		var p := Pickup.new()
		p.setup(d[0], d[1], player)
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, 1.0, 0)
