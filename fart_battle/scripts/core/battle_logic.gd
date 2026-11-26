extends RefCounted
## BattleLogic — 방귀 대결 규칙 (화면과 분리된 순수 로직, 테스트 가능)
##
## side 0 = 아래(플레이어), side 1 = 위(상대).
## cloud: 두 방귀 빔이 부딪히는 지점. -1 = side 0 엉덩이 앞, +1 = side 1 엉덩이 앞.
## 상대 쪽 끝까지 밀어붙이면 라운드 승리.
## 방귀는 일정 시간 빔을 뿜으며 부딪힘 지점에 힘을 준다 (빔 대결). 지점은 마찰로 서서히 멈춘다.
##
## 뿡 버튼을 누르고 있으면 압력이 차오른다. 떼는 순간 압력만큼 방귀.
##   - 완벽 구간(sweet)에서 떼면 파워 ×1.6
##   - 가득 찬 뒤 너무 오래 참으면 삐끗: 기절 + 구름이 나에게 밀려옴
## 코 막기: 상대 방귀 대부분을 막음. 상대가 뀌기 직전에 막으면 튕겨내기(반사).

var bal: Dictionary = {}
var fighters: Array = []
var cloud: float = 0.0
var cloud_vel: float = 0.0
var time_left: float = 40.0
var elapsed: float = 0.0
var round_no: int = 0
var round_over: bool = false
var round_winner: int = -1
var match_over: bool = false
var match_winner: int = -1
var foods: Array = [] ## {uid, id, pos: Vector2(0~1), life}
var food_timer: float = 5.0
var next_food_uid: int = 1
var food_defs: Array = []
var rng := RandomNumberGenerator.new()
var events: Array = []


func setup(def0: Dictionary, def1: Dictionary, balance: Dictionary, p_foods: Array, seed_value: int = -1) -> void:
	bal = balance
	food_defs = p_foods
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	fighters = [_new_fighter(def0), _new_fighter(def1)]
	round_no = 0
	match_over = false
	match_winner = -1


func _new_fighter(def: Dictionary) -> Dictionary:
	var f := {
		"def": def, "wins": 0,
		"stats": {"farts": 0, "perfect": 0, "blunders": 0, "parries": 0, "blocks": 0, "foods": 0, "max_power": 0.0},
	}
	_reset_fighter(f) # 첫 라운드 시작 전(소개 화면)에도 화면이 읽을 수 있게
	return f


func _reset_fighter(f: Dictionary) -> void:
	f["gas"] = float(bal.get("gas_start", 70.0))
	f["pressure"] = 0.0
	f["holding"] = false
	f["over_t"] = 0.0
	f["stun_t"] = 0.0
	f["block_t"] = 0.0
	f["block_cd"] = 0.0
	f["block_started"] = -99.0
	f["power_mult"] = 1.0
	f["power_count"] = 0
	f["stink_next"] = 0.0
	f["stink_t"] = 0.0
	f["fast_t"] = 0.0
	f["regen_t"] = 0.0
	f["boost_next"] = 1.0
	f["last_fart_t"] = -99.0
	f["beam_t"] = 0.0
	f["beam_total"] = 0.0
	f["beam_force"] = 0.0
	f["beam_perfect"] = false
	f["beam_power"] = 0.0
	f["fire_count"] = 0
	f["fire_mult"] = 1.0
	f["beam_fire"] = false
	f["beam_blocked"] = false


func start_round() -> void:
	round_no += 1
	for f in fighters:
		_reset_fighter(f)
	cloud = 0.0
	cloud_vel = 0.0
	time_left = float(bal.get("round_time", 40.0))
	elapsed = 0.0
	round_over = false
	round_winner = -1
	foods = []
	food_timer = rng.randf_range(2.5, 4.0)
	events.append({"type": "round_start", "round": round_no})


func take_events() -> Array:
	var e := events
	events = []
	return e


static func direction(side: int) -> float:
	return 1.0 if side == 0 else -1.0


func sweet_range(side: int) -> Vector2:
	var f: Dictionary = fighters[side]
	var lo := float(bal.get("sweet_min", 0.72))
	var w := float(bal.get("sweet_width", 0.16)) * float(f["def"].get("control", 1.0))
	return Vector2(lo, minf(1.0, lo + w))


func can_act(side: int) -> bool:
	return not round_over and float(fighters[side]["stun_t"]) <= 0.0


## 최대로 모을 수 있는 압력 (가스가 부족하면 덜 참)
func max_pressure(side: int) -> float:
	return clampf(float(fighters[side]["gas"]) / float(bal.get("gas_cost_full", 45.0)), 0.0, 1.0)


# ───────── 입력 ─────────

func press(side: int) -> bool:
	if not can_act(side):
		return false
	var f: Dictionary = fighters[side]
	if f["holding"]:
		return true
	if max_pressure(side) < float(bal.get("min_release", 0.12)):
		events.append({"type": "no_gas", "side": side})
		return false
	f["holding"] = true
	f["pressure"] = 0.0
	f["over_t"] = 0.0
	return true


func release(side: int) -> Dictionary:
	var f: Dictionary = fighters[side]
	if not f["holding"]:
		return {}
	f["holding"] = false
	var p := float(f["pressure"])
	f["pressure"] = 0.0
	f["over_t"] = 0.0
	if round_over:
		return {}
	return _fart(side, p)


func block(side: int) -> bool:
	if not can_act(side):
		return false
	var f: Dictionary = fighters[side]
	if float(f["block_cd"]) > 0.0:
		return false
	f["block_t"] = float(bal.get("block_duration", 0.8))
	f["block_cd"] = float(bal.get("block_cooldown", 3.0))
	f["block_started"] = elapsed
	events.append({"type": "block_start", "side": side})
	return true


func eat(side: int, food_uid: int) -> bool:
	if round_over:
		return false
	for fd in foods:
		if int(fd["uid"]) == food_uid:
			foods.erase(fd)
			_apply_food(side, str(fd["id"]))
			return true
	return false


# ───────── 진행 ─────────

func tick(delta: float) -> void:
	if round_over:
		return
	elapsed += delta
	time_left -= delta
	for side in 2:
		_tick_fighter(side, delta)
	# 구름 이동
	cloud += cloud_vel * delta
	cloud_vel *= exp(-float(bal.get("cloud_friction", 2.4)) * delta)
	var vmax := float(bal.get("cloud_max_speed", 1.6))
	cloud_vel = clampf(cloud_vel, -vmax, vmax)
	_tick_foods(delta)
	if cloud >= 1.0:
		_end_round(0, "ko")
	elif cloud <= -1.0:
		_end_round(1, "ko")
	elif time_left <= 0.0:
		if absf(cloud) < 0.02:
			_end_round(-1, "draw")
		else:
			_end_round(0 if cloud > 0.0 else 1, "time")


func _tick_fighter(side: int, delta: float) -> void:
	var f: Dictionary = fighters[side]
	var def: Dictionary = f["def"]
	for k in ["stun_t", "block_t", "block_cd", "fast_t", "regen_t"]:
		f[k] = maxf(0.0, float(f[k]) - delta)
	# 방귀 빔: 뿜는 동안 부딪힘 지점에 힘
	if float(f["beam_t"]) > 0.0:
		var dt := minf(delta, float(f["beam_t"]))
		f["beam_t"] = float(f["beam_t"]) - delta
		var force := float(f["beam_force"])
		if not f["beam_blocked"] and float(fighters[1 - side]["block_t"]) > 0.0:
			force *= 1.0 - float(bal.get("block_reduce", 0.75))
		cloud_vel += direction(side) * force * dt
	# 냄새 지속: 계속 조금씩 민다
	if float(f["stink_t"]) > 0.0:
		f["stink_t"] = maxf(0.0, float(f["stink_t"]) - delta)
		var push := direction(side) * float(bal.get("stink_push", 0.09)) * delta
		if float(fighters[1 - side]["block_t"]) > 0.0:
			push *= 1.0 - float(bal.get("block_reduce", 0.75))
		cloud += push
	if f["holding"]:
		var rate := 1.0 / maxf(0.2, float(bal.get("pressure_fill_time", 1.25)))
		if float(f["fast_t"]) > 0.0:
			rate *= 2.0
		var cap := max_pressure(side)
		f["pressure"] = minf(cap, float(f["pressure"]) + rate * delta)
		if float(f["pressure"]) >= cap - 0.0001:
			f["over_t"] = float(f["over_t"]) + delta
			if float(f["over_t"]) > float(bal.get("overcharge_grace", 0.35)):
				_blunder(side)
	else:
		var regen := float(def.get("gas_regen", 9.0))
		if float(f["regen_t"]) > 0.0:
			regen *= 2.0
		f["gas"] = minf(float(bal.get("gas_max", 100.0)), float(f["gas"]) + regen * delta)


func _fart(side: int, p: float) -> Dictionary:
	var f: Dictionary = fighters[side]
	var def: Dictionary = f["def"]
	var cost := p * float(bal.get("gas_cost_full", 45.0))
	f["gas"] = maxf(0.0, float(f["gas"]) - cost)
	var sweet := sweet_range(side)
	var perfect := p >= sweet.x and p <= sweet.y
	var power := float(def.get("power", 1.0)) * p
	if p < float(bal.get("min_release", 0.12)):
		power *= 0.3
	if perfect:
		power *= float(bal.get("perfect_mult", 1.6))
	if int(f["power_count"]) > 0:
		power *= float(f["power_mult"])
		f["power_count"] = int(f["power_count"]) - 1
	power *= float(f["boost_next"])
	f["boost_next"] = 1.0
	var fire := false
	if int(f["fire_count"]) > 0:
		power *= float(f["fire_mult"])
		f["fire_count"] = int(f["fire_count"]) - 1
		fire = true
	var push := power * float(bal.get("push_strength", 0.62))
	var target: Dictionary = fighters[1 - side]
	var result := "hit"
	if float(target["block_t"]) > 0.0:
		target["stats"]["blocks"] += 1
		if elapsed - float(target["block_started"]) <= float(bal.get("parry_window", 0.3)):
			result = "parry"
			push = -push * float(bal.get("parry_reflect", 0.45))
			target["stats"]["parries"] += 1
		else:
			result = "blocked"
	if result == "parry":
		cloud_vel += direction(side) * push # 반사: 즉시 되돌아감
		f["beam_t"] = 0.0
	else:
		# 빔으로 뿜기 (막는 중이면 tick 에서 약해짐)
		var dur := float(bal.get("beam_min_time", 0.35)) + float(bal.get("beam_extra_time", 0.7)) * p
		f["beam_t"] = dur
		f["beam_total"] = dur
		f["beam_force"] = push / dur
		f["beam_blocked"] = result == "blocked"
		if result == "blocked":
			f["beam_force"] = float(f["beam_force"]) * (1.0 - float(bal.get("block_reduce", 0.75)))
		f["beam_perfect"] = perfect
		f["beam_power"] = power
		f["beam_fire"] = fire
	# 냄새 지속 (계란 / 캐릭터 고유)
	var stink := maxf(float(f["stink_next"]), float(def.get("stink", 0.0)))
	f["stink_next"] = 0.0
	if stink > 0.0 and result == "hit":
		f["stink_t"] = maxf(float(f["stink_t"]), stink)
	f["last_fart_t"] = elapsed
	var st: Dictionary = f["stats"]
	st["farts"] += 1
	if perfect:
		st["perfect"] += 1
	st["max_power"] = maxf(float(st["max_power"]), power)
	var size := "tiny"
	if power >= 1.4:
		size = "mega"
	elif power >= 0.9:
		size = "big"
	elif power >= 0.4:
		size = "medium"
	var ev := {"type": "fart", "side": side, "p": p, "power": power, "perfect": perfect, "size": size, "result": result, "stink": stink > 0.0, "fire": fire}
	events.append(ev)
	return ev


func _blunder(side: int) -> void:
	var f: Dictionary = fighters[side]
	f["holding"] = false
	f["pressure"] = 0.0
	f["over_t"] = 0.0
	f["stun_t"] = float(bal.get("blunder_stun", 1.5))
	f["beam_t"] = 0.0
	f["gas"] = float(f["gas"]) * 0.5
	f["stats"]["blunders"] += 1
	cloud_vel -= direction(side) * float(bal.get("blunder_backfire", 0.28))
	events.append({"type": "blunder", "side": side})


func _apply_food(side: int, id: String) -> void:
	var fd: Dictionary = {}
	for d in food_defs:
		if d["id"] == id:
			fd = d
	if fd.is_empty():
		return
	var f: Dictionary = fighters[side]
	f["stats"]["foods"] += 1
	var v := float(fd.get("value", 0))
	var ev := {"type": "eat", "side": side, "food": id, "name": fd.get("name", ""), "good": true}
	match str(fd.get("effect", "")):
		"power":
			f["power_mult"] = v
			f["power_count"] = int(fd.get("count", 3))
		"fire":
			f["fire_mult"] = v
			f["fire_count"] = int(fd.get("count", 2))
		"gas":
			f["gas"] = minf(float(bal.get("gas_max", 100.0)), float(f["gas"]) + v)
		"stink":
			f["stink_next"] = v
		"fast":
			f["fast_t"] = v
		"regen":
			f["regen_t"] = v
		"gamble":
			if rng.randf() < float(bal.get("milk_bad_chance", 0.5)):
				f["stun_t"] = maxf(float(f["stun_t"]), float(bal.get("milk_stun", 1.0)))
				f["holding"] = false
				f["pressure"] = 0.0
				ev["good"] = false
			else:
				f["boost_next"] = v
	events.append(ev)


func _tick_foods(delta: float) -> void:
	for fd in foods.duplicate():
		fd["life"] = float(fd["life"]) - delta
		if float(fd["life"]) <= 0.0:
			foods.erase(fd)
	food_timer -= delta
	if food_timer <= 0.0 and not food_defs.is_empty():
		food_timer = rng.randf_range(float(bal.get("food_interval_min", 4.0)), float(bal.get("food_interval_max", 6.5)))
		spawn_food(_pick_food())


func _pick_food() -> String:
	var total := 0.0
	for d in food_defs:
		total += float(d.get("weight", 1.0))
	var roll := rng.randf() * total
	for d in food_defs:
		roll -= float(d.get("weight", 1.0))
		if roll <= 0.0:
			return str(d["id"])
	return str(food_defs[0]["id"])


func spawn_food(id: String, pos: Vector2 = Vector2(-1, -1)) -> Dictionary:
	if pos.x < 0.0:
		pos = Vector2(rng.randf_range(0.14, 0.86), rng.randf_range(0.3, 0.7))
	var fd := {"uid": next_food_uid, "id": id, "pos": pos, "life": float(bal.get("food_lifetime", 4.0))}
	next_food_uid += 1
	foods.append(fd)
	events.append({"type": "food_spawn", "uid": fd["uid"], "food": id})
	return fd


func _end_round(winner: int, how: String) -> void:
	round_over = true
	round_winner = winner
	for f in fighters:
		f["holding"] = false
		f["pressure"] = 0.0
		f["beam_t"] = 0.0
	if winner >= 0:
		fighters[winner]["wins"] += 1
		fighters[1 - winner]["stun_t"] = float(bal.get("knockout_stun", 1.8))
	events.append({"type": "round_end", "winner": winner, "how": how})
	var need := int(bal.get("rounds_to_win", 2))
	for s in 2:
		if int(fighters[s]["wins"]) >= need:
			match_over = true
			match_winner = s
			events.append({"type": "match_end", "winner": s})
