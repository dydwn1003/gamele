extends "res://scripts/ui/base_panel.gd"
## 시장 관리 — 시장 단계/평판 진행, 다음 해금, 6개 자리 현황, 누적 기록

func _configure() -> void:
	title_text = "시장 관리"
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
	info_row(v, "노점 최고 레벨", "Lv.%d" % GameManager.progression.max_stall_level())
	info_row(v, "방문객 배수", "x%.2f" % float(st.get("visitor_mult", 1.0)))
	if not nxt.is_empty():
		var need := int(nxt.get("required_reputation", 0))
		v.add_child(UIKit.label("다음 단계: %s (평판 %d)" % [nxt.get("name", ""), need], "body"))
		v.add_child(UIKit.progress_bar(GameManager.state.reputation, need, UIKit.REP, 14))
		v.add_child(UIKit.label(str(nxt.get("desc", "")), "caption"))
	content.add_child(c)
	section("노점 자리")
	for i in GameManager.state.slots.size():
		var s: Dictionary = GameManager.state.get_slot(i)
		var txt := "%d. 빈 자리 — 설치하기" % (i + 1)
		var variant := "ghost"
		if s.get("kind", "") == "stall":
			var menu: Dictionary = GameManager.economy.menu_for_slot(i)
			txt = "%d. %s Lv.%d · %s · 재고 %d/%d" % [i + 1, DataManager.get_stall(str(s["type"])).get("name", ""), int(s["level"]), menu.get("name", ""), int(s["stock"]), GameManager.economy.stock_max(i)]
			variant = "secondary"
		elif s.get("kind", "") == "facility":
			txt = "%d. %s" % [i + 1, DataManager.get_facility(str(s["type"])).get("name", "")]
			variant = "secondary"
		var b := UIKit.button(txt, variant, 72)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): ui.open("stall", {"slot": i}))
		content.add_child(b)
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
		info_row(rv, "최근 영업 순수익", UIKit.fmt(int(ls.get("net_profit", 0))))
		info_row(rv, "오프라인 기준 (분당)", UIKit.fmt(int(ls.get("per_minute", 0.0))))
	info_row(rv, "오프라인 수령", "%d회 · 총 %s" % [int(GameManager.state.offline.get("claim_count", 0)), UIKit.fmt(int(GameManager.state.offline.get("total_claimed", 0)))])
	content.add_child(rc)
