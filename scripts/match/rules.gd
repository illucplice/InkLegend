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

## Wind is a sideways push in px/s². A new wind is rolled each turn.
const MAX_WIND := 70.0
## Legs take this share of body damage.
const LEG_MULTIPLIER := 0.7
## Sky Shot: a hit after this long in the air (a big lob) gets bonus damage.
const SKY_SHOT_TIME := 2.4
const SKY_SHOT_BONUS := 0.15
## Hitting on consecutive turns stacks this bonus per turn, up to COMBO_MAX.
const COMBO_BONUS := 0.1
const COMBO_MAX := 0.3

## Hit zones on a fighter.
const HEAD := &"head"
const BODY := &"body"
const LEGS := &"legs"


## Base damage for a hit on a part, before bonuses.
static func damage_for(weapon: WeaponData, part: StringName) -> int:
	match part:
		HEAD:
			return weapon.head_damage
		LEGS:
			return roundi(weapon.body_damage * LEG_MULTIPLIER)
	return weapon.body_damage


## Base damage with the Sky Shot and combo bonuses applied.
static func damage_with_bonuses(weapon: WeaponData, part: StringName, flight_time: float, combo: int) -> int:
	var bonus := 0.0
	if flight_time >= SKY_SHOT_TIME:
		bonus += SKY_SHOT_BONUS
	bonus += minf(COMBO_BONUS * maxi(combo - 1, 0), COMBO_MAX)
	return roundi(damage_for(weapon, part) * (1.0 + bonus))


## Distance between the fighters' feet. Each map has its own range (ships stand far
## apart, the dojo is close quarters); with no map, the classic range.
static func random_distance_px(rng: RandomNumberGenerator, map: MapData = null) -> float:
	if map != null:
		return rng.randf_range(map.min_distance_m, map.max_distance_m) * PX_PER_M
	return rng.randf_range(MIN_DISTANCE_M, MAX_DISTANCE_M) * PX_PER_M


## A wind for the next turn, in px/s² (negative blows left). Calm half the time on easy.
static func random_wind(rng: RandomNumberGenerator, strength: float = 1.0) -> float:
	return roundf(rng.randf_range(-1.0, 1.0) * MAX_WIND * strength)


## Angle is degrees above horizontal, towards the way the thrower faces (1 or -1).
static func launch_velocity(angle_deg: float, power: float, max_speed: float, facing: int) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return Vector2(cos(a) * facing, -sin(a)) * clampf(power, 0.0, 1.0) * max_speed


## Where a projectile is t seconds after launch, with gravity and wind. Exact, so it
## doesn't drift with frame rate.
static func position_at(origin: Vector2, velocity: Vector2, t: float, wind: float = 0.0, gravity: float = GRAVITY) -> Vector2:
	return origin + velocity * t + Vector2(0.5 * wind * t * t, 0.5 * gravity * t * t)


static func velocity_at(velocity: Vector2, t: float, wind: float = 0.0, gravity: float = GRAVITY) -> Vector2:
	return velocity + Vector2(wind * t, gravity * t)


## Launch speed needed to pass through a point dx px ahead and dy px above (up is positive)
## at the given angle. wind_along is the wind in the throw direction. Returns -1 when
## that angle can't reach it.
static func solve_speed(dx: float, dy: float, angle_deg: float, wind_along: float = 0.0, gravity: float = GRAVITY) -> float:
	var a := deg_to_rad(angle_deg)
	if dx <= 0.0:
		return -1.0
	# With x = v·cos·t + ½·w·t² and y = v·sin·t − ½·g·t², eliminating v gives t² directly.
	var cot := cos(a) / sin(a)
	var denom := 0.5 * (gravity * cot + wind_along)
	var numer := dx - dy * cot
	if denom <= 0.0 or numer <= 0.0:
		return -1.0
	var t := sqrt(numer / denom)
	return (dy + 0.5 * gravity * t * t) / (sin(a) * t)
