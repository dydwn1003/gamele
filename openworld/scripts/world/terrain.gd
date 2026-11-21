extends RefCounted
## 섬 대륙 "에버린"의 지형 공식.
## 같은 시드면 항상 같은 지형이 나오므로 맵 데이터를 저장할 필요가 없다.
## 지름 약 3.2km 의 섬: 중앙 평원(시작 지점) → 숲과 언덕 → 북쪽·동쪽 산맥 → 해안.

const WATER_LEVEL := 0.0
const WORLD_RADIUS := 1600.0
const SPAWN := Vector2(0, 0)

static var _continent: FastNoiseLite
static var _mountain: FastNoiseLite
static var _detail: FastNoiseLite
static var _forest: FastNoiseLite
static var _beacon_cache: Array[Vector3] = []


static func init(seed_value: int) -> void:
	_continent = FastNoiseLite.new()
	_continent.seed = seed_value
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent.frequency = 0.0011
	_continent.fractal_octaves = 3

	_mountain = FastNoiseLite.new()
	_mountain.seed = seed_value + 1
	_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain.frequency = 0.0035
	_mountain.fractal_octaves = 4

	_detail = FastNoiseLite.new()
	_detail.seed = seed_value + 2
	_detail.frequency = 0.03
	_detail.fractal_octaves = 2

	_forest = FastNoiseLite.new()
	_forest.seed = seed_value + 3
	_forest.frequency = 0.006
	_forest.fractal_octaves = 2


static func height(x: float, z: float) -> float:
	var c := _continent.get_noise_2d(x, z)
	var h := 7.0 + c * 26.0
	# 대륙값이 높은 곳에만 날카로운 능선형 산맥을 올린다
	var ridge := 1.0 - absf(_mountain.get_noise_2d(x, z))
	ridge = ridge * ridge * ridge
	var mountain_mask := smoothstep(-0.05, 0.45, c)
	h += ridge * 85.0 * mountain_mask
	h += _detail.get_noise_2d(x, z) * 2.2
	# 섬 가장자리는 바다로
	var dist := Vector2(x, z).length()
	var edge := smoothstep(WORLD_RADIUS * 0.68, WORLD_RADIUS, dist)
	h = lerpf(h, -28.0, edge)
	# 시작 지점은 완만한 언덕
	var sp := 1.0 - smoothstep(30.0, 110.0, Vector2(x, z).distance_to(SPAWN))
	h = lerpf(h, 9.0 + _detail.get_noise_2d(x, z) * 1.5, sp)
	return h


## 0..1, 숲이 얼마나 빽빽한지
static func forest(x: float, z: float) -> float:
	return clampf(_forest.get_noise_2d(x, z) * 1.4 + 0.35, 0.0, 1.0)


static func slope(x: float, z: float) -> float:
	var e := 1.5
	var dx := height(x + e, z) - height(x - e, z)
	var dz := height(x, z + e) - height(x, z - e)
	return Vector2(dx, dz).length() / (2.0 * e)


## 삼각형 하나의 색 (높이·경사·숲 밀도로 결정)
static func color_at(h: float, steep: float, x: float, z: float, jitter: float) -> Color:
	var col: Color
	if h < -2.0:
		col = Color(0.62, 0.58, 0.42)
	elif h < 1.6:
		col = Color(0.88, 0.8, 0.56)  # 모래사장
	elif h > 78.0 and steep < 0.9:
		col = Color(0.95, 0.96, 0.98)  # 만년설
	elif steep > 0.75 or h > 60.0:
		col = Color(0.52, 0.5, 0.48)  # 바위
	else:
		var f := forest(x, z)
		col = Color(0.5, 0.7, 0.3).lerp(Color(0.28, 0.48, 0.22), f)
		if h > 35.0:
			col = col.lerp(Color(0.55, 0.55, 0.4), smoothstep(35.0, 58.0, h))
		if steep > 0.5:
			col = col.lerp(Color(0.5, 0.46, 0.4), smoothstep(0.5, 0.75, steep))
	return col * (1.0 + jitter)


## 봉화 7개의 위치: 섬을 고르게 둘러싸도록 각도별로 탐색한다
static func beacon_sites(count: int) -> Array[Vector3]:
	if _beacon_cache.size() == count:
		return _beacon_cache
	var sites: Array[Vector3] = []
	for i in count:
		var ang := TAU * float(i) / count + 0.35
		var chosen := Vector3.ZERO
		var found := false
		var r := 1000.0 - float(i % 3) * 120.0
		while r > 220.0 and not found:
			for da in [0.0, 0.08, -0.08, 0.16, -0.16]:
				var a: float = ang + da
				var x := cos(a) * r
				var z := sin(a) * r
				var h := height(x, z)
				if h > 6.0 and h < 70.0 and slope(x, z) < 0.35:
					chosen = Vector3(x, h, z)
					found = true
					break
			r -= 40.0
		if not found:
			var x := cos(ang) * 200.0
			var z := sin(ang) * 200.0
			chosen = Vector3(x, height(x, z), z)
		sites.append(chosen)
	_beacon_cache = sites
	return sites
