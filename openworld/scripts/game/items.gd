extends RefCounted
## 아이템 데이터베이스 (소비 / 재료 / 무기 / 방어구 / 장신구) + 제작 레시피 + 상점 목록

const RARITY_NAMES := ["일반", "고급", "희귀", "영웅", "전설"]
## 스타일 가이드 등급색 (art/concept/style_guide.png)
const RARITY_COLORS := [
	Color("#9AA0A6"), Color("#34A853"), Color("#4285F4"), Color("#B04CC8"), Color("#FF8F00")]

const TYPE_NAMES := {
	"consumable": "소비", "material": "재료", "weapon": "무기", "armor": "방어구", "accessory": "장신구"}

## stats: atk(공격력) def(방어력) hp(최대 체력) crit(치명타 확률) stamina(최대 기력)
## 무기의 blade: 칼날 색 / len: 칼날 길이,  방어구의 tint: 튜닉·망토 색 / plate: 판금 여부
const ITEMS := {
	# ---------------- 소비 아이템
	"potion_s": {"name": "체력 물약", "type": "consumable", "rarity": 0, "price": 20,
		"heal": 60, "icon": "potion", "color": Color(0.9, 0.2, 0.25),
		"desc": "붉은 약초를 달인 물약. 체력을 60 회복한다."},
	"potion_l": {"name": "큰 체력 물약", "type": "consumable", "rarity": 1, "price": 65,
		"heal": 180, "icon": "potion", "color": Color(1.0, 0.35, 0.5),
		"desc": "진하게 달인 물약. 체력을 180 회복한다."},
	"stamina_potion": {"name": "기력 물약", "type": "consumable", "rarity": 1, "price": 35,
		"stamina_buff": 20.0, "icon": "potion", "color": Color(0.95, 0.8, 0.2),
		"desc": "기력을 모두 채우고 20초 동안 기력이 줄지 않는다."},
	"roast_meat": {"name": "구운 고기", "type": "consumable", "rarity": 0, "price": 12,
		"heal": 35, "icon": "meat", "color": Color(0.7, 0.35, 0.2),
		"desc": "모닥불에 구운 고기. 체력을 35 회복한다."},
	"elixir": {"name": "용기의 영약", "type": "consumable", "rarity": 2, "price": 150,
		"heal": 9999, "atk_buff": 45.0, "icon": "potion", "color": Color(0.6, 0.4, 1.0),
		"desc": "체력을 모두 회복하고 45초 동안 공격력이 30% 오른다."},

	# ---------------- 재료
	"goblin_ear": {"name": "고블린 귀", "type": "material", "rarity": 0, "price": 6, "icon": "ear",
		"color": Color(0.45, 0.65, 0.28), "desc": "고블린을 처치한 증표. 경비대가 반긴다."},
	"wolf_pelt": {"name": "늑대 가죽", "type": "material", "rarity": 0, "price": 10, "icon": "pelt",
		"color": Color(0.55, 0.55, 0.58), "desc": "질기고 따뜻한 회색 가죽. 가죽 장비의 재료."},
	"raw_meat": {"name": "날고기", "type": "material", "rarity": 0, "price": 4, "icon": "meat",
		"color": Color(0.85, 0.4, 0.4), "desc": "대장간 화덕에서 구우면 먹을 수 있다."},
	"boar_tusk": {"name": "멧돼지 엄니", "type": "material", "rarity": 1, "price": 14, "icon": "tusk",
		"color": Color(0.95, 0.92, 0.8), "desc": "단단하고 휘어진 엄니. 장신구 재료."},
	"bone_dust": {"name": "뼛가루", "type": "material", "rarity": 0, "price": 8, "icon": "bone",
		"color": Color(0.9, 0.88, 0.82), "desc": "망자의 뼈가 부서진 가루. 연금술 재료."},
	"herb": {"name": "약초", "type": "material", "rarity": 0, "price": 5, "icon": "herb",
		"color": Color(0.35, 0.75, 0.3), "desc": "들판에서 자라는 약초. 물약의 재료."},
	"iron_ore": {"name": "철광석", "type": "material", "rarity": 1, "price": 12, "icon": "ore",
		"color": Color(0.55, 0.5, 0.5), "desc": "산의 바위에서 캐낸 광석. 무기·갑옷·강화의 재료."},
	"golem_core": {"name": "골렘 핵", "type": "material", "rarity": 2, "price": 80, "icon": "core",
		"color": Color(0.4, 0.95, 1.0), "desc": "수호자의 가슴에서 빛나던 룬석. 강력한 장비의 재료."},
	"ogre_horn": {"name": "오우거 뿔", "type": "material", "rarity": 2, "price": 60, "icon": "horn",
		"color": Color(0.75, 0.6, 0.45), "desc": "오우거 족장의 부러진 뿔."},

	# ---------------- 무기
	"sword_rusty": {"name": "낡은 장검", "type": "weapon", "rarity": 0, "price": 10, "icon": "sword",
		"stats": {"atk": 0}, "blade": Color(0.7, 0.68, 0.66), "len": 0.85,
		"desc": "카엘이 오래 써온 검. 이가 조금 빠졌다."},
	"sword_iron": {"name": "강철 장검", "type": "weapon", "rarity": 1, "price": 160, "icon": "sword",
		"stats": {"atk": 8}, "blade": Color(0.82, 0.85, 0.9), "len": 0.9,
		"desc": "마을 대장간에서 벼린 튼튼한 검."},
	"sword_knight": {"name": "기사단 장검", "type": "weapon", "rarity": 2, "price": 420, "icon": "sword",
		"stats": {"atk": 18, "crit": 0.03}, "blade": Color(0.75, 0.85, 1.0), "len": 1.0,
		"desc": "옛 봉화 기사단이 쓰던 검. 푸른빛이 돈다."},
	"axe_ogre": {"name": "족장의 대검", "type": "weapon", "rarity": 3, "price": 600, "icon": "sword",
		"stats": {"atk": 27, "hp": 30}, "blade": Color(0.55, 0.45, 0.4), "len": 1.15,
		"desc": "오우거 족장이 휘두르던 투박하고 무거운 대검."},
	"sword_flame": {"name": "불꽃의 검", "type": "weapon", "rarity": 3, "price": 900, "icon": "sword",
		"stats": {"atk": 32, "crit": 0.06}, "blade": Color(1.0, 0.45, 0.15), "len": 1.0,
		"desc": "골렘 핵의 열기를 담아 벼린 검. 칼날이 타오른다."},
	"sword_dawn": {"name": "새벽의 검", "type": "weapon", "rarity": 4, "price": 2000, "icon": "sword",
		"stats": {"atk": 50, "crit": 0.1, "stamina": 30}, "blade": Color(1.0, 0.9, 0.5), "len": 1.1,
		"desc": "일곱 봉화의 빛이 깃든 전설의 검."},

	# ---------------- 방어구
	"armor_cloth": {"name": "여행자의 옷", "type": "armor", "rarity": 0, "price": 10, "icon": "armor",
		"stats": {"def": 0}, "tint": Color(0.55, 0.12, 0.12), "plate": false,
		"desc": "붉은 튜닉과 가죽 흉갑. 오래 입어 손에 익었다."},
	"armor_leather": {"name": "늑대가죽 갑옷", "type": "armor", "rarity": 1, "price": 140, "icon": "armor",
		"stats": {"def": 6, "hp": 20}, "tint": Color(0.42, 0.36, 0.3), "plate": false,
		"desc": "늑대 가죽을 덧댄 가벼운 갑옷."},
	"armor_chain": {"name": "사슬 갑옷", "type": "armor", "rarity": 2, "price": 520, "icon": "armor",
		"stats": {"def": 14, "hp": 45}, "tint": Color(0.2, 0.3, 0.55), "plate": true,
		"desc": "촘촘한 쇠사슬로 엮은 갑옷."},
	"armor_knight": {"name": "기사 판금 갑옷", "type": "armor", "rarity": 3, "price": 950, "icon": "armor",
		"stats": {"def": 26, "hp": 80}, "tint": Color(0.15, 0.2, 0.45), "plate": true,
		"desc": "봉화 기사단의 문장이 새겨진 판금 갑옷."},
	"armor_guardian": {"name": "수호자의 갑주", "type": "armor", "rarity": 4, "price": 1800, "icon": "armor",
		"stats": {"def": 40, "hp": 150, "stamina": 20}, "tint": Color(0.12, 0.45, 0.5), "plate": true,
		"desc": "골렘 핵이 박힌 갑주. 수호자의 힘이 깃들어 있다."},

	# ---------------- 장신구
	"ring_copper": {"name": "구리 반지", "type": "accessory", "rarity": 1, "price": 120, "icon": "ring",
		"stats": {"crit": 0.04}, "color": Color(0.85, 0.55, 0.3), "desc": "행운을 부른다는 소박한 반지."},
	"amulet_wolf": {"name": "늑대 이빨 목걸이", "type": "accessory", "rarity": 2, "price": 300, "icon": "amulet",
		"stats": {"atk": 5, "stamina": 25}, "color": Color(0.9, 0.9, 0.85), "desc": "사냥꾼들의 부적."},
	"ring_ember": {"name": "불씨 반지", "type": "accessory", "rarity": 3, "price": 700, "icon": "ring",
		"stats": {"atk": 10, "crit": 0.08}, "color": Color(1.0, 0.45, 0.2), "desc": "꺼진 봉화의 불씨가 깃든 반지."},
}

## 대장장이 제작 목록
const RECIPES := [
	{"item": "roast_meat", "count": 1, "gold": 0, "mats": {"raw_meat": 1}},
	{"item": "potion_l", "count": 1, "gold": 15, "mats": {"herb": 3, "bone_dust": 1}},
	{"item": "armor_leather", "count": 1, "gold": 40, "mats": {"wolf_pelt": 4}},
	{"item": "amulet_wolf", "count": 1, "gold": 120, "mats": {"wolf_pelt": 3, "boar_tusk": 3}},
	{"item": "sword_knight", "count": 1, "gold": 250, "mats": {"iron_ore": 5, "goblin_ear": 6}},
	{"item": "armor_knight", "count": 1, "gold": 400, "mats": {"iron_ore": 8, "boar_tusk": 4}},
	{"item": "sword_flame", "count": 1, "gold": 600, "mats": {"golem_core": 2, "iron_ore": 6}},
	{"item": "armor_guardian", "count": 1, "gold": 900, "mats": {"golem_core": 3, "ogre_horn": 2}},
]

## 상인 판매 목록
const SHOP := ["potion_s", "potion_l", "stamina_potion", "roast_meat", "sword_iron", "armor_leather", "armor_chain", "ring_copper"]

const MAX_ENHANCE := 5


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))


static func rarity_color(id: String) -> Color:
	return RARITY_COLORS[int(get_item(id).get("rarity", 0))]


static func is_equipment(id: String) -> bool:
	var t: String = get_item(id).get("type", "")
	return t == "weapon" or t == "armor" or t == "accessory"


## 강화 수치를 반영한 장비 능력치
static func stats_of(id: String, enhance: int) -> Dictionary:
	var base: Dictionary = get_item(id).get("stats", {})
	var out := {}
	for k in base:
		var v: float = base[k]
		if k == "crit":
			out[k] = v + 0.01 * enhance
		else:
			out[k] = v * (1.0 + 0.15 * enhance) + (2.0 * enhance if k != "stamina" else 0.0)
	return out


static func enhance_cost(id: String, level: int) -> Dictionary:
	var r := int(get_item(id).get("rarity", 0))
	return {"gold": 60 * (level + 1) * (r + 1), "iron_ore": level + 1}


static func describe_stats(stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names := {"atk": "공격력", "def": "방어력", "hp": "최대 체력", "stamina": "최대 기력", "crit": "치명타"}
	for k in ["atk", "def", "hp", "stamina", "crit"]:
		if stats.has(k) and float(stats[k]) != 0.0:
			if k == "crit":
				parts.append("%s +%d%%" % [names[k], roundi(float(stats[k]) * 100.0)])
			else:
				parts.append("%s +%d" % [names[k], roundi(float(stats[k]))])
	return ", ".join(parts)
