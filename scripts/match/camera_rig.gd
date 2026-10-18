class_name CameraRig
extends Camera2D
## Keeps every point from points_provider on screen, easing its zoom and position.

const MARGIN_SIDE := 200.0
const MARGIN_TOP := 260.0
const MARGIN_BOTTOM := 170.0
const MIN_ZOOM := 0.3
const MAX_ZOOM := 1.1
const EASE_SPEED := 3.0

## Returns a PackedVector2Array of world points to keep in view.
var points_provider: Callable


func snap() -> void:
	_follow(1.0)


func _process(delta: float) -> void:
	_follow(1.0 - exp(-EASE_SPEED * delta))


func _follow(weight: float) -> void:
	if not points_provider.is_valid():
		return
	var points: PackedVector2Array = points_provider.call()
	if points.is_empty():
		return
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	rect = rect.grow_individual(MARGIN_SIDE, MARGIN_TOP, MARGIN_SIDE, MARGIN_BOTTOM)
	var view := get_viewport_rect().size
	var z := clampf(minf(view.x / rect.size.x, view.y / rect.size.y), MIN_ZOOM, MAX_ZOOM)
	zoom = zoom.lerp(Vector2(z, z), weight)
	position = position.lerp(rect.get_center(), weight)
