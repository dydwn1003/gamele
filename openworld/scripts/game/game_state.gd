extends Node
## 게임 진행 상태 (자동 로드: GameState)
## 레벨·골드·인벤토리·장비·강화·퀘스트·봉화·상자 기록을 관리하고 user://save.json 에 저장한다.

signal stats_changed
signal inventory_changed
signal equipment_changed
signal quests_changed
signal beacon_lit(index: int)
signal message(text: String)
signal banner(title: String, subtitle: String)
signal item_gained(id: String, count: int)

const Items = preload("res://scripts/game/items.gd")
const Quests = preload("res://scripts/game/quests.gd")

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const BEACON_COUNT := 7
const SAVE_VERSION := 2

# 진행
var level := 1
var xp := 0
var gold := 0
var lit_beacons: Array = []
var defeated_guardians: Array = []
var opened_chests: Array = []
var discovered: Array = []  # 발견한 야영지 id
var kills := {}
var spawn_position := Vector3.ZERO
var has_spawn := false
var last_position := Vector3.ZERO
var has_last_position := false
var time_of_day := 0.3

# 아이템
var inventory := {}  # id -> 개수
var equipment := {"weapon": "sword_rusty", "armor": "armor_cloth", "accessory": ""}
var enhance := {}  # 장비 id -> 강화 단계

# 퀘스트: id -> {"state": "active"/"ready"/"done", "progress": int}
var quests := {}
var tracked_quest := ""

# 일시 효과 (저장 안 함): 이름 -> 남은 초
var buffs := {}

# 설정
var settings := {"sensitivity": 1.0, "view": 1, "shadows": true, "music": 0.7, "sfx": 0.9, "show_fps": false}

## 타이틀 화면을 건너뛰고 바로 시작할지 (새 게임 / 불러오기 직후)
var skip_title := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_settings()


func _process(delta: float) -> void:
	for k in buffs.keys():
		buffs[k] = float(buffs[k]) - delta
		if buffs[k] <= 0.0:
			buffs.erase(k)
			stats_changed.emit()


# ------------------------------------------------------------------ 능력치

func equip_stat(key: String) -> float:
	var total := 0.0
	for slot in equipment:
		var id: String = equipment[slot]
		if id == "":
			continue
		var st := Items.stats_of(id, int(enhance.get(id, 0)))
		total += float(st.get(key, 0.0))
	return total


func xp_to_next() -> int:
	return 40 + (level - 1) * 35


func max_hp() -> float:
	return 100.0 + (level - 1) * 18.0 + equip_stat("hp")


func max_stamina() -> float:
	return 100.0 + (level - 1) * 4.0 + equip_stat("stamina")


func attack_power() -> float:
	var a := 14.0 + (level - 1) * 3.0 + equip_stat("atk")
	if buffs.has("atk"):
		a *= 1.3
	return a


func defense() -> float:
	return (level - 1) * 1.0 + equip_stat("def")


func crit_chance() -> float:
	return 0.08 + equip_stat("crit")


## 방어력으로 줄어든 피해량
func reduce_damage(amount: float) -> float:
	return amount * 100.0 / (100.0 + defense() * 2.0)


func add_xp(amount: int) -> void:
	xp += amount
	var leveled := false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		leveled = true
	if leveled:
		banner.emit("레벨 업!", "Lv.%d 에 도달했다" % level)
		Sfx.play("levelup")
	stats_changed.emit()


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	stats_changed.emit()


# ------------------------------------------------------------------ 인벤토리

func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n := 1, announce := true) -> void:
	if n <= 0 or Items.get_item(id).is_empty():
		return
	inventory[id] = count(id) + n
	if announce:
		item_gained.emit(id, n)
	inventory_changed.emit()
	_update_collect_quests()


func remove_item(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	_update_collect_quests()
	return true


func is_equipped(id: String) -> bool:
	return equipment.values().has(id)


func equip(id: String) -> void:
	var t: String = Items.get_item(id).get("type", "")
	if not equipment.has(t) or count(id) <= 0:
		return
	var old: String = equipment[t]
	if old != "":
		inventory[old] = count(old) + 1
	remove_item(id, 1)
	equipment[t] = id
	Sfx.play("equip")
	equipment_changed.emit()
	stats_changed.emit()


func unequip(slot: String) -> void:
	var old: String = equipment.get(slot, "")
	if old == "" or slot == "weapon":
		return  # 무기는 항상 하나 들고 있어야 한다
	equipment[slot] = ""
	add_item(old, 1, false)
	equipment_changed.emit()
	stats_changed.emit()


## 소비 아이템 사용. 결과 메시지를 돌려준다 (실패 시 빈 문자열)
func use_item(id: String, player) -> String:
	var it := Items.get_item(id)
	if it.get("type", "") != "consumable" or count(id) <= 0 or player == null or player.dead:
		return ""
	if it.has("heal") and player.hp >= max_hp() and not it.has("atk_buff") and not it.has("stamina_buff"):
		return ""
	remove_item(id, 1)
	if it.has("heal"):
		player.hp = minf(max_hp(), player.hp + float(it["heal"]))
	if it.has("stamina_buff"):
		player.stamina = max_stamina()
		buffs["stamina"] = float(it["stamina_buff"])
	if it.has("atk_buff"):
		buffs["atk"] = float(it["atk_buff"])
	Sfx.play("potion")
	stats_changed.emit()
	return "%s 사용" % it["name"]


## 가장 알맞은 회복 아이템을 자동으로 고른다 (빠른 사용 버튼용)
func best_heal_item(missing: float) -> String:
	var best := ""
	var best_waste := 1e9
	for id in ["roast_meat", "potion_s", "potion_l", "elixir"]:
		if count(id) <= 0:
			continue
		var heal := float(Items.get_item(id).get("heal", 0))
		var waste := absf(heal - missing)
		if waste < best_waste:
			best_waste = waste
			best = id
	return best


func heal_item_total() -> int:
	return count("roast_meat") + count("potion_s") + count("potion_l") + count("elixir")


# ------------------------------------------------------------------ 상점 / 제작 / 강화

func buy(id: String) -> bool:
	var price := int(Items.get_item(id).get("price", 0))
	if gold < price:
		return false
	add_gold(-price)
	add_item(id, 1, false)
	Sfx.play("coin")
	return true


func sell_price(id: String) -> int:
	return maxi(1, int(Items.get_item(id).get("price", 0)) / 2)


func sell(id: String) -> bool:
	if not remove_item(id, 1):
		return false
	add_gold(sell_price(id))
	Sfx.play("coin")
	return true


func can_craft(recipe: Dictionary) -> bool:
	if gold < int(recipe["gold"]):
		return false
	var mats: Dictionary = recipe["mats"]
	for m in mats:
		if count(m) < int(mats[m]):
			return false
	return true


func craft(recipe: Dictionary) -> bool:
	if not can_craft(recipe):
		return false
	var mats: Dictionary = recipe["mats"]
	for m in mats:
		remove_item(m, int(mats[m]))
	add_gold(-int(recipe["gold"]))
	add_item(recipe["item"], int(recipe["count"]), false)
	Sfx.play("anvil")
	return true


func enhance_level(id: String) -> int:
	return int(enhance.get(id, 0))


func can_enhance(id: String) -> bool:
	var lv := enhance_level(id)
	if lv >= Items.MAX_ENHANCE:
		return false
	var cost := Items.enhance_cost(id, lv)
	return gold >= int(cost["gold"]) and count("iron_ore") >= int(cost["iron_ore"])


func do_enhance(id: String) -> bool:
	if not can_enhance(id):
		return false
	var cost := Items.enhance_cost(id, enhance_level(id))
	add_gold(-int(cost["gold"]))
	remove_item("iron_ore", int(cost["iron_ore"]))
	enhance[id] = enhance_level(id) + 1
	Sfx.play("anvil")
	equipment_changed.emit()
	stats_changed.emit()
	return true


# ------------------------------------------------------------------ 퀘스트

func quest_state(id: String) -> String:
	if quests.has(id):
		return quests[id]["state"]
	var q := Quests.get_quest(id)
	if q.is_empty():
		return ""
	var req: String = q.get("requires", "")
	if req == "" or quest_state(req) == "done":
		return "available"
	return "locked"


func quest_progress(id: String) -> int:
	var q := Quests.get_quest(id)
	match q.get("type", ""):
		"beacon":
			return lit_beacons.size()
		"collect":
			return count(q["target"])
		"chest":
			return int(quests.get(id, {}).get("progress", 0))
	return int(quests.get(id, {}).get("progress", 0))


func accept_quest(id: String) -> void:
	if quests.has(id):
		return
	quests[id] = {"state": "active", "progress": 0}
	tracked_quest = id
	banner.emit("새 퀘스트", Quests.get_quest(id)["title"])
	Sfx.play("quest")
	_check_quest(id)
	quests_changed.emit()


func _check_quest(id: String) -> void:
	if not quests.has(id) or quests[id]["state"] == "done":
		return
	var q := Quests.get_quest(id)
	var done := quest_progress(id) >= int(q["count"])
	if done and quests[id]["state"] == "active":
		quests[id]["state"] = "ready"
		if q["turn_in"] == "auto":
			complete_quest(id)
		else:
			message.emit("퀘스트 목표 달성: %s  (%s에게 보고)" % [q["title"], Quests.NPC_NAMES.get(q["turn_in"], "")])
			Sfx.play("quest")
	elif not done and quests[id]["state"] == "ready":
		quests[id]["state"] = "active"  # 수집품을 팔거나 써버린 경우
	quests_changed.emit()


func complete_quest(id: String) -> void:
	var q := Quests.get_quest(id)
	if q["type"] == "collect":
		remove_item(q["target"], int(q["count"]))
	quests[id]["state"] = "done"
	var r: Dictionary = q.get("rewards", {})
	var items: Dictionary = r.get("items", {})
	for k in items:
		add_item(k, int(items[k]))
	add_gold(int(r.get("gold", 0)))
	banner.emit("퀘스트 완료!", q["title"])
	Sfx.play("quest_done")
	add_xp(int(r.get("xp", 0)))
	if tracked_quest == id:
		tracked_quest = ""
	var nxt: String = q.get("next", "")
	if nxt != "":
		accept_quest(nxt)
	if tracked_quest == "":
		tracked_quest = _first_active()
	quests_changed.emit()
	save_game()


func _first_active() -> String:
	for id in quests:
		if quests[id]["state"] != "done":
			return id
	return ""


## 처치/대화/상자 같은 사건을 퀘스트에 알린다
func notify(event: String, target := "") -> void:
	if event == "kill":
		kills[target] = int(kills.get(target, 0)) + 1
	for id in quests.keys():
		if quests[id]["state"] != "active":
			continue
		var q := Quests.get_quest(id)
		var hit := false
		match q["type"]:
			"kill":
				hit = event == "kill" and q["target"] == target
			"talk":
				hit = event == "talk" and q["target"] == target
			"chest":
				hit = event == "chest"
		if hit:
			quests[id]["progress"] = int(quests[id]["progress"]) + 1
		_check_quest(id)


func _update_collect_quests() -> void:
	for id in quests.keys():
		if Quests.get_quest(id).get("type", "") == "collect":
			_check_quest(id)


## NPC 머리 위 표시: "!" (줄 퀘스트 있음) / "?" (보고할 퀘스트 있음) / ""
func npc_marker(npc: String) -> String:
	for id in Quests.QUESTS:
		var q: Dictionary = Quests.QUESTS[id]
		if q.get("turn_in", "") == npc and quest_state(id) == "ready":
			return "?"
	for id in Quests.QUESTS:
		var q: Dictionary = Quests.QUESTS[id]
		if q.get("giver", "") == npc and quest_state(id) == "available" and not q.get("main", false):
			return "!"
	return ""


# ------------------------------------------------------------------ 봉화 / 상자

func is_beacon_lit(index: int) -> bool:
	return lit_beacons.has(index)


func light_beacon(index: int, respawn_at: Vector3) -> void:
	if is_beacon_lit(index):
		return
	lit_beacons.append(index)
	spawn_position = respawn_at
	has_spawn = true
	beacon_lit.emit(index)
	banner.emit("봉화가 타오른다", "%d / %d" % [lit_beacons.size(), BEACON_COUNT])
	Sfx.play("beacon")
	for id in quests.keys():
		_check_quest(id)
	save_game()
	stats_changed.emit()


func mark_guardian_defeated(index: int) -> void:
	if not defeated_guardians.has(index):
		defeated_guardians.append(index)
		message.emit("봉화의 수호자를 쓰러뜨렸다! 봉화에 불을 붙이자")


func open_chest(id: String) -> void:
	if opened_chests.has(id):
		return
	opened_chests.append(id)
	notify("chest")
	save_game()


func discover(id: String, name: String) -> void:
	if discovered.has(id):
		return
	discovered.append(id)
	banner.emit("새로운 장소 발견", name)


# ------------------------------------------------------------------ 저장 / 불러오기

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset() -> void:
	level = 1
	xp = 0
	gold = 0
	lit_beacons = []
	defeated_guardians = []
	opened_chests = []
	discovered = []
	kills = {}
	has_spawn = false
	has_last_position = false
	time_of_day = 0.3
	inventory = {"potion_s": 2}
	equipment = {"weapon": "sword_rusty", "armor": "armor_cloth", "accessory": ""}
	enhance = {}
	quests = {}
	tracked_quest = ""
	buffs = {}


func new_game() -> void:
	reset()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	accept_quest("main_1")


func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"level": level, "xp": xp, "gold": gold,
		"beacons": lit_beacons, "guardians": defeated_guardians,
		"chests": opened_chests, "discovered": discovered, "kills": kills,
		"spawn": _v3(spawn_position) if has_spawn else [],
		"pos": _v3(last_position) if has_last_position else [],
		"time": time_of_day,
		"inventory": inventory, "equipment": equipment, "enhance": enhance,
		"quests": quests, "tracked": tracked_quest,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or int(data.get("version", 1)) < SAVE_VERSION:
		return false
	reset()
	inventory = {}
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	gold = int(data.get("gold", 0))
	for v in data.get("beacons", []):
		lit_beacons.append(int(v))
	for v in data.get("guardians", []):
		defeated_guardians.append(int(v))
	for v in data.get("chests", []):
		opened_chests.append(String(v))
	for v in data.get("discovered", []):
		discovered.append(String(v))
	var k: Dictionary = data.get("kills", {})
	for key in k:
		kills[key] = int(k[key])
	var s: Array = data.get("spawn", [])
	if s.size() == 3:
		spawn_position = Vector3(s[0], s[1], s[2])
		has_spawn = true
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		last_position = Vector3(p[0], p[1], p[2])
		has_last_position = true
	time_of_day = float(data.get("time", 0.3))
	var inv: Dictionary = data.get("inventory", {})
	for key in inv:
		inventory[key] = int(inv[key])
	var eq: Dictionary = data.get("equipment", {})
	for slot in equipment:
		equipment[slot] = String(eq.get(slot, equipment[slot]))
	var en: Dictionary = data.get("enhance", {})
	for key in en:
		enhance[key] = int(en[key])
	var qs: Dictionary = data.get("quests", {})
	for key in qs:
		quests[key] = {"state": String(qs[key].get("state", "active")), "progress": int(qs[key].get("progress", 0))}
	tracked_quest = String(data.get("tracked", ""))
	return true


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if data is Dictionary:
		for k in data:
			settings[k] = data[k]
