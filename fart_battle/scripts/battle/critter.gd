extends Node2D
## Critter — 엉덩이를 맞대는 동물 캐릭터 (옆모습, 도형으로 그림).
## 로컬 좌표: 머리 = 왼쪽(-x), 엉덩이 = 오른쪽(+x), 발 = y 0. 오른쪽 선수는 scale.x = -1 로 뒤집는다.
## 압력이 차면 엉덩이가 부풀고 얼굴이 빨개지며, 기절하면 눈이 X 가 된다.

const BUTT := Vector2(88, -60) ## 빔이 나가는 곳

var species: String = "mole"
var body_col: Color = Color("#6B5A70")
var belly_col: Color = Color("#C9A0B8")
var pressure: float = 0.0
var stunned: bool = false
var blocking: bool = false
var beaming: float = 0.0 ## 0~1 빔 세기
var mood: String = "normal" ## normal / happy / sad
var anim_t: float = 0.0
var recoil: float = 0.0
var eat_t: float = 0.0


func setup_from(def: Dictionary) -> void:
	species = str(def.get("species", "mole"))
	body_col = Data.color(def.get("body", "#6B5A70"))
	belly_col = Data.color(def.get("belly", "#C9A0B8"))
	queue_redraw()


func butt_global() -> Vector2:
	return to_global(BUTT)


func _process(delta: float) -> void:
	anim_t += delta
	recoil = maxf(0.0, recoil - delta * 3.0)
	eat_t = maxf(0.0, eat_t - delta)
	queue_redraw()


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var p := pressure
	var shake := Vector2(sin(anim_t * 60.0), cos(anim_t * 47.0)) * (p * p * 3.0) + Vector2(-recoil * 10.0, 0)
	var breathe := sin(anim_t * 3.0) * 1.5
	var dark := body_col.darkened(0.25)
	# 그림자
	_ellipse(Vector2(0, 4), 92, 12, Color(0, 0, 0, 0.25))
	# 꼬리 (몸 뒤)
	_draw_tail(shake, dark)
	# 다리
	for x in [-46.0, -24.0]:
		draw_rect(Rect2(Vector2(x - 9, -30) + shake * 0.3, Vector2(18, 30)), dark)
		_ellipse(Vector2(x, -2) + shake * 0.3, 11, 6, dark.darkened(0.2))
	for x in [34.0, 56.0]:
		draw_rect(Rect2(Vector2(x - 10, -38) + shake * 0.3, Vector2(20, 38)), dark)
		_ellipse(Vector2(x, -2) + shake * 0.3, 12, 6, dark.darkened(0.2))
	# 몸통 (엉덩이 쪽이 들림)
	var big := 1.25 if species in ["gorilla", "hippo"] else 1.0
	_ellipse(Vector2(6, -62 + breathe) + shake, 66 * big, 40 * big, body_col, -0.16)
	_ellipse(Vector2(-6, -46 + breathe) + shake, 46 * big, 20 * big, belly_col, -0.1)
	# 엉덩이 (압력에 따라 부풂)
	var br := (36.0 + 10.0 * p) * big
	var bc := Vector2(52, -64 + breathe) + shake
	_ellipse(bc, br, br * 0.95, body_col.lightened(0.05))
	draw_arc(bc + Vector2(br * 0.35, 4), br * 0.55, PI * 0.55, PI * 1.25, 12, dark, 3.0, true)
	if species == "skunk":
		_ellipse(Vector2(10, -96 + breathe) + shake, 60, 8, Color("#FFFFFF"), -0.16)
	# 머리
	var hp := Vector2(-66, -50 + breathe * 0.5) + shake
	if species == "hippo":
		hp += Vector2(-6, -4)
	_draw_head(hp, p, big)
	# 코 막기 (빨래집게 + 방어막)
	if blocking:
		var nose := hp + Vector2(-34 * big, 4)
		draw_rect(Rect2(nose + Vector2(-6, -16), Vector2(12, 22)), Color("#FFD25F"))
		draw_rect(Rect2(nose + Vector2(-6, -16), Vector2(12, 5)), Color("#D9A62F"))
		draw_arc(Vector2(10, -60), 110, -PI * 0.35, PI * 0.35, 24, Color(0.5, 1.0, 0.6, 0.35 + 0.2 * sin(anim_t * 12.0)), 6.0, true)
	# 기절 별
	if stunned:
		for k in 3:
			var a := anim_t * 4.0 + k * TAU / 3.0
			var sp := hp + Vector2(cos(a) * 30, -38 + sin(a) * 8)
			_star(sp, 7, Color("#FFE15F"))


func _draw_tail(shake: Vector2, dark: Color) -> void:
	match species:
		"squirrel":
			var tp := Vector2(70, -100) + shake * 0.6
			_ellipse(tp, 26, 40, body_col.lightened(0.1), 0.5)
			_ellipse(tp + Vector2(-14, -34), 22, 22, body_col.lightened(0.15))
			_ellipse(tp + Vector2(-4, 6), 14, 26, belly_col, 0.5)
		"skunk":
			var tp2 := Vector2(64, -112) + shake * 0.6
			_ellipse(tp2, 30, 52, Color("#2A2A33"), 0.35)
			_ellipse(tp2 + Vector2(-4, -4), 9, 44, Color("#FFFFFF"), 0.35)
		"boar", "mole", "hippo":
			draw_line(Vector2(84, -78) + shake, Vector2(100, -92) + shake, dark, 4.0)
			draw_arc(Vector2(104, -96) + shake, 6, 0, PI * 1.5, 8, dark, 3.0, true)
		_:
			pass


func _draw_head(hp: Vector2, p: float, big: float) -> void:
	var r := 32.0 * big
	var face := body_col.lightened(0.05)
	if species == "gorilla":
		face = Color("#7A7A88")
	# 귀
	match species:
		"squirrel":
			_ellipse(hp + Vector2(4, -r * 0.9), 8, 14, body_col.darkened(0.1), 0.2)
			draw_line(hp + Vector2(4, -r * 1.3), hp + Vector2(8, -r * 1.55), body_col.darkened(0.3), 3.0)
		"boar":
			draw_colored_polygon(PackedVector2Array([hp + Vector2(0, -r * 0.7), hp + Vector2(14, -r * 1.3), hp + Vector2(18, -r * 0.6)]), body_col.darkened(0.2))
			_ellipse(hp + Vector2(20, -r * 0.9), 7, 7, Color("#FF8FB8"))
		"hippo":
			_ellipse(hp + Vector2(10, -r * 0.85), 7, 9, body_col.darkened(0.15))
		"skunk":
			_ellipse(hp + Vector2(8, -r * 0.85), 9, 10, Color("#2A2A33"))
		"gorilla":
			pass
	_ellipse(hp, r, r * 0.92, face)
	# 주둥이 / 코
	match species:
		"mole":
			_ellipse(hp + Vector2(-r * 0.95, 4), 13, 11, Color("#FF8FB8"))
			_ellipse(hp + Vector2(-r * 1.0, 1), 5, 4, Color("#FFC9DD"))
		"boar":
			_ellipse(hp + Vector2(-r * 0.9, 8), 14, 13, Color("#D9A08A"))
			draw_circle(hp + Vector2(-r * 1.0, 6), 3, Color("#5A3A30"))
			draw_line(hp + Vector2(-r * 0.7, 16), hp + Vector2(-r * 0.95, 0), Color("#FFF8E6"), 5.0)
		"hippo":
			_ellipse(hp + Vector2(-r * 0.7, 10), r * 0.7, r * 0.55, belly_col)
			draw_circle(hp + Vector2(-r * 1.05, 2), 3.5, Color("#5A4A70"))
		"squirrel", "skunk":
			_ellipse(hp + Vector2(-r * 0.85, 6), 10, 8, belly_col)
			draw_circle(hp + Vector2(-r * 1.02, 3), 4, Color("#2A1A0C"))
		"gorilla":
			_ellipse(hp + Vector2(-r * 0.6, 8), r * 0.55, r * 0.45, Color("#9A9AA8"))
			draw_rect(Rect2(hp + Vector2(-r * 0.6, -r * 0.55), Vector2(r * 1.2, 7)), Color("#E5483A"))
	# 볼 (압력에 따라 빨개짐)
	_ellipse(hp + Vector2(-r * 0.25, r * 0.35), 8, 5, Color(1.0, 0.3, 0.35, 0.25 + 0.55 * p))
	# 눈
	var eye := hp + Vector2(-r * 0.35, -r * 0.15)
	if stunned:
		draw_line(eye + Vector2(-5, -5), eye + Vector2(5, 5), Color("#1A1A1A"), 3.0)
		draw_line(eye + Vector2(5, -5), eye + Vector2(-5, 5), Color("#1A1A1A"), 3.0)
	elif mood == "happy":
		draw_arc(eye, 6, PI * 1.1, PI * 1.9, 8, Color("#1A1A1A"), 3.0, true)
	elif mood == "sad":
		draw_arc(eye + Vector2(0, -6), 6, PI * 0.1, PI * 0.9, 8, Color("#1A1A1A"), 3.0, true)
	elif p > 0.55:
		draw_line(eye + Vector2(-6, -4), eye + Vector2(4, 0), Color("#1A1A1A"), 3.0)
		draw_line(eye + Vector2(-6, 4), eye + Vector2(4, 0), Color("#1A1A1A"), 3.0)
	else:
		var sz := 2.5 if species == "mole" else 5.0
		draw_circle(eye, sz, Color("#1A1A1A"))
		if species != "mole":
			draw_circle(eye + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1))
	# 땀
	if p > 0.7 and not stunned:
		var dy := fmod(anim_t * 40.0, 16.0)
		_ellipse(hp + Vector2(4, -r - 2 + dy), 4, 6, Color(0.5, 0.8, 1.0, 0.8))
	# 먹는 중
	if eat_t > 0.0:
		var mouth := hp + Vector2(-r * 0.75, r * 0.45)
		draw_arc(mouth, 6, 0, PI, 8, Color("#1A1A1A"), 2.5, true)
	# 캐릭터 소품
	match species:
		"skunk":
			draw_arc(eye, 9, 0, TAU, 16, Color("#5FE8FF"), 2.5, true)
		"boar":
			_ellipse(hp + Vector2(6, -r * 0.95), 10, 6, Color("#FF5FD2"))
			_ellipse(hp + Vector2(6, -r * 0.95), 4, 4, Color("#FFE15F"))
		"hippo":
			var c := hp + Vector2(4, -r - 6)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 6), c + Vector2(-16, -10), c + Vector2(-8, -2), c + Vector2(0, -14), c + Vector2(8, -2), c + Vector2(16, -10), c + Vector2(16, 6)]), Color("#FFD25F"))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
