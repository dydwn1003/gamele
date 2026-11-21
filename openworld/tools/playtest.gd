extends SceneTree
## 자동 플레이 테스트: 타이틀 → 마을 → 대화/퀘스트 → 상점 → 메뉴 탭들 → 대장간
## → 야영지 전투 → 보물상자 → 밤의 해골 → 오우거 → 봉화 점화. 장면마다 스크린샷.

const Terrain = preload("res://scripts/world/terrain.gd")

var frame := 0
var out := ""
var main
var gs
var c
var step_frame := 0
var phase := "title"
var target_camp
var errors := []


func _initialize() -> void:
	out = OS.get_environment("SHOT_DIR")
	if out == "":
		out = "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("shot ", name)


func _at(f: int) -> bool:
	return frame == step_frame + f


func _next(p: String) -> void:
	phase = p
	step_frame = frame
	print("--- ", p, "  (Lv.%d, %dG)" % [gs.level, gs.gold])


func _tp(pos: Vector3) -> void:
	main.world.build_around(pos, 1)
	main.player.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z) + 1.0, pos.z)
	main.rig.global_position = main.player.global_position + Vector3(0, 1.6, 0)


func _look_at(p: Vector3, pitch := -0.2) -> void:
	var d: Vector3 = p - main.player.global_position
	main.rig.yaw = atan2(-d.x, -d.z)
	main.rig.pitch = pitch


func _fight(radius := 40.0) -> int:
	## 가장 가까운 적에게 다가가 공격. 남은 적 수를 돌려준다
	main.player.hp = 9999.0
	var best = null
	var best_d := radius
	var n := 0
	var list: Array = main.get_tree().get_nodes_in_group("enemies")
	for e in list:
		var d: float = e.global_position.distance_to(main.player.global_position)
		if d < radius:
			n += 1
			if d < best_d:
				best_d = d
				best = e
	if best:
		var d: Vector3 = best.global_position - main.player.global_position
		main.rig.yaw = lerp_angle(main.rig.yaw, atan2(-d.x, -d.z), 0.2)
		main.rig.pitch = -0.25
		c.move_touch = Vector2(0, -1) if best_d > 2.6 else Vector2.ZERO
		if best_d <= 3.2 and frame % 8 == 0:
			c.press("attack")
	else:
		c.move_touch = Vector2.ZERO
	return n


func _process(_d: float) -> bool:
	frame += 1
	if gs == null:
		gs = root.get_node("/root/GameState")
		c = root.get_node("/root/Controls")
	match phase:
		"title":
			if _at(50):
				_shot("01_title")
			if _at(52):
				main.queue_free()
				gs.new_game()
				gs.skip_title = true
				gs.time_of_day = 0.35
			if _at(55):
				main = load("res://scenes/main.tscn").instantiate()
				root.add_child(main)
			if _at(110):
				_shot("02_village")
				_next("dialog")
		"dialog":
			var dlg = main.get_tree().get_nodes_in_group("dialog_ui")[0]
			if _at(5):
				var elder = main.get_tree().get_nodes_in_group("npcs").filter(func(n): return n.npc_id == "elder")[0]
				_tp(elder.global_position + Vector3(0, 0, 3))
				_look_at(elder.global_position, -0.1)
			if _at(40):
				_shot("03_elder_marker")
				main.get_tree().call_group("dialog_ui", "open_npc", "elder")
			if _at(70):
				_shot("04_dialog")
				dlg._turn_in("main_1")
			if _at(100):
				_shot("05_quest_complete")
				dlg.close()
				main.get_tree().call_group("dialog_ui", "open_npc", "guard")
			if _at(115):
				dlg._offer("side_goblin")
			if _at(130):
				_shot("06_quest_offer")
				gs.accept_quest("side_goblin")
				dlg.close()
				gs.accept_quest("side_wolf")
				gs.accept_quest("side_herb")
				gs.add_gold(3000)
				main.get_tree().call_group("dialog_ui", "open_npc", "merchant")
			if _at(145):
				dlg._mode = "shop"
				dlg._sub = 0
				dlg._show_shop()
			if _at(170):
				_shot("07_shop")
				gs.buy("armor_chain")
				gs.buy("ring_copper")
				gs.buy("potion_s")
				gs.equip("armor_chain")
				gs.equip("ring_copper")
				gs.add_item("iron_ore", 12, false)
				gs.add_item("goblin_ear", 7, false)
				gs.add_item("wolf_pelt", 4, false)
				gs.add_item("herb", 4, false)
				gs.add_item("golem_core", 1, false)
				dlg.close()
				main.get_tree().call_group("dialog_ui", "open_npc", "smith")
			if _at(185):
				dlg._sub = 0
				dlg._show_smith()
			if _at(210):
				_shot("08_smith_craft")
				var recipes = load("res://scripts/game/items.gd").RECIPES
				gs.craft(recipes[4])  # 기사단 장검
				gs.equip("sword_knight")
				gs.do_enhance("sword_knight")
				gs.do_enhance("sword_knight")
				dlg._sub = 1
				dlg._show_smith()
			if _at(235):
				_shot("09_smith_enhance")
				dlg.close()
				_next("menu")
		"menu":
			var tabs := ["10_menu_bag", "11_menu_equip", "12_menu_quest", "13_menu_map", "14_menu_settings"]
			for i in tabs.size():
				if _at(10 + i * 40):
					main.menu.open_menu(i)
				if _at(38 + i * 40):
					_shot(tabs[i])
			if _at(220):
				main.menu.close_menu()
				# 우두머리가 있는 고블린 야영지로
				for cp in main.camps:
					if cp.kind == "goblin" and cp.has_chief:
						target_camp = cp
						break
				_tp(target_camp.global_position + Vector3(25, 0, 0))
				_look_at(target_camp.global_position, -0.15)
				_next("camp")
		"camp":
			if _at(60):
				_shot("15_goblin_camp")
			if frame > step_frame + 60:
				var n := _fight(45.0)
				if _at(140):
					_shot("16_combat")
				if (n == 0 and frame > step_frame + 120) or _at(1600):
					c.move_touch = Vector2.ZERO
					print("camp cleared=", target_camp.cleared, " alive=", target_camp.alive_count(), " kills=", gs.kills)
					var chest
					for ch in target_camp.get_children():
						if ch.has_method("interact") and "chest_id" in ch:
							chest = ch
					_tp(chest.global_position + Vector3(0, 0, 2.2))
					_look_at(chest.global_position, -0.35)
					set_meta("chest", chest)
					_next("chest")
		"chest":
			main.player.hp = 9999.0
			if _at(20):
				print("chest hint: ", c.interact_hint)
				c.press("interact")
			if _at(45):
				_shot("17_chest_loot")
			if _at(120):
				_shot("18_loot_feed")
				print("chests opened: ", gs.opened_chests, " inventory: ", gs.inventory)
				_next("night")
		"night":
			main.player.hp = 9999.0
			if _at(1):
				gs.time_of_day = 0.92
				var p: Vector3 = main.player.global_position + Vector3(10, 0, 6)
				for k in ["skeleton", "skeleton", "boar"]:
					var e = load("res://scripts/enemies/enemy.gd").new()
					e.setup(k, 2, main.player, k == "boar")
					e.position = Vector3(p.x, Terrain.height(p.x, p.z) + 0.5, p.z)
					main.add_child(e)
					p += Vector3(3, 0, 2)
				_look_at(p, -0.15)
			if _at(50):
				_shot("19_night_skeletons")
			if frame > step_frame + 55:
				var n := _fight(30.0)
				if (n == 0 and frame > step_frame + 100) or _at(900):
					print("night fight done kills=", gs.kills)
					gs.time_of_day = 0.4
					var ogre_camp
					for cp in main.camps:
						if cp.kind == "ogre":
							ogre_camp = cp
							break
					_tp(ogre_camp.global_position + Vector3(22, 0, 8))
					_look_at(ogre_camp.global_position, -0.1)
					set_meta("ogre_camp", ogre_camp)
					_next("ogre")
		"ogre":
			main.player.hp = 9999.0
			if _at(90):
				_shot("20_ogre_lair")
			if frame > step_frame + 90:
				var n := _fight(45.0)
				if _at(200):
					_shot("21_ogre_fight")
				if (n == 0 and frame > step_frame + 150) or _at(2500):
					print("ogre camp cleared=", get_meta("ogre_camp").cleared, " level=", gs.level)
					var b = main.beacons[0]
					_tp(b.global_position + Vector3(14, 0, 10))
					_next("beacon")
		"beacon":
			main.player.hp = 9999.0
			if frame > step_frame + 60:
				var n := _fight(40.0)
				var b = main.beacons[0]
				if n == 0 and frame > step_frame + 120 and not b.lit:
					_tp(b.global_position + Vector3(0, 0, -5))
					b.interact()
				if b.lit and not has_meta("lit_shot"):
					set_meta("lit_shot", frame)
					_look_at(b.global_position + Vector3(0, 8, 0), 0.1)
				if has_meta("lit_shot") and frame == get_meta("lit_shot") + 40:
					_shot("22_beacon_lit")
					print("quests: ", gs.quests)
					print("final: Lv.%d gold=%d equip=%s" % [gs.level, gs.gold, gs.equipment])
					return true
				if _at(2500):
					print("beacon phase timeout")
					return true
	return false
