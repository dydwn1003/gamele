extends RefCounted
## 지형에 흩뿌리는 소품(나무·바위·덤불) 메시. 한 번 만들고 MultiMesh 로 재사용한다.

const LowPoly = preload("res://scripts/models/low_poly.gd")

static var _cache := {}


static func mesh(kind: String) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var lp := LowPoly.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"pine":
			lp.cylinder(Vector3.ZERO, 0.28, 0.18, 1.6, 5, Color(0.42, 0.28, 0.17))
			lp.cylinder(Vector3(0, 1.1, 0), 1.7, 0.0, 2.3, 6, Color(0.17, 0.38, 0.22))
			lp.cylinder(Vector3(0, 2.3, 0), 1.3, 0.0, 2.0, 6, Color(0.2, 0.43, 0.25))
			lp.cylinder(Vector3(0, 3.4, 0), 0.9, 0.0, 1.7, 6, Color(0.23, 0.48, 0.27))
		"oak":
			lp.cylinder(Vector3.ZERO, 0.32, 0.22, 2.4, 5, Color(0.45, 0.3, 0.18))
			lp.sphere(Vector3(0, 3.1, 0), 1.6, Color(0.36, 0.58, 0.24), Vector3(1, 0.8, 1), 3, 6, Transform3D.IDENTITY, 0.15, rng)
			lp.sphere(Vector3(0.9, 2.6, 0.3), 1.0, Color(0.32, 0.54, 0.22), Vector3.ONE, 3, 5, Transform3D.IDENTITY, 0.15, rng)
			lp.sphere(Vector3(-0.7, 2.7, -0.5), 1.1, Color(0.4, 0.62, 0.26), Vector3.ONE, 3, 5, Transform3D.IDENTITY, 0.15, rng)
		"birch":
			lp.cylinder(Vector3.ZERO, 0.18, 0.12, 3.0, 5, Color(0.9, 0.88, 0.82))
			lp.sphere(Vector3(0, 3.4, 0), 1.1, Color(0.75, 0.72, 0.3), Vector3(1, 1.4, 1), 3, 6, Transform3D.IDENTITY, 0.15, rng)
		"rock":
			lp.sphere(Vector3(0, 0.3, 0), 1.0, Color(0.55, 0.54, 0.52), Vector3(1.2, 0.75, 1.0), 3, 6, Transform3D.IDENTITY, 0.25, rng)
		"bush":
			lp.sphere(Vector3(0, 0.35, 0), 0.6, Color(0.3, 0.52, 0.22), Vector3(1, 0.7, 1), 2, 6, Transform3D.IDENTITY, 0.2, rng)
			lp.sphere(Vector3(0.35, 0.3, 0.2), 0.4, Color(0.34, 0.56, 0.24), Vector3(1, 0.8, 1), 2, 5)
			lp.box(Vector3(0.1, 0.62, -0.3), Vector3(0.12, 0.12, 0.12), Color(0.85, 0.2, 0.25))  # 산딸기
		"flowers":
			for i in 5:
				var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
				lp.cylinder(p, 0.02, 0.02, 0.3, 3, Color(0.3, 0.55, 0.2))
				var cols := [Color(0.95, 0.85, 0.3), Color(0.9, 0.4, 0.5), Color(0.6, 0.5, 0.95), Color(1, 1, 1)]
				lp.box(p + Vector3(0, 0.32, 0), Vector3(0.1, 0.06, 0.1), cols[i % cols.size()])
	var m := lp.commit()
	_cache[kind] = m
	return m


## 충돌용 줄기 반지름 (0 이면 충돌 없음)
static func trunk_radius(kind: String) -> float:
	match kind:
		"pine":
			return 0.35
		"oak":
			return 0.4
		"birch":
			return 0.25
		"rock":
			return 0.9
	return 0.0
