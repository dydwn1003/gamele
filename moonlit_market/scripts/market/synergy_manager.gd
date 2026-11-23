extends RefCounted
## SynergyManager
## 6개 슬롯의 인접 관계(synergies.json slot_adjacency)를 기준으로 노점 조합 시너지를 계산한다.
## 결과: {"slots": {idx: [ {id,name,color,partner,effects} ]}, "global": {key: value}, "active": [ids]}

var data


func setup(p_data) -> void:
	data = p_data


func _tag_of(slot: Dictionary) -> String:
	return str(slot.get("type", ""))


func neighbors(idx: int) -> Array:
	var out: Array = []
	for pair in data.slot_adjacency:
		if pair is Array and pair.size() == 2:
			if int(pair[0]) == idx:
				out.append(int(pair[1]))
			elif int(pair[1]) == idx:
				out.append(int(pair[0]))
	return out


func compute(slots: Array) -> Dictionary:
	var per_slot := {}
	var global := {}
	var active: Array = []
	for i in slots.size():
		per_slot[i] = []
	for pair in data.slot_adjacency:
		if not (pair is Array) or pair.size() != 2:
			continue
		var i := int(pair[0])
		var j := int(pair[1])
		if i < 0 or j < 0 or i >= slots.size() or j >= slots.size():
			continue
		var ti := _tag_of(slots[i])
		var tj := _tag_of(slots[j])
		if ti == "" or tj == "":
			continue
		for syn in data.synergies:
			var a: Array = syn.get("a", [])
			var b: Array = syn.get("b", [])
			var a_idx := -1
			var b_idx := -1
			if a.has(ti) and b.has(tj):
				a_idx = i
				b_idx = j
			elif a.has(tj) and b.has(ti):
				a_idx = j
				b_idx = i
			if a_idx < 0:
				continue
			per_slot[a_idx].append({"id": syn["id"], "name": syn["name"], "color": syn["color"], "partner": b_idx, "role": "a", "effects": syn.get("effects_a", {})})
			per_slot[b_idx].append({"id": syn["id"], "name": syn["name"], "color": syn["color"], "partner": a_idx, "role": "b", "effects": syn.get("effects_b", {})})
			if not active.has(syn["id"]):
				active.append(syn["id"])
				var g: Dictionary = syn.get("global", {})
				for k in g.keys():
					global[k] = float(global.get(k, 0.0)) + float(g[k])
	return {"slots": per_slot, "global": global, "active": active}


## 특정 슬롯에 적용되는 시너지 효과 합계
static func slot_effect(result: Dictionary, idx: int, key: String) -> float:
	var total := 0.0
	var list = result.get("slots", {}).get(idx, [])
	for s in list:
		total += float(s.get("effects", {}).get(key, 0.0))
	return total


## follow_up_chance 처럼 "파트너 노점"이 필요한 효과: [{partner, value}]
static func follow_ups(result: Dictionary, idx: int) -> Array:
	var out: Array = []
	var list = result.get("slots", {}).get(idx, [])
	for s in list:
		var v := float(s.get("effects", {}).get("follow_up_chance", 0.0))
		if v > 0.0:
			out.append({"partner": int(s["partner"]), "value": v})
	return out
