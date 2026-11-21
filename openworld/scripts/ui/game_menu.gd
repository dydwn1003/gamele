extends CanvasLayer
## 게임 메뉴: 가방 / 장비 / 퀘스트 / 지도 / 설정. 열려 있는 동안 게임이 멈춘다.

const UI = preload("res://scripts/ui/ui_kit.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
const Items = preload("res://scripts/game/items.gd")
const Quests = preload("res://scripts/game/quests.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const HumanoidModel = preload("res://scripts/models/humanoid_model.gd")

const TABS := ["가방", "장비", "퀘스트", "지도", "설정"]

var main  # main.gd (빠른 이동·설정 적용·타이틀 복귀)
var player

var _root: Control
var _tab_buttons: Array[Button] = []
var _content: Control
var _gold_label: Label
var _tab := 0
var _selected_item := ""
var _bag_filter := "all"
var _selected_quest := ""
var _map_target := -1

static var _map_tex: ImageTexture


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -600
	panel.offset_right = 600
	panel.offset_top = -340
	panel.offset_bottom = 340
	_root.add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(v)
	var head := UI.hbox(8)
	v.add_child(head)
	for i in TABS.size():
		var b := UI.button(TABS[i], Vector2(120, 54), 24)
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(i))
		head.add_child(b)
		_tab_buttons.append(b)
	head.add_child(UI.spacer())
	_gold_label = UI.label("", 24, Color(1, 0.85, 0.35))
	head.add_child(_gold_label)
	var close := UI.button("닫기 ✕", Vector2(110, 54))
	close.pressed.connect(close_menu)
	head.add_child(close)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	visible = false
	GameState.inventory_changed.connect(_refresh_if_open)
	GameState.equipment_changed.connect(_refresh_if_open)
	GameState.quests_changed.connect(_refresh_if_open)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("menu"):
			if visible:
				close_menu()
			elif not get_tree().paused:
				open_menu(0)
			get_viewport().set_input_as_handled()
		elif event.is_action("map") and not get_tree().paused:
			open_menu(3)
			get_viewport().set_input_as_handled()


func open_menu(tab: int) -> void:
	if player and player.dead:
		return
	visible = true
	get_tree().paused = true
	Sfx.play("ui_open")
	_set_tab(tab)


func close_menu() -> void:
	visible = false
	get_tree().paused = false
	GameState.save_game()


func _refresh_if_open() -> void:
	if visible:
		_set_tab(_tab)


func _set_tab(i: int) -> void:
	_tab = i
	for j in _tab_buttons.size():
		_tab_buttons[j].button_pressed = j == i
	_gold_label.text = "%d G" % GameState.gold
	UI.clear(_content)
	var page: Control
	match i:
		0:
			page = _bag_page()
		1:
			page = _equip_page()
		2:
			page = _quest_page()
		3:
			page = _map_page()
		4:
			page = _settings_page()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(page)


# ================================================================== 가방

func _bag_page() -> Control:
	var h := UI.hbox(16)
	var left := UI.vbox(10)
	h.add_child(left)
	var filters := UI.hbox(6)
	left.add_child(filters)
	for f in [["all", "전체"], ["equip", "장비"], ["consumable", "소비"], ["material", "재료"]]:
		var b := UI.button(f[1], Vector2(96, 46), 20)
		b.toggle_mode = true
		b.button_pressed = _bag_filter == f[0]
		b.pressed.connect(func() -> void:
			_bag_filter = f[0]
			_set_tab(0))
		filters.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var ids := []
	for id in GameState.inventory:
		var t: String = Items.get_item(id).get("type", "")
		var ok := _bag_filter == "all" or (_bag_filter == "equip" and Items.is_equipment(id)) or t == _bag_filter
		if ok:
			ids.append(id)
	ids.sort_custom(func(a, b) -> bool:
		var ra := int(Items.get_item(a).get("rarity", 0))
		var rb := int(Items.get_item(b).get("rarity", 0))
		return ra > rb if ra != rb else String(a) < String(b))
	for k in 32:
		var icon := ItemIcon.new()
		if k < ids.size():
			icon.set_item(ids[k], GameState.count(ids[k]))
			icon.selected = ids[k] == _selected_item
			icon.clicked.connect(func(id: String) -> void:
				_selected_item = id
				_set_tab(0))
		grid.add_child(icon)
	if not ids.has(_selected_item):
		_selected_item = ids[0] if ids.size() > 0 else ""
	h.add_child(_item_detail(_selected_item))
	return h


func _item_detail(id: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.BG2, UI.GOLD_DIM, 10, 2, 16))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(10)
	p.add_child(v)
	if id == "":
		v.add_child(UI.label("가방이 비어 있다.", 22, UI.TEXT_DIM))
		return p
	var it := Items.get_item(id)
	var top := UI.hbox(14)
	v.add_child(top)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.set_item(id, 0)
	top.add_child(icon)
	var tv := UI.vbox(4)
	top.add_child(tv)
	var title := it["name"] as String
	if GameState.enhance_level(id) > 0:
		title += "  +%d" % GameState.enhance_level(id)
	tv.add_child(UI.label(title, 28, Items.rarity_color(id)))
	tv.add_child(UI.label("%s · %s" % [Items.RARITY_NAMES[int(it["rarity"])], Items.TYPE_NAMES.get(it["type"], "")], 18, UI.TEXT_DIM))
	tv.add_child(UI.label("보유 %d개 · 판매가 %dG" % [GameState.count(id), GameState.sell_price(id)], 18, UI.TEXT_DIM))
	if Items.is_equipment(id):
		var st := Items.stats_of(id, GameState.enhance_level(id))
		v.add_child(UI.label(Items.describe_stats(st), 22, UI.GOOD, true))
		var slot: String = it["type"]
		var cur: String = GameState.equipment[slot]
		if cur != "":
			v.add_child(UI.label("현재 장착: %s  (%s)" % [Items.item_name(cur), Items.describe_stats(Items.stats_of(cur, GameState.enhance_level(cur)))], 17, UI.TEXT_DIM, true))
	var desc := UI.label(String(it.get("desc", "")), 20, UI.TEXT, true)
	desc.custom_minimum_size = Vector2(380, 0)
	v.add_child(desc)
	v.add_child(UI.spacer())
	var btns := UI.hbox(10)
	v.add_child(btns)
	if it["type"] == "consumable":
		var use := UI.button("사용하기", Vector2(160, 56))
		use.pressed.connect(func() -> void:
			var msg := GameState.use_item(id, player)
			if msg == "":
				Sfx.play("error")
			_set_tab(0))
		btns.add_child(use)
	elif Items.is_equipment(id):
		var eq := UI.button("장착하기", Vector2(160, 56))
		eq.pressed.connect(func() -> void: GameState.equip(id))
		btns.add_child(eq)
	return p


# ================================================================== 장비

func _equip_page() -> Control:
	var h := UI.hbox(16)
	# 3D 미리보기
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(340, 540)
	svc.stretch = true
	h.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = Vector2i(340, 540)
	svc.add_child(sv)
	var stage := Node3D.new()
	sv.add_child(stage)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 4.3)
	cam.fov = 40
	stage.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.5, 0)
	stage.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	stage.add_child(env)
	var model := HumanoidModel.new()
	var weapon := Items.get_item(GameState.equipment["weapon"])
	var armor := Items.get_item(GameState.equipment["armor"])
	model.setup("hero", {"tint": armor.get("tint", Color(0.55, 0.12, 0.12)), "plate": armor.get("plate", false),
		"blade": weapon.get("blade", Color(0.8, 0.8, 0.84)), "blade_len": weapon.get("len", 0.9)})
	model.rotation.y = 0.4
	stage.add_child(model)
	var spin := model.create_tween().set_loops()
	spin.tween_property(model, "rotation:y", model.rotation.y + TAU, 8.0).from(model.rotation.y)

	var mid := UI.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	mid.add_child(UI.label("장착 중인 장비", 24, UI.GOLD))
	for slot in [["weapon", "무기"], ["armor", "방어구"], ["accessory", "장신구"]]:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(UI.BG2, UI.GOLD_DIM, 10, 2, 10))
		var rh := UI.hbox(12)
		row.add_child(rh)
		var id: String = GameState.equipment[slot[0]]
		var icon := ItemIcon.new()
		icon.set_item(id, 0)
		rh.add_child(icon)
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(tv)
		tv.add_child(UI.label(slot[1], 16, UI.TEXT_DIM))
		if id == "":
			tv.add_child(UI.label("비어 있음", 22, UI.TEXT_DIM))
		else:
			var nm := Items.item_name(id) + ("  +%d" % GameState.enhance_level(id) if GameState.enhance_level(id) > 0 else "")
			tv.add_child(UI.label(nm, 22, Items.rarity_color(id)))
			tv.add_child(UI.label(Items.describe_stats(Items.stats_of(id, GameState.enhance_level(id))), 17, UI.GOOD))
			if slot[0] != "weapon":
				var off := UI.button("해제", Vector2(80, 46), 18)
				off.pressed.connect(GameState.unequip.bind(slot[0]))
				rh.add_child(off)
		mid.add_child(row)
	mid.add_child(UI.label("가방 탭에서 다른 장비를 골라 장착할 수 있다.\n대장장이에게 가면 장비를 강화할 수 있다.", 17, UI.TEXT_DIM, true))

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UI.box(UI.BG2, UI.GOLD_DIM, 10, 2, 16))
	right.custom_minimum_size = Vector2(300, 0)
	h.add_child(right)
	var sv2 := UI.vbox(8)
	right.add_child(sv2)
	sv2.add_child(UI.label("카엘의 능력치", 24, UI.GOLD))
	var rows := [
		["레벨", "Lv.%d" % GameState.level],
		["경험치", "%d / %d" % [GameState.xp, GameState.xp_to_next()]],
		["공격력", str(roundi(GameState.attack_power()))],
		["방어력", str(roundi(GameState.defense()))],
		["최대 체력", str(roundi(GameState.max_hp()))],
		["최대 기력", str(roundi(GameState.max_stamina()))],
		["치명타", "%d%%" % roundi(GameState.crit_chance() * 100)],
		["밝힌 봉화", "%d / 7" % GameState.lit_beacons.size()],
		["처치한 적", str(_total_kills())],
	]
	for r in rows:
		var rh := UI.hbox(8)
		rh.add_child(UI.label(r[0], 20, UI.TEXT_DIM))
		rh.add_child(UI.spacer())
		rh.add_child(UI.label(r[1], 20))
		sv2.add_child(rh)
	return h


func _total_kills() -> int:
	var n := 0
	for k in GameState.kills:
		n += int(GameState.kills[k])
	return n


# ================================================================== 퀘스트

func _quest_page() -> Control:
	var h := UI.hbox(16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	var list := UI.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var active := []
	var done := []
	for id in Quests.QUESTS:
		var st := GameState.quest_state(id)
		if st == "active" or st == "ready":
			active.append(id)
		elif st == "done":
			done.append(id)
	if _selected_quest == "" or not (active.has(_selected_quest) or done.has(_selected_quest)):
		_selected_quest = GameState.tracked_quest if active.has(GameState.tracked_quest) else (active[0] if active.size() > 0 else "")
	list.add_child(UI.label("진행 중", 20, UI.GOLD))
	for id in active:
		list.add_child(_quest_button(id))
	if active.is_empty():
		list.add_child(UI.label("마을 사람들에게 말을 걸어보자.", 18, UI.TEXT_DIM))
	if done.size() > 0:
		list.add_child(UI.label("완료", 20, UI.TEXT_DIM))
		for id in done:
			list.add_child(_quest_button(id))

	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.BG2, UI.GOLD_DIM, 10, 2, 18))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(p)
	var v := UI.vbox(12)
	p.add_child(v)
	if _selected_quest == "":
		v.add_child(UI.label("진행 중인 퀘스트가 없다.", 22, UI.TEXT_DIM))
		return h
	var q := Quests.get_quest(_selected_quest)
	var st := GameState.quest_state(_selected_quest)
	v.add_child(UI.label(("[메인] " if q.get("main", false) else "[서브] ") + String(q["title"]), 30, UI.GOLD if q.get("main", false) else UI.TEXT))
	v.add_child(UI.label("의뢰인: %s" % Quests.NPC_NAMES.get(q["giver"], ""), 18, UI.TEXT_DIM))
	v.add_child(UI.label(String(q["desc"]), 21, UI.TEXT, true))
	var prog := mini(GameState.quest_progress(_selected_quest), int(q["count"]))
	var status := "완료" if st == "done" else ("보고 가능 → %s" % Quests.NPC_NAMES.get(q["turn_in"], "") if st == "ready" else "진행 중")
	v.add_child(UI.label("진행도  %d / %d   (%s)" % [prog, int(q["count"]), status], 22, UI.GOOD if st != "active" else UI.TEXT))
	v.add_child(UI.label("보상: " + Quests.rewards_text(_selected_quest), 20, Color(1, 0.85, 0.4), true))
	v.add_child(UI.spacer())
	if st == "active" or st == "ready":
		var track_btn := UI.button("화면에 추적하기" if GameState.tracked_quest != _selected_quest else "추적 중 ✓", Vector2(220, 54))
		track_btn.disabled = GameState.tracked_quest == _selected_quest
		track_btn.pressed.connect(func() -> void:
			GameState.tracked_quest = _selected_quest
			GameState.quests_changed.emit())
		v.add_child(track_btn)
	return h


func _quest_button(id: String) -> Button:
	var q := Quests.get_quest(id)
	var st := GameState.quest_state(id)
	var mark := "★ " if GameState.tracked_quest == id else ""
	var suffix := "  ✓" if st == "ready" else ""
	var b := UI.button(mark + String(q["title"]) + suffix, Vector2(400, 52), 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = id == _selected_quest
	if st == "done":
		b.add_theme_color_override("font_color", UI.TEXT_DIM)
	b.pressed.connect(func() -> void:
		_selected_quest = id
		_set_tab(2))
	return b


# ================================================================== 지도

static func map_texture() -> ImageTexture:
	if _map_tex:
		return _map_tex
	var n := 200
	var extent := Terrain.WORLD_RADIUS * 1.05
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var prev := PackedFloat32Array()
	prev.resize(n)
	for y in n:
		var row := PackedFloat32Array()
		row.resize(n)
		for x in n:
			var wx := (float(x) / n * 2.0 - 1.0) * extent
			var wz := (float(y) / n * 2.0 - 1.0) * extent
			row[x] = Terrain.height(wx, wz)
		for x in n:
			var hgt := row[x]
			var c: Color
			if hgt < Terrain.WATER_LEVEL:
				c = Color(0.16, 0.38, 0.55).lerp(Color(0.08, 0.2, 0.35), clampf(-hgt / 25.0, 0.0, 1.0))
			else:
				var dx := hgt - row[maxi(0, x - 1)]
				var dz := hgt - (prev[x] if y > 0 else hgt)
				var steep := Vector2(dx, dz).length() / (extent * 2.0 / n)
				var wx := (float(x) / n * 2.0 - 1.0) * extent
				var wz := (float(y) / n * 2.0 - 1.0) * extent
				c = Terrain.color_at(hgt, steep, wx, wz, 0.0)
				c = c * (1.0 + clampf((dx + dz) * 0.04, -0.25, 0.25))  # 언덕 음영
			img.set_pixel(x, y, c)
		prev = row
	_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


func _map_page() -> Control:
	var h := UI.hbox(16)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.15), UI.GOLD, 6, 3, 4))
	h.add_child(frame)
	var map := Control.new()
	map.custom_minimum_size = Vector2(540, 540)
	map.clip_contents = true
	frame.add_child(map)
	var tex := TextureRect.new()
	tex.texture = map_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map.add_child(tex)
	var overlay := MapOverlay.new()
	overlay.menu = self
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.add_child(overlay)

	var side := UI.vbox(10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(side)
	side.add_child(UI.label("에버린 섬", 30, UI.GOLD))
	side.add_child(UI.label("●  흰 화살표: 카엘\n●  노란 점: 꺼진 봉화\n●  주황 점: 밝힌 봉화 (눌러서 빠른 이동)\n●  초록 집: 새벽 마을\n●  빨간 점: 발견한 몬스터 거점\n●  ★ : 추적 중인 퀘스트 목표", 19, UI.TEXT, true))
	if _map_target >= 0:
		var b = main.beacons[_map_target]
		side.add_child(UI.label("%s 봉화" % b.display_name(), 24, Color(1, 0.7, 0.3)))
		var go := UI.button("이곳으로 빠른 이동", Vector2(260, 60), 22)
		go.pressed.connect(func() -> void:
			close_menu()
			main.fast_travel(b))
		side.add_child(go)
	else:
		side.add_child(UI.label("밝힌 봉화를 누르면 그곳으로 빠르게 이동할 수 있다.", 18, UI.TEXT_DIM, true))
	return h


func world_to_map(p: Vector3, size: Vector2) -> Vector2:
	var extent := Terrain.WORLD_RADIUS * 1.05
	return Vector2((p.x / extent + 1.0) * 0.5 * size.x, (p.z / extent + 1.0) * 0.5 * size.y)


func select_map_beacon(i: int) -> void:
	_map_target = i
	_set_tab(3)


class MapOverlay extends Control:
	var menu

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var best := -1
			var best_d := 28.0
			for b in menu.main.beacons:
				if not b.lit:
					continue
				var d: float = menu.world_to_map(b.global_position, size).distance_to(event.position)
				if d < best_d:
					best_d = d
					best = b.index
			if best >= 0:
				Sfx.play("ui_click", 0.0)
				menu.select_map_beacon(best)

	func _draw() -> void:
		var font := get_theme_default_font()
		# 마을
		var v: Vector2 = menu.world_to_map(Vector3.ZERO, size)
		draw_rect(Rect2(v - Vector2(9, 6), Vector2(18, 12)), Color(0.3, 0.75, 0.35))
		draw_colored_polygon(PackedVector2Array([v + Vector2(-12, -6), v + Vector2(12, -6), v + Vector2(0, -16)]), Color(0.3, 0.75, 0.35))
		draw_string_outline(font, v + Vector2(-40, 30), "새벽 마을", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, 4, Color.BLACK)
		draw_string(font, v + Vector2(-40, 30), "새벽 마을", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color.WHITE)
		# 발견한 거점
		for c in menu.get_tree().get_nodes_in_group("camps"):
			if GameState.discovered.has(c.camp_id):
				var p: Vector2 = menu.world_to_map(c.global_position, size)
				draw_circle(p, 6, Color(0.9, 0.25, 0.2))
				draw_arc(p, 6, 0, TAU, 12, Color.BLACK, 1.5)
		# 봉화
		for b in menu.main.beacons:
			var p: Vector2 = menu.world_to_map(b.global_position, size)
			var col := Color(1, 0.55, 0.15) if b.lit else Color(1, 0.92, 0.3)
			draw_circle(p, 10 if b.lit else 8, col)
			draw_arc(p, 10, 0, TAU, 16, Color.BLACK, 2)
			if b.index == menu._map_target:
				draw_arc(p, 16, 0, TAU, 20, Color.WHITE, 3)
			draw_string_outline(font, p + Vector2(-60, 28), b.display_name(), HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 4, Color.BLACK)
			draw_string(font, p + Vector2(-60, 28), b.display_name(), HORIZONTAL_ALIGNMENT_CENTER, 120, 15, col)
		# 퀘스트 목표
		var tgt = menu.main.quest_target()
		if tgt != null:
			var tp: Vector2 = menu.world_to_map(tgt, size)
			draw_string_outline(font, tp + Vector2(-12, -14), "★", HORIZONTAL_ALIGNMENT_CENTER, 24, 26, 5, Color.BLACK)
			draw_string(font, tp + Vector2(-12, -14), "★", HORIZONTAL_ALIGNMENT_CENTER, 24, 26, Color(1, 0.9, 0.3))
		# 플레이어
		var pl = menu.player
		var pp: Vector2 = menu.world_to_map(pl.global_position, size)
		var yaw: float = pl.model.rotation.y
		var f := Vector2(-sin(yaw), -cos(yaw))
		var s := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([pp + f * 13, pp - f * 8 + s * 8, pp - f * 8 - s * 8]), Color.WHITE)
		draw_polyline(PackedVector2Array([pp + f * 13, pp - f * 8 + s * 8, pp - f * 8 - s * 8, pp + f * 13]), Color.BLACK, 2)


# ================================================================== 설정

func _settings_page() -> Control:
	var v := UI.vbox(14)
	var st: Dictionary = GameState.settings
	v.add_child(_slider_row("카메라 감도", float(st["sensitivity"]), 0.3, 2.0, func(x: float) -> void: st["sensitivity"] = x))
	v.add_child(_slider_row("배경음악", float(st["music"]), 0.0, 1.0, func(x: float) -> void:
		st["music"] = x
		Sfx.update_volume()))
	v.add_child(_slider_row("효과음", float(st["sfx"]), 0.0, 1.0, func(x: float) -> void: st["sfx"] = x))
	var view := UI.hbox(10)
	view.add_child(_fixed_label("시야 거리"))
	for i in 3:
		var b := UI.button(["가까이 (빠름)", "보통", "멀리 (고사양)"][i], Vector2(190, 52), 20)
		b.toggle_mode = true
		b.button_pressed = int(st["view"]) == i
		b.pressed.connect(func() -> void:
			st["view"] = i
			_apply_settings()
			_set_tab(4))
		view.add_child(b)
	v.add_child(view)
	v.add_child(_toggle_row("그림자", bool(st["shadows"]), func(on: bool) -> void: st["shadows"] = on))
	v.add_child(_toggle_row("FPS 표시", bool(st["show_fps"]), func(on: bool) -> void: st["show_fps"] = on))
	v.add_child(UI.spacer())
	var bottom := UI.hbox(12)
	var save := UI.button("지금 저장하기", Vector2(220, 58))
	save.pressed.connect(func() -> void:
		main.save_now()
		GameState.message.emit("저장했다"))
	bottom.add_child(save)
	var title := UI.button("타이틀 화면으로", Vector2(220, 58))
	title.pressed.connect(func() -> void:
		main.save_now()
		get_tree().paused = false
		get_tree().reload_current_scene())
	bottom.add_child(title)
	v.add_child(bottom)
	v.add_child(UI.label("조작: 왼쪽 화면 드래그 = 이동,  오른쪽 화면 드래그 = 카메라,  공격 연타 = 3단 콤보,  공중에서 점프 = 망토 활공", 17, UI.TEXT_DIM, true))
	return v


func _fixed_label(t: String) -> Label:
	var l := UI.label(t, 22)
	l.custom_minimum_size = Vector2(170, 0)
	return l


func _slider_row(title: String, value: float, lo: float, hi: float, on_change: Callable) -> Control:
	var h := UI.hbox(10)
	h.add_child(_fixed_label(title))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(420, 44)
	var val := UI.label("%d%%" % roundi(value * 100), 20, UI.TEXT_DIM)
	s.value_changed.connect(func(x: float) -> void:
		on_change.call(x)
		val.text = "%d%%" % roundi(x * 100)
		_apply_settings())
	h.add_child(s)
	h.add_child(val)
	return h


func _toggle_row(title: String, on: bool, on_change: Callable) -> Control:
	var h := UI.hbox(10)
	h.add_child(_fixed_label(title))
	var b := UI.button("켜짐" if on else "꺼짐", Vector2(140, 50), 20)
	b.toggle_mode = true
	b.button_pressed = on
	b.toggled.connect(func(x: bool) -> void:
		on_change.call(x)
		b.text = "켜짐" if x else "꺼짐"
		_apply_settings())
	h.add_child(b)
	return h


func _apply_settings() -> void:
	GameState.save_settings()
	if main:
		main.apply_settings()
