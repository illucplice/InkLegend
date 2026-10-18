class_name Rules
extends RefCounted
## Game rules and the throw maths. Projectiles, the aim preview and the AI all use
## these same functions, so the AI's aim is honest.

const MAX_HEALTH := 100
const PX_PER_M := 20.0
## Downward acceleration in px/s². Lower = floatier, slower throws (weapon speeds are
## scaled with sqrt(GRAVITY) so every throw still reaches the same distance).
const GRAVITY := 560.0
const MIN_DISTANCE_M := 65.0
const MAX_DISTANCE_M := 85.0
const MIN_ANGLE := 5.0
const MAX_ANGLE := 85.0


static func damage_for(weapon: WeaponData, is_head: bool) -> int:
	return weapon.head_damage if is_head else weapon.body_damage


static func random_distance_px(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(MIN_DISTANCE_M, MAX_DISTANCE_M) * PX_PER_M


## Angle is degrees above horizontal, towards the way the thrower faces (1 or -1).
static func launch_velocity(angle_deg: float, power: float, max_speed: float, facing: int) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return Vector2(cos(a) * facing, -sin(a)) * clampf(power, 0.0, 1.0) * max_speed


## Where a projectile is t seconds after launch. Exact, so it doesn't drift with frame rate.
static func position_at(origin: Vector2, velocity: Vector2, t: float) -> Vector2:
	return origin + velocity * t + Vector2(0.0, 0.5 * GRAVITY * t * t)


## Launch speed needed to pass through a point dx px ahead and dy px above (up is positive)
## at the given angle. Returns -1 when that angle can't reach it.
static func solve_speed(dx: float, dy: float, angle_deg: float) -> float:
	var a := deg_to_rad(angle_deg)
	var denom := 2.0 * cos(a) * cos(a) * (dx * tan(a) - dy)
	if dx <= 0.0 or denom <= 0.0:
		return -1.0
	return sqrt(GRAVITY * dx * dx / denom)
