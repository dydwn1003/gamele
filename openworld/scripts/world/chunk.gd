extends StaticBody3D
## 지형 한 조각 (48m x 48m). 높이 공식으로 메시·충돌·소품을 만든다.

const LowPoly = preload("res://scripts/models/low_poly.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Props = preload("res://scripts/world/props.gd")
const ResourceNode = preload("res://scripts/world/resource_node.gd")
const Camp = preload("res://scripts/world/camp.gd")

const SIZE := 48.0
const RES := 16  # 한 변 격자 수 → 3m 짜리 큰 삼각형으로 로우폴리 느낌

var coord := Vector2i.ZERO


func build(c: Vector2i) -> void:
	coord = c
	position = Vector3(c.x * SIZE, 0, c.y * SIZE)
	collision_layer = 1
	collision_mask = 0
	var step := SIZE / RES
	var n := RES + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = Terrain.height(position.x + i * step, position.z + j * step)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var lp := LowPoly.new()
	for j in RES:
		for i in RES:
			var p00 := Vector3(i * step, hs[j * n + i], j * step)
			var p10 := Vector3((i + 1) * step, hs[j * n + i + 1], j * step)
			var p01 := Vector3(i * step, hs[(j + 1) * n + i], (j + 1) * step)
			var p11 := Vector3((i + 1) * step, hs[(j + 1) * n + i + 1], (j + 1) * step)
			# 대각선 방향을 번갈아 써서 격자 무늬가 덜 보이게
			if (i + j) % 2 == 0:
				_terrain_tri(lp, p00, p10, p11, rng)
				_terrain_tri(lp, p00, p11, p01, rng)
			else:
				_terrain_tri(lp, p00, p10, p01, rng)
				_terrain_tri(lp, p10, p11, p01, rng)

	var mi := MeshInstance3D.new()
	mi.mesh = lp.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = mi.mesh.create_trimesh_shape()
	add_child(col)
	_scatter(rng)
	_resources()


func _terrain_tri(lp: LowPoly, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> void:
	var nrm := (c - a).cross(b - a).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	var steep := sqrt(maxf(0.0, 1.0 - nrm.y * nrm.y)) / maxf(nrm.y, 0.05)
	var center := (a + b + c) / 3.0
	var col := Terrain.color_at(center.y, steep, position.x + center.x, position.z + center.z, rng.randf_range(-0.04, 0.04))
	lp.tri(a, b, c, col, center - Vector3.UP)


## 거점·봉화 근처처럼 비워둬야 하는 원 (x, z, 반지름)
func _clear_zones() -> Array:
	var zones := []
	var center := Vector2(position.x + SIZE * 0.5, position.z + SIZE * 0.5)
	for s in Camp.sites():
		var p := Vector2(s["pos"].x, s["pos"].z)
		if p.distance_to(center) < SIZE + 20.0:
			zones.append([p, 15.0])
	for b in Terrain.beacon_sites(GameState.BEACON_COUNT):
		var p := Vector2(b.x, b.z)
		if p.distance_to(center) < SIZE + 20.0:
			zones.append([p, 11.0])
	return zones


func _in_zone(zones: Array, x: float, z: float) -> bool:
	for zn in zones:
		if Vector2(x, z).distance_to(zn[0]) < float(zn[1]):
			return true
	return false


func _scatter(rng: RandomNumberGenerator) -> void:
	var groups := {}
	var zones := _clear_zones()
	for attempt in 70:
		var lx := rng.randf() * SIZE
		var lz := rng.randf() * SIZE
		var wx := position.x + lx
		var wz := position.z + lz
		var h := Terrain.height(wx, wz)
		if h < 2.0 or h > 62.0:
			continue
		if Terrain.slope(wx, wz) > 0.55:
			continue
		# 시작 지점 바로 주변은 비워둔다
		if Vector2(wx, wz).length() < 42.0 or _in_zone(zones, wx, wz):
			continue
		var f := Terrain.forest(wx, wz)
		var r := rng.randf()
		var kind := ""
		if r < f * 0.55:
			if h > 28.0:
				kind = "pine"
			else:
				var t := rng.randf()
				kind = "oak" if t < 0.55 else ("pine" if t < 0.8 else "birch")
		elif r < f * 0.55 + 0.06:
			kind = "rock"
		elif r < f * 0.55 + 0.14:
			kind = "bush"
		elif r < f * 0.55 + 0.24 and h < 30.0:
			kind = "flowers"
		if kind == "":
			continue
		var s := rng.randf_range(0.8, 1.35)
		if kind == "rock":
			s = rng.randf_range(0.6, 2.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(lx, h - position.y - 0.1, lz))
		if not groups.has(kind):
			groups[kind] = []
		groups[kind].append(xf)
		var tr := Props.trunk_radius(kind)
		if tr > 0.0:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = tr * s
			cyl.height = 3.0 * s
			cs.shape = cyl
			cs.position = xf.origin + Vector3(0, 1.5 * s, 0)
			add_child(cs)

	for kind in groups:
		var list: Array = groups[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Props.mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 70.0 if kind == "flowers" else 170.0
		if kind == "flowers" or kind == "bush":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## 약초·광맥 채집 지점
func _resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord) + 99
	for i in 3:
		var lx := rng.randf_range(4.0, SIZE - 4.0)
		var lz := rng.randf_range(4.0, SIZE - 4.0)
		var wx := position.x + lx
		var wz := position.z + lz
		var h := Terrain.height(wx, wz)
		var roll := rng.randf()
		if Vector2(wx, wz).length() < 45.0 or Terrain.slope(wx, wz) > 0.6:
			continue
		var kind := ""
		if h > 20.0 and h < 65.0 and roll < 0.3:
			kind = "ore"
		elif h > 2.0 and h < 30.0 and roll < 0.3:
			kind = "herb"
		if kind == "":
			continue
		var n := ResourceNode.new()
		n.node_id = "%d_%d_%d" % [coord.x, coord.y, i]
		n.kind = kind
		n.position = Vector3(lx, h - position.y, lz)
		add_child(n)
