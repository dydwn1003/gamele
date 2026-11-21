extends Node3D
## 땅에 떨어진 아이템/골드. 튀어나온 뒤 플레이어가 가까이 오면 빨려 들어간다.

const LowPoly = preload("res://scripts/models/low_poly.gd")
const Items = preload("res://scripts/game/items.gd")
const Terrain = preload("res://scripts/world/terrain.gd")

var item_id := ""  # 빈 문자열이면 골드
var amount := 1
var player

var _vel := Vector3.ZERO
var _age := 0.0
var _mesh: Node3D
var _landed := false


func setup(p_item: String, p_amount: int, p_player) -> void:
	item_id = p_item
	amount = p_amount
	player = p_player
	_vel = Vector3(randf_range(-3, 3), randf_range(5, 7), randf_range(-3, 3))


func _ready() -> void:
	_mesh = Node3D.new()
	add_child(_mesh)
	var lp := LowPoly.new()
	if item_id == "":
		lp.cylinder(Vector3(0, -0.04, 0), 0.18, 0.18, 0.08, 8, Color(1.0, 0.8, 0.25), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	else:
		var c := Items.rarity_color(item_id)
		lp.box(Vector3(0, 0, 0), Vector3(0.32, 0.26, 0.24), Color(0.55, 0.4, 0.25))  # 주머니
		lp.box(Vector3(0, 0.15, 0), Vector3(0.12, 0.08, 0.12), Color(0.45, 0.32, 0.2))
		lp.box(Vector3(0, 0.0, -0.125), Vector3(0.14, 0.14, 0.02), c)
	var mi := lp.instance(false)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1, 0.85, 0.4) if item_id == "" else Items.rarity_color(item_id)
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	_mesh.add_child(mi)
	if item_id != "" and int(Items.get_item(item_id).get("rarity", 0)) >= 2:
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.12
		cm.height = 3.0
		beam.mesh = cm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var rc := Items.rarity_color(item_id)
		bm.albedo_color = Color(rc.r, rc.g, rc.b, 0.4)
		beam.material_override = bm
		beam.position.y = 1.5
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)


func _process(delta: float) -> void:
	_age += delta
	if _age > 90.0:
		queue_free()
		return
	_mesh.rotation.y += delta * 2.5
	var ground := Terrain.height(global_position.x, global_position.z) + 0.35
	var to := Vector3.ZERO
	var dist := 999.0
	if player and is_instance_valid(player) and not player.dead:
		to = player.global_position + Vector3(0, 0.9, 0) - global_position
		dist = to.length()
	if _age > 0.6 and dist < 7.0:
		# 플레이어에게 빨려 들어감
		global_position += to.normalized() * minf(dist, (6.0 + _age * 4.0) * delta)
		if dist < 0.9:
			_collect()
		return
	if not _landed:
		_vel.y -= 20.0 * delta
		global_position += _vel * delta
		if global_position.y <= ground:
			global_position.y = ground
			_landed = true
	else:
		global_position.y = ground + sin(_age * 3.0) * 0.08


func _collect() -> void:
	if item_id == "":
		GameState.add_gold(amount)
		GameState.item_gained.emit("", amount)
		Sfx.play("coin")
	else:
		GameState.add_item(item_id, amount)
		Sfx.play("pickup")
	queue_free()
