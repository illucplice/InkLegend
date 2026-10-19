extends Node
## Player settings, stored on the device in user://settings.cfg.
## Phase 4 adds progress (coins, unlocks, stats) here too.

const PATH := "user://settings.cfg"

var sound_on := true
var volume := 0.8
var screen_shake := true
var long_aim_guide := false
var show_hints := true
var music_on := true
var music_volume := 0.6


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	sound_on = config.get_value("audio", "sound_on", sound_on)
	volume = config.get_value("audio", "volume", volume)
	screen_shake = config.get_value("game", "screen_shake", screen_shake)
	long_aim_guide = config.get_value("game", "long_aim_guide", long_aim_guide)
	show_hints = config.get_value("game", "show_hints", show_hints)
	music_on = config.get_value("audio", "music_on", music_on)
	music_volume = config.get_value("audio", "music_volume", music_volume)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sound_on", sound_on)
	config.set_value("audio", "volume", volume)
	config.set_value("game", "screen_shake", screen_shake)
	config.set_value("game", "long_aim_guide", long_aim_guide)
	config.set_value("game", "show_hints", show_hints)
	config.set_value("audio", "music_on", music_on)
	config.set_value("audio", "music_volume", music_volume)
	config.save(PATH)


func apply() -> void:
	Audio.muted = not sound_on
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	Audio.music_on = music_on
	Audio.music_volume = music_volume
	Audio.apply_music_settings()
