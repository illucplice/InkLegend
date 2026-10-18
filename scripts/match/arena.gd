class_name Arena
extends Node2D
## The colosseum floor at y = 0: sand over a stone wall, pillars with banners,
## flaming braziers and drifting embers, plus the ground collision.

const HALF_WIDTH := 4000.0
const DEPTH := 1200.0
const INK := Color(0.12, 0.1, 0.14)
const SAND := Color(0.9, 0.72, 0.5)
const BRICK := Color(0.5, 0.36, 0.38)
const MARBLE := Color(0.93, 0.86, 0.8)
## Pillars stand outside the spots where fighters usually stand (about 450-600 px out).
const PILLARS := [-1500.0, -880.0, 880.0, 1500.0]
const BRAZIERS := [-1180.0, -260.0, 260.0, 1180.0]

var _ember_texture: GradientTexture2D


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

	_ember_texture = _glow_texture()
	for x: float in BRAZIERS:
		_add_fire(Vector2(x, -96))
	for x: float in PILLARS:
		_add_fire(Vector2(x, -400), 0.7)
	_add_embers()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3

	for x: float in PILLARS:
		_draw_pillar(x)
	for x: float in BRAZIERS:
		_draw_brazier(x)

	# Stone wall under the sand, brick by brick.
	draw_rect(Rect2(-HALF_WIDTH, 0, HALF_WIDTH * 2, DEPTH), BRICK.darkened(0.3))
	for row in 10:
		var y := 34.0 + row * 34.0
		var shift := 40.0 if row % 2 else 0.0
		for i in int(HALF_WIDTH * 2 / 80):
			var brick := Rect2(-HALF_WIDTH + i * 80 + shift, y, 76, 30)
			var tint := rng.randf_range(-0.06, 0.06)
			draw_rect(brick, BRICK.darkened(0.1 + row * 0.05 + tint))
			draw_rect(Rect2(brick.position, Vector2(brick.size.x, 4)), BRICK.lightened(0.12 - row * 0.03))

	# Sand floor with a lit lip and scattered grit.
	var sand_top := PackedVector2Array()
	for x in range(-int(HALF_WIDTH), int(HALF_WIDTH) + 1, 30):
		sand_top.append(Vector2(x, 30.0 + 3.0 * sin(x * 0.03) + 2.0 * sin(x * 0.11)))
	sand_top.append(Vector2(HALF_WIDTH, -2))
	sand_top.append(Vector2(-HALF_WIDTH, -2))
	draw_colored_polygon(sand_top, SAND)
	draw_rect(Rect2(-HALF_WIDTH, -2, HALF_WIDTH * 2, 6), SAND.lightened(0.25))
	draw_line(Vector2(-HALF_WIDTH, -2), Vector2(HALF_WIDTH, -2), INK, 4.0)
	for i in 700:
		var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0))
		draw_circle(at, rng.randf_range(1.0, 2.6), SAND.darkened(rng.randf_range(0.1, 0.25)), true, -1.0, true)
	for i in 30:
		var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(10.0, 22.0))
		draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, rng.randf_range(5.0, 9.0), Color(0.62, 0.55, 0.52), true, -1.0, true)
		draw_circle(Vector2(-2, -2), 3.0, Color(0.78, 0.72, 0.68), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


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
	# Fire bowl on top and a long banner hanging from it.
	draw_colored_polygon(PackedVector2Array([Vector2(x - 34, -height), Vector2(x + 34, -height), Vector2(x + 20, -height + 18), Vector2(x - 20, -height + 18)]).duplicate(), Color(0.3, 0.22, 0.2))
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


func _draw_brazier(x: float) -> void:
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(x + side * 6, -80), Vector2(x + side * 22, 0), INK, 8.0, true)
		draw_line(Vector2(x + side * 6, -80), Vector2(x + side * 22, 0), Color(0.42, 0.3, 0.26), 4.0, true)
	var bowl := PackedVector2Array([Vector2(x - 30, -100), Vector2(x + 30, -100), Vector2(x + 18, -76), Vector2(x - 18, -76)])
	draw_colored_polygon(bowl, Color(0.36, 0.26, 0.24))
	var outline := bowl.duplicate()
	outline.append(bowl[0])
	draw_polyline(outline, INK, 3.0, true)
	draw_rect(Rect2(x - 32, -104, 64, 7), Color(0.9, 0.68, 0.3))


func _add_fire(at: Vector2, size: float = 1.0) -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var glow := Sprite2D.new()
	glow.texture = _ember_texture
	glow.material = additive
	glow.modulate = Color(1.0, 0.55, 0.2, 0.45)
	glow.scale = Vector2.ONE * 7.0 * size
	glow.position = at
	add_child(glow)
	var flicker := glow.create_tween().set_loops()
	flicker.tween_property(glow, "modulate:a", 0.3, 0.13).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(glow, "modulate:a", 0.5, 0.17).set_trans(Tween.TRANS_SINE)

	var flame := CPUParticles2D.new()
	flame.texture = _ember_texture
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
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 1))
	ramp.set_color(1, Color(0.8, 0.15, 0.05, 0))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.15, 0.9))
	flame.color_ramp = ramp
	flame.position = at
	add_child(flame)


func _add_embers() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var embers := CPUParticles2D.new()
	embers.texture = _ember_texture
	embers.material = additive
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(2200, 40)
	embers.position = Vector2(0, -40)
	embers.direction = Vector2.UP
	embers.spread = 30.0
	embers.gravity = Vector2(6, -12)
	embers.initial_velocity_min = 15.0
	embers.initial_velocity_max = 45.0
	embers.scale_amount_min = 0.12
	embers.scale_amount_max = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.7, 0.3, 0))
	ramp.set_color(1, Color(1.0, 0.4, 0.15, 0))
	ramp.add_point(0.2, Color(1.0, 0.75, 0.35, 0.9))
	embers.color_ramp = ramp
	embers.z_index = 15
	add_child(embers)


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
