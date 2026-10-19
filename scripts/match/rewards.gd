class_name Rewards
extends RefCounted
## What a finished match is worth: coins, newly earned achievements, and whether it
## completed today's daily challenge. Pure functions over a match summary (built by
## MatchController) and the save data, so they are easy to test.
##
## A summary has: mode, won, difficulty, round, champion, headshots, longest (m),
## damage_taken, max_combo, throws, special_used, practice_stars, fighter_id, map_id.

## Match modes (same values as MatchController.Mode; spelled out so tests can load this
## without compiling the controller).
const MODE_VS_AI := 0
const MODE_TOURNAMENT := 2
const MODE_PRACTICE := 3
const ACHIEVEMENT_COINS := 50
const DAILY_COINS := 150
## Win bonus by AI difficulty (Easy, Normal, Hard, Champion).
const DIFFICULTY_BONUS := [0, 20, 50, 80]

const ACHIEVEMENTS := [
	{"id": "first_win", "name": "First Blood", "desc": "Win a match."},
	{"id": "headhunter", "name": "Headhunter", "desc": "Land 3 headshots in one match."},
	{"id": "sniper", "name": "Sniper", "desc": "Hit someone from 80 m or more."},
	{"id": "flawless", "name": "Untouchable", "desc": "Win without losing any health."},
	{"id": "combo", "name": "On Fire", "desc": "Reach a x3 combo."},
	{"id": "champion", "name": "Champion", "desc": "Win a tournament."},
	{"id": "smasher", "name": "Wrecking Crew", "desc": "Smash 10 obstacles."},
	{"id": "collector", "name": "Supply Run", "desc": "Collect 10 crates."},
	{"id": "specials", "name": "Show-off", "desc": "Use 10 specials."},
	{"id": "practice", "name": "Sharpshooter", "desc": "Score 25+ stars in Target Practice."},
	{"id": "globetrotter", "name": "Globetrotter", "desc": "Win on all 6 maps."},
	{"id": "roster", "name": "Full Roster", "desc": "Unlock every fighter."},
]

## Daily challenge twists: [id, text].
const TWISTS := [
	["win", "Win"],
	["headshots", "Win with 2+ headshots"],
	["no_special", "Win without using your special"],
	["healthy", "Win with 70+ health left"],
	["quick", "Win in 6 throws or fewer"],
]


## Coins for each level gained.
const LEVEL_UP_COINS := 100


## XP for a match: more for winning and for harder AI; practice by stars.
static func xp_for(summary: Dictionary) -> int:
	match summary["mode"]:
		MODE_VS_AI, MODE_TOURNAMENT:
			return (40 + 10 * int(summary.get("difficulty", 0))) if summary["won"] else 15
		MODE_PRACTICE:
			return int(summary.get("practice_stars", 0)) * 3
	return 0


static func coins_for(summary: Dictionary) -> int:
	var headshot_bonus: int = summary.get("headshots", 0) * 5
	match summary["mode"]:
		MODE_VS_AI:
			if summary["won"]:
				return 50 + DIFFICULTY_BONUS[summary["difficulty"]] + headshot_bonus
			return 10 + headshot_bonus
		MODE_TOURNAMENT:
			if summary["won"]:
				return 40 + int(summary["round"]) * 30 + (300 if summary.get("champion", false) else 0) + headshot_bonus
			return 10 + headshot_bonus
		MODE_PRACTICE:
			return int(summary.get("practice_stars", 0)) * 3
	return 0


## Ids of achievements this summary (plus running totals in `save`) has just earned.
## roster_size is how many fighters exist, for Full Roster.
static func new_achievements(summary: Dictionary, save: Node, roster_size: int) -> Array[String]:
	var earned: Array[String] = []
	var won: bool = summary.get("won", false)
	var counters: Dictionary = save.counters
	var checks := {
		"first_win": won,
		"headhunter": int(summary.get("headshots", 0)) >= 3,
		"sniper": float(summary.get("longest", 0.0)) >= 80.0,
		"flawless": won and int(summary.get("damage_taken", 1)) == 0,
		"combo": int(summary.get("max_combo", 0)) >= 3,
		"champion": summary.get("champion", false),
		"smasher": int(counters.get("smashed", 0)) >= 10,
		"collector": int(counters.get("crates", 0)) >= 10,
		"specials": int(counters.get("specials", 0)) >= 10,
		"practice": int(summary.get("practice_stars", 0)) >= 25,
		"globetrotter": (counters.get("maps_won", []) as Array).size() >= 6,
		"roster": save.unlocked.size() >= roster_size,
	}
	for achievement: Dictionary in ACHIEVEMENTS:
		var id: String = achievement["id"]
		if checks.get(id, false) and not save.achievements.has(id):
			earned.append(id)
	return earned


static func achievement(id: String) -> Dictionary:
	for entry: Dictionary in ACHIEVEMENTS:
		if entry["id"] == id:
			return entry
	return {"id": id, "name": id, "desc": ""}


static func today() -> String:
	return Time.get_date_string_from_system()


## Today's challenge, the same for everyone on the same date: a fighter (maybe one
## you haven't unlocked yet), a map, an AI difficulty and a twist.
static func daily(date: String, roster: Array[FighterData], maps: Array[MapData]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var fighter := roster[rng.randi_range(0, roster.size() - 1)]
	var map := maps[rng.randi_range(0, maps.size() - 1)]
	var difficulty := AiAimer.Difficulty.NORMAL if rng.randf() < 0.6 else AiAimer.Difficulty.HARD
	var twist: Array = TWISTS[rng.randi_range(0, TWISTS.size() - 1)]
	return {
		"date": date,
		"fighter": fighter,
		"map": map,
		"difficulty": difficulty,
		"twist": twist[0],
		"text": "%s as %s on %s (%s AI)" % [twist[1], fighter.short_name, map.display_name, "Hard" if difficulty == AiAimer.Difficulty.HARD else "Normal"],
	}


static func daily_met(challenge: Dictionary, summary: Dictionary) -> bool:
	if not summary.get("won", false) or summary.get("fighter_id", "") != String(challenge["fighter"].id):
		return false
	match challenge["twist"]:
		"headshots":
			return int(summary.get("headshots", 0)) >= 2
		"no_special":
			return not summary.get("special_used", false)
		"healthy":
			return int(summary.get("health_left", 0)) >= 70
		"quick":
			return int(summary.get("throws", 99)) <= 6
	return true
