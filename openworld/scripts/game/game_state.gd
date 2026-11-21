extends Node
## 게임 진행 상태 (자동 로드: GameState)
## 레벨/경험치/골드, 밝힌 봉화, 부활 위치를 관리하고 user://save.json 에 저장한다.

signal stats_changed
signal beacon_lit(index: int)
signal message(text: String)

const SAVE_PATH := "user://save.json"
const BEACON_COUNT := 7

var level := 1
var xp := 0
var gold := 0
var lit_beacons: Array = []
var defeated_guardians: Array = []
var spawn_position := Vector3.ZERO
var has_spawn := false
var last_position := Vector3.ZERO
var has_last_position := false


func xp_to_next() -> int:
	return 40 + (level - 1) * 35


func max_hp() -> float:
	return 100.0 + (level - 1) * 18.0


func max_stamina() -> float:
	return 100.0 + (level - 1) * 6.0


func attack_power() -> float:
	return 14.0 + (level - 1) * 3.5


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		message.emit("레벨 업!  Lv.%d" % level)
	stats_changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit()


func is_beacon_lit(index: int) -> bool:
	return lit_beacons.has(index)


func light_beacon(index: int, respawn_at: Vector3) -> void:
	if is_beacon_lit(index):
		return
	lit_beacons.append(index)
	spawn_position = respawn_at
	has_spawn = true
	beacon_lit.emit(index)
	if lit_beacons.size() >= BEACON_COUNT:
		message.emit("일곱 봉화가 모두 타오른다!  에버린에 빛이 돌아왔다.")
	else:
		message.emit("봉화가 타오른다  (%d / %d)" % [lit_beacons.size(), BEACON_COUNT])
	save_game()
	stats_changed.emit()


func mark_guardian_defeated(index: int) -> void:
	if not defeated_guardians.has(index):
		defeated_guardians.append(index)
		message.emit("봉화의 수호자를 쓰러뜨렸다!")


func save_game() -> void:
	var data := {
		"level": level,
		"xp": xp,
		"gold": gold,
		"beacons": lit_beacons,
		"guardians": defeated_guardians,
		"spawn": [spawn_position.x, spawn_position.y, spawn_position.z] if has_spawn else [],
		"pos": [last_position.x, last_position.y, last_position.z] if has_last_position else [],
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	gold = int(data.get("gold", 0))
	lit_beacons.clear()
	for v in data.get("beacons", []):
		lit_beacons.append(int(v))
	defeated_guardians.clear()
	for v in data.get("guardians", []):
		defeated_guardians.append(int(v))
	var s: Array = data.get("spawn", [])
	if s.size() == 3:
		spawn_position = Vector3(s[0], s[1], s[2])
		has_spawn = true
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		last_position = Vector3(p[0], p[1], p[2])
		has_last_position = true
