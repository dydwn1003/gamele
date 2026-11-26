extends Node
## 헤드리스 테스트 러너: godot --headless --path . res://tests/test_runner.tscn -- --test

const SUITES := [preload("res://tests/battle_test.gd")]

var passed: int = 0
var failed: int = 0
var current: String = ""


func ok(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  FAIL [%s] %s" % [current, msg])


func eq(a, b, msg: String) -> void:
	ok(a == b, "%s (expected %s, got %s)" % [msg, str(b), str(a)])


func _ready() -> void:
	await get_tree().process_frame
	print("=== 방귀 대결 테스트 ===")
	for suite_script in SUITES:
		var suite = suite_script.new()
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			current = mname
			var before := failed
			await suite.call(mname, self)
			print("%s %s" % ["  ok  " if failed == before else "  FAIL", mname])
	print("=== 결과: %d 통과, %d 실패 ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
