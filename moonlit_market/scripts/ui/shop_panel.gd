extends "res://scripts/ui/base_panel.gd"
## 상점 — 향후 BM 상품/보상 광고 자리. 실제 결제·광고 SDK가 없으므로 구매는 비활성화된다.
## (가짜 결제 성공 금지: PurchaseService.is_available() == false)

func _configure() -> void:
	title_text = "상점"
	sheet_ratio = 0.84


func build() -> void:
	var gc := UIKit.card(UIKit.PANEL_DARK)
	var gr := UIKit.hbox(10)
	gc.add_child(gr)
	gr.add_child(UIKit.icon("gem", 40))
	var gl := UIKit.label("달빛 보석 %d" % GameManager.state.gems, "section")
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gr.add_child(gl)
	gr.add_child(UIKit.label("프리미엄 재화 (준비 중)", "caption"))
	content.add_child(gc)
	content.add_child(UIKit.label("과금 없이도 모든 성장이 가능합니다. 유료 상품은 꾸미기와 편의성 위주로 준비 중입니다.", "caption"))
	section("상품")
	var available: bool = GameManager.purchases.is_available()
	for p in GameManager.purchases.products:
		var card := UIKit.card()
		var col := UIKit.vbox(6)
		card.add_child(col)
		var row := UIKit.hbox(10)
		col.add_child(row)
		var t := UIKit.label(str(p.get("name", "")), "section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(UIKit.label("₩%s" % UIKit.fmt(int(p.get("price_krw", 0))), "number", UIKit.ACCENT))
		col.add_child(UIKit.label(str(p.get("desc", "")), "caption"))
		var b := UIKit.button("구매" if available else "준비 중", "primary", 68)
		UIKit.set_enabled(b, available)
		var pid := str(p.get("id", ""))
		b.pressed.connect(func(): GameManager.purchases.purchase(pid))
		col.add_child(b)
		content.add_child(card)
	content.add_child(UIKit.label("가격은 시장 테스트용 가설값입니다. " + GameManager.purchases.status_text(), "caption"))
	section("선택형 보상 광고")
	for a in DataManager.bm.get("ad_placements", []):
		var row2 := UIKit.hbox(10)
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(str(a.get("name", "")), "body"))
		v.add_child(UIKit.label(str(a.get("desc", "")), "caption"))
		row2.add_child(v)
		row2.add_child(UIKit.label("준비 중" if not GameManager.ads.has_sdk() else "사용 가능", "caption"))
		content.add_child(row2)
	content.add_child(UIKit.label("광고 상태: " + GameManager.ads.status_text() + " · 강제 광고는 넣지 않습니다.", "caption"))
