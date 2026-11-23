extends Node
## Main — 시장 월드(Market)와 UI(UIManager)를 연결하는 최상위 장면 스크립트.
## 게임 규칙은 GameManager/매니저들에 있고, 여기서는 화면 흐름만 조정한다.

const SfxScript := preload("res://scripts/services/sfx_player.gd")

@onready var market = $Market
@onready var ui = $UILayer/UIRoot

var sfx


func _ready() -> void:
	sfx = SfxScript.new()
	add_child(sfx)
	ui.main = self
	var hud = ui.hud
	hud.main_button_pressed.connect(_on_main_button)
	hud.nav_pressed.connect(_on_nav)
	hud.settings_pressed.connect(func(): ui.open("settings"))
	hud.speed_pressed.connect(_on_speed)
	hud.cancel_mode_pressed.connect(_cancel_mode)
	ui.layout_changed.connect(_relayout)
	market.slot_tapped.connect(_on_slot_tapped)
	var op = market.operating
	op.tick.connect(func(remaining: float, stats: Dictionary): hud.update_session(remaining, stats))
	op.event_started.connect(_on_event_started)
	op.event_ended.connect(func(_ev): hud.hide_event())
	market.stall_manager.sale_made.connect(func(_i, _p, _s): sfx.play("coin"))
	market.customer_manager.walkout_feedback.connect(func(_pos): sfx.play("bad"))
	GameManager.placement_requested.connect(_on_placement_requested)
	GameManager.move_requested.connect(_on_move_requested)
	GameManager.session_result_ready.connect(_on_result)
	GameManager.offline_reward_ready.connect(_on_offline_reward)
	GameManager.stage_up.connect(_on_stage_up)
	GameManager.boot_issue.connect(_on_boot_issue)
	call_deferred("_after_ready")


func _after_ready() -> void:
	_relayout()
	# 부팅 상태 확인 (시그널을 놓친 경우 대비)
	if GameManager.boot_status == "corrupt" or GameManager.boot_status == "recovered":
		_on_boot_issue(GameManager.boot_status, GameManager.boot_message)
	elif GameManager.economy.has_unclaimed_result():
		ui.open("result", {})
	elif GameManager.offline.has_pending():
		_on_offline_reward({})
	if not GameManager.state.tutorial_done and GameManager.boot_status != "corrupt":
		GameManager.state.tutorial_done = true
		ui.dialog("달빛장터에 오신 것을 환영합니다!", "작은 꼬치 노점 하나로 시작합니다.\n\n1. 빈 자리(+)를 눌러 노점을 설치하세요.\n2. [영업 준비]에서 메뉴·가격·재고를 정하세요.\n3. 영업을 시작하면 손님들이 실제로 찾아와 줄을 서고 구매합니다.\n\n이웃한 노점 조합(예: 꼬치+음료)은 시너지를 만듭니다.", [{"text": "시작하기", "variant": "primary", "callback": Callable()}])


func _relayout() -> void:
	market.fit_to_rect(ui.market_rect())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android 뒤로 가기: 열린 패널/모드부터 닫는다
		if market.mode != "normal":
			_cancel_mode()
		elif not ui.handle_back():
			ui.confirm("게임 종료", "달빛장터를 종료할까요? (진행 상황은 저장됩니다)", "종료", func():
				GameManager.save_game("quit")
				get_tree().quit()
			)


# ───────── 영업 ─────────

func can_start_session() -> String:
	return market.operating.can_start()


func start_session() -> bool:
	_cancel_mode()
	var ok: bool = market.operating.start_session()
	if ok:
		ui.close_all()
		sfx.play("click")
	return ok


func debug_trigger_event() -> void:
	if not OS.is_debug_build():
		return
	if not market.operating.is_running():
		GameManager.notify("영업 중에만 이벤트를 발생시킬 수 있습니다.", "error")
		return
	var ids: Array = DataManager.events.keys()
	if ids.size() > 0:
		market.operating.debug_trigger_event(str(ids[randi() % ids.size()]))
		ui.close_all()


func _on_main_button() -> void:
	if GameManager.is_operating:
		return
	if GameManager.economy.has_unclaimed_result():
		ui.open("result", {})
		return
	_cancel_mode()
	ui.open("preparation")


func _on_speed() -> void:
	var op = market.operating
	var s: float = op.speed + 1.0
	if s > 3.0:
		s = 1.0
	op.set_speed(s)
	ui.hud.update_session(op.remaining(), op.stats())


func _on_event_started(ev: Dictionary) -> void:
	ui.hud.show_event(ev)
	GameManager.notify("이벤트 발생: " + str(ev.get("name", "")), "event")


func _on_result(result: Dictionary) -> void:
	ui.close_all()
	ui.hud.hide_event()
	ui.open("result", {"result": result})


func _on_offline_reward(_info: Dictionary) -> void:
	if GameManager.is_operating or ui.is_open("offline") or ui.is_open("result"):
		return
	ui.open("offline")


func _on_stage_up(stage: Dictionary) -> void:
	sfx.play("levelup")
	GameManager.vibrate(60)
	ui.dialog("시장 성장!", "%d단계 「%s」 달성!\n\n%s" % [int(stage.get("level", 0)), stage.get("name", ""), stage.get("desc", "")], [{"text": "좋아요", "variant": "primary", "callback": Callable()}])


func _on_boot_issue(status: String, message: String) -> void:
	if ui.is_open("dialog"):
		return
	if status == "recovered":
		ui.dialog("저장 데이터 복구", message + "\n일부 최근 진행이 빠졌을 수 있습니다.", [{"text": "확인", "variant": "primary", "callback": Callable()}])
		return
	var buttons: Array = []
	if SaveManager.has_backup():
		buttons.append({"text": "백업 복원", "variant": "primary", "callback": _try_restore_backup})
	buttons.append({"text": "새 게임", "variant": "danger", "callback": GameManager.reset_game})
	ui.dialog("저장 데이터 손상", message + "\n손상된 파일은 save.corrupt.json 으로 보관했습니다. 어떻게 할까요?", buttons, false)


func _try_restore_backup() -> void:
	if not GameManager.recover_from_backup():
		_on_boot_issue("corrupt", "백업도 손상되었습니다.")


# ───────── 메뉴 / 슬롯 ─────────

func _on_nav(id: String) -> void:
	_cancel_mode()
	match id:
		"market":
			ui.open("market")
		"staff":
			ui.open("employee")
		"build":
			ui.open("build")
		"shop":
			ui.open("shop")


func _on_slot_tapped(idx: int) -> void:
	match market.mode:
		"place":
			var t: String = market.place_type
			if not GameManager.state.is_slot_empty(idx):
				GameManager.notify("빈 자리를 선택하세요.", "error")
				return
			var r: Dictionary = GameManager.build_structure(idx, t)
			if r.get("ok", false):
				sfx.play("levelup")
			_cancel_mode()
		"move":
			var from: int = market.move_from
			if idx != from:
				GameManager.move_structure(from, idx)
			_cancel_mode()
		_:
			if ui.top_panel() != null:
				return
			sfx.play("click")
			market.set_selected(idx)
			var p = ui.open("stall", {"slot": idx})
			if p:
				p.tree_exited.connect(func():
					if is_instance_valid(market):
						market.set_selected(-1)
				)


func _on_placement_requested(structure_type: String) -> void:
	ui.close_all()
	market.enter_place_mode(structure_type)
	var nm := str(DataManager.get_stall(structure_type).get("name", DataManager.get_facility(structure_type).get("name", "")))
	ui.hud.show_mode("「%s」을(를) 설치할 빈 자리를 누르세요" % nm)


func _on_move_requested(from_slot: int) -> void:
	ui.close_all()
	market.enter_move_mode(from_slot)
	ui.hud.show_mode("옮길 자리를 누르세요 (노점이 있으면 서로 바뀝니다)")


func _cancel_mode() -> void:
	if market.mode != "normal":
		market.cancel_mode()
	ui.hud.show_mode("")
