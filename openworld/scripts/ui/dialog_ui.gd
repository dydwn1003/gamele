extends CanvasLayer
## NPC 대화창 + 상점(구매/판매) + 대장간(제작/강화). 열려 있는 동안 게임이 멈춘다.

const UI = preload("res://scripts/ui/ui_kit.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
const Items = preload("res://scripts/game/items.gd")
const Quests = preload("res://scripts/game/quests.gd")

const GREETINGS := {
	"elder": ["봉화가 꺼진 뒤로 밤이 길어졌소…", "기사여, 몸조심하시오.", "마을 사람들이 그대만 믿고 있소."],
	"merchant": ["어서 오세요! 물약 필요하시죠?", "좋은 물건 들어왔어요~", "재료는 비싸게 사드릴게요!"],
	"smith": ["쇠는 뜨거울 때 두드려야지.", "장비가 무르면 목숨도 무른 법이야.", "재료만 가져오면 뭐든 만들어주지."],
	"guard": ["마을 밖은 위험하다. 방심하지 마라.", "밤에는 망자들이 돌아다닌다.", "야영지의 놈들이 점점 늘고 있어."],
}

var player
var _npc := ""
var _root: Control
var _panel: PanelContainer
var _body: VBoxContainer
var _name_label: Label
var _mode := "talk"
var _sub := 0


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialog_ui")
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_root.add_child(_panel)
	var v := UI.vbox(10)
	_panel.add_child(v)
	_name_label = UI.label("", 28, Color(0.7, 1.0, 0.7))
	v.add_child(_name_label)
	_body = UI.vbox(10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	visible = false


func _place_panel(full: bool) -> void:
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	if full:
		_panel.anchor_top = 0.5
		_panel.anchor_bottom = 0.5
		_panel.offset_left = -560
		_panel.offset_right = 560
		_panel.offset_top = -330
		_panel.offset_bottom = 330
	else:
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.offset_left = -560
		_panel.offset_right = 560
		_panel.offset_top = -270
		_panel.offset_bottom = -20


func open_npc(id: String) -> void:
	_npc = id
	visible = true
	get_tree().paused = true
	GameState.notify("talk", id)
	_mode = "talk"
	_show_talk(GREETINGS[id][randi() % GREETINGS[id].size()])


func close() -> void:
	visible = false
	get_tree().paused = false
	GameState.save_game()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.is_action("menu"):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ 대화

func _show_talk(text: String) -> void:
	_place_panel(false)
	_name_label.text = Quests.NPC_NAMES.get(_npc, _npc)
	UI.clear(_body)
	var t := UI.label(text, 23, UI.TEXT, true)
	t.visible_ratio = 0.0
	_body.add_child(t)
	var tw := create_tween()
	tw.tween_property(t, "visible_ratio", 1.0, clampf(text.length() * 0.02, 0.2, 1.2))
	var opts := HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 10)
	opts.add_theme_constant_override("v_separation", 10)
	_body.add_child(opts)
	# 보고할 퀘스트
	for id in Quests.QUESTS:
		var q: Dictionary = Quests.QUESTS[id]
		if q.get("turn_in", "") == _npc and GameState.quest_state(id) == "ready":
			var b := UI.button("✓ [완료] " + String(q["title"]), Vector2(0, 56))
			b.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
			b.pressed.connect(_turn_in.bind(id))
			opts.add_child(b)
	# 새 퀘스트
	for id in Quests.QUESTS:
		var q: Dictionary = Quests.QUESTS[id]
		if q.get("giver", "") == _npc and GameState.quest_state(id) == "available" and not q.get("main", false):
			var b := UI.button("! [퀘스트] " + String(q["title"]), Vector2(0, 56))
			b.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
			b.pressed.connect(_offer.bind(id))
			opts.add_child(b)
	# 진행 중인 퀘스트 안내
	for id in Quests.QUESTS:
		var q: Dictionary = Quests.QUESTS[id]
		if q.get("turn_in", "") == _npc and GameState.quest_state(id) == "active":
			var b := UI.button("… " + String(q["title"]) + " (%d/%d)" % [mini(GameState.quest_progress(id), int(q["count"])), int(q["count"])], Vector2(0, 56))
			b.pressed.connect(func() -> void: _show_talk("아직이오? " + String(q["desc"])))
			opts.add_child(b)
	match _npc:
		"merchant":
			var s := UI.button("상점", Vector2(140, 56))
			s.pressed.connect(func() -> void:
				_mode = "shop"
				_sub = 0
				_show_shop())
			opts.add_child(s)
		"smith":
			var c := UI.button("제작", Vector2(140, 56))
			c.pressed.connect(func() -> void:
				_sub = 0
				_show_smith())
			opts.add_child(c)
			var e := UI.button("강화", Vector2(140, 56))
			e.pressed.connect(func() -> void:
				_sub = 1
				_show_smith())
			opts.add_child(e)
	var bye := UI.button("작별", Vector2(140, 56))
	bye.pressed.connect(close)
	opts.add_child(bye)


func _offer(id: String) -> void:
	var q := Quests.get_quest(id)
	_place_panel(false)
	UI.clear(_body)
	_body.add_child(UI.label(String(q.get("offer", q["desc"])), 23, UI.TEXT, true))
	_body.add_child(UI.label("목표: %s" % q["desc"], 19, UI.TEXT_DIM, true))
	_body.add_child(UI.label("보상: " + Quests.rewards_text(id), 19, Color(1, 0.85, 0.4), true))
	var h := UI.hbox(10)
	_body.add_child(h)
	var ok := UI.button("수락한다", Vector2(180, 56))
	ok.pressed.connect(func() -> void:
		GameState.accept_quest(id)
		_show_talk("고맙네! 부탁하지."))
	h.add_child(ok)
	var no := UI.button("나중에", Vector2(140, 56))
	no.pressed.connect(func() -> void: _show_talk("그래, 생각해보게."))
	h.add_child(no)


func _turn_in(id: String) -> void:
	var q := Quests.get_quest(id)
	var text := String(q.get("talk", "정말 고맙소! 약속한 보상이오."))
	GameState.complete_quest(id)
	_show_talk(text + "\n(보상: " + Quests.rewards_text(id) + ")")


# ------------------------------------------------------------------ 목록 공용

func _tabs(names: Array, on_select: Callable) -> HBoxContainer:
	var h := UI.hbox(8)
	for i in names.size():
		var b := UI.button(names[i], Vector2(130, 50))
		b.toggle_mode = true
		b.button_pressed = _sub == i
		b.pressed.connect(func() -> void:
			_sub = i
			on_select.call())
		h.add_child(b)
	h.add_child(UI.spacer())
	h.add_child(UI.label("%d G" % GameState.gold, 24, Color(1, 0.85, 0.35)))
	var back := UI.button("돌아가기", Vector2(130, 50))
	back.pressed.connect(func() -> void: _show_talk("또 필요한 거 있어?"))
	h.add_child(back)
	return h


func _list() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var list := UI.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _row(id: String, title: String, sub: String, sub_color: Color, button_text: String, enabled: bool, on_press: Callable) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.BG2, UI.GOLD_DIM, 8, 1, 8))
	var h := UI.hbox(12)
	p.add_child(h)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.set_item(id, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(title, 22, Items.rarity_color(id)))
	v.add_child(UI.label(sub, 17, sub_color, true))
	var b := UI.button(button_text, Vector2(150, 56))
	b.disabled = not enabled
	b.pressed.connect(on_press)
	h.add_child(b)
	return p


# ------------------------------------------------------------------ 상점

func _show_shop() -> void:
	_place_panel(true)
	_name_label.text = "미라의 잡화점"
	UI.clear(_body)
	_body.add_child(_tabs(["구매", "판매"], _show_shop))
	var list := _list()
	if _sub == 0:
		for id in Items.SHOP:
			var it := Items.get_item(id)
			var price := int(it["price"])
			var sub := "%dG · %s" % [price, Items.describe_stats(it.get("stats", {})) if Items.is_equipment(id) else String(it["desc"])]
			list.add_child(_row(id, String(it["name"]) + "  (보유 %d)" % GameState.count(id), sub,
				UI.TEXT_DIM, "구매", GameState.gold >= price, func() -> void:
					GameState.buy(id)
					_show_shop()))
	else:
		var ids := GameState.inventory.keys()
		if ids.is_empty():
			list.add_child(UI.label("팔 물건이 없다.", 22, UI.TEXT_DIM))
		for id in ids:
			var price := GameState.sell_price(id)
			list.add_child(_row(id, "%s  x%d" % [Items.item_name(id), GameState.count(id)], "1개당 %dG에 판매" % price,
				UI.TEXT_DIM, "판매", true, func() -> void:
					GameState.sell(id)
					_show_shop()))


# ------------------------------------------------------------------ 대장간

func _show_smith() -> void:
	_place_panel(true)
	_name_label.text = "고르의 대장간"
	UI.clear(_body)
	_body.add_child(_tabs(["제작", "강화"], _show_smith))
	var list := _list()
	if _sub == 0:
		for r in Items.RECIPES:
			var id: String = r["item"]
			var parts: PackedStringArray = []
			var mats: Dictionary = r["mats"]
			for m in mats:
				parts.append("%s %d/%d" % [Items.item_name(m), GameState.count(m), int(mats[m])])
			if int(r["gold"]) > 0:
				parts.append("%dG" % int(r["gold"]))
			var ok := GameState.can_craft(r)
			var extra := ""
			if Items.is_equipment(id):
				extra = "  →  " + Items.describe_stats(Items.get_item(id).get("stats", {}))
			list.add_child(_row(id, Items.item_name(id) + extra, "재료: " + ", ".join(parts),
				UI.GOOD if ok else UI.BAD, "제작", ok, func() -> void:
					if GameState.craft(r):
						GameState.message.emit("%s 제작 완료!" % Items.item_name(id))
					_show_smith()))
	else:
		for slot in ["weapon", "armor", "accessory"]:
			var id: String = GameState.equipment[slot]
			if id == "":
				continue
			var lv := GameState.enhance_level(id)
			var title := "%s  +%d" % [Items.item_name(id), lv]
			if lv >= Items.MAX_ENHANCE:
				list.add_child(_row(id, title, "최대 강화 단계", UI.GOOD, "완료", false, func() -> void: pass))
				continue
			var cost := Items.enhance_cost(id, lv)
			var nxt := Items.describe_stats(Items.stats_of(id, lv + 1))
			var sub := "다음 단계: %s\n비용: %dG, 철광석 %d/%d" % [nxt, int(cost["gold"]), GameState.count("iron_ore"), int(cost["iron_ore"])]
			var ok := GameState.can_enhance(id)
			list.add_child(_row(id, title, sub, UI.GOOD if ok else UI.BAD, "강화", ok, func() -> void:
				if GameState.do_enhance(id):
					GameState.message.emit("%s +%d 강화 성공!" % [Items.item_name(id), GameState.enhance_level(id)])
				_show_smith()))
		list.add_child(UI.label("장착 중인 장비만 강화할 수 있다. 철광석은 산기슭 광맥과 고블린에게서 얻는다.", 17, UI.TEXT_DIM, true))
