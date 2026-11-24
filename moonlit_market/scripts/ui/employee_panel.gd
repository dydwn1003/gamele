extends "res://scripts/ui/base_panel.gd"
## D. 상인 관리 화면 — 상인 목록, 능력치, 레벨, 배치 상태, 해금 조건, 고용/레벨업/배치

func _configure() -> void:
	title_text = "상인 관리"
	sheet_ratio = 0.88


func build() -> void:
	content.add_child(UIKit.label("근무 중인 상인만 효과를 냅니다. 근무 자리: %d/%d (포차 레벨업 시 증가). 평판과 영업 기록으로 새 상인이 해금됩니다." % [GameManager.state.staff_list().size(), GameManager.staff.staff_slots()], "caption"))
	for id in DataManager.employees.keys():
		_employee_card(id)


func _employee_card(id: String) -> void:
	var def: Dictionary = DataManager.employees[id]
	var hired: bool = GameManager.staff.is_hired(id)
	var unlocked: bool = GameManager.staff.is_unlocked(id)
	var card := UIKit.card(UIKit.PANEL_LIGHT if hired else UIKit.PANEL_DARK)
	var col := UIKit.vbox(8)
	card.add_child(col)
	var head := UIKit.hbox(12)
	col.add_child(head)
	var avatar := ColorRect.new()
	avatar.color = DataManager.color(def.get("color", "#E9C46A"))
	avatar.custom_minimum_size = Vector2(56, 56)
	head.add_child(avatar)
	var nv := UIKit.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nv)
	nv.add_child(UIKit.label(str(def.get("name", "")), "section"))
	nv.add_child(UIKit.label(str(def.get("role", "")), "caption", UIKit.ACCENT))
	if hired:
		var lv: int = GameManager.staff.level_of(id)
		head.add_child(UIKit.label("Lv.%d/%d" % [lv, GameManager.staff.max_level()], "number", UIKit.ACCENT))
	elif not unlocked:
		head.add_child(UIKit.icon("lock", 40))
	col.add_child(UIKit.label(str(def.get("desc", "")), "caption", UIKit.TEXT))
	col.add_child(UIKit.label("능력: " + GameManager.staff.describe_effects(id), "body", UIKit.SUCCESS))
	var op: bool = GameManager.is_operating
	if hired:
		var working: bool = GameManager.state.is_staff_active(id)
		col.add_child(UIKit.label("포차에서 근무 중" if working else "쉬는 중", "body", UIKit.SUCCESS if working else UIKit.TEXT_SUB))
		var row := UIKit.hbox(10)
		col.add_child(row)
		var wb := UIKit.button("근무 해제" if working else "근무 배치", "secondary" if working else "success", 72)
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.set_enabled(wb, not op)
		wb.pressed.connect(func(): GameManager.set_staff_working(id, not working))
		row.add_child(wb)
		var cost: int = GameManager.staff.level_up_cost(id)
		var lb := UIKit.button("최고 레벨" if cost < 0 else "레벨업 -%s" % UIKit.fmt(cost), "primary", 72)
		lb.custom_minimum_size = Vector2(230, 72)
		UIKit.set_enabled(lb, cost >= 0 and GameManager.economy.can_afford(cost) and not op)
		lb.pressed.connect(func(): GameManager.level_up_employee(id))
		row.add_child(lb)
	elif unlocked:
		var cost2: int = GameManager.staff.hire_cost(id)
		var hb := UIKit.button("고용하기 -%s 코인" % UIKit.fmt(cost2), "success", 80)
		UIKit.set_enabled(hb, GameManager.economy.can_afford(cost2) and not op)
		hb.pressed.connect(func(): GameManager.hire_employee(id))
		col.add_child(hb)
	else:
		col.add_child(UIKit.label("해금 조건: " + GameManager.progression.describe_condition(def.get("unlock", {})), "body", UIKit.TEXT_SUB))
	content.add_child(card)
