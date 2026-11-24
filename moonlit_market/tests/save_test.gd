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
	s.employees["emp_basic"] = {"hired": true, "level": 3}
	s.pocha = {"level": 3, "rep": 33.0, "staff": ["emp_basic"],
		"menus": {"dak_skewer": {"enabled": true, "price_ratio": 1.15, "stock": 7}, "draft_beer": {"enabled": false, "price_ratio": 1.0, "stock": 2}},
		"stats": {"sold_total": 40, "revenue_total": 4800, "last_sold": 12, "last_revenue": 1440, "best_quality": 91}}
	s.rivals = {"rival_bunsik": {"rep": 30.0, "sales_total": 55, "last_sales": 9}}
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
	t.eq(s2.pocha_level(), 3, "포차 레벨 복원")
	t.ok(s2.is_menu_enabled("dak_skewer") and not s2.is_menu_enabled("draft_beer"), "메뉴판 복원")
	t.eq(s2.stock_of("dak_skewer"), 7, "재료 복원")
	t.ok(absf(float(s2.menu_entry("dak_skewer")["price_ratio"]) - 1.15) < 0.001, "판매 가격 복원")
	t.eq(s2.staff_list(), ["emp_basic"], "근무 상인 복원")
	t.eq(int(s2.employees["emp_basic"]["level"]), 3, "상인 레벨 복원")
	t.eq(int(s2.rivals["rival_bunsik"]["sales_total"]), 55, "경쟁 노점 기록 복원")
	t.eq(int(s2.pocha["stats"]["sold_total"]), 40, "포차 통계 복원")
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
	var bad := {"coins": -50, "reputation": "abc", "employees": {"emp_basic": {"hired": true, "level": 1}},
		"pocha": {"level": 99, "staff": ["emp_basic", "emp_basic", "emp_chef"],
			"menus": {"dak_skewer": {"enabled": true, "price_ratio": 5.0, "stock": 999}, "unknown_menu": {"enabled": true}, "tteokbokki": {"enabled": true}, "x": "weird"}}}
	t.ok(s.from_dict(bad, DataManager), "누락/이상 값이 있어도 로드")
	t.eq(s.coins, 0, "음수 코인 → 0")
	t.eq(s.pocha_level(), 5, "포차 레벨 상한")
	t.eq(float(s.menu_entry("dak_skewer")["price_ratio"]), 1.3, "가격 비율 상한")
	t.eq(s.stock_of("dak_skewer"), 40, "재고 상한 (Lv.5 = 40)")
	t.ok(not s.has_menu("unknown_menu"), "알 수 없는 메뉴 제거")
	t.ok(not s.has_menu("tteokbokki"), "경쟁 노점 전용 메뉴는 포차 메뉴판에서 제거")
	t.eq(s.staff_list(), ["emp_basic"], "중복/미고용 상인 제거")
	t.ok(not s.from_dict({"foo": 1}, DataManager), "필수 키 없으면 거부")


func test_version_migration(t) -> void:
	var m = _mgr()
	var old := {"version": 1, "coins": 10, "slots": [], "last_seen_unix": 100.0}
	var d: Dictionary = m.migrate(old)
	t.eq(int(d["version"]), 3, "v1 → v3 마이그레이션")
	t.ok(d.has("offline") and d.has("pocha"), "새 필드 추가")
	t.eq(float(d["max_seen_unix"]), 100.0, "max_seen 초기화")
	t.ok(m.migrate({"version": 999, "coins": 1, "pocha": {}}).is_empty(), "미래 버전 거부")
	m.free()


## 노점 6칸 시절(v2) 세이브 → 포차(v3) 변환: 재고 환급, 레벨/상인 이전
func test_v2_save_converts(t) -> void:
	var m = _mgr()
	var v2 := {"version": 2, "coins": 100, "reputation": 40,
		"employees": {"emp_basic": {"hired": true, "level": 2}},
		"slots": [{}, {"kind": "stall", "type": "skewer", "level": 3, "menu": "skewer_grill", "stock": 10, "employee": "emp_basic", "rep": 44.0},
			{"kind": "facility", "type": "photo_zone"}, {}, {"kind": "stall", "type": "drink", "level": 1, "menu": "lemonade", "stock": 4}, {}]}
	var d: Dictionary = m.migrate(v2)
	t.eq(int(d["version"]), 3, "v2 → v3")
	t.eq(int(d["coins"]), 100 + 10 * 40 + 4 * 25, "기존 재고는 원가로 환급")
	var s = GameStateScript.new()
	t.ok(s.from_dict(d, DataManager), "변환된 세이브 로드")
	t.eq(s.pocha_level(), 3, "가장 높은 노점 레벨 이전")
	t.eq(s.staff_list(), ["emp_basic"], "배치 상인 이전")
	t.ok(s.is_menu_enabled("dak_skewer"), "기본 메뉴판 생성")
	t.eq(s.reputation, 40, "시장 평판 유지")
	m.free()
