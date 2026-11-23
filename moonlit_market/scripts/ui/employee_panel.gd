extends "res://scripts/ui/base_panel.gd"
## D. 상인 관리 화면 — 상인 목록, 능력치, 레벨, 배치 상태, 해금 조건, 고용/레벨업/배치

func _configure() -> void:
	title_text = "상인 관리"
	sheet_ratio = 0.88


func build() -> void:
	content.add_child(UIKit.label("상인은 한 번에 한 노점에만 배치할 수 있습니다. 평판과 영업 기록으로 새 상인이 해금됩니다.", "caption"))
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
	var sp: Dictionary = def.get("special", {})
	if not sp.is_empty():
		col.add_child(UIKit.label("특별 시너지: %s 배치 시 추가 효과" % DataManager.get_stall(str(sp.get("stall_type", ""))).get("name", ""), "caption", UIKit.REP))
	var op: bool = GameManager.is_operating
	if hired:
		var where: int = GameManager.state.employee_slot(id)
		var where_text := "대기 중 (배치 안 됨)"
		if where >= 0:
			where_text = "배치: 자리 %d · %s" % [where + 1, DataManager.get_stall(str(GameManager.state.slots[where]["type"])).get("name", "")]
		col.add_child(UIKit.label(where_text, "body"))
		var row := UIKit.hbox(10)
		col.add_child(row)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(0, 72)
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_item("배치 선택", 0)
		ob.set_item_metadata(0, -2)
		ob.add_item("배치 해제", 1)
		ob.set_item_metadata(1, -1)
		var k := 2
		for i in GameManager.state.slots.size():
			if GameManager.state.is_stall(i):
				ob.add_item("자리 %d · %s" % [i + 1, DataManager.get_stall(str(GameManager.state.slots[i]["type"])).get("name", "")], k)
				ob.set_item_metadata(k, i)
				k += 1
		ob.select(0)
		ob.disabled = op
		ob.item_selected.connect(func(sel: int):
			var target := int(ob.get_item_metadata(sel))
			if target == -1:
				var cur: int = GameManager.state.employee_slot(id)
				if cur >= 0:
					GameManager.assign_employee("", cur)
			elif target >= 0:
				GameManager.assign_employee(id, target)
		)
		row.add_child(ob)
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
