extends "res://scripts/ui/base_panel.gd"
## C. 노점 상세 화면 — 이름/레벨/메뉴/가격/재고/업그레이드/상인 배치/시너지/통계/이동·철거
## 빈 자리를 누르면 이 자리에 설치할 수 있는 노점/시설 목록을 보여준다.

var slot: int = 0
var price_label: Label
var demand_label: Label


func _configure() -> void:
	slot = int(args.get("slot", 0))
	sheet_ratio = 0.86
	_update_title()


func _update_title() -> void:
	var s: Dictionary = GameManager.state.get_slot(slot)
	match str(s.get("kind", "")):
		"stall":
			title_text = "%s  Lv.%d" % [DataManager.get_stall(str(s["type"])).get("name", "노점"), int(s.get("level", 1))]
		"facility":
			title_text = str(DataManager.get_facility(str(s["type"])).get("name", "시설"))
		_:
			title_text = "빈 자리 %d" % (slot + 1)


func build() -> void:
	_update_title()
	var s: Dictionary = GameManager.state.get_slot(slot)
	match str(s.get("kind", "")):
		"stall":
			_build_stall(s)
		"facility":
			_build_facility(s)
		_:
			_build_empty()


# ───────── 빈 자리: 설치 목록 ─────────

func _build_empty() -> void:
	content.add_child(UIKit.label("이 자리에 설치할 노점이나 시설을 고르세요. 옆 자리와의 조합에 따라 시너지가 생깁니다.", "caption"))
	_neighbor_hint()
	section("노점")
	for id in DataManager.stalls.keys():
		var def: Dictionary = DataManager.stalls[id]
		_build_option(id, def.get("name", ""), int(def.get("build_cost", 0)), _stall_desc(def),
			GameManager.progression.is_stall_unlocked(id), def.get("unlock", {}))
	section("시설")
	for id in DataManager.facilities.keys():
		var def: Dictionary = DataManager.facilities[id]
		_build_option(id, def.get("name", ""), int(def.get("build_cost", 0)), str(def.get("desc", "")),
			GameManager.progression.is_facility_unlocked(id), def.get("unlock", {}))


func _stall_desc(def: Dictionary) -> String:
	var names: Array = []
	for m in def.get("menus", []):
		names.append(DataManager.get_menu(m).get("name", m))
	return "메뉴: " + ", ".join(names) + " · 대기열 %d명" % int(def.get("queue_capacity", 4))


func _build_option(id: String, nm: String, cost: int, desc: String, unlocked: bool, cond) -> void:
	var card := UIKit.card()
	var col := UIKit.vbox(8)
	card.add_child(col)
	var row := UIKit.hbox(10)
	col.add_child(row)
	var t := UIKit.label(nm, "section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UIKit.currency("coin", cost))
	col.add_child(UIKit.label(desc, "caption"))
	var b: Button
	if unlocked:
		b = UIKit.button("이 자리에 설치", "primary", 80)
		UIKit.set_enabled(b, GameManager.economy.can_afford(cost))
		b.pressed.connect(func():
			var r: Dictionary = GameManager.build_structure(slot, id)
			if r.get("ok", false):
				close()
		)
	else:
		b = UIKit.button("잠김 · " + GameManager.progression.describe_condition(cond), "secondary", 80)
		UIKit.set_enabled(b, false)
	col.add_child(b)
	content.add_child(card)


func _neighbor_hint() -> void:
	var names: Array = []
	for n in GameManager.synergy.neighbors(slot):
		var ns: Dictionary = GameManager.state.get_slot(n)
		if ns.is_empty():
			continue
		if ns["kind"] == "stall":
			names.append(DataManager.get_stall(ns["type"]).get("name", ""))
		else:
			names.append(DataManager.get_facility(ns["type"]).get("name", ""))
	if names.size() > 0:
		content.add_child(UIKit.label("이웃: " + ", ".join(names), "caption", UIKit.ACCENT))


# ───────── 시설 ─────────

func _build_facility(s: Dictionary) -> void:
	var def: Dictionary = DataManager.get_facility(str(s["type"]))
	content.add_child(UIKit.label(str(def.get("desc", "")), "body"))
	_synergy_section()
	_manage_section(false)


# ───────── 노점 ─────────

func _build_stall(s: Dictionary) -> void:
	var def: Dictionary = DataManager.get_stall(str(s["type"]))
	var level := int(s.get("level", 1))
	var op: bool = GameManager.is_operating
	# 요약
	var summary := UIKit.card()
	var sc := UIKit.vbox(6)
	summary.add_child(sc)
	info_row(sc, "노점 종류", str(def.get("name", "")))
	info_row(sc, "레벨", "%d / %d" % [level, DataManager.max_stall_level()])
	info_row(sc, "노점 평판", "%d / 100" % int(s.get("rep", 0)), UIKit.REP)
	info_row(sc, "대기열 수용", "%d명" % int(def.get("queue_capacity", 4)))
	content.add_child(summary)
	if op:
		content.add_child(UIKit.label("영업 중에는 정보만 볼 수 있습니다.", "caption", UIKit.SECONDARY))
	# 메뉴
	section("판매 메뉴")
	var menu_row := UIKit.hbox(10)
	for m in def.get("menus", []):
		var mdef: Dictionary = DataManager.get_menu(m)
		var available: bool = GameManager.economy.is_menu_available(slot, m)
		var selected: bool = s.get("menu", "") == m
		var need := int((def.get("menu_unlock_level", {}) as Dictionary).get(m, 1))
		var label_text := "%s\n%d코인 · %.0f초" % [mdef.get("name", m), int(mdef.get("price", 0)), float(mdef.get("cook_time", 0))]
		if not available:
			label_text = "%s\nLv.%d 해금" % [mdef.get("name", m), need]
		var b := UIKit.button(label_text, "primary" if selected else "secondary", 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.set_enabled(b, available and not selected and not op)
		var menu_id: String = m
		b.pressed.connect(func(): GameManager.set_menu(slot, menu_id))
		menu_row.add_child(b)
	content.add_child(menu_row)
	var menu: Dictionary = GameManager.economy.menu_for_slot(slot)
	if not menu.is_empty():
		var pref_names: Array = []
		for c in menu.get("preferred_customers", []):
			pref_names.append(DataManager.get_customer_type(c).get("name", c))
		content.add_child(UIKit.label("원가 %d · 인기 %d%% · %s 선호" % [int(menu.get("cost", 0)), int(float(menu.get("popularity", 0)) * 100), ", ".join(pref_names)], "caption"))
	# 가격
	section("판매 가격")
	var price_card := UIKit.card()
	var pc := UIKit.vbox(8)
	price_card.add_child(pc)
	price_label = UIKit.label("", "number", UIKit.ACCENT)
	pc.add_child(price_label)
	var slider := HSlider.new()
	slider.min_value = float(DataManager.bal("price_ratio_min", 0.8))
	slider.max_value = float(DataManager.bal("price_ratio_max", 1.3))
	slider.step = float(DataManager.bal("price_ratio_step", 0.05))
	slider.value = float(s.get("price_ratio", 1.0))
	slider.custom_minimum_size = Vector2(0, 56)
	slider.editable = not op
	slider.value_changed.connect(func(v: float):
		GameManager.set_price_ratio(slot, v)
		_update_price_labels()
	)
	slider.drag_ended.connect(func(_changed: bool): GameManager.save_game("price"))
	pc.add_child(slider)
	demand_label = UIKit.label("", "caption")
	pc.add_child(demand_label)
	content.add_child(price_card)
	_update_price_labels()
	# 재고
	section("재고")
	var stock_card := UIKit.card()
	var stc := UIKit.vbox(8)
	stock_card.add_child(stc)
	var stock := int(s.get("stock", 0))
	var smax: int = GameManager.economy.stock_max(slot)
	info_row(stc, "현재 재고", "%d / %d" % [stock, smax], UIKit.SUCCESS if stock > 0 else UIKit.DANGER)
	stc.add_child(UIKit.progress_bar(stock, smax, UIKit.SUCCESS, 14))
	var rc: int = GameManager.economy.restock_cost(slot)
	var rb := UIKit.button("재고 채우기  -%s 코인" % UIKit.fmt(rc) if rc > 0 else "재고 가득", "success", 80)
	UIKit.set_enabled(rb, rc > 0 and not op and GameManager.state.coins > 0)
	rb.pressed.connect(func(): GameManager.restock(slot))
	stc.add_child(rb)
	stc.add_child(UIKit.label("재고 1개당 원가가 들고, 영업 후 남은 재고의 %d%%는 손실됩니다." % int(float(DataManager.bal("spoilage_rate", 0.15)) * 100), "caption"))
	content.add_child(stock_card)
	# 업그레이드
	section("업그레이드")
	var up_card := UIKit.card()
	var uc := UIKit.vbox(8)
	up_card.add_child(uc)
	var cost: int = GameManager.economy.upgrade_cost(slot)
	var cur_lv: Dictionary = DataManager.get_level(level)
	if cost < 0:
		uc.add_child(UIKit.label("최고 레벨입니다.", "body", UIKit.SUCCESS))
	else:
		var nxt: Dictionary = DataManager.get_level(level + 1)
		info_row(uc, "조리 속도", "x%.2f → x%.2f" % [cur_lv["cook_speed"], nxt["cook_speed"]])
		info_row(uc, "최대 재고", "%d → %d" % [int(cur_lv["stock_max"]), int(nxt["stock_max"])])
		info_row(uc, "판매 효율", "x%.2f → x%.2f" % [cur_lv["sales_efficiency"], nxt["sales_efficiency"]])
		for m in def.get("menus", []):
			if int((def.get("menu_unlock_level", {}) as Dictionary).get(m, 1)) == level + 1:
				info_row(uc, "메뉴 해금", str(DataManager.get_menu(m).get("name", m)), UIKit.ACCENT)
		var stage_max: int = GameManager.progression.max_stall_level()
		var ub := UIKit.button("Lv.%d 업그레이드  -%s 코인" % [level + 1, UIKit.fmt(cost)], "primary", 84)
		if level >= stage_max:
			ub.text = "시장 %d단계에서 해금" % (GameManager.state.market_level + 1)
			UIKit.set_enabled(ub, false)
		else:
			UIKit.set_enabled(ub, GameManager.economy.can_afford(cost) and not op)
		ub.pressed.connect(func(): GameManager.upgrade_stall(slot))
		uc.add_child(ub)
	content.add_child(up_card)
	# 상인
	section("상인 배치")
	var emp_card := UIKit.card()
	var ec := UIKit.vbox(8)
	emp_card.add_child(ec)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(0, 76)
	ob.add_item("배치 안 함", 0)
	ob.set_item_metadata(0, "")
	var current := str(s.get("employee", ""))
	var idx := 1
	for id in DataManager.employees.keys():
		if not GameManager.staff.is_hired(id):
			continue
		var where: int = GameManager.state.employee_slot(id)
		var nm := "%s (Lv.%d)" % [DataManager.employees[id]["name"], GameManager.staff.level_of(id)]
		if where >= 0 and where != slot:
			nm += " · 자리 %d에서 이동" % (where + 1)
		ob.add_item(nm, idx)
		ob.set_item_metadata(idx, id)
		if id == current:
			ob.select(idx)
		idx += 1
	if current == "":
		ob.select(0)
	ob.disabled = op
	ob.item_selected.connect(func(i: int): GameManager.assign_employee(str(ob.get_item_metadata(i)), slot))
	ec.add_child(ob)
	if current != "":
		ec.add_child(UIKit.label(GameManager.staff.describe_effects(current, str(s["type"])), "caption", UIKit.SUCCESS))
	content.add_child(emp_card)
	_synergy_section()
	# 통계
	section("영업 통계")
	var stat_card := UIKit.card()
	var stv := UIKit.vbox(6)
	stat_card.add_child(stv)
	var st: Dictionary = s.get("stats", {})
	info_row(stv, "지난 영업 판매", "%d개" % int(st.get("last_sold", 0)))
	info_row(stv, "지난 영업 매출", "%s 코인" % UIKit.fmt(int(st.get("last_revenue", 0))))
	info_row(stv, "누적 판매", "%d개" % int(st.get("sold_total", 0)))
	info_row(stv, "누적 매출", "%s 코인" % UIKit.fmt(int(st.get("revenue_total", 0))))
	content.add_child(stat_card)
	_manage_section(true)


func _update_price_labels() -> void:
	if price_label == null:
		return
	var s: Dictionary = GameManager.state.get_slot(slot)
	var ratio := float(s.get("price_ratio", 1.0))
	price_label.text = "%s 코인  (기준가의 %d%%)" % [UIKit.fmt(GameManager.economy.unit_price(slot)), int(round(ratio * 100))]
	var margin: int = GameManager.economy.unit_price(slot) - GameManager.economy.unit_cost(slot)
	var hint := "균형 잡힌 가격"
	if ratio >= 1.15:
		hint = "판매당 이익↑ · 구매 확률/만족도↓ (학생이 특히 민감)"
	elif ratio <= 0.9:
		hint = "구매 확률/만족도↑ · 판매당 이익↓"
	demand_label.text = "개당 이익 %d 코인 · %s" % [margin, hint]


func _synergy_section() -> void:
	section("시너지")
	var list: Array = GameManager.slot_synergies(slot)
	if list.is_empty():
		content.add_child(UIKit.label("활성 시너지 없음. 이웃 자리에 어울리는 노점을 배치해 보세요.", "caption"))
	for syn in list:
		var card := UIKit.card(Color(DataManager.color(syn.get("color", "#FFB45C")).darkened(0.6), 1.0), 14)
		var v := UIKit.vbox(4)
		card.add_child(v)
		v.add_child(UIKit.label("%s  (자리 %d와 연결)" % [syn.get("name", ""), int(syn.get("partner", 0)) + 1], "section"))
		var sd: Dictionary = {}
		for d in DataManager.synergies:
			if d["id"] == syn["id"]:
				sd = d
		v.add_child(UIKit.label(str(sd.get("desc", "")), "caption", UIKit.TEXT))
		content.add_child(card)
	# 이 노점 종류로 가능한 조합 안내
	var t := str(GameManager.state.get_slot(slot).get("type", ""))
	var hints: Array = []
	for d in DataManager.synergies:
		if (d.get("a", []) as Array).has(t) or (d.get("b", []) as Array).has(t):
			hints.append(str(d.get("name", "")))
	if hints.size() > 0:
		content.add_child(UIKit.label("가능한 조합: " + ", ".join(hints), "caption"))


func _manage_section(is_stall: bool) -> void:
	if GameManager.is_operating:
		return
	section("관리")
	var row := UIKit.hbox(10)
	var mv := UIKit.button("자리 이동", "secondary", 80)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.pressed.connect(func():
		GameManager.request_move(slot)
		close()
	)
	row.add_child(mv)
	var refund: int = GameManager.economy.demolish_refund(slot)
	var del := UIKit.button("철거 (+%s)" % UIKit.fmt(refund), "danger", 80)
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_stall and GameManager.state.stall_count() <= 1:
		UIKit.set_enabled(del, false)
	del.pressed.connect(func():
		ui.confirm("철거 확인", "정말 철거할까요? 건설비의 %d%%만 환급되며 남은 재고와 업그레이드는 사라집니다." % int(float(DataManager.bal("build_refund_rate", 0.5)) * 100), "철거", func():
			var r: Dictionary = GameManager.demolish(slot)
			if r.get("ok", false):
				close()
		, true)
	)
	row.add_child(del)
	content.add_child(row)
