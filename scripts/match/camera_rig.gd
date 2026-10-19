class_name CameraRig
extends Camera2D
## Keeps every point from points_provider on screen, easing its zoom and position,
## and shakes on hits. Runs on physics ticks (smoothed by physics interpolation)
## using real time, so slow-motion doesn't freeze it.

const MARGIN_SIDE := 200.0
const MARGIN_TOP := 280.0
const MARGIN_BOTTOM := 110.0
const MIN_ZOOM := 0.3
const MAX_ZOOM := 1.1
const CINEMATIC_ZOOM := 1.6
const MOVE_SPEED := 3.0
const ZOOM_SPEED := 2.2
const MAX_SHAKE := 26.0

## Returns a PackedVector2Array of world points to keep in view.
var points_provider: Callable

## Cinematic: while active, frame these points tightly instead (see focus_on).
var _focus: Callable
var _focus_until := 0
var _trauma := 0.0
var _time := 0.0


func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_mode = Node.PROCESS_MODE_ALWAYS


## The part of the world currently on screen.
func visible_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - size / 2, size)


## amount 0..1. Shake grows with the square of trauma, so small hits stay subtle.
func shake(amount: float) -> void:
	if not Save.screen_shake:
		return
	_trauma = minf(1.0, _trauma + amount)


## Swoop in on the points from `points` (a Callable) for `seconds` of real time.
func focus_on(points: Callable, seconds: float) -> void:
	_focus = points
	_focus_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func snap() -> void:
	_follow(1.0, 1.0)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_follow(1.0 - exp(-MOVE_SPEED * real_delta), 1.0 - exp(-ZOOM_SPEED * real_delta))
	_time += real_delta
	_trauma = maxf(0.0, _trauma - real_delta * 1.8)
	var strength := _trauma * _trauma * MAX_SHAKE / zoom.x
	offset = Vector2(sin(_time * 53.0) + sin(_time * 31.0), cos(_time * 47.0) + cos(_time * 23.0)) * 0.5 * strength


func _follow(move_weight: float, zoom_weight: float) -> void:
	var cinematic := _focus.is_valid() and Time.get_ticks_msec() < _focus_until
	var provider := _focus if cinematic else points_provider
	if not provider.is_valid():
		return
	var points: PackedVector2Array = provider.call()
	if points.is_empty():
		return
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	var margin := 0.45 if cinematic else 1.0
	rect = rect.grow_individual(MARGIN_SIDE * margin, MARGIN_TOP * margin, MARGIN_SIDE * margin, MARGIN_BOTTOM * margin)
	var view := get_viewport_rect().size
	var z := clampf(minf(view.x / rect.size.x, view.y / rect.size.y), MIN_ZOOM, CINEMATIC_ZOOM if cinematic else MAX_ZOOM)
	if cinematic:
		move_weight = minf(1.0, move_weight * 3.0)
		zoom_weight = minf(1.0, zoom_weight * 3.0)
	zoom = zoom.lerp(Vector2(z, z), zoom_weight)
	position = position.lerp(rect.get_center(), move_weight)
