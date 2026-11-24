extends Node2D
## Pocha — 내 포장마차 외형. 주황 천막, 나무 카운터, 화구(실제 Kitchen 상태 반영), 플라스틱 의자.
## 레벨이 오르면 좌석·화구·전구 장식이 늘어난다.

const DrawUtil := preload("res://scripts/market/draw_util.gd")
const KitchenScript := preload("res://scripts/market/kitchen.gd")

var market
var anim_t: float = 0.0
var pulse: float = 0.0


func flash() -> void:
	pulse = 1.0


func _process(delta: float) -> void:
	anim_t += delta
	pulse = maxf(0.0, pulse - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var lv: int = GameManager.state.pocha_level()
	var ldef: Dictionary = DataManager.get_pocha_level(lv)
	var pm = market.pocha_manager if market else null
	var tarp := Color("#E8742E")
	var tarp_dark := Color("#B9521C")
	var w := 150.0
	# 바닥 그림자 + 따뜻한 빛
	DrawUtil.ellipse(self, Vector2(0, 30), 230, 70, Color(1.0, 0.6, 0.25, 0.10))
	DrawUtil.ellipse(self, Vector2(0, 8), w + 10, 34, Color(0, 0, 0, 0.35))
	# 천막 뒷면 (안쪽)
	draw_rect(Rect2(Vector2(-w, -175), Vector2(w * 2, 160)), tarp_dark.darkened(0.35))
	# 안쪽 선반 + 술병
	draw_rect(Rect2(Vector2(-w + 16, -128), Vector2(w * 2 - 32, 8)), Color("#6B4430"))
	for k in 8:
		var bx := -w + 30 + k * 34.0
		var bc: Color = [Color("#3E8E5A"), Color("#2F6F9A"), Color("#EDE6D6")][k % 3]
		draw_rect(Rect2(Vector2(bx, -152), Vector2(10, 24)), bc)
		draw_rect(Rect2(Vector2(bx + 3, -160), Vector2(4, 8)), bc.darkened(0.3))
	# 사장님 (나)
	var cook_x := sin(anim_t * 1.3) * 26.0 if pm and pm.is_open else 0.0
	var cp := Vector2(cook_x, -46)
	DrawUtil.rounded_rect(self, Rect2(cp + Vector2(-16, -40), Vector2(32, 40)), 12, Color("#FFF5E9"))
	draw_rect(Rect2(cp + Vector2(-16, -22), Vector2(32, 22)), Color("#2A2A3A"))
	draw_circle(cp + Vector2(0, -52), 14, Color("#F6D7B8"))
	draw_arc(cp + Vector2(0, -52), 14, PI * 1.05, TAU * 0.98, 12, Color("#2A1A0C"), 7, true)
	draw_rect(Rect2(cp + Vector2(-15, -62), Vector2(30, 6)), Color("#E5483A"))
	draw_circle(cp + Vector2(-5, -51), 2, Color("#2A1A0C"))
	draw_circle(cp + Vector2(5, -51), 2, Color("#2A1A0C"))
	# 카운터
	draw_rect(Rect2(Vector2(-w + 6, -30), Vector2(w * 2 - 12, 40)), Color("#8A5A3C"))
	draw_rect(Rect2(Vector2(-w, -40), Vector2(w * 2, 12)), Color("#C99E70"))
	for k in 5:
		draw_line(Vector2(-w + 30 + k * 60, -26), Vector2(-w + 30 + k * 58, 8), Color("#6B4430"), 2.0)
	# 화구 (실제 주방 상태)
	var burners: Array = pm.kitchen.burners if pm else []
	var count := int(ldef.get("burners", 2))
	for i in count:
		var bx2 := (i - (count - 1) / 2.0) * 56.0
		var bp := Vector2(bx2, -44)
		DrawUtil.ellipse(self, bp, 24, 9, Color("#2A2A2A"))
		var stage := "empty"
		if i < burners.size() and burners[i]["menu"] != "":
			stage = pm.kitchen.stage(i)
			var glow := Color(1.0, 0.45, 0.15, 0.5 + 0.2 * sin(anim_t * 9.0 + i))
			DrawUtil.ellipse(self, bp, 22, 8, glow)
			var m: Dictionary = DataManager.get_menu(str(burners[i]["menu"]))
			var fc := DataManager.color(m.get("color", "#E97858"))
			if stage == KitchenScript.STAGE_BURNT:
				fc = Color("#2A2220")
			elif stage == KitchenScript.STAGE_OVER:
				fc = fc.darkened(0.45)
			elif stage == KitchenScript.STAGE_RAW:
				fc = fc.lightened(0.35)
			DrawUtil.menu_icon(self, m, bp + Vector2(0, -8), 11, fc)
			# 김/연기
			for k in 2:
				var sy := fmod(anim_t * 26.0 + k * 13.0 + i * 7.0, 30.0)
				var smoke := Color(0.25, 0.22, 0.2, 0.5) if stage == KitchenScript.STAGE_BURNT else Color(1, 1, 1, 0.35)
				draw_circle(bp + Vector2(k * 8 - 4, -18 - sy), 5.0 - sy * 0.1, Color(smoke, smoke.a - sy * 0.01))
		else:
			DrawUtil.ellipse(self, bp, 18, 6, Color("#444040"))
	# 천막 지붕 (앞면 + 줄무늬 처마)
	var roof := PackedVector2Array([Vector2(-w - 20, -170), Vector2(-w + 10, -215), Vector2(w - 10, -215), Vector2(w + 20, -170)])
	draw_colored_polygon(roof, tarp)
	for k in 12:
		var x0 := -w - 20 + k * ((w + 20) * 2 / 12.0)
		var col := tarp if k % 2 == 0 else Color("#F7C04A")
		draw_colored_polygon(PackedVector2Array([Vector2(x0, -170), Vector2(x0 + (w + 20) * 2 / 12.0, -170),
			Vector2(x0 + (w + 20) * 2 / 12.0 - 3, -150), Vector2(x0 + 3, -150)]), col)
	# 기둥
	draw_line(Vector2(-w - 12, -170), Vector2(-w - 6, 6), Color("#5A3A28"), 6)
	draw_line(Vector2(w + 12, -170), Vector2(w + 6, 6), Color("#5A3A28"), 6)
	# 전구 줄 (레벨만큼 더 화려하게)
	var bulbs := 5 + lv * 2
	for k in bulbs:
		var t := float(k) / (bulbs - 1)
		var p := Vector2(lerpf(-w + 4, w - 4, t), -148 + sin(t * PI) * 10)
		var fl := 0.75 + 0.25 * sin(anim_t * 3.0 + k)
		DrawUtil.glow(self, p, 16, Color(1.0, 0.8, 0.45, 0.6 * fl), 3)
		draw_circle(p, 4, Color(1.0, 0.92, 0.7, fl))
	# 간판
	var sign_rect := Rect2(Vector2(-80, -246), Vector2(160, 40))
	var neon := 0.75 + 0.25 * sin(anim_t * 2.4)
	DrawUtil.rounded_rect(self, sign_rect.grow(7), 14, Color(1.0, 0.55, 0.3, 0.3 * neon))
	DrawUtil.rounded_rect(self, sign_rect.grow(2), 10, Color("#FFB45C"))
	DrawUtil.rounded_rect(self, sign_rect, 8, Color("#2A1E2E"))
	DrawUtil.text_center(self, sign_rect.get_center(), "달빛포차 Lv.%d" % lv, 22, Color("#FFF1B8"), 0)
	# 플라스틱 의자
	var seats := int(ldef.get("seats", 3))
	for i in seats:
		var sp: Vector2 = market.seat_pos(i, seats) - position if market else Vector2((i - (seats - 1) / 2.0) * 48.0, 58)
		DrawUtil.ellipse(self, sp + Vector2(0, 8), 15, 6, Color(0, 0, 0, 0.3))
		draw_rect(Rect2(sp + Vector2(-11, -6), Vector2(22, 12)), Color("#3E7FD9"))
		DrawUtil.ellipse(self, sp + Vector2(0, -6), 13, 5, Color("#5B95E8"))
	# 서빙 반짝
	if pulse > 0.0:
		DrawUtil.glow(self, Vector2(0, -40), 120, Color(1.0, 0.85, 0.4, pulse * 0.6))
