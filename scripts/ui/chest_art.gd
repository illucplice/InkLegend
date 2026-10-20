class_name ChestArt
extends Control
## A drawn treasure chest. kind picks the finish: wood (planks with iron bands), silver
## (polished steel with a sapphire) or gold (gold plate with a ruby and glints). open
## (0..1) lifts the lid, shake rattles it, and glow lights it from inside.

const INK := Color(0.06, 0.055, 0.07)

var color := Color(0.7, 0.48, 0.28)
## wood, silver or gold.
var kind := "wood"
var open := 0.0
var shake := 0.0
var glow := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _finish() -> Dictionary:
	match kind:
		"silver":
			return {"body": Color(0.66, 0.7, 0.8), "dark": Color(0.42, 0.45, 0.55), "band": Color(0.88, 0.9, 0.95), "gem": Color(0.25, 0.55, 1.0)}
		"gold":
			return {"body": Color(0.95, 0.72, 0.2), "dark": Color(0.72, 0.48, 0.1), "band": Color(1.0, 0.92, 0.55), "gem": Color(0.9, 0.12, 0.18)}
	return {"body": Color(0.66, 0.42, 0.24), "dark": Color(0.45, 0.27, 0.14), "band": Color(0.42, 0.42, 0.46), "gem": Color(0.95, 0.75, 0.3)}


func _draw() -> void:
	var finish := _finish()
	var body_color: Color = finish["body"]
	var dark: Color = finish["dark"]
	var band: Color = finish["band"]
	var gem: Color = finish["gem"]
	var s := minf(size.x, size.y)
	var centre := size / 2 + Vector2(sin(_time * 50.0) * shake * s * 0.03, 0)
	var w := s * 0.82
	var h := s * 0.4
	var body := Rect2(centre + Vector2(-w / 2, -h * 0.05), Vector2(w, h * 0.78))
	# Shadow underneath.
	draw_set_transform(Vector2(centre.x, body.end.y + 4), 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, w * 0.55, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if glow > 0.0:
		for ring in 4:
			draw_circle(centre, s * (0.5 + ring * 0.12) * glow, Color(1.0, 0.92, 0.6, 0.12 * glow), true, -1.0, true)
	# Body: planks (wood) or plates, edged in ink.
	draw_rect(body.grow(3), INK)
	draw_rect(body, body_color)
	var planks := 3
	for k in planks:
		var y := body.position.y + body.size.y * (k + 1) / float(planks + 1)
		draw_line(Vector2(body.position.x + 2, y), Vector2(body.end.x - 2, y), dark, 2.0)
	if kind == "wood":
		for k in 6:
			var x := body.position.x + body.size.x * (0.1 + k * 0.16)
			draw_arc(Vector2(x, body.position.y + body.size.y * 0.5), 3.0, 0.0, TAU, 8, dark, 1.2, true)
	else:
		draw_rect(Rect2(body.position + Vector2(4, 4), Vector2(body.size.x - 8, 5)), Color(1, 1, 1, 0.3))
	draw_rect(Rect2(body.position.x, body.end.y - 6, body.size.x, 6), dark)
	# Metal bands with rivets, and corner caps.
	for x: float in [0.14, 0.86]:
		var band_rect := Rect2(body.position + Vector2(body.size.x * x - 6, 0), Vector2(12, body.size.y))
		draw_rect(band_rect, band)
		draw_rect(band_rect, INK, false, 1.5)
		for k in 3:
			draw_circle(band_rect.get_center() + Vector2(0, (k - 1) * body.size.y * 0.3), 2.0, INK, true, -1.0, true)
	for corner: Vector2 in [body.position, Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), body.end]:
		draw_circle(corner, 4.5, band, true, -1.0, true)
		draw_circle(corner, 4.5, INK, false, 1.5, true)
	# Light spilling out when open.
	if open > 0.0:
		var mouth := PackedVector2Array([body.position + Vector2(8, 0), body.position + Vector2(body.size.x - 8, 0), centre + Vector2(w * 0.7, -s * 0.9), centre + Vector2(-w * 0.7, -s * 0.9)])
		draw_colored_polygon(mouth, Color(1.0, 0.95, 0.65, 0.35 * open))
	# Lid: a dome hinged at the back, swinging up as it opens.
	var hinge := body.position + Vector2(0, -h * 0.02)
	draw_set_transform_matrix(Transform2D(-open * 1.9, hinge))
	var lid := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		lid.append(Vector2(w * t, -sin(t * PI) * h * 0.5))
	lid.append(Vector2(w, 4))
	lid.append(Vector2(0, 4))
	var outline := lid.duplicate()
	outline.append(lid[0])
	draw_colored_polygon(lid, body_color.lightened(0.06))
	# A shine along the top of the dome.
	var shine := PackedVector2Array()
	for i in 9:
		var t := 0.12 + i / 8.0 * 0.5
		shine.append(Vector2(w * t, -sin(t * PI) * h * 0.5 + 6.0))
	draw_polyline(shine, Color(1, 1, 1, 0.35), 3.0, true)
	draw_line(Vector2(2, 0), Vector2(w - 2, 0), dark, 3.0)
	draw_polyline(outline, INK, 3.0, true)
	for x: float in [0.14, 0.86]:
		var top := -sin(x * PI) * h * 0.5
		draw_line(Vector2(w * x, 4), Vector2(w * x, top), INK, 13.0)
		draw_line(Vector2(w * x, 4), Vector2(w * x, top), band, 10.0)
	if kind == "gold":
		# A little crown on the lid.
		var crown := Vector2(w * 0.5, -h * 0.3)
		draw_colored_polygon(PackedVector2Array([crown + Vector2(-12, 6), crown + Vector2(-12, -6), crown + Vector2(-6, 0), crown + Vector2(0, -9), crown + Vector2(6, 0), crown + Vector2(12, -6), crown + Vector2(12, 6)]), band)
	draw_set_transform(Vector2.ZERO)
	# Lock plate with a gem.
	if open < 0.3:
		var lock := Rect2(centre + Vector2(-11, -h * 0.16), Vector2(22, 26))
		draw_rect(lock.grow(2), INK)
		draw_rect(lock, band)
		draw_circle(lock.get_center() + Vector2(0, -2), 5.5, INK, true, -1.0, true)
		draw_circle(lock.get_center() + Vector2(0, -2), 4.2, gem, true, -1.0, true)
		draw_circle(lock.get_center() + Vector2(-1.5, -3.5), 1.4, Color(1, 1, 1, 0.8), true, -1.0, true)
		draw_rect(Rect2(lock.get_center() + Vector2(-1.5, 4), Vector2(3, 6)), INK)
	# Glints dancing over the precious ones.
	if kind != "wood":
		for k in 3:
			var phase := fmod(_time * 0.8 + k * 0.33, 1.0)
			if phase < 0.3:
				var at := centre + Vector2((k - 1) * w * 0.32, -h * 0.25 + (k % 2) * h * 0.3)
				var r := sin(phase / 0.3 * PI) * 7.0
				draw_line(at + Vector2(-r, 0), at + Vector2(r, 0), Color(1, 1, 1, 0.95), 2.0, true)
				draw_line(at + Vector2(0, -r), at + Vector2(0, r), Color(1, 1, 1, 0.95), 2.0, true)
