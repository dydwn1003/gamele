extends "res://scripts/ui/base_panel.gd"
## 공통 확인/알림 대화상자

func _configure() -> void:
	centered = true
	auto_refresh = false
	title_text = str(args.get("title", "알림"))
	dismiss_on_dim = bool(args.get("dismissable", true))


func build() -> void:
	var msg := UIKit.label(str(args.get("message", "")), "body")
	content.add_child(msg)
	for b in args.get("buttons", []):
		var cb: Callable = b.get("callback", Callable())
		footer_button(str(b.get("text", "확인")), str(b.get("variant", "primary")), func():
			close()
			if cb.is_valid():
				cb.call()
		)
	if footer.get_child_count() == 0:
		footer_button("확인", "primary", close)
