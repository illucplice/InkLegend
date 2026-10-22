class_name Stand
extends CanvasGroup
## A stand (Jotar's Star Platina, Dyo's The Warld): a big muscular spirit looming over
## its user's shoulder, fading into a wisp below the waist. Drawn as one group so the
## whole figure fades evenly instead of its overlapping parts showing through.

## How much of it shows, 0..1.
var show := 0.0
## 0 = guard, 1 = arm fully out in a straight punch.
var punch := 0.0
## A rush of fists (ORA / MUDA).
var barrage := false
var kind := &"stardust"
var facing := 1

var _time := 0.0
var _painter := Node2D.new()

const OUTLINE := Color(0.12, 0.1, 0.14)
const SCALE := 1.45


func _ready() -> void:
	show_behind_parent = true
	fit_margin = 40.0
	add_child(_painter)
	_painter.draw.connect(_paint)


func _process(delta: float) -> void:
	_time += delta
	visible = show > 0.02
	if visible:
		self_modulate.a = clampf(show, 0.0, 1.0) * 0.9
		_painter.queue_redraw()


func _paint() -> void:
	var star := kind == &"stardust"
	var skin := Color(0.56, 0.42, 0.86) if star else Color(0.98, 0.84, 0.34)
	var shade := skin.darkened(0.28)
	var light := skin.lightened(0.25)
	var dark := Color(0.1, 0.08, 0.14) if star else Color(0.08, 0.28, 0.27)
	var trim := Color(0.95, 0.78, 0.28) if star else Color(0.12, 0.44, 0.4)
	var c := _painter
	var bob := sin(_time * 2.2) * 3.0
	c.draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing * SCALE, SCALE))

	# A glow, and wisps rising off it.
	for ring in 3:
		c.draw_circle(Vector2(0, -45), 62.0 - ring * 14.0, Color(skin, 0.08 + ring * 0.04), true, -1.0, true)
	for k in 5:
		var rise := fmod(_time * 0.7 + k * 0.2, 1.0)
		c.draw_circle(Vector2(-30 + k * 15.0, 20.0 - rise * 110.0), 5.0 * (1.0 - rise), Color(light, 0.5 * (1.0 - rise)), true, -1.0, true)

	# Below the waist it trails away into a wisp.
	var tail := PackedVector2Array([Vector2(-12, -2), Vector2(12, -2), Vector2(9, 22), Vector2(-4, 46), Vector2(-28, 70), Vector2(-20, 44), Vector2(-14, 20)])
	c.draw_colored_polygon(tail, Color(skin, 0.55))
	c.draw_polyline(PackedVector2Array([tail[1], tail[2], tail[3], tail[4]]), Color(OUTLINE, 0.4), 2.0, true)

	var head := Vector2(5, -90)
	if not star:
		# Two ribbed hoses running from the back of the helmet down into the back.
		for hose in 2:
			var points := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				var from := head + Vector2(-12, -2 + hose * 8.0)
				var to := Vector2(-22 + hose * 8.0, -56)
				points.append(from.lerp(to, t) + Vector2(-18.0 * sin(t * PI), 0))
			c.draw_polyline(points, OUTLINE, 9.0, true)
			c.draw_polyline(points, dark, 6.0, true)
			for k in range(1, 8):
				c.draw_circle(points[k], 2.5, Color(OUTLINE, 0.6), true, -1.0, true)

	# The back arm, held in guard.
	_limb(Vector2(-20, -60), Vector2(-26, -36), 13.0, 11.0, skin)
	_limb(Vector2(-26, -36), Vector2(-6, -44), 11.0, 10.0, skin)
	if not star:
		_gauntlet(Vector2(-26, -36), Vector2(-6, -44), dark, skin)
		_shoulder_pad(Vector2(-20, -62), dark, skin)
	_fist(Vector2(-4, -45), shade, trim)

	# Torso: broad shoulders tapering to a narrow waist, chest and abs inked in.
	var torso := PackedVector2Array([Vector2(-27, -66), Vector2(-9, -75), Vector2(12, -75), Vector2(26, -65), Vector2(21, -40), Vector2(12, -16), Vector2(10, 0), Vector2(-10, 0), Vector2(-15, -16), Vector2(-24, -40)])
	c.draw_colored_polygon(torso, skin)
	var outline := torso.duplicate()
	outline.append(torso[0])
	c.draw_polyline(outline, OUTLINE, 2.5, true)
	c.draw_arc(Vector2(-7, -54), 10.0, 0.3, PI - 0.3, 10, shade, 2.0, true)
	c.draw_arc(Vector2(11, -54), 10.0, 0.3, PI - 0.3, 10, shade, 2.0, true)
	for row in 3:
		c.draw_line(Vector2(-6, -36 + row * 9.0), Vector2(-1, -36 + row * 9.0), shade, 2.0, true)
		c.draw_line(Vector2(4, -36 + row * 9.0), Vector2(9, -36 + row * 9.0), shade, 2.0, true)
	c.draw_line(Vector2(1.5, -46), Vector2(1.5, -12), shade, 1.5, true)
	if star:
		c.draw_line(Vector2(-9, -2), Vector2(10, -2), trim, 5.0, true)
	else:
		# A collar plate with a heart, and a belt studded with hearts.
		c.draw_colored_polygon(PackedVector2Array([Vector2(-14, -74), Vector2(16, -74), Vector2(8, -64), Vector2(1, -60), Vector2(-6, -64)]), dark)
		_heart(Vector2(1, -66), 4.0, skin)
		c.draw_line(Vector2(-11, -4), Vector2(11, -4), dark, 7.0, true)
		for k in 3:
			_heart(Vector2(-7 + k * 7.0, -4), 3.0, skin)

	# The punching arm: a guard, a straight punch, or a rush of fists.
	var shoulder := Vector2(18, -63)
	if barrage:
		for k in 7:
			var spin := fmod(_time * 11.0 + k * 0.37, 1.0)
			var fist := Vector2(70.0 + spin * 22.0, -86.0 + k * 8.0 + sin(_time * 40.0 + k) * 4.0)
			var elbow := shoulder.lerp(fist, 0.5) + Vector2(0, 6)
			_limb(shoulder, elbow, 11.0, 9.0, Color(skin, 0.55))
			_limb(elbow, fist, 9.0, 8.0, Color(skin, 0.55))
			_fist(fist, Color(shade, 0.7), Color(trim, 0.7))
			c.draw_line(fist + Vector2(-38, 0), fist + Vector2(-14, 0), Color(light, 0.6), 2.0, true)
	var reach := 1.0 if barrage else punch
	var front_elbow := Vector2(28, -40).lerp(Vector2(50, -62), reach)
	var front_fist := Vector2(32, -62).lerp(Vector2(88, -64), reach)
	_limb(shoulder, front_elbow, 14.0, 11.0, skin)
	_limb(front_elbow, front_fist, 11.0, 10.0, skin)
	if star:
		_fist(front_fist, shade, trim)
		c.draw_circle(shoulder + Vector2(0, -2), 9.0, trim, true, -1.0, true)
		c.draw_arc(shoulder + Vector2(0, -2), 9.0, 0.0, TAU, 14, OUTLINE, 2.0, true)
	else:
		_gauntlet(front_elbow, front_fist, dark, skin)
		_fist(front_fist, shade, dark)
		_shoulder_pad(shoulder, dark, skin)

	# Neck and head.
	_limb(Vector2(2, -72), Vector2(4, -80), 10.0, 10.0, skin)
	if star:
		# Long black hair whipping back, a red scarf streaming behind.
		var wave := sin(_time * 4.0) * 3.0
		var hair := PackedVector2Array([head + Vector2(12, -10), head + Vector2(2, -18), head + Vector2(-14, -18), head + Vector2(-38, -14 + wave), head + Vector2(-26, -6), head + Vector2(-46, 2 + wave), head + Vector2(-28, 6), head + Vector2(-40, 18 + wave), head + Vector2(-16, 12), head + Vector2(-8, 6)])
		c.draw_colored_polygon(hair, dark)
		var scarf := PackedVector2Array([head + Vector2(-6, 14), head + Vector2(10, 14), head + Vector2(6, 22), head + Vector2(-30, 30 + wave), head + Vector2(-44, 24 + wave), head + Vector2(-22, 20)])
		c.draw_colored_polygon(scarf, Color(0.85, 0.15, 0.2))
		c.draw_polyline(PackedVector2Array([scarf[3], scarf[4], scarf[5]]), OUTLINE, 1.5, true)
	_oval(head, 12.0, 14.0, skin)
	if star:
		var fringe := PackedVector2Array([head + Vector2(-12, -6), head + Vector2(-6, -16), head + Vector2(8, -15), head + Vector2(14, -6), head + Vector2(8, -9), head + Vector2(2, -6), head + Vector2(-4, -10)])
		c.draw_colored_polygon(fringe, dark)
		c.draw_line(head + Vector2(-10, -8), head + Vector2(14, -9), trim, 2.5, true)
	else:
		# The Warld's head: a dark helmet sweeping back over the skull with a ridge and
		# a heart on the brow, a round ear guard, and the striped faceplate.
		var helmet := PackedVector2Array([head + Vector2(14, -5), head + Vector2(10, -14), head + Vector2(0, -19), head + Vector2(-12, -17), head + Vector2(-22, -8), head + Vector2(-18, 2), head + Vector2(-14, 10), head + Vector2(-8, 8), head + Vector2(-6, -2), head + Vector2(4, -7)])
		c.draw_colored_polygon(helmet, dark)
		var rim := helmet.duplicate()
		rim.append(helmet[0])
		c.draw_polyline(rim, OUTLINE, 2.0, true)
		c.draw_polyline(PackedVector2Array([head + Vector2(8, -15), head + Vector2(-4, -21), head + Vector2(-18, -16)]), skin.darkened(0.1), 2.5, true)
		_heart(head + Vector2(6, -11), 4.0, skin)
		c.draw_circle(head + Vector2(-8, 1), 4.5, skin.darkened(0.15), true, -1.0, true)
		c.draw_arc(head + Vector2(-8, 1), 4.5, 0.0, TAU, 12, OUTLINE, 1.5, true)
		# A dark band across the eyes, and stripes running down from them.
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(0, -6), head + Vector2(13, -7), head + Vector2(13, 1), head + Vector2(1, 1)]), dark)
		for stripe: float in [5.0, 9.5]:
			c.draw_line(head + Vector2(stripe, 1), head + Vector2(stripe - 0.5, 10), dark, 2.0, true)
		c.draw_line(head + Vector2(6, 11), head + Vector2(12, 10), Color(0.15, 0.4, 0.3), 2.5, true)
	# Fierce white eyes under a heavy brow.
	c.draw_colored_polygon(PackedVector2Array([head + Vector2(3, -3), head + Vector2(12, -4), head + Vector2(10, 0), head + Vector2(4, 0)]), Color.WHITE)
	if star:
		c.draw_line(head + Vector2(1, -5), head + Vector2(13, -6), OUTLINE, 2.5, true)
		c.draw_line(head + Vector2(5, 7), head + Vector2(11, 7), OUTLINE, 1.5, true)
	c.draw_set_transform(Vector2.ZERO)


## A limb: an inked outline under a tapered fill.
func _limb(from: Vector2, to: Vector2, from_width: float, to_width: float, color: Color) -> void:
	_taper(from, to, from_width + 3.5, to_width + 3.5, Color(OUTLINE, color.a))
	_taper(from, to, from_width, to_width, color)


func _taper(from: Vector2, to: Vector2, from_width: float, to_width: float, color: Color) -> void:
	var along := to - from
	if along.length() < 0.5:
		return
	var side := along.normalized().orthogonal()
	_painter.draw_colored_polygon(PackedVector2Array([from + side * from_width * 0.5, to + side * to_width * 0.5, to - side * to_width * 0.5, from - side * from_width * 0.5]), color)
	_painter.draw_circle(from, from_width * 0.5, color, true, -1.0, true)
	_painter.draw_circle(to, to_width * 0.5, color, true, -1.0, true)


## A big squared-off fist with a wristband.
func _fist(at: Vector2, color: Color, band: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(OUTLINE, color.a)
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.anti_aliasing = true
	_painter.draw_style_box(box, Rect2(at - Vector2(8, 7.5), Vector2(17, 15)))
	_painter.draw_line(at + Vector2(3, -6), at + Vector2(3, 6), Color(OUTLINE, color.a * 0.7), 1.5, true)
	_painter.draw_line(at + Vector2(-10, -7), at + Vector2(-10, 7), band, 4.0, true)


func _oval(at: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		points.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	_painter.draw_colored_polygon(points, color)
	points.append(points[0])
	_painter.draw_polyline(points, OUTLINE, 2.0, true)


func _heart(at: Vector2, size: float, color: Color) -> void:
	_painter.draw_colored_polygon(PackedVector2Array([at + Vector2(0, size), at + Vector2(-size, -size * 0.1), at + Vector2(-size * 0.6, -size * 0.8), at + Vector2(0, -size * 0.35), at + Vector2(size * 0.6, -size * 0.8), at + Vector2(size, -size * 0.1)]), color)


## The Warld's forearm guard: dark plating over the lower arm with a heart on it.
func _gauntlet(elbow: Vector2, wrist: Vector2, color: Color, heart: Color) -> void:
	var from := elbow.lerp(wrist, 0.35)
	_limb(from, wrist, 13.0, 12.0, color)
	_heart(from.lerp(wrist, 0.5), 3.5, heart)


## A big round shoulder pad with a heart.
func _shoulder_pad(at: Vector2, color: Color, heart: Color) -> void:
	_painter.draw_circle(at, 11.0, color, true, -1.0, true)
	_painter.draw_arc(at, 11.0, 0.0, TAU, 16, OUTLINE, 2.0, true)
	_heart(at, 5.0, heart)
