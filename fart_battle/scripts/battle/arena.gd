extends Node2D
## Arena — 숲속 빈터 대결장 (디자인 좌표 720x560).
## 배경, 두 동물, 방귀 빔과 부딪힘 지점, 음식, 파티클, 팝업 글씨, 화면 흔들림을 그린다.
## 규칙은 BattleLogic 에 있고, 여기서는 상태를 읽어 표현만 한다.

const CritterScript := preload("res://scripts/battle/critter.gd")
const UIKit := preload("res://scripts/ui/ui_kit.gd")

const SIZE := Vector2(720, 560)
const GROUND_Y := 470.0
const LEFT_X := 118.0
const RIGHT_X := 602.0
const FOOD_AREA := Rect2(Vector2(90, 110), Vector2(540, 220))
const FART_WORDS := {"tiny": ["뽁", "뿡", "뽀옹"], "medium": ["뿌웅!", "뿡뿡!", "뿌르륵!"],
	"big": ["뿌아앙!", "뿌우우웅!", "뿌르르릉!"], "mega": ["뿌아아아앙!!", "부와아아앙!!", "뿌르르르릉!!"]}

var logic
var critters: Array = []
var defs: Array = []
var particles: Array = []
var popups: Array = []
var leaves: Array = []
var anim_t: float = 0.0
var shake: float = 0.0
var flash: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for side in 2:
		var c = CritterScript.new()
		c.position = Vector2(LEFT_X if side == 0 else RIGHT_X, GROUND_Y)
		# 왼쪽 선수는 머리가 왼쪽, 오른쪽 선수는 뒤집어서 머리가 오른쪽
		if side == 1:
			c.scale = Vector2(-1, 1)
		add_child(c)
		critters.append(c)
	for i in 14:
		leaves.append({"p": Vector2(rng.randf_range(0, 720), rng.randf_range(0, 460)), "s": rng.randf_range(10, 30), "ph": rng.randf() * TAU})


func setup(p_logic, def0: Dictionary, def1: Dictionary) -> void:
	logic = p_logic
	defs = [def0, def1]
	critters[0].setup_from(def0)
	critters[1].setup_from(def1)


## 부딪힘 지점 (구름 위치 → 화면 x)
func clash_pos() -> Vector2:
	var a: Vector2 = butt_pos(0)
	var b: Vector2 = butt_pos(1)
	var k := clampf((float(logic.cloud) + 1.0) / 2.0, 0.0, 1.0) if logic else 0.5
	return a.lerp(b, k)


func butt_pos(side: int) -> Vector2:
	var c = critters[side]
	return c.position + Vector2(c.BUTT.x * c.scale.x, c.BUTT.y)


func _process(delta: float) -> void:
	anim_t += delta
	shake = maxf(0.0, shake - delta * 2.5)
	flash = maxf(0.0, flash - delta * 3.0)
	if logic:
		for side in 2:
			var f: Dictionary = logic.fighters[side]
			var c = critters[side]
			c.pressure = float(f["pressure"]) if f["holding"] else 0.0
			c.stunned = float(f["stun_t"]) > 0.0
			c.blocking = float(f["block_t"]) > 0.0
			c.beaming = clampf(float(f["beam_t"]) / maxf(0.01, float(f["beam_total"])), 0.0, 1.0) if float(f["beam_t"]) > 0.0 else 0.0
		# 빔 부딪힘 불꽃
		if critters[0].beaming > 0.0 and critters[1].beaming > 0.0 and rng.randf() < 0.8:
			_spark(clash_pos(), 2)
	for pt in particles.duplicate():
		pt["life"] = float(pt["life"]) - delta
		pt["p"] += pt["v"] * delta
		pt["v"] *= 0.96
		pt["v"].y += float(pt.get("g", 0.0)) * delta
		if float(pt["life"]) <= 0.0:
			particles.erase(pt)
	for pp in popups.duplicate():
		pp["t"] = float(pp["t"]) + delta
		if float(pp["t"]) > 1.1:
			popups.erase(pp)
	position = base_position + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake * 14.0 * scale.x
	queue_redraw()


var base_position: Vector2 = Vector2.ZERO


# ───────── 이벤트 연출 ─────────

func handle_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"fart":
			var side := int(ev["side"])
			var size := str(ev["size"])
			var c = critters[side]
			c.recoil = 1.0
			var bp := butt_pos(side)
			var dir := 1.0 if side == 0 else -1.0
			for i in {"tiny": 4, "medium": 8, "big": 14, "mega": 22}.get(size, 6):
				particles.append({"p": bp, "v": Vector2(dir * rng.randf_range(60, 260), rng.randf_range(-90, 60)), "life": rng.randf_range(0.5, 1.1),
					"r": rng.randf_range(8, 20), "c": Color(0.75, 0.95, 0.45, 0.55), "kind": "puff"})
			var words: Array = FART_WORDS.get(size, ["뿡!"])
			var col := Color("#FFE15F") if not ev.get("perfect", false) else Color("#7BE85F")
			popup(bp + Vector2(dir * 40, -70), words[rng.randi() % words.size()], col, {"tiny": 26, "medium": 34, "big": 44, "mega": 54}.get(size, 30))
			if ev.get("perfect", false):
				popup(bp + Vector2(dir * 40, -118), "완벽한 뿡!", Color("#7BE85F"), 26)
			match str(ev.get("result", "")):
				"blocked":
					popup(butt_pos(1 - side) + Vector2(-dir * 30, -110), "막았다!", Color("#5FE8FF"), 28)
				"parry":
					popup(butt_pos(1 - side) + Vector2(-dir * 30, -110), "튕겨내기!!", Color("#FF5FD2"), 34)
					flash = 1.0
			shake = maxf(shake, {"tiny": 0.1, "medium": 0.3, "big": 0.6, "mega": 1.0}.get(size, 0.3))
		"blunder":
			var s2 := int(ev["side"])
			popup(critters[s2].position + Vector2(0, -150), "삐끗!", Color("#FF5F5F"), 44)
			shake = maxf(shake, 0.5)
		"eat":
			var s3 := int(ev["side"])
			critters[s3].eat_t = 0.6
			popup(critters[s3].position + Vector2(0, -150), ("%s 냠!" % ev.get("name", "")) if ev.get("good", true) else "배탈…", Color("#FFFFFF") if ev.get("good", true) else Color("#B9B5B0"), 26)
		"block_start":
			pass
		"no_gas":
			popup(critters[int(ev["side"])].position + Vector2(0, -150), "가스 부족!", Color("#B9B5B0"), 24)
		"round_end":
			var w := int(ev["winner"])
			if w >= 0:
				for i in 30:
					_spark(butt_pos(1 - w), 1)
				shake = 1.0
				critters[w].mood = "happy"
				critters[1 - w].mood = "sad"


func reset_moods() -> void:
	for c in critters:
		c.mood = "normal"


func popup(p: Vector2, text: String, col: Color, size: int) -> void:
	popups.append({"p": p, "text": text, "c": col, "s": size, "t": 0.0})


func _spark(p: Vector2, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		particles.append({"p": p, "v": Vector2.from_angle(a) * rng.randf_range(80, 320), "life": rng.randf_range(0.2, 0.5),
			"r": rng.randf_range(3, 7), "c": Color.from_hsv(rng.randf(), 0.6, 1.0), "kind": "spark"})


## 음식 탭 → uid (없으면 -1)
func food_at(local: Vector2) -> int:
	if logic == null:
		return -1
	for fd in logic.foods:
		if local.distance_to(food_pos(fd)) < 56.0:
			return int(fd["uid"])
	return -1


func food_pos(fd: Dictionary) -> Vector2:
	var p: Vector2 = fd["pos"]
	return FOOD_AREA.position + Vector2(p.x * FOOD_AREA.size.x, (p.y - 0.3) / 0.4 * FOOD_AREA.size.y) + Vector2(0, sin(anim_t * 3.0 + float(fd["uid"])) * 6.0)


# ───────── 그리기 ─────────

func _draw() -> void:
	_draw_background()
	_draw_beams()
	_draw_foods()
	for pt in particles:
		var a := clampf(float(pt["life"]) * 2.0, 0.0, 1.0)
		var c: Color = pt["c"]
		if pt["kind"] == "puff":
			draw_circle(pt["p"], float(pt["r"]) * (1.6 - a * 0.6), Color(c, c.a * a))
		else:
			draw_circle(pt["p"], float(pt["r"]), Color(c, a))
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(1, 1, 1, flash * 0.35))


func _draw_background() -> void:
	# 숲 빛 (위는 금빛, 아래로 초록)
	draw_polygon(PackedVector2Array([Vector2(-400, -900), Vector2(1120, -900), Vector2(1120, GROUND_Y), Vector2(-400, GROUND_Y)]),
		PackedColorArray([Color("#F6D58A"), Color("#F6D58A"), Color("#5E9A54"), Color("#5E9A54")]))
	# 나무 줄기와 잎
	for i in 7:
		var x := -40.0 + i * 128.0 + (40.0 if i % 2 == 0 else 0.0)
		draw_rect(Rect2(Vector2(x, -600), Vector2(26, GROUND_Y + 600)), Color("#6B4A33").lerp(Color("#3E5A35"), 0.35))
	for row in 3:
		for i in 12:
			var cx := -30.0 + i * 68.0 + row * 30.0
			draw_circle(Vector2(cx, 30 + (i % 3) * 22 - row * 150), 74, Color("#4E8A47").lerp(Color("#7FB85A"), float((i + row) % 4) / 4.0).darkened(row * 0.08))
	# 햇살
	for i in 5:
		var x0 := 160.0 + i * 110.0
		var a := 0.08 + 0.04 * sin(anim_t * 0.8 + i)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 50, 0), Vector2(x0 - 60, GROUND_Y), Vector2(x0 - 140, GROUND_Y)]), Color(1, 0.95, 0.7, a))
	# 떠다니는 잎/빛가루
	for l in leaves:
		var p: Vector2 = l["p"] + Vector2(sin(anim_t * 0.7 + float(l["ph"])) * 20.0, fmod(anim_t * float(l["s"]), 480.0))
		p.y = fmod(p.y, GROUND_Y)
		draw_circle(p, 3.0, Color(1, 0.9, 0.5, 0.6))
	# 풀밭
	draw_rect(Rect2(Vector2(-400, GROUND_Y), Vector2(1520, 300)), Color("#4C8C3E"))
	draw_rect(Rect2(Vector2(-400, GROUND_Y), Vector2(1520, 10)), Color("#6FB255"))
	for i in 30:
		var gx := -20.0 + i * 26.0
		draw_line(Vector2(gx, GROUND_Y + 2), Vector2(gx + 4, GROUND_Y - 12), Color("#7FC66B"), 3.0)
	for i in 8:
		var fx := 30.0 + i * 92.0
		draw_circle(Vector2(fx, GROUND_Y + 34 + (i % 2) * 18), 5, [Color("#FFD25F"), Color("#FF8FB8"), Color("#FFFFFF")][i % 3])


func _beam_colors(side: int) -> Array:
	var f: Dictionary = logic.fighters[side]
	if f.get("beam_fire", false):
		return [Color("#FF3B1F"), Color("#FFB43B"), Color("#FFF1A0")]
	var b: Array = defs[side].get("beam", ["#FF5FD2", "#5FE8FF"])
	var c0 := Data.color(b[0])
	var c1 := Data.color(b[1] if b.size() > 1 else b[0])
	if f.get("beam_perfect", false):
		# 완벽한 방귀는 무지개빛
		c0 = Color.from_hsv(fmod(anim_t * 0.8, 1.0), 0.7, 1.0)
		c1 = Color.from_hsv(fmod(anim_t * 0.8 + 0.35, 1.0), 0.6, 1.0)
	return [c0, c1, Color(1, 1, 1)]


func _draw_beams() -> void:
	if logic == null:
		return
	var clash := clash_pos()
	var any := false
	for side in 2:
		var k: float = critters[side].beaming
		if k <= 0.0:
			continue
		any = true
		var f: Dictionary = logic.fighters[side]
		var from := butt_pos(side)
		var cols := _beam_colors(side)
		var width := (16.0 + 26.0 * clampf(float(f["beam_power"]), 0.0, 1.6)) * (0.4 + 0.6 * k)
		var pts := PackedVector2Array()
		var n := 18
		for i in n + 1:
			var t := float(i) / n
			var wob := sin(anim_t * 30.0 + t * 12.0 + side * 2.0) * 4.0 * (1.0 - t * 0.5)
			pts.append(from.lerp(clash, t) + Vector2(0, wob))
		draw_polyline(pts, Color(cols[0], 0.18), width * 2.2, true)
		draw_polyline(pts, Color(cols[0], 0.6), width * 1.3, true)
		draw_polyline(pts, Color(cols[1], 0.85), width * 0.75, true)
		draw_polyline(pts, Color(cols[2], 0.95), width * 0.3, true)
		# 빔 속 에너지 알갱이
		for j in 5:
			var t2 := fmod(anim_t * 2.4 + j * 0.2, 1.0)
			draw_circle(from.lerp(clash, t2), width * 0.22, Color(1, 1, 1, 0.8))
		draw_circle(from, width * 0.7, Color(cols[1], 0.7))
	# 냄새 구름 (부딪힘 지점)
	var pulse := 1.0 + 0.08 * sin(anim_t * 8.0)
	var big := 1.4 if any else 1.0
	for i in 6:
		var a := anim_t * 1.5 + i * TAU / 6.0
		draw_circle(clash + Vector2(cos(a), sin(a) * 0.7) * 22.0 * big, 20.0 * big * pulse, Color(0.7, 0.9, 0.35, 0.55))
	draw_circle(clash, 26.0 * big * pulse, Color(0.8, 0.95, 0.45, 0.8))
	draw_circle(clash + Vector2(-8, -6), 3.5, Color(0.15, 0.2, 0.1))
	draw_circle(clash + Vector2(8, -6), 3.5, Color(0.15, 0.2, 0.1))
	draw_arc(clash + Vector2(0, 6), 7, 0.2, PI - 0.2, 8, Color(0.15, 0.2, 0.1), 2.5, true)
	if critters[0].beaming > 0.0 and critters[1].beaming > 0.0:
		var r := 46.0 + 10.0 * sin(anim_t * 20.0)
		draw_circle(clash, r, Color(1, 1, 1, 0.35))
		for i in 8:
			var a2 := anim_t * 6.0 + i * TAU / 8.0
			draw_line(clash, clash + Vector2.from_angle(a2) * (r + 30), Color(1, 1, 0.8, 0.6), 4.0)


func _draw_foods() -> void:
	if logic == null:
		return
	var font: Font = UIKit.bold_font()
	for fd in logic.foods:
		var p := food_pos(fd)
		var def: Dictionary = Data.food(str(fd["id"]))
		var blink := float(fd["life"]) > 1.2 or fmod(anim_t, 0.3) < 0.18
		if not blink:
			continue
		draw_circle(p, 44, Color(1, 1, 1, 0.25))
		draw_arc(p, 44, 0, TAU, 24, Color(1, 1, 1, 0.7), 3.0, true)
		_draw_food(str(fd["id"]), p, Data.color(def.get("color", "#FFB45C")), Data.color(def.get("inner", "#FFF5E9")))
		var w := 140.0
		draw_string_outline(font, p + Vector2(-w / 2, 64), str(def.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, w, 20, 6, Color(0, 0, 0, 0.7))
		draw_string(font, p + Vector2(-w / 2, 64), str(def.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(1, 1, 1))
	# 팝업 글씨
	for pp in popups:
		var t := float(pp["t"])
		var a := clampf(1.4 - t * 1.3, 0.0, 1.0)
		var s := int(float(pp["s"]) * (1.0 + 0.3 * maxf(0.0, 0.15 - t) / 0.15))
		var pos: Vector2 = pp["p"] + Vector2(0, -t * 40.0)
		var w2 := 400.0
		draw_string_outline(font, pos + Vector2(-w2 / 2, 0), str(pp["text"]), HORIZONTAL_ALIGNMENT_CENTER, w2, s, 10, Color(0.15, 0.08, 0.2, a))
		draw_string(font, pos + Vector2(-w2 / 2, 0), str(pp["text"]), HORIZONTAL_ALIGNMENT_CENTER, w2, s, Color(pp["c"], a))


func _draw_food(id: String, p: Vector2, c: Color, inner: Color) -> void:
	match id:
		"sweet_potato":
			_ellipse(p, 30, 17, c, -0.4)
			_ellipse(p + Vector2(10, -6), 12, 8, inner, -0.4)
		"beans":
			for k in 3:
				_ellipse(p + Vector2(-16 + k * 16, (k % 2) * 6), 9, 12, c, 0.3)
		"egg":
			_ellipse(p, 20, 26, c)
			_ellipse(p + Vector2(0, 4), 11, 11, inner)
		"soda":
			draw_rect(Rect2(p + Vector2(-15, -24), Vector2(30, 48)), c)
			draw_rect(Rect2(p + Vector2(-15, -8), Vector2(30, 12)), inner)
			draw_rect(Rect2(p + Vector2(-12, -28), Vector2(24, 5)), Color("#C9CDD8"))
		"cabbage":
			draw_circle(p, 26, c)
			draw_circle(p + Vector2(-6, -4), 15, inner)
			draw_arc(p, 18, 0.5, 2.6, 8, c.darkened(0.3), 2.0, true)
		"milk":
			draw_rect(Rect2(p + Vector2(-17, -18), Vector2(34, 40)), c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-17, -18), p + Vector2(0, -34), p + Vector2(17, -18)]), Color("#E8E8F0"))
			draw_rect(Rect2(p + Vector2(-17, -2), Vector2(34, 12)), inner)
		"chili":
			draw_polyline(PackedVector2Array([p + Vector2(-26, -10), p + Vector2(-6, 2), p + Vector2(14, 10), p + Vector2(28, 22)]), c, 15.0, true)
			draw_line(p + Vector2(-26, -10), p + Vector2(-34, -20), inner, 5.0)
		_:
			draw_circle(p, 22, c)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)
