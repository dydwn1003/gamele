extends Node
## OperatingManager — 240초 영업 흐름, 시간 배속, 이벤트 발생, 영업 종료/정산 트리거.
## phase: "idle" → "open" → "closing" → "idle"(결과 대기)

const CustomerScript := preload("res://scripts/customer/customer.gd")

signal tick(remaining: float, stats: Dictionary)
signal event_started(event: Dictionary)
signal event_ended(event: Dictionary)
signal phase_changed(phase: String)

var rival_manager
var pocha_manager
var customer_manager
var phase: String = "idle"
var elapsed: float = 0.0
var duration: float = 240.0
var closing_t: float = 0.0
var speed: float = 1.0
var active_event: Dictionary = {}
var event_left: float = 0.0
var scheduled_event: String = ""
var scheduled_time: float = -1.0
var rng := RandomNumberGenerator.new()
var _tick_accum: float = 0.0


func _ready() -> void:
	rng.randomize()


func is_running() -> bool:
	return phase == "open" or phase == "closing"


## 영업 시작 가능 여부 → "" 이면 가능, 아니면 사유
func can_start() -> String:
	if is_running():
		return "이미 영업 중입니다."
	if GameManager.economy.has_unclaimed_result():
		return "먼저 지난 영업 정산을 받아 주세요."
	var has_food := false
	for id in GameManager.state.enabled_menus():
		if GameManager.state.stock_of(id) > 0 and str(DataManager.get_menu(id).get("station", "")) == "grill":
			has_food = true
	if not has_food:
		return "음식 재료가 없습니다. 영업 준비에서 재료를 채워 주세요."
	return ""


func start_session() -> bool:
	var reason := can_start()
	if reason != "":
		GameManager.notify(reason, "error")
		return false
	duration = float(DataManager.bal("session_duration", 240.0))
	elapsed = 0.0
	closing_t = 0.0
	speed = 1.0
	active_event = {}
	event_left = 0.0
	var sid: int = GameManager.state.next_session_id
	GameManager.state.next_session_id += 1
	GameManager.economy.begin_session(sid, GameManager.state.today_weather)
	GameManager.refresh_synergy()
	rival_manager.reset_runtime()
	pocha_manager.begin()
	customer_manager.begin(GameManager.market_modifiers())
	_schedule_event()
	_set_phase("open")
	GameManager.set_operating(true, "open")
	GameManager.save_game("session_start")
	return true


func set_speed(s: float) -> void:
	speed = clampf(s, 1.0, 3.0)


func remaining() -> float:
	return maxf(0.0, duration - elapsed)


func _process(delta: float) -> void:
	if not is_running():
		return
	var d := delta * speed
	rival_manager.tick(d, customer_manager.event_mods)
	pocha_manager.tick(d)
	customer_manager.tick(d)
	if phase == "open":
		elapsed += d
		_update_event(d)
		if elapsed >= duration:
			_begin_closing()
	elif phase == "closing":
		closing_t += d
		if customer_manager.active_count() == 0 or closing_t >= float(DataManager.bal("closing_grace", 12.0)):
			_finish()
	_tick_accum += delta
	if _tick_accum >= 0.2:
		_tick_accum = 0.0
		tick.emit(remaining(), stats())


func stats() -> Dictionary:
	var l: Dictionary = GameManager.economy.ledger
	return {
		"visitors": int(l.get("visitors", 0)), "buyers": int(l.get("buyers", 0)),
		"walkouts": int(l.get("walkouts", 0)), "sales": int(l.get("sales", 0)),
		"revenue": int(l.get("revenue", 0)), "phase": phase, "speed": speed,
		"customers_now": customer_manager.active_count(),
		"tips": int(l.get("tips", 0)), "rival_buyers": int(l.get("rival_buyers", 0)),
		"combo": pocha_manager.combo,
		"showdown": _showdown_stats(l),
	}


## 마감: 새 손님은 받지 않고, 이미 자리에 앉았거나 줄 선 손님은 유예 시간 동안 마저 대접한다
func _showdown_stats(l: Dictionary) -> Dictionary:
	if not GameManager.goals.is_showdown_today():
		return {}
	var rid := str(GameManager.state.showdown["rival"])
	return {"rival": rid, "rival_name": str(DataManager.get_rival(rid).get("name", rid)),
		"mine": int(l.get("revenue", 0)), "theirs": int(l.get("rival_revenue", {}).get(rid, 0))}


func _begin_closing() -> void:
	elapsed = duration
	customer_manager.stop_spawning()
	if not active_event.is_empty():
		_end_event()
	for c in customer_manager.customers:
		if is_instance_valid(c) and c.state in [CustomerScript.State.ENTERING, CustomerScript.State.BROWSING]:
			c.force_leave()
	_set_phase("closing")
	GameManager.set_operating(true, "closing")


func _finish() -> void:
	customer_manager.dismiss_all()
	pocha_manager.close()
	rival_manager.clear_all()
	market_release()
	var result: Dictionary = GameManager.economy.close_session(duration, {"best_combo": pocha_manager.best_combo})
	_set_phase("idle")
	GameManager.set_operating(false, "result")
	GameManager.on_session_closed(result)


func market_release() -> void:
	if pocha_manager.market:
		pocha_manager.market.release_all_spots()


func _set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)


# ───────── 이벤트 ─────────

func _schedule_event() -> void:
	scheduled_event = ""
	scheduled_time = -1.0
	if rng.randf() > float(DataManager.events_meta.get("chance_per_session", 0.6)):
		return
	var hist: Array = GameManager.state.event_history
	var last_bad := false
	if hist.size() > 0:
		last_bad = not bool(DataManager.get_event(str(hist[hist.size() - 1])).get("favorable", true))
	var weather_bad := bool(DataManager.get_weather(GameManager.state.today_weather).get("is_bad", false))
	var pool: Array = []
	var total := 0.0
	for id in DataManager.events.keys():
		var ev: Dictionary = DataManager.events[id]
		# 연속으로 불리한 상황 방지: 직전 이벤트가 불리했거나 날씨가 나쁘면 불리한 이벤트 제외
		if not bool(ev.get("favorable", true)) and (last_bad or weather_bad):
			continue
		pool.append(id)
		total += float(ev.get("weight", 1.0))
	if pool.is_empty():
		return
	var roll := rng.randf() * total
	for id in pool:
		roll -= float(DataManager.events[id].get("weight", 1.0))
		if roll <= 0.0:
			scheduled_event = id
			break
	if scheduled_event == "":
		scheduled_event = pool[pool.size() - 1]
	scheduled_time = rng.randf_range(float(DataManager.events_meta.get("start_time_min", 40.0)), float(DataManager.events_meta.get("start_time_max", 150.0)))


func _update_event(d: float) -> void:
	if not active_event.is_empty():
		event_left -= d
		if event_left <= 0.0:
			_end_event()
	elif scheduled_event != "" and elapsed >= scheduled_time:
		_start_event(scheduled_event)
		scheduled_event = ""


func _start_event(id: String) -> void:
	var ev: Dictionary = DataManager.get_event(id).duplicate(true)
	if ev.is_empty():
		return
	ev["id"] = id
	var eff: Dictionary = ev.get("effects", {})
	var mods := {}
	for k in eff.keys():
		mods[k] = eff[k]
	if eff.has("trend_mult"):
		# 현재 판매 중인 메뉴 중 하나가 유행
		var menus: Array = GameManager.state.enabled_menus()
		if menus.size() > 0:
			mods["trend_menu"] = menus[rng.randi() % menus.size()]
			ev["trend_name"] = DataManager.get_menu(mods["trend_menu"]).get("name", "")
	customer_manager.event_mods = mods
	active_event = ev
	event_left = float(ev.get("duration", 40.0))
	GameManager.economy.record_event(id)
	GameManager.state.event_history.append(id)
	while GameManager.state.event_history.size() > 5:
		GameManager.state.event_history.pop_front()
	event_started.emit(ev)


func _end_event() -> void:
	var ev := active_event
	active_event = {}
	customer_manager.event_mods = {}
	event_ended.emit(ev)


## 디버그: 즉시 이벤트 발생 (디버그 빌드 전용 UI 에서만 호출)
func debug_trigger_event(id: String) -> void:
	if phase == "open" and OS.is_debug_build():
		if not active_event.is_empty():
			_end_event()
		_start_event(id)
