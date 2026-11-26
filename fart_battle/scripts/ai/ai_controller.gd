extends RefCounted
## AIController — 컴퓨터 상대. 캐릭터 데이터의 ai_* 값으로 실력이 정해진다.
##   ai_reaction : 반응 속도(초, 작을수록 빠름)
##   ai_accuracy : 떼는 타이밍 오차 (작을수록 정확, 크면 삐끗도 함)
##   ai_aggression : 얼마나 자주 뀌는가
##   ai_block : 상대가 크게 모을 때 코를 막을 확률
##   ai_greed : 음식을 먹으러 가는 확률

var logic
var side: int = 1
var def: Dictionary = {}
var rng := RandomNumberGenerator.new()
var think_t: float = 0.6
var target_p: float = 0.8
var block_decided: bool = false
var food_plans: Dictionary = {} ## food uid -> 남은 반응 시간


func setup(p_logic, p_side: int, seed_value: int = -1) -> void:
	logic = p_logic
	side = p_side
	def = logic.fighters[side]["def"]
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func tick(delta: float) -> void:
	if logic.round_over:
		return
	var me: Dictionary = logic.fighters[side]
	var opp: Dictionary = logic.fighters[1 - side]
	_think_food(delta)
	if float(me["stun_t"]) > 0.0:
		return
	_think_block(opp)
	if me["holding"]:
		if float(me["pressure"]) >= target_p or (target_p > 1.0 and false):
			logic.release(side)
		return
	think_t -= delta
	if think_t > 0.0:
		return
	var reaction := float(def.get("ai_reaction", 0.5))
	think_t = reaction * rng.randf_range(0.6, 1.4)
	# 구름이 내 쪽에 가까우면 더 급해진다
	var danger := clampf(-logic.cloud * logic.direction(side), 0.0, 1.0)
	var want := float(def.get("ai_aggression", 0.5)) + danger * 0.5
	var sweet: Vector2 = logic.sweet_range(side)
	var center := (sweet.x + sweet.y) / 2.0
	if logic.max_pressure(side) < center * 0.8 and danger < 0.6:
		return # 가스를 모으며 기다림
	if rng.randf() > want:
		return
	var noise := rng.randf_range(-1.0, 1.0) * float(def.get("ai_accuracy", 0.15)) * 2.0
	target_p = center + noise
	# 가스가 부족하면 있는 만큼만
	target_p = minf(target_p, logic.max_pressure(side) + 0.6) if target_p > 1.0 else minf(target_p, logic.max_pressure(side))
	if target_p > 1.0:
		target_p = 9.0 # 욕심내다 삐끗
	logic.press(side)


func _think_block(opp: Dictionary) -> void:
	if not opp["holding"]:
		block_decided = false
		return
	if block_decided:
		return
	var sweet: Vector2 = logic.sweet_range(1 - side)
	var p := float(opp["pressure"])
	# 상대가 완벽 구간 직전까지 모았을 때 한 번 판단
	if p >= sweet.x - 0.15:
		block_decided = true
		var chance := float(def.get("ai_block", 0.3))
		var danger := clampf(-logic.cloud * logic.direction(side), 0.0, 1.0)
		if rng.randf() < chance * (0.6 + danger):
			logic.block(side)


func _think_food(delta: float) -> void:
	for fd in logic.foods:
		var uid := int(fd["uid"])
		if not food_plans.has(uid):
			if rng.randf() < float(def.get("ai_greed", 0.5)):
				food_plans[uid] = float(def.get("ai_reaction", 0.5)) * rng.randf_range(1.6, 3.2)
			else:
				food_plans[uid] = -1.0
		elif float(food_plans[uid]) > 0.0:
			food_plans[uid] = float(food_plans[uid]) - delta
			if float(food_plans[uid]) <= 0.0:
				logic.eat(side, uid)
				return
