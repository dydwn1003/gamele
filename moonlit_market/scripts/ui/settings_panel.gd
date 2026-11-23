extends "res://scripts/ui/base_panel.gd"
## G. 설정 화면 — 사운드/음악/진동, 저장 상태, 초기화, 게임 정보, (디버그 빌드 전용) 테스트 도구

func _configure() -> void:
	title_text = "설정"
	sheet_ratio = 0.84


func build() -> void:
	section("사운드")
	for item in [["sound", "효과음"], ["music", "배경 음악"], ["vibration", "진동"]]:
		var key: String = item[0]
		var on := bool(GameManager.state.settings.get(key, true))
		var row := UIKit.hbox(10)
		var l := UIKit.label(item[1], "body")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var b := UIKit.button("켜짐" if on else "꺼짐", "success" if on else "secondary", 68)
		b.custom_minimum_size = Vector2(160, 68)
		b.pressed.connect(func(): GameManager.set_setting(key, not on))
		row.add_child(b)
		content.add_child(row)
	content.add_child(UIKit.label("TODO: 배경 음악 에셋이 아직 없습니다 (설정만 저장됨).", "caption"))
	section("저장")
	var sc := UIKit.card()
	var sv := UIKit.vbox(6)
	sc.add_child(sv)
	var t: float = SaveManager.last_save_unix
	var when := "-" if t <= 0.0 else Time.get_datetime_string_from_unix_time(int(t) + _tz_offset(), true)
	info_row(sv, "마지막 저장", when)
	info_row(sv, "상태", SaveManager.last_message if SaveManager.last_message != "" else "-", UIKit.SUCCESS if SaveManager.last_save_ok else UIKit.DANGER)
	info_row(sv, "백업 파일", "있음" if SaveManager.has_backup() else "없음")
	info_row(sv, "자동 저장", "%d초마다 · 중요 행동 직후 · 백그라운드 전환 시" % int(DataManager.bal("autosave_interval", 30)))
	content.add_child(sc)
	var row2 := UIKit.hbox(10)
	var save_b := UIKit.button("지금 저장", "primary", 76)
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_b.disabled = GameManager.is_operating
	save_b.pressed.connect(func():
		if GameManager.save_game("manual"):
			GameManager.notify("저장했습니다.", "success")
		queue_refresh()
	)
	row2.add_child(save_b)
	var reset_b := UIKit.button("초기화", "danger", 76)
	reset_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.set_enabled(reset_b, not GameManager.is_operating)
	reset_b.pressed.connect(_confirm_reset)
	row2.add_child(reset_b)
	content.add_child(row2)
	section("게임 정보")
	var ic := UIKit.card()
	var iv := UIKit.vbox(6)
	ic.add_child(iv)
	info_row(iv, "게임", "달빛장터 (MOONLIT MARKET)")
	info_row(iv, "버전", str(ProjectSettings.get_setting("application/config/version", "0.1.0")))
	info_row(iv, "엔진", "Godot %s" % Engine.get_version_info().get("string", ""))
	info_row(iv, "세이브 버전", str(SaveManager.CURRENT_VERSION))
	info_row(iv, "빌드", "디버그" if OS.is_debug_build() else "출시")
	content.add_child(ic)
	if not DataManager.load_errors.is_empty():
		content.add_child(UIKit.label("데이터 경고: " + "; ".join(DataManager.load_errors), "caption", UIKit.DANGER))
	if OS.is_debug_build() and bool(DataManager.bal("debug_rewards_enabled", false)):
		_build_debug()


func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _confirm_reset() -> void:
	ui.confirm("게임 초기화", "모든 진행 상황이 삭제됩니다. 계속할까요?", "다음", func():
		ui.confirm("정말 초기화할까요?", "이 작업은 되돌릴 수 없습니다.", "초기화", func():
			GameManager.reset_game()
			ui.close_all()
		, true)
	, true)


## 디버그 빌드 전용 — 출시 빌드(OS.is_debug_build() == false)에서는 표시되지 않는다.
func _build_debug() -> void:
	section("[디버그 전용] 테스트 도구")
	content.add_child(UIKit.label("출시 빌드에서는 자동으로 숨겨집니다.", "caption", UIKit.DANGER))
	var row := UIKit.hbox(10)
	var b1 := UIKit.button("+1,000 코인", "secondary", 68)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.pressed.connect(func():
		GameManager.economy.earn(1000)
		GameManager.commit("debug")
	)
	row.add_child(b1)
	var b2 := UIKit.button("+50 평판", "secondary", 68)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.pressed.connect(func():
		GameManager.state.reputation += 50
		GameManager.commit("debug")
	)
	row.add_child(b2)
	content.add_child(row)
	var row2 := UIKit.hbox(10)
	var b3 := UIKit.button("오프라인 60분 경과", "secondary", 68)
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b3.pressed.connect(func():
		GameManager.state.last_seen_unix -= 3600.0
		GameManager.state.max_seen_unix -= 3600.0
		GameManager.check_offline_reward()
	)
	row2.add_child(b3)
	var b4 := UIKit.button("이벤트 발생", "secondary", 68)
	b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b4.pressed.connect(func():
		if ui.main:
			ui.main.debug_trigger_event()
	)
	row2.add_child(b4)
	content.add_child(row2)
