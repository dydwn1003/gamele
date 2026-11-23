extends RefCounted
## GameState
## 게임의 "실제 상태"만 담는 데이터 객체. 화면 상태가 아니라 복구 가능한 진행 정보.
## to_dict()/from_dict() 로 직렬화하며, from_dict 는 손상/누락 값을 정리(sanitize)한다.

const SAVE_VERSION := 2
const SLOT_COUNT := 6
const DECO_SPOT_COUNT := 4

var coins: int = 0
var reputation: int = 0
var gems: int = 0 ## 프리미엄 재화 (TODO: 결제 연동 시 사용. 현재는 획득 경로 없음)
var market_level: int = 1
var day: int = 1
## 슬롯 6개. 빈 슬롯 = {} / 노점 = {"kind":"stall",...} / 시설 = {"kind":"facility","type":...}
var slots: Array = []
## 상인 보유 현황: id -> {"hired": bool, "level": int}
var employees: Dictionary = {}
var decorations_owned: Array = []
var deco_spots: Array = []
## 해금 기록: "stall:skewer" / "employee:emp_chef" / "facility:stage" / "decoration:bench" -> true
var unlocked: Dictionary = {}
var settings: Dictionary = {"sound": true, "music": true, "vibration": true}
var last_seen_unix: float = 0.0
var max_seen_unix: float = 0.0
## 최근 정상 영업 통계 (오프라인 수익 기준)
var last_session: Dictionary = {}
## 영업 종료 후 아직 수령하지 않은 정산 결과 (앱이 꺼져도 유지)
var pending_result: Dictionary = {}
var settled_session_id: int = 0
var next_session_id: int = 1
var offline: Dictionary = {}
var lifetime: Dictionary = {}
var today_weather: String = "cloudy"
var weather_history: Array = []
var event_history: Array = []
var tutorial_done: bool = false


static func empty_offline() -> Dictionary:
	return {"pending_amount": 0, "pending_minutes": 0.0, "last_claim_unix": 0.0,
		"last_claim_amount": 0, "total_claimed": 0, "claim_count": 0, "clock_rollback_detected": false}


static func empty_lifetime() -> Dictionary:
	return {"customers": 0, "buyers": 0, "sales": 0, "revenue": 0, "sessions": 0}


static func make_stall(stall_type: String, menu_id: String, stock: int, base_rep: float) -> Dictionary:
	return {
		"kind": "stall", "type": stall_type, "level": 1, "menu": menu_id,
		"price_ratio": 1.0, "stock": stock, "employee": "", "rep": base_rep,
		"stats": {"sold_total": 0, "revenue_total": 0, "last_sold": 0, "last_revenue": 0},
	}


static func make_facility(facility_type: String) -> Dictionary:
	return {"kind": "facility", "type": facility_type}


func reset_empty() -> void:
	coins = 0
	reputation = 0
	gems = 0
	market_level = 1
	day = 1
	slots = []
	for i in SLOT_COUNT:
		slots.append({})
	employees = {}
	decorations_owned = []
	deco_spots = []
	for i in DECO_SPOT_COUNT:
		deco_spots.append("")
	unlocked = {}
	settings = {"sound": true, "music": true, "vibration": true}
	last_seen_unix = 0.0
	max_seen_unix = 0.0
	last_session = {}
	pending_result = {}
	settled_session_id = 0
	next_session_id = 1
	offline = empty_offline()
	lifetime = empty_lifetime()
	today_weather = "cloudy"
	weather_history = []
	event_history = []
	tutorial_done = false


func is_slot_empty(idx: int) -> bool:
	if idx < 0 or idx >= slots.size():
		return false
	return (slots[idx] as Dictionary).is_empty()


func get_slot(idx: int) -> Dictionary:
	if idx < 0 or idx >= slots.size():
		return {}
	return slots[idx]


func is_stall(idx: int) -> bool:
	return get_slot(idx).get("kind", "") == "stall"


func stall_count() -> int:
	var n := 0
	for s in slots:
		if (s as Dictionary).get("kind", "") == "stall":
			n += 1
	return n


func employee_slot(emp_id: String) -> int:
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.get("kind", "") == "stall" and s.get("employee", "") == emp_id:
			return i
	return -1


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins, "reputation": reputation, "gems": gems,
		"market_level": market_level, "day": day,
		"slots": slots.duplicate(true),
		"employees": employees.duplicate(true),
		"decorations_owned": decorations_owned.duplicate(),
		"deco_spots": deco_spots.duplicate(),
		"unlocked": unlocked.duplicate(),
		"settings": settings.duplicate(),
		"last_seen_unix": last_seen_unix, "max_seen_unix": max_seen_unix,
		"last_session": last_session.duplicate(true),
		"pending_result": pending_result.duplicate(true),
		"settled_session_id": settled_session_id, "next_session_id": next_session_id,
		"offline": offline.duplicate(true),
		"lifetime": lifetime.duplicate(true),
		"today_weather": today_weather,
		"weather_history": weather_history.duplicate(),
		"event_history": event_history.duplicate(),
		"tutorial_done": tutorial_done,
	}


## 손상되었거나 이전 버전인 데이터를 정리해 적용한다. 검증 실패 시 false.
## data: DataManager (유효한 ID 확인용, null 이면 ID 검사 생략)
func from_dict(d: Dictionary, data = null) -> bool:
	if not d.has("coins") or not d.has("slots"):
		return false
	reset_empty()
	coins = maxi(0, int(d.get("coins", 0)))
	reputation = maxi(0, int(d.get("reputation", 0)))
	gems = maxi(0, int(d.get("gems", 0)))
	market_level = clampi(int(d.get("market_level", 1)), 1, 99)
	day = maxi(1, int(d.get("day", 1)))
	var raw_slots = d.get("slots", [])
	if raw_slots is Array:
		for i in mini(raw_slots.size(), SLOT_COUNT):
			slots[i] = _sanitize_slot(raw_slots[i], data)
	var raw_emp = d.get("employees", {})
	if raw_emp is Dictionary:
		for id in raw_emp.keys():
			var e = raw_emp[id]
			if e is Dictionary and (data == null or data.employees.has(id)):
				employees[str(id)] = {"hired": bool(e.get("hired", false)), "level": clampi(int(e.get("level", 1)), 1, 5)}
	# 상인 중복 배치 정리
	var seen := {}
	for s in slots:
		if (s as Dictionary).get("kind", "") == "stall":
			var emp: String = s.get("employee", "")
			if emp != "" and (seen.has(emp) or not employees.has(emp) or not employees[emp]["hired"]):
				s["employee"] = ""
			elif emp != "":
				seen[emp] = true
	var raw_owned = d.get("decorations_owned", [])
	if raw_owned is Array:
		for id in raw_owned:
			if data == null or data.decorations.has(str(id)):
				if not decorations_owned.has(str(id)):
					decorations_owned.append(str(id))
	var raw_spots = d.get("deco_spots", [])
	if raw_spots is Array:
		for i in mini(raw_spots.size(), DECO_SPOT_COUNT):
			var id := str(raw_spots[i])
			deco_spots[i] = id if decorations_owned.has(id) else ""
	var raw_unlocked = d.get("unlocked", {})
	if raw_unlocked is Dictionary:
		for k in raw_unlocked.keys():
			unlocked[str(k)] = bool(raw_unlocked[k])
	var raw_settings = d.get("settings", {})
	if raw_settings is Dictionary:
		for k in ["sound", "music", "vibration"]:
			settings[k] = bool(raw_settings.get(k, true))
	last_seen_unix = maxf(0.0, float(d.get("last_seen_unix", 0.0)))
	max_seen_unix = maxf(last_seen_unix, float(d.get("max_seen_unix", 0.0)))
	var ls = d.get("last_session", {})
	last_session = ls if ls is Dictionary else {}
	var pr = d.get("pending_result", {})
	pending_result = pr if pr is Dictionary else {}
	settled_session_id = maxi(0, int(d.get("settled_session_id", 0)))
	next_session_id = maxi(settled_session_id + 1, int(d.get("next_session_id", 1)))
	var off = d.get("offline", {})
	offline = empty_offline()
	if off is Dictionary:
		offline["pending_amount"] = maxi(0, int(off.get("pending_amount", 0)))
		offline["pending_minutes"] = maxf(0.0, float(off.get("pending_minutes", 0.0)))
		offline["last_claim_unix"] = float(off.get("last_claim_unix", 0.0))
		offline["last_claim_amount"] = maxi(0, int(off.get("last_claim_amount", 0)))
		offline["total_claimed"] = maxi(0, int(off.get("total_claimed", 0)))
		offline["claim_count"] = maxi(0, int(off.get("claim_count", 0)))
		offline["clock_rollback_detected"] = bool(off.get("clock_rollback_detected", false))
	var lt = d.get("lifetime", {})
	lifetime = empty_lifetime()
	if lt is Dictionary:
		for k in lifetime.keys():
			lifetime[k] = maxi(0, int(lt.get(k, 0)))
	today_weather = str(d.get("today_weather", "cloudy"))
	if data != null and not data.weather.has(today_weather):
		today_weather = "cloudy"
	var wh = d.get("weather_history", [])
	weather_history = wh if wh is Array else []
	var eh = d.get("event_history", [])
	event_history = eh if eh is Array else []
	tutorial_done = bool(d.get("tutorial_done", false))
	return true


func _sanitize_slot(raw, data) -> Dictionary:
	if not (raw is Dictionary) or raw.is_empty():
		return {}
	var kind := str(raw.get("kind", ""))
	var t := str(raw.get("type", ""))
	if kind == "facility":
		if data != null and not data.facilities.has(t):
			return {}
		return make_facility(t)
	if kind != "stall":
		return {}
	if data != null and not data.stalls.has(t):
		return {}
	var s := make_stall(t, str(raw.get("menu", "")), maxi(0, int(raw.get("stock", 0))), float(raw.get("rep", 10.0)))
	s["level"] = clampi(int(raw.get("level", 1)), 1, 5)
	s["price_ratio"] = clampf(float(raw.get("price_ratio", 1.0)), 0.8, 1.3)
	s["employee"] = str(raw.get("employee", ""))
	s["rep"] = clampf(float(raw.get("rep", 10.0)), 0.0, 100.0)
	var st = raw.get("stats", {})
	if st is Dictionary:
		for k in s["stats"].keys():
			s["stats"][k] = maxi(0, int(st.get(k, 0)))
	if data != null:
		var def: Dictionary = data.get_stall(t)
		var menus: Array = def.get("menus", [])
		if not menus.has(s["menu"]):
			s["menu"] = def.get("default_menu", menus[0] if menus.size() > 0 else "")
		var max_stock := int(data.get_level(s["level"]).get("stock_max", 20))
		s["stock"] = mini(s["stock"], max_stock)
	return s
