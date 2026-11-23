extends "res://scripts/ui/base_panel.gd"
## B. 영업 준비 화면 — 메뉴 선택, 가격 설정, 재고 확인/구매, 상인 배치, 예상 매출, 영업 시작

const CustomerAI := preload("res://scripts/customer/customer_ai.gd")

var estimate_label: Label
var stall_estimates: Dictionary = {}


func _configure() -> void:
	title_text = "영업 준비"
	sheet_ratio = 0.9


func build() -> void:
	# 오늘의 날씨
	var w: Dictionary = DataManager.get_weather(GameManager.state.today_weather)
	var wc := UIKit.card()
	var wr := UIKit.hbox(14)
	wc.add_child(wr)
	var wid := str(GameManager.state.today_weather)
	wr.add_child(UIKit.icon("sun" if wid == "sunny" else ("rain" if wid == "rain" else "cloud"), 56))
	var wv := UIKit.vbox(2)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.add_child(UIKit.label("오늘의 날씨: %s" % w.get("name", ""), "section"))
	wv.add_child(UIKit.label(str(w.get("desc", "")), "caption"))
	wr.add_child(wv)
	content.add_child(wc)
	# 시너지 요약
	var active: Array = GameManager.synergy_cache.get("active", [])
	if active.size() > 0:
		var names: Array = []
		for d in DataManager.synergies:
			if active.has(d["id"]):
				names.append(d["name"])
		content.add_child(UIKit.label("활성 시너지: " + ", ".join(names), "body", UIKit.SUCCESS))
	# 노점별 준비
	section("노점별 준비")
	stall_estimates.clear()
	var any := false
	for i in GameManager.state.slots.size():
		if GameManager.state.is_stall(i):
			any = true
			_stall_card(i)
	if not any:
		content.add_child(UIKit.label("설치된 노점이 없습니다.", "body"))
	# 예상 매출
	section("예상 결과")
	var ec := UIKit.card(UIKit.PANEL_DARK)
	estimate_label = UIKit.label("", "body")
	ec.add_child(estimate_label)
	content.add_child(ec)
	_update_estimate()
	content.add_child(UIKit.label("예상치는 참고용입니다. 실제 결과는 손님 취향, 대기열, 이벤트에 따라 달라집니다.", "caption"))
	var total_restock := 0
	for i in GameManager.state.slots.size():
		total_restock += GameManager.economy.restock_cost(i)
	footer_button("재고 전부 채우기\n-%s" % UIKit.fmt(total_restock), "success", func(): GameManager.restock_all(), total_restock > 0 and GameManager.state.coins > 0)
	var reason: String = ui.main.can_start_session() if ui and ui.main else ""
	var start := footer_button("영업 시작 (%d초)" % int(DataManager.bal("session_duration", 240.0)), "primary", _on_start, reason == "")
	if reason != "":
		start.text = "영업 불가"
		content.add_child(UIKit.label(reason, "body", UIKit.DANGER))


func _stall_card(i: int) -> void:
	var s: Dictionary = GameManager.state.get_slot(i)
	var def: Dictionary = DataManager.get_stall(str(s["type"]))
	var card := UIKit.card()
	var col := UIKit.vbox(8)
	card.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.label("자리 %d · %s Lv.%d" % [i + 1, def.get("name", ""), int(s.get("level", 1))], "section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var detail := UIKit.button("상세", "secondary", 60)
	detail.custom_minimum_size = Vector2(96, 60)
	detail.pressed.connect(func(): ui.open("stall", {"slot": i}))
	head.add_child(detail)
	# 메뉴 선택
	var mrow := UIKit.hbox(8)
	for m in def.get("menus", []):
		var ok: bool = GameManager.economy.is_menu_available(i, m)
		var sel: bool = s.get("menu", "") == m
		var b := UIKit.button(str(DataManager.get_menu(m).get("name", m)) + ("" if ok else " (잠김)"), "primary" if sel else "secondary", 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.set_enabled(b, ok)
		var mid: String = m
		if not sel:
			b.pressed.connect(func(): GameManager.set_menu(i, mid))
		mrow.add_child(b)
	col.add_child(mrow)
	# 가격
	var price_l := UIKit.label("", "body", UIKit.ACCENT)
	col.add_child(price_l)
	var slider := HSlider.new()
	slider.min_value = float(DataManager.bal("price_ratio_min", 0.8))
	slider.max_value = float(DataManager.bal("price_ratio_max", 1.3))
	slider.step = float(DataManager.bal("price_ratio_step", 0.05))
	slider.value = float(s.get("price_ratio", 1.0))
	slider.custom_minimum_size = Vector2(0, 52)
	col.add_child(slider)
	var upd := func():
		var ratio := float(GameManager.state.get_slot(i).get("price_ratio", 1.0))
		price_l.text = "가격 %s 코인 (%d%%) · 개당 이익 %d" % [UIKit.fmt(GameManager.economy.unit_price(i)), int(round(ratio * 100)), GameManager.economy.unit_price(i) - GameManager.economy.unit_cost(i)]
	upd.call()
	slider.value_changed.connect(func(v: float):
		GameManager.set_price_ratio(i, v)
		upd.call()
		_update_estimate()
	)
	slider.drag_ended.connect(func(_c: bool): GameManager.save_game("price"))
	# 재고 + 상인
	var row := UIKit.hbox(10)
	col.add_child(row)
	var stock := int(s.get("stock", 0))
	var smax: int = GameManager.economy.stock_max(i)
	var sl := UIKit.label("재고 %d/%d" % [stock, smax], "body", UIKit.SUCCESS if stock > 0 else UIKit.DANGER)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(sl)
	var rc: int = GameManager.economy.restock_cost(i)
	var rb := UIKit.button("채우기 -%s" % UIKit.fmt(rc) if rc > 0 else "가득", "success", 64)
	rb.custom_minimum_size = Vector2(220, 64)
	UIKit.set_enabled(rb, rc > 0 and GameManager.state.coins > 0)
	rb.pressed.connect(func(): GameManager.restock(i))
	row.add_child(rb)
	var emp := str(s.get("employee", ""))
	var emp_text := "상인: " + (str(DataManager.get_employee(emp).get("name", "")) if emp != "" else "없음 (상세에서 배치)")
	col.add_child(UIKit.label(emp_text, "caption", UIKit.TEXT_SUB))
	content.add_child(card)


## 간단한 예상: 조리 가능 수량, 재고, 평균 손님 가격 반응을 조합한 추정치
func _estimate_slot(i: int) -> Dictionary:
	var s: Dictionary = GameManager.state.get_slot(i)
	var menu: Dictionary = GameManager.economy.menu_for_slot(i)
	if menu.is_empty():
		return {"sales": 0, "revenue": 0}
	var mods: Dictionary = GameManager.slot_modifiers(i)
	var duration := float(DataManager.bal("session_duration", 240.0))
	var cook := float(menu.get("cook_time", 6.0)) / maxf(0.1, float(mods.get("cook_speed", 1.0)))
	var capacity := duration / (cook + 1.5)
	var ratio := float(s.get("price_ratio", 1.0))
	var demand := 0.0
	for id in DataManager.customers.keys():
		var ct: Dictionary = DataManager.customers[id]
		demand += CustomerAI.purchase_probability(ct, ratio, float(mods.get("price_tolerance", 0.0)), 1.0, 0.97, 1.3)
	demand /= maxf(1.0, DataManager.customers.size())
	var sales := int(minf(float(s.get("stock", 0)), capacity * 0.7 * demand))
	return {"sales": sales, "revenue": sales * GameManager.economy.unit_price(i), "cogs": sales * GameManager.economy.unit_cost(i)}


func _update_estimate() -> void:
	if estimate_label == null:
		return
	var sales := 0
	var revenue := 0
	var cogs := 0
	for i in GameManager.state.slots.size():
		if GameManager.state.is_stall(i):
			var e := _estimate_slot(i)
			sales += int(e["sales"])
			revenue += int(e["revenue"])
			cogs += int(e.get("cogs", 0))
	estimate_label.text = "예상 판매 약 %d개\n예상 매출 약 %s 코인 · 예상 순수익 약 %s 코인" % [sales, UIKit.fmt(revenue), UIKit.fmt(revenue - cogs)]


func _on_start() -> void:
	if ui and ui.main and ui.main.start_session():
		close()
