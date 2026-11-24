extends RefCounted
## Kitchen — 화구(버너) 상태와 익힘 판정 (순수 로직, 테스트 가능)
##
## 익힘 비율 r = 경과 시간 / 조리 시간
##   r < too_early(0.8)      : 덜 익음 — 꺼낼 수 없음
##   0.8 ≤ r < 1.0           : 조금 덜 익음  (품질 60 → 90)
##   1.0 ≤ r ≤ perfect_end   : 딱 좋음       (품질 100)
##   perfect_end < r ≤ burn  : 조금 탐       (품질 100 → 45)
##   r > burn                : 탔음 — 버려야 함

const STAGE_EMPTY := "empty"
const STAGE_RAW := "raw"
const STAGE_ALMOST := "almost"
const STAGE_PERFECT := "perfect"
const STAGE_OVER := "over"
const STAGE_BURNT := "burnt"

var burners: Array = []
var too_early: float = 0.8


func setup(count: int, p_too_early: float = 0.8) -> void:
	too_early = p_too_early
	burners = []
	resize(count)


func resize(count: int) -> void:
	while burners.size() < count:
		burners.append(_empty())
	while burners.size() > count and burners[burners.size() - 1]["menu"] == "":
		burners.pop_back()


static func _empty() -> Dictionary:
	return {"menu": "", "t": 0.0, "cook": 1.0, "perfect_end": 1.4, "burn": 1.9, "auto": false, "for_order": -1}


func free_burner(allow_auto_reserved: bool = false, auto_index: int = -1) -> int:
	for i in burners.size():
		if burners[i]["menu"] == "" and (allow_auto_reserved or i != auto_index):
			return i
	return -1


func is_busy(i: int) -> bool:
	return i >= 0 and i < burners.size() and burners[i]["menu"] != ""


## 화구 i 에 메뉴를 올린다. cook_speed 는 조리 속도 배수.
func start(i: int, menu: Dictionary, cook_speed: float = 1.0, auto: bool = false, for_order: int = -1) -> bool:
	if i < 0 or i >= burners.size() or burners[i]["menu"] != "" or menu.is_empty():
		return false
	burners[i] = {
		"menu": str(menu.get("id", "")),
		"t": 0.0,
		"cook": maxf(0.5, float(menu.get("cook_time", 6.0)) / maxf(0.1, cook_speed)),
		"perfect_end": float(menu.get("perfect_end", 1.4)),
		"burn": float(menu.get("burn", 1.9)),
		"auto": auto,
		"for_order": for_order,
	}
	return true


func tick(delta: float) -> void:
	for b in burners:
		if b["menu"] != "":
			b["t"] = float(b["t"]) + delta


func ratio(i: int) -> float:
	var b: Dictionary = burners[i]
	if b["menu"] == "":
		return 0.0
	return float(b["t"]) / maxf(0.01, float(b["cook"]))


static func stage_for(r: float, perfect_end: float, burn: float, early: float = 0.8) -> String:
	if r < early:
		return STAGE_RAW
	if r < 1.0:
		return STAGE_ALMOST
	if r <= perfect_end:
		return STAGE_PERFECT
	if r <= burn:
		return STAGE_OVER
	return STAGE_BURNT


static func quality_for(r: float, perfect_end: float, burn: float, early: float = 0.8) -> float:
	match stage_for(r, perfect_end, burn, early):
		STAGE_RAW, STAGE_BURNT:
			return -1.0
		STAGE_ALMOST:
			return 60.0 + 30.0 * (r - early) / maxf(0.01, 1.0 - early)
		STAGE_PERFECT:
			return 100.0
		_:
			return 100.0 - 55.0 * (r - perfect_end) / maxf(0.01, burn - perfect_end)


func stage(i: int) -> String:
	var b: Dictionary = burners[i]
	if b["menu"] == "":
		return STAGE_EMPTY
	return stage_for(ratio(i), float(b["perfect_end"]), float(b["burn"]), too_early)


## 꺼내기. 반환 {ok, menu, quality, burnt, too_early}
func collect(i: int) -> Dictionary:
	if i < 0 or i >= burners.size() or burners[i]["menu"] == "":
		return {"ok": false, "empty": true}
	var b: Dictionary = burners[i]
	var st := stage(i)
	if st == STAGE_RAW:
		return {"ok": false, "too_early": true, "menu": b["menu"]}
	var out := {"ok": true, "menu": b["menu"], "burnt": st == STAGE_BURNT, "stage": st,
		"quality": quality_for(ratio(i), float(b["perfect_end"]), float(b["burn"]), too_early),
		"for_order": int(b["for_order"]), "auto": bool(b["auto"])}
	burners[i] = _empty()
	return out


## 자동 요리용: 딱 좋은 구간에 들어왔는가
func auto_ready(i: int) -> bool:
	return is_busy(i) and ratio(i) >= 1.0 + (float(burners[i]["perfect_end"]) - 1.0) * 0.3


## 영업 종료 시 화구 비우기 → 올라가 있던 메뉴 목록 반환
func clear() -> Array:
	var left: Array = []
	for i in burners.size():
		if burners[i]["menu"] != "":
			left.append(burners[i]["menu"])
		burners[i] = _empty()
	return left
