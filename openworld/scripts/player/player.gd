extends CharacterBody3D
## 주인공 카엘. 이동·질주·점프·망토 활공·구르기·3단 콤보·수영.

signal died
signal hurt(amount: float)

const HumanoidModel = preload("res://scripts/models/humanoid_model.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Fx = preload("res://scripts/game/fx.gd")
const CameraRig = preload("res://scripts/player/camera_rig.gd")
const Items = preload("res://scripts/game/items.gd")

const RUN_SPEED := 7.5
const SPRINT_SPEED := 12.0
const SWIM_SPEED := 3.6
const JUMP_VELOCITY := 8.0
const GRAVITY := 24.0
const GLIDE_FALL := 2.4
const GLIDE_SPEED := 11.0

# 콤보: [지속시간, 타격 시점, 사거리, 판정 각도(dot), 피해 배율]
const COMBO := [
	[0.38, 0.16, 2.8, 0.25, 1.0],
	[0.36, 0.14, 2.9, 0.0, 1.15],
	[0.55, 0.28, 3.3, -1.0, 1.8],
]

var camera_rig: CameraRig
var model: HumanoidModel

var hp := 100.0
var stamina := 100.0
var dead := false

var gliding := false
var swimming := false
var sprinting := false
var _attack_i := -1
var _attack_t := 0.0
var _attack_hit_done := false
var _attack_queued := false
var _dodge_t := -1.0
var _dodge_dir := Vector3.ZERO
var _invuln := 0.0
var _stamina_delay := 0.0
var _last_level := 1
var _facing := Vector3.FORWARD
var _speed_ratio := 0.0
var _last_safe := Vector3.ZERO
var _potion_cd := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	refresh_model()
	hp = GameState.max_hp()
	stamina = GameState.max_stamina()
	_last_level = GameState.level
	_last_safe = global_position
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.equipment_changed.connect(refresh_model)


## 장비에 맞춰 겉모습(튜닉 색, 판금, 칼날 색·길이)을 다시 만든다
func refresh_model() -> void:
	var yaw := 0.0
	if model:
		yaw = model.rotation.y
		model.queue_free()
	var weapon := Items.get_item(GameState.equipment["weapon"])
	var armor := Items.get_item(GameState.equipment["armor"])
	var opts := {
		"tint": armor.get("tint", Color(0.55, 0.12, 0.12)),
		"plate": armor.get("plate", false),
		"blade": weapon.get("blade", Color(0.78, 0.8, 0.84)),
		"blade_len": weapon.get("len", 0.9),
	}
	model = HumanoidModel.new()
	add_child(model)
	model.setup("hero", opts)
	model.rotation.y = yaw


func _on_stats_changed() -> void:
	hp = minf(hp, GameState.max_hp())
	if GameState.level > _last_level:
		_last_level = GameState.level
		hp = GameState.max_hp()
		stamina = GameState.max_stamina()
		Fx.popup(get_parent(), global_position + Vector3(0, 2.4, 0), "LEVEL UP", Color(1, 0.85, 0.3), 80)


func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_potion_cd = maxf(0.0, _potion_cd - delta)
	if dead:
		velocity.x = 0
		velocity.z = 0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		model.animate(delta, "dead", 0.0)
		return

	var mv := Controls.get_move()
	var dir := Vector3.ZERO
	if camera_rig:
		dir = camera_rig.right() * mv.x - camera_rig.forward() * mv.y
	var mag := clampf(mv.length(), 0.0, 1.0)
	if dir.length() > 0.001:
		dir = dir.normalized()

	var on_floor := is_on_floor()
	swimming = global_position.y < Terrain.WATER_LEVEL - 1.0 and not on_floor
	if on_floor or swimming:
		gliding = false

	sprinting = Controls.held("sprint") and mag > 0.1 and stamina > 1.0 and (on_floor or swimming)

	# --- 입력 처리
	if Controls.consume("potion"):
		use_quick_potion()
	if Controls.consume("dodge") and _dodge_t < 0.0 and on_floor and stamina >= 20.0:
		_start_dodge(dir if mag > 0.1 else _facing)
	if Controls.consume("attack") and on_floor and _dodge_t < 0.0:
		if _attack_i < 0:
			_start_attack(0)
		else:
			_attack_queued = true
	if Controls.consume("jump"):
		if on_floor and _attack_i < 0 and _dodge_t < 0.0:
			velocity.y = JUMP_VELOCITY
			on_floor = false
		elif not on_floor and not swimming:
			gliding = (not gliding) and stamina > 5.0

	# --- 상태별 이동
	var state := "idle"
	var progress := 0.0
	if _dodge_t >= 0.0:
		_dodge_t += delta
		var t := _dodge_t / 0.45
		var spd := lerpf(15.0, 4.0, t)
		velocity.x = _dodge_dir.x * spd
		velocity.z = _dodge_dir.z * spd
		state = "dodge"
		progress = clampf(t, 0.0, 1.0)
		if _dodge_t >= 0.45:
			_dodge_t = -1.0
	elif _attack_i >= 0:
		_update_attack(delta)
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		state = "idle"
	else:
		var speed := RUN_SPEED * mag
		if sprinting:
			speed = SPRINT_SPEED
		if swimming:
			speed = SWIM_SPEED * (1.6 if sprinting else 1.0) * mag
		if gliding:
			var g_dir := dir if mag > 0.1 else _facing
			var target := g_dir * GLIDE_SPEED
			velocity.x = lerpf(velocity.x, target.x, 2.5 * delta)
			velocity.z = lerpf(velocity.z, target.z, 2.5 * delta)
			if mag > 0.1:
				_face(dir, delta * 0.4)
		else:
			var accel := 30.0 if on_floor else 8.0
			velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
			velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
			if mag > 0.1:
				_face(dir, delta)
		_speed_ratio = Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED
		if swimming:
			state = "swim"
		elif gliding:
			state = "glide"
		elif not on_floor:
			state = "air"
		elif _speed_ratio > 0.05:
			state = "move"

	# --- 중력 / 부력 / 활공
	if swimming:
		var target_y := Terrain.WATER_LEVEL - 1.15
		velocity.y = (target_y - global_position.y) * 4.0
	elif gliding:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -GLIDE_FALL)
	elif not on_floor:
		velocity.y -= GRAVITY * delta

	move_and_slide()
	_update_stamina(delta)
	model.animate(delta, state, _speed_ratio * 1.3, progress)
	_safety_net()


func _face(dir: Vector3, delta: float) -> void:
	var f := _facing.lerp(dir, clampf(12.0 * delta, 0.0, 1.0))
	_facing = f.normalized() if f.length() > 0.01 else dir
	model.rotation.y = atan2(-_facing.x, -_facing.z)


func _snap_face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	_facing = dir.normalized()
	model.rotation.y = atan2(-_facing.x, -_facing.z)


func use_quick_potion() -> void:
	if _potion_cd > 0.0 or dead:
		return
	var id := GameState.best_heal_item(GameState.max_hp() - hp)
	if id == "":
		GameState.message.emit("회복 아이템이 없다")
		Sfx.play("error")
		return
	if hp >= GameState.max_hp():
		GameState.message.emit("체력이 가득 차 있다")
		return
	var msg := GameState.use_item(id, self)
	if msg != "":
		_potion_cd = 1.0
		Fx.popup(get_parent(), global_position + Vector3(0, 2.2, 0), "+HP", Color(0.4, 1.0, 0.5), 60)


func _update_stamina(delta: float) -> void:
	var cap := GameState.max_stamina()
	if GameState.buffs.has("stamina"):
		stamina = cap
		return
	var using := false
	if sprinting:
		stamina -= 14.0 * delta
		using = true
	if gliding:
		stamina -= 9.0 * delta
		using = true
		if stamina <= 0.0:
			gliding = false
			GameState.message.emit("기력이 바닥났다!")
	if swimming and not sprinting:
		stamina -= 3.0 * delta
		using = true
		if stamina <= 0.0:
			take_damage(6.0 * delta, Vector3.ZERO, true)
	if using:
		_stamina_delay = 0.8
	else:
		_stamina_delay -= delta
		if _stamina_delay <= 0.0:
			stamina += 30.0 * delta
	stamina = clampf(stamina, 0.0, cap)


func _start_dodge(d: Vector3) -> void:
	_attack_i = -1
	_dodge_t = 0.0
	_dodge_dir = d.normalized()
	_snap_face(_dodge_dir)
	_invuln = 0.4
	if not GameState.buffs.has("stamina"):
		stamina -= 20.0
	_stamina_delay = 0.8
	Sfx.play("dodge")


func _start_attack(i: int) -> void:
	_attack_i = i
	_attack_t = 0.0
	_attack_hit_done = false
	_attack_queued = false
	# 가까운 적 쪽으로 자동 조준 (모바일 편의)
	var target := _nearest_enemy(6.0)
	if target:
		_snap_face(target.global_position - global_position)
	var spec: Array = COMBO[i]
	model.play_attack(i, spec[0])
	Sfx.play("swing", 0.12)
	# 살짝 앞으로 내딛기
	velocity.x = _facing.x * 5.0
	velocity.z = _facing.z * 5.0


func _update_attack(delta: float) -> void:
	var spec: Array = COMBO[_attack_i]
	_attack_t += delta
	if not _attack_hit_done and _attack_t >= spec[1]:
		_attack_hit_done = true
		_deal_damage(spec[2], spec[3], spec[4])
	if _attack_t >= spec[0]:
		if _attack_queued and _attack_i < COMBO.size() - 1:
			_start_attack(_attack_i + 1)
		else:
			_attack_i = -1


func _deal_damage(reach: float, min_dot: float, mult: float) -> void:
	var hit_any := false
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in list:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > reach + e.radius:
			continue
		if d > 0.3 and _facing.dot(to / d) < min_dot:
			continue
		var crit := randf() < GameState.crit_chance()
		var dmg := GameState.attack_power() * mult * randf_range(0.9, 1.1) * (1.8 if crit else 1.0)
		e.take_damage(dmg, global_position, crit)
		hit_any = true
	if hit_any:
		_shake_camera()


func _shake_camera() -> void:
	if camera_rig and camera_rig.camera:
		var cam := camera_rig.camera
		var tw := cam.create_tween()
		tw.tween_property(cam, "h_offset", 0.08, 0.03)
		tw.tween_property(cam, "h_offset", -0.06, 0.03)
		tw.tween_property(cam, "h_offset", 0.0, 0.04)


func _nearest_enemy(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in list:
		if e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func take_damage(amount: float, from: Vector3, silent := false) -> void:
	if dead or (_invuln > 0.0 and not silent):
		return
	if not silent:
		amount = GameState.reduce_damage(amount)
	hp -= amount
	if not silent:
		Sfx.play("hurt")
		hurt.emit(amount)
		_invuln = 0.35
		model.flash()
		Fx.popup(get_parent(), global_position + Vector3(0, 2.0, 0), str(roundi(amount)), Color(1, 0.35, 0.3))
		if from != Vector3.ZERO:
			var kb := global_position - from
			kb.y = 0
			if kb.length() > 0.01:
				kb = kb.normalized() * 6.0
				velocity.x = kb.x
				velocity.z = kb.z
		_attack_i = -1
	if hp <= 0.0:
		hp = 0.0
		dead = true
		gliding = false
		var lost := GameState.gold / 10
		if lost > 0:
			GameState.add_gold(-lost)
			GameState.message.emit("골드를 %dG 잃었다" % lost)
		died.emit()


func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	hp = GameState.max_hp()
	stamina = GameState.max_stamina()
	dead = false
	_invuln = 2.0
	_attack_i = -1
	_dodge_t = -1.0


## 아직 지형이 만들어지기 전이거나 틈으로 빠졌을 때 지면 위로 되돌린다
func _safety_net() -> void:
	var p := global_position
	var ground := Terrain.height(p.x, p.z)
	if p.y < ground - 2.0:
		global_position.y = ground + 0.5
		velocity.y = 0.0
	if is_on_floor() and p.y > Terrain.WATER_LEVEL + 0.3:
		_last_safe = p
