extends RefCounted
## 저장 시스템 테스트: 왕복 저장, 손상 파일 복구, 백업, 버전 마이그레이션, 신규 게임

const SaveScript := preload("res://scripts/core/save_manager.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")

const DIR := "user://_test_save_suite"


func _mgr():
	DirAccess.make_dir_recursive_absolute(DIR)
	var m = SaveScript.new()
	m.save_dir = DIR
	m.delete_all()
	return m


func _sample_state():
	var s = GameStateScript.new()
	s.reset_empty()
	s.coins = 1234
	s.reputation = 56
	s.market_level = 2
	s.slots[1] = GameStateScript.make_stall("skewer", "twigim", 7, 33.0)
	s.slots[1]["level"] = 2
	s.slots[1]["price_ratio"] = 1.15
	s.slots[1]["employee"] = "emp_basic"
	s.slots[4] = GameStateScript.make_facility("photo_zone")
	s.employees["emp_basic"] = {"hired": true, "level": 3}
	s.decorations_owned = ["flower_pots"]
	s.deco_spots[0] = "flower_pots"
	s.settings["music"] = false
	s.last_session = {"per_minute": 42.5, "session_id": 3}
	s.offline["claim_count"] = 2
	s.settled_session_id = 3
	s.next_session_id = 4
	return s


func test_roundtrip(t) -> void:
	var m = _mgr()
	var s = _sample_state()
	t.ok(m.save_dict(s.to_dict()), "저장 성공")
	var res: Dictionary = m.load_dict()
	t.eq(res["status"], "ok", "불러오기 성공")
	var s2 = GameStateScript.new()
	t.ok(s2.from_dict(res["data"], DataManager), "상태 복원")
	t.eq(s2.coins, 1234, "코인 복원")
	t.eq(s2.reputation, 56, "평판 복원")
	t.eq(s2.market_level, 2, "시장 레벨 복원")
	t.eq(s2.slots[1]["menu"], "twigim", "판매 메뉴 복원")
	t.eq(int(s2.slots[1]["level"]), 2, "노점 레벨 복원")
	t.eq(int(s2.slots[1]["stock"]), 7, "재고 복원")
	t.ok(absf(float(s2.slots[1]["price_ratio"]) - 1.15) < 0.001, "판매 가격 복원")
	t.eq(s2.slots[1]["employee"], "emp_basic", "상인 배치 복원")
	t.eq(int(s2.employees["emp_basic"]["level"]), 3, "상인 레벨 복원")
	t.eq(s2.slots[4]["type"], "photo_zone", "시설 복원")
	t.eq(s2.deco_spots[0], "flower_pots", "장식 설치 복원")
	t.eq(s2.settings["music"], false, "사운드 설정 복원")
	t.eq(int(s2.offline["claim_count"]), 2, "오프라인 정산 기록 복원")
	t.eq(s2.settled_session_id, 3, "정산 기록 복원")
	m.delete_all()
	m.free()


func test_corrupt_main_uses_backup(t) -> void:
	var m = _mgr()
	var s = _sample_state()
	m.save_dict(s.to_dict())
	s.coins = 9999
	m.save_dict(s.to_dict()) # 이전 저장본이 백업으로 이동
	t.ok(m.has_backup(), "백업 파일 생성")
	var f := FileAccess.open(DIR.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var res: Dictionary = m.load_dict()
	t.eq(res["status"], "recovered", "손상 시 백업에서 복구")
	t.eq(int(res["data"]["coins"]), 1234, "백업 데이터 사용")
	t.ok(FileAccess.file_exists(DIR.path_join("save.corrupt.json")), "손상 파일 보관")
	# 손상된 메인으로 백업을 덮어쓰지 않음
	m.save_dict(s.to_dict())
	t.eq(int(m.restore_backup_only().get("coins", 0)), 1234, "정상 백업 보존")
	m.delete_all()
	m.free()


func test_all_corrupt_and_none(t) -> void:
	var m = _mgr()
	t.eq(m.load_dict()["status"], "none", "저장 없음 → 신규 게임")
	var f := FileAccess.open(DIR.path_join("save.json"), FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	t.eq(m.load_dict()["status"], "corrupt", "모두 손상 → 손상 보고")
	var f2 := FileAccess.open(DIR.path_join("save.json"), FileAccess.WRITE)
	f2.store_string("[1, 2, 3]")
	f2.close()
	t.eq(m.load_dict()["status"], "corrupt", "형식 오류(배열) → 손상 보고")
	m.delete_all()
	m.free()


func test_invalid_values_sanitized(t) -> void:
	var s = GameStateScript.new()
	var bad := {"coins": -50, "reputation": "abc", "slots": [{"kind": "stall", "type": "unknown_stall"},
		{"kind": "stall", "type": "skewer", "menu": "nope", "level": 99, "price_ratio": 5.0, "stock": 999},
		"weird", null], "employees": {"emp_basic": {"hired": true, "level": 1}}}
	t.ok(s.from_dict(bad, DataManager), "누락/이상 값이 있어도 로드")
	t.eq(s.coins, 0, "음수 코인 → 0")
	t.ok(s.is_slot_empty(0), "알 수 없는 노점 제거")
	t.eq(s.slots[1]["menu"], "skewer_grill", "잘못된 메뉴 → 기본 메뉴")
	t.eq(int(s.slots[1]["level"]), 5, "레벨 상한")
	t.eq(float(s.slots[1]["price_ratio"]), 1.3, "가격 비율 상한")
	t.ok(int(s.slots[1]["stock"]) <= 42, "재고 상한")
	t.ok(s.is_slot_empty(2), "잘못된 슬롯 데이터 무시")
	t.ok(not s.from_dict({"foo": 1}, DataManager), "필수 키 없으면 거부")


func test_version_migration(t) -> void:
	var m = _mgr()
	var old := {"version": 1, "coins": 10, "slots": [], "last_seen_unix": 100.0}
	var d: Dictionary = m.migrate(old)
	t.eq(int(d["version"]), 2, "v1 → v2 마이그레이션")
	t.ok(d.has("offline") and d.has("pending_result"), "새 필드 추가")
	t.eq(float(d["max_seen_unix"]), 100.0, "max_seen 초기화")
	t.ok(m.migrate({"version": 999, "coins": 1, "slots": []}).is_empty(), "미래 버전 거부")
	m.free()
