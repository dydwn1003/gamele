extends Node
## 개발용 자동 플레이 + 스크린샷 도구 (렌더링 가능한 환경에서 실행)
## godot --path . --rendering-driver opengl3 res://tools/capture.tscn -- --test --out=<폴더>
## 새 게임 → 내 포차 → 영업 준비 → 영업(봇이 요리) → 정산 → 시장/상인 화면을 PNG 로 저장한다.

const MainScene := preload("res://scenes/main/main.tscn")

var out_dir: String = "user://captures"
var main
var bot_on: bool = false


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
	GameManager.state.coins = 3000
	GameManager.restock_all()
	main.ui.open("pocha")
	await _wait(0.6)
	await _shot("02_pocha_panel")
	main.ui.close_all(false)
	main._on_main_button()
	await _wait(0.6)
	await _shot("03_preparation")
	main.start_session()
	main.market.operating.set_speed(2.0)
	bot_on = true
	await _wait(14.0)
	await _shot("04_cooking")
	await _wait(16.0)
	await _shot("05_cooking_busy")
	while main.market.operating.is_running():
		await _wait(1.0)
	bot_on = false
	await _wait(1.0)
	await _shot("06_result")
	main.ui.close_all(false)
	main.ui.open("market")
	await _wait(0.6)
	await _shot("07_rivals")
	main.ui.close_all(false)
	main.ui.open("employee")
	await _wait(0.6)
	await _shot("08_staff")
	print("CAPTURE_DONE ", out_dir)
	get_tree().quit()


## 화면 확인용 봇: 실제 플레이와 같은 API 로 요리·따르기·서빙·치우기
func _process(_delta: float) -> void:
	if not bot_on or main == null:
		return
	var pm = main.market.pocha_manager
	for i in pm.kitchen.burners.size():
		if i != pm.auto_burner and pm.kitchen.stage(i) == "perfect" and pm.kitchen.ratio(i) > 1.1 and pm.pass_space() > 0:
			main.ui.hud.kitchen._on_burner(i)
	for i in pm.seat_state.size():
		if pm.seat_state[i]["state"] == "dirty" and randf() < 0.02:
			pm.tap_seat(i)
		elif pm.seats[i] != null and is_instance_valid(pm.seats[i]) and pm.seats[i].can_receive() and randf() < 0.05:
			if pm.pass_has_for(pm.seats[i], pm.server.tray) or pm.server.tray_has_for(pm.seats[i]):
				pm.tap_seat(i)
	var making := {}
	for b in pm.kitchen.burners:
		if b["menu"] != "":
			making[b["menu"]] = int(making.get(b["menu"], 0)) + 1
	for p in pm.pass_items:
		making[p["menu"]] = int(making.get(p["menu"], 0)) + 1
	for it in pm.server.tray:
		making[it["menu"]] = int(making.get(it["menu"], 0)) + 1
	for o in pm.orders:
		var m: String = o["menu"]
		if not o["customer"].can_receive():
			continue
		if int(making.get(m, 0)) > 0:
			making[m] = int(making[m]) - 1
			continue
		if str(DataManager.get_menu(m).get("station", "")) == "drink":
			if randf() < 0.04:
				main.ui.hud.kitchen.pour_amount(m, 0.86)
			return
		main.ui.hud.kitchen._on_cook(m)
		return


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)
