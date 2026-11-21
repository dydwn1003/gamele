extends Node3D
## 마을 NPC. 다가가면 '대화하기', 머리 위에 퀘스트 표시(! / ?)가 뜬다.

const HumanoidModel = preload("res://scripts/models/humanoid_model.gd")
const Quests = preload("res://scripts/game/quests.gd")
const Fx = preload("res://scripts/game/fx.gd")

var npc_id := "elder"
var player
var interact_radius := 3.2

var model: HumanoidModel
var _marker: Label3D
var _timer := 0.0
var _base_yaw := 0.0


func setup(id: String, p_player, yaw: float) -> void:
	npc_id = id
	player = p_player
	_base_yaw = yaw


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	model = HumanoidModel.new()
	add_child(model)
	model.setup(npc_id)
	model.rotation.y = _base_yaw

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	add_child(body)

	var name_label := Label3D.new()
	name_label.text = Quests.NPC_NAMES.get(npc_id, npc_id)
	name_label.font = Fx.font()
	name_label.font_size = 44
	name_label.outline_size = 10
	name_label.pixel_size = 0.006
	name_label.modulate = Color(0.7, 1.0, 0.7)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position.y = 2.25
	name_label.visibility_range_end = 30.0
	add_child(name_label)

	_marker = Label3D.new()
	_marker.font = Fx.font()
	_marker.font_size = 140
	_marker.outline_size = 18
	_marker.pixel_size = 0.006
	_marker.modulate = Color(1.0, 0.82, 0.2)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.position.y = 2.85
	add_child(_marker)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_marker.text = GameState.npc_marker(npc_id)
	_marker.position.y = 2.85 + sin(Time.get_ticks_msec() / 300.0) * 0.08
	var yaw := _base_yaw
	if player and is_instance_valid(player):
		var d: Vector3 = player.global_position - global_position
		d.y = 0
		if d.length() < 6.0 and d.length() > 0.1:
			yaw = atan2(-d.x, -d.z)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, 1.0 - exp(-6.0 * delta))
	model.animate(delta, "idle", 0.0)


func interact_text() -> String:
	return "대화하기"


func interact() -> void:
	get_tree().call_group("dialog_ui", "open_npc", npc_id)
