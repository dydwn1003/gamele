extends Node3D
## 봉화탑. 수호자(바위 골렘)를 쓰러뜨리고 불을 붙이면 부활 지점이 되고,
## 하늘로 솟는 빛기둥이 생겨 멀리서도 보인다.

const LowPoly = preload("res://scripts/models/low_poly.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Terrain = preload("res://scripts/world/terrain.gd")

const NAMES := ["새벽 언덕", "늑대 숲", "서리 봉우리", "잿빛 고원", "등대 곶", "고목 계곡", "왕의 무덤"]

var index := 0
var player  # 플레이어 (player.gd)
var guardian  # 수호자 골렘 (enemy.gd)
var lit := false

var _fire: Node3D
var _light: OmniLight3D
var _beam: MeshInstance3D


func setup(p_index: int, pos: Vector3, p_player) -> void:
	index = p_index
	player = p_player
	position = pos


func display_name() -> String:
	return NAMES[index % NAMES.size()]


var interact_radius := 7.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("beacons")
	var stone := Color(0.62, 0.6, 0.56)
	var stone_d := Color(0.45, 0.44, 0.42)
	var wood := Color(0.42, 0.28, 0.16)
	var lp := LowPoly.new()
	lp.box(Vector3(0, -0.5, 0), Vector3(7, 2.0, 7), stone_d)  # 기단 (지형에 박히도록 아래로)
	lp.box(Vector3(0, 0.6, 0), Vector3(5.5, 0.4, 5.5), stone)
	lp.cylinder(Vector3(0, 0.8, 0), 1.9, 1.3, 8.0, 8, stone)
	for i in 4:  # 층마다 띠
		lp.cylinder(Vector3(0, 2.5 + i * 1.8, 0), 1.85 - i * 0.13, 1.8 - i * 0.13, 0.25, 8, stone_d)
	lp.box(Vector3(0, 8.9, 0), Vector3(3.6, 0.4, 3.6), stone_d)
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			lp.box(Vector3(x, 9.4, z), Vector3(0.4, 0.8, 0.4), stone)
	lp.cylinder(Vector3(0, 9.1, 0), 0.9, 1.1, 0.7, 8, Color(0.25, 0.22, 0.2))  # 화로
	for i in 5:  # 쌓아둔 장작
		var a := TAU * i / 5.0
		lp.box(Vector3(cos(a) * 0.4, 9.9, sin(a) * 0.4), Vector3(0.15, 0.15, 0.9), wood,
			Transform3D(Basis(Vector3.UP, a), Vector3.ZERO))
	# 입구
	lp.box(Vector3(0, 1.8, -1.75), Vector3(1.1, 2.0, 0.3), Color(0.2, 0.16, 0.12))
	add_child(lp.instance())

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.9
	cyl.height = 10.0
	cs.shape = cyl
	cs.position.y = 5.0
	body.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(5.5, 1.0, 5.5)
	cs2.shape = bx
	cs2.position.y = 0.3
	body.add_child(cs2)
	add_child(body)

	lit = GameState.is_beacon_lit(index)
	if lit:
		_ignite(false)


func _ignite(announce: bool) -> void:
	lit = true
	_fire = Node3D.new()
	_fire.position.y = 9.8
	add_child(_fire)
	var f := LowPoly.new()
	f.cylinder(Vector3.ZERO, 0.75, 0.0, 2.0, 6, Color(1.0, 0.45, 0.1))
	f.cylinder(Vector3(0, 0.1, 0), 0.45, 0.0, 1.5, 5, Color(1.0, 0.85, 0.3))
	var fm := f.instance(false)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	fm.material_override = mat
	_fire.add_child(fm)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.3)
	_light.omni_range = 26.0
	_light.light_energy = 2.5
	_light.position.y = 1.5
	_fire.add_child(_light)

	# 멀리서도 보이는 빛기둥
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.9
	cm.height = 160.0
	cm.radial_segments = 8
	_beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(1.0, 0.5, 0.15, 0.16)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 10.0 + 80.0
	add_child(_beam)
	if announce:
		GameState.light_beacon(index, global_position + Vector3(0, 1.2, -4.5))


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	var guardian_alive: bool = guardian != null and is_instance_valid(guardian) and not guardian.dead
	if guardian != null and is_instance_valid(guardian) and guardian.dead and not GameState.defeated_guardians.has(index):
		GameState.mark_guardian_defeated(index)

	# 수호자 등장/퇴장
	if not lit and not GameState.defeated_guardians.has(index):
		if not guardian_alive and dist < 110.0 and (guardian == null or not is_instance_valid(guardian)):
			_spawn_guardian()
		elif guardian_alive and dist > 220.0:
			guardian.queue_free()
			guardian = null



## ---- 상호작용 (interaction.gd 가 호출)
func interact_text() -> String:
	if lit:
		return ""
	if _guardian_alive():
		return "수호자를 먼저 쓰러뜨려야 한다"
	return "봉화 밝히기"


func interact() -> void:
	if lit or _guardian_alive():
		Sfx.play("error")
		return
	_ignite(true)


func _guardian_alive() -> bool:
	return guardian != null and is_instance_valid(guardian) and not guardian.dead


func _spawn_guardian() -> void:
	var g := Enemy.new()
	# 수호자 레벨은 거리 대신 "몇 번째 봉화인지"로 정한다 → 어느 봉화부터 가도 난이도가 차례로 오른다
	var lvl := 2 + GameState.lit_beacons.size() * 2
	g.setup("golem", lvl, player)
	var x := position.x + 9.0
	var z := position.z + 4.0
	g.position = Vector3(x, Terrain.height(x, z) + 0.5, z)
	get_parent().add_child(g)
	guardian = g


func _process(_delta: float) -> void:
	if _fire:
		var t := Time.get_ticks_msec() / 1000.0
		_fire.scale = Vector3(1.0 + sin(t * 9.0) * 0.08, 1.0 + sin(t * 13.0 + 1.0) * 0.15, 1.0 + cos(t * 11.0) * 0.08)
		_light.light_energy = 2.3 + sin(t * 17.0) * 0.4
