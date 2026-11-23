extends Node
## 개발용 자동 플레이 + 스크린샷 도구 (렌더링 가능한 환경에서 실행)
## godot --path . --rendering-driver opengl3 res://tools/capture.tscn -- --test --out=<폴더>
## 새 게임 → 노점 설치 → 영업 준비 화면 → 영업(3배속) → 정산 화면을 PNG 로 저장한다.

const MainScene := preload("res://scenes/main/main.tscn")

var out_dir: String = "user://captures"
var main


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	GameManager.reset_game()
	GameManager.state.tutorial_done = true
	main = MainScene.instantiate()
	add_child(main)
	await _wait(1.0)
	main.ui.close_all(false)
	await _wait(0.5)
	await _shot("01_market_start")
	# 노점 설치 (꼬치 옆 음료 → 시너지)
	GameManager.state.coins = 3000
	GameManager.build_structure(0, "drink")
	GameManager.build_structure(4, "skewer")
	GameManager.restock_all()
	await _wait(0.5)
	main.ui.open("stall", {"slot": 1})
	await _wait(0.6)
	await _shot("02_stall_panel")
	main.ui.close_all(false)
	main._on_main_button()
	await _wait(0.6)
	await _shot("03_preparation")
	main.start_session()
	main.market.operating.set_speed(3.0)
	await _wait(12.0)
	await _shot("04_operating")
	await _wait(14.0)
	await _shot("05_operating_busy")
	while main.market.operating.is_running():
		await _wait(1.0)
	await _wait(1.0)
	await _shot("06_result")
	main.ui.open("employee")
	await _wait(0.6)
	await _shot("07_employees")
	main.ui.close_all(false)
	main.ui.open("build", {"tab": "synergy"})
	await _wait(0.6)
	await _shot("08_build_synergy")
	print("CAPTURE_DONE ", out_dir)
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)
