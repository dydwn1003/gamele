extends RefCounted
## 퀘스트 데이터베이스
## type: talk(대화) / beacon(봉화 N개) / kill(처치) / collect(아이템 소지, 완료 시 회수) / chest(상자 열기)
## giver: 퀘스트를 주는 NPC,  turn_in: "auto" 면 조건 달성 즉시 완료, 아니면 그 NPC 에게 보고
## next: 완료되면 자동으로 이어서 받는 퀘스트

const Items = preload("res://scripts/game/items.gd")

const NPC_NAMES := {"elder": "촌장 하든", "merchant": "상인 미라", "smith": "대장장이 고르", "guard": "경비대장 브란"}

const QUESTS := {
	# ---------------------------------------------- 메인 퀘스트
	"main_1": {"title": "봉화지기의 부탁", "main": true, "giver": "elder", "turn_in": "elder",
		"type": "talk", "target": "elder", "count": 1,
		"desc": "새벽 마을의 촌장 하든이 카엘을 찾는다. 마을 우물가로 가보자.",
		"talk": "오, 떠돌이 기사여. 잘 와주었소. 일곱 봉화가 꺼진 뒤로 이 섬엔 괴물들이 들끓고 있소… 봉화를 다시 밝힐 수 있는 건 그대뿐이오. 부디 힘을 빌려주시오.",
		"rewards": {"xp": 30, "gold": 50, "items": {"potion_s": 3}}, "next": "main_2"},
	"main_2": {"title": "첫 번째 불씨", "main": true, "giver": "elder", "turn_in": "auto",
		"type": "beacon", "count": 1,
		"desc": "봉화 하나를 다시 밝히자. 봉화마다 바위 골렘 수호자가 지키고 있다. 레이더의 노란 점을 따라가자.",
		"rewards": {"xp": 120, "gold": 100, "items": {"potion_l": 2}}, "next": "main_3"},
	"main_3": {"title": "꺼지지 않는 불길", "main": true, "giver": "elder", "turn_in": "auto",
		"type": "beacon", "count": 3,
		"desc": "봉화 세 개를 밝히자. 수호자는 점점 강해진다. 대장간에서 장비를 갖추자.",
		"rewards": {"xp": 400, "gold": 300, "items": {"elixir": 1, "iron_ore": 5}}, "next": "main_4"},
	"main_4": {"title": "산 너머의 빛", "main": true, "giver": "elder", "turn_in": "auto",
		"type": "beacon", "count": 5,
		"desc": "봉화 다섯 개를 밝히자. 높은 산은 망토 활공으로 넘으면 빠르다.",
		"rewards": {"xp": 900, "gold": 600, "items": {"golem_core": 1, "elixir": 1}}, "next": "main_5"},
	"main_5": {"title": "일곱 번째 봉화", "main": true, "giver": "elder", "turn_in": "elder",
		"type": "beacon", "count": 7,
		"desc": "마지막 봉화까지 모두 밝히고 촌장에게 돌아가자.",
		"talk": "보시오, 섬 전체가 빛나고 있소! 에버린은 그대를 잊지 않을 것이오. 이 검은 봉화 기사단장이 남긴 것이오. 받아주시오.",
		"rewards": {"xp": 2000, "gold": 2000, "items": {"sword_dawn": 1}}},

	# ---------------------------------------------- 서브 퀘스트
	"side_goblin": {"title": "약탈자 소탕", "giver": "guard", "turn_in": "guard", "requires": "main_1",
		"type": "kill", "target": "goblin", "count": 6,
		"desc": "마을 주변을 어슬렁거리는 고블린 약탈자 6마리를 처치하자.",
		"offer": "고블린 놈들이 밤마다 창고를 털어간다. 여섯 놈만 혼내주면 보상을 두둑이 주지.",
		"rewards": {"xp": 90, "gold": 80, "items": {"potion_s": 2}}},
	"side_chief": {"title": "고블린 우두머리", "giver": "guard", "turn_in": "guard", "requires": "side_goblin",
		"type": "kill", "target": "goblin_chief", "count": 1,
		"desc": "고블린 야영지 어딘가에 있는 우두머리를 쓰러뜨리자. 지도에서 야영지를 찾아보자.",
		"offer": "놈들 뒤에는 덩치 큰 우두머리가 있다. 야영지를 찾아 그놈을 끝장내라.",
		"rewards": {"xp": 250, "gold": 200, "items": {"iron_ore": 4, "sword_iron": 1}}},
	"side_skeleton": {"title": "밤의 망자들", "giver": "guard", "turn_in": "guard", "requires": "main_2",
		"type": "kill", "target": "skeleton", "count": 5,
		"desc": "밤이 되면 들판에 해골 전사가 나타난다. 5마리를 처치하자.",
		"offer": "봉화가 꺼진 뒤로 밤마다 망자들이 일어난다. 해가 지면 놈들을 사냥해다오.",
		"rewards": {"xp": 300, "gold": 180, "items": {"stamina_potion": 3}}},
	"side_ogre": {"title": "산의 폭군", "giver": "guard", "turn_in": "guard", "requires": "main_3",
		"type": "kill", "target": "ogre", "count": 1,
		"desc": "높은 산 동굴에 산다는 오우거 족장을 쓰러뜨리자. 매우 강하다.",
		"offer": "산에 오우거 족장이 산다. 기사단 시절에도 함부로 못 건드린 놈이지… 자신 있나?",
		"rewards": {"xp": 800, "gold": 500, "items": {"ring_ember": 1}}},
	"side_wolf": {"title": "늑대 가죽 주문", "giver": "smith", "turn_in": "smith", "requires": "main_1",
		"type": "collect", "target": "wolf_pelt", "count": 5,
		"desc": "대장장이 고르가 늑대 가죽 5장을 원한다. 숲에서 늑대를 사냥하자.",
		"offer": "갑옷을 지으려는데 늑대 가죽이 모자라. 다섯 장만 구해다 주면 하나 만들어주지.",
		"rewards": {"xp": 80, "gold": 30, "items": {"armor_leather": 1}}},
	"side_ore": {"title": "광석 납품", "giver": "smith", "turn_in": "smith", "requires": "side_wolf",
		"type": "collect", "target": "iron_ore", "count": 6,
		"desc": "산기슭의 반짝이는 광석 바위에서 철광석 6개를 캐오자.",
		"offer": "좋은 검을 만들려면 철이 필요해. 산기슭 바위에서 반짝이는 광맥을 캐 와.",
		"rewards": {"xp": 200, "gold": 120, "items": {"sword_knight": 1}}},
	"side_herb": {"title": "약초 심부름", "giver": "merchant", "turn_in": "merchant", "requires": "main_1",
		"type": "collect", "target": "herb", "count": 6,
		"desc": "들판에 자라는 약초 6개를 채집해 상인 미라에게 가져가자.",
		"offer": "물약 재료가 똑 떨어졌어요. 들판에 핀 약초 여섯 송이만 따다 주실래요?",
		"rewards": {"xp": 60, "gold": 60, "items": {"potion_l": 2}}},
	"side_boar": {"title": "멧돼지 엄니", "giver": "merchant", "turn_in": "merchant", "requires": "side_herb",
		"type": "collect", "target": "boar_tusk", "count": 4,
		"desc": "멧돼지 엄니 4개를 구해 미라에게 가져가자. 멧돼지는 돌진하니 조심!",
		"offer": "멧돼지 엄니로 만든 장신구가 요즘 잘 팔려요. 네 개만 구해주시면 반지를 드릴게요.",
		"rewards": {"xp": 150, "gold": 100, "items": {"ring_copper": 1}}},
	"side_chest": {"title": "보물 사냥꾼", "giver": "elder", "turn_in": "elder", "requires": "main_2",
		"type": "chest", "count": 3,
		"desc": "섬 곳곳의 야영지와 폐허에 숨겨진 보물상자 3개를 열어보자.",
		"offer": "옛 기사단의 보급 상자들이 섬 곳곳에 흩어져 있다고 하오. 찾아보시겠소?",
		"rewards": {"xp": 300, "gold": 300, "items": {"elixir": 1}}},
}


static func get_quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})


static func rewards_text(id: String) -> String:
	var r: Dictionary = get_quest(id).get("rewards", {})
	var parts: PackedStringArray = []
	if r.has("xp"):
		parts.append("경험치 %d" % int(r["xp"]))
	if r.has("gold"):
		parts.append("%dG" % int(r["gold"]))
	var items: Dictionary = r.get("items", {})
	for k in items:
		parts.append("%s x%d" % [Items.item_name(k), int(items[k])])
	return ", ".join(parts)
