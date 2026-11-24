extends Node2D
## Pocha — 포차 앞 카운터 (사장님보다 앞에 그려짐).
## 왼쪽: 화구(실제 Kitchen 상태), 가운데: 서빙대(완성 음식), 오른쪽: 술 냉장고 + 생맥주 탭.

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
	var pm = market.pocha_manager if market else null
	var lv: int = GameManager.state.pocha_level()
	var count := int(DataManager.get_pocha_level(lv).get("burners", 2))
	# 카운터 본체 (전체 폭)
	draw_rect(Rect2(Vector2(-372, -18), Vector2(744, 90)), Color("#6B4430"))
	draw_rect(Rect2(Vector2(-372, -30), Vector2(744, 16)), Color("#C99E70"))
	draw_rect(Rect2(Vector2(-372, -14), Vector2(744, 4)), Color("#8A5A3C"))
	for k in 9:
		draw_line(Vector2(-360 + k * 90, -10), Vector2(-360 + k * 90, 70), Color("#5A3826"), 2.0)
	# ── 화구 (왼쪽) ──
	var gx := -230.0
	draw_rect(Rect2(Vector2(gx - 120, -40), Vector2(240, 26)), Color("#3A3A3E"))
	var burners: Array = pm.kitchen.burners if pm else []
	for i in count:
		var bp := Vector2(gx - 82 + i * (164.0 / maxf(1, count - 1) if count > 1 else 0.0), -30)
		if count == 1:
			bp.x = gx
		DrawUtil.ellipse(self, bp, 22, 7, Color("#1E1E22"))
		if i < burners.size() and burners[i]["menu"] != "":
			var stage: String = pm.kitchen.stage(i)
			DrawUtil.ellipse(self, bp, 20, 6, Color(1.0, 0.45, 0.15, 0.5 + 0.25 * sin(anim_t * 9.0 + i)))
			var m: Dictionary = DataManager.get_menu(str(burners[i]["menu"]))
			var fc := DataManager.color(m.get("color", "#E97858"))
			if stage == KitchenScript.STAGE_BURNT:
				fc = Color("#2A2220")
			elif stage == KitchenScript.STAGE_OVER:
				fc = fc.darkened(0.45)
			elif stage == KitchenScript.STAGE_RAW:
				fc = fc.lightened(0.35)
			DrawUtil.menu_icon(self, m, bp + Vector2(0, -8), 12, fc)
			for k in 2:
				var sy := fmod(anim_t * 30.0 + k * 14.0 + i * 9.0, 34.0)
				var smoke := Color(0.25, 0.22, 0.2, 0.55) if stage == KitchenScript.STAGE_BURNT else Color(1, 1, 1, 0.35)
				draw_circle(bp + Vector2(k * 9 - 4, -20 - sy), 5.5 - sy * 0.1, Color(smoke, maxf(0.0, smoke.a - sy * 0.01)))
			if stage == KitchenScript.STAGE_PERFECT:
				draw_arc(bp + Vector2(0, -8), 20, 0, TAU, 20, Color(0.4, 0.85, 0.6, 0.5 + 0.4 * sin(anim_t * 10.0)), 3.0, true)
	DrawUtil.text_center(self, Vector2(gx, 30), "화구", 18, Color(1, 1, 1, 0.55), 0)
	# ── 서빙대 (가운데) ──
	var cap: int = pm.pass_capacity() if pm else 4
	draw_rect(Rect2(Vector2(-110, -44), Vector2(220, 18)), Color("#E8E2D6"))
	draw_rect(Rect2(Vector2(-110, -28), Vector2(220, 4)), Color("#B8AE9C"))
	var items: Array = pm.pass_items if pm else []
	for k in cap:
		var px := -82.0 + k * (164.0 / maxf(1, cap - 1))
		DrawUtil.ellipse(self, Vector2(px, -40), 18, 5, Color(1, 1, 1, 0.5) if k < items.size() else Color(0, 0, 0, 0.12))
		if k < items.size():
			var m2: Dictionary = DataManager.get_menu(str(items[k]["menu"]))
			var bobv := sin(anim_t * 4.0 + k) * 1.5
			DrawUtil.menu_icon(self, m2, Vector2(px, -52 + bobv), 12)
			var age := float(items[k]["age"])
			if age > float(DataManager.pocha.get("pass_decay_time", 22.0)) * 0.6:
				DrawUtil.text_center(self, Vector2(px, -76), "!", 18, Color("#E97858"), 4)
	DrawUtil.text_center(self, Vector2(0, 30), "서빙대 %d/%d" % [items.size(), cap], 18, Color("#FFD27A") if items.size() >= cap else Color(1, 1, 1, 0.55), 0)
	# ── 술 냉장고 + 맥주 탭 (오른쪽) ──
	var dx := 230.0
	DrawUtil.rounded_rect(self, Rect2(Vector2(dx - 60, -120), Vector2(120, 96)), 10, Color("#D9E2EA"))
	DrawUtil.rounded_rect(self, Rect2(Vector2(dx - 52, -112), Vector2(104, 80)), 6, Color("#2C4A66"))
	for k in 5:
		var bc: Color = [Color("#3E8E5A"), Color("#EDE6D6"), Color("#F2C14E"), Color("#3E8E5A"), Color("#9EE0C9")][k]
		draw_rect(Rect2(Vector2(dx - 44 + k * 19, -100), Vector2(10, 26)), bc)
		draw_rect(Rect2(Vector2(dx - 42 + k * 19, -106), Vector2(6, 6)), bc.darkened(0.3))
	draw_rect(Rect2(Vector2(dx - 52, -66), Vector2(104, 3)), Color(1, 1, 1, 0.3))
	DrawUtil.glow(self, Vector2(dx, -72), 60, Color(0.6, 0.85, 1.0, 0.18), 2)
	# 생맥주 탭
	draw_rect(Rect2(Vector2(dx + 70, -76), Vector2(10, 46)), Color("#A0A4B8"))
	draw_rect(Rect2(Vector2(dx + 64, -82), Vector2(22, 8)), Color("#C9CDD8"))
	draw_rect(Rect2(Vector2(dx + 76, -60), Vector2(14, 6)), Color("#2A2A2A"))
	DrawUtil.text_center(self, Vector2(dx, 30), "술·음료", 18, Color(1, 1, 1, 0.55), 0)
	if pulse > 0.0:
		DrawUtil.glow(self, Vector2(0, -40), 120, Color(1.0, 0.85, 0.4, pulse * 0.5))
