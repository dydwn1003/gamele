extends "res://scripts/ui/base_panel.gd"
## 시장 — 시장 단계/평판, 경쟁 노점 정보와 지난 영업 순위, 누적 기록

func _configure() -> void:
	title_text = "시장 · 경쟁 노점"
	sheet_ratio = 0.86


func build() -> void:
	var st: Dictionary = GameManager.progression.current_stage()
	var nxt: Dictionary = GameManager.progression.next_stage()
	var c := UIKit.card(UIKit.PANEL_DARK)
	var v := UIKit.vbox(6)
	c.add_child(v)
	v.add_child(UIKit.label("%d단계 · %s" % [GameManager.state.market_level, st.get("name", "")], "section", UIKit.ACCENT))
	v.add_child(UIKit.label(str(st.get("desc", "")), "caption"))
	info_row(v, "시장 평판", UIKit.fmt(GameManager.state.reputation), UIKit.REP)
	info_row(v, "포차 최고 레벨", "Lv.%d" % GameManager.progression.max_stall_level())
	if not nxt.is_empty():
		var need := int(nxt.get("required_reputation", 0))
		v.add_child(UIKit.label("다음 단계: %s (평판 %d)" % [nxt.get("name", ""), need], "body"))
		v.add_child(UIKit.progress_bar(GameManager.state.reputation, need, UIKit.REP, 14))
		v.add_child(UIKit.label(str(nxt.get("desc", "")), "caption"))
	content.add_child(c)
	section("경쟁 노점")
	content.add_child(UIKit.label("주변 노점은 손님을 두고 경쟁합니다. 직접 조작할 수는 없지만, 맛·가격·대기 시간으로 이길 수 있어요.", "caption"))
	var active: Array = GameManager.progression.active_rivals()
	for id in DataManager.rivals.keys():
		_rival_card(id, active.has(id))
	section("기록")
	var rc := UIKit.card()
	var rv := UIKit.vbox(6)
	rc.add_child(rv)
	var lt: Dictionary = GameManager.state.lifetime
	info_row(rv, "영업 횟수", "%d회" % int(lt.get("sessions", 0)))
	info_row(rv, "누적 손님", "%d명" % int(lt.get("customers", 0)))
	info_row(rv, "누적 판매", "%d개" % int(lt.get("sales", 0)))
	info_row(rv, "누적 매출", UIKit.fmt(int(lt.get("revenue", 0))))
	var ls: Dictionary = GameManager.state.last_session
	if not ls.is_empty():
		info_row(rv, "오프라인 기준 (분당 순수익)", UIKit.fmt(int(ls.get("per_minute", 0.0))))
	info_row(rv, "오프라인 수령", "%d회 · 총 %s" % [int(GameManager.state.offline.get("claim_count", 0)), UIKit.fmt(int(GameManager.state.offline.get("total_claimed", 0)))])
	content.add_child(rc)


func _rival_card(id: String, active: bool) -> void:
	var d: Dictionary = DataManager.get_rival(id)
	var card := UIKit.card(UIKit.PANEL_LIGHT if active else UIKit.PANEL_DARK)
	var col := UIKit.vbox(4)
	card.add_child(col)
	var row := UIKit.hbox(8)
	col.add_child(row)
	var t := UIKit.label(str(d.get("name", "")), "section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(t)
	var s := UIKit.label("영업 중" if active else "%d단계에 등장" % int(d.get("appear_level", 1)), "body", UIKit.SECONDARY if active else UIKit.TEXT_SUB)
	s.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(s)
	col.add_child(UIKit.label(str(d.get("desc", "")), "caption", UIKit.TEXT))
	var menus: Array = []
	for m in d.get("menus", []):
		menus.append("%s %d" % [DataManager.get_menu(m).get("name", m), int(round(float(DataManager.get_menu(m).get("price", 0)) * float(d.get("price_ratio", 1.0))))])
	col.add_child(UIKit.label("메뉴: " + ", ".join(menus), "caption"))
	var rec: Dictionary = GameManager.state.rivals.get(id, {})
	col.add_child(UIKit.label("맛 %d · 평판 %d · 지난 영업 판매 %d개" % [int(d.get("quality", 70)), int(rec.get("rep", d.get("reputation", 20))), int(rec.get("last_sales", 0))], "caption"))
	content.add_child(card)
