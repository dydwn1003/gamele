extends RefCounted
## 공용 연출/리소스 도우미

static var _font: SystemFont


## 한글이 나오는 시스템 폰트 (안드로이드/iOS/PC 공통으로 찾아서 사용)
static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo",
			"Malgun Gothic", "NanumGothic", "Droid Sans Fallback", "sans-serif"])
		_font.font_weight = 700
	return _font


## 머리 위로 떠오르는 숫자/글자 (데미지, 경험치 등)
static func popup(parent: Node, pos: Vector3, text: String, color: Color, size := 64) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = size
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4, 0), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
