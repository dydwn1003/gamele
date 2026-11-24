extends RefCounted
## 경제/정산/오프라인/상인/궁합 테스트 (GameState 를 새로 만들어 격리된 상태에서 검증)

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
	for id in ["dak_skewer", "eomuk_tang", "draft_beer", "cider"]:
		state.pocha["menus"][id] = GameStateScript.make_menu_entry(true, 0)
	progression = ProgressionScript.new()
	economy = EconomyScript.new()
	staff = StaffScript.new()
	offline = OfflineScript.new()
	progression.setup(state, DataManager)
	economy.setup(state, DataManager, staff)
	staff.setup(state, DataManager, economy, progression)
	offline.setup(state, DataManager)


func test_upgrade_reduces_coins(t) -> void:
	_fresh(500)
	var cost: int = economy.upgrade_cost()
	t.eq(cost, 500, "Lv.2 업그레이드 비용 500")
	var r: Dictionary = economy.upgrade_pocha(3)
	t.ok(r["ok"], "업그레이드 성공")
	t.eq(state.coins, 0, "코인이 업그레이드 비용만큼 감소")
	t.eq(state.pocha_level(), 2, "포차 Lv.2")
	var r2: Dictionary = economy.upgrade_pocha(3)
	t.ok(not r2["ok"], "코인 부족 시 실패 (연타해도 추가 차감 없음)")
	t.eq(state.coins, 0, "실패 시 코인 변화 없음")
	state.coins = 99999
	economy.upgrade_pocha(3)
	t.ok(not economy.upgrade_pocha(3)["ok"], "시장 단계 제한 (1단계 최대 Lv.3)")


func test_sales_revenue_cogs_net(t) -> void:
	_fresh(1000)
	t.ok(not economy.record_sale("dak_skewer", 120, 100.0), "영업 전에는 판매 기록 불가")
	economy.restock("dak_skewer")
	t.eq(state.stock_of("dak_skewer"), 15, "재료 최대 15 (Lv.1)")
	t.eq(state.coins, 1000 - 15 * 40, "재료 구매 시 원가 차감")
	state.coins = 0
	economy.begin_session(1, "cloudy")
	var price: int = economy.unit_price("dak_skewer")
	t.eq(price, 120, "기준 가격 120")
	for i in 3:
		t.ok(economy.consume_stock("dak_skewer"), "화구에 올릴 때 재료 사용")
		t.ok(economy.record_sale("dak_skewer", price, 100.0), "판매 %d 성공" % (i + 1))
	t.ok(economy.consume_stock("dak_skewer"), "4번째 재료 사용")
	economy.record_waste("dak_skewer", true)
	t.eq(economy.ledger["revenue"], 360, "총매출 = 판매 수량 × 판매 가격")
	t.eq(economy.ledger["cogs"], 120, "재료 원가 = 판매 수량 × 원가(40)")
	t.eq(economy.ledger["other_costs"], 40, "태운 요리는 기타 비용")
	t.eq(state.coins, 360, "판매 즉시 코인 증가")
	economy.record_tip(20)
	t.eq(state.coins, 380, "팁 지급")
	t.eq(state.stock_of("dak_skewer"), 11, "재고 = 15 - 사용 4")
	var res: Dictionary = economy.close_session(240.0)
	var spoil := int(floor(11 * float(DataManager.bal("spoilage_rate", 0.15))))
	t.eq(res["other_costs"], 40 + spoil * 40, "기타 비용 = 탄 요리 + 상한 재료")
	t.eq(res["net_profit"], 360 + 20 - 120 - (40 + spoil * 40), "순수익 = 매출 + 팁 - 원가 - 기타 비용")
	t.eq(res["burnt"], 1, "탄 요리 집계")
	var res2: Dictionary = economy.close_session(240.0)
	t.eq(res2["net_profit"], res["net_profit"], "영업 종료 중복 호출 시 동일 결과")
	t.eq(state.stock_of("dak_skewer"), 11 - spoil, "재고 손실은 한 번만 적용")
	t.ok(not economy.consume_stock("cider"), "재고 0이면 사용 불가")


func test_result_paid_once(t) -> void:
	_fresh(0)
	economy.begin_session(7, "cloudy")
	for i in 10:
		economy.record_sale("dak_skewer", 120, 100.0)
		economy.record_satisfaction(90.0)
	economy.record_buyer()
	var res: Dictionary = economy.close_session(240.0)
	var coins_before: int = state.coins
	var rep_before: int = state.reputation
	var c1: Dictionary = economy.claim_result()
	t.ok(c1["ok"], "첫 정산 성공")
	t.ok(int(res["rep_gain"]) > 0, "평판 획득")
	t.eq(state.reputation, rep_before + int(res["rep_gain"]), "평판 지급")
	t.eq(state.coins, coins_before + int(res["bonus_coins"]), "보너스 코인 지급")
	var coins_after: int = state.coins
	var rep_after: int = state.reputation
	for i in 5:
		t.ok(not economy.claim_result()["ok"], "중복 정산 거부 %d" % i)
	t.eq(state.coins, coins_after, "중복 정산 시 코인 변화 없음")
	t.eq(state.reputation, rep_after, "중복 정산 시 평판 변화 없음")
	var s2 = GameStateScript.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())), DataManager)
	var e2 = EconomyScript.new()
	e2.setup(s2, DataManager, null)
	t.ok(not e2.claim_result()["ok"], "재실행 후에도 중복 정산 불가")


func test_ranking_vs_rivals(t) -> void:
	_fresh(0)
	economy.begin_session(3, "cloudy")
	economy.record_sale("dak_skewer", 120, 100.0)
	for i in 3:
		economy.record_rival_sale("rival_bunsik", 130)
	economy.record_rival_sale("rival_juice", 90)
	var res: Dictionary = economy.close_session(240.0)
	t.eq(res["ranking"][0]["id"], "rival_bunsik", "매출 1위는 분식집")
	t.eq(res["my_rank"], 2, "내 포차 2위")
	t.eq(res["rival_buyers"], 4, "경쟁 노점 손님 수")
	t.eq(int(state.rivals["rival_bunsik"]["last_sales"]), 3, "라이벌 판매 기록 저장")


func test_offline_once_and_capped(t) -> void:
	_fresh(0)
	state.last_session = {"per_minute": 100.0}
	var t0 := 1_700_000_000.0
	state.last_seen_unix = t0
	state.max_seen_unix = t0
	var info: Dictionary = offline.compute_pending(t0 + 60 * 60)
	var expected := int(floor(100.0 * 60.0 * 0.35))
	t.eq(info["pending_amount"], expected, "60분 오프라인 = 분당 순수익 × 60 × 0.35")
	t.eq(offline.compute_pending(t0 + 60 * 60)["added"], 0, "같은 시각 재계산 시 추가 없음")
	t.eq(offline.claim(economy, t0 + 3600), expected, "수령액")
	t.eq(offline.claim(economy, t0 + 3600), 0, "두 번째 수령은 0")
	t.eq(state.coins, expected, "중복 지급 없음")
	var rb: Dictionary = offline.compute_pending(t0)
	t.ok(rb["rollback"], "시간 역행 감지")
	t.eq(offline.compute_pending(t0 + 3600)["added"], 0, "시각 복귀 후 중복 보상 없음")
	var far: Dictionary = offline.compute_pending(t0 + 3600 + 10 * 3600)
	t.eq(far["pending_minutes"], 240.0, "최대 240분")
	t.eq(far["pending_amount"], int(floor(100.0 * 240.0 * 0.35)), "최대 누적 보상")


func test_menu_price_unlock(t) -> void:
	_fresh(1000)
	economy.set_price_ratio("dak_skewer", 2.0)
	t.eq(float(state.menu_entry("dak_skewer")["price_ratio"]), 1.3, "가격 상한 130%")
	economy.set_price_ratio("dak_skewer", 0.1)
	t.eq(float(state.menu_entry("dak_skewer")["price_ratio"]), 0.8, "가격 하한 80%")
	t.ok(not economy.set_menu_enabled("gyeranmari", true, progression)["ok"], "Lv.1 에서 계란말이 잠김")
	state.pocha["level"] = 2
	t.ok(economy.set_menu_enabled("gyeranmari", true, progression)["ok"], "Lv.2 계란말이 해금")
	t.ok(state.is_menu_enabled("gyeranmari"), "메뉴판에 올라감")
	t.ok(not economy.set_menu_enabled("samgyeop_skewer", true, progression)["ok"], "삼겹살 꼬치는 평판 20 필요")
	t.ok(not economy.set_menu_enabled("haemul_jeon", true, progression)["ok"], "해물파전은 시장 2단계 필요")
	state.market_level = 2
	t.ok(economy.set_menu_enabled("haemul_jeon", true, progression)["ok"], "2단계에서 해물파전")
	for id in state.enabled_menus():
		if id != "cider":
			economy.set_menu_enabled(id, false)
	t.ok(not economy.set_menu_enabled("cider", false)["ok"], "마지막 메뉴는 내릴 수 없음")


func test_staff_working_slots(t) -> void:
	_fresh(5000)
	state.employees["emp_basic"] = {"hired": true, "level": 1}
	state.reputation = 999
	t.ok(staff.hire("emp_chef")["ok"], "해금 후 고용")
	t.ok(staff.set_working("emp_basic", true)["ok"], "기본 상인 근무")
	t.ok(not staff.set_working("emp_chef", true)["ok"], "Lv.1 근무 자리 1개 초과 불가")
	state.pocha["level"] = 3
	t.ok(staff.set_working("emp_chef", true)["ok"], "Lv.3 에서 2명 근무")
	staff.set_working("emp_chef", true)
	t.eq(state.staff_list().size(), 2, "같은 상인 중복 배치 안 됨")
	var fx: Dictionary = staff.pocha_effects()
	t.eq(float(fx["auto_cook"]), 1.0, "요리사 자동 요리 효과")
	var q1 := float(staff.effects_for("emp_chef")["auto_quality"])
	staff.level_up("emp_chef")
	t.ok(float(staff.effects_for("emp_chef")["auto_quality"]) > q1, "레벨업 시 자동 요리 품질 증가")
	staff.set_working("emp_chef", false)
	t.eq(float(staff.pocha_effects()["auto_cook"]), 0.0, "근무 해제 시 효과 없음")


func test_pairings(t) -> void:
	var syn = SynergyScript.new()
	syn.setup(DataManager)
	var r: Dictionary = syn.compute(["dak_skewer", "draft_beer", "cider"])
	t.ok((r["active"] as Array).has("chimaek"), "닭꼬치+생맥주 = 치맥")
	t.ok(float(r["effects"].get("drink_chance", 0.0)) > 0.0, "음료 주문 확률 효과")
	r = syn.compute(["dak_skewer", "cider"])
	t.ok(not (r["active"] as Array).has("chimaek"), "맥주가 없으면 치맥 없음")


func test_market_level_and_rivals(t) -> void:
	_fresh(0)
	t.eq(progression.active_rivals().size(), 3, "1단계 경쟁 노점 3곳")
	t.ok(not progression.active_rivals().has("rival_fire"), "불꽃꼬치는 아직 없음")
	state.reputation = 85
	t.eq(progression.update_market_level().size(), 1, "평판 80 이상 → 2단계")
	t.ok(progression.active_rivals().has("rival_fire"), "2단계에 불꽃꼬치 등장")
	state.reputation = 10
	progression.update_market_level()
	t.eq(state.market_level, 2, "단계는 내려가지 않음")
