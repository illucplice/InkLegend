class_name StickRagdoll
extends RefCounted
## A floppy stickman: joints as Verlet particles held together by stick constraints,
## with gravity, a ground at y = 0 and friction. Positions are in the fighter's node
## space (feet at the origin, y down). Stable by construction: no physics engine joints.

const POINTS := [&"head", &"neck", &"hip", &"bknee", &"bfoot", &"fknee", &"ffoot", &"belbow", &"bhand", &"felbow", &"fhand"]
const STICKS := [
	[&"head", &"neck"], [&"neck", &"hip"],
	[&"hip", &"bknee"], [&"bknee", &"bfoot"], [&"hip", &"fknee"], [&"fknee", &"ffoot"],
	[&"neck", &"belbow"], [&"belbow", &"bhand"], [&"neck", &"felbow"], [&"felbow", &"fhand"],
	# Stiffeners keep the head on top of the body and the legs from folding into it.
	[&"head", &"hip"], [&"bknee", &"fknee"],
]
const GRAVITY := 1300.0
const STEP := 1.0 / 120.0
const ITERATIONS := 8
const AIR_DRAG := 0.992
const GROUND_FRICTION := 0.55
const MAX_SPEED := 1100.0

var pos := {}
var _prev := {}
var _rest := []
var _head_radius := 19.0
var _accumulator := 0.0


## Starts from a pose (node-space points), at rest.
func start(points: Dictionary, head_radius: float) -> void:
	_head_radius = head_radius
	for point: StringName in POINTS:
		pos[point] = points[point]
		_prev[point] = points[point]
	_rest.clear()
	for stick: Array in STICKS:
		_rest.append((points[stick[0]] as Vector2).distance_to(points[stick[1]]))


## Gives one joint a velocity kick (px/s).
func push(point: StringName, velocity: Vector2) -> void:
	velocity = velocity.limit_length(MAX_SPEED)
	_prev[point] = pos[point] - velocity * STEP


## Gives every joint the same kick, scaled by `share`.
func push_all(velocity: Vector2, share: float) -> void:
	for point: StringName in POINTS:
		var current: Vector2 = pos[point] - _prev[point]
		_prev[point] = pos[point] - (current + velocity.limit_length(MAX_SPEED) * share * STEP)


## Average joint speed in px/s, to tell when it has come to rest.
func speed() -> float:
	var total := 0.0
	for point: StringName in POINTS:
		total += (pos[point] - _prev[point]).length() / STEP
	return total / POINTS.size()


func step(delta: float) -> void:
	_accumulator = minf(_accumulator + delta, STEP * 8)
	while _accumulator >= STEP:
		_accumulator -= STEP
		_integrate()
		for i in ITERATIONS:
			_solve_sticks()
			_solve_ground()


func _integrate() -> void:
	for point: StringName in POINTS:
		var current: Vector2 = pos[point]
		var velocity: Vector2 = (current - _prev[point]) * AIR_DRAG
		_prev[point] = current
		pos[point] = current + velocity + Vector2(0, GRAVITY * STEP * STEP)


func _solve_sticks() -> void:
	for i in STICKS.size():
		var a: StringName = STICKS[i][0]
		var b: StringName = STICKS[i][1]
		var delta: Vector2 = pos[b] - pos[a]
		var length := delta.length()
		if length < 0.001:
			continue
		var stiffness := 0.5 if i < 10 else 0.12
		var correction: Vector2 = delta * ((length - float(_rest[i])) / length) * stiffness
		pos[a] += correction
		pos[b] -= correction


func _solve_ground() -> void:
	for point: StringName in POINTS:
		var floor_y := -_head_radius if point == &"head" else -3.0
		var p: Vector2 = pos[point]
		if p.y > floor_y:
			p.y = floor_y
			pos[point] = p
			# Friction: bleed off sideways speed while touching the ground.
			var prev: Vector2 = _prev[point]
			prev.x = lerpf(prev.x, p.x, GROUND_FRICTION)
			_prev[point] = prev
