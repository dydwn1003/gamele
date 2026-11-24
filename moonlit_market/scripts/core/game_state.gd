extends RefCounted
## GameState
## 게임의 "실제 상태"만 담는 데이터 객체. 화면 상태가 아니라 복구 가능한 진행 정보.
## to_dict()/from_dict() 로 직렬화하며, from_dict 는 손상/누락 값을 정리(sanitize)한다.
##
## v3: 플레이어는 포장마차(pocha) 하나만 운영한다. 주변 노점은 경쟁 상대(rivals).

const SAVE_VERSION := 3
const DECO_SPOT_COUNT := 4

var coins: int = 0
var reputation: int = 0
var gems: int = 0 ## 프리미엄 재화 (TODO: 결제 연동 시 사용. 현재는 획득 경로 없음)
var market_level: int = 1
var day: int = 1
## 내 포장마차
## {"level", "rep", "staff": [emp_id], "menus": {menu_id: {"enabled", "price_ratio", "stock"}},
##  "stats": {"sold_total", "revenue_total", "last_sold", "last_revenue", "best_quality"}}
var pocha: Dictionary = {}
## 경쟁 노점 진행: rival_id -> {"rep": float, "sales_total": int, "last_sales": int}
var rivals: Dictionary = {}
## 상인 보유 현황: id -> {"hired": bool, "level": int}
var employees: Dictionary = {}
var decorations_owned: Array = []
var deco_spots: Array = []
## 해금 기록: "menu:dak_skewer" / "employee:emp_chef" / "decoration:bench" -> true
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
## 오늘의 목표 [{"id", "target"}] 와 생성된 날
var daily_goals: Array = []
var goals_day: int = 0
## 오늘 라이벌 대결 {"day", "rival"} (없으면 {})
var showdown: Dictionary = {}
var showdown_record: Dictionary = {"wins": 0, "losses": 0}
## 인플루언서 효과: 다음 영업 방문객 보너스
var next_visitor_bonus: float = 0.0


static func empty_offline() -> Dictionary:
	return {"pending_amount": 0, "pending_minutes": 0.0, "last_claim_unix": 0.0,
		"last_claim_amount": 0, "total_claimed": 0, "claim_count": 0, "clock_rollback_detected": false}


static func empty_lifetime() -> Dictionary:
	return {"customers": 0, "buyers": 0, "sales": 0, "revenue": 0, "sessions": 0, "perfect": 0, "burnt": 0}


static func empty_pocha() -> Dictionary:
	return {"level": 1, "rep": 10.0, "staff": [], "menus": {},
		"stats": {"sold_total": 0, "revenue_total": 0, "last_sold": 0, "last_revenue": 0, "best_quality": 0}}


static func make_menu_entry(enabled: bool, stock: int) -> Dictionary:
	return {"enabled": enabled, "price_ratio": 1.0, "stock": stock}


func reset_empty() -> void:
	coins = 0
	reputation = 0
	gems = 0
	market_level = 1
	day = 1
	pocha = empty_pocha()
	rivals = {}
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
	daily_goals = []
	goals_day = 0
	showdown = {}
	showdown_record = {"wins": 0, "losses": 0}
	next_visitor_bonus = 0.0


# ───────── 포차 조회 ─────────

func pocha_level() -> int:
	return int(pocha.get("level", 1))


func menu_entry(menu_id: String) -> Dictionary:
	var menus: Dictionary = pocha.get("menus", {})
	return menus.get(menu_id, {})


func has_menu(menu_id: String) -> bool:
	return (pocha.get("menus", {}) as Dictionary).has(menu_id)


func is_menu_enabled(menu_id: String) -> bool:
	return bool(menu_entry(menu_id).get("enabled", false))


func enabled_menus() -> Array:
	var out: Array = []
	var menus: Dictionary = pocha.get("menus", {})
	for id in menus.keys():
		if bool(menus[id].get("enabled", false)):
			out.append(str(id))
	out.sort()
	return out


func stock_of(menu_id: String) -> int:
	return int(menu_entry(menu_id).get("stock", 0))


func staff_list() -> Array:
	return pocha.get("staff", [])


func is_staff_active(emp_id: String) -> bool:
	return staff_list().has(emp_id)


# ───────── 직렬화 ─────────

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins, "reputation": reputation, "gems": gems,
		"market_level": market_level, "day": day,
		"pocha": pocha.duplicate(true),
		"rivals": rivals.duplicate(true),
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
		"daily_goals": daily_goals.duplicate(true),
		"goals_day": goals_day,
		"showdown": showdown.duplicate(),
		"showdown_record": showdown_record.duplicate(),
		"next_visitor_bonus": next_visitor_bonus,
	}


## 손상되었거나 이전 버전인 데이터를 정리해 적용한다. 검증 실패 시 false.
## data: DataManager (유효한 ID 확인용, null 이면 ID 검사 생략)
func from_dict(d: Dictionary, data = null) -> bool:
	if not d.has("coins") or not d.has("pocha"):
		return false
	reset_empty()
	coins = maxi(0, int(d.get("coins", 0)))
	reputation = maxi(0, int(d.get("reputation", 0)))
	gems = maxi(0, int(d.get("gems", 0)))
	market_level = clampi(int(d.get("market_level", 1)), 1, 99)
	day = maxi(1, int(d.get("day", 1)))
	var raw_emp = d.get("employees", {})
	if raw_emp is Dictionary:
		for id in raw_emp.keys():
			var e = raw_emp[id]
			if e is Dictionary and (data == null or data.employees.has(id)):
				employees[str(id)] = {"hired": bool(e.get("hired", false)), "level": clampi(int(e.get("level", 1)), 1, 5)}
	pocha = _sanitize_pocha(d.get("pocha", {}), data)
	var raw_rivals = d.get("rivals", {})
	if raw_rivals is Dictionary:
		for id in raw_rivals.keys():
			var r = raw_rivals[id]
			if r is Dictionary and (data == null or data.rivals.has(id)):
				rivals[str(id)] = {"rep": clampf(float(r.get("rep", 20.0)), 0.0, 100.0),
					"sales_total": maxi(0, int(r.get("sales_total", 0))), "last_sales": maxi(0, int(r.get("last_sales", 0)))}
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
	var dg = d.get("daily_goals", [])
	if dg is Array:
		for g in dg:
			if g is Dictionary and g.has("id"):
				daily_goals.append({"id": str(g["id"]), "target": maxi(0, int(g.get("target", 1)))})
	goals_day = maxi(0, int(d.get("goals_day", 0)))
	var sd = d.get("showdown", {})
	if sd is Dictionary and sd.has("rival") and (data == null or data.rivals.has(str(sd["rival"]))):
		showdown = {"day": int(sd.get("day", 0)), "rival": str(sd["rival"])}
	var sr = d.get("showdown_record", {})
	if sr is Dictionary:
		showdown_record = {"wins": maxi(0, int(sr.get("wins", 0))), "losses": maxi(0, int(sr.get("losses", 0)))}
	next_visitor_bonus = clampf(float(d.get("next_visitor_bonus", 0.0)), 0.0, 1.0)
	return true


func _sanitize_pocha(raw, data) -> Dictionary:
	var p := empty_pocha()
	if not (raw is Dictionary):
		return p
	var max_lv: int = 5 if data == null else data.max_stall_level()
	p["level"] = clampi(int(raw.get("level", 1)), 1, max_lv)
	p["rep"] = clampf(float(raw.get("rep", 10.0)), 0.0, 100.0)
	var stock_max: int = 999 if data == null else int(data.get_pocha_level(p["level"]).get("stock_max", 15))
	var raw_menus = raw.get("menus", {})
	if raw_menus is Dictionary:
		for id in raw_menus.keys():
			var m = raw_menus[id]
			if not (m is Dictionary):
				continue
			if data != null and not data.pocha_menu_ids().has(str(id)):
				continue
			p["menus"][str(id)] = {
				"enabled": bool(m.get("enabled", false)),
				"price_ratio": clampf(float(m.get("price_ratio", 1.0)), 0.8, 1.3),
				"stock": clampi(int(m.get("stock", 0)), 0, stock_max),
			}
	var raw_staff = raw.get("staff", [])
	var slots: int = 3 if data == null else int(data.get_pocha_level(p["level"]).get("staff_slots", 1))
	if raw_staff is Array:
		for id in raw_staff:
			var sid := str(id)
			if p["staff"].size() >= slots or p["staff"].has(sid):
				continue
			if employees.has(sid) and bool(employees[sid].get("hired", false)):
				p["staff"].append(sid)
	var st = raw.get("stats", {})
	if st is Dictionary:
		for k in p["stats"].keys():
			p["stats"][k] = maxi(0, int(st.get(k, 0)))
	return p
