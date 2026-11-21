extends Node3D
## 시작 마을 "새벽 마을": 집, 우물, 시장 좌판, 대장간, 경비 초소, 울타리, 등불과 NPC 4명.

const LowPoly = preload("res://scripts/models/low_poly.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Npc = preload("res://scripts/world/npc.gd")

const CENTER := Vector2(0, 0)

var player
var _lights: Array[OmniLight3D] = []
var _body: StaticBody3D

const WALL := Color(0.9, 0.85, 0.72)
const WOOD := Color(0.45, 0.3, 0.18)
const WOOD_D := Color(0.32, 0.21, 0.13)
const STONE := Color(0.6, 0.58, 0.55)


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	add_child(_body)
	# 집들 (위치 x, z, 방향, 지붕색)
	var houses := [
		[-16.0, -12.0, 0.3, Color(0.7, 0.25, 0.2)], [16.0, -14.0, -0.4, Color(0.3, 0.4, 0.6)],
		[-22.0, 8.0, 1.4, Color(0.55, 0.35, 0.2)], [22.0, 10.0, -1.3, Color(0.7, 0.25, 0.2)],
		[-6.0, 24.0, 3.0, Color(0.35, 0.5, 0.3)], [9.0, 25.0, 2.9, Color(0.55, 0.35, 0.2)],
	]
	for h in houses:
		_house(h[0], h[1], h[2], h[3])
	_well(0.0, -5.0)
	_stall(-11.0, 4.0)
	_forge(12.0, 3.0)
	_guard_post(0.0, -30.0)
	_fence_ring()
	for p in [Vector2(-5, 3), Vector2(5, 3), Vector2(0, -16), Vector2(-10, 15), Vector2(10, 15)]:
		_lantern(p.x, p.y)
	_board(4.0, -9.0)

	_npc("elder", Vector3(2.5, 0, -7.0), PI * 0.8)
	_npc("merchant", Vector3(-11.0, 0, 6.2), PI)
	_npc("smith", Vector3(12.0, 0, 6.0), PI)
	_npc("guard", Vector3(2.5, 0, -28.0), PI)


func _ground(x: float, z: float) -> float:
	return Terrain.height(x, z)


func _place(lp: LowPoly, x: float, z: float, yaw: float, sink := 0.3) -> void:
	var mi := lp.instance()
	mi.position = Vector3(x, _ground(x, z) - sink, z)
	mi.rotation.y = yaw
	add_child(mi)


func _collider(size: Vector3, x: float, z: float, yaw: float, y_off: float) -> void:
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	cs.position = Vector3(x, _ground(x, z) + y_off, z)
	cs.rotation.y = yaw
	_body.add_child(cs)


func _house(x: float, z: float, yaw: float, roof: Color) -> void:
	var lp := LowPoly.new()
	var w := 6.0
	var d := 5.0
	var h := 3.4
	lp.box(Vector3(0, 0.2, 0), Vector3(w + 0.4, 0.6, d + 0.4), STONE)  # 기초
	lp.box(Vector3(0, h * 0.5 + 0.3, 0), Vector3(w, h, d), WALL)
	for sx in [-1.0, 1.0]:  # 기둥
		for sz in [-1.0, 1.0]:
			lp.box(Vector3(sx * w * 0.5, h * 0.5 + 0.3, sz * d * 0.5), Vector3(0.25, h, 0.25), WOOD_D)
	lp.box(Vector3(0, h + 0.3, 0), Vector3(w + 0.1, 0.2, d + 0.1), WOOD_D)
	# 지붕 (삼각기둥)
	var top := h + 0.3
	var ridge := top + 2.2
	var ov := 0.5
	var a := Vector3(-w * 0.5 - ov, top - 0.2, -d * 0.5 - ov)
	var b := Vector3(w * 0.5 + ov, top - 0.2, -d * 0.5 - ov)
	var c := Vector3(w * 0.5 + ov, top - 0.2, d * 0.5 + ov)
	var e := Vector3(-w * 0.5 - ov, top - 0.2, d * 0.5 + ov)
	var r1 := Vector3(-w * 0.5 - ov, ridge, 0)
	var r2 := Vector3(w * 0.5 + ov, ridge, 0)
	var inside := Vector3(0, top + 0.6, 0)
	lp.quad(a, b, r2, r1, roof, inside)
	lp.quad(e, c, r2, r1, roof.darkened(0.15), inside)
	lp.tri(a, e, r1, WALL.darkened(0.1), inside)
	lp.tri(b, c, r2, WALL.darkened(0.1), inside)
	# 문·창문·굴뚝
	lp.box(Vector3(0, 1.3, -d * 0.5 - 0.03), Vector3(1.1, 2.0, 0.1), WOOD)
	lp.box(Vector3(-1.9, 2.2, -d * 0.5 - 0.03), Vector3(0.9, 0.8, 0.08), Color(0.3, 0.45, 0.6))
	lp.box(Vector3(1.9, 2.2, -d * 0.5 - 0.03), Vector3(0.9, 0.8, 0.08), Color(0.3, 0.45, 0.6))
	lp.box(Vector3(1.8, ridge - 0.3, 1.0), Vector3(0.6, 1.6, 0.6), STONE)
	_place(lp, x, z, yaw)
	_collider(Vector3(w, h + 1.5, d), x, z, yaw, h * 0.5)


func _well(x: float, z: float) -> void:
	var lp := LowPoly.new()
	lp.cylinder(Vector3(0, 0, 0), 1.3, 1.3, 1.0, 8, STONE)
	lp.cylinder(Vector3(0, 0.95, 0), 1.0, 1.0, 0.1, 8, Color(0.2, 0.35, 0.5))
	for sx in [-1.0, 1.0]:
		lp.box(Vector3(sx * 1.1, 1.8, 0), Vector3(0.18, 1.8, 0.18), WOOD)
	lp.box(Vector3(0, 2.6, 0), Vector3(2.4, 0.15, 0.15), WOOD_D)
	lp.cylinder(Vector3(0, 2.7, 0), 1.7, 0.0, 0.9, 4, Color(0.55, 0.3, 0.2), Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO))
	lp.box(Vector3(0, 1.9, 0), Vector3(0.3, 0.35, 0.3), WOOD)  # 두레박
	_place(lp, x, z, 0.0, 0.1)
	_collider(Vector3(2.6, 2.0, 2.6), x, z, 0.0, 1.0)


func _stall(x: float, z: float) -> void:
	var lp := LowPoly.new()
	lp.box(Vector3(0, 0.9, 0), Vector3(3.4, 0.15, 1.3), WOOD)
	lp.box(Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 1.1), WOOD_D)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			lp.box(Vector3(sx * 1.6, 1.4, sz * 0.6), Vector3(0.1, 2.8, 0.1), WOOD_D)
	for i in 6:  # 줄무늬 차양
		var col := Color(0.85, 0.3, 0.25) if i % 2 == 0 else Color(0.95, 0.9, 0.8)
		lp.box(Vector3(-1.45 + i * 0.58, 2.85, 0), Vector3(0.58, 0.08, 1.6), col)
	var goods := [Color(0.9, 0.2, 0.25), Color(0.95, 0.8, 0.2), Color(0.35, 0.75, 0.3), Color(0.6, 0.4, 1.0)]
	for i in 4:
		lp.box(Vector3(-1.2 + i * 0.8, 1.1, 0), Vector3(0.22, 0.3, 0.22), goods[i])
	_place(lp, x, z, 0.0, 0.1)
	_collider(Vector3(3.4, 1.2, 1.3), x, z, 0.0, 0.6)


func _forge(x: float, z: float) -> void:
	var lp := LowPoly.new()
	lp.box(Vector3(0, 0.9, 1.5), Vector3(2.4, 1.8, 1.8), STONE)  # 화덕
	lp.box(Vector3(0, 0.8, 0.58), Vector3(1.0, 0.6, 0.1), Color(1.0, 0.45, 0.1))  # 불구멍
	lp.box(Vector3(0, 2.6, 1.6), Vector3(0.7, 1.8, 0.7), STONE)  # 굴뚝
	lp.box(Vector3(-1.6, 0.4, -0.4), Vector3(0.5, 0.8, 0.4), WOOD_D)  # 모루 받침
	lp.box(Vector3(-1.6, 0.9, -0.4), Vector3(0.9, 0.25, 0.4), Color(0.3, 0.3, 0.33))  # 모루
	lp.cylinder(Vector3(1.7, 0, -0.5), 0.4, 0.45, 0.7, 7, WOOD)  # 물통
	lp.cylinder(Vector3(1.7, 0.65, -0.5), 0.36, 0.36, 0.06, 7, Color(0.2, 0.35, 0.5))
	for sx in [-1.0, 1.0]:  # 지붕 기둥과 지붕
		lp.box(Vector3(sx * 2.2, 1.5, -1.0), Vector3(0.15, 3.0, 0.15), WOOD_D)
	lp.box(Vector3(0, 3.0, 0.3), Vector3(5.0, 0.15, 3.4), WOOD)
	_place(lp, x, z, PI, 0.1)
	_collider(Vector3(2.4, 2.0, 1.8), x, z - 1.5, 0.0, 1.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.omni_range = 7.0
	glow.light_energy = 1.4
	glow.position = Vector3(x, _ground(x, z) + 1.0, z - 0.8)
	add_child(glow)


func _guard_post(x: float, z: float) -> void:
	var lp := LowPoly.new()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			lp.box(Vector3(sx * 1.3, 2.5, sz * 1.3), Vector3(0.3, 5.0, 0.3), WOOD_D)
	lp.box(Vector3(0, 4.0, 0), Vector3(3.2, 0.2, 3.2), WOOD)
	lp.box(Vector3(0, 4.5, -1.55), Vector3(3.2, 0.9, 0.12), WOOD)
	lp.cylinder(Vector3(0, 5.0, 0), 2.4, 0.0, 1.5, 4, Color(0.55, 0.3, 0.2), Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO))
	lp.box(Vector3(1.6, 3.0, -1.6), Vector3(0.05, 1.6, 0.9), Color(0.75, 0.2, 0.15))  # 깃발
	_place(lp, x + 6.0, z, 0.0, 0.1)
	_collider(Vector3(3.0, 5.0, 3.0), x + 6.0, z, 0.0, 2.5)


func _fence_ring() -> void:
	# 마을 둘레 울타리 (북쪽 입구와 남쪽 입구는 비워둔다)
	var lp := LowPoly.new()
	var r := 34.0
	var n := 44
	var c := Vector3(0, 0, 0)
	for i in n:
		var a := TAU * i / n
		var deg := rad_to_deg(a)
		if absf(deg - 270.0) < 14.0 or absf(deg - 90.0) < 14.0:
			continue
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var gy := _ground(p.x, p.z)
		lp.box(c + Vector3(p.x, gy + 0.6, p.z), Vector3(0.18, 1.3, 0.18), WOOD_D)
		var a2 := TAU * (i + 1) / n
		var p2 := Vector3(cos(a2) * r, 0, sin(a2) * r)
		var deg2 := rad_to_deg(a2)
		if absf(deg2 - 270.0) < 14.0 or absf(deg2 - 90.0) < 14.0:
			continue
		var mid := (p + p2) * 0.5
		var seg_len := p.distance_to(p2)
		var yaw := atan2(p2.x - p.x, p2.z - p.z)
		var gm := (gy + _ground(p2.x, p2.z)) * 0.5
		lp.box(Vector3.ZERO, Vector3(0.08, 0.12, seg_len), WOOD, Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, gm + 0.9, mid.z)))
		lp.box(Vector3.ZERO, Vector3(0.08, 0.12, seg_len), WOOD, Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, gm + 0.45, mid.z)))
	add_child(lp.instance())


func _lantern(x: float, z: float) -> void:
	var lp := LowPoly.new()
	lp.box(Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), WOOD_D)
	lp.box(Vector3(0, 2.9, 0), Vector3(0.35, 0.4, 0.35), Color(1.0, 0.8, 0.4))
	lp.cylinder(Vector3(0, 3.1, 0), 0.3, 0.0, 0.25, 4, WOOD_D)
	_place(lp, x, z, 0.0, 0.05)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.omni_range = 9.0
	l.light_energy = 0.0
	l.position = Vector3(x, _ground(x, z) + 2.8, z)
	add_child(l)
	_lights.append(l)


func _board(x: float, z: float) -> void:
	var lp := LowPoly.new()
	for sx in [-1.0, 1.0]:
		lp.box(Vector3(sx * 0.8, 0.9, 0), Vector3(0.12, 1.8, 0.12), WOOD_D)
	lp.box(Vector3(0, 1.4, 0), Vector3(1.8, 1.0, 0.08), WOOD)
	for i in 3:
		lp.box(Vector3(-0.5 + i * 0.5, 1.4 + (i % 2) * 0.1, -0.05), Vector3(0.35, 0.45, 0.02), Color(0.95, 0.92, 0.8))
	_place(lp, x, z, PI * 0.8, 0.05)


func _npc(id: String, local: Vector3, yaw: float) -> void:
	var n := Npc.new()
	n.setup(id, player, yaw)
	n.position = Vector3(local.x, _ground(local.x, local.z), local.z)
	add_child(n)


func _process(_delta: float) -> void:
	# 밤에는 등불을 켠다
	var t := GameState.time_of_day
	var on := 1.6 if (t < 0.24 or t > 0.74) else 0.0
	for l in _lights:
		l.light_energy = lerpf(l.light_energy, on, 0.05)
