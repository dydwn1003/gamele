extends RefCounted
## 주방(화구) 익힘 판정 테스트

const KitchenScript := preload("res://scripts/market/kitchen.gd")


func _menu() -> Dictionary:
	return {"id": "dak_skewer", "cook_time": 10.0, "perfect_end": 1.4, "burn": 1.9}


func test_stages_and_quality(t) -> void:
	var k = KitchenScript.new()
	k.setup(2)
	t.ok(k.start(0, _menu()), "화구 0에 올리기")
	t.ok(not k.start(0, _menu()), "사용 중인 화구에는 못 올림")
	k.tick(5.0)
	t.eq(k.stage(0), "raw", "50% → 덜 익음")
	var early: Dictionary = k.collect(0)
	t.ok(not early["ok"] and early.get("too_early", false), "덜 익으면 꺼낼 수 없음")
	k.tick(4.0)
	t.eq(k.stage(0), "almost", "90% → 거의")
	k.tick(3.0)
	t.eq(k.stage(0), "perfect", "120% → 딱 좋음")
	var r: Dictionary = k.collect(0)
	t.ok(r["ok"] and not r["burnt"], "꺼내기 성공")
	t.eq(r["quality"], 100.0, "딱 좋을 때 품질 100")
	t.ok(not k.is_busy(0), "꺼낸 뒤 화구 비움")
	k.start(1, _menu())
	k.tick(16.0)
	t.eq(k.stage(1), "over", "160% → 조금 탐")
	var over: Dictionary = k.collect(1)
	t.ok(float(over["quality"]) < 100.0 and float(over["quality"]) > 45.0, "조금 타면 품질 하락")
	k.start(1, _menu())
	k.tick(25.0)
	var burnt: Dictionary = k.collect(1)
	t.ok(burnt["ok"] and burnt["burnt"], "너무 오래 두면 탐")


func test_quality_curve(t) -> void:
	t.eq(KitchenScript.quality_for(0.5, 1.4, 1.9), -1.0, "덜 익음 = 품질 없음")
	t.eq(KitchenScript.quality_for(0.8, 1.4, 1.9), 60.0, "80% = 60")
	t.eq(KitchenScript.quality_for(1.0, 1.4, 1.9), 100.0, "100% = 100")
	t.eq(KitchenScript.quality_for(1.4, 1.4, 1.9), 100.0, "완벽 구간 끝 = 100")
	t.ok(absf(KitchenScript.quality_for(1.9, 1.4, 1.9) - 45.0) < 0.01, "타기 직전 = 45")
	t.eq(KitchenScript.quality_for(2.0, 1.4, 1.9), -1.0, "탐 = 품질 없음")


func test_cook_speed_and_resize(t) -> void:
	var k = KitchenScript.new()
	k.setup(2)
	k.start(0, _menu(), 2.0)
	k.tick(5.0)
	t.eq(k.stage(0), "perfect", "조리 속도 2배면 절반 시간에 완성")
	k.resize(4)
	t.eq(k.burners.size(), 4, "화구 늘리기")
	t.eq(k.free_burner(false, 3), 1, "자동 요리 화구는 건너뛰고 빈 화구 찾기")
	t.eq(k.clear(), ["dak_skewer"], "정리 시 남은 음식 반환")


func test_pour_quality(t) -> void:
	t.eq(KitchenScript.pour_quality(0.85, 0.78, 0.92, 1.0), 100.0, "선 안에서 떼면 완벽")
	t.ok(KitchenScript.pour_quality(0.5, 0.78, 0.92, 1.0) < 90.0, "덜 채우면 품질 하락")
	t.ok(KitchenScript.pour_quality(0.97, 0.78, 0.92, 1.0) < 100.0, "선을 넘기면 품질 하락")
	t.eq(KitchenScript.pour_quality(1.02, 0.78, 0.92, 1.0), -1.0, "넘치면 버림")
