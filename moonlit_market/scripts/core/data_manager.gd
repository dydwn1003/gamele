extends Node
## DataManager (Autoload)
## 모든 밸런스/콘텐츠 데이터를 JSON에서 읽어 온다. 코드에 수치를 하드코딩하지 않는다.
## 키가 누락되면 기본값으로 채우고, 파일이 깨졌으면 load_errors 에 기록한다.

const DATA_DIR := "res://data/"

var menus: Dictionary = {}
var stalls: Dictionary = {}
var stall_levels: Array = []
var customers: Dictionary = {}
var employees: Dictionary = {}
var employee_meta: Dictionary = {}
var facilities: Dictionary = {}
var decorations: Dictionary = {}
var weather: Dictionary = {}
var weather_meta: Dictionary = {}
var events: Dictionary = {}
var events_meta: Dictionary = {}
var pairings: Array = []
var pocha: Dictionary = {}
var pocha_levels: Array = []
var rivals: Dictionary = {}
var stages: Array = []
var balance: Dictionary = {}
var bm: Dictionary = {}
var load_errors: Array = []

# 키 누락 대비 기본값
const MENU_DEFAULTS := {
	"name": "메뉴", "category": "snack", "price": 100, "cost": 40, "cook_time": 6.0,
	"popularity": 0.5, "warm": false, "local_specialty": false,
	"preferred_customers": [], "color": "#FFB45C", "station": "rival", "icon": "",
	"perfect_end": 1.4, "burn": 1.9, "eat_time": 7.0, "alcohol": false, "unlock": {},
}
const POCHA_LEVEL_DEFAULTS := {
	"upgrade_cost": 0, "seats": 3, "burners": 2, "stock_max": 15, "staff_slots": 1, "appeal": 0.0, "tray": 2,
}
const RIVAL_DEFAULTS := {
	"name": "노점", "owner": "", "stall_type": "skewer", "menus": [], "price_ratio": 1.0,
	"quality": 70, "service_time": 5.0, "queue_capacity": 4, "reputation": 20,
	"appear_level": 1, "growth": {}, "desc": "",
}
const STALL_DEFAULTS := {
	"name": "노점", "kind": "food", "build_cost": 300, "menus": [], "default_menu": "",
	"menu_unlock_level": {}, "queue_capacity": 4, "base_reputation": 10,
	"color": "#E97858", "roof_color": "#B8443A", "sign": "노점", "unlock": {},
}
const LEVEL_DEFAULTS := {
	"upgrade_cost": 0, "cook_speed": 1.0, "stock_max": 20, "sales_efficiency": 1.0, "appeal": 0.0,
}
const CUSTOMER_DEFAULTS := {
	"name": "손님", "spawn_weight": 1.0, "budget_min": 100, "budget_max": 300,
	"spend_tendency": 0.6, "patience": 30.0, "speed": 110.0, "category_pref": {},
	"price_sensitivity": 1.0, "queue_sensitivity": 0.4, "popularity_affinity": 0.3,
	"reputation_sensitivity": 0.4, "prefers_warm": 0.0, "local_affinity": 0.0,
	"extra_purchase_chance": 0.2, "purposes": ["구경"], "names": ["손님"],
	"drink_chance": 0.6, "reorder_chance": 0.2, "no_alcohol": false, "eat_speed": 1.0,
	"color": "#B9B5B0", "accent": "#555555",
}
const EMPLOYEE_DEFAULTS := {
	"name": "상인", "role": "상인", "role_type": "basic", "desc": "", "effects": {},
	"special": {}, "unlock": {}, "hire_cost": 0, "starting": false, "color": "#E9C46A",
}
const BALANCE_DEFAULTS := {
	"start_coins": 500, "start_reputation": 0,
	"start_employee": "emp_basic", "session_duration": 240.0,
	"closing_grace": 12.0, "price_ratio_min": 0.8, "price_ratio_max": 1.3,
	"price_ratio_step": 0.05, "spawn_interval": 2.4, "max_customers": 34,
	"browse_time_min": 0.6, "browse_time_max": 1.8, "no_choice_weight": 0.35,
	"purchase_base_chance": 0.97, "purchase_price_penalty": 1.3,
	"satisfaction_base": 68.0, "satisfaction_wait_penalty": 0.9, "walkout_satisfaction": 15.0,
	"reputation_per_satisfaction": 0.015, "reputation_per_buyer": 0.1,
	"reputation_walkout_penalty": 0.3, "satisfaction_bonus_threshold": 70.0,
	"satisfaction_bonus_rate": 0.05, "spoilage_rate": 0.15,
	"tip_threshold": 80.0, "tip_rate": 0.12, "rival_eat_time": 6.0,
	"combo_tip_bonus": 0.05, "combo_max_bonus": 0.5,
	"offline_efficiency": 0.35, "offline_max_minutes": 240.0, "offline_min_minutes": 1.0,
	"autosave_interval": 30.0, "stall_reputation_max": 100.0, "debug_rewards_enabled": false,
}


func _init() -> void:
	load_all()


func load_all() -> bool:
	load_errors.clear()
	var d = _load_json("menus.json")
	menus = _index(d.get("menus", []), MENU_DEFAULTS)
	d = _load_json("stalls.json")
	stalls = _index(d.get("stalls", []), STALL_DEFAULTS)
	stall_levels = []
	for lv in d.get("levels", []):
		if lv is Dictionary:
			stall_levels.append(_with_defaults(lv, LEVEL_DEFAULTS))
	if stall_levels.is_empty():
		stall_levels.append(LEVEL_DEFAULTS.duplicate(true))
		load_errors.append("stalls.json: levels 누락 → 기본 레벨 사용")
	d = _load_json("customers.json")
	customers = _index(d.get("customers", []), CUSTOMER_DEFAULTS)
	d = _load_json("employees.json")
	employees = _index(d.get("employees", []), EMPLOYEE_DEFAULTS)
	employee_meta = {
		"max_level": int(d.get("max_level", 5)),
		"level_effect_growth": float(d.get("level_effect_growth", 0.25)),
		"level_up_costs": d.get("level_up_costs", [0, 300, 700, 1400, 2600]),
	}
	d = _load_json("decorations.json")
	facilities = _index(d.get("facilities", []), {"name": "시설", "build_cost": 500, "desc": "", "unlock": {}, "color": "#FFD27A", "tags": []})
	decorations = _index(d.get("decorations", []), {"name": "장식", "cost": 200, "desc": "", "effects": {}, "unlock": {}, "color": "#FFB45C"})
	d = _load_json("weather.json")
	weather = _index(d.get("weather", []), {"name": "흐림", "weight": 1.0, "visitor_mult": 1.0, "warm_mult": 1.0, "cold_mult": 1.0, "category_mult": {}, "is_bad": false, "desc": ""})
	weather_meta = {"max_consecutive_bad": int(d.get("max_consecutive_bad", 1))}
	d = _load_json("events.json")
	events = _index(d.get("events", []), {"name": "이벤트", "desc": "", "weight": 1.0, "duration": 40.0, "favorable": true, "effects": {}, "color": "#FFB45C"})
	events_meta = {
		"chance_per_session": float(d.get("chance_per_session", 0.6)),
		"start_time_min": float(d.get("start_time_min", 40.0)),
		"start_time_max": float(d.get("start_time_max", 150.0)),
	}
	d = _load_json("synergies.json")
	pairings = []
	for s in d.get("pairings", []):
		if s is Dictionary and s.has("id"):
			pairings.append(_with_defaults(s, {"name": "궁합", "desc": "", "a": "", "b": "", "effects": {}, "color": "#FFB45C"}))
	d = _load_json("pocha.json")
	pocha = d
	pocha_levels = []
	for lv in d.get("levels", []):
		if lv is Dictionary:
			pocha_levels.append(_with_defaults(lv, POCHA_LEVEL_DEFAULTS))
	if pocha_levels.is_empty():
		pocha_levels.append(POCHA_LEVEL_DEFAULTS.duplicate(true))
		load_errors.append("pocha.json: levels 누락 → 기본 레벨 사용")
	d = _load_json("rivals.json")
	rivals = _index(d.get("rivals", []), RIVAL_DEFAULTS)
	d = _load_json("progression.json")
	stages = []
	for st in d.get("stages", []):
		if st is Dictionary:
			stages.append(_with_defaults(st, {"level": stages.size() + 1, "name": "시장", "required_reputation": 0, "visitor_mult": 1.0, "max_stall_level": 5, "deco_spots": 2, "rivals": 3, "desc": ""}))
	if stages.is_empty():
		stages.append({"level": 1, "name": "작은 노점", "required_reputation": 0, "visitor_mult": 1.0, "max_stall_level": 5, "deco_spots": 2, "desc": ""})
		load_errors.append("progression.json: stages 누락 → 기본 단계 사용")
	balance = _with_defaults(_load_json("balance.json"), BALANCE_DEFAULTS)
	bm = _load_json("bm.json")
	if not load_errors.is_empty():
		for e in load_errors:
			push_warning("[DataManager] " + str(e))
	return load_errors.is_empty()


func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		load_errors.append("%s: 파일 없음" % file_name)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		load_errors.append("%s: JSON 파싱 오류 (줄 %d) %s" % [file_name, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		load_errors.append("%s: 최상위가 객체가 아님" % file_name)
		return {}
	return json.data


func _index(list, defaults: Dictionary) -> Dictionary:
	var out := {}
	if not (list is Array):
		return out
	for rec in list:
		if rec is Dictionary and rec.has("id"):
			out[str(rec["id"])] = _with_defaults(rec, defaults)
	return out


func _with_defaults(rec: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	for k in rec.keys():
		out[k] = rec[k]
	return out


# ───────── 조회 헬퍼 ─────────

func bal(key: String, default_value = null):
	return balance.get(key, default_value)


func get_menu(id: String) -> Dictionary:
	return menus.get(id, {})


func get_stall(id: String) -> Dictionary:
	return stalls.get(id, {})


func get_level(level: int) -> Dictionary:
	if stall_levels.is_empty():
		return LEVEL_DEFAULTS
	var idx := clampi(level - 1, 0, stall_levels.size() - 1)
	return stall_levels[idx]


func max_stall_level() -> int:
	return pocha_levels.size()


func get_pocha_level(level: int) -> Dictionary:
	var idx := clampi(level - 1, 0, pocha_levels.size() - 1)
	return pocha_levels[idx]


func get_rival(id: String) -> Dictionary:
	return rivals.get(id, {})


## 내 포차에서 팔 수 있는 메뉴 (station 이 grill/drink)
func pocha_menu_ids() -> Array:
	var out: Array = []
	for id in menus.keys():
		if str(menus[id].get("station", "rival")) in ["grill", "drink"]:
			out.append(id)
	return out


func get_customer_type(id: String) -> Dictionary:
	return customers.get(id, {})


func get_employee(id: String) -> Dictionary:
	return employees.get(id, {})


func get_facility(id: String) -> Dictionary:
	return facilities.get(id, {})


func get_decoration(id: String) -> Dictionary:
	return decorations.get(id, {})


func get_weather(id: String) -> Dictionary:
	if weather.has(id):
		return weather[id]
	if weather.has("cloudy"):
		return weather["cloudy"]
	return {"id": "cloudy", "name": "흐림", "visitor_mult": 1.0, "warm_mult": 1.0, "cold_mult": 1.0, "category_mult": {}, "is_bad": false, "desc": ""}


func get_event(id: String) -> Dictionary:
	return events.get(id, {})


func get_stage(level: int) -> Dictionary:
	var idx := clampi(level - 1, 0, stages.size() - 1)
	return stages[idx]


static func color(hex, fallback: Color = Color.WHITE) -> Color:
	if hex is String and Color.html_is_valid(hex):
		return Color.html(hex)
	return fallback
