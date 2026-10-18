extends Node
## Plays sound effects from a small pool of players. Use: Audio.play("hit_head").
## Browsers only allow sound after the first tap; Godot's web export resumes it then.

const SOUNDS := ["whoosh", "sling", "twang", "hit_body", "hit_head", "tick", "thunk", "ground", "ko", "win", "lose", "turn", "click"]
const POOL_SIZE := 10

var muted := false

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
