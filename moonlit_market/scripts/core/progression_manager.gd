extends RefCounted
## ProgressionManager
## 시장 평판 → 시장 단계(1~3), 해금 조건(JSON) 판정, 해금 기록 저장.
## 조건 형식: {"reputation": N, "market_level": N, "days": N, "lifetime_sales": N} (모두 만족해야 함)

const GameStateScript := preload("res://scripts/core/game_state.gd")

var state
var data


func setup(p_state, p_data) -> void:
	state = p_state
	data = p_data


func check_condition(cond) -> bool:
	if not (cond is Dictionary):
		return true
	for k in cond.keys():
		var need := int(cond[k])
		match str(k):
			"reputation":
				if state.reputation < need:
					return false
			"market_level":
				if state.market_level < need:
					return false
			"days":
				if int(state.lifetime.get("sessions", 0)) < need:
					return false
			"lifetime_sales":
				if int(state.lifetime.get("sales", 0)) < need:
					return false
			"pocha_level":
				if state.pocha_level() < need:
					return false
			_:
				push_warning("알 수 없는 해금 조건: %s" % k)
	return true


func describe_condition(cond) -> String:
	if not (cond is Dictionary) or cond.is_empty():
		return "조건 없음"
	var parts: Array = []
	for k in cond.keys():
		var need := int(cond[k])
		match str(k):
			"reputation":
				parts.append("평판 %d" % need)
			"market_level":
				parts.append("시장 %d단계" % need)
			"days":
				parts.append("영업 %d회" % need)
			"lifetime_sales":
				parts.append("누적 판매 %d개" % need)
			"pocha_level":
				parts.append("포차 Lv.%d" % need)
	return " · ".join(parts)


func current_stage() -> Dictionary:
	return data.get_stage(state.market_level)


func next_stage() -> Dictionary:
	if state.market_level >= data.stages.size():
		return {}
	return data.get_stage(state.market_level + 1)


func max_stall_level() -> int:
	return mini(int(current_stage().get("max_stall_level", 5)), data.max_stall_level())


func deco_spot_count() -> int:
	return clampi(int(current_stage().get("deco_spots", 2)), 0, GameStateScript.DECO_SPOT_COUNT)


## 평판에 맞춰 시장 단계를 올린다. 오른 단계 목록 반환 (단계는 내려가지 않음).
func update_market_level() -> Array:
	var ups: Array = []
	while state.market_level < data.stages.size():
		var nxt: Dictionary = data.get_stage(state.market_level + 1)
		if state.reputation >= int(nxt.get("required_reputation", 0)):
			state.market_level += 1
			ups.append(nxt)
		else:
			break
	return ups


func is_menu_unlocked(id: String) -> bool:
	var m: Dictionary = data.get_menu(id)
	if m.is_empty() or not (str(m.get("station", "")) in ["grill", "drink", "mix"]):
		return false
	return check_condition(m.get("unlock", {}))


func is_decoration_unlocked(id: String) -> bool:
	return check_condition(data.get_decoration(id).get("unlock", {}))


## 현재 시장 단계에서 영업하는 경쟁 노점 (등장 순)
func active_rivals() -> Array:
	var limit := int(current_stage().get("rivals", 3))
	var ids: Array = []
	for id in data.rivals.keys():
		if int(data.rivals[id].get("appear_level", 1)) <= state.market_level:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(data.rivals[a].get("appear_level", 1)) < int(data.rivals[b].get("appear_level", 1)))
	return ids.slice(0, limit)


## 새로 해금된 콘텐츠 이름 목록을 반환하고 state.unlocked 에 기록한다.
func refresh_unlocks() -> Array:
	var newly: Array = []
	for id in data.pocha_menu_ids():
		_mark("menu:" + id, is_menu_unlocked(id), data.menus[id]["name"], newly)
	for id in data.decorations.keys():
		_mark("decoration:" + id, is_decoration_unlocked(id), data.decorations[id]["name"], newly)
	for id in data.employees.keys():
		_mark("employee:" + id, check_condition(data.employees[id].get("unlock", {})), data.employees[id]["name"], newly)
	for id in active_rivals():
		_mark("rival:" + id, true, "라이벌 " + str(data.rivals[id]["name"]), newly)
	return newly


func _mark(key: String, ok: bool, label, newly: Array) -> void:
	if ok and not state.unlocked.get(key, false):
		state.unlocked[key] = true
		newly.append(str(label))
