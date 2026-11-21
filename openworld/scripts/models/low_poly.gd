extends RefCounted
## 코드로 로우폴리 메시를 만드는 도구.
## 정점 색상 + 면 단위 노멀(플랫 셰이딩)을 사용해 텍스처 없이도 각진 스타일을 낸다.
## 모든 도형은 "안쪽 기준점"을 받아 면의 방향을 자동으로 바깥쪽으로 맞춘다.

static var _material: StandardMaterial3D

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.92
	return _material


## 삼각형 하나. inside 는 도형 안쪽의 한 점(면이 그 반대쪽을 향하도록 정렬)
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	var centroid := (a + b + c) / 3.0
	if n.dot(centroid - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	_verts.append(a)
	_verts.append(b)
	_verts.append(c)
	for i in 3:
		_normals.append(n)
		_colors.append(color)


## 사각형 (a,b,c,d 는 둘레 순서)
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, inside: Vector3) -> void:
	tri(a, b, c, color, inside)
	tri(a, c, d, color, inside)


func box(center: Vector3, size: Vector3, color: Color, xf := Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		var v := Vector3(
			h.x if (i & 1) else -h.x,
			h.y if (i & 2) else -h.y,
			h.z if (i & 4) else -h.z)
		p.append(xf * (center + v))
	var inside: Vector3 = xf * center
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], color, inside)


## 아래 중심 base 에서 위로 height 만큼 뻗는 원기둥/원뿔 (r_top=0 이면 원뿔)
func cylinder(base: Vector3, r_bottom: float, r_top: float, height: float, segments: int,
		color: Color, xf := Transform3D.IDENTITY, top_color := Color(0, 0, 0, 0)) -> void:
	var tc := color if top_color.a == 0.0 else top_color
	var inside: Vector3 = xf * (base + Vector3(0, height * 0.5, 0))
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in segments:
		var ang := TAU * float(i) / segments
		var dir := Vector3(cos(ang), 0, sin(ang))
		bottom.append(xf * (base + dir * r_bottom))
		top.append(xf * (base + dir * r_top + Vector3(0, height, 0)))
	var apex: Vector3 = xf * (base + Vector3(0, height, 0))
	var bottom_c: Vector3 = xf * base
	for i in segments:
		var j := (i + 1) % segments
		if r_top <= 0.001:
			tri(bottom[i], bottom[j], apex, color, inside)
		else:
			quad(bottom[i], bottom[j], top[j], top[i], color, inside)
			tri(top[i], top[j], apex, tc, inside)
		tri(bottom[i], bottom[j], bottom_c, color, inside)


## 각진 구 (scale 로 타원체, jitter 로 울퉁불퉁한 바위)
func sphere(center: Vector3, radius: float, color: Color, scale := Vector3.ONE,
		rings := 4, segments := 6, xf := Transform3D.IDENTITY, jitter := 0.0, rng: RandomNumberGenerator = null) -> void:
	var pts := []
	for r in rings + 1:
		var row: Array[Vector3] = []
		var lat := PI * float(r) / rings - PI * 0.5
		for s in segments:
			var lon := TAU * float(s) / segments
			var v := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * radius
			if jitter > 0.0 and rng != null and r > 0 and r < rings:
				v *= 1.0 + rng.randf_range(-jitter, jitter)
			row.append(xf * (center + v * scale))
		pts.append(row)
	var inside: Vector3 = xf * center
	for r in rings:
		for s in segments:
			var s2 := (s + 1) % segments
			quad(pts[r][s], pts[r][s2], pts[r + 1][s2], pts[r + 1][s], color, inside)


func is_empty() -> bool:
	return _verts.is_empty()


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


func instance(cast_shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
