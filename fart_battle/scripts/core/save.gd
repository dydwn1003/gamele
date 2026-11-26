extends Node
## Save (Autoload) — 리그 진행(해금), 전적, 설정. user://fart_save.json (임시 파일 → 교체)

var unlocked: int = 1 ## 도전 가능한 상대 수
var wins: Dictionary = {} ## opponent_id -> 승리 횟수
var stats: Dictionary = {"farts": 0, "perfect": 0, "blunders": 0, "parries": 0, "matches": 0, "match_wins": 0}
var sound: bool = true
var vibration: bool = true
var tutorial_done: bool = false
var path: String = "user://fart_save.json"


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--test"):
		path = "user://fart_save_test.json"
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(path):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		push_warning("세이브 손상 — 새로 시작합니다.")
		return
	var d: Dictionary = j.data
	unlocked = clampi(int(d.get("unlocked", 1)), 1, 99)
	var w = d.get("wins", {})
	wins = w if w is Dictionary else {}
	var s = d.get("stats", {})
	if s is Dictionary:
		for k in stats.keys():
			stats[k] = maxi(0, int(s.get(k, 0)))
	sound = bool(d.get("sound", true))
	vibration = bool(d.get("vibration", true))
	tutorial_done = bool(d.get("tutorial_done", false))


func save_game() -> void:
	var d := {"version": 1, "unlocked": unlocked, "wins": wins, "stats": stats, "sound": sound,
		"vibration": vibration, "tutorial_done": tutorial_done}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func reset() -> void:
	unlocked = 1
	wins = {}
	for k in stats.keys():
		stats[k] = 0
	tutorial_done = false
	save_game()


## 리그 경기 결과 기록
func record_match(opp_index: int, opp_id: String, won: bool, match_stats: Dictionary) -> bool:
	stats["matches"] += 1
	for k in ["farts", "perfect", "blunders", "parries"]:
		stats[k] += int(match_stats.get(k, 0))
	var newly := false
	if won:
		stats["match_wins"] += 1
		wins[opp_id] = int(wins.get(opp_id, 0)) + 1
		if opp_index + 1 >= unlocked:
			unlocked = opp_index + 2
			newly = true
	save_game()
	return newly
