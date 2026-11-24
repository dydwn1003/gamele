extends RefCounted
## EconomyManager
## 코인 증감, 포차 업그레이드/메뉴/가격/재고 구매, 영업 장부(ledger)와 정산을 한 곳에서 처리한다.
##
## 회계 규칙
## - 재료(재고)는 영업 준비에서 메뉴 원가로 구매한다 (선결제).
## - 요리를 화구에 올리거나 음료를 따를 때 재고 1개가 쓰인다.
## - 손님에게 낸 순간 판매 가격만큼 코인이 들어온다.  총매출 = 판매 수량 × 판매 가격
## - 정산의 "재료 원가" = 판매 수량 × 메뉴 원가 (판매된 것만).
## - "기타 비용" = 태워서 버린 요리 + 영업 후 남은 재고 손실분의 원가.
## - 팁은 매출과 별도로 기록한다. 순수익 = 총매출 + 팁 - 재료 원가 - 기타 비용
## - 영업 결과 보상(평판/만족도 보너스)은 claim_result() 에서 세션당 정확히 한 번만 지급.

signal coins_changed(coins: int)
signal stock_changed(menu_id: String)

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


# ───────── 메뉴 / 가격 ─────────

static func price_for(base_price: int, ratio: float) -> int:
	return maxi(1, int(round(base_price * ratio)))


func unit_price(menu_id: String) -> int:
	var m: Dictionary = data.get_menu(menu_id)
	if m.is_empty():
		return 0
	return price_for(int(m["price"]), float(state.menu_entry(menu_id).get("price_ratio", 1.0)))


func unit_cost(menu_id: String) -> int:
	return int(data.get_menu(menu_id).get("cost", 0))


func stock_max() -> int:
	return int(data.get_pocha_level(state.pocha_level()).get("stock_max", 15))


func _staff_effects() -> Dictionary:
	if staff == null:
		return {}
	return staff.pocha_effects()


## 레벨/평판 조건을 만족해 메뉴판에 올릴 수 있는가
func is_menu_unlocked(menu_id: String, progression = null) -> bool:
	var m: Dictionary = data.get_menu(menu_id)
	if m.is_empty() or not (str(m.get("station", "")) in ["grill", "drink"]):
		return false
	var cond: Dictionary = m.get("unlock", {})
	if cond.has("pocha_level") and state.pocha_level() < int(cond["pocha_level"]):
		return false
	if progression != null:
		var rest := cond.duplicate()
		rest.erase("pocha_level")
		return progression.check_condition(rest)
	return true


func set_menu_enabled(menu_id: String, enabled: bool, progression = null) -> Dictionary:
	if enabled and not is_menu_unlocked(menu_id, progression):
		return _fail("아직 해금되지 않은 메뉴입니다.")
	if not state.has_menu(menu_id):
		if not enabled:
			return {"ok": true}
		state.pocha["menus"][menu_id] = state.make_menu_entry(true, 0)
		return {"ok": true}
	if not enabled and state.enabled_menus().size() <= 1:
		return _fail("메뉴가 하나는 있어야 합니다.")
	state.pocha["menus"][menu_id]["enabled"] = enabled
	return {"ok": true}


func snap_price_ratio(ratio: float) -> float:
	var lo := float(data.bal("price_ratio_min", 0.8))
	var hi := float(data.bal("price_ratio_max", 1.3))
	var step := float(data.bal("price_ratio_step", 0.05))
	var r := clampf(ratio, lo, hi)
	if step > 0.0:
		r = snappedf(r, step)
	return clampf(r, lo, hi)


func set_price_ratio(menu_id: String, ratio: float) -> Dictionary:
	if not state.has_menu(menu_id):
		return _fail("메뉴판에 없는 메뉴입니다.")
	state.pocha["menus"][menu_id]["price_ratio"] = snap_price_ratio(ratio)
	return {"ok": true, "price_ratio": state.pocha["menus"][menu_id]["price_ratio"]}


# ───────── 업그레이드 ─────────

func upgrade_cost() -> int:
	var lv: int = state.pocha_level()
	if lv >= data.max_stall_level():
		return -1
	return int(data.get_pocha_level(lv + 1).get("upgrade_cost", 0))


func upgrade_pocha(max_level_allowed: int) -> Dictionary:
	var lv: int = state.pocha_level()
	if lv >= data.max_stall_level():
		return _fail("최고 레벨입니다.")
	if lv >= max_level_allowed:
		return _fail("시장 단계를 올려야 더 업그레이드할 수 있습니다.")
	var cost := upgrade_cost()
	if not spend(cost):
		return _fail("코인이 부족합니다.")
	state.pocha["level"] = lv + 1
	return {"ok": true, "cost": cost, "level": lv + 1}


# ───────── 재고 ─────────

func restock_unit_cost(menu_id: String) -> float:
	var discount := float(_staff_effects().get("restock_discount", 0.0))
	return unit_cost(menu_id) * clampf(1.0 - discount, 0.5, 1.0)


func restock_cost(menu_id: String) -> int:
	if not state.has_menu(menu_id):
		return 0
	var missing := maxi(0, stock_max() - state.stock_of(menu_id))
	return int(ceil(missing * restock_unit_cost(menu_id)))


## 가진 코인 안에서 최대한 채운다. 반환: {ok, bought, cost}
func restock(menu_id: String) -> Dictionary:
	if not state.has_menu(menu_id):
		return _fail("메뉴판에 없는 메뉴입니다.")
	var missing := maxi(0, stock_max() - state.stock_of(menu_id))
	if missing == 0:
		return _fail("재고가 이미 가득 찼습니다.")
	var per := restock_unit_cost(menu_id)
	var affordable := missing
	if per > 0.0:
		affordable = mini(missing, int(floor(state.coins / per)))
	if affordable <= 0:
		return _fail("코인이 부족합니다.")
	var cost := int(ceil(affordable * per))
	if not spend(cost):
		return _fail("코인이 부족합니다.")
	state.pocha["menus"][menu_id]["stock"] = state.stock_of(menu_id) + affordable
	stock_changed.emit(menu_id)
	return {"ok": true, "bought": affordable, "cost": cost}


func restock_all() -> Dictionary:
	var bought := 0
	var cost := 0
	for id in state.enabled_menus():
		if restock_cost(id) > 0:
			var r := restock(id)
			if r.get("ok", false):
				bought += int(r["bought"])
				cost += int(r["cost"])
	if bought == 0:
		return _fail("채울 재고가 없거나 코인이 부족합니다.")
	return {"ok": true, "bought": bought, "cost": cost}


func restock_all_cost() -> int:
	var total := 0
	for id in state.enabled_menus():
		total += restock_cost(id)
	return total


## 요리 시작/음료 따르기 시 재료 1개 사용. 재고가 없으면 false.
func consume_stock(menu_id: String) -> bool:
	if state.stock_of(menu_id) <= 0:
		return false
	state.pocha["menus"][menu_id]["stock"] = state.stock_of(menu_id) - 1
	stock_changed.emit(menu_id)
	return true


# ───────── 영업 장부 ─────────

func begin_session(session_id: int, weather_id: String) -> void:
	ledger = {
		"session_id": session_id, "active": true, "closed": false,
		"visitors": 0, "buyers": 0, "walkouts": 0, "browsers": 0, "rival_buyers": 0,
		"sales": 0, "revenue": 0, "cogs": 0, "other_costs": 0, "tips": 0,
		"burnt": 0, "perfect": 0, "quality_sum": 0.0,
		"sat_sum": 0.0, "sat_count": 0, "rep_points": 0.0,
		"menu_sales": {}, "rival_sales": {}, "rival_revenue": {},
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
	ledger["sat_sum"] += float(data.bal("walkout_satisfaction", 15.0))
	ledger["sat_count"] += 1


func record_event(event_id: String) -> void:
	if is_session_active():
		(ledger["events"] as Array).append(event_id)


## 내 포차 판매 1건 (재료는 consume_stock 에서 이미 사용됨)
func record_sale(menu_id: String, price: int, quality: float) -> bool:
	if not is_session_active() or price <= 0 or data.get_menu(menu_id).is_empty():
		return false
	ledger["sales"] += 1
	ledger["revenue"] += price
	ledger["cogs"] += unit_cost(menu_id)
	ledger["quality_sum"] += quality
	if quality >= 99.0:
		ledger["perfect"] += 1
	ledger["menu_sales"][menu_id] = int(ledger["menu_sales"].get(menu_id, 0)) + 1
	var st: Dictionary = state.pocha["stats"]
	st["sold_total"] = int(st.get("sold_total", 0)) + 1
	st["revenue_total"] = int(st.get("revenue_total", 0)) + price
	earn(price)
	return true


## 손님 만족도 기록 (내 포차 손님이 떠날 때 1회)
func record_satisfaction(sat: float) -> void:
	if not is_session_active():
		return
	ledger["sat_sum"] += sat
	ledger["sat_count"] += 1
	ledger["rep_points"] += (sat - 40.0) * float(data.bal("reputation_per_satisfaction", 0.015))


func record_tip(amount: int) -> void:
	if not is_session_active() or amount <= 0:
		return
	ledger["tips"] += amount
	earn(amount)


## 태운 요리 / 버린 음식 (재료는 이미 사용됨 → 원가만큼 손실 기록)
func record_waste(menu_id: String, burnt: bool) -> void:
	if not is_session_active():
		return
	ledger["other_costs"] += unit_cost(menu_id)
	if burnt:
		ledger["burnt"] += 1


func record_rival_sale(rival_id: String, price: int) -> void:
	if not is_session_active():
		return
	ledger["rival_buyers"] += 1
	ledger["rival_sales"][rival_id] = int(ledger["rival_sales"].get(rival_id, 0)) + 1
	ledger["rival_revenue"][rival_id] = int(ledger["rival_revenue"].get(rival_id, 0)) + price


## 영업 종료: 결과를 계산해 state.pending_result 에 저장. 두 번 호출해도 한 번만 처리된다.
func close_session(duration_sec: float) -> Dictionary:
	if ledger.is_empty():
		return {}
	if ledger.get("closed", false):
		return ledger["result"]
	ledger["active"] = false
	ledger["closed"] = true
	# 남은 재고 손실
	var spoil_rate := float(data.bal("spoilage_rate", 0.15))
	var reduction := clampf(float(_staff_effects().get("spoilage_reduction", 0.0)), 0.0, 1.0)
	var spoiled_total := 0
	for id in state.pocha.get("menus", {}).keys():
		var lost := int(floor(state.stock_of(id) * spoil_rate * (1.0 - reduction)))
		if lost > 0:
			state.pocha["menus"][id]["stock"] = state.stock_of(id) - lost
			ledger["other_costs"] += lost * unit_cost(id)
			spoiled_total += lost
	var revenue := int(ledger["revenue"])
	var tips := int(ledger["tips"])
	var cogs := int(ledger["cogs"])
	var other := int(ledger["other_costs"])
	var net := revenue + tips - cogs - other
	var sales := int(ledger["sales"])
	var avg := 0.0
	if int(ledger["sat_count"]) > 0:
		avg = float(ledger["sat_sum"]) / int(ledger["sat_count"])
	var avg_quality := 0.0
	if sales > 0:
		avg_quality = float(ledger["quality_sum"]) / sales
	var rep_gain := int(round(float(ledger["rep_points"])
		+ int(ledger["buyers"]) * float(data.bal("reputation_per_buyer", 0.1))
		- int(ledger["walkouts"]) * float(data.bal("reputation_walkout_penalty", 0.3))))
	rep_gain = maxi(0, rep_gain)
	var bonus := 0
	if avg >= float(data.bal("satisfaction_bonus_threshold", 70.0)) and sales > 0:
		bonus = int(round(revenue * float(data.bal("satisfaction_bonus_rate", 0.05))))
	# 인기 메뉴
	var best_menu := "-"
	var best_sales := 0
	for id in ledger["menu_sales"].keys():
		if int(ledger["menu_sales"][id]) > best_sales:
			best_sales = int(ledger["menu_sales"][id])
			best_menu = str(data.get_menu(id).get("name", id))
	# 경쟁 노점과 매출 순위
	var ranking: Array = [{"id": "pocha", "name": "내 포차", "revenue": revenue, "sales": sales, "mine": true}]
	for rid in ledger["rival_revenue"].keys():
		ranking.append({"id": rid, "name": str(data.get_rival(rid).get("name", rid)),
			"revenue": int(ledger["rival_revenue"][rid]), "sales": int(ledger["rival_sales"].get(rid, 0)), "mine": false})
	ranking.sort_custom(func(a, b): return int(a["revenue"]) > int(b["revenue"]))
	var my_rank := 1
	for i in ranking.size():
		if ranking[i]["mine"]:
			my_rank = i + 1
	# 포차 평판/통계, 라이벌 기록
	var st: Dictionary = state.pocha["stats"]
	st["last_sold"] = sales
	st["last_revenue"] = revenue
	st["best_quality"] = maxi(int(st.get("best_quality", 0)), int(round(avg_quality)))
	if int(ledger["sat_count"]) > 0:
		state.pocha["rep"] = clampf(float(state.pocha.get("rep", 10.0)) + (avg - 55.0) / 8.0 + sales * 0.05,
			0.0, float(data.bal("stall_reputation_max", 100.0)))
	for rid in ledger["rival_sales"].keys():
		var rv: Dictionary = state.rivals.get(rid, {"rep": float(data.get_rival(rid).get("reputation", 20)), "sales_total": 0, "last_sales": 0})
		rv["last_sales"] = int(ledger["rival_sales"][rid])
		rv["sales_total"] = int(rv.get("sales_total", 0)) + rv["last_sales"]
		state.rivals[rid] = rv
	var result := {
		"session_id": int(ledger["session_id"]),
		"day": state.day,
		"duration": duration_sec,
		"visitors": int(ledger["visitors"]),
		"buyers": int(ledger["buyers"]),
		"rival_buyers": int(ledger["rival_buyers"]),
		"walkouts": int(ledger["walkouts"]),
		"sales": sales,
		"revenue": revenue, "tips": tips, "cogs": cogs, "other_costs": other,
		"spoiled": spoiled_total, "burnt": int(ledger["burnt"]), "perfect": int(ledger["perfect"]),
		"avg_quality": avg_quality,
		"net_profit": net, "avg_satisfaction": avg,
		"rep_gain": rep_gain, "bonus_coins": bonus,
		"best_menu": best_menu, "best_menu_sales": best_sales,
		"ranking": ranking, "my_rank": my_rank,
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
	state.lifetime["sales"] = int(state.lifetime.get("sales", 0)) + sales
	state.lifetime["revenue"] = int(state.lifetime.get("revenue", 0)) + revenue
	state.lifetime["sessions"] = int(state.lifetime.get("sessions", 0)) + 1
	state.lifetime["perfect"] = int(state.lifetime.get("perfect", 0)) + result["perfect"]
	state.lifetime["burnt"] = int(state.lifetime.get("burnt", 0)) + result["burnt"]
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
