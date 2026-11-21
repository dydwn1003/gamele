extends Node3D
## 게임 진입점. 하늘·조명·지형·마을·거점·플레이어·카메라·봉화·적·UI 를 코드로 조립한다.
## 처음에는 타이틀 화면(게임 멈춤)을 보여주고, 이어하기/새 게임을 고르면 시작한다.

const Terrain = preload("res://scripts/world/terrain.gd")
const World = preload("res://scripts/world/world.gd")
const Player = preload("res://scripts/player/player.gd")
const CameraRig = preload("res://scripts/player/camera_rig.gd")
const Beacon = preload("res://scripts/world/beacon.gd")
const Village = preload("res://scripts/world/village.gd")
const Camp = preload("res://scripts/world/camp.gd")
const Interaction = preload("res://scripts/world/interaction.gd")
const EnemySpawner = preload("res://scripts/enemies/enemy_spawner.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const GameMenu = preload("res://scripts/ui/game_menu.gd")
const DialogUI = preload("res://scripts/ui/dialog_ui.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const Quests = preload("res://scripts/game/quests.gd")

const WORLD_SEED := 20261121
const DAY_LENGTH := 720.0  # 하루 12분
const VILLAGE_SPAWN := Vector3(0, 0, 4)

var world: World
var player: Player
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var beacons: Array = []
var camps: Array = []
var village: Node3D
var hud: Hud
var menu: GameMenu
var _save_timer := 0.0


func _ready() -> void:
	Terrain.init(WORLD_SEED)
	var show_title := not GameState.skip_title
	if show_title:
		if not GameState.load_game():
			GameState.reset()
	GameState.skip_title = false
	if GameState.quests.is_empty():
		GameState.accept_quest("main_1")
	_setup_environment()

	world = World.new()
	add_child(world)

	var spawn := _default_spawn()
	if GameState.has_last_position:
		spawn = GameState.last_position + Vector3(0, 1.0, 0)
	world.build_around(spawn, 2 if show_title else 1)

	player = Player.new()
	add_child(player)
	player.global_position = spawn
	player.died.connect(_on_player_died)

	rig = CameraRig.new()
	rig.target = player
	add_child(rig)
	player.camera_rig = rig
	rig.yaw = PI  # 마을 광장 쪽을 바라보며 시작

	village = Village.new()
	village.player = player
	add_child(village)

	var sites := Terrain.beacon_sites(GameState.BEACON_COUNT)
	for i in sites.size():
		var b := Beacon.new()
		b.setup(i, sites[i], player)
		add_child(b)
		beacons.append(b)

	for info in Camp.sites():
		var c := Camp.new()
		c.setup(info, player)
		add_child(c)
		camps.append(c)

	var spawner := EnemySpawner.new()
	spawner.player = player
	add_child(spawner)

	var interaction := Interaction.new()
	interaction.player = player
	add_child(interaction)

	menu = GameMenu.new()
	menu.main = self
	menu.player = player
	add_child(menu)

	var dialog := DialogUI.new()
	dialog.player = player
	add_child(dialog)

	hud = Hud.new()
	hud.player = player
	hud.camera_rig = rig
	hud.beacons = beacons
	hud.menu = menu
	hud.main = self
	add_child(hud)

	apply_settings()
	if show_title:
		var title := TitleScreen.new()
		title.main = self
		add_child(title)
		hud.visible = false
		get_tree().paused = true
	else:
		start_game()


## 타이틀에서 시작을 누르면 호출
func start_game() -> void:
	get_tree().paused = false
	hud.visible = true
	Sfx.play_music("field")
	rig.pitch = -0.3
	rig.spring.spring_length = rig.distance
	rig.spring.collision_mask = 1
	rig.spring.process_mode = Node.PROCESS_MODE_INHERIT
	if GameState.quest_state("main_1") == "active":
		hud.show_banner("에버린", "잊힌 봉화")
		hud.show_message("마을 우물가의 촌장 하든에게 말을 걸어보자 (머리 위 이름표)")


func _default_spawn() -> Vector3:
	return Vector3(VILLAGE_SPAWN.x, Terrain.height(VILLAGE_SPAWN.x, VILLAGE_SPAWN.z) + 1.0, VILLAGE_SPAWN.z)


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
	var ang := (GameState.time_of_day - 0.25) * TAU
	var elevation := sin(ang)
	sun.rotation = Vector3(-ang if elevation > 0.0 else -0.3, deg_to_rad(-35.0), 0)
	var day := clampf(elevation * 3.0 + 0.3, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elevation) * 4.0, 0.0, 1.0) * day
	sun.light_energy = lerpf(0.35, 1.15, day)  # 밤에도 달빛으로 길이 보이게
	sun.light_color = Color(1, 0.97, 0.9).lerp(Color(1, 0.6, 0.35), dusk).lerp(Color(0.6, 0.7, 1.0), 1.0 - day)
	var top_day := Color(0.3, 0.55, 0.9)
	var horizon_day := Color(0.72, 0.82, 0.92)
	var top_night := Color(0.06, 0.08, 0.18)
	var horizon_night := Color(0.18, 0.22, 0.36)
	sky_mat.sky_top_color = top_night.lerp(top_day, day)
	var horizon := horizon_night.lerp(horizon_day, day).lerp(Color(0.95, 0.6, 0.4), dusk * 0.7)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = top_night.lerp(Color(0.3, 0.35, 0.3), day)
	env.fog_light_color = horizon
	env.ambient_light_energy = lerpf(0.75, 1.0, day)


func _process(delta: float) -> void:
	world.update(player.global_position)
	GameState.time_of_day = fmod(GameState.time_of_day + delta / DAY_LENGTH, 1.0)
	_update_daylight()
	_save_timer += delta
	if _save_timer > 15.0 and not player.dead and player.is_on_floor():
		_save_timer = 0.0
		save_now()


func save_now() -> void:
	if player and not player.dead:
		GameState.last_position = player.global_position
		GameState.has_last_position = true
	GameState.save_game()


func apply_settings() -> void:
	var st: Dictionary = GameState.settings
	var radius := [3, 4, 5][clampi(int(st.get("view", 1)), 0, 2)] as int
	if world.view_radius != radius:
		world.view_radius = radius
		world.force_refresh()
	if rig.camera:
		rig.camera.far = 70.0 + radius * 48.0
	env.fog_depth_begin = radius * 48.0 * 0.55
	env.fog_depth_end = radius * 48.0 * 1.1
	sun.shadow_enabled = bool(st.get("shadows", true))
	rig.sensitivity = 0.006 * float(st.get("sensitivity", 1.0))
	Sfx.update_volume()


## 밝힌 봉화로 순간이동
func fast_travel(beacon) -> void:
	var pos: Vector3 = beacon.global_position + Vector3(0, 1.2, -4.5)
	world.build_around(pos, 1)
	player.respawn(pos)
	player.hp = minf(player.hp, GameState.max_hp())
	rig.global_position = pos + Vector3(0, 1.6, 0)
	Sfx.play("beacon")
	hud.show_banner("빠른 이동", "%s 봉화" % beacon.display_name())


## 추적 중인 퀘스트의 목표 위치 (레이더·지도의 ★ 표시). 없으면 null
func quest_target():
	var id := GameState.tracked_quest
	if id == "" or not GameState.quests.has(id):
		return null
	var q := Quests.get_quest(id)
	var st := GameState.quest_state(id)
	if st == "ready" or q["type"] == "talk":
		var npc: String = q["turn_in"] if st == "ready" else q["target"]
		var list: Array = get_tree().get_nodes_in_group("npcs")
		for n in list:
			if n.npc_id == npc:
				return n.global_position
		return null
	match q["type"]:
		"beacon":
			return _nearest(beacons.filter(func(b): return not b.lit))
		"kill":
			match q["target"]:
				"goblin_chief":
					return _nearest(camps.filter(func(c): return c.kind == "goblin" and c.has_chief and not c.cleared))
				"ogre":
					return _nearest(camps.filter(func(c): return c.kind == "ogre" and not c.cleared))
		"chest":
			return _nearest(camps.filter(func(c): return not GameState.opened_chests.has(c.camp_id)))
	return null


func _nearest(nodes: Array):
	var best = null
	var best_d := 1e12
	for n in nodes:
		var d: float = n.global_position.distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n.global_position
	return best


func _on_player_died() -> void:
	await get_tree().create_timer(3.0).timeout
	var pos := GameState.spawn_position if GameState.has_spawn else _default_spawn()
	world.build_around(pos, 1)
	# 부활 지점 주변 적 정리
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in list:
		if e.global_position.distance_to(pos) < 40.0 and not e.is_boss():
			e.queue_free()
	player.respawn(pos + Vector3(0, 0.5, 0))
	save_now()


func _notification(what: int) -> void:
	# 앱이 백그라운드로 가거나 종료될 때 저장 (모바일)
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player and hud and hud.visible:
			save_now()
