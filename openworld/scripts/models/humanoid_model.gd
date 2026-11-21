extends Node3D
## 사람형 로우폴리 캐릭터 (주인공 카엘 / 고블린 약탈자 / 바위 골렘)
## 관절(엉덩이·몸통·머리·팔·다리·망토)을 Node3D 피벗으로 나눠서
## 코드로 걷기·공격·회피·활공 애니메이션을 준다. 앞쪽은 -Z.

const LowPoly = preload("res://scripts/models/low_poly.gd")

var style := "hero"

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var cape: Node3D
var weapon: Node3D

var _hip_height := 0.95
var _phase := 0.0
var _attack_t := -1.0
var _attack_len := 0.35
var _attack_kind := 0
var _base_scale := 1.0


func setup(p_style: String) -> void:
	style = p_style
	match style:
		"hero":
			_build_hero()
		"goblin":
			_build_goblin()
		"golem":
			_build_golem()
	_base_scale = scale.x


# ---------------------------------------------------------------- 공통 골격

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _attach(parent: Node3D, lp: LowPoly) -> void:
	parent.add_child(lp.instance())


func _skeleton(hip_h: float, shoulder: Vector3, hip_off: float, neck_y: float) -> void:
	_hip_height = hip_h
	hips = _pivot(self, Vector3(0, hip_h, 0))
	torso = _pivot(hips, Vector3(0, 0.08, 0))
	head = _pivot(torso, Vector3(0, neck_y, 0))
	arm_l = _pivot(torso, Vector3(-shoulder.x, shoulder.y, shoulder.z))
	arm_r = _pivot(torso, Vector3(shoulder.x, shoulder.y, shoulder.z))
	leg_l = _pivot(hips, Vector3(-hip_off, -0.06, 0))
	leg_r = _pivot(hips, Vector3(hip_off, -0.06, 0))


# ---------------------------------------------------------------- 카엘 (주인공)
# 떠돌이 기사. 붉은 망토, 가죽 갑옷, 은빛 견갑, 장검. 갈색 머리에 흉터 하나.

func _build_hero() -> void:
	var skin := Color(0.93, 0.76, 0.62)
	var hair := Color(0.36, 0.22, 0.13)
	var tunic := Color(0.55, 0.12, 0.12)
	var leather := Color(0.45, 0.30, 0.18)
	var dark := Color(0.22, 0.15, 0.10)
	var steel := Color(0.78, 0.80, 0.84)
	var gold := Color(0.88, 0.68, 0.25)
	_skeleton(0.95, Vector3(0.29, 0.44, 0), 0.11, 0.52)

	var p := LowPoly.new()
	p.box(Vector3(0, -0.02, 0), Vector3(0.38, 0.22, 0.24), leather)
	# 허리 앞뒤 천 자락
	p.box(Vector3(0, -0.2, -0.12), Vector3(0.3, 0.26, 0.03), tunic)
	p.box(Vector3(0, -0.2, 0.12), Vector3(0.3, 0.26, 0.03), tunic)
	_attach(hips, p)

	var t := LowPoly.new()
	t.box(Vector3(0, 0.26, 0), Vector3(0.44, 0.44, 0.26), tunic)
	t.box(Vector3(0, 0.24, -0.02), Vector3(0.46, 0.36, 0.25), leather)  # 가죽 흉갑
	t.box(Vector3(0, 0.03, 0), Vector3(0.46, 0.07, 0.28), dark)  # 벨트
	t.box(Vector3(0, 0.03, -0.145), Vector3(0.09, 0.08, 0.02), gold)  # 버클
	t.box(Vector3(0.06, 0.28, -0.14), Vector3(0.05, 0.4, 0.02), dark)  # 어깨끈
	# 견갑
	t.sphere(Vector3(0.28, 0.46, 0), 0.13, steel, Vector3(1.1, 0.7, 1.1), 3, 6)
	t.sphere(Vector3(-0.28, 0.46, 0), 0.13, steel, Vector3(1.1, 0.7, 1.1), 3, 6)
	t.cylinder(Vector3(0, 0.46, 0), 0.08, 0.07, 0.08, 6, skin)  # 목
	_attach(torso, t)

	var h := LowPoly.new()
	h.sphere(Vector3(0, 0.16, 0), 0.17, skin, Vector3(0.95, 1.05, 1.0), 4, 7)
	# 머리카락: 위·뒤를 덮는 덩어리 + 앞머리
	h.sphere(Vector3(0, 0.22, 0.03), 0.18, hair, Vector3(1.02, 0.8, 1.02), 3, 7)
	h.box(Vector3(0.06, 0.27, -0.14), Vector3(0.16, 0.06, 0.06), hair, Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3.ZERO))
	h.box(Vector3(0, 0.12, 0.15), Vector3(0.22, 0.16, 0.05), hair)
	# 눈·눈썹·흉터
	h.box(Vector3(-0.065, 0.16, -0.158), Vector3(0.04, 0.05, 0.02), Color(0.12, 0.1, 0.1))
	h.box(Vector3(0.065, 0.16, -0.158), Vector3(0.04, 0.05, 0.02), Color(0.12, 0.1, 0.1))
	h.box(Vector3(-0.065, 0.205, -0.158), Vector3(0.06, 0.015, 0.02), hair)
	h.box(Vector3(0.065, 0.205, -0.158), Vector3(0.06, 0.015, 0.02), hair)
	h.box(Vector3(0.1, 0.12, -0.15), Vector3(0.012, 0.07, 0.02), Color(0.75, 0.45, 0.4))
	_attach(head, h)

	for side in [-1.0, 1.0]:
		var arm: Node3D = arm_l if side < 0 else arm_r
		var a := LowPoly.new()
		a.box(Vector3(0, -0.15, 0), Vector3(0.12, 0.3, 0.12), tunic)
		a.box(Vector3(0, -0.42, 0), Vector3(0.12, 0.26, 0.12), leather)
		a.box(Vector3(0, -0.4, 0), Vector3(0.135, 0.1, 0.135), steel)  # 팔목 보호대
		a.sphere(Vector3(0, -0.6, 0), 0.065, skin, Vector3.ONE, 3, 5)
		_attach(arm, a)

		var leg: Node3D = leg_l if side < 0 else leg_r
		var l := LowPoly.new()
		l.box(Vector3(0, -0.2, 0), Vector3(0.15, 0.4, 0.16), Color(0.3, 0.24, 0.2))
		l.box(Vector3(0, -0.6, 0), Vector3(0.16, 0.38, 0.18), dark)
		l.box(Vector3(0, -0.84, -0.05), Vector3(0.16, 0.1, 0.26), dark)
		l.box(Vector3(0, -0.43, -0.09), Vector3(0.12, 0.1, 0.03), steel)  # 무릎 보호대
		_attach(leg, l)

	# 붉은 망토 (등 뒤 피벗에서 아래로)
	cape = _pivot(torso, Vector3(0, 0.46, 0.14))
	var c := LowPoly.new()
	c.box(Vector3(0, -0.42, 0.02), Vector3(0.5, 0.84, 0.03), Color(0.68, 0.1, 0.1))
	c.box(Vector3(0, -0.85, 0.02), Vector3(0.5, 0.05, 0.035), gold)
	_attach(cape, c)

	# 장검 (손에서 앞쪽 -Z 로 뻗음)
	weapon = _pivot(arm_r, Vector3(0, -0.6, 0))
	var s := LowPoly.new()
	s.box(Vector3(0, 0, 0.06), Vector3(0.04, 0.04, 0.2), dark)  # 손잡이
	s.sphere(Vector3(0, 0, 0.17), 0.035, gold, Vector3.ONE, 2, 5)  # 폼멜
	s.box(Vector3(0, 0, -0.06), Vector3(0.26, 0.05, 0.05), gold)  # 가드
	s.box(Vector3(0, 0, -0.55), Vector3(0.07, 0.02, 0.9), steel)  # 칼날
	s.box(Vector3(0, 0, -0.55), Vector3(0.015, 0.03, 0.88), Color(0.6, 0.62, 0.68))  # 홈
	_attach(weapon, s)


# ---------------------------------------------------------------- 고블린 약탈자
# 작고 등이 굽은 초록 피부. 큰 귀, 노란 눈, 누더기 천, 가시 박힌 몽둥이.

func _build_goblin() -> void:
	var skin := Color(0.42, 0.6, 0.25)
	var rag := Color(0.42, 0.33, 0.22)
	var dark := Color(0.2, 0.16, 0.12)
	_skeleton(0.62, Vector3(0.22, 0.3, 0), 0.09, 0.36)
	torso.rotation.x = -0.25  # 구부정한 자세

	var p := LowPoly.new()
	p.box(Vector3(0, 0, 0), Vector3(0.28, 0.16, 0.2), rag)
	p.box(Vector3(0, -0.14, -0.1), Vector3(0.22, 0.2, 0.03), rag)
	_attach(hips, p)

	var t := LowPoly.new()
	t.sphere(Vector3(0, 0.18, 0), 0.2, skin, Vector3(1.0, 1.0, 0.8), 3, 6)
	t.box(Vector3(0, 0.1, 0), Vector3(0.36, 0.16, 0.26), rag)
	t.box(Vector3(0.1, 0.2, -0.13), Vector3(0.05, 0.3, 0.02), dark)
	_attach(torso, t)

	var h := LowPoly.new()
	h.sphere(Vector3(0, 0.14, -0.02), 0.17, skin, Vector3(1.1, 0.9, 1.0), 3, 6)
	h.cylinder(Vector3(0.14, 0.16, 0), 0.06, 0.0, 0.24, 4, skin, Transform3D(Basis(Vector3.BACK, -1.25), Vector3.ZERO))
	h.cylinder(Vector3(-0.14, 0.16, 0), 0.06, 0.0, 0.24, 4, skin, Transform3D(Basis(Vector3.BACK, 1.25), Vector3.ZERO))
	h.cylinder(Vector3(0, 0.11, -0.16), 0.04, 0.0, 0.1, 4, skin, Transform3D(Basis(Vector3.RIGHT, -1.4), Vector3.ZERO))  # 매부리코
	h.box(Vector3(-0.07, 0.18, -0.16), Vector3(0.06, 0.035, 0.02), Color(1.0, 0.85, 0.2))
	h.box(Vector3(0.07, 0.18, -0.16), Vector3(0.06, 0.035, 0.02), Color(1.0, 0.85, 0.2))
	h.box(Vector3(0, 0.05, -0.15), Vector3(0.14, 0.02, 0.02), dark)
	_attach(head, h)

	for side in [-1.0, 1.0]:
		var arm: Node3D = arm_l if side < 0 else arm_r
		var a := LowPoly.new()
		a.box(Vector3(0, -0.14, 0), Vector3(0.08, 0.28, 0.08), skin)
		a.box(Vector3(0, -0.36, 0), Vector3(0.08, 0.2, 0.08), skin)
		a.sphere(Vector3(0, -0.48, 0), 0.06, skin, Vector3.ONE, 2, 5)
		_attach(arm, a)
		var leg: Node3D = leg_l if side < 0 else leg_r
		var l := LowPoly.new()
		l.box(Vector3(0, -0.15, 0), Vector3(0.1, 0.3, 0.11), skin)
		l.box(Vector3(0, -0.42, 0), Vector3(0.1, 0.24, 0.11), skin)
		l.box(Vector3(0, -0.55, -0.06), Vector3(0.12, 0.07, 0.22), dark)
		_attach(leg, l)

	weapon = _pivot(arm_r, Vector3(0, -0.48, 0))
	var w := LowPoly.new()
	w.cylinder(Vector3.ZERO, 0.04, 0.09, 0.6, 5, Color(0.5, 0.34, 0.2), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.08)))
	for i in 4:
		var ang := TAU * i / 4.0
		w.box(Vector3(cos(ang) * 0.09, sin(ang) * 0.09, -0.42), Vector3(0.04, 0.04, 0.04), Color(0.7, 0.7, 0.72))
	_attach(weapon, w)


# ---------------------------------------------------------------- 바위 골렘 (봉화의 수호자)
# 봉화를 지키도록 만들어진 거대한 돌 거인. 이끼 덮인 어깨와 푸른 빛의 눈.

func _build_golem() -> void:
	var stone := Color(0.5, 0.5, 0.52)
	var stone_d := Color(0.38, 0.38, 0.4)
	var moss := Color(0.35, 0.52, 0.25)
	var glow := Color(0.4, 0.95, 1.0)
	_skeleton(1.1, Vector3(0.62, 0.62, 0), 0.24, 0.82)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	var p := LowPoly.new()
	p.sphere(Vector3(0, 0, 0), 0.38, stone_d, Vector3(1.2, 0.7, 0.9), 3, 6, Transform3D.IDENTITY, 0.12, rng)
	_attach(hips, p)

	var t := LowPoly.new()
	t.sphere(Vector3(0, 0.42, 0), 0.6, stone, Vector3(1.15, 0.9, 0.85), 3, 7, Transform3D.IDENTITY, 0.1, rng)
	t.sphere(Vector3(0.55, 0.72, 0.05), 0.28, moss, Vector3(1.0, 0.55, 1.0), 2, 6)
	t.sphere(Vector3(-0.55, 0.72, 0.05), 0.28, moss, Vector3(1.0, 0.55, 1.0), 2, 6)
	t.box(Vector3(0, 0.42, -0.5), Vector3(0.18, 0.18, 0.06), glow)  # 가슴의 룬
	_attach(torso, t)

	var h := LowPoly.new()
	h.box(Vector3(0, 0.16, -0.05), Vector3(0.42, 0.34, 0.4), stone_d)
	h.box(Vector3(-0.1, 0.18, -0.26), Vector3(0.1, 0.06, 0.02), glow)
	h.box(Vector3(0.1, 0.18, -0.26), Vector3(0.1, 0.06, 0.02), glow)
	h.box(Vector3(0, 0.36, -0.02), Vector3(0.46, 0.08, 0.42), moss)
	_attach(head, h)

	for side in [-1.0, 1.0]:
		var arm: Node3D = arm_l if side < 0 else arm_r
		var a := LowPoly.new()
		a.sphere(Vector3(0, -0.3, 0), 0.24, stone, Vector3(1, 1.4, 1), 3, 6, Transform3D.IDENTITY, 0.1, rng)
		a.sphere(Vector3(0, -0.85, 0), 0.22, stone_d, Vector3(1, 1.5, 1), 3, 6, Transform3D.IDENTITY, 0.1, rng)
		a.sphere(Vector3(0, -1.25, 0), 0.3, stone, Vector3(1.1, 1, 1.1), 3, 6, Transform3D.IDENTITY, 0.12, rng)  # 주먹
		_attach(arm, a)
		var leg: Node3D = leg_l if side < 0 else leg_r
		var l := LowPoly.new()
		l.sphere(Vector3(0, -0.3, 0), 0.24, stone_d, Vector3(1, 1.3, 1), 3, 6, Transform3D.IDENTITY, 0.1, rng)
		l.box(Vector3(0, -0.85, -0.05), Vector3(0.4, 0.34, 0.5), stone)
		_attach(leg, l)


# ---------------------------------------------------------------- 애니메이션

func play_attack(kind: int, length: float) -> void:
	_attack_kind = kind
	_attack_len = length
	_attack_t = 0.0


func flash() -> void:
	var tw := create_tween()
	var s := _base_scale
	tw.tween_property(self, "scale", Vector3.ONE * s * 1.12, 0.05)
	tw.tween_property(self, "scale", Vector3.ONE * s, 0.12)


## state: idle / move / air / glide / swim / dodge / dead
## speed_ratio: 0(정지)~1(최고 속도)
func animate(delta: float, state: String, speed_ratio: float, progress := 0.0) -> void:
	var k := 1.0 - exp(-14.0 * delta)
	var tl := 0.0  # 왼다리
	var tr := 0.0
	var al := 0.0  # 왼팔 앞뒤
	var ar := 0.0
	var al_z := 0.0  # 팔 벌리기
	var ar_z := 0.0
	var torso_x := -0.25 if style == "goblin" else 0.0
	var torso_y := 0.0
	var hip_y := _hip_height
	var cape_x := 0.0
	var cape_sx := 1.0
	var body_x := 0.0

	match state:
		"move":
			_phase += delta * lerpf(6.0, 11.0, speed_ratio)
			var sw := sin(_phase) * lerpf(0.35, 0.85, speed_ratio)
			tl = sw
			tr = -sw
			al = -sw * 0.8
			ar = sw * 0.8
			hip_y += absf(sin(_phase)) * 0.06 * speed_ratio
			torso_x += -0.12 * speed_ratio
			cape_x = -0.35 - 0.45 * speed_ratio + sin(_phase * 2.0) * 0.08
		"idle":
			_phase += delta * 2.0
			hip_y += sin(_phase) * 0.01
			al = 0.05
			ar = 0.1
			cape_x = -0.05 + sin(_phase * 0.7) * 0.03
		"air":
			tl = 0.5
			tr = -0.2
			al = -0.6
			ar = -0.4
			al_z = -0.4
			ar_z = 0.4
			cape_x = -0.9
		"glide":
			al_z = -1.35
			ar_z = 1.35
			tl = -0.25
			tr = -0.3
			torso_x = -0.35
			cape_x = -1.05
			cape_sx = 2.2
		"swim":
			_phase += delta * 5.0
			al = 2.6 + sin(_phase) * 0.6
			ar = 2.6 - sin(_phase) * 0.6
			tl = sin(_phase * 1.5) * 0.4
			tr = -tl
			torso_x = -0.9
			hip_y -= 0.3
			cape_x = -1.2
		"dodge":
			body_x = -TAU * progress
			hip_y -= 0.35 * sin(progress * PI)
			tl = 1.2
			tr = 1.2
			al = 1.0
			ar = 1.0
			cape_x = -0.5
		"dead":
			body_x = -1.45
			hip_y = 0.25
			al = 0.4
			ar = 0.2
			al_z = -0.6
			ar_z = 0.6

	# 공격 동작은 하체 움직임 위에 덮어쓴다
	var body_y := 0.0
	if _attack_t >= 0.0:
		_attack_t += delta
		var t := clampf(_attack_t / _attack_len, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)
		match _attack_kind:
			0:  # 내려베기
				ar = lerpf(2.7, 0.15, e) if t > 0.15 else 2.7 * (t / 0.15)
				torso_x += lerpf(-0.1, 0.25, e)
				al = -0.3
			1:  # 가로베기
				ar = 1.45
				ar_z = 0.2
				torso_y = lerpf(1.0, -1.0, e)
				al = -0.4
			2:  # 회전베기
				ar = 1.5
				ar_z = 1.2
				body_y = -TAU * e
				al_z = -1.0
			3:  # 양손 내려치기 (골렘·고블린 강공격)
				ar = lerpf(3.0, 0.3, e) if t > 0.3 else 3.0 * (t / 0.3)
				al = ar
				torso_x += lerpf(-0.3, 0.45, e)
		if _attack_t >= _attack_len:
			_attack_t = -1.0

	leg_l.rotation.x = lerpf(leg_l.rotation.x, tl, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, tr, k)
	var ka := 1.0 if _attack_t >= 0.0 else k
	arm_l.rotation.x = lerpf(arm_l.rotation.x, al, ka)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, ar, ka)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, al_z, ka)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, ar_z, ka)
	torso.rotation.x = lerpf(torso.rotation.x, torso_x, ka)
	torso.rotation.y = lerpf(torso.rotation.y, torso_y, ka)
	hips.position.y = lerpf(hips.position.y, hip_y, k)
	hips.rotation.y = body_y
	if state == "dodge":
		hips.rotation.x = body_x
	else:
		hips.rotation.x = lerp_angle(hips.rotation.x, body_x, k)
	if cape:
		cape.rotation.x = lerpf(cape.rotation.x, cape_x, k * 0.7)
		cape.scale.x = lerpf(cape.scale.x, cape_sx, k)
