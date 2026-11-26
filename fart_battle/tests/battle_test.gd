extends RefCounted
## 방귀 대결 로직 테스트

const Logic := preload("res://scripts/core/battle_logic.gd")
const AI := preload("res://scripts/ai/ai_controller.gd")


func _logic(seed_value: int = 1, opp: int = 0):
	var l = Logic.new()
	l.setup(Data.player, Data.opponent(opp), Data.balance, Data.foods, seed_value)
	l.start_round()
	l.food_timer = 999.0
	return l


func _hold(l, side: int, seconds: float) -> Dictionary:
	l.press(side)
	var t := 0.0
	while t < seconds:
		l.tick(0.01)
		t += 0.01
	return l.release(side)


func _run(l, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not l.round_over:
		l.tick(0.02)
		t += 0.02


func test_perfect_release_is_stronger(t) -> void:
	var a = _logic()
	var fill := float(Data.balance["pressure_fill_time"])
	var weak: Dictionary = _hold(a, 0, fill * 0.4)
	t.ok(not weak["perfect"], "40% 압력은 완벽 아님")
	var b = _logic()
	var strong: Dictionary = _hold(b, 0, fill * 0.8)
	t.ok(strong["perfect"], "80% 압력은 완벽 구간")
	t.ok(float(strong["power"]) > float(weak["power"]) * 2.5, "완벽 방귀가 훨씬 셈")
	_run(a, 1.5)
	_run(b, 1.5)
	t.ok(b.cloud > a.cloud and a.cloud > 0.0, "빔이 상대 쪽으로 밀어냄 (%.2f > %.2f)" % [b.cloud, a.cloud])


func test_overcharge_blunder(t) -> void:
	var l = _logic()
	l.press(0)
	_run(l, float(Data.balance["pressure_fill_time"]) + float(Data.balance["overcharge_grace"]) + 0.2)
	t.ok(not l.fighters[0]["holding"], "너무 오래 참으면 강제로 끝남")
	t.ok(float(l.fighters[0]["stun_t"]) > 0.0, "삐끗 → 기절")
	t.eq(int(l.fighters[0]["stats"]["blunders"]), 1, "삐끗 기록")
	_run(l, 0.5)
	t.ok(l.cloud < 0.0, "삐끗하면 구름이 나에게 옴")
	t.ok(not l.press(0), "기절 중엔 못 뀜")


func test_gas_limits(t) -> void:
	var l = _logic()
	l.fighters[0]["gas"] = 2.0
	t.ok(not l.press(0), "가스가 거의 없으면 못 뀜")
	l.fighters[0]["gas"] = 20.0
	l.press(0)
	_run(l, 0.2)
	t.ok(float(l.fighters[0]["pressure"]) <= 20.0 / float(Data.balance["gas_cost_full"]) + 0.001, "가스만큼만 압력이 참")


func test_block_and_parry(t) -> void:
	var fill := float(Data.balance["pressure_fill_time"])
	var free_l = _logic()
	_hold(free_l, 1, fill * 0.8)
	_run(free_l, 1.5)
	var blk = _logic()
	blk.press(1)
	_run(blk, fill * 0.8 - 0.6)
	blk.block(0)
	_run(blk, 0.6)
	var r: Dictionary = blk.release(1)
	t.eq(r["result"], "blocked", "늦지 않게 막으면 막기")
	_run(blk, 1.5)
	t.ok(absf(blk.cloud) < absf(free_l.cloud) * 0.6, "막으면 덜 밀림 (%.2f < %.2f)" % [absf(blk.cloud), absf(free_l.cloud)])
	var par = _logic()
	par.press(1)
	_run(par, fill * 0.8 - 0.1)
	par.block(0)
	_run(par, 0.1)
	var pr: Dictionary = par.release(1)
	t.eq(pr["result"], "parry", "직전에 막으면 튕겨내기")
	_run(par, 0.5)
	t.ok(par.cloud > 0.0, "튕겨내면 상대 쪽으로 감")
	t.ok(not par.block(0), "쿨타임 중엔 다시 못 막음")


func test_foods(t) -> void:
	var l = _logic()
	var fd: Dictionary = l.spawn_food("beans", Vector2(0.5, 0.5))
	l.fighters[0]["gas"] = 10.0
	t.ok(l.eat(0, int(fd["uid"])), "콩 먹기")
	t.eq(float(l.fighters[0]["gas"]), 60.0, "가스 +50")
	t.ok(not l.eat(1, int(fd["uid"])), "먹은 음식은 사라짐")
	var c: Dictionary = l.spawn_food("chili", Vector2(0.5, 0.5))
	l.eat(0, int(c["uid"]))
	var r: Dictionary = _hold(l, 0, float(Data.balance["pressure_fill_time"]) * 0.8)
	t.ok(r["fire"], "고추 → 불꽃 빔")


func test_round_and_match(t) -> void:
	var l = _logic()
	l.cloud = 0.99
	l.cloud_vel = 1.0
	l.tick(0.05)
	t.ok(l.round_over and l.round_winner == 0, "상대 쪽 끝에 닿으면 승리")
	l.start_round()
	l.time_left = 0.01
	l.cloud = -0.3
	l.tick(0.05)
	t.eq(l.round_winner, 1, "시간 종료 시 구름이 먼 쪽이 승리")
	l.start_round()
	l.cloud = 1.5
	l.tick(0.01)
	t.ok(l.match_over, "2선승이면 경기 끝")


func _ai_match(opp: int, player_ai: Dictionary, seed_value: int) -> int:
	var l = Logic.new()
	var pdef: Dictionary = Data.player.duplicate(true)
	for k in player_ai.keys():
		pdef[k] = player_ai[k]
	l.setup(pdef, Data.opponent(opp), Data.balance, Data.foods, seed_value)
	var a0 = AI.new()
	a0.setup(l, 0, seed_value + 11)
	var a1 = AI.new()
	a1.setup(l, 1, seed_value + 23)
	var rounds := 0
	while not l.match_over and rounds < 7:
		l.start_round()
		rounds += 1
		var steps := 0
		while not l.round_over and steps < 3000:
			a0.tick(0.05)
			a1.tick(0.05)
			l.tick(0.05)
			steps += 1
	return l.match_winner


func test_ai_matches_finish_and_difficulty(t) -> void:
	var mid := {"ai_reaction": 0.4, "ai_accuracy": 0.12, "ai_aggression": 0.6, "ai_block": 0.35, "ai_greed": 0.5}
	var wins_easy := 0
	var wins_hard := 0
	var n := 20
	for i in n:
		if _ai_match(0, mid, i * 7 + 1) == 0:
			wins_easy += 1
		if _ai_match(4, mid, i * 7 + 1) == 0:
			wins_hard += 1
	print("    보통 AI 승률: 다람쥐 상대 %d/%d, 하마 대왕 상대 %d/%d" % [wins_easy, n, wins_hard, n])
	t.ok(wins_easy > wins_hard, "첫 상대가 마지막 상대보다 쉬움")
	t.ok(wins_easy >= n * 0.6, "첫 상대는 대부분 이김")
	t.ok(wins_hard <= n * 0.5, "챔피언은 어려움")


func test_state_readable_before_first_round(t) -> void:
	var l = Logic.new()
	l.setup(Data.player, Data.opponent(0), Data.balance, Data.foods, 1)
	t.ok(l.fighters[0].has("gas") and l.fighters[1].has("holding"), "라운드 시작 전에도 상태 값이 있음")
