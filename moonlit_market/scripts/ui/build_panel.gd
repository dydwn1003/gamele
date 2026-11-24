extends "res://scripts/ui/base_panel.gd"
## F. 장식 화면 — 장식 구매/설치/보관, 잠금 조건


func _configure() -> void:
	title_text = "장식"
	sheet_ratio = 0.84


func build() -> void:
	content.add_child(UIKit.label("시장 곳곳의 장식은 방문객·만족도·인내심을 올려 줍니다.", "caption"))
	_build_decos()


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
