extends RefCounted
## 경제/정산/오프라인 테스트 (GameState 를 새로 만들어 격리된 상태에서 검증)

const GameStateScript := preload("res://scripts/core/game_state.gd")
const EconomyScript := preload("res://scripts/core/economy_manager.gd")
const ProgressionScript := preload("res://scripts/core/progression_manager.gd")
const StaffScript := preload("res://scripts/staff/staff_manager.gd")
const OfflineScript := preload("res://scripts/core/offline_manager.gd")
const SynergyScript := preload("res://scripts/market/synergy_manager.gd")

var state
var economy
var staff
var progression
var offline


func _fresh(coins: int = 500) -> void:
	state = GameStateScript.new()
	state.reset_empty()
	state.coins = coins
	progression = ProgressionScript.new()
	economy = EconomyScript.new()
	staff = StaffScript.new()
	offline = OfflineScript.new()
	progression.setup(state, DataManager)
	economy.setup(state, DataManager, staff)
	staff.setup(state, DataManager, economy, progression)
	offline.setup(state, DataManager)


func test_build_reduces_coins(t) -> void:
	_fresh(500)
	var cost := int(DataManager.get_stall("drink")["build_cost"])
	var r: Dictionary = economy.build_stall(0, "drink")
	t.ok(r["ok"], "노점 구매 성공")
	t.eq(state.coins, 500 - cost, "코인이 건설비만큼 감소")
	var r2: Dictionary = economy.build_stall(0, "skewer")
	t.ok(not r2["ok"], "같은 자리 중복 건설 실패")
	t.eq(state.coins, 500 - cost, "중복 클릭 시 코인 추가 차감 없음")
	state.coins = 10
	var r3: Dictionary = economy.build_stall(1, "dessert")
	t.ok(not r3["ok"], "코인 부족 시 실패")
	t.eq(state.coins, 10, "실패 시 코인 변화 없음")
	t.ok(state.is_slot_empty(1), "실패 시 슬롯 비어 있음")


func test_sales_revenue_cogs_net(t) -> void:
	_fresh(0)
	state.slots[1] = GameStateScript.make_stall("skewer", "skewer_grill", 20, 10.0)
	t.ok(not economy.record_sale(1, 110, 70.0), "영업 전에는 판매 기록 불가")
	economy.begin_session(1, "cloudy")
	var price: int = economy.unit_price(1)
	t.eq(price, 110, "기준 가격 110")
	for i in 3:
		t.ok(economy.record_sale(1, price, 80.0), "판매 %d 성공" % (i + 1))
	t.eq(economy.ledger["revenue"], 330, "총매출 = 판매 수량 × 판매 가격")
	t.eq(economy.ledger["cogs"], 120, "재료 원가 = 판매 수량 × 메뉴 원가(40)")
	t.eq(state.coins, 330, "판매 즉시 코인 증가")
	t.eq(int(state.slots[1]["stock"]), 17, "판매 수량만큼 재고 감소")
	var res: Dictionary = economy.close_session(240.0)
	var spoil := int(floor(17 * float(DataManager.bal("spoilage_rate", 0.15))))
	t.eq(res["other_costs"], spoil * 40, "기타 비용 = 재고 손실 × 원가")
	t.eq(res["net_profit"], 330 - 120 - spoil * 40, "순수익 = 총매출 - 원가 - 기타 비용")
	t.eq(int(state.slots[1]["stock"]), 17 - spoil, "재고 손실 반영")
	var res2: Dictionary = economy.close_session(240.0)
	t.eq(res2["net_profit"], res["net_profit"], "영업 종료 중복 호출 시 동일 결과")
	t.eq(int(state.slots[1]["stock"]), 17 - spoil, "재고 손실은 한 번만 적용")


func test_result_paid_once(t) -> void:
	_fresh(0)
	state.slots[0] = GameStateScript.make_stall("skewer", "skewer_grill", 20, 10.0)
	economy.begin_session(7, "cloudy")
	for i in 10:
		economy.record_sale(0, 110, 90.0)
	var res: Dictionary = economy.close_session(240.0)
	var coins_before: int = state.coins
	var rep_before: int = state.reputation
	var c1: Dictionary = economy.claim_result()
	t.ok(c1["ok"], "첫 정산 성공")
	t.eq(state.reputation, rep_before + int(res["rep_gain"]), "평판 지급")
	t.eq(state.coins, coins_before + int(res["bonus_coins"]), "보너스 코인 지급")
	var coins_after: int = state.coins
	var rep_after: int = state.reputation
	for i in 5:
		var c2: Dictionary = economy.claim_result()
		t.ok(not c2["ok"], "중복 정산 거부 %d" % i)
	t.eq(state.coins, coins_after, "중복 정산 시 코인 변화 없음")
	t.eq(state.reputation, rep_after, "중복 정산 시 평판 변화 없음")
	# 세이브/로드 후에도 다시 받을 수 없음
	var d: Dictionary = state.to_dict()
	var s2 = GameStateScript.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)), DataManager)
	var e2 = EconomyScript.new()
	e2.setup(s2, DataManager, null)
	t.ok(not e2.claim_result()["ok"], "재실행 후에도 중복 정산 불가")


func test_offline_once_and_capped(t) -> void:
	_fresh(0)
	state.last_session = {"per_minute": 100.0}
	var t0 := 1_700_000_000.0
	state.last_seen_unix = t0
	state.max_seen_unix = t0
	var info: Dictionary = offline.compute_pending(t0 + 60 * 60)
	var expected := int(floor(100.0 * 60.0 * 0.35))
	t.eq(info["pending_amount"], expected, "60분 오프라인 = 분당 순수익 × 60 × 0.35")
	var again: Dictionary = offline.compute_pending(t0 + 60 * 60)
	t.eq(again["added"], 0, "같은 시각 재계산 시 추가 없음")
	var paid: int = offline.claim(economy, t0 + 3600)
	t.eq(paid, expected, "수령액")
	t.eq(state.coins, expected, "코인 지급")
	t.eq(offline.claim(economy, t0 + 3600), 0, "두 번째 수령은 0")
	t.eq(state.coins, expected, "중복 지급 없음")
	# 시간을 과거로 되돌림
	var rb: Dictionary = offline.compute_pending(t0)
	t.ok(rb["rollback"], "시간 역행 감지")
	t.eq(int(state.offline["pending_amount"]), 0, "시간 역행 시 보상 없음")
	# 다시 원래 시각으로 돌아와도 이미 계산된 구간은 재지급 안 됨
	var back: Dictionary = offline.compute_pending(t0 + 3600)
	t.eq(back["added"], 0, "시각 복귀 후 중복 보상 없음")
	# 최대 240분 제한
	var far: Dictionary = offline.compute_pending(t0 + 3600 + 10 * 3600)
	t.eq(far["pending_minutes"], 240.0, "최대 240분")
	t.eq(far["pending_amount"], int(floor(100.0 * 240.0 * 0.35)), "최대 누적 보상")


func test_price_restock_menu(t) -> void:
	_fresh(1000)
	state.slots[0] = GameStateScript.make_stall("skewer", "skewer_grill", 5, 10.0)
	economy.set_price_ratio(0, 2.0)
	t.eq(float(state.slots[0]["price_ratio"]), 1.3, "가격 상한 130%")
	economy.set_price_ratio(0, 0.1)
	t.eq(float(state.slots[0]["price_ratio"]), 0.8, "가격 하한 80%")
	economy.set_price_ratio(0, 1.0)
	var cost: int = economy.restock_cost(0)
	t.eq(cost, 15 * 40, "재고 15개 × 원가 40")
	economy.restock(0)
	t.eq(state.coins, 1000 - cost, "재고 구매 시 원가 차감")
	t.eq(int(state.slots[0]["stock"]), 20, "최대 재고 20")
	t.ok(not economy.restock(0)["ok"], "가득 차면 구매 불가")
	t.ok(not economy.set_menu(0, "twigim")["ok"], "Lv.1 에서 튀김 잠김")
	state.slots[0]["level"] = 2
	var coins_before: int = state.coins
	var r: Dictionary = economy.set_menu(0, "twigim")
	t.ok(r["ok"], "Lv.2 메뉴 변경")
	t.eq(state.coins, coins_before + 20 * 40, "남은 재고는 기존 원가로 환급")
	t.eq(int(state.slots[0]["stock"]), 0, "메뉴 변경 후 재고 0")
	state.coins = 0
	t.ok(not economy.restock(0)["ok"], "코인 0이면 재고 구매 불가")


func test_staff_exclusive_assignment(t) -> void:
	_fresh(5000)
	state.slots[0] = GameStateScript.make_stall("skewer", "skewer_grill", 5, 10.0)
	state.slots[1] = GameStateScript.make_stall("drink", "lemonade", 5, 10.0)
	state.employees["emp_basic"] = {"hired": true, "level": 1}
	staff.assign("emp_basic", 0)
	staff.assign("emp_basic", 1)
	t.eq(state.slots[0]["employee"], "", "이전 노점에서 해제")
	t.eq(state.slots[1]["employee"], "emp_basic", "새 노점에 배치")
	t.ok(not staff.hire("emp_grandma")["ok"], "해금 전 고용 불가")
	state.reputation = 999
	t.ok(staff.hire("emp_chef")["ok"], "해금 후 고용")
	var e1: float = staff.effects_for("emp_chef")["cook_speed"]
	staff.level_up("emp_chef")
	t.ok(staff.effects_for("emp_chef")["cook_speed"] > e1, "레벨업 시 능력 증가")


func test_synergy(t) -> void:
	var syn = SynergyScript.new()
	syn.setup(DataManager)
	var slots: Array = [{}, {}, {}, {}, {}, {}]
	slots[0] = GameStateScript.make_stall("skewer", "skewer_grill", 5, 10.0)
	slots[1] = GameStateScript.make_stall("drink", "lemonade", 5, 10.0)
	var r: Dictionary = syn.compute(slots)
	t.ok((r["active"] as Array).has("skewer_drink"), "꼬치+음료 인접 시너지")
	t.eq(SynergyScript.follow_ups(r, 0).size(), 1, "꼬치 노점에 음료 연계 효과")
	slots[1] = {}
	slots[2] = GameStateScript.make_stall("drink", "lemonade", 5, 10.0)
	r = syn.compute(slots)
	t.ok(not (r["active"] as Array).has("skewer_drink"), "인접하지 않으면 시너지 없음")
	slots[3] = GameStateScript.make_facility("photo_zone")
	slots[0] = GameStateScript.make_stall("dessert", "hotteok", 5, 10.0)
	r = syn.compute(slots)
	t.ok((r["active"] as Array).has("dessert_photo"), "디저트+포토존 (통로 건너편)")
	t.ok(float(r["global"].get("tourist_mult", 0.0)) > 0.0, "관광객 증가 전역 효과")


func test_market_level_up(t) -> void:
	_fresh(0)
	state.reputation = 85
	var ups: Array = progression.update_market_level()
	t.eq(state.market_level, 2, "평판 80 이상 → 2단계")
	t.eq(ups.size(), 1, "단계 상승 1회")
	state.reputation = 10
	progression.update_market_level()
	t.eq(state.market_level, 2, "단계는 내려가지 않음")
	t.ok(progression.is_facility_unlocked("photo_zone"), "2단계에서 포토존 해금")
