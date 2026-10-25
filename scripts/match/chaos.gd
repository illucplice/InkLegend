class_name Chaos
extends RefCounted
## Chaos mutators: one twist on the rules for a whole match. Pure data and helpers;
## MatchController applies them as the match is set up and each turn begins.

## id -> [name, what it does].
const MUTATORS := {
	&"low_gravity": ["Low Gravity", "Everything floats: throws fly far and slow."],
	&"giant": ["Giant Weapons", "Every weapon is huge."],
	&"storm": ["Storm", "The wind blows three times as hard."],
	&"sudden_death": ["Sudden Death", "Everyone starts on 30 health."],
	&"overcharged": ["Overcharged", "Specials refill every turn."],
	&"bouncy": ["Bouncy", "Every throw bounces once."],
	&"glass_cannon": ["Glass Cannon", "Every hit does double damage."],
}
const SUDDEN_DEATH_HEALTH := 30
const LOW_GRAVITY := 0.55
const GIANT_SIZE := 1.9
const STORM_WIND := 3.0


static func pick(rng: RandomNumberGenerator) -> StringName:
	var ids := MUTATORS.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]


static func display_name(id: StringName) -> String:
	return String(MUTATORS.get(id, ["", ""])[0])


static func description(id: StringName) -> String:
	return String(MUTATORS.get(id, ["", ""])[1])


## A fighter as the mutator has them: the weapon changed for Low Gravity, Giant
## Weapons and Glass Cannon; anything else leaves them as they are.
static func mutate(data: FighterData, id: StringName) -> FighterData:
	if not id in [&"low_gravity", &"giant", &"glass_cannon"]:
		return data
	var changed := data.duplicate() as FighterData
	var weapon := data.weapon.duplicate() as WeaponData
	match id:
		&"low_gravity":
			weapon.gravity_scale *= LOW_GRAVITY
		&"giant":
			weapon.size *= GIANT_SIZE
		&"glass_cannon":
			weapon.body_damage *= 2
			weapon.head_damage *= 2
	changed.weapon = weapon
	return changed
