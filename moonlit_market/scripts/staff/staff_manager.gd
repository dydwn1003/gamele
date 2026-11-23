extends RefCounted
## StaffManager
## 상인 고용/해금/레벨업/배치와 능력치 계산. 한 상인은 한 노점에만 배치된다.

const EFFECT_KEYS := ["cook_speed", "satisfaction", "price_tolerance", "patience",
	"spoilage_reduction", "restock_discount", "attraction"]

var state
var data
var economy
var progression


func setup(p_state, p_data, p_economy, p_progression) -> void:
	state = p_state
	data = p_data
	economy = p_economy
	progression = p_progression


static func empty_effects() -> Dictionary:
	var d := {}
	for k in EFFECT_KEYS:
		d[k] = 0.0
	return d


func is_hired(emp_id: String) -> bool:
	return state.employees.has(emp_id) and bool(state.employees[emp_id].get("hired", false))


func level_of(emp_id: String) -> int:
	if not state.employees.has(emp_id):
		return 1
	return int(state.employees[emp_id].get("level", 1))


func max_level() -> int:
	return int(data.employee_meta.get("max_level", 5))


func is_unlocked(emp_id: String) -> bool:
	var def: Dictionary = data.get_employee(emp_id)
	if def.is_empty():
		return false
	if is_hired(emp_id):
		return true
	return progression.check_condition(def.get("unlock", {}))


## 레벨이 반영된 능력치. stall_type 이 특별 상인의 전문 노점이면 특별 효과 추가.
func effects_for(emp_id: String, stall_type: String = "") -> Dictionary:
	var out := empty_effects()
	if emp_id == "" or not is_hired(emp_id):
		return out
	var def: Dictionary = data.get_employee(emp_id)
	if def.is_empty():
		return out
	var mult := 1.0 + float(data.employee_meta.get("level_effect_growth", 0.25)) * (level_of(emp_id) - 1)
	var eff: Dictionary = def.get("effects", {})
	for k in eff.keys():
		out[k] = float(out.get(k, 0.0)) + float(eff[k]) * mult
	var sp: Dictionary = def.get("special", {})
	if not sp.is_empty() and str(sp.get("stall_type", "")) == stall_type:
		for k in sp.keys():
			if k == "stall_type":
				continue
			out[k] = float(out.get(k, 0.0)) + float(sp[k]) * mult
		out["special_active"] = 1.0
	return out


func hire_cost(emp_id: String) -> int:
	return int(data.get_employee(emp_id).get("hire_cost", 0))


func hire(emp_id: String) -> Dictionary:
	var def: Dictionary = data.get_employee(emp_id)
	if def.is_empty():
		return _fail("알 수 없는 상인입니다.")
	if is_hired(emp_id):
		return _fail("이미 고용한 상인입니다.")
	if not is_unlocked(emp_id):
		return _fail("아직 해금되지 않았습니다.")
	var cost := hire_cost(emp_id)
	if not economy.spend(cost):
		return _fail("코인이 부족합니다.")
	state.employees[emp_id] = {"hired": true, "level": 1}
	return {"ok": true, "cost": cost}


func level_up_cost(emp_id: String) -> int:
	var lv := level_of(emp_id)
	if lv >= max_level():
		return -1
	var costs: Array = data.employee_meta.get("level_up_costs", [])
	if lv < costs.size():
		return int(costs[lv])
	return 9999


func level_up(emp_id: String) -> Dictionary:
	if not is_hired(emp_id):
		return _fail("고용하지 않은 상인입니다.")
	var cost := level_up_cost(emp_id)
	if cost < 0:
		return _fail("최고 레벨입니다.")
	if not economy.spend(cost):
		return _fail("코인이 부족합니다.")
	state.employees[emp_id]["level"] = level_of(emp_id) + 1
	return {"ok": true, "cost": cost, "level": level_of(emp_id)}


## 배치: 다른 노점에 있던 같은 상인은 자동으로 해제된다 (동시 배치 불가).
func assign(emp_id: String, slot_idx: int) -> Dictionary:
	if not state.is_stall(slot_idx):
		return _fail("노점에만 배치할 수 있습니다.")
	if emp_id == "":
		state.slots[slot_idx]["employee"] = ""
		return {"ok": true}
	if not is_hired(emp_id):
		return _fail("고용하지 않은 상인입니다.")
	var prev: int = state.employee_slot(emp_id)
	if prev >= 0 and prev != slot_idx:
		state.slots[prev]["employee"] = ""
	state.slots[slot_idx]["employee"] = emp_id
	return {"ok": true, "moved_from": prev}


func unassign(emp_id: String) -> void:
	var prev: int = state.employee_slot(emp_id)
	if prev >= 0:
		state.slots[prev]["employee"] = ""


func describe_effects(emp_id: String, stall_type: String = "") -> String:
	var e := effects_for(emp_id, stall_type) if is_hired(emp_id) else _preview_effects(emp_id)
	var parts: Array = []
	if float(e.get("cook_speed", 0)) > 0.0:
		parts.append("조리 속도 +%d%%" % int(round(e["cook_speed"] * 100)))
	if float(e.get("satisfaction", 0)) > 0.0:
		parts.append("만족도 +%d" % int(round(e["satisfaction"])))
	if float(e.get("price_tolerance", 0)) > 0.0:
		parts.append("가격 저항 -%d%%" % int(round(e["price_tolerance"] * 100)))
	if float(e.get("patience", 0)) > 0.0:
		parts.append("대기 인내심 +%d%%" % int(round(e["patience"] * 100)))
	if float(e.get("spoilage_reduction", 0)) > 0.0:
		parts.append("재고 손실 -%d%%" % int(round(minf(1.0, e["spoilage_reduction"]) * 100)))
	if float(e.get("restock_discount", 0)) > 0.0:
		parts.append("재고 구매가 -%d%%" % int(round(e["restock_discount"] * 100)))
	if float(e.get("attraction", 0)) > 0.0:
		parts.append("손님 유인 +%d%%" % int(round(e["attraction"] * 100)))
	return " · ".join(parts) if parts.size() > 0 else "-"


func _preview_effects(emp_id: String) -> Dictionary:
	var out := empty_effects()
	var def: Dictionary = data.get_employee(emp_id)
	var eff: Dictionary = def.get("effects", {})
	for k in eff.keys():
		out[k] = float(eff[k])
	return out


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
