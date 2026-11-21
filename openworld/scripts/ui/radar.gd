extends Control
## 원형 레이더 겸 나침반. 위쪽이 카메라가 보는 방향.
## 노란 점: 아직 밝히지 않은 봉화 / 주황 점: 밝힌 봉화 / 빨간 점: 근처의 적.
## 범위 밖 봉화는 테두리에 화살표로 표시한다.

const RANGE := 400.0

var player  # player.gd
var camera_rig  # camera_rig.gd
var beacons: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _to_radar(world: Vector3, yaw: float, radius: float) -> Vector2:
	var pp: Vector3 = player.global_position
	var d := Vector2(world.x - pp.x, world.z - pp.z)
	# 카메라 yaw 만큼 반대로 돌려서 "보는 방향 = 위"
	var rx := d.x * cos(yaw) - d.y * sin(yaw)
	var rz := d.x * sin(yaw) + d.y * cos(yaw)
	return Vector2(rx, rz) / RANGE * radius


func _draw() -> void:
	if player == null or camera_rig == null:
		return
	var radius := size.x * 0.5
	var c := size * 0.5
	var yaw: float = camera_rig.yaw
	var font := get_theme_default_font()
	draw_circle(c, radius, Color(0.08, 0.1, 0.12, 0.6))
	draw_arc(c, radius, 0, TAU, 48, Color(0.95, 0.85, 0.6, 0.8), 3.0, true)
	draw_arc(c, radius * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.15), 1.0, true)

	# 북쪽(N) 표시
	var north := _to_radar(player.global_position + Vector3(0, 0, -RANGE), yaw, radius)
	draw_string(font, c + north.normalized() * (radius - 14) + Vector2(-8, 7), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.5, 0.4))

	var list: Array = player.get_tree().get_nodes_in_group("enemies")
	for e in list:
		var p := _to_radar(e.global_position, yaw, radius)
		if p.length() < radius - 4:
			draw_circle(c + p, 3.5, Color(1, 0.3, 0.25))

	for b in beacons:
		var p := _to_radar(b.global_position, yaw, radius)
		var col := Color(1, 0.55, 0.15) if b.lit else Color(1, 0.92, 0.3)
		if p.length() > radius - 10:
			var dir := p.normalized()
			var tip := c + dir * (radius - 4)
			var side := Vector2(-dir.y, dir.x) * 7.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14 + side, tip - dir * 14 - side]), col)
		else:
			draw_circle(c + p, 6.0, col)

	# 플레이어 (가운데 삼각형: 캐릭터가 보는 방향)
	var face_yaw: float = player.model.rotation.y - yaw
	var f := Vector2(-sin(face_yaw), -cos(face_yaw))
	var s := Vector2(-f.y, f.x)
	draw_colored_polygon(PackedVector2Array([c + f * 10, c - f * 6 + s * 6, c - f * 6 - s * 6]), Color(1, 1, 1))
