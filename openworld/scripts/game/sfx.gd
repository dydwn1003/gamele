extends Node
## 효과음·배경음악 재생 (자동 로드: Sfx). 메뉴로 게임이 멈춰도 소리는 계속 난다.

const SOUNDS := ["swing", "dodge", "hit", "crit", "hurt", "enemy_die", "smash", "pickup", "coin",
	"potion", "equip", "anvil", "ui_click", "ui_open", "error", "chest", "levelup", "quest",
	"quest_done", "beacon"]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		var path := "res://audio/%s.wav" % s
		if ResourceLoader.exists(path):
			_streams[s] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(func() -> void: _music.play())


func _db(v: float) -> float:
	return linear_to_db(clampf(v, 0.0001, 1.0))


func play(name: String, pitch_jitter := 0.06) -> void:
	if not _streams.has(name):
		return
	var vol := float(GameState.settings.get("sfx", 0.9))
	if vol <= 0.01:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = _db(vol)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(name: String) -> void:
	if name == _music_name and _music.playing:
		return
	_music_name = name
	var path := "res://audio/music_%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	_music.stream = load(path)
	update_volume()
	_music.play()


func update_volume() -> void:
	_music.volume_db = _db(float(GameState.settings.get("music", 0.7)) * 0.6)
