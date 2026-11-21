extends Node3D
## 몬스터 거점: 고블린 야영지 / 망자의 폐허 / 오우거 동굴.
## 가까이 가면 적이 나타나고, 모두 처치하면 보물상자를 열 수 있다.

const LowPoly = preload("res://scripts/models/low_poly.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Chest = preload("res://scripts/world/chest.gd")

const KIND_NAMES := {"goblin": "고블린 야영지", "ruins": "망자의 폐허", "ogre": "오우거의 동굴"}

var camp_id := ""
var kind := "goblin"
var has_chief := false
var player
var enemies: Array = []
var cleared := false  # 이번 접속에서 소탕했는지

var _spawned := false

static var _sites_cache: Array = []


static func sites() -> Array:
	## 섬 곳곳에 거점 위치를 정한다 (같은 시드면 항상 같은 곳)
	if not _sites_cache.is_empty():
		return _sites_cache
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var out := []
	var kinds := ["goblin", "goblin", "goblin", "goblin", "goblin", "goblin", "goblin", "goblin",
		"ruins", "ruins", "ruins", "ogre", "ogre"]
	var beacons := Terrain.beacon_sites(GameState.BEACON_COUNT)
	var tries := 0
	var i := 0
	while i < kinds.size() and tries < 3000:
		tries += 1
		var k: String = kinds[i]
		var a := rng.randf() * TAU
		var r := rng.randf_range(200.0, 1250.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var h := Terrain.height(x, z)
		if h < 3.0 or Terrain.slope(x, z) > 0.3:
			continue
		if k == "ogre" and (h < 28.0 or h > 70.0):
			continue
		if k != "ogre" and h > 45.0:
			continue
		var ok := true
		for b in beacons:
			if Vector2(b.x, b.z).distance_to(Vector2(x, z)) < 90.0:
				ok = false
		for o in out:
			if Vector2(o["pos"].x, o["pos"].z).distance_to(Vector2(x, z)) < 160.0:
				ok = false
		if not ok:
			continue
		out.append({"id": "camp_%d" % i, "kind": k, "pos": Vector3(x, h, z), "chief": k == "goblin" and i % 2 == 0})
		i += 1
	_sites_cache = out
	return out


func setup(info: Dictionary, p_player) -> void:
	camp_id = info["id"]
	kind = info["kind"]
	has_chief = info["chief"]
	player = p_player
	position = info["pos"]


func display_name() -> String:
	return KIND_NAMES.get(kind, "야영지")


func alive_count() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n


func _level() -> int:
	return 1 + int(Vector2(position.x, position.z).length() / 260.0) + (2 if kind == "ogre" else 0)


func _ready() -> void:
	add_to_group("camps")
	match kind:
		"goblin":
			_build_goblin_camp()
		"ruins":
			_build_ruins()
		"ogre":
			_build_ogre_cave()
	var chest := Chest.new()
	chest.chest_id = camp_id
	chest.tier = {"goblin": 0, "ruins": 1, "ogre": 2}[kind]
	chest.camp = self
	chest.player = player
	var cx := position.x + 3.0
	var cz := position.z - 3.0
	chest.position = Vector3(3.0, Terrain.height(cx, cz) - position.y, -3.0)
	chest.rotation.y = 0.4
	add_child(chest)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var d: float = global_position.distance_to(player.global_position)
	if d < 60.0:
		GameState.discover(camp_id, display_name())
	if not _spawned and not cleared and d < 110.0:
		_spawn()
	elif _spawned and d > 230.0:
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		enemies.clear()
		_spawned = false
	if _spawned and not cleared and alive_count() == 0:
		cleared = true
		GameState.message.emit("%s 소탕 완료! 보물상자를 열어보자" % display_name())


func _spawn() -> void:
	_spawned = true
	enemies.clear()
	var lvl := _level()
	var list := []
	match kind:
		"goblin":
			list = ["goblin", "goblin", "goblin", "goblin"]
			if has_chief:
				list.append("goblin_chief")
		"ruins":
			list = ["skeleton", "skeleton", "skeleton", "skeleton", "skeleton"]
		"ogre":
			list = ["ogre", "goblin", "goblin"]
	for i in list.size():
		var a := TAU * i / list.size()
		var x := position.x + cos(a) * 6.0
		var z := position.z + sin(a) * 6.0
		var e := Enemy.new()
		e.setup(list[i], lvl, player, false)
		e.position = Vector3(x, Terrain.height(x, z) + 0.5, z)
		get_parent().add_child(e)
		enemies.append(e)


# ------------------------------------------------------------------ 겉모습

func _put(lp: LowPoly) -> void:
	var mi := lp.instance()
	mi.position.y = -0.2
	add_child(mi)


func _fire(at: Vector3, big := false) -> void:
	var lp := LowPoly.new()
	for i in 6:
		var a := TAU * i / 6.0
		lp.box(Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Vector3(0.3, 0.2, 0.3), Color(0.45, 0.43, 0.4))
	lp.box(Vector3(0, 0.15, 0), Vector3(0.9, 0.12, 0.12), Color(0.35, 0.22, 0.12), Transform3D(Basis(Vector3.UP, 0.7), Vector3.ZERO))
	lp.box(Vector3(0, 0.15, 0), Vector3(0.9, 0.12, 0.12), Color(0.35, 0.22, 0.12), Transform3D(Basis(Vector3.UP, -0.7), Vector3.ZERO))
	var mi := lp.instance()
	mi.position = at
	add_child(mi)
	var f := LowPoly.new()
	var s := 1.6 if big else 1.0
	f.cylinder(Vector3(0, 0.15, 0), 0.4 * s, 0.0, 1.0 * s, 5, Color(1.0, 0.5, 0.1))
	f.cylinder(Vector3(0, 0.2, 0), 0.22 * s, 0.0, 0.7 * s, 5, Color(1.0, 0.85, 0.3))
	var fm := f.instance(false)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.material_override = mat
	fm.position = at
	add_child(fm)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.omni_range = 10.0 * s
	l.light_energy = 1.5
	l.position = at + Vector3(0, 1.0, 0)
	add_child(l)


func _build_goblin_camp() -> void:
	var lp := LowPoly.new()
	var hide := Color(0.55, 0.45, 0.3)
	for i in 3:  # 천막
		var a := TAU * i / 3.0 + 0.5
		var p := Vector3(cos(a) * 7.0, 0, sin(a) * 7.0)
		p.y = Terrain.height(position.x + p.x, position.z + p.z) - position.y
		lp.cylinder(p, 1.8, 0.0, 2.6, 5, hide.darkened(i * 0.1))
		lp.box(p + Vector3(0, 2.6, 0), Vector3(0.1, 0.8, 0.1), Color(0.35, 0.22, 0.12))
	for i in 14:  # 뾰족 말뚝 울타리
		var a := TAU * i / 14.0
		var p := Vector3(cos(a) * 11.0, 0, sin(a) * 11.0)
		if i == 3 or i == 4:
			continue
		p.y = Terrain.height(position.x + p.x, position.z + p.z) - position.y
		lp.cylinder(p, 0.15, 0.0, 1.8, 4, Color(0.4, 0.27, 0.15))
	# 토템
	lp.box(Vector3(-3, 1.2, 3), Vector3(0.3, 2.4, 0.3), Color(0.4, 0.27, 0.15))
	lp.sphere(Vector3(-3, 2.6, 3), 0.3, Color(0.9, 0.88, 0.8), Vector3(1, 0.9, 1), 2, 5)
	_put(lp)
	_fire(Vector3(0, 0, 0))


func _build_ruins() -> void:
	var lp := LowPoly.new()
	var st := Color(0.58, 0.58, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(camp_id)
	for i in 8:  # 무너진 기둥
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		p.y = Terrain.height(position.x + p.x, position.z + p.z) - position.y
		var h := rng.randf_range(1.0, 5.0)
		lp.cylinder(p, 0.55, 0.5, h, 6, st)
		if h > 4.0:
			lp.box(p + Vector3(0, h + 0.2, 0), Vector3(1.4, 0.4, 1.4), st.darkened(0.1))
	for i in 10:  # 잔해
		var p := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		lp.box(p, Vector3(rng.randf_range(0.4, 1.2), 0.5, rng.randf_range(0.4, 1.2)), st.darkened(0.2), Transform3D(Basis(Vector3.UP, rng.randf() * 3.0), Vector3.ZERO))
	lp.box(Vector3(0, 0.2, 0), Vector3(5, 0.4, 5), st.darkened(0.15))  # 제단
	lp.box(Vector3(0, 0.9, 0), Vector3(1.6, 1.0, 0.8), st)
	_put(lp)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.8, 1.0)
	l.omni_range = 12.0
	l.light_energy = 1.2
	l.position = Vector3(0, 2.0, 0)
	add_child(l)


func _build_ogre_cave() -> void:
	var lp := LowPoly.new()
	var rock := Color(0.45, 0.42, 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(camp_id)
	for i in 9:  # 둘러싼 거대한 바위
		var a := TAU * i / 9.0
		var p := Vector3(cos(a) * 12.0, 0, sin(a) * 12.0)
		p.y = Terrain.height(position.x + p.x, position.z + p.z) - position.y
		if i == 2:
			continue
		lp.sphere(p + Vector3(0, 1.5, 0), 3.0, rock, Vector3(1, 1.2, 1), 3, 6, Transform3D.IDENTITY, 0.25, rng)
	for i in 8:  # 뼈 무더기
		var p := Vector3(rng.randf_range(-6, 6), 0.1, rng.randf_range(-6, 6))
		lp.box(p, Vector3(0.12, 0.12, 0.8), Color(0.9, 0.88, 0.8), Transform3D(Basis(Vector3.UP, rng.randf() * 3.0), Vector3.ZERO))
	_put(lp)
	_fire(Vector3(-2, 0, 2), true)
