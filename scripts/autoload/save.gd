extends Node
## Everything kept on the player's device: settings in user://settings.cfg and
## progress (coins, unlocks, cosmetics, stats, achievements, a tournament in
## progress, the daily challenge) in user://progress.cfg.

const PATH := "user://settings.cfg"
const PROGRESS_PATH := "user://progress.cfg"
const STARTING_FIGHTERS := ["quotuk", "klakla"]

## Ink colours for your stickman and trail colours for your throws: id -> [name, colour, price].
const INKS := {
	"black": ["Classic ink", Color(0.06, 0.055, 0.07), 0],
	"navy": ["Navy", Color(0.1, 0.15, 0.36), 120],
	"crimson": ["Crimson", Color(0.45, 0.06, 0.1), 120],
	"forest": ["Forest", Color(0.07, 0.28, 0.14), 120],
	"violet": ["Violet", Color(0.3, 0.1, 0.42), 120],
}
const TRAILS := {
	"white": ["Cloud", Color(1, 1, 1), 0],
	"gold": ["Gold", Color(1.0, 0.8, 0.3), 80],
	"fire": ["Fire", Color(1.0, 0.45, 0.2), 80],
	"ice": ["Ice", Color(0.5, 0.85, 1.0), 80],
	"candy": ["Candy", Color(1.0, 0.5, 0.85), 80],
}

# Settings
var sound_on := true
var volume := 0.8
var screen_shake := true
var long_aim_guide := false
var show_hints := true
var music_on := true
var music_volume := 0.6

# Progress
var coins := 0
var unlocked: Array = STARTING_FIGHTERS.duplicate()
var owned_inks: Array = ["black"]
var ink := "black"
var owned_trails: Array = ["white"]
var trail := "white"
## fighter id -> {matches, wins, headshots, longest, damage}
var fighter_stats := {}
var achievements: Array = []
## Running totals for achievements: smashed, crates, specials, and maps_won (ids).
var counters := {"smashed": 0, "crates": 0, "specials": 0, "maps_won": []}
## A tournament in progress (see MatchController.start_tournament), or empty.
var tournament := {}
## The date (YYYY-MM-DD) of the last daily challenge completed.
var daily_done := ""

## Where progress is saved; tests point this somewhere else.
var progress_path := PROGRESS_PATH


func _ready() -> void:
	load_settings()
	apply()
	load_progress()


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


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(progress_path) != OK:
		return
	coins = config.get_value("progress", "coins", coins)
	unlocked = config.get_value("progress", "unlocked", unlocked)
	owned_inks = config.get_value("progress", "owned_inks", owned_inks)
	ink = config.get_value("progress", "ink", ink)
	owned_trails = config.get_value("progress", "owned_trails", owned_trails)
	trail = config.get_value("progress", "trail", trail)
	fighter_stats = config.get_value("progress", "fighter_stats", fighter_stats)
	achievements = config.get_value("progress", "achievements", achievements)
	counters = config.get_value("progress", "counters", counters)
	tournament = config.get_value("progress", "tournament", tournament)
	daily_done = config.get_value("progress", "daily_done", daily_done)


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "owned_inks", owned_inks)
	config.set_value("progress", "ink", ink)
	config.set_value("progress", "owned_trails", owned_trails)
	config.set_value("progress", "trail", trail)
	config.set_value("progress", "fighter_stats", fighter_stats)
	config.set_value("progress", "achievements", achievements)
	config.set_value("progress", "counters", counters)
	config.set_value("progress", "tournament", tournament)
	config.set_value("progress", "daily_done", daily_done)
	config.save(progress_path)


## Wipes progress back to a fresh start (settings are kept).
func reset_progress() -> void:
	coins = 0
	unlocked = STARTING_FIGHTERS.duplicate()
	owned_inks = ["black"]
	ink = "black"
	owned_trails = ["white"]
	trail = "white"
	fighter_stats = {}
	achievements = []
	counters = {"smashed": 0, "crates": 0, "specials": 0, "maps_won": []}
	tournament = {}
	daily_done = ""


func is_unlocked(fighter: FighterData) -> bool:
	return fighter.unlocked_by_default or unlocked.has(String(fighter.id))


## Spends coins to unlock a fighter. Returns false if it can't be afforded.
func buy_fighter(fighter: FighterData) -> bool:
	if is_unlocked(fighter) or coins < fighter.price:
		return false
	coins -= fighter.price
	unlocked.append(String(fighter.id))
	save_progress()
	return true


## Equips a cosmetic, buying it first if needed. kind is "ink" or "trail".
func choose_cosmetic(kind: String, id: String) -> bool:
	var table: Dictionary = INKS if kind == "ink" else TRAILS
	var owned: Array = owned_inks if kind == "ink" else owned_trails
	if not owned.has(id):
		var price: int = table[id][2]
		if coins < price:
			return false
		coins -= price
		owned.append(id)
	if kind == "ink":
		ink = id
	else:
		trail = id
	save_progress()
	return true


func ink_color() -> Color:
	return INKS.get(ink, INKS["black"])[1]


func trail_color() -> Color:
	return TRAILS.get(trail, TRAILS["white"])[1]


func stats_for(fighter_id: String) -> Dictionary:
	if not fighter_stats.has(fighter_id):
		fighter_stats[fighter_id] = {"matches": 0, "wins": 0, "headshots": 0, "longest": 0.0, "damage": 0}
	return fighter_stats[fighter_id]
