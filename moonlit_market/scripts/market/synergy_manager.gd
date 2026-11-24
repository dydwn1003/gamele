extends RefCounted
## SynergyManager — 메뉴 궁합(페어링)
## 두 메뉴가 모두 내 포차 메뉴판(활성)에 있으면 궁합이 활성화되고 효과가 합산된다.
## 결과: {"active": [ids], "effects": {key: value}, "list": [pairing dict]}

var data


func setup(p_data) -> void:
	data = p_data


func compute(enabled_menus: Array) -> Dictionary:
	var active: Array = []
	var list: Array = []
	var effects := {}
	for p in data.pairings:
		if enabled_menus.has(str(p.get("a", ""))) and enabled_menus.has(str(p.get("b", ""))):
			active.append(p["id"])
			list.append(p)
			var e: Dictionary = p.get("effects", {})
			for k in e.keys():
				effects[k] = float(effects.get(k, 0.0)) + float(e[k])
	return {"active": active, "effects": effects, "list": list}


## 특정 메뉴가 포함된 활성 궁합
static func pairings_with(result: Dictionary, menu_id: String) -> Array:
	var out: Array = []
	for p in result.get("list", []):
		if p.get("a", "") == menu_id or p.get("b", "") == menu_id:
			out.append(p)
	return out
