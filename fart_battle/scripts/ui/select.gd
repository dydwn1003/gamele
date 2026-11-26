extends Control
## 리그 상대 고르기 — 이긴 상대 다음 사람이 열린다.

const CritterScript := preload("res://scripts/battle/critter.gd")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

signal picked(opp_index: int)
signal back


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.build_theme()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := UIKit.vbox(14)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 30
	col.offset_bottom = -24
	var head := UIKit.hbox(12)
	col.add_child(head)
	var b := UIKit.button("뒤로", "secondary", 68)
	b.custom_minimum_size = Vector2(120, 68)
	b.pressed.connect(func(): back.emit())
	head.add_child(b)
	var t := UIKit.label("뿌앙 리그 · 상대 고르기", "title", UIKit.ACCENT)
	t.add_theme_font_size_override("font_size", 34)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list := UIKit.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in Data.opponents.size():
		list.add_child(_card(i))


func _card(i: int) -> Control:
	var o: Dictionary = Data.opponents[i]
	var open := i < Save.unlocked
	var wins := int(Save.wins.get(str(o["id"]), 0))
	var card := UIKit.card(UIKit.PANEL_LIGHT if open else UIKit.PANEL_DARK, 16)
	card.custom_minimum_size = Vector2(0, 170)
	var row := UIKit.hbox(14)
	card.add_child(row)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(190, 138)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var c = CritterScript.new()
	c.setup_from(o)
	c.scale = Vector2(-0.8, 0.8)
	c.position = Vector2(100, 128)
	if not open:
		c.modulate = Color(0, 0, 0, 0.75)
	pic.add_child(c)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UIKit.label("%d. %s" % [i + 1, o["name"] if open else "???"], "section", Data.color(o.get("beam", ["#FFD25F"])[0]) if open else UIKit.TEXT_SUB))
	v.add_child(UIKit.label(str(o.get("title", "")) if open else "앞 상대를 이기면 열려요", "caption"))
	if open:
		v.add_child(UIKit.label("「%s」" % o.get("lines", {}).get("intro", ""), "caption", UIKit.TEXT))
	var bt := UIKit.button(("도전! (승리 %d)" % wins) if wins > 0 else "도전!", "primary" if open else "secondary", 64)
	UIKit.set_enabled(bt, open)
	bt.pressed.connect(func(): picked.emit(i))
	v.add_child(bt)
	return card
