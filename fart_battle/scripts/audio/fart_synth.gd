extends Node
## Sfx (Autoload) — 외부 오디오 파일 없이 코드로 합성한 방귀/효과음.
## 방귀: 낮은 주파수 버즈 + 떨림(진폭 변조) + 잡음, 세기에 따라 길이·음높이가 달라진다.

const RATE := 22050

var sounds: Dictionary = {}
var players: Array = []
var _next: int = 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 42
	sounds["tiny"] = [_fart(0.18, 210.0, 0.55, 0.1), _fart(0.14, 260.0, 0.5, 0.05)]
	sounds["medium"] = [_fart(0.45, 120.0, 0.7, 0.25), _fart(0.5, 140.0, 0.7, 0.3)]
	sounds["big"] = [_fart(0.85, 85.0, 0.85, 0.4), _fart(0.95, 95.0, 0.85, 0.35)]
	sounds["mega"] = [_fart(1.4, 62.0, 1.0, 0.5), _fart(1.5, 70.0, 1.0, 0.55)]
	sounds["squeak"] = [_squeak()]
	sounds["block"] = [_tone([300.0, 450.0], 0.07, 0.3)]
	sounds["parry"] = [_tone([600.0, 900.0, 1200.0], 0.06, 0.3)]
	sounds["eat"] = [_tone([520.0, 660.0], 0.06, 0.25)]
	sounds["bad"] = [_tone([260.0, 180.0], 0.12, 0.3)]
	sounds["win"] = [_tone([523.0, 659.0, 784.0, 1046.0], 0.1, 0.3)]
	sounds["lose"] = [_tone([392.0, 330.0, 262.0], 0.16, 0.3)]
	sounds["click"] = [_tone([700.0], 0.04, 0.2)]
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(id: String, pitch: float = 1.0) -> void:
	if not Save.sound or not sounds.has(id) or players.is_empty():
		return
	var list: Array = sounds[id]
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = list[rng.randi() % list.size()]
	p.pitch_scale = pitch * rng.randf_range(0.92, 1.08)
	p.play()


func play_fart(size: String) -> void:
	play(size if sounds.has(size) else "medium")


func _fart(dur: float, f0: float, vol: float, noise_amt: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var flutter_rate := rng.randf_range(14.0, 26.0)
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		# 음높이: 살짝 떨리며 내려감
		var f := f0 * (1.0 - 0.35 * k) * (1.0 + 0.08 * sin(TAU * 5.0 * t)) * (1.0 + rng.randf_range(-0.04, 0.04))
		phase += TAU * f / RATE
		# 버즈(사각파에 가까운 파형)
		var buzz := clampf(sin(phase) * 2.5, -1.0, 1.0) * 0.7 + sin(phase * 2.0) * 0.2
		# 떨림 (뿌르르)
		var am := 0.55 + 0.45 * sin(TAU * flutter_rate * t + sin(TAU * 3.0 * t))
		# 잡음 (저역 통과)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.15
		var env := minf(1.0, t / 0.02) * pow(1.0 - k, 0.6)
		var v := (buzz * am * (1.0 - noise_amt) + lp * noise_amt * 2.0) * env * vol * 0.6
		var s := int(clampf(v, -1.0, 1.0) * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav(data)


func _squeak() -> AudioStreamWAV:
	var dur := 0.5
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 900.0 - 700.0 * (t / dur)
		phase += TAU * f / RATE
		var v := sin(phase) * (1.0 - t / dur) * 0.35
		var s := int(v * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav(data)


func _tone(freqs: Array, note_len: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var n := int(RATE * note_len)
	for f in freqs:
		for i in n:
			var t := float(i) / RATE
			var v := sin(TAU * float(f) * t) * (1.0 - float(i) / n) * vol
			var s := int(clampf(v, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
