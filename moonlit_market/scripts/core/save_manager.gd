extends Node
## SaveManager (Autoload)
## JSON 세이브 + 버전 관리 + 백업 + 손상 대응.
##
## 저장 절차 (원자적 교체)
##   1) save.tmp 에 기록 → 2) 다시 읽어 파싱 검증 → 3) 기존 save.json 을 save.bak 로 복사
##   4) save.json 교체. 어느 단계에서 실패해도 기존 save.json/save.bak 은 보존된다.
## 불러오기 순서: save.json → save.tmp → save.bak. 모두 실패 시 손상 상태를 보고하고
## 손상 파일을 save.corrupt.json 으로 보관한다 (UI 에서 백업 복원/새 게임 선택).

signal saved(ok: bool, message: String)

const SAVE_DIR := "user://"
const MAIN_FILE := "save.json"
const TMP_FILE := "save.tmp"
const BACKUP_FILE := "save.bak"
const CORRUPT_FILE := "save.corrupt.json"
const CURRENT_VERSION := 2

var save_dir: String = SAVE_DIR ## 테스트에서 별도 폴더로 교체 가능
var last_save_unix: float = 0.0
var last_save_ok: bool = true
var last_message: String = ""
var save_count: int = 0


func path(file_name: String) -> String:
	return save_dir.path_join(file_name)


func has_save() -> bool:
	return FileAccess.file_exists(path(MAIN_FILE)) or FileAccess.file_exists(path(BACKUP_FILE)) or FileAccess.file_exists(path(TMP_FILE))


func has_backup() -> bool:
	return FileAccess.file_exists(path(BACKUP_FILE))


func save_dict(d: Dictionary) -> bool:
	var text := JSON.stringify(d, "\t")
	var tmp_path := path(TMP_FILE)
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return _report(false, "임시 파일 쓰기 실패 (%s)" % error_string(FileAccess.get_open_error()))
	f.store_string(text)
	f.flush()
	f.close()
	# 검증
	var verify := _read_json(tmp_path)
	if verify.is_empty():
		return _report(false, "저장 검증 실패 — 기존 데이터를 유지합니다.")
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return _report(false, "저장 폴더 접근 실패")
	if dir.file_exists(MAIN_FILE):
		# 기존 정상 세이브만 백업으로 승격 (손상된 파일로 백업을 덮어쓰지 않음)
		if not _read_json(path(MAIN_FILE)).is_empty():
			dir.copy(path(MAIN_FILE), path(BACKUP_FILE))
		dir.remove(MAIN_FILE)
	var err := dir.rename(TMP_FILE, MAIN_FILE)
	if err != OK:
		# 이름 변경 실패 시 직접 복사
		err = dir.copy(tmp_path, path(MAIN_FILE))
		if err != OK:
			return _report(false, "저장 파일 교체 실패 (%s) — 임시 파일에서 복구 가능" % error_string(err))
		dir.remove(TMP_FILE)
	save_count += 1
	last_save_unix = Time.get_unix_time_from_system()
	return _report(true, "저장 완료")


## 반환: {"status": "ok"|"none"|"recovered"|"corrupt", "data": Dictionary, "message": String}
func load_dict() -> Dictionary:
	var main_exists := FileAccess.file_exists(path(MAIN_FILE))
	var candidates := [MAIN_FILE, TMP_FILE, BACKUP_FILE]
	if not has_save():
		return {"status": "none", "data": {}, "message": "저장 데이터 없음 — 새 게임"}
	for i in candidates.size():
		var file_name: String = candidates[i]
		if not FileAccess.file_exists(path(file_name)):
			continue
		var d := _read_json(path(file_name))
		if d.is_empty():
			continue
		d = migrate(d)
		if d.is_empty():
			continue
		if i == 0:
			return {"status": "ok", "data": d, "message": "불러오기 완료"}
		if main_exists:
			_preserve_corrupt()
		return {"status": "recovered", "data": d, "message": "기본 세이브가 손상되어 %s 에서 복구했습니다." % ("임시 저장" if file_name == TMP_FILE else "백업")}
	_preserve_corrupt()
	return {"status": "corrupt", "data": {}, "message": "저장 데이터가 손상되었습니다."}


## 버전 마이그레이션. 알 수 없는 미래 버전이면 {} (덮어쓰지 않도록).
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v > CURRENT_VERSION:
		push_warning("세이브 버전(%d)이 게임 버전보다 높습니다." % v)
		return {}
	if v < 2:
		# v1 → v2: 오프라인 기록/정산 기록 필드 추가
		if not d.has("offline"):
			d["offline"] = {}
		if not d.has("pending_result"):
			d["pending_result"] = {}
		if not d.has("max_seen_unix"):
			d["max_seen_unix"] = d.get("last_seen_unix", 0.0)
		d["version"] = 2
	return d


func delete_all() -> void:
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return
	for file_name in [MAIN_FILE, TMP_FILE, BACKUP_FILE]:
		if dir.file_exists(file_name):
			dir.remove(file_name)


func restore_backup_only() -> Dictionary:
	var d := _read_json(path(BACKUP_FILE))
	if d.is_empty():
		return {}
	return migrate(d)


func _preserve_corrupt() -> void:
	var dir := DirAccess.open(save_dir)
	if dir != null and dir.file_exists(MAIN_FILE):
		dir.copy(path(MAIN_FILE), path(CORRUPT_FILE))


func _read_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var text := FileAccess.get_file_as_string(file_path)
	if text.strip_edges() == "":
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if not d.has("coins") or not d.has("slots"):
		return {}
	return d


func _report(ok: bool, msg: String) -> bool:
	last_save_ok = ok
	last_message = msg
	if not ok:
		push_warning("[SaveManager] " + msg)
	saved.emit(ok, msg)
	return ok
