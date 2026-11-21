extends Node3D
## 3인칭 카메라. 화면 오른쪽을 드래그(또는 마우스 드래그)하면 회전한다.
## SpringArm3D 가 지형·나무에 부딪히면 카메라를 앞으로 당겨 벽 뚫림을 막는다.

const Terrain = preload("res://scripts/world/terrain.gd")

var target: Node3D
var yaw := 0.0
var pitch := -0.3
var distance := 6.5
var sensitivity := 0.006

var spring: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	top_level = true
	spring = SpringArm3D.new()
	spring.spring_length = distance
	spring.collision_mask = 1
	spring.margin = 0.3
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	spring.shape = shape
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 260.0
	spring.add_child(camera)
	camera.current = true
	if target:
		global_position = target.global_position + Vector3(0, 1.6, 0)


func _process(delta: float) -> void:
	if target == null:
		return
	var look := Controls.consume_look()
	yaw -= look.x * sensitivity
	pitch = clampf(pitch - look.y * sensitivity * 0.8, -1.25, 0.45)
	var goal := target.global_position + Vector3(0, 1.6, 0)
	global_position = global_position.lerp(goal, 1.0 - exp(-14.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
	# 카메라가 물속/땅속으로 들어가지 않게
	var cam_pos := camera.global_position
	var ground := Terrain.height(cam_pos.x, cam_pos.z)
	if cam_pos.y < ground + 0.5:
		camera.global_position.y = ground + 0.5


## 카메라 기준 앞/오른쪽 방향 (수평)
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))
