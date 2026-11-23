extends Node
## 외부 오디오 에셋 없이 코드로 합성한 짧은 효과음 (코인/클릭/레벨업/이탈).
## 설정의 "효과음"이 꺼져 있으면 재생하지 않는다. 배경 음악은 TODO.

const RATE := 22050

var streams: Dictionary = {}
var players: Array = []
var _next: int = 0


func _ready() -> void:
	streams["coin"] = _tone([1320.0, 1760.0], 0.07, 0.25)
	streams["click"] = _tone([660.0], 0.04, 0.18)
	streams["levelup"] = _tone([523.0, 659.0, 784.0, 1046.0], 0.08, 0.25)
	streams["bad"] = _tone([300.0, 220.0], 0.09, 0.2)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(id: String) -> void:
	if not bool(GameManager.state.settings.get("sound", true)) or not streams.has(id):
		return
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[id]
	p.play()


func _tone(freqs: Array, note_len: float, volume: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var n := int(RATE * note_len)
	for f in freqs:
		for i in n:
			var t := float(i) / RATE
			var env := 1.0 - float(i) / n
			var v := sin(TAU * float(f) * t) * env * volume
			var s := int(clampf(v, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
