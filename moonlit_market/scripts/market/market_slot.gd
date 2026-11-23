extends Node2D
## MarketSlot — 6개 고정 배치 슬롯 중 하나.
## 빈 자리 / 노점 / 시설(포토존·공연장)을 시각적으로 명확히 구분해서 그린다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")
const StallScene := preload("res://scenes/market/stall.tscn")

const HW := 96.0
const HH := 48.0

var slot_index: int = 0
var facing: int = 1
var slot_data: Dictionary = {}
var highlight: String = "" ## "", "place", "move_target", "move_source", "selected"
var anim_t: float = 0.0
var stall_node = null
var operating: bool = false


func _ready() -> void:
	stall_node = StallScene.instantiate()
	stall_node.slot_index = slot_index
	stall_node.facing = facing
	add_child(stall_node)
	stall_node.visible = false


func update_data(p_slot: Dictionary, p_runtime: Dictionary, p_synergies: Array, p_stock_max: int, p_operating: bool) -> void:
	slot_data = p_slot
	operating = p_operating
	var is_stall: bool = p_slot.get("kind", "") == "stall"
	stall_node.visible = is_stall
	if is_stall:
		stall_node.update_data(p_slot, p_runtime, p_synergies, p_stock_max)
	queue_redraw()


func set_highlight(mode: String) -> void:
	highlight = mode
	queue_redraw()


func flash() -> void:
	if stall_node and stall_node.visible:
		stall_node.flash()


func _process(delta: float) -> void:
	anim_t += delta
	if highlight != "" or slot_data.is_empty() or slot_data.get("kind", "") == "facility":
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-HW - 6, -230), Vector2(HW * 2 + 12, 230 + HH + 40))


func _draw() -> void:
	var kind := str(slot_data.get("kind", ""))
	# 바닥 패드 (모든 슬롯 공통)
	var pad := DrawUtil.diamond(Vector2.ZERO, HW, HH)
	if kind == "":
		var pulse := 0.5 + 0.5 * sin(anim_t * 2.5 + slot_index)
		draw_colored_polygon(pad, Color(1, 0.71, 0.36, 0.06 + 0.05 * pulse))
		_dashed_outline(pad, Color(1, 0.71, 0.36, 0.45 + 0.3 * pulse), 3.0)
		if not operating:
			draw_circle(Vector2(0, -6), 22, Color(0.15, 0.17, 0.22, 0.9))
			draw_arc(Vector2(0, -6), 22, 0, TAU, 24, Color("#FFB45C"), 3.0, true)
			draw_line(Vector2(-10, -6), Vector2(10, -6), Color("#FFB45C"), 4.0)
			draw_line(Vector2(0, -16), Vector2(0, 4), Color("#FFB45C"), 4.0)
			DrawUtil.text_center(self, Vector2(0, 32), "빈 자리", 18, Color("#FFF5E9", 0.8), 4)
	elif kind == "facility":
		draw_colored_polygon(pad, Color(0, 0, 0, 0.25))
		_draw_facility(str(slot_data.get("type", "")))
	# 하이라이트
	match highlight:
		"place", "move_target":
			var a := 0.35 + 0.3 * sin(anim_t * 6.0)
			draw_colored_polygon(DrawUtil.diamond(Vector2.ZERO, HW + 8, HH + 4), Color(1, 0.71, 0.36, a * 0.5))
			var ring := DrawUtil.diamond(Vector2.ZERO, HW + 8, HH + 4)
			ring.append(ring[0])
			draw_polyline(ring, Color(1, 0.85, 0.5, 0.9), 4.0, true)
			DrawUtil.text_center(self, Vector2(0, HH + 26), "여기에 설치" if highlight == "place" else "여기로 이동", 20, Color("#FFF5E9"), 5, Color("#C9822F"))
		"move_source", "selected":
			var ring2 := DrawUtil.diamond(Vector2.ZERO, HW + 10, HH + 5)
			ring2.append(ring2[0])
			draw_polyline(ring2, Color(0.4, 0.8, 0.6, 0.9), 4.0, true)


func _dashed_outline(pts: PackedVector2Array, col: Color, width: float) -> void:
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var segs := 7
		for k in segs:
			if k % 2 == 0:
				draw_line(a.lerp(b, float(k) / segs), a.lerp(b, float(k + 1) / segs), col, width)


func _draw_facility(t: String) -> void:
	var def: Dictionary = DataManager.get_facility(t)
	var col := DataManager.color(def.get("color", "#FFD27A"))
	if t == "photo_zone":
		# 초승달 포토 프레임
		draw_line(Vector2(-40, 0), Vector2(-30, -70), Color("#5A3A28"), 6.0)
		draw_line(Vector2(40, 0), Vector2(30, -70), Color("#5A3A28"), 6.0)
		var c := Vector2(0, -120)
		DrawUtil.glow(self, c, 90, Color(col, 0.6 + 0.2 * sin(anim_t * 2.0)))
		draw_circle(c, 52, col)
		draw_circle(c + Vector2(22, -14), 46, Color("#1D2130"))
		for k in 6:
			var a := anim_t * 0.8 + k * TAU / 6.0
			var sp := c + Vector2.from_angle(a) * 70
			draw_circle(sp, 3.0 + sin(anim_t * 4.0 + k) * 1.5, Color("#FFF5E9"))
		DrawUtil.text_center(self, Vector2(0, -40), "PHOTO", 18, Color("#FFF5E9"), 4)
	elif t == "stage":
		# 버스킹 무대
		var top := DrawUtil.diamond(Vector2(0, -16), HW * 0.9, HH * 0.9)
		draw_colored_polygon(PackedVector2Array([top[3], top[2], top[2] + Vector2(0, 16), top[3] + Vector2(0, 16)]), Color("#4A3A6A"))
		draw_colored_polygon(PackedVector2Array([top[2], top[1], top[1] + Vector2(0, 16), top[2] + Vector2(0, 16)]), Color("#5B4A80"))
		draw_colored_polygon(top, Color("#7A68B0"))
		# 커튼
		draw_rect(Rect2(Vector2(-70, -150), Vector2(140, 90)), Color("#8E2F4A"))
		draw_rect(Rect2(Vector2(-70, -150), Vector2(140, 14)), Color("#FFD27A"))
		for k in 4:
			draw_line(Vector2(-60 + k * 40, -136), Vector2(-60 + k * 40, -60), Color("#6E1F38"), 3.0)
		# 연주자
		var bob := sin(anim_t * 6.0) * 3.0
		draw_rect(Rect2(Vector2(-10, -62 + bob), Vector2(20, 28)), col)
		draw_circle(Vector2(0, -72 + bob), 10, Color("#F6D7B8"))
		draw_line(Vector2(-16, -48 + bob), Vector2(18, -56 + bob), Color("#C98A3D"), 5.0)
		# 음표
		for k in 3:
			var ny := fmod(anim_t * 40.0 + k * 30.0, 90.0)
			var np := Vector2(30 + k * 14, -80 - ny)
			var na := 1.0 - ny / 90.0
			draw_circle(np, 5, Color(1, 0.95, 0.7, na))
			draw_line(np + Vector2(4, 0), np + Vector2(4, -14), Color(1, 0.95, 0.7, na), 2.0)
		DrawUtil.text_center(self, Vector2(0, -168), "공연장", 20, Color("#FFF5E9"), 4)
	else:
		draw_circle(Vector2(0, -30), 30, col)
