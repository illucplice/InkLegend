class_name AiAimer
extends RefCounted
## Computer aim: finds a throw that lands on target without hitting an obstacle,
## then adds mistakes that shrink every turn.

## CHAMPION is only used for the tournament boss.
enum Difficulty { EASY, NORMAL, HARD, CHAMPION }

## angle_error is in degrees and power_error a fraction of power (standard deviations on
## the first throw). Each turn they are multiplied by sharpen, down to min_scale.
const SETTINGS := {
	Difficulty.EASY: {"angle_error": 6.0, "power_error": 0.16, "sharpen": 0.85, "min_scale": 0.45, "head_chance": 0.0},
	Difficulty.NORMAL: {"angle_error": 4.0, "power_error": 0.1, "sharpen": 0.75, "min_scale": 0.3, "head_chance": 0.15},
	Difficulty.HARD: {"angle_error": 2.5, "power_error": 0.06, "sharpen": 0.6, "min_scale": 0.15, "head_chance": 0.35},
	Difficulty.CHAMPION: {"angle_error": 1.6, "power_error": 0.04, "sharpen": 0.5, "min_scale": 0.08, "head_chance": 0.5},
}
const MIN_SEARCH_ANGLE := 12.0
const MAX_SEARCH_ANGLE := 80.0
## Simulation step and safety margin for the obstacle check.
const PATH_STEP := 1.0 / 240.0
const PATH_MARGIN := 6.0

var difficulty: int
var turns_taken := 0
var rng := RandomNumberGenerator.new()


func _init(level: int = Difficulty.NORMAL, seed_value: int = -1) -> void:
	difficulty = level
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## The throw that lands exactly on target, as {"angle", "power", "clear"}. Angles are
## tried outward from first_angle; the first reachable one with a clear path wins.
## "clear" is false when every reachable throw hits an obstacle (or nothing reaches).
static func solve(origin: Vector2, target: Vector2, max_speed: float, facing: int, first_angle: float = 45.0, obstacles: Array[Rect2] = []) -> Dictionary:
	var dx := (target.x - origin.x) * facing
	var dy := origin.y - target.y
	var blocked := {}
	for step in int(MAX_SEARCH_ANGLE - MIN_SEARCH_ANGLE) * 2 + 1:
		var offset := ceilf(step / 2.0) * (1.0 if step % 2 else -1.0)
		var angle := first_angle + offset
		if angle < MIN_SEARCH_ANGLE or angle > MAX_SEARCH_ANGLE:
			continue
		var speed := Rules.solve_speed(dx, dy, angle)
		if speed <= 0.0 or speed > max_speed:
			continue
		var shot := {"angle": angle, "power": speed / max_speed, "clear": true}
		var velocity := Rules.launch_velocity(angle, 1.0, speed, facing)
		if path_is_clear(origin, velocity, target, obstacles):
			return shot
		if blocked.is_empty():
			blocked = shot
	if not blocked.is_empty():
		blocked["clear"] = false
		return blocked
	return {"angle": 45.0, "power": 1.0, "clear": false}


## True if a throw reaches target's x without passing through any obstacle.
static func path_is_clear(origin: Vector2, velocity: Vector2, target: Vector2, obstacles: Array[Rect2]) -> bool:
	if obstacles.is_empty():
		return true
	var direction := signf(velocity.x)
	var t := 0.0
	while t < 8.0:
		var point := Rules.position_at(origin, velocity, t)
		if (point.x - target.x) * direction >= 0.0:
			return true
		for box in obstacles:
			if box.grow(PATH_MARGIN).has_point(point):
				return false
		t += PATH_STEP
	return false


func wants_headshot() -> bool:
	return rng.randf() < float(SETTINGS[difficulty]["head_chance"])


func aim(origin: Vector2, target: Vector2, max_speed: float, facing: int, obstacles: Array[Rect2] = []) -> Dictionary:
	var settings: Dictionary = SETTINGS[difficulty]
	var perfect := solve(origin, target, max_speed, facing, rng.randf_range(35.0, 58.0), obstacles)
	var error_scale := maxf(pow(float(settings["sharpen"]), turns_taken), float(settings["min_scale"]))
	turns_taken += 1
	var angle: float = perfect["angle"] + rng.randfn(0.0, float(settings["angle_error"]) * error_scale)
	var power: float = perfect["power"] * (1.0 + rng.randfn(0.0, float(settings["power_error"]) * error_scale))
	return {
		"angle": clampf(angle, Rules.MIN_ANGLE, Rules.MAX_ANGLE),
		"power": clampf(power, 0.05, 1.0),
	}
