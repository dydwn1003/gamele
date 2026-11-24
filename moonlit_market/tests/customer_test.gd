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


func _setup_state() -> void:
	GameManager.reset_game()
	var st = GameManager.state
	st.coins = 0
	for id in ["dak_skewer", "eomuk_tang", "draft_beer", "cider"]:
		st.pocha["menus"][id] = GameStateScript.make_menu_entry(true, 15)
	st.today_weather = "sunny"
	st.tutorial_done = true
	GameManager.refresh_synergy()


## 플레이어 대신 일하는 봇: 주문된 음식을 굽고, 딱 좋을 때 꺼내고, 음료를 따르고,
## 손님을 탭해 서빙하고, 빈 테이블을 치운다 (실제 플레이와 같은 API 사용)
func _bot_play(pm) -> void:
	for i in pm.kitchen.burners.size():
		if i == pm.auto_burner:
			continue
		if pm.kitchen.needs_flip(i):
			var f: Dictionary = pm.kitchen.burners[i]["flip"]
			if pm.kitchen.ratio(i) >= (float(f["good_min"]) + float(f["good_max"])) / 2.0:
				pm.tap_burner(i)
		elif pm.kitchen.stage(i) == "perfect" and pm.pass_space() > 0:
			pm.tap_burner(i)
	for i in pm.seat_state.size():
		var st: Dictionary = pm.seat_state[i]
		if st["state"] == "dirty":
			pm.tap_seat(i)
		elif pm.seats[i] != null and is_instance_valid(pm.seats[i]) and pm.seats[i].can_receive():
			if pm.pass_has_for(pm.seats[i], pm.server.tray) or pm.server.tray_has_for(pm.seats[i]):
				pm.tap_seat(i)
	var making := {}
	for b in pm.kitchen.burners:
		if b["menu"] != "":
			making[b["menu"]] = int(making.get(b["menu"], 0)) + 1
	for p in pm.pass_items:
		making[p["menu"]] = int(making.get(p["menu"], 0)) + 1
	for it in pm.server.tray:
		making[it["menu"]] = int(making.get(it["menu"], 0)) + 1
	for o in pm.orders:
		var m: String = o["menu"]
		if not o["customer"].can_receive():
			continue
		if int(making.get(m, 0)) > 0:
			making[m] = int(making[m]) - 1
			continue
		var station := str(DataManager.get_menu(m).get("station", ""))
		if station == "drink" or station == "mix":
			if pm.pour_start(m).get("ok", false):
				if station == "mix":
					pm.pour_finish_mix(m, 0.28, 0.86)
				else:
					pm.pour_finish(m, 0.85)
			return
		if pm.cook(m).get("ok", false):
			return


func _run_session(t, cook: bool) -> Dictionary:
	_setup_state()
	var st = GameManager.state
	var tree: SceneTree = Engine.get_main_loop()
	var market = MarketScene.instantiate()
	tree.root.add_child(market)
	await tree.process_frame
	t.ok(market.is_inside_tree(), "시장 장면 생성")
	var op = market.operating
	op.set_process(false)
	t.ok(op.start_session(), "영업 시작")
	t.ok(GameManager.is_operating, "영업 중 상태")
	t.ok(not GameManager.upgrade_pocha()["ok"], "영업 중 업그레이드 차단")
	var out_of_bounds := 0
	var states_seen := {}
	var eaters_at_spots := 0
	var steps := 0
	while op.is_running() and steps < 4000:
		op._process(0.1)
		if cook:
			_bot_play(market.pocha_manager)
		steps += 1
		for c in market.customer_manager.customers:
			if not is_instance_valid(c):
				continue
			states_seen[c.state_name()] = true
			if c.state_name() == "EATING" and c.eat_spot >= 0 and c.arrived:
				eaters_at_spots += 1
			var p: Vector2 = c.position
			if p.x < 0.0 or p.x > 720.0 or p.y < 40.0 or p.y > 720.0:
				out_of_bounds += 1
	t.ok(not op.is_running(), "영업 종료 (%d 스텝)" % steps)
	t.eq(out_of_bounds, 0, "손님이 시장 밖으로 나가지 않음")
	var r: Dictionary = st.pending_result.duplicate(true)
	print("    [%s] 방문 %d · 내 포차 %d · 경쟁 %d · 이탈 %d · 판매 %d · 완벽 %d · 품질 %.0f · 매출 %d · 팁 %d · 순수익 %d · 만족 %.0f · 순위 %d" % [
		"요리" if cook else "방치", int(r.get("visitors", 0)), int(r.get("buyers", 0)), int(r.get("rival_buyers", 0)), int(r.get("walkouts", 0)),
		int(r.get("sales", 0)), int(r.get("perfect", 0)), float(r.get("avg_quality", 0)), int(r.get("revenue", 0)), int(r.get("tips", 0)),
		int(r.get("net_profit", 0)), float(r.get("avg_satisfaction", 0)), int(r.get("my_rank", 0))])
	market.queue_free()
	await tree.process_frame
	return {"r": r, "states": states_seen, "eaters": eaters_at_spots}


## 실제 market.tscn 을 띄우고 240초 영업을 봇이 요리하며 시뮬레이션
func test_full_session_with_cooking(t) -> void:
	var out: Dictionary = await _run_session(t, true)
	var r: Dictionary = out["r"]
	var st = GameManager.state
	t.ok(not r.is_empty(), "정산 결과 생성")
	t.ok(int(r.get("visitors", 0)) > 30, "손님 방문 (%d명)" % int(r.get("visitors", 0)))
	t.ok(int(r.get("buyers", 0)) > 3, "내 포차 손님 (%d명)" % int(r.get("buyers", 0)))
	t.ok(int(r.get("rival_buyers", 0)) > 3, "경쟁 노점 손님 (%d명)" % int(r.get("rival_buyers", 0)))
	t.ok(int(r.get("sales", 0)) > 5, "판매 (%d개)" % int(r.get("sales", 0)))
	t.ok(int(r.get("perfect", 0)) > 0, "완벽한 요리 (%d개)" % int(r.get("perfect", 0)))
	t.eq(int(r.get("burnt", 0)), 0, "봇은 태우지 않음")
	t.eq(st.coins, int(r["revenue"]) + int(r["tips"]), "코인 증가 = 매출 + 팁 (재료비는 선결제)")
	t.ok((r.get("ranking", []) as Array).size() >= 2, "경쟁 노점과 순위 비교")
	for sname in ["ENTERING", "BROWSING", "SELECTING", "QUEUING", "SERVING", "SEATED", "EATING", "LEAVING"]:
		t.ok(out["states"].has(sname), "손님 상태 %s 관찰" % sname)
	t.ok(int(out["eaters"]) > 0, "경쟁 노점 손님이 거리 테이블에서 먹음")
	t.ok(int(r.get("tips", 0)) > 0, "테이블을 치워서 팁 수령 (%d)" % int(r.get("tips", 0)))
	t.ok(int(r["buyers"]) + int(r["rival_buyers"]) + int(r["walkouts"]) <= int(r["visitors"]) + int(r["buyers"]), "집계 일관성")
	var coins := int(st.coins)
	t.ok(GameManager.claim_session_result().get("ok", false), "정산 수령")
	var coins_after := int(st.coins)
	t.eq(coins_after, coins + int(r["bonus_coins"]) + int(r["goal_coins"]) + int(r.get("showdown", {}).get("coins", 0)), "보너스 + 목표 보상만 추가 지급")
	t.eq((r.get("goals", []) as Array).size(), 3, "오늘의 목표 3개 판정")
	GameManager.claim_session_result()
	GameManager.claim_session_result()
	t.eq(int(st.coins), coins_after, "정산 버튼 반복 시 중복 지급 없음")
	t.ok(float(st.last_session.get("per_minute", -1.0)) >= 0.0, "오프라인 기준 기록")
	GameManager.reset_game()


## 요리를 하나도 안 하면 손님이 기다리다 떠난다
func test_session_without_cooking(t) -> void:
	var out: Dictionary = await _run_session(t, false)
	var r: Dictionary = out["r"]
	t.ok(int(r.get("walkouts", 0)) > 0, "음식이 안 나오면 이탈 (%d명)" % int(r.get("walkouts", 0)))
	t.eq(int(r.get("perfect", 0)), 0, "요리하지 않으면 완벽한 요리 없음")
	GameManager.reset_game()


## 특별 손님: 회식 단체·평론가·취객·인플루언서가 실제로 와서 행동한다
func test_special_customers(t) -> void:
	_setup_state()
	GameManager.state.day = 5
	var tree: SceneTree = Engine.get_main_loop()
	var market = MarketScene.instantiate()
	tree.root.add_child(market)
	await tree.process_frame
	var op = market.operating
	op.set_process(false)
	op.start_session()
	var cm = market.customer_manager
	var spawned := {}
	for id in ["group", "critic", "drunk", "influencer"]:
		var c = cm.spawn_customer("", id)
		spawned[id] = c
		t.eq(c.special_id, id, "특별 손님 생성: %s" % id)
	var group_items := 0
	var group_seen := false
	var dozed := false
	for step in 3200:
		op._process(0.1)
		_bot_play(market.pocha_manager)
		for id in spawned.keys():
			var c = spawned[id]
			if not is_instance_valid(c):
				continue
			if id == "group" and c.ordered and c.rounds == 1 and not group_seen:
				group_seen = true
				group_items = c.pending.size() + c.served_items.size()
			if id == "drunk" and c.doze_t > 0.0:
				dozed = true
		if not op.is_running():
			break
	var r: Dictionary = GameManager.state.pending_result
	t.ok(group_items >= 2, "회식 단체는 한 번에 여러 개 주문 (%d)" % group_items)
	t.ok(int(r.get("specials_served", 0)) >= 2, "특별 손님 대접 (%d명)" % int(r.get("specials_served", 0)))
	t.ok(r.has("critic_rep"), "평론가 평가 기록")
	market.queue_free()
	await tree.process_frame
	GameManager.reset_game()


## 회귀: 주방 UI 에서 뒤집기 탭 시 오류 없이 처리
func test_kitchen_ui_flip_tap(t) -> void:
	_setup_state()
	var tree: SceneTree = Engine.get_main_loop()
	var market = MarketScene.instantiate()
	tree.root.add_child(market)
	await tree.process_frame
	var op = market.operating
	op.set_process(false)
	op.start_session()
	var KitchenUI = load("res://scripts/ui/kitchen_ui.gd")
	var ui = KitchenUI.new()
	tree.root.add_child(ui)
	ui.bind(market.pocha_manager)
	var pm = market.pocha_manager
	t.ok(pm.cook("dak_skewer")["ok"], "닭꼬치 올리기")
	for i in 30:
		op._process(0.1)
	t.ok(pm.kitchen.needs_flip(0), "뒤집기 필요")
	ui._on_burner(0)
	t.ok(not pm.kitchen.needs_flip(0), "UI 탭으로 뒤집음")
	t.ok(ui.status_label.text.contains("뒤집기"), "뒤집기 안내 표시")
	ui.queue_free()
	market.queue_free()
	await tree.process_frame
	GameManager.reset_game()
