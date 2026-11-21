extends Node3D
## 잿빛 늑대. 네 다리를 대각선 쌍으로 움직여 달린다. 앞쪽은 -Z.

const LowPoly = preload("res://scripts/models/low_poly.gd")

var body: Node3D
var head: Node3D
var tail: Node3D
var legs: Array[Node3D] = []
var _phase := 0.0
var _attack_t := -1.0
var _attack_len := 0.4
var _base_scale := 1.0


func setup(_style := "wolf") -> void:
	var fur := Color(0.45, 0.45, 0.48)
	var fur_d := Color(0.3, 0.3, 0.33)
	var belly := Color(0.72, 0.7, 0.66)
	body = Node3D.new()
	body.position = Vector3(0, 0.62, 0)
	add_child(body)

	var b := LowPoly.new()
	b.box(Vector3(0, 0, 0), Vector3(0.42, 0.38, 0.95), fur)
	b.box(Vector3(0, 0.06, -0.38), Vector3(0.48, 0.46, 0.4), fur_d)  # 갈기
	b.box(Vector3(0, -0.17, 0.05), Vector3(0.34, 0.06, 0.7), belly)
	body.add_child(b.instance())

	head = Node3D.new()
	head.position = Vector3(0, 0.12, -0.55)
	body.add_child(head)
	var h := LowPoly.new()
	h.box(Vector3(0, 0, -0.1), Vector3(0.32, 0.3, 0.3), fur)
	h.box(Vector3(0, -0.05, -0.33), Vector3(0.18, 0.16, 0.24), fur)  # 주둥이
	h.box(Vector3(0, -0.01, -0.45), Vector3(0.07, 0.06, 0.03), Color(0.1, 0.1, 0.1))
	h.cylinder(Vector3(0.1, 0.14, -0.02), 0.06, 0.0, 0.16, 4, fur_d)
	h.cylinder(Vector3(-0.1, 0.14, -0.02), 0.06, 0.0, 0.16, 4, fur_d)
	h.box(Vector3(0.08, 0.06, -0.255), Vector3(0.05, 0.03, 0.02), Color(1.0, 0.55, 0.15))
	h.box(Vector3(-0.08, 0.06, -0.255), Vector3(0.05, 0.03, 0.02), Color(1.0, 0.55, 0.15))
	head.add_child(h.instance())

	tail = Node3D.new()
	tail.position = Vector3(0, 0.1, 0.47)
	body.add_child(tail)
	var t := LowPoly.new()
	t.box(Vector3(0, -0.05, 0.22), Vector3(0.12, 0.12, 0.45), fur_d, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3.ZERO))
	tail.add_child(t.instance())

	for pos in [Vector3(-0.14, -0.12, -0.35), Vector3(0.14, -0.12, -0.35), Vector3(-0.14, -0.12, 0.35), Vector3(0.14, -0.12, 0.35)]:
		var leg := Node3D.new()
		leg.position = pos
		body.add_child(leg)
		var l := LowPoly.new()
		l.box(Vector3(0, -0.22, 0), Vector3(0.1, 0.44, 0.12), fur)
		l.box(Vector3(0, -0.47, -0.03), Vector3(0.11, 0.06, 0.16), fur_d)
		leg.add_child(l.instance())
		legs.append(leg)
	_base_scale = scale.x


func play_attack(_kind: int, length: float) -> void:
	_attack_len = length
	_attack_t = 0.0


func flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * _base_scale * 1.12, 0.05)
	tw.tween_property(self, "scale", Vector3.ONE * _base_scale, 0.12)


func animate(delta: float, state: String, speed_ratio: float, _progress := 0.0) -> void:
	var k := 1.0 - exp(-14.0 * delta)
	var sw := 0.0
	var body_x := 0.0
	var head_x := 0.0
	var body_y := 0.62
	if state == "move":
		_phase += delta * lerpf(7.0, 14.0, speed_ratio)
		sw = sin(_phase) * lerpf(0.4, 0.9, speed_ratio)
		body_y += absf(sin(_phase)) * 0.05
		body_x = sin(_phase * 2.0) * 0.05
	elif state == "idle":
		_phase += delta * 2.5
		head_x = sin(_phase) * 0.08
	elif state == "dead":
		body.rotation.z = lerpf(body.rotation.z, PI * 0.5, k)
		body.position.y = lerpf(body.position.y, 0.25, k)
		return
	if _attack_t >= 0.0:
		_attack_t += delta
		var t := _attack_t / _attack_len
		head_x = -0.6 * sin(t * PI)
		body_x = 0.25 * sin(t * PI)
		if _attack_t >= _attack_len:
			_attack_t = -1.0
	legs[0].rotation.x = sw
	legs[3].rotation.x = sw
	legs[1].rotation.x = -sw
	legs[2].rotation.x = -sw
	body.rotation.x = lerpf(body.rotation.x, body_x, k)
	body.position.y = lerpf(body.position.y, body_y, k)
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
	tail.rotation.y = sin(_phase * 1.3) * 0.4
