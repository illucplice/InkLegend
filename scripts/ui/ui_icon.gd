class_name UiIcon
extends Control
## A small vector icon (white with an ink outline) for buttons.
## Names: play, duo, gear, help, quit, pause, back, restart, home, sound, sword, trophy, star, target, coin.

const INK := Color(0.12, 0.1, 0.14)

var icon: StringName = &"play"
var color := Color.WHITE


static func make(icon_name: StringName, icon_size: float = 34.0, tint: Color = Color.WHITE) -> UiIcon:
	var node := UiIcon.new()
	node.icon = icon_name
	node.color = tint
	node.custom_minimum_size = Vector2(icon_size, icon_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	var u := s / 32.0
	match icon:
		&"play":
			_shape([c + Vector2(-8, -11) * u, c + Vector2(12, 0) * u, c + Vector2(-8, 11) * u])
		&"duo":
			_head(c + Vector2(-6, -5) * u, 6 * u)
			_body(c + Vector2(-6, 9) * u, 9 * u)
			_head(c + Vector2(7, -5) * u, 6 * u)
			_body(c + Vector2(7, 9) * u, 9 * u)
		&"gear":
			for i in 8:
				var a := i * TAU / 8
				var tooth := PackedVector2Array()
				for corner: Vector2 in [Vector2(-3, -15), Vector2(3, -15), Vector2(3, -9), Vector2(-3, -9)]:
					tooth.append(c + corner.rotated(a) * u)
				_shape(tooth)
			draw_circle(c, 11.5 * u, INK, true, -1.0, true)
			draw_circle(c, 9.0 * u, color, true, -1.0, true)
			draw_circle(c, 4.0 * u, INK, true, -1.0, true)
		&"help":
			draw_circle(c, 13 * u, INK, true, -1.0, true)
			draw_circle(c, 10.5 * u, color, true, -1.0, true)
			draw_arc(c + Vector2(0, -3) * u, 4.5 * u, PI, TAU + 0.6, 10, INK, 3.2 * u, true)
			draw_line(c + Vector2(2.6, 0.6) * u, c + Vector2(0, 3.5) * u, INK, 3.2 * u, true)
			draw_circle(c + Vector2(0, 7.5) * u, 2 * u, INK, true, -1.0, true)
		&"quit":
			for side: float in [-1.0, 1.0]:
				var a := c + Vector2(-9, -9 * side) * u
				var b := c + Vector2(9, 9 * side) * u
				draw_line(a, b, INK, 8 * u, true)
				draw_line(a, b, color, 4 * u, true)
		&"pause":
			for x: float in [-6.0, 6.0]:
				var bar := Rect2(c + Vector2(x - 3.5, -10) * u, Vector2(7, 20) * u)
				draw_rect(bar.grow(2 * u), INK)
				draw_rect(bar, color)
		&"back":
			_shape([c + Vector2(-12, 0) * u, c + Vector2(0, -11) * u, c + Vector2(0, -5) * u, c + Vector2(11, -5) * u, c + Vector2(11, 5) * u, c + Vector2(0, 5) * u, c + Vector2(0, 11) * u])
		&"restart":
			draw_arc(c, 10 * u, -PI * 0.2, PI * 1.45, 18, INK, 7 * u, true)
			draw_arc(c, 10 * u, -PI * 0.2, PI * 1.45, 18, color, 3.5 * u, true)
			var tip := c + Vector2.from_angle(-PI * 0.2) * 10 * u
			_shape([tip + Vector2(-6, -6) * u, tip + Vector2(6, -2) * u, tip + Vector2(-2, 6) * u])
		&"home":
			_shape([c + Vector2(0, -13) * u, c + Vector2(13, -1) * u, c + Vector2(9, -1) * u, c + Vector2(9, 12) * u, c + Vector2(-9, 12) * u, c + Vector2(-9, -1) * u, c + Vector2(-13, -1) * u])
		&"sound":
			_shape([c + Vector2(-12, -5) * u, c + Vector2(-5, -5) * u, c + Vector2(3, -12) * u, c + Vector2(3, 12) * u, c + Vector2(-5, 5) * u, c + Vector2(-12, 5) * u])
			for r: float in [7.0, 12.0]:
				draw_arc(c + Vector2(3, 0) * u, r * u, -0.8, 0.8, 8, INK, 5 * u, true)
				draw_arc(c + Vector2(3, 0) * u, r * u, -0.8, 0.8, 8, color, 2.2 * u, true)
		&"coin":
			draw_circle(c, 13.5 * u, INK, true, -1.0, true)
			draw_circle(c, 11.0 * u, Color(1.0, 0.8, 0.25), true, -1.0, true)
			draw_arc(c, 7.5 * u, 0.0, TAU, 20, Color(0.85, 0.6, 0.15), 2.5 * u, true)
			draw_rect(Rect2(c + Vector2(-1.5, -5) * u, Vector2(3, 10) * u), Color(0.85, 0.6, 0.15))
		&"target":
			for ring in 3:
				draw_circle(c, (13.0 - ring * 4.0) * u, INK, true, -1.0, true)
				draw_circle(c, (11.5 - ring * 4.0) * u, color if ring % 2 == 0 else Color(0.95, 0.3, 0.3), true, -1.0, true)
			draw_circle(c, 2.0 * u, INK, true, -1.0, true)
		&"star":
			var star := PackedVector2Array()
			for i in 10:
				var r := 14.0 if i % 2 == 0 else 6.0
				star.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * r * u)
			var saved_star := color
			color = Color(1.0, 0.85, 0.3)
			_shape(star)
			color = saved_star
		&"trophy":
			var gold := Color(1.0, 0.8, 0.25)
			var cup := PackedVector2Array([c + Vector2(-10, -12) * u, c + Vector2(10, -12) * u, c + Vector2(8, -1) * u, c + Vector2(3, 3) * u, c + Vector2(-3, 3) * u, c + Vector2(-8, -1) * u])
			for side: float in [-1.0, 1.0]:
				draw_arc(c + Vector2(side * 10, -6) * u, 5 * u, -PI / 2 if side > 0 else PI / 2, PI / 2 if side > 0 else PI * 1.5, 8, INK, 4.5 * u, true)
				draw_arc(c + Vector2(side * 10, -6) * u, 5 * u, -PI / 2 if side > 0 else PI / 2, PI / 2 if side > 0 else PI * 1.5, 8, gold, 2.0 * u, true)
			var saved := color
			color = gold
			_shape(cup)
			_shape([c + Vector2(-2, 3) * u, c + Vector2(2, 3) * u, c + Vector2(2, 8) * u, c + Vector2(-2, 8) * u])
			_shape([c + Vector2(-8, 8) * u, c + Vector2(8, 8) * u, c + Vector2(8, 12) * u, c + Vector2(-8, 12) * u])
			color = saved
		&"sword":
			_shape([c + Vector2(-11, 11) * u, c + Vector2(-8, 8) * u, c + Vector2(9, -11) * u, c + Vector2(12, -12) * u, c + Vector2(11, -9) * u, c + Vector2(-8, 8) * u])
			draw_line(c + Vector2(-12, 5) * u, c + Vector2(-5, 12) * u, INK, 6 * u, true)
			draw_line(c + Vector2(-12, 5) * u, c + Vector2(-5, 12) * u, Color(1.0, 0.8, 0.3), 3 * u, true)


func _shape(points: Variant) -> void:
	var shape := PackedVector2Array(points)
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, INK, 5.0 * size.x / 32.0, true)
	draw_colored_polygon(shape, color)
	draw_polyline(closed, INK, 2.0 * size.x / 32.0, true)


func _head(at: Vector2, r: float) -> void:
	draw_circle(at, r + 2.0, INK, true, -1.0, true)
	draw_circle(at, r, color, true, -1.0, true)


func _body(at: Vector2, r: float) -> void:
	draw_arc(at, r, PI, TAU, 12, INK, 4.0, true)
	var points := PackedVector2Array([at + Vector2(-r, 0)])
	for i in 13:
		points.append(at + Vector2.from_angle(PI + PI * i / 12.0) * (r - 1.5))
	draw_colored_polygon(points, color)
