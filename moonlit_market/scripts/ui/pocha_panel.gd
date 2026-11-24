extends "res://scripts/ui/base_panel.gd"
## 내 포차 — 메뉴판(메뉴 올리기/내리기), 가격, 재료, 업그레이드, 근무 상인, 메뉴 궁합, 통계

func _configure() -> void:
	title_text = "달빛포차  Lv.%d" % GameManager.state.pocha_level()
	sheet_ratio = 0.88


func build() -> void:
	title_text = "달빛포차  Lv.%d" % GameManager.state.pocha_level()
	title_label.text = title_text
	var op: bool = GameManager.is_operating
	var lv: int = GameManager.state.pocha_level()
	var ldef: Dictionary = DataManager.get_pocha_level(lv)
	# 요약
	var summary := UIKit.card()
	var sv := UIKit.vbox(6)
	summary.add_child(sv)
	info_row(sv, "좌석", "%d석 (+대기 %d명)" % [int(ldef["seats"]), int(DataManager.pocha.get("waiting_spots", 3))])
	info_row(sv, "화구", "%d개" % int(ldef["burners"]))
	info_row(sv, "메뉴별 최대 재료", "%d개" % int(ldef["stock_max"]))
	info_row(sv, "근무 상인 자리", "%d명" % int(ldef["staff_slots"]))
	info_row(sv, "포차 평판", "%d / 100" % int(GameManager.state.pocha.get("rep", 0)), UIKit.REP)
	content.add_child(summary)
	if op:
		content.add_child(UIKit.label("영업 중에는 정보만 볼 수 있습니다.", "caption", UIKit.SECONDARY))
	# 업그레이드
	section("포차 업그레이드")
	var uc := UIKit.card()
	var uv := UIKit.vbox(8)
	uc.add_child(uv)
	var cost: int = GameManager.economy.upgrade_cost()
	if cost < 0:
		uv.add_child(UIKit.label("최고 레벨입니다.", "body", UIKit.SUCCESS))
	else:
		var nxt: Dictionary = DataManager.get_pocha_level(lv + 1)
		info_row(uv, "좌석", "%d → %d" % [int(ldef["seats"]), int(nxt["seats"])])
		info_row(uv, "화구", "%d → %d" % [int(ldef["burners"]), int(nxt["burners"])])
		info_row(uv, "최대 재료", "%d → %d" % [int(ldef["stock_max"]), int(nxt["stock_max"])])
		info_row(uv, "상인 자리", "%d → %d" % [int(ldef["staff_slots"]), int(nxt["staff_slots"])])
		var unlocks: Array = []
		for id in DataManager.pocha_menu_ids():
			if int(DataManager.get_menu(id).get("unlock", {}).get("pocha_level", 0)) == lv + 1:
				unlocks.append(DataManager.get_menu(id).get("name", id))
		if unlocks.size() > 0:
			info_row(uv, "새 메뉴", ", ".join(unlocks), UIKit.ACCENT)
		var ub := UIKit.button("Lv.%d 업그레이드  -%s 코인" % [lv + 1, UIKit.fmt(cost)], "primary", 84)
		if lv >= GameManager.progression.max_stall_level():
			ub.text = "시장 %d단계에서 해금" % (GameManager.state.market_level + 1)
			UIKit.set_enabled(ub, false)
		else:
			UIKit.set_enabled(ub, GameManager.economy.can_afford(cost) and not op)
		ub.pressed.connect(func(): GameManager.upgrade_pocha())
		uv.add_child(ub)
	content.add_child(uc)
	# 메뉴판
	section("메뉴판")
	content.add_child(UIKit.label("메뉴판에 올린 메뉴만 손님이 주문합니다. 음식은 화구에서 직접 굽고, 음료는 탭해서 따릅니다.", "caption"))
	for station in ["grill", "drink", "mix"]:
		for id in DataManager.pocha_menu_ids():
			var m: Dictionary = DataManager.get_menu(id)
			if str(m.get("station", "")) != station:
				continue
			_menu_card(id, m, op)
	_pairings()
	# 통계
	section("기록")
	var stc := UIKit.card()
	var stv := UIKit.vbox(6)
	stc.add_child(stv)
	var st: Dictionary = GameManager.state.pocha.get("stats", {})
	info_row(stv, "지난 영업 판매", "%d개" % int(st.get("last_sold", 0)))
	info_row(stv, "지난 영업 매출", "%s 코인" % UIKit.fmt(int(st.get("last_revenue", 0))))
	info_row(stv, "누적 판매", "%d개" % int(st.get("sold_total", 0)))
	info_row(stv, "누적 매출", "%s 코인" % UIKit.fmt(int(st.get("revenue_total", 0))))
	info_row(stv, "완벽하게 구운 요리", "%d개" % int(GameManager.state.lifetime.get("perfect", 0)), UIKit.SUCCESS)
	info_row(stv, "태운 요리", "%d개" % int(GameManager.state.lifetime.get("burnt", 0)), UIKit.DANGER)
	content.add_child(stc)


func _menu_card(id: String, m: Dictionary, op: bool) -> void:
	var unlocked: bool = GameManager.economy.is_menu_unlocked(id, GameManager.progression)
	var enabled: bool = GameManager.state.is_menu_enabled(id)
	var card := UIKit.card(UIKit.PANEL_LIGHT if enabled else UIKit.PANEL_DARK)
	var col := UIKit.vbox(6)
	card.add_child(col)
	var row := UIKit.hbox(10)
	col.add_child(row)
	var t := UIKit.label("%s%s" % [m.get("name", ""), "  (음료)" if m.get("station", "") == "drink" else ""], "section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(t)
	if not unlocked:
		row.add_child(UIKit.icon("lock", 34))
		col.add_child(UIKit.label("해금: " + GameManager.progression.describe_condition(m.get("unlock", {})), "caption"))
		content.add_child(card)
		return
	var tb := UIKit.button("판매 중" if enabled else "메뉴에 올리기", "success" if enabled else "secondary", 60)
	tb.custom_minimum_size = Vector2(170, 60)
	UIKit.set_enabled(tb, not op)
	tb.pressed.connect(func(): GameManager.set_menu_enabled(id, not enabled))
	row.add_child(tb)
	var info := "원가 %d · 기준가 %d" % [int(m.get("cost", 0)), int(m.get("price", 0))]
	if m.get("station", "") == "grill":
		info += " · 굽는 시간 %.0f초" % float(m.get("cook_time", 0))
	if bool(m.get("alcohol", false)):
		info += " · 주류(학생·가족 X)"
	col.add_child(UIKit.label(info, "caption"))
	if not enabled:
		content.add_child(card)
		return
	var price_l := UIKit.label("", "body", UIKit.ACCENT)
	col.add_child(price_l)
	var upd := func():
		var r := float(GameManager.state.menu_entry(id).get("price_ratio", 1.0))
		price_l.text = "판매가 %s 코인 (%d%%) · 개당 이익 %d" % [UIKit.fmt(GameManager.economy.unit_price(id)), int(round(r * 100)), GameManager.economy.unit_price(id) - GameManager.economy.unit_cost(id)]
	upd.call()
	var slider := HSlider.new()
	slider.min_value = float(DataManager.bal("price_ratio_min", 0.8))
	slider.max_value = float(DataManager.bal("price_ratio_max", 1.3))
	slider.step = float(DataManager.bal("price_ratio_step", 0.05))
	slider.value = float(GameManager.state.menu_entry(id).get("price_ratio", 1.0))
	slider.custom_minimum_size = Vector2(0, 50)
	slider.editable = not op
	slider.value_changed.connect(func(v: float):
		GameManager.set_price_ratio(id, v)
		upd.call()
	)
	slider.drag_ended.connect(func(_c: bool): GameManager.save_game("price"))
	col.add_child(slider)
	var srow := UIKit.hbox(10)
	col.add_child(srow)
	var stock: int = GameManager.state.stock_of(id)
	var smax: int = GameManager.economy.stock_max()
	var sl := UIKit.label("재료 %d/%d" % [stock, smax], "body", UIKit.SUCCESS if stock > 0 else UIKit.DANGER)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	srow.add_child(sl)
	var rc: int = GameManager.economy.restock_cost(id)
	var rb := UIKit.button("채우기 -%s" % UIKit.fmt(rc) if rc > 0 else "가득", "success", 60)
	rb.custom_minimum_size = Vector2(200, 60)
	UIKit.set_enabled(rb, rc > 0 and not op and GameManager.state.coins > 0)
	rb.pressed.connect(func(): GameManager.restock(id))
	srow.add_child(rb)
	content.add_child(card)


func _pairings() -> void:
	section("메뉴 궁합")
	var active: Array = GameManager.synergy_cache.get("active", [])
	for p in DataManager.pairings:
		var on: bool = active.has(p["id"])
		var card := UIKit.card(DataManager.color(p.get("color", "#FFB45C")).darkened(0.6) if on else UIKit.PANEL_DARK, 14)
		var v := UIKit.vbox(2)
		card.add_child(v)
		var row := UIKit.hbox(8)
		v.add_child(row)
		var t := UIKit.label(str(p.get("name", "")), "section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(t)
		var s := UIKit.label("활성" if on else "비활성", "body", UIKit.SUCCESS if on else UIKit.TEXT_SUB)
		s.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(s)
		v.add_child(UIKit.label("%s + %s · %s" % [DataManager.get_menu(p["a"]).get("name", ""), DataManager.get_menu(p["b"]).get("name", ""), p.get("desc", "")], "caption", UIKit.TEXT))
		content.add_child(card)
