class_name Mastery
extends RefCounted
## Fighter mastery: every match you play with a fighter earns them mastery XP, and each
## level unlocks something for that fighter: more coins, new colour schemes, a
## signature trail and, at the top, a golden Master aura. Pure functions over a match
## summary and plain numbers, like Rewards, so they are easy to test.

## XP needed to reach each level (index = level).
const LEVELS := [0, 100, 250, 450, 700, 1000]
const MAX_LEVEL := 5
## Level 1 on: this much more coin from every match with the fighter.
const COIN_BONUS := 0.1
## What each level unlocks, as shown on screen.
const REWARDS := ["", "+10% coins", "New colours", "Signature trail", "More colours", "Master aura + gold"]


## The level for this much XP.
static func level(xp: int) -> int:
	var reached := 0
	for i in LEVELS.size():
		if xp >= int(LEVELS[i]):
			reached = i
	return reached


## XP for the level after `current_level` (or the top level's, once maxed).
static func next_threshold(current_level: int) -> int:
	return int(LEVELS[mini(current_level + 1, MAX_LEVEL)])


## Mastery XP a match earns: more for winning and for harder AI, a big bonus for
## clearing an arcade or winning a tournament, a little for landing the fatality.
static func xp_for(summary: Dictionary) -> int:
	if summary.get("mode", 0) == Rewards.MODE_PRACTICE:
		return 0
	var xp := 10
	if summary.get("won", false):
		xp = 30 + 10 * int(summary.get("difficulty", 0))
	if summary.get("champion", false):
		xp += 100 if summary.get("kind", "tournament") == "arcade" else 150
	if summary.get("fatality", false):
		xp += 10
	return xp


## How many colour schemes a fighter at `mastery_level` can wear (the first is their own).
static func skin_count(mastery_level: int) -> int:
	var count := 1
	for unlock in [2, 4, 5]:
		if mastery_level >= unlock:
			count += 1
	return count


const SKIN_NAMES := ["Classic", "Alternate", "Shadow", "Gold"]


## A fighter wearing colour scheme `skin` (0 is their own colours). Only their own
## colours change (outfit, cape, hair), never their weapon or kit.
static func skinned(data: FighterData, skin: int) -> FighterData:
	if skin <= 0 or data == null:
		return data
	var worn := data.duplicate() as FighterData
	match skin:
		1:
			worn.body_color = _hue_shift(data.body_color, 0.42)
			worn.cape_color = _hue_shift(data.cape_color, 0.42)
			worn.accent_color = _hue_shift(data.accent_color, 0.42)
			worn.hair_color = _hue_shift(data.hair_color, 0.3)
		2:
			worn.body_color = data.body_color.darkened(0.55)
			worn.cape_color = Color(0.25, 0.1, 0.35)
			worn.accent_color = Color(0.7, 0.35, 0.95)
			worn.hair_color = data.hair_color.darkened(0.6)
		_:
			worn.body_color = Color(1.0, 0.78, 0.25)
			worn.cape_color = Color(0.6, 0.42, 0.1)
			worn.accent_color = Color(0.45, 0.3, 0.08)
			worn.hair_color = Color(1.0, 0.9, 0.55)
	return worn


## The trail a level-3 master leaves behind: the fighter's own colour.
static func trail_color(data: FighterData) -> Color:
	return data.body_color.lightened(0.25)


static func _hue_shift(color: Color, amount: float) -> Color:
	return Color.from_hsv(fposmod(color.h + amount, 1.0), color.s, color.v, color.a)
