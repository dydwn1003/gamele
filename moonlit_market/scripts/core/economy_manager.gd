extends RefCounted
## EconomyManager
## 코인 증감, 건설/업그레이드/재고 구매, 영업 장부(ledger)와 정산을 한 곳에서 처리한다.
##
## 회계 규칙
## - 재고 구매 시 메뉴 원가만큼 코인이 즉시 차감된다 (선결제).
## - 판매 시 실제 판매 가격만큼 코인이 즉시 증가한다.
## - 정산 화면의 "재료 원가"는 판매 수량 × 메뉴 원가 (판매된 상품에 대해서만).
## - 순수익 = 총매출 - 재료 원가 - 기타 비용(영업 종료 시 재고 손실분).
## - 영업 결과 보상(평판/만족도 보너스)은 claim_result() 에서 세션당 정확히 한 번만 지급.

signal coins_changed(coins: int)
signal stock_changed(slot_idx: int)

var state
var data
var staff
var ledger: Dictionary = {}


func setup(p_state, p_data, p_staff = null) -> void:
	state = p_state
	data = p_data
	staff = p_staff


# ───────── 기본 재화 ─────────

func can_afford(amount: int) -> bool:
	return amount >= 0 and state.coins >= amount


func spend(amount: int) -> bool:
	if amount < 0 or state.coins < amount:
		return false
	state.coins -= amount
	coins_changed.emit(state.coins)
	return true


func earn(amount: int) -> void:
	if amount <= 0:
		return
	state.coins += amount
	coins_changed.emit(state.coins)


# ───────── 노점 수치 조회 ─────────

func menu_for_slot(idx: int) -> Dictionary:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return {}
	return data.get_menu(str(s.get("menu", "")))


func unit_price(idx: int) -> int:
	var m := menu_for_slot(idx)
	if m.is_empty():
		return 0
	var ratio := float(state.get_slot(idx).get("price_ratio", 1.0))
	return price_for(int(m["price"]), ratio)


static func price_for(base_price: int, ratio: float) -> int:
	return maxi(1, int(round(base_price * ratio)))


func unit_cost(idx: int) -> int:
	var m := menu_for_slot(idx)
	return int(m.get("cost", 0))


func stock_max(idx: int) -> int:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return 0
	return int(data.get_level(int(s.get("level", 1))).get("stock_max", 20))


func _employee_effects(idx: int) -> Dictionary:
	if staff == null:
		return {}
	var s: Dictionary = state.get_slot(idx)
	return staff.effects_for(str(s.get("employee", "")), str(s.get("type", "")))


func build_cost(structure_type: String) -> int:
	if data.stalls.has(structure_type):
		return int(data.get_stall(structure_type).get("build_cost", 0))
	if data.facilities.has(structure_type):
		return int(data.get_facility(structure_type).get("build_cost", 0))
	return -1


# ───────── 건설 / 철거 / 이동 ─────────

func build_stall(idx: int, stall_type: String) -> Dictionary:
	if not state.is_slot_empty(idx):
		return _fail("이미 사용 중인 자리입니다.")
	var def: Dictionary = data.get_stall(stall_type)
	if def.is_empty():
		return _fail("알 수 없는 노점입니다.")
	var cost := int(def.get("build_cost", 0))
	if not spend(cost):
		return _fail("코인이 부족합니다.")
	var opening_stock := mini(10, int(data.get_level(1).get("stock_max", 20)))
	state.slots[idx] = state.make_stall(stall_type, str(def.get("default_menu", "")), opening_stock, float(def.get("base_reputation", 10)))
	return {"ok": true, "cost": cost}


func build_facility(idx: int, facility_type: String) -> Dictionary:
	if not state.is_slot_empty(idx):
		return _fail("이미 사용 중인 자리입니다.")
	var def: Dictionary = data.get_facility(facility_type)
	if def.is_empty():
		return _fail("알 수 없는 시설입니다.")
	var cost := int(def.get("build_cost", 0))
	if not spend(cost):
		return _fail("코인이 부족합니다.")
	state.slots[idx] = state.make_facility(facility_type)
	return {"ok": true, "cost": cost}


func demolish_refund(idx: int) -> int:
	var s: Dictionary = state.get_slot(idx)
	if s.is_empty():
		return 0
	return int(floor(build_cost(str(s.get("type", ""))) * float(data.bal("build_refund_rate", 0.5))))


func demolish(idx: int) -> Dictionary:
	var s: Dictionary = state.get_slot(idx)
	if s.is_empty():
		return _fail("비어 있는 자리입니다.")
	if s.get("kind", "") == "stall" and state.stall_count() <= 1:
		return _fail("마지막 노점은 철거할 수 없습니다.")
	var refund := demolish_refund(idx)
	state.slots[idx] = {}
	earn(refund)
	return {"ok": true, "refund": refund}


func move_structure(from_idx: int, to_idx: int) -> Dictionary:
	if from_idx == to_idx or from_idx < 0 or to_idx < 0 or from_idx >= state.slots.size() or to_idx >= state.slots.size():
		return _fail("잘못된 위치입니다.")
	if state.is_slot_empty(from_idx):
		return _fail("옮길 노점이 없습니다.")
	var tmp = state.slots[to_idx]
	state.slots[to_idx] = state.slots[from_idx]
	state.slots[from_idx] = tmp
	return {"ok": true}


# ───────── 업그레이드 ─────────

func upgrade_cost(idx: int) -> int:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return -1
	var lv := int(s.get("level", 1))
	if lv >= data.max_stall_level():
		return -1
	return int(data.get_level(lv + 1).get("upgrade_cost", 0))


func upgrade_stall(idx: int, max_level_allowed: int) -> Dictionary:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return _fail("노점이 아닙니다.")
	var lv := int(s.get("level", 1))
	if lv >= data.max_stall_level():
		return _fail("최고 레벨입니다.")
	if lv >= max_level_allowed:
		return _fail("시장 단계를 올려야 더 업그레이드할 수 있습니다.")
	var cost := upgrade_cost(idx)
	if not spend(cost):
		return _fail("코인이 부족합니다.")
	s["level"] = lv + 1
	return {"ok": true, "cost": cost, "level": lv + 1}


# ───────── 메뉴 / 가격 ─────────

func is_menu_available(idx: int, menu_id: String) -> bool:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return false
	var def: Dictionary = data.get_stall(str(s["type"]))
	if not (def.get("menus", []) as Array).has(menu_id):
		return false
	var need := int((def.get("menu_unlock_level", {}) as Dictionary).get(menu_id, 1))
	return int(s.get("level", 1)) >= need


## 메뉴 변경: 남은 재고는 기존 원가로 환급된다 (악용 불가: 새 재고는 새 원가로 구매).
func set_menu(idx: int, menu_id: String) -> Dictionary:
	if not is_menu_available(idx, menu_id):
		return _fail("아직 판매할 수 없는 메뉴입니다.")
	var s: Dictionary = state.get_slot(idx)
	if s["menu"] == menu_id:
		return {"ok": true, "refund": 0}
	var refund := int(s.get("stock", 0)) * unit_cost(idx)
	s["stock"] = 0
	s["menu"] = menu_id
	earn(refund)
	stock_changed.emit(idx)
	return {"ok": true, "refund": refund}


func snap_price_ratio(ratio: float) -> float:
	var lo := float(data.bal("price_ratio_min", 0.8))
	var hi := float(data.bal("price_ratio_max", 1.3))
	var step := float(data.bal("price_ratio_step", 0.05))
	var r := clampf(ratio, lo, hi)
	if step > 0.0:
		r = snappedf(r, step)
	return clampf(r, lo, hi)


func set_price_ratio(idx: int, ratio: float) -> Dictionary:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return _fail("노점이 아닙니다.")
	s["price_ratio"] = snap_price_ratio(ratio)
	return {"ok": true, "price_ratio": s["price_ratio"]}


# ───────── 재고 ─────────

func restock_unit_cost(idx: int) -> float:
	var discount := float(_employee_effects(idx).get("restock_discount", 0.0))
	return unit_cost(idx) * clampf(1.0 - discount, 0.5, 1.0)


func restock_cost(idx: int) -> int:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return 0
	var missing := maxi(0, stock_max(idx) - int(s.get("stock", 0)))
	return int(ceil(missing * restock_unit_cost(idx)))


## 가진 코인 안에서 최대한 채운다. 반환: {ok, bought, cost}
func restock(idx: int) -> Dictionary:
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall":
		return _fail("노점이 아닙니다.")
	var missing := maxi(0, stock_max(idx) - int(s.get("stock", 0)))
	if missing == 0:
		return _fail("재고가 이미 가득 찼습니다.")
	var per := restock_unit_cost(idx)
	var affordable := missing
	if per > 0.0:
		affordable = mini(missing, int(floor(state.coins / per)))
	if affordable <= 0:
		return _fail("코인이 부족합니다.")
	var cost := int(ceil(affordable * per))
	if not spend(cost):
		return _fail("코인이 부족합니다.")
	s["stock"] = int(s["stock"]) + affordable
	stock_changed.emit(idx)
	return {"ok": true, "bought": affordable, "cost": cost}


func restock_all() -> Dictionary:
	var bought := 0
	var cost := 0
	for i in state.slots.size():
		if state.is_stall(i) and restock_cost(i) > 0:
			var r := restock(i)
			if r.get("ok", false):
				bought += int(r["bought"])
				cost += int(r["cost"])
	if bought == 0:
		return _fail("채울 재고가 없거나 코인이 부족합니다.")
	return {"ok": true, "bought": bought, "cost": cost}


# ───────── 영업 장부 ─────────

func begin_session(session_id: int, weather_id: String) -> void:
	ledger = {
		"session_id": session_id, "active": true, "closed": false,
		"visitors": 0, "buyers": 0, "walkouts": 0, "browsers": 0,
		"sales": 0, "revenue": 0, "cogs": 0, "other_costs": 0,
		"sat_sum": 0.0, "sat_count": 0, "rep_points": 0.0,
		"stall_sales": {}, "stall_revenue": {}, "stall_sat_sum": {},
		"weather": weather_id, "events": [], "result": {},
	}


func is_session_active() -> bool:
	return ledger.get("active", false)


func record_visit() -> void:
	if is_session_active():
		ledger["visitors"] += 1


func record_buyer() -> void:
	if is_session_active():
		ledger["buyers"] += 1


func record_browser() -> void:
	if is_session_active():
		ledger["browsers"] += 1


func record_walkout() -> void:
	if not is_session_active():
		return
	ledger["walkouts"] += 1
	var sat := float(data.bal("walkout_satisfaction", 15.0))
	ledger["sat_sum"] += sat
	ledger["sat_count"] += 1


func record_event(event_id: String) -> void:
	if is_session_active():
		(ledger["events"] as Array).append(event_id)


## 판매 1건 기록. 재고가 없거나 영업 중이 아니면 false (코인 변화 없음).
func record_sale(idx: int, price: int, satisfaction: float) -> bool:
	if not is_session_active():
		return false
	var s: Dictionary = state.get_slot(idx)
	if s.get("kind", "") != "stall" or int(s.get("stock", 0)) <= 0 or price <= 0:
		return false
	var cost := unit_cost(idx)
	s["stock"] = int(s["stock"]) - 1
	ledger["sales"] += 1
	ledger["revenue"] += price
	ledger["cogs"] += cost
	ledger["sat_sum"] += satisfaction
	ledger["sat_count"] += 1
	ledger["rep_points"] += (satisfaction - 40.0) * float(data.bal("reputation_per_satisfaction", 0.04))
	var key := str(idx)
	ledger["stall_sales"][key] = int(ledger["stall_sales"].get(key, 0)) + 1
	ledger["stall_revenue"][key] = int(ledger["stall_revenue"].get(key, 0)) + price
	ledger["stall_sat_sum"][key] = float(ledger["stall_sat_sum"].get(key, 0.0)) + satisfaction
	var st: Dictionary = s["stats"]
	st["sold_total"] = int(st.get("sold_total", 0)) + 1
	st["revenue_total"] = int(st.get("revenue_total", 0)) + price
	earn(price)
	stock_changed.emit(idx)
	return true


## 영업 종료: 결과를 계산해 state.pending_result 에 저장. 두 번 호출해도 한 번만 처리된다.
func close_session(duration_sec: float) -> Dictionary:
	if ledger.is_empty():
		return {}
	if ledger.get("closed", false):
		return ledger["result"]
	ledger["active"] = false
	ledger["closed"] = true
	# 재고 손실 (기타 비용)
	var spoil_rate := float(data.bal("spoilage_rate", 0.15))
	var spoiled_total := 0
	for i in state.slots.size():
		if not state.is_stall(i):
			continue
		var s: Dictionary = state.slots[i]
		var reduction := clampf(float(_employee_effects(i).get("spoilage_reduction", 0.0)), 0.0, 1.0)
		var lost := int(floor(int(s["stock"]) * spoil_rate * (1.0 - reduction)))
		if lost > 0:
			s["stock"] = int(s["stock"]) - lost
			ledger["other_costs"] += lost * unit_cost(i)
			spoiled_total += lost
		var key := str(i)
		var sold := int(ledger["stall_sales"].get(key, 0))
		s["stats"]["last_sold"] = sold
		s["stats"]["last_revenue"] = int(ledger["stall_revenue"].get(key, 0))
		if sold > 0:
			var avg_sat := float(ledger["stall_sat_sum"][key]) / sold
			var rep_max := float(data.bal("stall_reputation_max", 100.0))
			s["rep"] = clampf(float(s.get("rep", 10.0)) + (avg_sat - 55.0) / 8.0 + sold * 0.1, 0.0, rep_max)
	var revenue := int(ledger["revenue"])
	var cogs := int(ledger["cogs"])
	var other := int(ledger["other_costs"])
	var net := revenue - cogs - other
	var avg := 0.0
	if int(ledger["sat_count"]) > 0:
		avg = float(ledger["sat_sum"]) / int(ledger["sat_count"])
	var rep_gain := int(round(float(ledger["rep_points"])
		+ int(ledger["buyers"]) * float(data.bal("reputation_per_buyer", 0.15))
		- int(ledger["walkouts"]) * float(data.bal("reputation_walkout_penalty", 0.3))))
	rep_gain = maxi(0, rep_gain)
	var bonus := 0
	if avg >= float(data.bal("satisfaction_bonus_threshold", 70.0)) and int(ledger["sales"]) > 0:
		bonus = int(round(revenue * float(data.bal("satisfaction_bonus_rate", 0.05))))
	var best_idx := -1
	var best_sales := 0
	for key in ledger["stall_sales"].keys():
		var n := int(ledger["stall_sales"][key])
		if n > best_sales:
			best_sales = n
			best_idx = int(key)
	var best_name := "-"
	if best_idx >= 0 and state.is_stall(best_idx):
		best_name = str(data.get_stall(str(state.slots[best_idx]["type"])).get("name", "-"))
	var result := {
		"session_id": int(ledger["session_id"]),
		"day": state.day,
		"duration": duration_sec,
		"visitors": int(ledger["visitors"]),
		"buyers": int(ledger["buyers"]),
		"walkouts": int(ledger["walkouts"]),
		"sales": int(ledger["sales"]),
		"revenue": revenue, "cogs": cogs, "other_costs": other, "spoiled": spoiled_total,
		"net_profit": net, "avg_satisfaction": avg,
		"rep_gain": rep_gain, "bonus_coins": bonus,
		"best_stall": best_name, "best_stall_sales": best_sales, "best_slot": best_idx,
		"weather": ledger["weather"], "events": (ledger["events"] as Array).duplicate(),
	}
	ledger["result"] = result
	state.pending_result = result.duplicate(true)
	# 오프라인 기준이 되는 "정상 영업" 기록 (60초 이상 영업한 경우만)
	if duration_sec >= 60.0:
		state.last_session = {
			"session_id": result["session_id"],
			"net_profit": net,
			"duration_sec": duration_sec,
			"per_minute": maxf(0.0, float(net)) / maxf(1.0, duration_sec / 60.0),
			"ended_unix": Time.get_unix_time_from_system(),
		}
	state.lifetime["customers"] = int(state.lifetime.get("customers", 0)) + result["visitors"]
	state.lifetime["buyers"] = int(state.lifetime.get("buyers", 0)) + result["buyers"]
	state.lifetime["sales"] = int(state.lifetime.get("sales", 0)) + result["sales"]
	state.lifetime["revenue"] = int(state.lifetime.get("revenue", 0)) + revenue
	state.lifetime["sessions"] = int(state.lifetime.get("sessions", 0)) + 1
	state.day += 1
	return result


func has_unclaimed_result() -> bool:
	return not state.pending_result.is_empty() and int(state.pending_result.get("session_id", 0)) > state.settled_session_id


## 정산 보상 수령. 같은 세션은 절대 두 번 지급되지 않는다.
func claim_result() -> Dictionary:
	if not has_unclaimed_result():
		state.pending_result = {}
		return _fail("이미 정산이 완료되었습니다.")
	var r: Dictionary = state.pending_result
	var bonus := maxi(0, int(r.get("bonus_coins", 0)))
	var rep := maxi(0, int(r.get("rep_gain", 0)))
	state.settled_session_id = int(r["session_id"])
	state.pending_result = {}
	state.reputation += rep
	earn(bonus)
	return {"ok": true, "bonus_coins": bonus, "rep_gain": rep}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
