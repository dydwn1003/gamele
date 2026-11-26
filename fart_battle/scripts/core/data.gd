extends Node
## Data (Autoload) — JSON 데이터 로딩. 키가 없으면 기본값을 쓴다.

var balance: Dictionary = {}
var player: Dictionary = {}
var opponents: Array = []
var foods: Array = []

const BALANCE_DEFAULTS := {
	"round_time": 40.0, "rounds_to_win": 2, "gas_max": 100.0, "gas_start": 70.0, "gas_cost_full": 45.0,
	"min_release": 0.12, "pressure_fill_time": 1.25, "sweet_min": 0.72, "sweet_width": 0.16,
	"overcharge_grace": 0.35, "perfect_mult": 1.6, "push_strength": 0.62, "cloud_friction": 2.4,
	"cloud_max_speed": 1.6, "blunder_stun": 1.5, "blunder_backfire": 0.28, "block_duration": 0.8,
	"block_cooldown": 3.0, "block_reduce": 0.75, "parry_window": 0.3, "parry_reflect": 0.45,
	"stink_push": 0.09, "food_interval_min": 4.0, "food_interval_max": 6.5, "food_lifetime": 4.0,
	"milk_bad_chance": 0.5, "milk_stun": 1.0, "knockout_stun": 1.8,
}
const FIGHTER_DEFAULTS := {
	"name": "방귀러", "title": "", "power": 1.0, "control": 1.0, "gas_regen": 9.0, "stink": 0.0,
	"ai_reaction": 0.5, "ai_accuracy": 0.15, "ai_aggression": 0.5, "ai_block": 0.3, "ai_greed": 0.5,
	"species": "mole", "body": "#6B5A70", "belly": "#C9A0B8", "beam": ["#FF5FD2", "#5FE8FF"], "lines": {},
}


func _init() -> void:
	load_all()


func load_all() -> void:
	var b := _load("res://data/balance.json")
	balance = BALANCE_DEFAULTS.duplicate()
	for k in b.keys():
		balance[k] = b[k]
	var f := _load("res://data/fighters.json")
	player = _with(f.get("player", {}), FIGHTER_DEFAULTS)
	opponents = []
	for o in f.get("opponents", []):
		if o is Dictionary and o.has("id"):
			opponents.append(_with(o, FIGHTER_DEFAULTS))
	var fd := _load("res://data/foods.json")
	foods = []
	for x in fd.get("foods", []):
		if x is Dictionary and x.has("id"):
			foods.append(_with(x, {"name": "음식", "desc": "", "weight": 1.0, "effect": "gas", "value": 30, "count": 1, "color": "#FFB45C", "inner": "#FFF5E9"}))


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("데이터 파일 없음: " + path)
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		push_warning("데이터 파싱 실패: " + path)
		return {}
	return j.data


func _with(rec: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	for k in rec.keys():
		out[k] = rec[k]
	return out


func food(id: String) -> Dictionary:
	for f in foods:
		if f["id"] == id:
			return f
	return {}


func opponent(i: int) -> Dictionary:
	return opponents[clampi(i, 0, opponents.size() - 1)] if opponents.size() > 0 else FIGHTER_DEFAULTS.duplicate()


static func color(hex, fallback: Color = Color.WHITE) -> Color:
	if hex is String and Color.html_is_valid(hex):
		return Color.html(hex)
	return fallback
