extends Node
## Plays sound effects from a small pool of players. Use: Audio.play("hit_head").
## Browsers only allow sound after the first tap; Godot's web export resumes it then.

const SOUNDS := ["whoosh", "sling", "twang", "hit_body", "hit_head", "tick", "thunk", "ground", "ko", "win", "lose", "turn", "click", "splat", "gore", "gush", "slice", "crunch", "punch", "cheer", "clang", "zap", "boom", "voice_hurt", "voice_die", "voice_charge", "voice_laugh"]
const POOL_SIZE := 10

var muted := false
var music_on := true
## 0..1, on top of the master volume.
var music_volume := 0.6

var _music: AudioStreamPlayer
var _music_name := ""

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name: String in SOUNDS:
		var path := "res://audio/sfx/%s.wav" % sound_name
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	add_child(_music)


## pitch_jitter randomly shifts the pitch a little so repeated sounds don't feel robotic.
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.06) -> void:
	if muted or not _streams.has(sound_name):
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


## Starts a looping track from res://audio/music/ ("menu" or "battle"), fading
## from whatever was playing. Does nothing if that track is already on.
func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var path := "res://audio/music/%s.wav" % track
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var fade := create_tween()
	if _music.playing:
		fade.tween_property(_music, "volume_db", -40.0, 0.4)
	fade.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	fade.tween_property(_music, "volume_db", _music_db(), 0.6)


func apply_music_settings() -> void:
	if _music != null:
		_music.volume_db = _music_db()


func _music_db() -> float:
	if not music_on or muted:
		return -80.0
	return linear_to_db(maxf(music_volume, 0.001)) - 6.0
