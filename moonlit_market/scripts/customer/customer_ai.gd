extends RefCounted
## CustomerAI — 손님 의사결정 (순수 함수, 테스트 가능)
## 노점 선택 확률 = f(음식 취향, 판매 가격, 노점 평판, 대기열 길이, 접근성, 날씨/이벤트)
## 가장 점수가 높은 노점만 고르는 것이 아니라 가중 확률로 선택하므로
## 손님 유형마다 서로 다른 선택 분포가 나타난다.

## ctx 키
##   price_ratio, price_tolerance, stall_rep(0~100), market_rep, queue_len, queue_cap,
##   distance(px), weather(Dictionary), trend_menu, trend_mult, appeal, budget,
##   sold_out(bool), visited(bool)
static func preference(ctype: Dictionary, menu: Dictionary, ctx: Dictionary) -> float:
	var cat := str(menu.get("category", "snack"))
	var pref := float((ctype.get("category_pref", {}) as Dictionary).get(cat, 1.0))
	if (menu.get("preferred_customers", []) as Array).has(ctype.get("id", "")):
		pref *= 1.35
	pref *= 1.0 + (float(menu.get("popularity", 0.5)) - 0.5) * float(ctype.get("popularity_affinity", 0.3))
	if bool(menu.get("local_specialty", false)):
		pref *= 1.0 + float(ctype.get("local_affinity", 0.0)) * 0.5
	var w: Dictionary = ctx.get("weather", {})
	var warm := bool(menu.get("warm", false))
	if not w.is_empty():
		pref *= float(w.get("warm_mult", 1.0)) if warm else float(w.get("cold_mult", 1.0))
		pref *= float((w.get("category_mult", {}) as Dictionary).get(cat, 1.0))
	if warm:
		pref *= 1.0 + float(ctype.get("prefers_warm", 0.0))
	if str(ctx.get("trend_menu", "")) != "" and str(ctx.get("trend_menu", "")) == str(menu.get("id", "")):
		pref *= float(ctx.get("trend_mult", 1.0))
	return maxf(0.0, pref)


static func price_factor(ctype: Dictionary, price_ratio: float, tolerance: float) -> float:
	var over := clampf(price_ratio - 1.0 - tolerance, -0.3, 0.6)
	return exp(-float(ctype.get("price_sensitivity", 1.0)) * over * 1.8)


static func stall_score(ctype: Dictionary, menu: Dictionary, ctx: Dictionary) -> float:
	if menu.is_empty() or bool(ctx.get("sold_out", false)):
		return 0.0
	if int(ctx.get("queue_len", 0)) >= int(ctx.get("queue_cap", 4)):
		return 0.0
	var ratio := float(ctx.get("price_ratio", 1.0))
	var price := float(menu.get("price", 100)) * ratio
	if price > float(ctx.get("budget", 99999)):
		return 0.0
	var pref := preference(ctype, menu, ctx)
	var pf := price_factor(ctype, ratio, float(ctx.get("price_tolerance", 0.0)))
	var rep_sens := float(ctype.get("reputation_sensitivity", 0.4))
	var rep_factor := 0.7 + clampf(float(ctx.get("stall_rep", 10.0)) / 100.0, 0.0, 1.0) * 0.6 * (0.5 + rep_sens)
	rep_factor *= 1.0 + rep_sens * clampf(float(ctx.get("market_rep", 0.0)) / 300.0, 0.0, 1.0) * 0.3
	var queue_factor := 1.0 / (1.0 + int(ctx.get("queue_len", 0)) * float(ctype.get("queue_sensitivity", 0.4)))
	var access := 1.0 / (1.0 + float(ctx.get("distance", 0.0)) / 500.0)
	var appeal := 1.0 + float(ctx.get("appeal", 0.0))
	var score := pref * pf * rep_factor * queue_factor * access * appeal
	if bool(ctx.get("visited", false)):
		score *= 0.25
	return score


## candidates: [{"slot": int, "score": float}] → 선택된 slot 또는 -1(구매 안 함)
static func choose(candidates: Array, no_choice_weight: float, rng: RandomNumberGenerator) -> int:
	var total := maxf(0.0, no_choice_weight)
	var weights: Array = []
	for c in candidates:
		var w := pow(maxf(0.0, float(c.get("score", 0.0))), 1.5)
		weights.append(w)
		total += w
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in candidates.size():
		roll -= float(weights[i])
		if roll <= 0.0 and float(weights[i]) > 0.0:
			return int(candidates[i]["slot"])
	return -1


## 카운터 앞에서 실제 구매할 확률 (가격이 높을수록 감소)
static func purchase_probability(ctype: Dictionary, price_ratio: float, tolerance: float, sales_eff: float, base: float, penalty: float) -> float:
	var over := maxf(0.0, price_ratio - 1.0 - tolerance)
	var p := base - penalty * over * float(ctype.get("price_sensitivity", 1.0)) + (sales_eff - 1.0) * 0.5
	if price_ratio < 1.0:
		p += (1.0 - price_ratio) * 0.2
	return clampf(p, 0.05, 0.995)


## 구매 만족도 (0~100)
static func satisfaction(ctype: Dictionary, pref: float, price_ratio: float, wait_sec: float, bonus: float, base: float, wait_penalty: float) -> float:
	var s := base
	s += (pref - 1.0) * 12.0
	s += (1.0 - price_ratio) * 40.0 * float(ctype.get("price_sensitivity", 1.0))
	s -= wait_sec * wait_penalty * (float(ctype.get("queue_sensitivity", 0.4)) + 0.5)
	s += bonus
	return clampf(s, 0.0, 100.0)


## 손님 유형 선택 (가중치 × 관광객 배수 등)
static func pick_type(types: Dictionary, tourist_mult: float, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var ids: Array = types.keys()
	var weights: Array = []
	for id in ids:
		var w := float(types[id].get("spawn_weight", 1.0))
		if id == "tourist":
			w *= tourist_mult
		weights.append(maxf(0.0, w))
		total += maxf(0.0, w)
	if total <= 0.0 or ids.is_empty():
		return ids[0] if ids.size() > 0 else ""
	var roll := rng.randf() * total
	for i in ids.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(ids[i])
	return str(ids[ids.size() - 1])
