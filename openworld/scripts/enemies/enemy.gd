extends CharacterBody3D
## 적 공용 AI: 배회 → 추적 → 공격 준비(예고 동작) → 공격 → 쉬기.
## 예고 동작이 있어서 구르기로 피할 수 있다. 멧돼지는 예고 뒤 돌진한다.
## 일정 확률로 강한 [정예] 개체가 나오고, 처치하면 전리품이 땅에 떨어진다.

const HumanoidModel = preload("res://scripts/models/humanoid_model.gd")
const WolfModel = preload("res://scripts/models/wolf_model.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Fx = preload("res://scripts/game/fx.gd")
const Pickup = preload("res://scripts/world/pickup.gd")

## loot: [아이템 id, 확률, 최소, 최대]
const TYPES := {
	"goblin": {"name": "고블린 약탈자", "hp": 45.0, "dmg": 9.0, "speed": 4.4, "range": 1.7,
		"windup": 0.55, "cooldown": 1.3, "aggro": 15.0, "xp": 12, "gold": 4, "scale": 0.9,
		"radius": 0.4, "attack_kind": 0, "quad": false,
		"loot": [["goblin_ear", 0.6, 1, 1], ["iron_ore", 0.12, 1, 1], ["potion_s", 0.08, 1, 1]]},
	"goblin_chief": {"name": "고블린 우두머리", "hp": 200.0, "dmg": 16.0, "speed": 4.0, "range": 2.2,
		"windup": 0.8, "cooldown": 1.5, "aggro": 18.0, "xp": 90, "gold": 40, "scale": 1.35,
		"radius": 0.6, "attack_kind": 3, "quad": false, "boss": true,
		"loot": [["goblin_ear", 1.0, 2, 3], ["iron_ore", 1.0, 2, 4], ["potion_l", 0.5, 1, 1]], "gear": 0.5},
	"wolf": {"name": "잿빛 늑대", "hp": 32.0, "dmg": 7.0, "speed": 7.2, "range": 1.9,
		"windup": 0.4, "cooldown": 1.1, "aggro": 20.0, "xp": 10, "gold": 1, "scale": 1.0,
		"radius": 0.5, "attack_kind": 0, "quad": true,
		"loot": [["wolf_pelt", 0.65, 1, 1], ["raw_meat", 0.4, 1, 1]]},
	"boar": {"name": "성난 멧돼지", "hp": 60.0, "dmg": 13.0, "speed": 5.0, "range": 7.0,
		"windup": 0.75, "cooldown": 1.8, "aggro": 13.0, "xp": 15, "gold": 1, "scale": 1.15,
		"radius": 0.6, "attack_kind": 0, "quad": true, "charge": true,
		"loot": [["boar_tusk", 0.55, 1, 1], ["raw_meat", 0.7, 1, 2]]},
	"skeleton": {"name": "해골 전사", "hp": 55.0, "dmg": 11.0, "speed": 4.0, "range": 1.9,
		"windup": 0.6, "cooldown": 1.2, "aggro": 18.0, "xp": 18, "gold": 6, "scale": 1.0,
		"radius": 0.4, "attack_kind": 0, "quad": false,
		"loot": [["bone_dust", 0.6, 1, 2], ["iron_ore", 0.2, 1, 1]], "gear": 0.03},
	"golem": {"name": "봉화의 수호자", "hp": 260.0, "dmg": 24.0, "speed": 3.0, "range": 3.4,
		"windup": 0.95, "cooldown": 1.8, "aggro": 22.0, "xp": 150, "gold": 40, "scale": 2.0,
		"radius": 1.2, "attack_kind": 3, "quad": false, "boss": true,
		"loot": [["golem_core", 1.0, 1, 1], ["potion_l", 0.6, 1, 2]], "gear": 0.35},
	"ogre": {"name": "오우거 족장", "hp": 900.0, "dmg": 34.0, "speed": 3.4, "range": 3.6,
		"windup": 1.0, "cooldown": 1.6, "aggro": 20.0, "xp": 400, "gold": 150, "scale": 1.9,
		"radius": 1.1, "attack_kind": 3, "quad": false, "boss": true,
		"loot": [["ogre_horn", 1.0, 1, 2], ["iron_ore", 1.0, 3, 5], ["elixir", 0.5, 1, 1], ["axe_ogre", 0.35, 1, 1]], "gear": 0.6},
}

## 장비 드롭 후보 (등급별)
const GEAR_POOL := [["sword_iron", "armor_leather", "ring_copper"], ["sword_knight", "armor_chain", "amulet_wolf"], ["ring_ember", "armor_knight"]]

const GRAVITY := 24.0

signal defeated(enemy)

var kind := "goblin"
var level := 1
var elite := false
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
var _charge_hit := false


func setup(p_kind: String, p_level: int, p_player, p_elite := false) -> void:
	kind = p_kind
	level = p_level
	player = p_player
	elite = p_elite
	_cfg = TYPES[kind]
	var hp_mult := 1.0 + 0.4 * (level - 1)
	max_hp = float(_cfg["hp"]) * hp_mult * (2.5 if elite else 1.0)
	hp = max_hp
	dmg = float(_cfg["dmg"]) * (1.0 + 0.25 * (level - 1)) * (1.4 if elite else 1.0)
	radius = float(_cfg["radius"])
	if is_boss():
		leash = 28.0


func is_boss() -> bool:
	return bool(_cfg.get("boss", false)) or elite


func display_name() -> String:
	return ("[정예] " if elite else "") + String(_cfg["name"])


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	home = global_position
	_wander_target = home
	var s: float = float(_cfg["scale"]) * (1.25 if elite else 1.0)
	var quad: bool = _cfg["quad"]
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(1.0, 1.6 * s * (0.6 if quad else 1.0))
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)

	model = WolfModel.new() if quad else HumanoidModel.new()
	model.scale = Vector3.ONE * s
	add_child(model)
	model.setup(kind)

	var top := 2.0 * s + 0.3
	if quad:
		top = 1.4 * s
	var label := Label3D.new()
	label.text = "%s  Lv.%d" % [display_name(), level]
	label.font = Fx.font()
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var lvl_gap: int = level - GameState.level
	var col_name := Color(1, 1, 1)
	if is_boss():
		col_name = Color(1, 0.8, 0.35)
	elif lvl_gap >= 3:
		col_name = Color(1, 0.45, 0.4)
	label.modulate = col_name
	label.position.y = top + 0.25
	label.visibility_range_end = 45.0
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
	var anim := ""

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
			if player_ok and _cfg.get("charge", false):
				_face(to_player)  # 돌진 전에는 계속 노려본다
			if _timer <= 0.0:
				if _cfg.get("charge", false):
					_state = "charging"
					_timer = 0.65
					_charge_hit = false
				else:
					# 예고 동작이 끝나는 순간 아직 사거리 안이면 명중
					if player_ok and dist < float(_cfg["range"]) + 0.7 and _facing.dot(to_player / maxf(dist, 0.01)) > 0.2:
						player.take_damage(dmg * randf_range(0.9, 1.1), global_position)
					if int(_cfg["attack_kind"]) == 3:
						Sfx.play("smash")
					_state = "recover"
					_timer = float(_cfg["cooldown"])
					if kind == "wolf":
						velocity += _facing * 6.0  # 물고 튀어오르기
		"charging":
			velocity.x = _facing.x * 14.0
			velocity.z = _facing.z * 14.0
			anim = "move"
			if player_ok and not _charge_hit and dist < radius + 1.2:
				_charge_hit = true
				player.take_damage(dmg * randf_range(0.9, 1.1), global_position)
			if _timer <= 0.0 or is_on_wall():
				_state = "recover"
				_timer = float(_cfg["cooldown"])
		"recover":
			if _timer <= 0.0:
				_state = "chase"
			elif player_ok and dist > 0.5 and not _cfg.get("charge", false):
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

	if _state != "charging":
		if move_dir != Vector3.ZERO:
			_face(move_dir)
		velocity.x = move_toward(velocity.x, move_dir.x * move_speed, 25.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * move_speed, 25.0 * delta)
	move_and_slide()
	var ratio := Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1)
	if anim == "":
		anim = "move" if ratio > 0.08 else "idle"
	model.animate(delta, anim, minf(ratio, 1.5))

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
	Sfx.play("crit" if crit else "hit")
	var txt := str(roundi(amount)) + ("!" if crit else "")
	Fx.popup(get_parent(), global_position + Vector3(0, 1.8 * float(_cfg["scale"]), 0), txt,
		Color(1, 0.8, 0.2) if crit else Color(1, 1, 1), 80 if crit else 60)
	if not is_boss():
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
	_bar_root.visible = hp < max_hp and not dead and not is_boss()
	var r := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fg.scale.x = maxf(r, 0.001)


func _die() -> void:
	dead = true
	hp = 0
	_update_bar()
	remove_from_group("enemies")
	Sfx.play("enemy_die")
	var mult := 3 if elite else 1
	var xp: int = int(_cfg["xp"]) * level * mult
	GameState.add_xp(xp)
	GameState.notify("kill", kind)
	Fx.popup(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d XP" % xp, Color(0.5, 0.85, 1.0), 56)
	_drop_loot(mult)
	defeated.emit(self)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(model, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)


func _drop_loot(mult: int) -> void:
	var drops := []
	var gold := int(_cfg["gold"]) * level * mult
	if gold > 0:
		drops.append(["", int(gold * randf_range(0.7, 1.3)) + 1])
	for entry in _cfg.get("loot", []):
		var chance: float = minf(1.0, float(entry[1]) * (1.5 if elite else 1.0))
		if randf() < chance:
			drops.append([entry[0], randi_range(int(entry[2]), int(entry[3]))])
	var gear_chance: float = float(_cfg.get("gear", 0.0)) + (0.3 if elite else 0.0)
	if randf() < gear_chance:
		var tier := clampi(int(level / 4.0) + (1 if is_boss() else 0), 0, GEAR_POOL.size() - 1)
		var pool: Array = GEAR_POOL[tier]
		drops.append([pool[randi() % pool.size()], 1])
	for d in drops:
		var p := Pickup.new()
		p.setup(d[0], d[1], player)
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, 1.0, 0)
