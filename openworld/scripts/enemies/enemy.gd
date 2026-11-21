extends CharacterBody3D
## 적 공용 AI: 배회 → 추적 → 공격 준비(예고 동작) → 공격 → 쉬기.
## 예고 동작이 있어서 구르기로 피할 수 있다. 시작 지점에서 멀수록 레벨이 오른다.

const HumanoidModel = preload("res://scripts/models/humanoid_model.gd")
const WolfModel = preload("res://scripts/models/wolf_model.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Fx = preload("res://scripts/game/fx.gd")

const TYPES := {
	"goblin": {"name": "고블린 약탈자", "hp": 45.0, "dmg": 9.0, "speed": 4.4, "range": 1.7,
		"windup": 0.55, "cooldown": 1.3, "aggro": 15.0, "xp": 12, "gold": 3, "scale": 0.9,
		"radius": 0.4, "attack_kind": 0},
	"wolf": {"name": "잿빛 늑대", "hp": 32.0, "dmg": 7.0, "speed": 7.2, "range": 1.9,
		"windup": 0.4, "cooldown": 1.1, "aggro": 20.0, "xp": 10, "gold": 1, "scale": 1.0,
		"radius": 0.5, "attack_kind": 0},
	"golem": {"name": "봉화의 수호자", "hp": 260.0, "dmg": 24.0, "speed": 3.0, "range": 3.4,
		"windup": 0.95, "cooldown": 1.8, "aggro": 22.0, "xp": 150, "gold": 40, "scale": 2.0,
		"radius": 1.2, "attack_kind": 3},
}

const GRAVITY := 24.0

var kind := "goblin"
var level := 1
var max_hp := 40.0
var hp := 40.0
var dmg := 8.0
var radius := 0.4
var dead := false
var home := Vector3.ZERO
var leash := 45.0
var player  # 플레이어 (player.gd)
var model  # HumanoidModel 또는 WolfModel

var _cfg: Dictionary
var _state := "wander"
var _timer := 0.0
var _wander_target := Vector3.ZERO
var _facing := Vector3.FORWARD
var _bar_fg: MeshInstance3D
var _bar_root: Node3D


func setup(p_kind: String, p_level: int, p_player) -> void:
	kind = p_kind
	level = p_level
	player = p_player
	_cfg = TYPES[kind]
	var hp_mult := 1.0 + 0.4 * (level - 1)
	max_hp = float(_cfg["hp"]) * hp_mult
	hp = max_hp
	dmg = float(_cfg["dmg"]) * (1.0 + 0.25 * (level - 1))
	radius = float(_cfg["radius"])
	if kind == "golem":
		leash = 28.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	home = global_position
	_wander_target = home
	var s: float = _cfg["scale"]
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(1.0, 1.6 * s * (0.6 if kind == "wolf" else 1.0))
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)

	if kind == "wolf":
		model = WolfModel.new()
	else:
		model = HumanoidModel.new()
	model.scale = Vector3.ONE * s
	add_child(model)
	model.setup(kind)

	var top := 2.0 * s + 0.3
	if kind == "wolf":
		top = 1.4
	var label := Label3D.new()
	label.text = "%s  Lv.%d" % [_cfg["name"], level]
	label.font = Fx.font()
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.85, 0.5) if kind == "golem" else Color(1, 1, 1)
	label.position.y = top + 0.25
	label.visibility_range_end = 40.0
	add_child(label)
	_build_bar(top)


func _build_bar(y: float) -> void:
	_bar_root = Node3D.new()
	_bar_root.position.y = y
	add_child(_bar_root)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 0.12)
	bg.mesh = q
	bg.material_override = _bar_mat(Color(0.1, 0.1, 0.1, 0.8))
	_bar_root.add_child(bg)
	_bar_fg = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.14, 0.08)
	_bar_fg.mesh = q2
	_bar_fg.material_override = _bar_mat(Color(0.9, 0.2, 0.2))
	_bar_fg.position.z = 0.001
	_bar_root.add_child(_bar_fg)
	_bar_root.visible = false


func _bar_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = 1 if c.r > 0.5 else 0
	return m


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if dead:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		model.animate(delta, "dead", 0.0)
		return

	var speed: float = _cfg["speed"]
	var to_player := Vector3.ZERO
	var dist := 9999.0
	var player_ok: bool = player != null and is_instance_valid(player) and not player.dead
	if player_ok:
		to_player = player.global_position - global_position
		to_player.y = 0
		dist = to_player.length()
	var from_home := global_position.distance_to(home)
	_timer -= delta
	var move_dir := Vector3.ZERO
	var move_speed := 0.0

	match _state:
		"wander":
			if player_ok and dist < float(_cfg["aggro"]):
				_state = "chase"
			elif _timer <= 0.0:
				_timer = randf_range(2.5, 6.0)
				var a := randf() * TAU
				_wander_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 10.0)
			else:
				var to := _wander_target - global_position
				to.y = 0
				if to.length() > 1.0:
					move_dir = to.normalized()
					move_speed = speed * 0.35
		"chase":
			if not player_ok or from_home > leash or dist > float(_cfg["aggro"]) * 2.2:
				_state = "return"
			elif dist < float(_cfg["range"]):
				_state = "windup"
				_timer = float(_cfg["windup"])
				_face(to_player)
				model.play_attack(int(_cfg["attack_kind"]), float(_cfg["windup"]) + 0.2)
			else:
				move_dir = to_player / maxf(dist, 0.01)
				move_speed = speed
		"windup":
			if _timer <= 0.0:
				# 예고 동작이 끝나는 순간 아직 사거리 안이면 명중
				if player_ok and dist < float(_cfg["range"]) + 0.7 and _facing.dot(to_player / maxf(dist, 0.01)) > 0.2:
					player.take_damage(dmg * randf_range(0.9, 1.1), global_position)
				_state = "recover"
				_timer = float(_cfg["cooldown"])
				if kind == "wolf":
					velocity += _facing * 6.0  # 물고 튀어오르기
		"recover":
			if _timer <= 0.0:
				_state = "chase"
			elif player_ok and dist > 0.5:
				_face(to_player)
		"return":
			var to := home - global_position
			to.y = 0
			if to.length() < 2.0:
				_state = "wander"
				hp = max_hp
				_update_bar()
			else:
				move_dir = to.normalized()
				move_speed = speed
				hp = minf(max_hp, hp + max_hp * 0.2 * delta)

	if move_dir != Vector3.ZERO:
		_face(move_dir)
	velocity.x = move_toward(velocity.x, move_dir.x * move_speed, 25.0 * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * move_speed, 25.0 * delta)
	move_and_slide()
	var ratio := Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1)
	model.animate(delta, "move" if ratio > 0.08 else "idle", ratio)

	var ground := Terrain.height(global_position.x, global_position.z)
	if global_position.y < ground - 2.0:
		global_position.y = ground + 0.5
		velocity.y = 0


func _face(d: Vector3) -> void:
	d.y = 0
	if d.length() < 0.01:
		return
	_facing = d.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-_facing.x, -_facing.z), 0.3)


func take_damage(amount: float, from: Vector3, crit := false) -> void:
	if dead:
		return
	hp -= amount
	model.flash()
	var txt := str(roundi(amount)) + ("!" if crit else "")
	Fx.popup(get_parent(), global_position + Vector3(0, 1.8 * float(_cfg["scale"]), 0), txt,
		Color(1, 0.8, 0.2) if crit else Color(1, 1, 1), 80 if crit else 60)
	if kind != "golem":
		var kb := global_position - from
		kb.y = 0
		if kb.length() > 0.01:
			velocity += kb.normalized() * 5.0
	if _state == "wander" or _state == "return":
		_state = "chase"
	_update_bar()
	if hp <= 0.0:
		_die()


func _update_bar() -> void:
	_bar_root.visible = hp < max_hp and not dead
	var r := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fg.scale.x = maxf(r, 0.001)


func _die() -> void:
	dead = true
	hp = 0
	_update_bar()
	remove_from_group("enemies")
	var xp: int = int(_cfg["xp"]) * level
	var gold: int = int(_cfg["gold"]) * level
	GameState.add_xp(xp)
	GameState.add_gold(gold)
	Fx.popup(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d XP" % xp, Color(0.5, 0.85, 1.0), 56)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(model, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)
