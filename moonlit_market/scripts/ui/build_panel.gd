extends "res://scripts/ui/base_panel.gd"
## F. 건설 및 장식 화면 — 설치 가능한 노점/시설, 구매 비용, 잠금 조건, 장식 목록, 시너지 표시

var tab: String = "stall"


func _configure() -> void:
	title_text = "건설 · 장식"
	sheet_ratio = 0.88
	tab = str(args.get("tab", "stall"))


func build() -> void:
	var tabs := UIKit.hbox(8)
	for t in [["stall", "노점"], ["facility", "시설"], ["deco", "장식"], ["synergy", "시너지"]]:
		var id: String = t[0]
		var b := UIKit.button(t[1], "primary" if tab == id else "secondary", 68)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			tab = id
			queue_refresh()
		)
		tabs.add_child(b)
	content.add_child(tabs)
	match tab:
		"stall":
			_build_structures(true)
		"facility":
			_build_structures(false)
		"deco":
			_build_decos()
		_:
			_build_synergies()


func _build_structures(stalls: bool) -> void:
	var empty := 0
	for i in GameManager.state.slots.size():
		if GameManager.state.is_slot_empty(i):
			empty += 1
	content.add_child(UIKit.label("빈 자리 %d / 6 · 설치를 누른 뒤 시장에서 자리를 고르세요." % empty, "caption"))
	var src: Dictionary = DataManager.stalls if stalls else DataManager.facilities
	for id in src.keys():
		var def: Dictionary = src[id]
		var unlocked: bool = GameManager.progression.is_stall_unlocked(id) if stalls else GameManager.progression.is_facility_unlocked(id)
		var cost := int(def.get("build_cost", 0))
		var card := UIKit.card()
		var col := UIKit.vbox(8)
		card.add_child(col)
		var row := UIKit.hbox(10)
		col.add_child(row)
		var t := UIKit.label(str(def.get("name", "")), "section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(UIKit.currency("coin", cost))
		if stalls:
			var names: Array = []
			for m in def.get("menus", []):
				var md: Dictionary = DataManager.get_menu(m)
				names.append("%s %d" % [md.get("name", m), int(md.get("price", 0))])
			col.add_child(UIKit.label("메뉴: " + ", ".join(names), "caption"))
			var owned := 0
			for s in GameManager.state.slots:
				if s.get("type", "") == id:
					owned += 1
			if owned > 0:
				col.add_child(UIKit.label("보유 %d개" % owned, "caption", UIKit.SUCCESS))
		else:
			col.add_child(UIKit.label(str(def.get("desc", "")), "caption"))
		var b: Button
		if unlocked:
			b = UIKit.button("설치하기", "primary", 76)
			UIKit.set_enabled(b, GameManager.economy.can_afford(cost) and empty > 0)
			if empty == 0:
				b.text = "빈 자리 없음"
			b.pressed.connect(func():
				GameManager.request_placement(id)
				close()
			)
		else:
			b = UIKit.button("잠김 · " + GameManager.progression.describe_condition(def.get("unlock", {})), "secondary", 76)
			UIKit.set_enabled(b, false)
		col.add_child(b)
		content.add_child(card)


func _build_decos() -> void:
	var spots: int = GameManager.progression.deco_spot_count()
	var used := 0
	for i in spots:
		if GameManager.state.deco_spots[i] != "":
			used += 1
	content.add_child(UIKit.label("장식 자리 %d / %d 사용 중 (시장 단계가 오르면 늘어납니다)" % [used, spots], "caption"))
	for id in DataManager.decorations.keys():
		var def: Dictionary = DataManager.decorations[id]
		var owned: bool = GameManager.state.decorations_owned.has(id)
		var placed: bool = GameManager.state.deco_spots.has(id)
		var unlocked: bool = GameManager.progression.is_decoration_unlocked(id)
		var card := UIKit.card()
		var col := UIKit.vbox(8)
		card.add_child(col)
		var row := UIKit.hbox(10)
		col.add_child(row)
		var sw := ColorRect.new()
		sw.color = DataManager.color(def.get("color", "#FFB45C"))
		sw.custom_minimum_size = Vector2(36, 36)
		row.add_child(sw)
		var t := UIKit.label(str(def.get("name", "")), "section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		if not owned:
			row.add_child(UIKit.currency("coin", int(def.get("cost", 0))))
		col.add_child(UIKit.label(str(def.get("desc", "")), "caption"))
		var b: Button
		if owned:
			b = UIKit.button("보관하기" if placed else "설치하기", "secondary" if placed else "success", 72)
			b.pressed.connect(func(): GameManager.toggle_decoration(id))
		elif unlocked:
			b = UIKit.button("구매 -%s 코인" % UIKit.fmt(int(def.get("cost", 0))), "primary", 72)
			UIKit.set_enabled(b, GameManager.economy.can_afford(int(def.get("cost", 0))))
			b.pressed.connect(func(): GameManager.buy_decoration(id))
		else:
			b = UIKit.button("잠김 · " + GameManager.progression.describe_condition(def.get("unlock", {})), "secondary", 72)
			UIKit.set_enabled(b, false)
		col.add_child(b)
		content.add_child(card)
	content.add_child(UIKit.label("TODO: 유료 장식 패키지는 결제 연동 후 추가됩니다.", "caption"))


func _build_synergies() -> void:
	content.add_child(UIKit.label("6개 자리 중 서로 이웃한 자리(같은 줄 위아래, 통로 건너편 마주보기)의 조합으로 시너지가 생깁니다.", "caption"))
	var active: Array = GameManager.synergy_cache.get("active", [])
	for d in DataManager.synergies:
		var on: bool = active.has(d["id"])
		var col_c := DataManager.color(d.get("color", "#FFB45C"))
		var card := UIKit.card(col_c.darkened(0.55) if on else UIKit.PANEL_DARK)
		var v := UIKit.vbox(4)
		card.add_child(v)
		var row := UIKit.hbox(8)
		v.add_child(row)
		var t := UIKit.label(str(d.get("name", "")), "section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(UIKit.label("활성" if on else "비활성", "body", UIKit.SUCCESS if on else UIKit.TEXT_SUB))
		v.add_child(UIKit.label(str(d.get("desc", "")), "caption", UIKit.TEXT))
		content.add_child(card)
	# 자리 배치도
	section("현재 배치")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for r in 3:
		for side in 2:
			var i := r + side * 3
			var s: Dictionary = GameManager.state.get_slot(i)
			var nm := "빈 자리"
			if s.get("kind", "") == "stall":
				nm = str(DataManager.get_stall(str(s["type"])).get("name", ""))
			elif s.get("kind", "") == "facility":
				nm = str(DataManager.get_facility(str(s["type"])).get("name", ""))
			var c := UIKit.card(UIKit.PANEL_LIGHT if not s.is_empty() else UIKit.PANEL_DARK, 12)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var n := GameManager.slot_synergies(i).size()
			c.add_child(UIKit.label("%d. %s%s" % [i + 1, nm, ("  ★%d" % n) if n > 0 else ""], "body"))
			grid.add_child(c)
	content.add_child(grid)
