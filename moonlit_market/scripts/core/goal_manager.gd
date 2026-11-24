extends RefCounted
## GoalManager — 오늘의 목표 3개와 라이벌 대결의 밤 (goals.json)
## 목표는 하루에 한 번 생성되어 세이브에 남고, 영업 결과로 판정한다.

var state
var data
var progression


func setup(p_state, p_data, p_progression) -> void:
	state = p_state
	data = p_data
	progression = p_progression


func goal_def(id: String) -> Dictionary:
	for g in data.goals:
		if g["id"] == id:
			return g
	return {}


func target_for(def: Dictionary, day: int) -> int:
	return mini(int(def.get("max", 99999)), int(def.get("base", 1)) + int(def.get("per_day", 0)) * maxi(0, day - 1))


func describe(goal: Dictionary) -> String:
	var def := goal_def(str(goal.get("id", "")))
	if def.is_empty():
		return "-"
	return str(def.get("text", "%d")) % int(goal.get("target", 0))


## 아직 오늘 목표가 없으면 만든다. 반환: 새로 만들었는가
func prepare_day(rng: RandomNumberGenerator) -> bool:
	if state.goals_day == state.day and not state.daily_goals.is_empty():
		return false
	var pool: Array = data.goals.duplicate()
	# 특별 손님이 아직 안 나오는 날에는 특별 손님 목표 제외
	if state.day < 2:
		pool = pool.filter(func(g): return g["id"] != "special")
	var out: Array = []
	var n := mini(int(data.goals_meta.get("goals_per_day", 3)), pool.size())
	for i in n:
		var k := rng.randi() % pool.size()
		var def: Dictionary = pool[k]
		pool.remove_at(k)
		out.append({"id": def["id"], "target": target_for(def, state.day)})
	state.daily_goals = out
	state.goals_day = state.day
	state.showdown = {}
	var rival := showdown_rival_for(state.day)
	if rival != "":
		state.showdown = {"day": state.day, "rival": rival}
	return true


## 대결의 밤: first_day 부터 interval 일마다, 평판이 가장 높은 라이벌과
func showdown_rival_for(day: int) -> String:
	var sd: Dictionary = data.goals_meta.get("showdown", {})
	var first := int(sd.get("first_day", 3))
	var interval := maxi(1, int(sd.get("interval_days", 5)))
	if day < first or (day - first) % interval != 0:
		return ""
	var best := ""
	var best_rep := -1.0
	for id in progression.active_rivals():
		var rep := float(data.get_rival(id).get("reputation", 20))
		if state.rivals.has(id):
			rep = float(state.rivals[id].get("rep", rep))
		if rep > best_rep:
			best_rep = rep
			best = id
	return best


func is_showdown_today() -> bool:
	return not state.showdown.is_empty() and int(state.showdown.get("day", -1)) == state.day


## 결과(close_session 의 result)로 목표 판정
func evaluate(result: Dictionary) -> Array:
	var out: Array = []
	for g in state.daily_goals:
		var def := goal_def(str(g["id"]))
		if def.is_empty():
			continue
		var value := int(result.get(str(def["stat"]), 0))
		var target := int(g["target"])
		var done := value <= target if def.get("compare", "min") == "max" else value >= target
		out.append({"id": g["id"], "text": describe(g), "value": value, "target": target, "done": done,
			"coins": int(def.get("reward_coins", 0)) if done else 0, "rep": int(def.get("reward_rep", 0)) if done else 0})
	return out
