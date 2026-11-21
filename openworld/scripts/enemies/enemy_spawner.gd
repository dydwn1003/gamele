extends Node3D
## 플레이어 주변(화면 밖)에 적을 생성하고, 멀어진 적은 정리한다.
## 숲에는 늑대, 평원에는 고블린 무리가 주로 나온다.

const Enemy = preload("res://scripts/enemies/enemy.gd")
const Terrain = preload("res://scripts/world/terrain.gd")

var player  # 플레이어 (player.gd)
var max_enemies := 12
var _timer := 3.0


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
		if e.dead:
			continue
		if e.global_position.distance_to(player.global_position) > 170.0:
			e.queue_free()
		else:
			count += 1
	if count < max_enemies and not player.dead:
		_try_spawn()


func _try_spawn() -> void:
	var a := randf() * TAU
	var r := randf_range(45.0, 85.0)
	var x := player.global_position.x + cos(a) * r
	var z := player.global_position.z + sin(a) * r
	var h := Terrain.height(x, z)
	if h < 1.5 or h > 65.0 or Terrain.slope(x, z) > 0.6:
		return
	# 시작 지점 근처는 안전 지대
	if Vector2(x, z).length() < 60.0:
		return
	var lvl := 1 + int(Vector2(x, z).length() / 260.0)
	var forest := Terrain.forest(x, z)
	var kind := "wolf" if randf() < forest * 0.8 else "goblin"
	var pack := randi_range(2, 3) if kind == "goblin" else randi_range(1, 3)
	for i in pack:
		var ox := x + randf_range(-4.0, 4.0)
		var oz := z + randf_range(-4.0, 4.0)
		var e := Enemy.new()
		e.setup(kind, lvl, player)
		e.position = Vector3(ox, Terrain.height(ox, oz) + 0.5, oz)
		add_child(e)
