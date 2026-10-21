class_name Terrain
extends RefCounted
## The shape of the ground, Bowmasters-style: each fighter stands on a flat plateau
## (each at its own height), with a valley dipping between them and gentle bumps and
## rises out to the edges. y is world space (negative is up). Everything that sits on
## the ground asks height_at() instead of assuming y = 0.

const HALF_WIDTH := 4000.0
const STEP := 20.0
## Flat ground either side of where a fighter stands.
const PLATEAU := 190.0

static var _heights := PackedFloat32Array()


## Flat ground at y = 0 (the default, and for tests that want it).
static func flat() -> void:
	_heights = PackedFloat32Array()


## Builds the ground for fighters standing `half_gap` either side of the middle.
## roughness scales every height (0 = flat).
static func build(rng: RandomNumberGenerator, half_gap: float, roughness: float) -> void:
	if roughness <= 0.0:
		flat()
		return
	var left := -rng.randf_range(40.0, 150.0) * roughness
	var right := -rng.randf_range(40.0, 150.0) * roughness
	var valley := rng.randf_range(-10.0, 40.0) * roughness
	var outer_left := -rng.randf_range(20.0, 120.0) * roughness
	var outer_right := -rng.randf_range(20.0, 120.0) * roughness
	var phase := rng.randf_range(0.0, TAU)
	var count := int(HALF_WIDTH * 2.0 / STEP) + 1
	_heights.resize(count)
	var inner := maxf(half_gap - PLATEAU, 1.0)
	for i in count:
		var x := -HALF_WIDTH + i * STEP
		var y := 0.0
		var bumps := (9.0 * sin(x * 0.012 + phase) + 5.0 * sin(x * 0.031 + phase * 2.0)) * roughness
		if absf(x) < inner:
			# Between the plateaus: a smooth dip down into the valley and back up.
			var u := (x + inner) / (inner * 2.0)
			var level := lerpf(left, right, u)
			var dip := pow(sin(u * PI), 2.0)
			y = level + (valley - level) * dip + bumps * dip
		elif absf(x) <= half_gap + PLATEAU:
			y = left if x < 0.0 else right
		else:
			# Out past the fighters: easing up or down toward the far hills.
			var plateau := left if x < 0.0 else right
			var outer := outer_left if x < 0.0 else outer_right
			var t := clampf((absf(x) - half_gap - PLATEAU) / 700.0, 0.0, 1.0)
			var ease_t := t * t * (3.0 - 2.0 * t)
			y = lerpf(plateau, plateau + outer, ease_t) + bumps * ease_t
		_heights[i] = y


## The ground's height at x (world y, negative is up).
static func height_at(x: float) -> float:
	if _heights.is_empty():
		return 0.0
	var f := clampf((x + HALF_WIDTH) / STEP, 0.0, _heights.size() - 1.0)
	var i := int(f)
	var j := mini(i + 1, _heights.size() - 1)
	return lerpf(_heights[i], _heights[j], f - i)


## The surface as a line of points across the whole arena.
static func profile(step: float = STEP) -> PackedVector2Array:
	var points := PackedVector2Array()
	var x := -HALF_WIDTH
	while x <= HALF_WIDTH:
		points.append(Vector2(x, height_at(x)))
		x += step
	return points


## Blows a round bowl out of the ground at x (explosions). Never digs deeper than
## MAX_DIG below y = 0, so nobody falls out of the world.
const MAX_DIG := 220.0
static func crater(x: float, radius: float, depth: float) -> void:
	if _heights.is_empty():
		var count := int(HALF_WIDTH * 2.0 / STEP) + 1
		_heights.resize(count)
		_heights.fill(0.0)
	var first := maxi(0, int((x - radius + HALF_WIDTH) / STEP))
	var last := mini(_heights.size() - 1, int((x + radius + HALF_WIDTH) / STEP) + 1)
	for i in range(first, last + 1):
		var u := (-HALF_WIDTH + i * STEP - x) / radius
		if absf(u) >= 1.0:
			continue
		_heights[i] = minf(_heights[i] + depth * (1.0 - u * u), MAX_DIG)
