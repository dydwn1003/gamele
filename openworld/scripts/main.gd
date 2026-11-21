extends Node3D
## 게임 진입점. 하늘·조명·지형·플레이어·카메라·봉화·적·UI 를 코드로 조립한다.
## (외부 모델 파일 없이 전부 코드로 생성되므로 Godot 로 열면 바로 실행된다)

const Terrain = preload("res://scripts/world/terrain.gd")
const World = preload("res://scripts/world/world.gd")
const Player = preload("res://scripts/player/player.gd")
const CameraRig = preload("res://scripts/player/camera_rig.gd")
const Beacon = preload("res://scripts/world/beacon.gd")
const EnemySpawner = preload("res://scripts/enemies/enemy_spawner.gd")
const Hud = preload("res://scripts/ui/hud.gd")

const WORLD_SEED := 20261121
const DAY_LENGTH := 720.0  # 하루 12분

var world: World
var player: Player
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var beacons: Array = []
var _time_of_day := 0.3  # 0=자정, 0.25=해 뜰 무렵, 0.5=정오
var _save_timer := 0.0


func _ready() -> void:
	Terrain.init(WORLD_SEED)
	GameState.load_game()
	_setup_environment()

	world = World.new()
	add_child(world)

	var spawn := _default_spawn()
	if GameState.has_last_position:
		spawn = GameState.last_position + Vector3(0, 1.0, 0)
	world.build_around(spawn, 1)

	player = Player.new()
	add_child(player)
	player.global_position = spawn
	player.died.connect(_on_player_died)

	rig = CameraRig.new()
	rig.target = player
	add_child(rig)
	player.camera_rig = rig

	var sites := Terrain.beacon_sites(GameState.BEACON_COUNT)
	for i in sites.size():
		var b := Beacon.new()
		b.setup(i, sites[i], player)
		add_child(b)
		beacons.append(b)
	# 첫 화면에서 가장 가까운 봉화 쪽을 바라보게
	if not GameState.has_last_position:
		var first: Vector3 = sites[0]
		var d := first - spawn
		rig.yaw = atan2(-d.x, -d.z)

	var spawner := EnemySpawner.new()
	spawner.player = player
	add_child(spawner)

	var hud := Hud.new()
	hud.player = player
	hud.camera_rig = rig
	hud.beacons = beacons
	add_child(hud)

	if GameState.lit_beacons.is_empty():
		hud.show_message("일곱 봉화를 다시 밝혀라.  레이더의 노란 점을 따라가자")


func _default_spawn() -> Vector3:
	return Vector3(0, Terrain.height(0, 0) + 1.0, 0)


func _setup_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 110.0
	env.fog_depth_end = 220.0
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	_update_daylight()


func _update_daylight() -> void:
	# 태양이 동쪽에서 떠서 서쪽으로 진다
	var ang := (_time_of_day - 0.25) * TAU
	var elevation := sin(ang)
	sun.rotation = Vector3(-ang if elevation > 0.0 else -0.3, deg_to_rad(-35.0), 0)
	var day := clampf(elevation * 3.0 + 0.3, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elevation) * 4.0, 0.0, 1.0) * day
	sun.light_energy = lerpf(0.05, 1.15, day)
	sun.light_color = Color(1, 0.97, 0.9).lerp(Color(1, 0.6, 0.35), dusk)
	var top_day := Color(0.3, 0.55, 0.9)
	var horizon_day := Color(0.72, 0.82, 0.92)
	var top_night := Color(0.02, 0.03, 0.08)
	var horizon_night := Color(0.08, 0.1, 0.18)
	sky_mat.sky_top_color = top_night.lerp(top_day, day)
	var horizon := horizon_night.lerp(horizon_day, day).lerp(Color(0.95, 0.6, 0.4), dusk * 0.7)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = top_night.lerp(Color(0.3, 0.35, 0.3), day)
	env.fog_light_color = horizon
	env.ambient_light_energy = lerpf(0.35, 1.0, day)


func _process(delta: float) -> void:
	world.update(player.global_position)
	_time_of_day = fmod(_time_of_day + delta / DAY_LENGTH, 1.0)
	_update_daylight()
	_save_timer += delta
	if _save_timer > 15.0 and not player.dead and player.is_on_floor():
		_save_timer = 0.0
		GameState.last_position = player.global_position
		GameState.has_last_position = true
		GameState.save_game()


func _on_player_died() -> void:
	await get_tree().create_timer(3.0).timeout
	var pos := GameState.spawn_position if GameState.has_spawn else _default_spawn()
	world.build_around(pos, 1)
	# 부활 지점 주변 적 정리
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in list:
		if e.global_position.distance_to(pos) < 40.0 and e.kind != "golem":
			e.queue_free()
	player.respawn(pos + Vector3(0, 0.5, 0))
	GameState.last_position = pos
	GameState.has_last_position = true
	GameState.save_game()


func _notification(what: int) -> void:
	# 앱이 백그라운드로 가거나 종료될 때 저장 (모바일)
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player and not player.dead:
			GameState.last_position = player.global_position
			GameState.has_last_position = true
		GameState.save_game()
