extends Control
## Pad — 한 선수의 조작부 (그리기 + 영역 판정). 터치는 Battle 이 받아서 region_at() 으로 판정한다.
##   큰 뿡 버튼(꾹 눌러 압력 → 떼면 방귀), 코 막기 버튼, 압력 게이지(초록 = 완벽 구간), 가스 바, 효과 표시
## flipped = true 면 위쪽 선수용으로 180도 돌려 그린다 (둘이서 대결).

const UIKit := preload("res://scripts/ui/ui_kit.gd")

const FART_C := Vector2(500, 168)
const FART_R := 108.0
const BLOCK_C := Vector2(112, 176)
const BLOCK_R := 72.0
const GAUGE := Rect2(Vector2(240, 66), Vector2(40, 200))

var logic
var side: int = 0
var flipped: bool = false
var label: String = ""
var accent: Color = Color("#FF5FD2")
var fart_down: bool = false
var block_flash: float = 0.0
var anim_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(720, 300)


func _process(delta: float) -> void:
	anim_t += delta
	block_flash = maxf(0.0, block_flash - delta * 3.0)
	queue_redraw()


## 화면(전역) 좌표 → 이 패드의 영역 이름 ("fart" / "block" / "")
func region_at(global_point: Vector2) -> String:
	var local := (global_point - global_position) / maxf(0.01, get_global_transform().get_scale().x)
	if flipped:
		local = size - local
	if local.distance_to(FART_C) <= FART_R + 14.0:
		return "fart"
	if local.distance_to(BLOCK_C) <= BLOCK_R + 14.0:
		return "block"
	return ""


func _draw() -> void:
	if flipped:
		draw_set_transform(size, PI, Vector2.ONE)
	var font: Font = UIKit.bold_font()
	draw_style_box(UIKit.box(Color(UIKit.PANEL_DARK, 0.92), 26, 0), Rect2(Vector2.ZERO, size))
	if logic == null:
		return
	var f: Dictionary = logic.fighters[side]
	var bal: Dictionary = logic.bal
	# 이름
	draw_string(font, Vector2(24, 36), label, HORIZONTAL_ALIGNMENT_LEFT, 180, 20, accent)
	# 가스 바
	var gmax := float(bal.get("gas_max", 100.0))
	var gas_r := Rect2(Vector2(210, 18), Vector2(250, 22))
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.4), 11, 0), gas_r)
	var gk := clampf(float(f["gas"]) / gmax, 0.0, 1.0)
	if gk > 0.0:
		draw_style_box(UIKit.box(Color("#9BE05F") if float(f["regen_t"]) <= 0.0 else Color("#5FE8FF"), 11, 0), Rect2(gas_r.position, Vector2(maxf(22.0, gas_r.size.x * gk), gas_r.size.y)))
	draw_string(font, gas_r.position + Vector2(10, 17), "가스 %d" % int(f["gas"]), HORIZONTAL_ALIGNMENT_LEFT, 200, 16, Color(0.1, 0.1, 0.1, 0.8))
	# 효과 표시
	var chips: Array = []
	if int(f["power_count"]) > 0:
		chips.append(["고구마 x%d" % int(f["power_count"]), Color("#B5577A")])
	if int(f["fire_count"]) > 0:
		chips.append(["불꽃 x%d" % int(f["fire_count"]), Color("#E5302A")])
	if float(f["stink_next"]) > 0.0:
		chips.append(["냄새 지속", Color("#C9A040")])
	if float(f["fast_t"]) > 0.0:
		chips.append(["탄산 %d" % int(ceil(float(f["fast_t"]))), Color("#E5483A")])
	if float(f["regen_t"]) > 0.0:
		chips.append(["양배추 %d" % int(ceil(float(f["regen_t"]))), Color("#4E9A44")])
	if float(f["boost_next"]) > 1.0:
		chips.append(["초강력!", Color("#5F8FE8")])
	var cx := 474.0
	for ch in chips.slice(0, 3):
		var w := 74.0
		draw_style_box(UIKit.box(ch[1], 10, 0), Rect2(Vector2(cx, 16), Vector2(w, 26)))
		draw_string(font, Vector2(cx, 35), ch[0], HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1, 1, 1))
		cx += w + 6
	# 압력 게이지
	var sweet: Vector2 = logic.sweet_range(side)
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.45), 12, 0), GAUGE.grow(4))
	var gy := func(v: float) -> float: return GAUGE.position.y + GAUGE.size.y * (1.0 - v)
	draw_rect(Rect2(Vector2(GAUGE.position.x - 6, gy.call(sweet.y)), Vector2(GAUGE.size.x + 12, (sweet.y - sweet.x) * GAUGE.size.y)), Color("#7BE85F"))
	draw_rect(Rect2(Vector2(GAUGE.position.x, gy.call(1.0)), Vector2(GAUGE.size.x, 8)), Color("#FF5F5F"))
	var p := float(f["pressure"]) if f["holding"] else 0.0
	if p > 0.0:
		var pc := Color("#FFD25F")
		if p >= sweet.x and p <= sweet.y:
			pc = Color("#7BE85F").lightened(0.2)
		elif p > sweet.y:
			pc = Color("#FF5F5F")
		draw_rect(Rect2(Vector2(GAUGE.position.x + 6, gy.call(p)), Vector2(GAUGE.size.x - 12, GAUGE.size.y * p)), pc)
	var mp: float = logic.max_pressure(side)
	if mp < 1.0:
		draw_line(Vector2(GAUGE.position.x - 8, gy.call(mp)), Vector2(GAUGE.end.x + 8, gy.call(mp)), Color(1, 1, 1, 0.6), 2.0)
	draw_string(font, Vector2(GAUGE.position.x - 30, GAUGE.end.y + 26), "압력", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, UIKit.TEXT_SUB)
	# 코 막기 버튼
	var cd := float(f["block_cd"])
	var cdmax := float(bal.get("block_cooldown", 3.0))
	var bcol := Color("#5FE8FF") if cd <= 0.0 else Color("#4A5A6E")
	if float(f["block_t"]) > 0.0:
		bcol = Color("#9BFFB0")
	draw_circle(BLOCK_C, BLOCK_R, bcol.darkened(0.35))
	draw_circle(BLOCK_C + Vector2(0, -4), BLOCK_R - 6, bcol)
	if cd > 0.0:
		draw_arc(BLOCK_C, BLOCK_R - 3, -PI / 2, -PI / 2 + TAU * (1.0 - cd / cdmax), 32, Color(1, 1, 1, 0.8), 6.0, true)
	# 빨래집게 아이콘
	draw_rect(Rect2(BLOCK_C + Vector2(-9, -40), Vector2(18, 34)), Color("#FFD25F"))
	draw_rect(Rect2(BLOCK_C + Vector2(-9, -40), Vector2(18, 8)), Color("#D9A62F"))
	draw_string(font, BLOCK_C + Vector2(-80, 30), "코 막기", HORIZONTAL_ALIGNMENT_CENTER, 160, 24, Color("#1A2A33"))
	# 뿡 버튼
	var stunned := float(f["stun_t"]) > 0.0
	var fc := accent if not stunned else Color("#6E6478")
	var press_k := 0.94 if fart_down else 1.0
	var r := FART_R * press_k
	draw_circle(FART_C + Vector2(0, 8), r, fc.darkened(0.4))
	draw_circle(FART_C, r, fc)
	if p > 0.0:
		draw_circle(FART_C, r * clampf(p, 0.0, 1.0), Color(1, 1, 1, 0.25))
		var wob := sin(anim_t * 50.0) * 3.0 * p
		draw_arc(FART_C, r + 6 + wob, 0, TAU, 40, Color(1, 1, 1, 0.5), 4.0, true)
	draw_circle(FART_C + Vector2(-r * 0.35, -r * 0.4), r * 0.22, Color(1, 1, 1, 0.25))
	var txt := "꾹~ 뿡!" if not stunned else "기절…"
	if f["holding"]:
		txt = "지금 떼기!" if p >= sweet.x and p <= sweet.y else ("참는 중…" if p < sweet.x else "위험!!")
	draw_string_outline(font, FART_C + Vector2(-140, 14), txt, HORIZONTAL_ALIGNMENT_CENTER, 280, 40, 8, Color(0.2, 0.05, 0.2, 0.7))
	draw_string(font, FART_C + Vector2(-140, 14), txt, HORIZONTAL_ALIGNMENT_CENTER, 280, 40, Color(1, 1, 1))
