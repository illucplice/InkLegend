class_name Arena
extends Node2D
## The floor at y = 0, themed by a MapData: the ground surface and the wall under
## it, the props beside the fighters (pillars and braziers, ice crystals and frost
## torches, or basalt columns and lava pools), the weather, and the ground collision.

const HALF_WIDTH := 4000.0
const DEPTH := 1200.0
const INK := Color(0.12, 0.1, 0.14)
const MARBLE := Color(0.93, 0.86, 0.8)
## Props stand outside the spots where fighters stand (650-850 px out) and the
## obstacle zone in the middle.
const PILLARS := [-2100.0, -1250.0, 1250.0, 2100.0]
const BRAZIERS := [-1600.0, -1040.0, 1040.0, 1600.0]

## Set before adding to the tree.
var map: MapData

var _glow: GradientTexture2D
## The floor is drawn once, so lava glow is a fixed per-spot brightness (the fires flicker).
var _time := 0.0


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_WIDTH * 2, DEPTH)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, DEPTH / 2)
	body.add_child(collision)
	add_child(body)

	_glow = _glow_texture()
	match map.props:
		&"basalt":
			for x: float in BRAZIERS:
				_add_fire(Vector2(x, -6), 0.8)
			for x: float in PILLARS:
				_add_fire(Vector2(x, -330), 0.6)
		_:
			for x: float in BRAZIERS:
				_add_fire(Vector2(x, -96))
			for x: float in PILLARS:
				_add_fire(Vector2(x, -400), 0.7)
	_add_weather()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	match map.props:
		&"ice":
			for x: float in PILLARS:
				_draw_crystals(x, rng)
			for x: float in BRAZIERS:
				_draw_brazier(x, Color(0.55, 0.7, 0.85))
		&"basalt":
			for x: float in PILLARS:
				_draw_basalt(x, rng)
			for x: float in BRAZIERS:
				_draw_lava_pool(x)
		_:
			for x: float in PILLARS:
				_draw_pillar(x)
			for x: float in BRAZIERS:
				_draw_brazier(x, Color(0.42, 0.3, 0.26))
	_draw_ground(rng)


func _draw_ground(rng: RandomNumberGenerator) -> void:
	var wall := map.wall_color
	draw_rect(Rect2(-HALF_WIDTH, 0, HALF_WIDTH * 2, DEPTH), wall.darkened(0.3))
	for row in 10:
		var y := 34.0 + row * 34.0
		var shift := 40.0 if row % 2 else 0.0
		for i in int(HALF_WIDTH * 2 / 80):
			var brick := Rect2(-HALF_WIDTH + i * 80 + shift, y, 76, 30)
			var tint := rng.randf_range(-0.06, 0.06)
			draw_rect(brick, wall.darkened(0.1 + row * 0.05 + tint))
			draw_rect(Rect2(brick.position, Vector2(brick.size.x, 4)), wall.lightened(0.12 - row * 0.03))
	if map.props == &"basalt":
		# Lava glowing through the joints of the wall.
		for row in 4:
			draw_line(Vector2(-HALF_WIDTH, 33.0 + row * 34.0), Vector2(HALF_WIDTH, 33.0 + row * 34.0), Color(map.fire_color, 0.35 - row * 0.08), 2.0)

	var top := PackedVector2Array()
	for x in range(-int(HALF_WIDTH), int(HALF_WIDTH) + 1, 30):
		top.append(Vector2(x, 30.0 + 3.0 * sin(x * 0.03) + 2.0 * sin(x * 0.11)))
	top.append(Vector2(HALF_WIDTH, -2))
	top.append(Vector2(-HALF_WIDTH, -2))
	draw_colored_polygon(top, map.ground_top)
	draw_rect(Rect2(-HALF_WIDTH, -2, HALF_WIDTH * 2, 6), map.ground_lip)
	draw_line(Vector2(-HALF_WIDTH, -2), Vector2(HALF_WIDTH, -2), INK, 4.0)
	match map.weather:
		&"snow":
			for i in 600:
				var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0))
				draw_circle(at, rng.randf_range(1.0, 2.4), Color(0.7, 0.82, 0.95) if i % 3 else Color.WHITE, true, -1.0, true)
			for i in 60:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				draw_line(Vector2(x, 8), Vector2(x + rng.randf_range(-20, 20), 22), Color(0.6, 0.78, 0.95), 2.0, true)
		&"ash":
			for i in 500:
				var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0))
				draw_circle(at, rng.randf_range(1.0, 2.6), map.ground_top.lightened(rng.randf_range(0.05, 0.2)), true, -1.0, true)
			var pulse := 0.6 + 0.4 * sin(_time * 2.5)
			for i in 40:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				var crack := PackedVector2Array([Vector2(x, 4), Vector2(x + 8, 12), Vector2(x + 2, 20), Vector2(x + 12, 28)])
				draw_polyline(crack, Color(map.fire_color, 0.8 * pulse), 2.5, true)
		_:
			for i in 700:
				var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0))
				draw_circle(at, rng.randf_range(1.0, 2.6), map.ground_top.darkened(rng.randf_range(0.1, 0.25)), true, -1.0, true)
	for i in 30:
		var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(10.0, 22.0))
		draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, rng.randf_range(5.0, 9.0), map.obstacle_dark, true, -1.0, true)
		draw_circle(Vector2(-2, -2), 3.0, map.obstacle_stone, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


# --- colosseum props ---

func _draw_pillar(x: float) -> void:
	var height := 400.0
	var shaft := Rect2(x - 30, -height + 30, 60, height - 50)
	draw_rect(shaft.grow(3), INK)
	draw_rect(shaft, MARBLE)
	for k in 4:
		var fx := shaft.position.x + 10 + k * 13
		draw_line(Vector2(fx, shaft.position.y + 4), Vector2(fx, shaft.end.y - 4), MARBLE.darkened(0.15), 4.0)
	draw_rect(Rect2(shaft.position.x + 40, shaft.position.y, 20, shaft.size.y), Color(0.5, 0.3, 0.4, 0.25))
	var capital := Rect2(x - 44, -height, 88, 32)
	var base := Rect2(x - 42, -24, 84, 24)
	for part in [capital, base]:
		draw_rect(part.grow(3), INK)
		draw_rect(part, MARBLE.darkened(0.05))
		draw_rect(Rect2(part.position, Vector2(part.size.x, 6)), MARBLE.lightened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 34, -height), Vector2(x + 34, -height), Vector2(x + 20, -height + 18), Vector2(x - 20, -height + 18)]), Color(0.3, 0.22, 0.2))
	var color := Color(0.82, 0.2, 0.25) if x < 0 else Color(0.22, 0.38, 0.78)
	var banner := PackedVector2Array([
		Vector2(x - 24, -height + 36), Vector2(x + 24, -height + 36),
		Vector2(x + 24, -height + 210), Vector2(x, -height + 236), Vector2(x - 24, -height + 210),
	])
	draw_colored_polygon(banner, color)
	var outline := banner.duplicate()
	outline.append(banner[0])
	draw_polyline(outline, INK, 3.0, true)
	draw_rect(Rect2(x - 24, -height + 50, 48, 6), Color(1.0, 0.82, 0.35))
	draw_rect(Rect2(x - 24, -height + 190, 48, 6), Color(1.0, 0.82, 0.35))
	_draw_emblem(Vector2(x, -height + 120), color)


func _draw_emblem(at: Vector2, color: Color) -> void:
	draw_circle(at, 17.0, Color(1.0, 0.82, 0.35), true, -1.0, true)
	draw_circle(at, 13.0, color.darkened(0.2), true, -1.0, true)
	var star := PackedVector2Array()
	for i in 10:
		var r := 10.0 if i % 2 == 0 else 4.5
		star.append(at + Vector2.from_angle(-PI / 2 + i * PI / 5) * r)
	draw_colored_polygon(star, Color(1.0, 0.82, 0.35))


func _draw_brazier(x: float, metal: Color) -> void:
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(x + side * 6, -80), Vector2(x + side * 22, 0), INK, 8.0, true)
		draw_line(Vector2(x + side * 6, -80), Vector2(x + side * 22, 0), metal, 4.0, true)
	var bowl := PackedVector2Array([Vector2(x - 30, -100), Vector2(x + 30, -100), Vector2(x + 18, -76), Vector2(x - 18, -76)])
	draw_colored_polygon(bowl, metal.darkened(0.2))
	var outline := bowl.duplicate()
	outline.append(bowl[0])
	draw_polyline(outline, INK, 3.0, true)
	draw_rect(Rect2(x - 32, -104, 64, 7), metal.lightened(0.4))


# --- frozen peaks props ---

## A cluster of tall ice crystals with a frost torch flame on the tallest.
func _draw_crystals(x: float, rng: RandomNumberGenerator) -> void:
	var shards := [[0.0, 400.0, 34.0], [-46.0, 230.0, 26.0], [44.0, 280.0, 28.0], [-80.0, 120.0, 20.0], [76.0, 150.0, 18.0]]
	for shard: Array in shards:
		var cx: float = x + shard[0]
		var h: float = shard[1]
		var w: float = shard[2]
		var lean := rng.randf_range(-0.08, 0.08)
		var tip := Vector2(cx + h * lean, -h)
		var body := PackedVector2Array([Vector2(cx - w, 0), Vector2(cx - w * 0.8 + h * lean * 0.7, -h * 0.8), tip, Vector2(cx + w * 0.8 + h * lean * 0.7, -h * 0.8), Vector2(cx + w, 0)])
		draw_colored_polygon(body, Color(0.62, 0.84, 1.0, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.2, 0), tip, Vector2(cx + w, 0)]), Color(0.45, 0.68, 0.92, 0.9))
		draw_line(Vector2(cx - w * 0.5, -10), tip + Vector2(-4, 20), Color(1, 1, 1, 0.7), 3.0, true)
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, INK, 3.0, true)
	draw_rect(Rect2(x - 26, -404, 52, 10), Color(0.55, 0.7, 0.85))


# --- lava forge props ---

## A cluster of hexagonal basalt columns, glowing at the joints.
func _draw_basalt(x: float, rng: RandomNumberGenerator) -> void:
	var pulse := 0.6 + 0.4 * sin(_time * 2.0 + x)
	var columns := [[-60.0, 180.0], [-20.0, 300.0], [20.0, 330.0], [60.0, 220.0], [96.0, 120.0]]
	for column: Array in columns:
		var cx: float = x + column[0]
		var h: float = column[1]
		var face := Rect2(cx - 20, -h, 40, h)
		draw_rect(face.grow(3), INK)
		draw_rect(face, map.obstacle_stone.darkened(rng.randf_range(0.0, 0.15)))
		draw_rect(Rect2(cx + 6, -h, 14, h), map.obstacle_dark)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 20, -h), Vector2(cx - 10, -h - 10), Vector2(cx + 10, -h - 10), Vector2(cx + 20, -h)]), map.obstacle_stone.lightened(0.15))
		var y := -h + 50.0
		while y < -10.0:
			draw_line(Vector2(cx - 20, y), Vector2(cx + 20, y + 4), Color(map.fire_color, 0.6 * pulse), 2.0)
			y += rng.randf_range(50, 90)


## A pool of bubbling lava set into the floor, with a fire jet.
func _draw_lava_pool(x: float) -> void:
	var pulse := 0.6 + 0.4 * sin(_time * 3.0 + x)
	draw_set_transform(Vector2(x, -2), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 90.0, INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 84.0, map.fire_color, true, -1.0, true)
	draw_circle(Vector2(-10, -10), 54.0, map.fire_color.lightened(0.3 * pulse), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var t := fmod(_time * 0.6 + i * 0.25, 1.0)
		draw_circle(Vector2(x - 50 + i * 30, -4 - t * 10), 6.0 * (1.0 - t), Color(1.0, 0.85, 0.4, 1.0 - t), true, -1.0, true)


# --- fire and weather ---

func _add_fire(at: Vector2, size: float = 1.0) -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var glow := Sprite2D.new()
	glow.texture = _glow
	glow.material = additive
	glow.modulate = Color(map.fire_color, 0.45)
	glow.scale = Vector2.ONE * 7.0 * size
	glow.position = at
	add_child(glow)
	var flicker := glow.create_tween().set_loops()
	flicker.tween_property(glow, "modulate:a", 0.3, 0.13).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(glow, "modulate:a", 0.5, 0.17).set_trans(Tween.TRANS_SINE)

	var flame := CPUParticles2D.new()
	flame.texture = _glow
	flame.material = additive
	flame.amount = 26
	flame.lifetime = 0.7
	flame.preprocess = 1.0
	flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 14.0 * size
	flame.direction = Vector2.UP
	flame.spread = 14.0
	flame.gravity = Vector2(0, -160)
	flame.initial_velocity_min = 30.0
	flame.initial_velocity_max = 80.0
	flame.scale_amount_min = 0.9 * size
	flame.scale_amount_max = 1.6 * size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.1))
	flame.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, map.fire_color.lightened(0.6))
	ramp.set_color(1, Color(map.fire_color.darkened(0.4), 0))
	ramp.add_point(0.4, Color(map.fire_color, 0.9))
	flame.color_ramp = ramp
	flame.position = at
	add_child(flame)


func _add_weather() -> void:
	var particles := CPUParticles2D.new()
	particles.texture = _glow
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.z_index = 15
	var ramp := Gradient.new()
	match map.weather:
		&"snow":
			particles.amount = 220
			particles.lifetime = 9.0
			particles.preprocess = 9.0
			particles.emission_rect_extents = Vector2(2600, 40)
			particles.position = Vector2(0, -900)
			particles.direction = Vector2(0.2, 1)
			particles.spread = 20.0
			particles.gravity = Vector2(14, 40)
			particles.initial_velocity_min = 40.0
			particles.initial_velocity_max = 90.0
			particles.scale_amount_min = 0.12
			particles.scale_amount_max = 0.32
			ramp.set_color(0, Color(1, 1, 1, 0))
			ramp.set_color(1, Color(1, 1, 1, 0))
			ramp.add_point(0.1, Color(1, 1, 1, 0.9))
			ramp.add_point(0.9, Color(1, 1, 1, 0.9))
		&"ash":
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			particles.material = additive
			particles.amount = 120
			particles.lifetime = 8.0
			particles.preprocess = 8.0
			particles.emission_rect_extents = Vector2(2400, 300)
			particles.position = Vector2(0, -350)
			particles.direction = Vector2.UP
			particles.spread = 60.0
			particles.gravity = Vector2(10, -8)
			particles.initial_velocity_min = 10.0
			particles.initial_velocity_max = 40.0
			particles.scale_amount_min = 0.1
			particles.scale_amount_max = 0.28
			ramp.set_color(0, Color(map.fire_color, 0))
			ramp.set_color(1, Color(0.5, 0.45, 0.45, 0))
			ramp.add_point(0.2, Color(map.fire_color.lightened(0.3), 0.9))
			ramp.add_point(0.6, Color(0.6, 0.5, 0.5, 0.5))
		_:
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			particles.material = additive
			particles.amount = 70
			particles.lifetime = 7.0
			particles.preprocess = 7.0
			particles.emission_rect_extents = Vector2(2200, 40)
			particles.position = Vector2(0, -40)
			particles.direction = Vector2.UP
			particles.spread = 30.0
			particles.gravity = Vector2(6, -12)
			particles.initial_velocity_min = 15.0
			particles.initial_velocity_max = 45.0
			particles.scale_amount_min = 0.12
			particles.scale_amount_max = 0.3
			ramp.set_color(0, Color(1.0, 0.7, 0.3, 0))
			ramp.set_color(1, Color(1.0, 0.4, 0.15, 0))
			ramp.add_point(0.2, Color(1.0, 0.75, 0.35, 0.9))
	particles.color_ramp = ramp
	add_child(particles)


func _glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
