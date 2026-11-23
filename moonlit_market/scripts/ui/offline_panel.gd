extends "res://scripts/ui/base_panel.gd"
## 오프라인 보상 정산 화면. 보상은 광고 없이 받을 수 있고, 광고는 "추가 보상" 인터페이스만 준비.

var paid: int = -1


func _configure() -> void:
	title_text = "자리를 비운 동안"
	centered = true
	auto_refresh = false


func build() -> void:
	var off: Dictionary = GameManager.state.offline
	if paid >= 0:
		content.add_child(UIKit.label("%s 코인을 받았습니다!" % UIKit.fmt(paid), "section", UIKit.SUCCESS))
		footer_button("확인", "primary", close)
		return
	var minutes := float(off.get("pending_minutes", 0.0))
	var amount := int(off.get("pending_amount", 0))
	content.add_child(UIKit.label("시장이 닫혀 있는 동안에도 단골손님이 조금씩 찾아왔어요.", "body"))
	var c := UIKit.card(UIKit.PANEL_DARK)
	var v := UIKit.vbox(6)
	c.add_child(v)
	info_row(v, "경과 시간", "%d시간 %d분" % [int(minutes) / 60, int(minutes) % 60])
	info_row(v, "기준 (최근 영업 분당 순수익)", "%s" % UIKit.fmt(int(GameManager.state.last_session.get("per_minute", 0.0))))
	info_row(v, "오프라인 효율", "%d%% · 최대 %d분" % [int(GameManager.offline.efficiency() * 100), int(GameManager.offline.max_minutes())])
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label("보상", "section"))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.currency("coin", amount, "number"))
	v.add_child(row)
	content.add_child(c)
	var ad_ok: bool = GameManager.ads.is_available("offline_bonus")
	var ad_b := footer_button("광고 보고 2배" if ad_ok else "2배 (광고 준비 중)", "secondary", _on_ad, ad_ok and amount > 0)
	if ad_ok and not GameManager.ads.has_sdk():
		ad_b.text = "[테스트] 2배"
	footer_button("받기", "primary", _claim.bind(1.0), amount > 0)


func _claim(mult: float) -> void:
	if paid >= 0:
		return
	paid = GameManager.claim_offline_reward(mult)
	queue_refresh()


func _on_ad() -> void:
	if paid >= 0:
		return
	var ads = GameManager.ads
	if not ads.reward_granted.is_connected(_on_ad_reward):
		ads.reward_granted.connect(_on_ad_reward, CONNECT_ONE_SHOT)
	ads.show("offline_bonus")


func _on_ad_reward(placement: String) -> void:
	if placement == "offline_bonus":
		_claim(2.0)
