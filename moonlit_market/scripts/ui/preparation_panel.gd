extends "res://scripts/ui/base_panel.gd"
## B. 영업 준비 — 오늘 날씨, 메뉴별 재료/가격, 근무 상인, 메뉴 궁합, 경쟁 노점, 영업 시작

func _configure() -> void:
	title_text = "영업 준비"
	sheet_ratio = 0.9


func build() -> void:
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
	# 라이벌 대결의 밤
	if GameManager.goals.is_showdown_today():
		var rv: Dictionary = DataManager.get_rival(str(GameManager.state.showdown["rival"]))
		var sdm: Dictionary = DataManager.goals_meta.get("showdown", {})
		var sc := UIKit.card(Color("#6A2E2E"))
		var sv := UIKit.vbox(4)
		sc.add_child(sv)
		sv.add_child(UIKit.label("오늘은 대결의 밤! vs %s" % rv.get("name", ""), "section", UIKit.ACCENT))
		sv.add_child(UIKit.label("오늘 매출로 이기면 코인 +%d · 평판 +%d, 그 가게 평판 -%d. 지면 평판 %d. 라이벌도 실력을 발휘합니다." % [int(sdm.get("win_coins", 500)), int(sdm.get("win_rep", 12)), int(sdm.get("rival_rep_loss", 10)), int(sdm.get("lose_rep", -4))], "caption", UIKit.TEXT))
		content.add_child(sc)
	# 오늘의 목표
	section("오늘의 목표")
	var gc := UIKit.card()
	var gv := UIKit.vbox(6)
	gc.add_child(gv)
	for g in GameManager.state.daily_goals:
		var def: Dictionary = GameManager.goals.goal_def(str(g["id"]))
		info_row(gv, "· " + GameManager.goals.describe(g), "+%d 코인 · 평판 +%d" % [int(def.get("reward_coins", 0)), int(def.get("reward_rep", 0))], UIKit.ACCENT)
	content.add_child(gc)
	if GameManager.state.next_visitor_bonus > 0.0:
		content.add_child(UIKit.label("SNS 후기 효과: 오늘 손님 +%d%%" % int(GameManager.state.next_visitor_bonus * 100), "body", UIKit.SUCCESS))
	# 오늘 장사하는 경쟁 노점
	var rivals: Array = []
	for id in GameManager.progression.active_rivals():
		rivals.append(DataManager.get_rival(id).get("name", id))
	content.add_child(UIKit.label("오늘의 경쟁 노점: " + ", ".join(rivals), "body", UIKit.TEXT_SUB))
	# 메뉴별 재료/가격
	section("메뉴 · 재료")
	content.add_child(UIKit.label("재료가 없는 메뉴는 주문을 받을 수 없습니다. 남은 재료는 영업 후 %d%% 상합니다." % int(float(DataManager.bal("spoilage_rate", 0.15)) * 100), "caption"))
	for id in GameManager.state.enabled_menus():
		_menu_row(id)
	var edit := UIKit.button("메뉴판 바꾸기 (내 포차)", "secondary", 72)
	edit.pressed.connect(func(): ui.open("pocha"))
	content.add_child(edit)
	# 근무 상인
	section("근무 상인")
	var names: Array = []
	for e in GameManager.state.staff_list():
		names.append("%s (%s)" % [DataManager.get_employee(e).get("name", e), GameManager.staff.describe_effects(e)])
	var slots: int = GameManager.staff.staff_slots()
	content.add_child(UIKit.label(("\n".join(names) if names.size() > 0 else "근무 중인 상인 없음") + "\n자리 %d/%d" % [names.size(), slots], "body"))
	var staff_b := UIKit.button("상인 배치하기", "secondary", 72)
	staff_b.pressed.connect(func(): ui.open("employee"))
	content.add_child(staff_b)
	# 메뉴 궁합
	var list: Array = GameManager.synergy_cache.get("list", [])
	if list.size() > 0:
		var pn: Array = []
		for p in list:
			pn.append(p["name"])
		content.add_child(UIKit.label("활성 메뉴 궁합: " + ", ".join(pn), "body", UIKit.SUCCESS))
	# 조작 안내
	var tip := UIKit.card(UIKit.PANEL_DARK)
	tip.add_child(UIKit.label("영업 중 조작\n· 음식 버튼 → 화구에 올라감 → 링이 초록색(지금!)일 때 탭 → 서빙대\n· 꼬치·파전은 파란 구간에서 한 번 탭해 뒤집기 (안 뒤집으면 한쪽만 익음)\n· 「바싹」 요청은 조금 더, 「덜」 요청은 조금 덜 익혀서\n· 음료는 꾹 눌러 선까지, 소맥은 소주(파란 선) → 맥주(초록 선)\n· 손님 탭 → 서빙, 빈 테이블 탭 → 치우기, 조는 손님 탭 → 깨우기", "body"))
	content.add_child(tip)
	var total_restock: int = GameManager.economy.restock_all_cost()
	footer_button("재료 전부 채우기\n-%s" % UIKit.fmt(total_restock), "success", func(): GameManager.restock_all(), total_restock > 0 and GameManager.state.coins > 0)
	var reason: String = ui.main.can_start_session() if ui and ui.main else ""
	var start := footer_button("영업 시작 (%d초)" % int(DataManager.bal("session_duration", 240.0)), "primary", _on_start, reason == "")
	if reason != "":
		start.text = "영업 불가"
		content.add_child(UIKit.label(reason, "body", UIKit.DANGER))


func _menu_row(id: String) -> void:
	var m: Dictionary = DataManager.get_menu(id)
	var card := UIKit.card()
	var col := UIKit.vbox(6)
	card.add_child(col)
	var row := UIKit.hbox(10)
	col.add_child(row)
	var stock: int = GameManager.state.stock_of(id)
	var t := UIKit.label("%s · 재료 %d/%d" % [m.get("name", ""), stock, GameManager.economy.stock_max()], "body", UIKit.TEXT if stock > 0 else UIKit.DANGER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(t)
	var rc: int = GameManager.economy.restock_cost(id)
	var rb := UIKit.button("채우기 -%s" % UIKit.fmt(rc) if rc > 0 else "가득", "success", 60)
	rb.custom_minimum_size = Vector2(200, 60)
	UIKit.set_enabled(rb, rc > 0 and GameManager.state.coins > 0)
	rb.pressed.connect(func(): GameManager.restock(id))
	row.add_child(rb)
	var price_l := UIKit.label("", "caption", UIKit.ACCENT)
	col.add_child(price_l)
	var upd := func():
		var r := float(GameManager.state.menu_entry(id).get("price_ratio", 1.0))
		price_l.text = "가격 %s 코인 (%d%%) · 개당 이익 %d" % [UIKit.fmt(GameManager.economy.unit_price(id)), int(round(r * 100)), GameManager.economy.unit_price(id) - GameManager.economy.unit_cost(id)]
	upd.call()
	var slider := HSlider.new()
	slider.min_value = float(DataManager.bal("price_ratio_min", 0.8))
	slider.max_value = float(DataManager.bal("price_ratio_max", 1.3))
	slider.step = float(DataManager.bal("price_ratio_step", 0.05))
	slider.value = float(GameManager.state.menu_entry(id).get("price_ratio", 1.0))
	slider.custom_minimum_size = Vector2(0, 46)
	slider.value_changed.connect(func(v: float):
		GameManager.set_price_ratio(id, v)
		upd.call()
	)
	slider.drag_ended.connect(func(_c: bool): GameManager.save_game("price"))
	col.add_child(slider)
	content.add_child(card)


func _on_start() -> void:
	if ui and ui.main and ui.main.start_session():
		close()
