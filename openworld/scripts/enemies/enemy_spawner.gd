extends Node3D
## 플레이어 주변(화면 밖)에 적을 생성하고, 멀어진 적은 정리한다.
## 숲: 늑대 / 평원: 고블린 무리·멧돼지 / 밤: 해골 전사. 6% 확률로 [정예].

const Enemy = preload("res://scripts/enemies/enemy.gd")
const Terrain = preload("res://scripts/world/terrain.gd")

var player  # 플레이어 (player.gd)
var max_enemies := 12
var _timer := 3.0


static func is_night() -> bool:
	return GameState.time_of_day < 0.22 or GameState.time_of_day > 0.78


func _process(delta: float) -> void:
	if player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 2.0
	var count := 0
	var list: Array = get_children()
	for e in list:
		# 이 노드 밑에는 적 말고도 전리품·데미지 숫자가 붙는다
		if not e.has_method("is_boss") or e.dead:
			continue
		var far: bool = e.global_position.distance_to(player.global_position) > 170.0
		# 해가 뜨면 해골은 흙으로 돌아간다
		var dawn: bool = e.kind == "skeleton" and not is_night() and e.global_position.distance_to(player.global_position) > 30.0
		if far or dawn:
			e.queue_free()
		else:
			count += 1
	if count < max_enemies and not player.dead:
		_try_spawn()


func _try_spawn() -> void:
	var a := randf() * TAU
	var r := randf_range(45.0, 85.0)
	var x: float = player.global_position.x + cos(a) * r
	var z: float = player.global_position.z + sin(a) * r
	var h := Terrain.height(x, z)
	if h < 1.5 or h > 65.0 or Terrain.slope(x, z) > 0.6:
		return
	# 마을 근처는 안전 지대
	if Vector2(x, z).length() < 90.0:
		return
	var lvl := 1 + int(Vector2(x, z).length() / 260.0)
	var forest := Terrain.forest(x, z)
	var kind := "goblin"
	var roll := randf()
	if is_night() and roll < 0.55:
		kind = "skeleton"
	elif roll < forest * 0.8:
		kind = "wolf"
	elif roll < forest * 0.8 + 0.25 and h < 35.0:
		kind = "boar"
	var pack := 1
	match kind:
		"goblin":
			pack = randi_range(2, 3)
		"wolf":
			pack = randi_range(1, 3)
		"skeleton":
			pack = randi_range(1, 2)
	for i in pack:
		var ox: float = x + randf_range(-4.0, 4.0)
		var oz: float = z + randf_range(-4.0, 4.0)
		var e := Enemy.new()
		e.setup(kind, lvl, player, randf() < 0.06)
		e.position = Vector3(ox, Terrain.height(ox, oz) + 0.5, oz)
		add_child(e)
