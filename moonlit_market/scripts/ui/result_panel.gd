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
	info_row(v1, "방문 고객", "%d명" % int(r.get("visitors", 0)))
	info_row(v1, "구매 고객", "%d명" % int(r.get("buyers", 0)), UIKit.SUCCESS)
	info_row(v1, "이탈 고객", "%d명" % int(r.get("walkouts", 0)), UIKit.DANGER)
	info_row(v1, "평균 만족도", "%d / 100" % int(round(float(r.get("avg_satisfaction", 0)))))
	info_row(v1, "인기 노점", "%s (%d개)" % [r.get("best_stall", "-"), int(r.get("best_stall_sales", 0))], UIKit.ACCENT)
	content.add_child(c1)
	# 매출
	section("매출")
	var c2 := UIKit.card()
	var v2 := UIKit.vbox(6)
	c2.add_child(v2)
	info_row(v2, "판매 수량", "%d개" % int(r.get("sales", 0)))
	info_row(v2, "총매출", "+%s" % UIKit.fmt(int(r.get("revenue", 0))), UIKit.ACCENT)
	info_row(v2, "재료 원가 (판매분)", "-%s" % UIKit.fmt(int(r.get("cogs", 0))), UIKit.TEXT_SUB)
	info_row(v2, "기타 비용 (재고 손실 %d개)" % int(r.get("spoiled", 0)), "-%s" % UIKit.fmt(int(r.get("other_costs", 0))), UIKit.TEXT_SUB)
	v2.add_child(UIKit.separator())
	var net := int(r.get("net_profit", 0))
	info_row(v2, "순수익", ("+" if net >= 0 else "") + UIKit.fmt(net), UIKit.SUCCESS if net >= 0 else UIKit.DANGER)
	v2.add_child(UIKit.label("매출 코인은 판매 즉시 지급되었습니다. 재료비는 재고 구매 때 미리 지불했습니다.", "caption"))
	content.add_child(c2)
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
