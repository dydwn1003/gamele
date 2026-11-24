extends "res://scripts/ui/base_panel.gd"
## E. 시장 정산 화면 — 결과 표시 후 "정산 받기"는 세션당 한 번만 지급된다.
## (EconomyManager.claim_result 가 session_id 로 중복 지급을 막고, 버튼도 즉시 잠긴다)

var claimed: Dictionary = {}


func _configure() -> void:
	title_text = "영업 결과"
	sheet_ratio = 0.9
	auto_refresh = false
	dismiss_on_dim = false


func build() -> void:
	var r: Dictionary = args.get("result", {})
	if r.is_empty():
		r = GameManager.state.pending_result
	var w: Dictionary = DataManager.get_weather(str(r.get("weather", "cloudy")))
	content.add_child(UIKit.label("%d일차 영업 종료 · 날씨 %s" % [int(r.get("day", 0)), w.get("name", "")], "caption"))
	# 손님
	section("손님")
	var c1 := UIKit.card()
	var v1 := UIKit.vbox(6)
	c1.add_child(v1)
	info_row(v1, "시장 방문객", "%d명" % int(r.get("visitors", 0)))
	info_row(v1, "내 포차 손님", "%d명" % int(r.get("buyers", 0)), UIKit.SUCCESS)
	info_row(v1, "경쟁 노점 손님", "%d명" % int(r.get("rival_buyers", 0)), UIKit.TEXT_SUB)
	info_row(v1, "이탈 손님", "%d명" % int(r.get("walkouts", 0)), UIKit.DANGER)
	info_row(v1, "평균 만족도", "%d / 100" % int(round(float(r.get("avg_satisfaction", 0)))))
	content.add_child(c1)
	# 요리
	section("요리")
	var c0 := UIKit.card()
	var v0 := UIKit.vbox(6)
	c0.add_child(v0)
	info_row(v0, "판매", "%d개" % int(r.get("sales", 0)))
	info_row(v0, "평균 품질", "%d / 100" % int(round(float(r.get("avg_quality", 0)))), UIKit.ACCENT)
	info_row(v0, "완벽한 요리", "%d개" % int(r.get("perfect", 0)), UIKit.SUCCESS)
	info_row(v0, "태운 요리", "%d개" % int(r.get("burnt", 0)), UIKit.DANGER)
	info_row(v0, "인기 메뉴", "%s (%d개)" % [r.get("best_menu", "-"), int(r.get("best_menu_sales", 0))], UIKit.ACCENT)
	content.add_child(c0)
	# 매출
	section("매출")
	var c2 := UIKit.card()
	var v2 := UIKit.vbox(6)
	c2.add_child(v2)
	info_row(v2, "총매출", "+%s" % UIKit.fmt(int(r.get("revenue", 0))), UIKit.ACCENT)
	info_row(v2, "팁", "+%s" % UIKit.fmt(int(r.get("tips", 0))), UIKit.SUCCESS)
	info_row(v2, "재료 원가 (판매분)", "-%s" % UIKit.fmt(int(r.get("cogs", 0))), UIKit.TEXT_SUB)
	info_row(v2, "기타 비용 (탄 요리·상한 재료)", "-%s" % UIKit.fmt(int(r.get("other_costs", 0))), UIKit.TEXT_SUB)
	v2.add_child(UIKit.separator())
	var net := int(r.get("net_profit", 0))
	info_row(v2, "순수익", ("+" if net >= 0 else "") + UIKit.fmt(net), UIKit.SUCCESS if net >= 0 else UIKit.DANGER)
	v2.add_child(UIKit.label("매출과 팁은 받는 즉시 지급되었습니다. 재료비는 영업 준비 때 미리 지불했습니다.", "caption"))
	content.add_child(c2)
	# 순위
	var ranking: Array = r.get("ranking", [])
	if ranking.size() > 0:
		section("오늘의 매출 순위 · %d위" % int(r.get("my_rank", 1)))
		var c4 := UIKit.card()
		var v4 := UIKit.vbox(6)
		c4.add_child(v4)
		for i in ranking.size():
			var e: Dictionary = ranking[i]
			info_row(v4, "%d. %s" % [i + 1, e.get("name", "")], "%s (%d개)" % [UIKit.fmt(int(e.get("revenue", 0))), int(e.get("sales", 0))], UIKit.ACCENT if e.get("mine", false) else UIKit.TEXT)
		content.add_child(c4)
	# 대결의 밤
	var sd: Dictionary = r.get("showdown", {})
	if not sd.is_empty():
		var win: bool = sd.get("win", false)
		section("대결의 밤 — %s" % ("승리!" if win else "패배"))
		var c6 := UIKit.card(Color("#2F5E48") if win else Color("#6A2E2E"))
		var v6 := UIKit.vbox(6)
		c6.add_child(v6)
		info_row(v6, "내 포차", UIKit.fmt(int(sd.get("mine", 0))), UIKit.ACCENT)
		info_row(v6, str(sd.get("rival_name", "")), UIKit.fmt(int(sd.get("theirs", 0))))
		info_row(v6, "보상", ("코인 +%d · 평판 +%d" % [int(sd.get("coins", 0)), int(sd.get("rep", 0))]) if win else ("평판 %d" % int(sd.get("rep", 0))), UIKit.SUCCESS if win else UIKit.DANGER)
		content.add_child(c6)
	# 오늘의 목표
	var goals: Array = r.get("goals", [])
	if goals.size() > 0:
		var done_n := 0
		for g in goals:
			if g.get("done", false):
				done_n += 1
		section("오늘의 목표 %d/%d" % [done_n, goals.size()])
		var c5 := UIKit.card()
		var v5 := UIKit.vbox(6)
		c5.add_child(v5)
		for g in goals:
			var ok: bool = g.get("done", false)
			info_row(v5, ("✓ " if ok else "✗ ") + str(g.get("text", "")) + " (%d)" % int(g.get("value", 0)),
				("+%d 코인" % int(g.get("coins", 0))) if ok else "실패", UIKit.SUCCESS if ok else UIKit.TEXT_SUB)
		content.add_child(c5)
	# 특별 손님
	var sp: Array = r.get("specials_list", [])
	if sp.size() > 0 or int(r.get("best_combo", 0)) >= 2:
		section("오늘의 기록")
		var c7 := UIKit.card()
		var v7 := UIKit.vbox(6)
		c7.add_child(v7)
		info_row(v7, "최고 콤보", "x%d" % int(r.get("best_combo", 0)), UIKit.SUCCESS)
		if sp.size() > 0:
			var names: Array = []
			for id in sp:
				names.append(str(DataManager.specials.get(id, {}).get("name", id)))
			info_row(v7, "대접한 특별 손님", ", ".join(names), UIKit.ACCENT)
		if int(r.get("critic_rep", 0)) != 0:
			info_row(v7, "평론가 평가", "평판 %+d" % int(r.get("critic_rep", 0)), UIKit.REP)
		if float(r.get("influencer_bonus", 0.0)) > 0.0:
			info_row(v7, "SNS 후기", "다음 영업 손님 +%d%%" % int(float(r["influencer_bonus"]) * 100), UIKit.SUCCESS)
		content.add_child(c7)
	var events: Array = r.get("events", [])
	if events.size() > 0:
		var names: Array = []
		for e in events:
			names.append(DataManager.get_event(str(e)).get("name", e))
		content.add_child(UIKit.label("발생 이벤트: " + ", ".join(names), "body", UIKit.ACCENT))
	# 보상
	section("정산 보상")
	var c3 := UIKit.card(UIKit.PANEL_DARK)
	var v3 := UIKit.vbox(6)
	c3.add_child(v3)
	info_row(v3, "획득 평판", "+%d" % int(r.get("rep_gain", 0)), UIKit.REP)
	info_row(v3, "만족도 보너스", "+%s 코인" % UIKit.fmt(int(r.get("bonus_coins", 0))), UIKit.ACCENT)
	if int(r.get("goal_coins", 0)) > 0:
		info_row(v3, "목표 달성 보상", "+%s 코인 · 평판 +%d" % [UIKit.fmt(int(r.get("goal_coins", 0))), int(r.get("goal_rep", 0))], UIKit.ACCENT)
	if int(r.get("bonus_coins", 0)) == 0:
		v3.add_child(UIKit.label("평균 만족도 %d 이상이면 매출의 %d%% 보너스" % [int(DataManager.bal("satisfaction_bonus_threshold", 70)), int(float(DataManager.bal("satisfaction_bonus_rate", 0.05)) * 100)], "caption"))
	content.add_child(c3)
	if claimed.is_empty():
		var b := footer_button("정산 받기", "primary", _claim, GameManager.economy.has_unclaimed_result())
		if not GameManager.economy.has_unclaimed_result():
			b.text = "정산 완료"
			footer_button("닫기", "secondary", close)
	else:
		content.add_child(UIKit.label("평판 +%d, 코인 +%d 을(를) 받았습니다." % [int(claimed.get("rep_gain", 0)), int(claimed.get("bonus_coins", 0))], "section", UIKit.SUCCESS))
		footer_button("확인", "primary", close)


func _claim() -> void:
	if not claimed.is_empty():
		return
	var r: Dictionary = GameManager.claim_session_result()
	if r.get("ok", false):
		claimed = r
	else:
		claimed = {"rep_gain": 0, "bonus_coins": 0}
	queue_refresh()
