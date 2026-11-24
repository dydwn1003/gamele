extends Node
## GameManager (Autoload)
## 게임 상태와 하위 매니저(경제/성장/오프라인/상인/시너지)를 소유하고,
## UI 가 호출하는 "행동(action)" API 와 변경 알림(signal)을 제공한다.
## UI 는 상태를 직접 수정하지 않고 반드시 이 API 를 거친다.

const GameStateScript := preload("res://scripts/core/game_state.gd")
const EconomyScript := preload("res://scripts/core/economy_manager.gd")
const ProgressionScript := preload("res://scripts/core/progression_manager.gd")
const OfflineScript := preload("res://scripts/core/offline_manager.gd")
const StaffScript := preload("res://scripts/staff/staff_manager.gd")
const SynergyScript := preload("res://scripts/market/synergy_manager.gd")
const AdServiceScript := preload("res://scripts/services/rewarded_ad_service.gd")
const PurchaseServiceScript := preload("res://scripts/services/purchase_service.gd")

signal currency_changed(coins: int, reputation: int)
signal slots_changed
signal state_changed
signal toast(text: String, kind: String)
signal stage_up(stage: Dictionary)
signal offline_reward_ready(info: Dictionary)
signal boot_issue(status: String, message: String)
signal session_phase_changed(phase: String)
signal session_result_ready(result: Dictionary)

var state
var economy
var progression
var offline
var staff
var synergy
var ads
var purchases

var boot_status: String = "none"
var boot_message: String = ""
var is_operating: bool = false
var synergy_cache: Dictionary = {}
var _autosave_timer: float = 0.0
var _dirty: bool = false
var _booted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	# 테스트 실행 시 실제 세이브를 건드리지 않도록 별도 폴더 사용
	if is_test_run():
		SaveManager.save_dir = "user://_test_saves"
		DirAccess.make_dir_recursive_absolute(SaveManager.save_dir)
	_create_managers()
	boot()


func _create_managers() -> void:
	state = GameStateScript.new()
	state.reset_empty()
	progression = ProgressionScript.new()
	economy = EconomyScript.new()
	staff = StaffScript.new()
	offline = OfflineScript.new()
	synergy = SynergyScript.new()
	progression.setup(state, DataManager)
	economy.setup(state, DataManager, staff)
	staff.setup(state, DataManager, economy, progression)
	offline.setup(state, DataManager)
	synergy.setup(DataManager)
	economy.coins_changed.connect(func(_c): _emit_currency())
	ads = AdServiceScript.new()
	ads.setup(bool(DataManager.bal("debug_rewards_enabled", false)))
	purchases = PurchaseServiceScript.new()
	purchases.setup(DataManager.bm)


## 세이브 로드 또는 신규 게임 시작
func boot() -> void:
	var res: Dictionary = SaveManager.load_dict()
	boot_status = str(res.get("status", "none"))
	boot_message = str(res.get("message", ""))
	match boot_status:
		"ok", "recovered":
			if not state.from_dict(res["data"], DataManager):
				boot_status = "corrupt"
				boot_message = "저장 데이터 형식이 올바르지 않습니다."
				new_game(false)
		"corrupt":
			new_game(false) # 손상 시: 임시로 새 게임 상태 (UI 에서 복구/초기화 선택), 자동 저장은 보류
		_:
			new_game(true)
	_after_state_loaded()
	_booted = true
	if boot_status == "recovered" or boot_status == "corrupt":
		call_deferred("emit_signal", "boot_issue", boot_status, boot_message)
	call_deferred("check_offline_reward")


func new_game(save_now: bool = true) -> void:
	state.reset_empty()
	state.coins = int(DataManager.bal("start_coins", 500))
	state.reputation = int(DataManager.bal("start_reputation", 0))
	var start_emp := str(DataManager.bal("start_employee", "emp_basic"))
	for id in DataManager.employees.keys():
		if bool(DataManager.employees[id].get("starting", false)) or id == start_emp:
			state.employees[id] = {"hired": true, "level": 1}
	var start_stock := int(DataManager.pocha.get("start_stock", 12))
	for id in DataManager.pocha.get("start_menus", []):
		state.pocha["menus"][str(id)] = state.make_menu_entry(true, start_stock)
	if state.employees.has(start_emp):
		state.pocha["staff"].append(start_emp)
	state.today_weather = "cloudy"
	state.last_seen_unix = now()
	state.max_seen_unix = state.last_seen_unix
	progression.refresh_unlocks()
	if save_now:
		save_game("new_game")


func _after_state_loaded() -> void:
	progression.update_market_level()
	progression.refresh_unlocks()
	refresh_synergy()
	_emit_all()


func _process(delta: float) -> void:
	if not _booted or is_test_run():
		return
	_autosave_timer += delta
	if _autosave_timer >= float(DataManager.bal("autosave_interval", 30.0)):
		_autosave_timer = 0.0
		offline.touch(now())
		if boot_status != "corrupt":
			save_game("autosave")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _booted and boot_status != "corrupt":
				offline.touch(now())
				save_game("background")
		NOTIFICATION_APPLICATION_RESUMED:
			if _booted:
				check_offline_reward()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _booted and boot_status != "corrupt":
				offline.touch(now())
				save_game("quit")
			get_tree().quit()


static func is_test_run() -> bool:
	return OS.get_cmdline_user_args().has("--test")


static func now() -> float:
	return Time.get_unix_time_from_system()


# ───────── 저장 ─────────

func save_game(_reason: String = "") -> bool:
	if boot_status == "corrupt":
		return false
	_dirty = false
	return SaveManager.save_dict(state.to_dict())


## 중요한 행동 직후 호출
func commit(reason: String = "action") -> void:
	refresh_synergy()
	_check_progression()
	_emit_all()
	save_game(reason)


## 손상 세이브 대응: 백업 복원 시도
func recover_from_backup() -> bool:
	var d: Dictionary = SaveManager.restore_backup_only()
	if d.is_empty() or not state.from_dict(d, DataManager):
		toast.emit("백업 복원에 실패했습니다.", "error")
		return false
	boot_status = "ok"
	_after_state_loaded()
	save_game("recover")
	toast.emit("백업에서 복원했습니다.", "success")
	return true


## 손상 세이브 대응 / 설정의 초기화: 새 게임으로 시작
func reset_game() -> void:
	if is_operating:
		return
	SaveManager.delete_all()
	boot_status = "ok"
	new_game(true)
	_after_state_loaded()
	toast.emit("새 게임을 시작했습니다.", "info")


# ───────── 알림 ─────────

func _emit_currency() -> void:
	currency_changed.emit(state.coins, state.reputation)


func _emit_all() -> void:
	_emit_currency()
	slots_changed.emit()
	state_changed.emit()


func _check_progression() -> void:
	var ups: Array = progression.update_market_level()
	for st in ups:
		stage_up.emit(st)
	var newly: Array = progression.refresh_unlocks()
	if newly.size() > 0 and _booted:
		toast.emit("새로 해금: " + ", ".join(newly), "success")


func refresh_synergy() -> void:
	synergy_cache = synergy.compute(state.enabled_menus())


func notify(text: String, kind: String = "info") -> void:
	toast.emit(text, kind)


func _result(r: Dictionary, success_text: String = "") -> Dictionary:
	if r.get("ok", false):
		if success_text != "":
			toast.emit(success_text, "success")
		vibrate(20)
		commit()
	else:
		toast.emit(str(r.get("error", "실패")), "error")
	return r


func _blocked_by_operation() -> bool:
	if is_operating:
		toast.emit("영업 중에는 변경할 수 없습니다.", "error")
		return true
	return false


func vibrate(ms: int) -> void:
	if bool(state.settings.get("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ───────── 행동 API (UI → 로직) ─────────

func upgrade_pocha() -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	var r: Dictionary = economy.upgrade_pocha(progression.max_stall_level())
	return _result(r, "포차 업그레이드! Lv.%d" % int(r.get("level", 0)))


func set_menu_enabled(menu_id: String, enabled: bool) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	var r: Dictionary = economy.set_menu_enabled(menu_id, enabled, progression)
	return _result(r, "")


func set_price_ratio(menu_id: String, ratio: float) -> Dictionary:
	if is_operating:
		return {"ok": false}
	var r: Dictionary = economy.set_price_ratio(menu_id, ratio)
	if r.get("ok", false):
		_dirty = true
		slots_changed.emit()
	return r


func restock(menu_id: String) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	var r: Dictionary = economy.restock(menu_id)
	return _result(r, "재료 %d개 구매 (-%d 코인)" % [int(r.get("bought", 0)), int(r.get("cost", 0))])


func restock_all() -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	var r: Dictionary = economy.restock_all()
	return _result(r, "재료 %d개 구매 (-%d 코인)" % [int(r.get("bought", 0)), int(r.get("cost", 0))])


func hire_employee(emp_id: String) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	return _result(staff.hire(emp_id), "%s 고용 완료!" % DataManager.get_employee(emp_id).get("name", ""))


func level_up_employee(emp_id: String) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	var r: Dictionary = staff.level_up(emp_id)
	return _result(r, "상인 레벨 업! Lv.%d" % int(r.get("level", 0)))


func set_staff_working(emp_id: String, working: bool) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	return _result(staff.set_working(emp_id, working), "근무 배치 완료" if working else "근무 해제")


func buy_decoration(deco_id: String) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	var def: Dictionary = DataManager.get_decoration(deco_id)
	if def.is_empty():
		return _result({"ok": false, "error": "알 수 없는 장식입니다."})
	if state.decorations_owned.has(deco_id):
		return _result({"ok": false, "error": "이미 보유한 장식입니다."})
	if not progression.is_decoration_unlocked(deco_id):
		return _result({"ok": false, "error": "아직 해금되지 않았습니다."})
	if not economy.spend(int(def.get("cost", 0))):
		return _result({"ok": false, "error": "코인이 부족합니다."})
	state.decorations_owned.append(deco_id)
	# 빈 장식 자리에 자동 배치
	for i in progression.deco_spot_count():
		if state.deco_spots[i] == "":
			state.deco_spots[i] = deco_id
			break
	return _result({"ok": true}, "%s 구매 완료!" % def["name"])


func toggle_decoration(deco_id: String) -> Dictionary:
	if _blocked_by_operation():
		return {"ok": false}
	if not state.decorations_owned.has(deco_id):
		return {"ok": false}
	var idx: int = state.deco_spots.find(deco_id)
	if idx >= 0:
		state.deco_spots[idx] = ""
		return _result({"ok": true}, "장식을 보관했습니다.")
	for i in progression.deco_spot_count():
		if state.deco_spots[i] == "":
			state.deco_spots[i] = deco_id
			return _result({"ok": true}, "장식을 설치했습니다.")
	return _result({"ok": false, "error": "장식 자리가 부족합니다. 시장 단계를 올려 보세요."})


func set_setting(key: String, value: bool) -> void:
	state.settings[key] = value
	save_game("settings")
	state_changed.emit()


# ───────── 날씨 ─────────

func roll_weather(rng: RandomNumberGenerator = null) -> String:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var max_bad := int(DataManager.weather_meta.get("max_consecutive_bad", 1))
	var recent_bad := 0
	for i in range(state.weather_history.size() - 1, -1, -1):
		if bool(DataManager.get_weather(str(state.weather_history[i])).get("is_bad", false)):
			recent_bad += 1
		else:
			break
	var pool: Array = []
	var total := 0.0
	for id in DataManager.weather.keys():
		var w: Dictionary = DataManager.weather[id]
		if recent_bad >= max_bad and bool(w.get("is_bad", false)):
			continue
		pool.append(id)
		total += float(w.get("weight", 1.0))
	var pick := "cloudy"
	var roll := r.randf() * total
	for id in pool:
		roll -= float(DataManager.weather[id].get("weight", 1.0))
		if roll <= 0.0:
			pick = id
			break
	state.today_weather = pick
	return pick


# ───────── 모디파이어 (영업 시뮬레이션용) ─────────

## 장식 + 시장 단계 + 날씨 + 시너지 전역 효과
func market_modifiers() -> Dictionary:
	var m := {"visitor_mult": 1.0, "tourist_mult": 1.0, "satisfaction": 0.0, "patience_mult": 1.0, "stay_mult": 1.0}
	m["visitor_mult"] *= float(progression.current_stage().get("visitor_mult", 1.0))
	m["visitor_mult"] *= float(DataManager.get_weather(state.today_weather).get("visitor_mult", 1.0))
	for i in progression.deco_spot_count():
		var id: String = state.deco_spots[i]
		if id == "":
			continue
		var eff: Dictionary = DataManager.get_decoration(id).get("effects", {})
		m["visitor_mult"] *= 1.0 + float(eff.get("visitor_mult", 0.0))
		m["tourist_mult"] += float(eff.get("tourist_mult", 0.0))
		m["satisfaction"] += float(eff.get("satisfaction", 0.0))
		m["patience_mult"] += float(eff.get("patience_mult", 0.0))
	var g: Dictionary = synergy_cache.get("effects", {})
	if state.today_weather == "rain":
		m["visitor_mult"] *= 1.0 + float(g.get("rain_visitor_bonus", 0.0))
	# 관광객은 시장 평판에 민감
	m["tourist_mult"] *= clampf(0.5 + state.reputation / 150.0, 0.5, 2.5)
	return m


# ───────── 영업 / 정산 / 오프라인 ─────────

func set_operating(value: bool, phase: String) -> void:
	is_operating = value
	session_phase_changed.emit(phase)


func on_session_closed(result: Dictionary) -> void:
	state.weather_history.append(state.today_weather)
	while state.weather_history.size() > 5:
		state.weather_history.pop_front()
	roll_weather()
	save_game("session_closed")
	session_result_ready.emit(result)


## 정산 수령 (중복 지급 방지는 EconomyManager.claim_result 가 보장)
func claim_session_result() -> Dictionary:
	var r: Dictionary = economy.claim_result()
	if r.get("ok", false):
		commit("claim_result")
	return r


func check_offline_reward() -> void:
	if is_operating:
		return
	var info: Dictionary = offline.compute_pending(now())
	if info.get("rollback", false):
		toast.emit("기기 시간이 변경되어 오프라인 보상이 계산되지 않았습니다.", "error")
	save_game("offline_compute")
	if offline.has_pending():
		offline_reward_ready.emit(info)


func claim_offline_reward(multiplier: float = 1.0) -> int:
	var paid: int = offline.claim(economy, now(), multiplier)
	if paid > 0:
		commit("offline_claim")
	return paid
