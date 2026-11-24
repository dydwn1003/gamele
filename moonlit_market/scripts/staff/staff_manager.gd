extends RefCounted
## StaffManager
## 상인 고용/해금/레벨업과 "내 포차 근무" 배치. 근무 자리 수는 포차 레벨에 따라 늘어난다.
## 효과는 근무 중인 상인 전원의 합.
##   auto_cook: 화구 하나를 맡아 자동 요리 (auto_quality 품질)
##   auto_drink: 음료 주문 자동 서빙
##   special.menus: 특정 메뉴 품질 보너스/인기

const EFFECT_KEYS := ["cook_speed", "satisfaction", "price_tolerance", "patience",
	"spoilage_reduction", "restock_discount", "attraction", "reorder_chance",
	"auto_cook", "auto_quality", "auto_drink"]

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
	d["special_menus"] = {}
	return d


func is_hired(emp_id: String) -> bool:
	return state.employees.has(emp_id) and bool(state.employees[emp_id].get("hired", false))


func level_of(emp_id: String) -> int:
	if not state.employees.has(emp_id):
		return 1
	return int(state.employees[emp_id].get("level", 1))


func max_level() -> int:
	return int(data.employee_meta.get("max_level", 5))


func staff_slots() -> int:
	return int(data.get_pocha_level(state.pocha_level()).get("staff_slots", 1))


func is_unlocked(emp_id: String) -> bool:
	var def: Dictionary = data.get_employee(emp_id)
	if def.is_empty():
		return false
	if is_hired(emp_id):
		return true
	return progression.check_condition(def.get("unlock", {}))


func _level_mult(emp_id: String) -> float:
	return 1.0 + float(data.employee_meta.get("level_effect_growth", 0.25)) * (level_of(emp_id) - 1)


## 상인 한 명의 효과 (레벨 반영)
func effects_for(emp_id: String) -> Dictionary:
	var out := empty_effects()
	if emp_id == "" or not is_hired(emp_id):
		return out
	_add_effects(out, emp_id)
	return out


func _add_effects(out: Dictionary, emp_id: String) -> void:
	var def: Dictionary = data.get_employee(emp_id)
	var mult := _level_mult(emp_id)
	var eff: Dictionary = def.get("effects", {})
	for k in eff.keys():
		if k == "auto_quality":
			out[k] = maxf(float(out.get(k, 0.0)), minf(98.0, float(eff[k]) + 4.0 * (level_of(emp_id) - 1)))
		elif k in ["auto_cook", "auto_drink"]:
			out[k] = float(out.get(k, 0.0)) + float(eff[k])
		else:
			out[k] = float(out.get(k, 0.0)) + float(eff[k]) * mult
	var sp: Dictionary = def.get("special", {})
	for m in sp.get("menus", []):
		var cur: Dictionary = out["special_menus"].get(m, {"quality_bonus": 0.0, "attraction": 0.0})
		cur["quality_bonus"] = float(cur["quality_bonus"]) + float(sp.get("quality_bonus", 0.0)) * mult
		cur["attraction"] = float(cur["attraction"]) + float(sp.get("attraction", 0.0)) * mult
		out["special_menus"][m] = cur


## 현재 포차에서 근무 중인 상인들의 효과 합계
func pocha_effects() -> Dictionary:
	var out := empty_effects()
	for emp_id in state.staff_list():
		if is_hired(emp_id):
			_add_effects(out, emp_id)
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


## 근무 배치/해제. 같은 상인은 한 번만 배치되며, 자리 수를 넘을 수 없다.
func set_working(emp_id: String, working: bool) -> Dictionary:
	if not is_hired(emp_id):
		return _fail("고용하지 않은 상인입니다.")
	var list: Array = state.pocha["staff"]
	if not working:
		list.erase(emp_id)
		return {"ok": true}
	if list.has(emp_id):
		return {"ok": true}
	if list.size() >= staff_slots():
		return _fail("근무 자리가 부족합니다 (포차 레벨업 시 증가).")
	list.append(emp_id)
	return {"ok": true}


func describe_effects(emp_id: String) -> String:
	var e := effects_for(emp_id) if is_hired(emp_id) else _preview_effects(emp_id)
	var parts: Array = []
	if float(e.get("auto_cook", 0)) > 0.0:
		parts.append("화구 1개 자동 요리 (품질 %d)" % int(e.get("auto_quality", 80)))
	if float(e.get("auto_drink", 0)) > 0.0:
		parts.append("음료 자동 서빙")
	if float(e.get("cook_speed", 0)) > 0.0:
		parts.append("조리 속도 +%d%%" % int(round(e["cook_speed"] * 100)))
	if float(e.get("satisfaction", 0)) > 0.0:
		parts.append("만족도 +%d" % int(round(e["satisfaction"])))
	if float(e.get("price_tolerance", 0)) > 0.0:
		parts.append("가격 저항 -%d%%" % int(round(e["price_tolerance"] * 100)))
	if float(e.get("reorder_chance", 0)) > 0.0:
		parts.append("추가 주문 +%d%%" % int(round(e["reorder_chance"] * 100)))
	if float(e.get("patience", 0)) > 0.0:
		parts.append("대기 인내심 +%d%%" % int(round(e["patience"] * 100)))
	if float(e.get("spoilage_reduction", 0)) > 0.0:
		parts.append("재고 손실 -%d%%" % int(round(minf(1.0, e["spoilage_reduction"]) * 100)))
	if float(e.get("restock_discount", 0)) > 0.0:
		parts.append("재료 구매가 -%d%%" % int(round(e["restock_discount"] * 100)))
	var sp: Dictionary = e.get("special_menus", {})
	for m in sp.keys():
		parts.append("%s 품질 +%d" % [data.get_menu(m).get("name", m), int(sp[m].get("quality_bonus", 0))])
	return " · ".join(parts) if parts.size() > 0 else "-"


func _preview_effects(emp_id: String) -> Dictionary:
	var out := empty_effects()
	var def: Dictionary = data.get_employee(emp_id)
	var eff: Dictionary = def.get("effects", {})
	for k in eff.keys():
		out[k] = float(eff[k])
	var sp: Dictionary = def.get("special", {})
	for m in sp.get("menus", []):
		out["special_menus"][m] = {"quality_bonus": float(sp.get("quality_bonus", 0.0)), "attraction": float(sp.get("attraction", 0.0))}
	return out


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
