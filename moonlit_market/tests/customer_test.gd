extends RefCounted
## 손님 선택 로직(순수 함수) + 실제 시장 장면을 띄운 영업 시뮬레이션 통합 테스트

const CustomerAI := preload("res://scripts/customer/customer_ai.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const MarketScene := preload("res://scenes/market/market.tscn")


func _ct(id: String) -> Dictionary:
	var d: Dictionary = DataManager.get_customer_type(id).duplicate(true)
	d["id"] = id
	return d


func _ctx(extra: Dictionary = {}) -> Dictionary:
	var c := {"price_ratio": 1.0, "price_tolerance": 0.0, "stall_rep": 10.0, "market_rep": 0.0,
		"queue_len": 0, "queue_cap": 4, "distance": 200.0, "weather": DataManager.get_weather("cloudy"),
		"trend_menu": "", "trend_mult": 1.0, "appeal": 0.0, "budget": 1000.0, "sold_out": false, "visited": false}
	for k in extra.keys():
		c[k] = extra[k]
	return c


func test_types_prefer_differently(t) -> void:
	var office := _ct("office_worker")
	var student := _ct("student")
	var noodle := DataManager.get_menu("noodle")
	var bubble := DataManager.get_menu("bubble_tea")
	t.ok(CustomerAI.stall_score(office, noodle, _ctx()) > CustomerAI.stall_score(office, bubble, _ctx()), "직장인은 식사류(국수) 선호")
	t.ok(CustomerAI.stall_score(student, bubble, _ctx()) > CustomerAI.stall_score(student, noodle, _ctx()), "학생은 음료(버블티) 선호")


func test_price_affects_behavior(t) -> void:
	var student := _ct("student")
	var menu := DataManager.get_menu("tteokbokki")
	var cheap := CustomerAI.stall_score(student, menu, _ctx({"price_ratio": 0.8}))
	var normal := CustomerAI.stall_score(student, menu, _ctx({"price_ratio": 1.0}))
	var pricey := CustomerAI.stall_score(student, menu, _ctx({"price_ratio": 1.3}))
	t.ok(cheap > normal and normal > pricey, "가격이 높을수록 선택 확률 감소")
	var p_hi := CustomerAI.purchase_probability(student, 1.3, 0.0, 1.0, 0.97, 1.3)
	var p_lo := CustomerAI.purchase_probability(student, 0.9, 0.0, 1.0, 0.97, 1.3)
	t.ok(p_lo > p_hi, "가격이 높을수록 구매 확률 감소")
	var s_hi := CustomerAI.satisfaction(student, 1.2, 1.3, 5.0, 0.0, 68.0, 0.9)
	var s_lo := CustomerAI.satisfaction(student, 1.2, 0.9, 5.0, 0.0, 68.0, 0.9)
	t.ok(s_lo > s_hi, "가격이 높을수록 만족도 감소")
	var tourist := _ct("tourist")
	var p_tour := CustomerAI.purchase_probability(tourist, 1.3, 0.0, 1.0, 0.97, 1.3)
	t.ok(p_tour > p_hi, "관광객은 학생보다 가격에 덜 민감")


func test_blocked_choices(t) -> void:
	var office := _ct("office_worker")
	var menu := DataManager.get_menu("skewer_grill")
	t.eq(CustomerAI.stall_score(office, menu, _ctx({"queue_len": 4, "queue_cap": 4})), 0.0, "대기열 가득 → 선택 불가")
	t.eq(CustomerAI.stall_score(office, menu, _ctx({"sold_out": true})), 0.0, "품절 → 선택 불가")
	t.eq(CustomerAI.stall_score(office, menu, _ctx({"budget": 50.0})), 0.0, "예산 초과 → 선택 불가")
	var short_q := CustomerAI.stall_score(office, menu, _ctx({"queue_len": 0}))
	var long_q := CustomerAI.stall_score(office, menu, _ctx({"queue_len": 3}))
	t.ok(short_q > long_q, "대기열이 길면 선택 확률 감소")
	var rainy := CustomerAI.stall_score(office, menu, _ctx({"weather": DataManager.get_weather("rain")}))
	t.ok(rainy > short_q, "비 오는 날 따뜻한 음식 수요 증가")


func test_choice_is_probabilistic(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := {0: 0, 1: 0, -1: 0}
	for i in 3000:
		var pick := CustomerAI.choose([{"slot": 0, "score": 2.0}, {"slot": 1, "score": 1.0}], 0.35, rng)
		counts[pick] += 1
	t.ok(counts[0] > counts[1], "점수가 높은 노점이 더 자주 선택")
	t.ok(counts[1] > 300, "낮은 점수 노점도 선택됨 (모두 한 곳으로 몰리지 않음)")
	t.ok(counts[-1] > 0, "아무것도 사지 않는 손님도 존재")
	var tourists := 0
	var tourists_boost := 0
	for i in 3000:
		if CustomerAI.pick_type(DataManager.customers, 1.0, rng) == "tourist":
			tourists += 1
		if CustomerAI.pick_type(DataManager.customers, 3.0, rng) == "tourist":
			tourists_boost += 1
	t.ok(tourists_boost > tourists, "관광객 배수가 관광객 비율을 높임")


## 실제 market.tscn 을 띄우고 240초 영업을 고정 간격으로 시뮬레이션
func test_full_session_simulation(t) -> void:
	GameManager.reset_game()
	var st = GameManager.state
	st.coins = 0
	st.slots[1] = GameStateScript.make_stall("skewer", "skewer_grill", 20, 10.0)
	st.slots[4] = GameStateScript.make_stall("drink", "lemonade", 20, 10.0)
	st.slots[4]["level"] = 1
	st.today_weather = "sunny"
	GameManager.refresh_synergy()
	var tree: SceneTree = Engine.get_main_loop()
	var market = MarketScene.instantiate()
	tree.root.add_child(market)
	await tree.process_frame
	var op = market.operating
	op.set_process(false) # 수동으로 시간 진행
	t.ok(op.start_session(), "영업 시작")
	t.ok(GameManager.is_operating, "영업 중 상태")
	t.ok(not GameManager.build_structure(0, "drink")["ok"], "영업 중 건설 차단")
	var stock_before := int(st.slots[1]["stock"]) + int(st.slots[4]["stock"])
	var out_of_bounds := 0
	var max_customers := 0
	var states_seen := {}
	var steps := 0
	while op.is_running() and steps < 4000:
		op._process(0.1)
		steps += 1
		for c in market.customer_manager.customers:
			if not is_instance_valid(c):
				continue
			states_seen[c.state_name()] = true
			var p: Vector2 = c.position
			if p.x < 0.0 or p.x > 720.0 or p.y < 0.0 or p.y > 960.0:
				out_of_bounds += 1
		max_customers = maxi(max_customers, market.customer_manager.customers.size())
	t.ok(not op.is_running(), "영업 종료 (%d 스텝)" % steps)
	t.ok(not GameManager.is_operating, "영업 상태 해제")
	var r: Dictionary = st.pending_result
	t.ok(not r.is_empty(), "정산 결과 생성")
	t.ok(int(r.get("visitors", 0)) > 20, "손님 방문 (%d명)" % int(r.get("visitors", 0)))
	t.ok(int(r.get("sales", 0)) > 0, "판매 발생 (%d개)" % int(r.get("sales", 0)))
	t.eq(st.coins, int(r.get("revenue", 0)), "코인 증가 = 총매출 (재료비는 선결제)")
	var stock_after := int(st.slots[1]["stock"]) + int(st.slots[4]["stock"])
	t.eq(stock_before - stock_after, int(r["sales"]) + int(r["spoiled"]), "재고 감소 = 판매 + 손실")
	t.eq(int(r["cogs"]), int(st.slots[1]["stats"]["sold_total"]) * 40 + int(st.slots[4]["stats"]["sold_total"]) * 25, "원가 = 판매분 × 메뉴 원가")
	t.eq(out_of_bounds, 0, "손님이 시장 밖으로 나가지 않음")
	t.ok(max_customers <= int(DataManager.bal("max_customers", 34)), "동시 손님 수 제한")
	for sname in ["ENTERING", "BROWSING", "SELECTING", "QUEUING", "SERVING", "LEAVING"]:
		t.ok(states_seen.has(sname), "손님 상태 %s 관찰" % sname)
	t.ok(int(r["buyers"]) + int(r["walkouts"]) <= int(r["visitors"]), "구매+이탈 ≤ 방문")
	# 정산은 한 번만
	var coins := int(st.coins)
	var c1: Dictionary = GameManager.claim_session_result()
	t.ok(c1.get("ok", false), "정산 수령")
	var coins_after := int(st.coins)
	t.eq(coins_after, coins + int(r["bonus_coins"]), "보너스만 추가 지급")
	GameManager.claim_session_result()
	GameManager.claim_session_result()
	t.eq(int(st.coins), coins_after, "정산 버튼 반복 시 중복 지급 없음")
	t.ok(float(st.last_session.get("per_minute", -1.0)) >= 0.0, "오프라인 기준 기록")
	market.queue_free()
	await tree.process_frame
	GameManager.reset_game()
