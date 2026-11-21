extends Node3D
## 채집 지점: 약초(들판·숲) / 철광맥(산기슭). 채집하면 이번 접속 동안 사라진다.

const LowPoly = preload("res://scripts/models/low_poly.gd")

var node_id := ""
var kind := "herb"
var interact_radius := 2.6


func _ready() -> void:
	if GameState.harvested.has(node_id):
		queue_free()
		return
	add_to_group("interactable")
	var lp := LowPoly.new()
	if kind == "herb":
		for i in 5:
			var a := TAU * i / 5.0
			lp.cylinder(Vector3(cos(a) * 0.15, 0, sin(a) * 0.15), 0.08, 0.0, 0.55, 3, Color(0.25, 0.6, 0.25),
				Transform3D(Basis(Vector3(sin(a), 0, -cos(a)), 0.35), Vector3.ZERO))
		lp.sphere(Vector3(0, 0.55, 0), 0.1, Color(0.95, 0.3, 0.4), Vector3.ONE, 2, 5)
		lp.sphere(Vector3(0.18, 0.45, 0.1), 0.08, Color(0.95, 0.3, 0.4), Vector3.ONE, 2, 5)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(node_id)
		lp.sphere(Vector3(0, 0.4, 0), 0.9, Color(0.42, 0.4, 0.4), Vector3(1.2, 0.8, 1), 3, 6, Transform3D.IDENTITY, 0.2, rng)
		for i in 4:  # 반짝이는 광맥
			var a := TAU * i / 4.0 + 0.3
			lp.box(Vector3(cos(a) * 0.7, 0.55 + (i % 2) * 0.2, sin(a) * 0.55), Vector3(0.22, 0.22, 0.22), Color(0.95, 0.75, 0.35),
				Transform3D(Basis(Vector3.UP, a), Vector3.ZERO))
	var mi := lp.instance()
	if kind == "ore":
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.3, 0.1)
		mi.material_override = mat
	add_child(mi)


func interact_text() -> String:
	return "약초 채집" if kind == "herb" else "광석 캐기"


func interact() -> void:
	GameState.harvested[node_id] = true
	if kind == "herb":
		GameState.add_item("herb", randi_range(1, 2))
		Sfx.play("pickup")
	else:
		GameState.add_item("iron_ore", randi_range(1, 2))
		Sfx.play("anvil")
	queue_free()
