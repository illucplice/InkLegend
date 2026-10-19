class_name Beam
extends Node2D
## The Mega Wave: energy gathers in the hands, then a thick beam fires in a straight
## line to `end`, flickers, and fades. Purely visual; the match works out what it hits.

signal fired
signal finished

const CHARGE_TIME := 0.55
const FIRE_TIME := 0.8
const FADE_TIME := 0.3

var color := Color(0.35, 0.8, 1.0)
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _time := 0.0
var _phase := 0


func setup(from: Vector2, to: Vector2, beam_color: Color) -> void:
	_start = from
	_end = to
	color = beam_color
	z_index = 22
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	_time += delta
	if _phase == 0 and _time >= CHARGE_TIME:
		_phase = 1
		fired.emit()
	elif _phase == 1 and _time >= CHARGE_TIME + FIRE_TIME:
		_phase = 2
	elif _phase == 2 and _time >= CHARGE_TIME + FIRE_TIME + FADE_TIME:
		finished.emit()
		queue_free()
	queue_redraw()


func _draw() -> void:
	var flicker := 0.85 + 0.15 * sin(_time * 60.0)
	if _phase == 0:
		# A ball of energy swelling between the hands.
		var grow := _time / CHARGE_TIME
		for ring in 4:
			draw_circle(_start, (10.0 + grow * 26.0) * (1.3 - ring * 0.2), Color(color, 0.15 + ring * 0.15), true, -1.0, true)
		draw_circle(_start, 6.0 + grow * 10.0, Color.WHITE, true, -1.0, true)
		return
	var fade := 1.0
	if _phase == 2:
		fade = 1.0 - (_time - CHARGE_TIME - FIRE_TIME) / FADE_TIME
	var reach := clampf((_time - CHARGE_TIME) / 0.12, 0.0, 1.0)
	var tip := _start.lerp(_end, reach)
	var direction := (_end - _start).normalized()
	var side := direction.orthogonal()
	var widths := [64.0, 44.0, 26.0, 12.0]
	var colors := [Color(color, 0.18), Color(color, 0.4), color.lightened(0.35), Color.WHITE]
	for i in widths.size():
		var w: float = widths[i] * flicker * fade
		var c: Color = colors[i]
		c.a *= fade
		draw_colored_polygon(PackedVector2Array([_start + side * w * 0.5, tip + side * w * 0.5, tip - side * w * 0.5, _start - side * w * 0.5]), c)
		draw_circle(_start, w * 0.6, c, true, -1.0, true)
		draw_circle(tip, w * 0.55, c, true, -1.0, true)
	# Sparks racing along the beam.
	for k in 10:
		var t := fmod(_time * 2.5 + k * 0.1, 1.0)
		var at := _start.lerp(tip, t) + side * sin(k * 3.7 + _time * 20.0) * 18.0
		draw_circle(at, 3.0 * fade, Color(Color.WHITE, fade), true, -1.0, true)
