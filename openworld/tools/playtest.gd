extends SceneTree
## 자동 플레이 테스트: 장면별 스크린샷 + 전투/봉화 동작 검증
var frame := 0
var out := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://shots"
var main
var c
var golem
var b
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	frame += 1
	c = root.get_node("/root/Controls")
	if frame >= 120 and frame < 1500: main.player.hp = 999.0  # 테스트 중 무적
	match frame:
		60: _shot("01_start")
		70:  # 카엘 정면 클로즈업
			main.rig.yaw = main.player.model.rotation.y + PI
			main.rig.pitch = -0.12
			main.rig.spring.spring_length = 3.0
		110: _shot("02_kael_closeup")
		120:
			main.rig.spring.spring_length = 6.5
			b = main.beacons[0]
			main.player.global_position = b.global_position + Vector3(16, 2, 10)
		200:
			golem = b.guardian
			print("guardian spawned: ", golem != null)
			if golem:
				var d = golem.global_position - main.player.global_position
				main.rig.yaw = atan2(-d.x, -d.z) + 0.5
				main.rig.pitch = -0.15
		260: _shot("03_beacon_golem")
	# 260~ : 골렘에게 다가가 계속 공격
	if frame > 270 and frame < 1500 and golem and is_instance_valid(golem) and not golem.dead:
		var d = golem.global_position - main.player.global_position
		d.y = 0
		c.move_touch = Vector2(0, -1) if d.length() > 3.5 else Vector2.ZERO
		main.rig.yaw = lerp_angle(main.rig.yaw, atan2(-d.x, -d.z), 0.1)
		if d.length() <= 3.5 and frame % 10 == 0: c.press("attack")
		main.player.hp = 999.0  # 테스트 중에는 무적
		if frame == 420: _shot("04_combat")
	if frame == 1500 or (golem and is_instance_valid(golem) and golem.dead and frame < 1500 and not has_meta("killed")):
		set_meta("killed", true)
		c.move_touch = Vector2.ZERO
		print("golem dead at frame ", frame, " level=", root.get_node("/root/GameState").level)
		main.player.global_position = b.global_position + Vector3(0, 2, -5)
		set_meta("light_frame", frame + 30)
	if has_meta("light_frame") and frame == get_meta("light_frame"):
		print("hint: ", c.interact_hint)
		c.press("interact")
	if has_meta("light_frame") and frame == get_meta("light_frame") + 20:
		print("lit: ", b.lit, " beacons=", root.get_node("/root/GameState").lit_beacons)
		main.player.global_position = b.global_position + Vector3(25, 3, 25)
		var d = b.global_position - main.player.global_position
		main.rig.yaw = atan2(-d.x, -d.z); main.rig.pitch = 0.05
	if has_meta("light_frame") and frame == get_meta("light_frame") + 80:
		main._time_of_day = 0.82
		_shot("05_beacon_lit_dusk")
	if has_meta("light_frame") and frame == get_meta("light_frame") + 90:
		# 높은 곳에서 활공
		main._time_of_day = 0.4
		main.player.global_position = Vector3(200, 140, 200)
		c.press("jump")
	if has_meta("light_frame") and frame == get_meta("light_frame") + 110:
		c.press("jump")
		c.move_touch = Vector2(0, -1)
	if has_meta("light_frame") and frame == get_meta("light_frame") + 200:
		print("gliding: ", main.player.gliding)
		_shot("06_glide")
		return true
	return false
func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("shot ", name)
