class_name ChestArt
extends Control
## A drawn treasure chest in a chest kind's colour. open (0..1) lifts the lid, shake
## rattles it, and glow lights it from inside.

const INK := Color(0.06, 0.055, 0.07)

var color := Color(0.7, 0.48, 0.28)
var open := 0.0
var shake := 0.0
var glow := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var centre := size / 2 + Vector2(sin(_time * 50.0) * shake * s * 0.03, 0)
	var w := s * 0.8
	var h := s * 0.42
	var body := Rect2(centre + Vector2(-w / 2, -h * 0.1), Vector2(w, h * 0.75))
	var metal := Color(0.95, 0.8, 0.35) if color.v < 0.8 else Color(0.55, 0.42, 0.3)
	if glow > 0.0:
		for ring in 4:
			draw_circle(centre, s * (0.5 + ring * 0.12) * glow, Color(1.0, 0.92, 0.6, 0.12 * glow), true, -1.0, true)
	# Body.
	draw_rect(body.grow(3), INK)
	draw_rect(body, color)
	draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.15), Vector2(body.size.x, 5)), color.darkened(0.25))
	for x: float in [0.12, 0.88]:
		draw_rect(Rect2(body.position + Vector2(body.size.x * x - 5, 0), Vector2(10, body.size.y)), metal)
	# Light spilling out when open.
	if open > 0.0:
		var mouth := PackedVector2Array([body.position + Vector2(8, 0), body.position + Vector2(body.size.x - 8, 0), centre + Vector2(w * 0.7, -s * 0.9), centre + Vector2(-w * 0.7, -s * 0.9)])
		draw_colored_polygon(mouth, Color(1.0, 0.95, 0.65, 0.35 * open))
	# Lid, hinged at the back, swinging up as it opens.
	var hinge := body.position + Vector2(0, -h * 0.02)
	var lid_xf := Transform2D(-open * 1.9, hinge)
	draw_set_transform_matrix(lid_xf)
	var lid := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		lid.append(Vector2(w * t, -sin(t * PI) * h * 0.45))
	lid.append(Vector2(w, 4))
	lid.append(Vector2(0, 4))
	var outline := lid.duplicate()
	outline.append(lid[0])
	draw_colored_polygon(lid, color.lightened(0.08))
	draw_polyline(outline, INK, 3.0, true)
	for x: float in [0.12, 0.88]:
		draw_line(Vector2(w * x, 4), Vector2(w * x, -sin(x * PI) * h * 0.45), metal, 9.0)
	draw_set_transform(Vector2.ZERO)
	# Lock plate.
	if open < 0.3:
		var lock := Rect2(centre + Vector2(-10, -h * 0.16), Vector2(20, 24))
		draw_rect(lock.grow(2), INK)
		draw_rect(lock, metal)
		draw_circle(lock.get_center(), 3.5, INK, true, -1.0, true)
