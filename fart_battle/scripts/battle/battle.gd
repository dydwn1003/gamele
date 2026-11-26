extends Control
## Battle — 대결 화면. 로직(BattleLogic) + 컴퓨터(AIController) + 대결장(Arena) + 조작부(Pad) 연결.
## 흐름: intro(상대 소개) → countdown(3·2·1·뿡!) → fight → round_end → (다음 라운드 | result)
## 입력: 멀티터치(두 사람이 동시에 누를 수 있게 InputEventScreenTouch 로 직접 판정)

const LogicScript := preload("res://scripts/core/battle_logic.gd")
const AIScript := preload("res://scripts/ai/ai_controller.gd")
const ArenaScript := preload("res://scripts/battle/arena.gd")
const PadScript := preload("res://scripts/battle/pad.gd")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal exit_requested
signal next_requested(opp_index: int)

var mode: String = "league" ## league / versus
var opp_index: int = 0
var logic
var ai
var arena
var pads: Array = []
var defs: Array = []
var state: String = "intro"
var state_t: float = 0.0
var countdown: int = 3
var touches: Dictionary = {} ## touch index -> [side, region]
var top_card: PanelContainer
var top_label: Label
var top_sub: Label
var overlay: Control
var big_label: Label
var pause_button: Button
var match_saved: bool = false
var auto_play: bool = false ## 화면 확인/테스트용: 플레이어도 컴퓨터가 조작
var ai_player


func setup(p_mode: String, p_opp: int) -> void:
	mode = p_mode
	opp_index = p_opp


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.build_theme()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var opp: Dictionary = Data.opponent(opp_index)
	var p1: Dictionary = Data.player.duplicate(true)
	var p2: Dictionary = opp.duplicate(true)
	if mode == "versus":
		# 둘이서: 공정하게 같은 능력치, 겉모습만 다르게
		for k in ["power", "control", "gas_regen", "stink"]:
			p2[k] = p1[k]
		p2["name"] = "2P " + str(opp.get("name", ""))
		p1["name"] = "1P " + str(p1.get("name", ""))
	defs = [p1, p2]
	logic = LogicScript.new()
	logic.setup(p1, p2, Data.balance, Data.foods)
	if mode == "league":
		ai = AIScript.new()
		ai.setup(logic, 1)
	arena = ArenaScript.new()
	add_child(arena)
	arena.setup(logic, p1, p2)
	# 조작부
	var bottom = PadScript.new()
	bottom.logic = logic
	bottom.side = 0
	bottom.label = str(p1["name"])
	bottom.accent = Data.color(p1.get("beam", ["#FF5FD2"])[0])
	add_child(bottom)
	pads.append(bottom)
	if mode == "versus":
		var top = PadScript.new()
		top.logic = logic
		top.side = 1
		top.flipped = true
		top.label = str(p2["name"])
		top.accent = Data.color(p2.get("beam", ["#5FE8FF"])[0])
		add_child(top)
		pads.append(top)
	else:
		top_card = UIKit.card(Color(UIKit.PANEL_DARK, 0.92), 14)
		var v := UIKit.vbox(2)
		top_card.add_child(v)
		top_label = UIKit.label("", "section", Data.color(p2.get("beam", ["#FFD25F"])[0]))
		v.add_child(top_label)
		top_sub = UIKit.label("", "caption")
		top_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(top_sub)
		add_child(top_card)
	# 중앙 큰 글씨 (카운트다운/라운드 결과)
	big_label = UIKit.label("", "title", UIKit.ACCENT)
	big_label.add_theme_font_size_override("font_size", 72)
	big_label.add_theme_constant_override("outline_size", 18)
	big_label.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.2, 0.9))
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big_label)
	pause_button = UIKit.button("멈춤", "secondary", 64)
	pause_button.custom_minimum_size = Vector2(88, 64)
	pause_button.pressed.connect(_pause)
	add_child(pause_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_enter_intro()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var pad_h := 300.0
	var top_h := 300.0 if mode == "versus" else 150.0
	pads[0].position = Vector2((vp.x - 720.0) / 2.0, vp.y - pad_h)
	pads[0].size = Vector2(720, pad_h)
	if mode == "versus":
		pads[1].position = Vector2((vp.x - 720.0) / 2.0, 0)
		pads[1].size = Vector2(720, pad_h)
	else:
		top_card.position = Vector2(16, 16)
		top_card.size = Vector2(vp.x - 112, 0)
	var area := Rect2(Vector2(0, top_h), Vector2(vp.x, vp.y - top_h - pad_h))
	var s := minf(area.size.x / ArenaScript.SIZE.x, area.size.y / ArenaScript.SIZE.y)
	arena.scale = Vector2(s, s)
	# 풀밭이 조작부에 닿도록 아래쪽에 붙이고, 남는 공간은 위쪽 숲으로
	arena.base_position = Vector2((area.size.x - ArenaScript.SIZE.x * s) / 2.0, area.end.y - ArenaScript.SIZE.y * s + 20.0 * s)
	arena.position = arena.base_position
	big_label.position = Vector2(0, area.position.y + area.size.y * 0.25)
	big_label.size = Vector2(vp.x, 100)
	pause_button.position = Vector2(vp.x - 100, (top_h - 64) / 2.0 if mode == "league" else vp.y / 2.0 - 32)


# ───────── 흐름 ─────────

func _enter_intro() -> void:
	state = "intro"
	state_t = 1.8 if mode == "league" else 0.6
	var opp: Dictionary = defs[1]
	if mode == "league":
		top_label.text = "%s  ·  %s" % [opp.get("name", ""), opp.get("title", "")]
		top_sub.text = "「%s」" % opp.get("lines", {}).get("intro", "")
		if not Save.tutorial_done:
			_show_tutorial()


func _start_countdown() -> void:
	logic.start_round()
	_drain_events()
	arena.reset_moods()
	state = "countdown"
	countdown = 3
	state_t = 0.7
	big_label.text = "%d라운드" % logic.round_no
	_update_top()


func _process(delta: float) -> void:
	match state:
		"intro":
			state_t -= delta
			if state_t <= 0.0:
				_start_countdown()
		"countdown":
			state_t -= delta
			if state_t <= 0.0:
				if countdown > 0:
					big_label.text = str(countdown)
					Sfx.play("click")
					countdown -= 1
					state_t = 0.6
				else:
					big_label.text = "뿡!"
					Sfx.play_fart("medium")
					state = "fight"
					state_t = 0.6
		"fight":
			if state_t > 0.0:
				state_t -= delta
				if state_t <= 0.0:
					big_label.text = ""
			if auto_play and ai_player:
				ai_player.tick(delta)
			if ai:
				ai.tick(delta)
			logic.tick(delta)
			_drain_events()
			_update_top()
		"round_end":
			state_t -= delta
			if state_t <= 0.0:
				if logic.match_over:
					_show_result()
				else:
					big_label.text = ""
					_start_countdown()
	for p in pads:
		p.fart_down = bool(logic.fighters[p.side]["holding"])


func _update_top() -> void:
	if mode != "league" or logic == null:
		return
	var w0 := int(logic.fighters[0]["wins"])
	var w1 := int(logic.fighters[1]["wins"])
	var opp: Dictionary = defs[1]
	top_label.text = "%s  ·  %s" % [opp.get("name", ""), opp.get("title", "")]
	if state == "fight" or state == "countdown":
		top_sub.text = "%d라운드  ·  남은 시간 %d초  ·  나 %d : %d 상대  ·  상대 가스 %d" % [logic.round_no, int(ceil(maxf(0.0, logic.time_left))), w0, w1, int(logic.fighters[1]["gas"])]


func _drain_events() -> void:
	for ev in logic.take_events():
		arena.handle_event(ev)
		match str(ev.get("type", "")):
			"fart":
				Sfx.play_fart(str(ev["size"]))
				if int(ev["side"]) == 0 or mode == "versus":
					_vibrate(20 if str(ev["size"]) in ["tiny", "medium"] else 50)
				if str(ev.get("result", "")) == "parry":
					Sfx.play("parry")
				elif str(ev.get("result", "")) == "blocked":
					Sfx.play("block")
			"blunder":
				Sfx.play("squeak")
				_vibrate(80)
			"eat":
				Sfx.play("eat" if ev.get("good", true) else "bad")
			"block_start":
				Sfx.play("block", 1.3)
			"round_end":
				_on_round_end(ev)


func _on_round_end(ev: Dictionary) -> void:
	state = "round_end"
	state_t = 2.0
	touches.clear()
	var w := int(ev["winner"])
	if w < 0:
		big_label.text = "무승부!"
	else:
		var nm: String = str(defs[w].get("name", ""))
		big_label.text = ("%s 승리!" % nm) if mode == "versus" else ("라운드 승리!" if w == 0 else "라운드 패배…")
		Sfx.play("win" if w == 0 or mode == "versus" else "lose")


func _vibrate(ms: int) -> void:
	if Save.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ───────── 입력 ─────────

func _input(event: InputEvent) -> void:
	if state != "fight" or overlay != null:
		return
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed:
			_touch_down(st.index, st.position)
		else:
			_touch_up(st.index)
		return
	# 키보드 (PC 확인용): 스페이스 = 뿡, B = 코 막기
	var key := event as InputEventKey
	if key != null and not key.echo:
		if key.keycode == KEY_SPACE:
			if key.pressed:
				logic.press(0)
			else:
				logic.release(0)
		elif key.keycode == KEY_B and key.pressed:
			logic.block(0)


func _touch_down(index: int, pos: Vector2) -> void:
	for p in pads:
		var region: String = p.region_at(pos)
		if region == "fart":
			if logic.press(p.side):
				touches[index] = [p.side, "fart"]
			return
		if region == "block":
			logic.block(p.side)
			return
	# 음식 탭: 1인용은 플레이어, 둘이서는 화면 위/아래 절반으로 구분
	var local: Vector2 = arena.get_global_transform().affine_inverse() * pos
	var uid: int = arena.food_at(local)
	if uid >= 0:
		var side := 0
		if mode == "versus" and pos.y < get_viewport_rect().size.y / 2.0:
			side = 1
		logic.eat(side, uid)


func _touch_up(index: int) -> void:
	if not touches.has(index):
		return
	var t: Array = touches[index]
	touches.erase(index)
	if t[1] == "fart":
		logic.release(int(t[0]))


# ───────── 오버레이 ─────────

func _make_overlay(title: String) -> VBoxContainer:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := UIKit.card(UIKit.PANEL, 28)
	overlay.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(620, 0)
	card.position = Vector2((get_viewport_rect().size.x - 620) / 2.0, get_viewport_rect().size.y * 0.16)
	var v := UIKit.vbox(16)
	card.add_child(v)
	var t := UIKit.label(title, "title", UIKit.ACCENT)
	t.add_theme_font_size_override("font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _show_tutorial() -> void:
	var v := _make_overlay("방귀 대결 방법")
	var lines := [
		"① 「꾹~ 뿡!」 버튼을 누르고 있으면 압력이 차요.",
		"② 게이지가 초록색일 때 떼면 「완벽한 뿡!」 무지개 빔!",
		"③ 너무 오래 참으면 삐끗! 기절하고 빔이 나한테 와요.",
		"④ 상대가 크게 모으면 「코 막기」. 뀌기 직전에 막으면 튕겨내기!",
		"⑤ 가운데 나오는 음식을 탭해서 먹으면 특수 효과!",
		"⑥ 빔이 부딪히는 지점을 상대 엉덩이까지 밀면 승리!",
	]
	for l in lines:
		v.add_child(UIKit.label(l, "body"))
	var b := UIKit.button("알겠어! 뿡!", "primary", 92)
	b.pressed.connect(func():
		Save.tutorial_done = true
		Save.save_game()
		_close_overlay()
	)
	v.add_child(b)
	state_t = 99.0
	b.pressed.connect(func(): state_t = 0.8)


func _pause() -> void:
	if overlay != null or state == "intro":
		return
	var prev := state
	state = "paused"
	_release_all()
	var v := _make_overlay("잠깐 멈춤")
	var r := UIKit.button("계속하기", "primary", 88)
	r.pressed.connect(func():
		_close_overlay()
		state = prev
	)
	v.add_child(r)
	var q := UIKit.button("그만하고 나가기", "secondary", 80)
	q.pressed.connect(func(): exit_requested.emit())
	v.add_child(q)


func _release_all() -> void:
	for idx in touches.keys():
		_touch_up(idx)
	touches.clear()


func _show_result() -> void:
	state = "result"
	big_label.text = ""
	var w: int = logic.match_winner
	var won := w == 0
	var st: Dictionary = logic.fighters[0]["stats"]
	var title := ("%s 승리!" % defs[w].get("name", "")) if mode == "versus" else ("승리!" if won else "패배…")
	var v := _make_overlay(title)
	var line := ""
	if mode == "league":
		line = str(defs[0].get("lines", {}).get("win" if won else "lose", ""))
		var opp_line := str(defs[1].get("lines", {}).get("lose" if won else "win", ""))
		v.add_child(UIKit.label("「%s」" % line, "section", UIKit.TEXT))
		v.add_child(UIKit.label("%s: 「%s」" % [defs[1].get("name", ""), opp_line], "body", UIKit.TEXT_SUB))
	var stats := "방귀 %d번 · 완벽 %d번 · 삐끗 %d번 · 튕겨내기 %d번 · 음식 %d개" % [int(st["farts"]), int(st["perfect"]), int(st["blunders"]), int(st["parries"]), int(st["foods"])]
	v.add_child(UIKit.label(stats, "caption", UIKit.TEXT))
	if mode == "league" and not match_saved:
		match_saved = true
		var newly := Save.record_match(opp_index, str(defs[1].get("id", "")), won, st)
		if newly and opp_index + 1 < Data.opponents.size():
			v.add_child(UIKit.label("새 상대 등장: %s!" % Data.opponent(opp_index + 1).get("name", ""), "section", UIKit.SUCCESS))
		elif won and opp_index + 1 >= Data.opponents.size():
			v.add_child(UIKit.label("뿌앙 리그 챔피언 달성!", "section", UIKit.SUCCESS))
	if mode == "league" and won and opp_index + 1 < Data.opponents.size():
		var n := UIKit.button("다음 상대와 대결", "primary", 92)
		n.pressed.connect(func(): next_requested.emit(opp_index + 1))
		v.add_child(n)
	var again := UIKit.button("한 판 더", "primary" if not (mode == "league" and won) else "secondary", 84)
	again.pressed.connect(func(): next_requested.emit(opp_index))
	v.add_child(again)
	var menu := UIKit.button("메뉴로", "secondary", 76)
	menu.pressed.connect(func(): exit_requested.emit())
	v.add_child(menu)
	Sfx.play("win" if won or mode == "versus" else "lose")


## 화면 확인/테스트용: 1P 도 컴퓨터가 조작
func enable_auto_play() -> void:
	auto_play = true
	ai_player = AIScript.new()
	ai_player.setup(logic, 0)
	ai_player.def = {"ai_reaction": 0.35, "ai_accuracy": 0.08, "ai_aggression": 0.7, "ai_block": 0.5, "ai_greed": 0.7}
	Save.tutorial_done = true
