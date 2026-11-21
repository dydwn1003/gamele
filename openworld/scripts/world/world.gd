extends Node3D
## 플레이어 주변 청크만 불러오고 멀어진 청크는 지우는 스트리밍 관리자.
## 큰 맵을 휴대폰 메모리에 다 올리지 않기 위한 핵심 장치.

const Chunk = preload("res://scripts/world/chunk.gd")
const Terrain = preload("res://scripts/world/terrain.gd")

@export var view_radius := 4
@export var builds_per_frame := 2

var chunks := {}
var _queue: Array[Vector2i] = []
var _center := Vector2i(999999, 999999)
var water: MeshInstance3D


func _ready() -> void:
	water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Chunk.SIZE * (view_radius * 2 + 3), Chunk.SIZE * (view_radius * 2 + 3))
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.5, 0.7, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.1
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = Terrain.WATER_LEVEL
	add_child(water)


static func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / Chunk.SIZE), floori(pos.z / Chunk.SIZE))


## 시작할 때 주변 청크를 즉시 만든다 (플레이어가 떨어지지 않도록)
func build_around(pos: Vector3, radius: int) -> void:
	var c := chunk_of(pos)
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			_build(c + Vector2i(dx, dz))


func update(pos: Vector3) -> void:
	var c := chunk_of(pos)
	water.position.x = c.x * Chunk.SIZE
	water.position.z = c.y * Chunk.SIZE
	if not chunks.has(c):
		_build(c)
	if c != _center:
		_center = c
		_refresh_queue()
	var n := 0
	while n < builds_per_frame and not _queue.is_empty():
		var next: Vector2i = _queue.pop_front()
		if not chunks.has(next) and _in_range(next):
			_build(next)
			n += 1


## 시야 거리 설정이 바뀌었을 때 청크 목록을 다시 계산
func force_refresh() -> void:
	_center = Vector2i(999999, 999999)


func _in_range(c: Vector2i) -> bool:
	var d := c - _center
	return d.x * d.x + d.y * d.y <= view_radius * view_radius + 1


func _refresh_queue() -> void:
	_queue.clear()
	for dz in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			var c := _center + Vector2i(dx, dz)
			if _in_range(c) and not chunks.has(c):
				_queue.append(c)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _center).length_squared() < (b - _center).length_squared())
	# 멀어진 청크 정리 (경계에서 왔다갔다 할 때 깜빡이지 않도록 1칸 여유)
	var limit := (view_radius + 1) * (view_radius + 1) + 1
	for key in chunks.keys():
		var d: Vector2i = key - _center
		if d.x * d.x + d.y * d.y > limit:
			chunks[key].queue_free()
			chunks.erase(key)


func _build(c: Vector2i) -> void:
	if chunks.has(c):
		return
	var chunk := Chunk.new()
	add_child(chunk)
	chunk.build(c)
	chunks[c] = chunk
