extends Node
## 화면 확인용 자동 플레이 + 스크린샷
## godot --path . --rendering-driver opengl3 res://tools/capture.tscn -- --test --out=<폴더>

const MainScene := preload("res://scenes/main.tscn")

var out_dir: String = "user://captures"
var main


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.reset()
	Save.unlocked = 3
	Save.tutorial_done = true
	main = MainScene.instantiate()
	add_child(main)
	await _wait(2.5)
	await _shot("01_title")
	main.show_select()
	await _wait(0.6)
	await _shot("02_select")
	var b = main.start_battle("league", 1)
	b.enable_auto_play()
	await _wait(5.5)
	await _shot("03_battle")
	await _wait(2.0)
	await _shot("04_battle_beams")
	# 경기 끝까지
	var t := 0.0
	while b.state != "result" and t < 120.0:
		await _wait(1.0)
		t += 1.0
	await _wait(0.8)
	await _shot("05_result")
	var v = main.start_battle("versus", 3)
	v.ai_player = null
	var ai2 = load("res://scripts/ai/ai_controller.gd").new()
	ai2.setup(v.logic, 1)
	v.ai = ai2
	v.enable_auto_play()
	await _wait(6.0)
	await _shot("06_versus")
	print("CAPTURE_DONE ", out_dir)
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
