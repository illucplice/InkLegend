class_name AiAimer
extends RefCounted
## Computer aim: solves the perfect throw, then adds mistakes that shrink every turn.

enum Difficulty { EASY, NORMAL, HARD }

## angle_error is in degrees and power_error a fraction of power (standard deviations on
## the first throw). Each turn they are multiplied by sharpen, down to min_scale.
const SETTINGS := {
	Difficulty.EASY: {"angle_error": 8.0, "power_error": 0.20, "sharpen": 0.85, "min_scale": 0.45, "head_chance": 0.0},
	Difficulty.NORMAL: {"angle_error": 6.0, "power_error": 0.13, "sharpen": 0.75, "min_scale": 0.3, "head_chance": 0.15},
	Difficulty.HARD: {"angle_error": 4.0, "power_error": 0.08, "sharpen": 0.6, "min_scale": 0.15, "head_chance": 0.35},
}
## Angles to try when the first choice can't reach the target.
const FALLBACK_ANGLES := [45.0, 40.0, 50.0, 35.0, 55.0, 30.0, 60.0, 65.0, 70.0, 75.0, 80.0]

var difficulty: int
var turns_taken := 0
var rng := RandomNumberGenerator.new()


func _init(level: int = Difficulty.NORMAL, seed_value: int = -1) -> void:
	difficulty = level
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## The throw that lands exactly on target, as {"angle", "power"}. If nothing can reach,
## returns a full-power 45° throw.
static func solve(origin: Vector2, target: Vector2, max_speed: float, facing: int, first_angle: float = 45.0) -> Dictionary:
	var dx := (target.x - origin.x) * facing
	var dy := origin.y - target.y
	var angles: Array = [first_angle]
	angles.append_array(FALLBACK_ANGLES)
	for angle: float in angles:
		var speed := Rules.solve_speed(dx, dy, angle)
		if speed > 0.0 and speed <= max_speed:
			return {"angle": angle, "power": speed / max_speed}
	return {"angle": 45.0, "power": 1.0}


func wants_headshot() -> bool:
	return rng.randf() < float(SETTINGS[difficulty]["head_chance"])


func aim(origin: Vector2, target: Vector2, max_speed: float, facing: int) -> Dictionary:
	var settings: Dictionary = SETTINGS[difficulty]
	var perfect := solve(origin, target, max_speed, facing, rng.randf_range(38.0, 55.0))
	var error_scale := maxf(pow(float(settings["sharpen"]), turns_taken), float(settings["min_scale"]))
	turns_taken += 1
	var angle: float = perfect["angle"] + rng.randfn(0.0, float(settings["angle_error"]) * error_scale)
	var power: float = perfect["power"] * (1.0 + rng.randfn(0.0, float(settings["power_error"]) * error_scale))
	return {
		"angle": clampf(angle, Rules.MIN_ANGLE, Rules.MAX_ANGLE),
		"power": clampf(power, 0.05, 1.0),
	}
