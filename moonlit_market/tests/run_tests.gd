extends Node
## 헤드리스 테스트 러너
## 실행: godot --headless --path . res://tests/test_runner.tscn -- --test
## (--test 인자가 있으면 GameManager 가 user://_test_saves 를 사용해 실제 세이브를 보호한다)

const SUITES := [
	preload("res://tests/economy_test.gd"),
	preload("res://tests/save_test.gd"),
	preload("res://tests/kitchen_test.gd"),
	preload("res://tests/customer_test.gd"),
]

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
	if not OS.get_cmdline_user_args().has("--test"):
		printerr("테스트는 '-- --test' 인자와 함께 실행해야 합니다 (실제 세이브 보호).")
		get_tree().quit(2)
		return
	# 루트가 자식 노드를 구성하는 중에는 add_child 가 실패하므로 한 프레임 대기
	await get_tree().process_frame
	print("=== 달빛장터 테스트 시작 ===")
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
