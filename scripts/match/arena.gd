class_name Arena
extends Node2D
## The floor at y = 0, themed by a MapData: the ground surface and the wall under
## it, the props beside the fighters (pillars and braziers, ice crystals and frost
## torches, or basalt columns and lava pools), the weather, and the ground collision.

const HALF_WIDTH := 4000.0
const DEPTH := 1200.0
const INK := Color(0.12, 0.1, 0.14)
const MARBLE := Color(0.93, 0.86, 0.8)
## Props stand just outside the spots where the fighters stand, so they move out on
## maps where the fighters are further apart: these are distances past a fighter.
const PILLAR_OUT := [410.0, 1260.0]
const BRAZIER_OUT := [200.0, 760.0]

## Set before adding to the tree.
var map: MapData

var _glow: GradientTexture2D
var _pillars: Array[float] = []
var _braziers: Array[float] = []
## Fires and glows by the props, rebuilt when the props move.
var _lights: Node2D
## The ground's collision: a line along the terrain's surface.
var _ground: CollisionPolygon2D
## How far the prop being drawn is lifted to sit on the terrain.
var _lift := 0.0
## The floor is drawn once, so lava glow is a fixed per-spot brightness (the fires flicker).
var _time := 0.0


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_ground = CollisionPolygon2D.new()
	_ground.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	body.add_child(_ground)
	add_child(body)
	_shape_ground()

	_glow = _glow_texture()
	_lights = Node2D.new()
	add_child(_lights)
	set_spread(840.0)
	_add_weather()


## Re-shapes the ground after Terrain changes: collision, props and lights.
func refresh_terrain() -> void:
	_shape_ground()
	if _lights != null:
		for child in _lights.get_children():
			child.queue_free()
		_add_lights()
	queue_redraw()


func _shape_ground() -> void:
	if _ground == null:
		return
	var outline := Terrain.profile()
	outline.append(Vector2(HALF_WIDTH, DEPTH))
	outline.append(Vector2(-HALF_WIDTH, DEPTH))
	_ground.polygon = outline


## Lifts the next prop to stand on the terrain at x.
func _lift_to(x: float) -> void:
	_lift = Terrain.height_at(x)
	draw_set_transform(Vector2(0, _lift))


## Moves the props out to stand beside fighters `half_gap` px either side of the middle.
func set_spread(half_gap: float) -> void:
	_pillars.clear()
	_braziers.clear()
	for side: float in [-1.0, 1.0]:
		for out: float in PILLAR_OUT:
			_pillars.append(side * (half_gap + out))
		for out: float in BRAZIER_OUT:
			_braziers.append(side * (half_gap + out))
	if _lights == null:
		return
	for child in _lights.get_children():
		child.queue_free()
	_add_lights()
	queue_redraw()


func _add_lights() -> void:
	match map.props:
		&"cactus":
			pass
		&"dojo":
			for x: float in _pillars:
				_add_glow(Vector2(x, -173), 0.45)
			for x: float in _braziers:
				_add_glow(Vector2(x + 44, -172), 0.6)
		&"graves":
			for x: float in _pillars:
				_add_fire(Vector2(x + 40, -262), 0.35)
			for x: float in _braziers:
				_add_fire(Vector2(x + 34, -30), 0.25)
		&"masts":
			for x: float in _pillars:
				_add_fire(Vector2(x + 26, -300), 0.35)
		&"rooftop":
			for x: float in _braziers:
				_add_glow(Vector2(x, -150), 0.9)
			for x: float in _pillars:
				_add_glow(Vector2(x, -420), 0.4)
		&"trees":
			pass
		&"basalt":
			for x: float in _braziers:
				_add_fire(Vector2(x, -6), 0.8)
			for x: float in _pillars:
				_add_fire(Vector2(x, -330), 0.6)
		_:
			for x: float in _braziers:
				_add_fire(Vector2(x, -96))
			for x: float in _pillars:
				_add_fire(Vector2(x, -400), 0.7)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	match map.props:
		&"cactus":
			for x: float in _pillars:
				_lift_to(x)
				_draw_big_cactus(x, rng)
			for x: float in _braziers:
				_lift_to(x)
				_draw_skull_rocks(x, rng)
		&"dojo":
			for x: float in _pillars:
				_lift_to(x)
				_draw_stone_lantern(x)
			for x: float in _braziers:
				_lift_to(x)
				_draw_paper_lantern(x)
		&"graves":
			for x: float in _pillars:
				_lift_to(x)
				_draw_lamp_post(x)
			for x: float in _braziers:
				_lift_to(x)
				_draw_candle_grave(x, rng)
		&"masts":
			for x: float in _pillars:
				_lift_to(x)
				_draw_mast(x)
			for x: float in _braziers:
				_lift_to(x)
				_draw_barrels(x, rng)
		&"rooftop":
			for x: float in _pillars:
				_lift_to(x)
				_draw_water_tower(x)
			for x: float in _braziers:
				_lift_to(x)
				_draw_neon_post(x)
		&"trees":
			for x: float in _pillars:
				_lift_to(x)
				_draw_big_tree(x, rng)
			for x: float in _braziers:
				_lift_to(x)
				_draw_bush(x, rng)
		&"ice":
			for x: float in _pillars:
				_lift_to(x)
				_draw_crystals(x, rng)
			for x: float in _braziers:
				_lift_to(x)
				_draw_brazier(x, Color(0.55, 0.7, 0.85))
		&"basalt":
			for x: float in _pillars:
				_lift_to(x)
				_draw_basalt(x, rng)
			for x: float in _braziers:
				_lift_to(x)
				_draw_lava_pool(x)
		_:
			for x: float in _pillars:
				_lift_to(x)
				_draw_pillar(x)
			for x: float in _braziers:
				_lift_to(x)
				_draw_brazier(x, Color(0.42, 0.3, 0.26))
	_lift = 0.0
	draw_set_transform(Vector2(0, _lift))
	_draw_ground(rng)


## A point `y` below the ground surface at x (the ground follows the terrain).
func _g(x: float, y: float) -> Vector2:
	return Vector2(x, y + Terrain.height_at(x))


func _draw_ground(rng: RandomNumberGenerator) -> void:
	var wall := map.wall_color
	var surface := Terrain.profile(30.0)
	# The earth or wall under the whole profile.
	var mass := surface.duplicate()
	mass.append(Vector2(HALF_WIDTH, DEPTH))
	mass.append(Vector2(-HALF_WIDTH, DEPTH))
	draw_colored_polygon(mass, wall.darkened(0.3))
	if map.props == &"masts":
		# A ship's hull: long planks with rows of rivets, following the deck.
		for row in 12:
			var y := 30.0 + row * 26.0
			var plank := PackedVector2Array()
			for p in surface:
				plank.append(p + Vector2(0, y))
			for k in range(surface.size() - 1, -1, -1):
				plank.append(surface[k] + Vector2(0, y + 22))
			draw_colored_polygon(plank, wall.darkened(0.05 + row * 0.04 + rng.randf_range(-0.03, 0.03)))
			for x in range(-int(HALF_WIDTH), int(HALF_WIDTH), 160):
				draw_circle(_g(x + (row % 2) * 80, y + 11), 2.5, wall.darkened(0.5), true, -1.0, true)
	elif map.props == &"trees":
		# Earth with roots and pebbles under the grass.
		var earth := surface.duplicate()
		earth.append(Vector2(HALF_WIDTH, DEPTH))
		earth.append(Vector2(-HALF_WIDTH, DEPTH))
		draw_colored_polygon(earth, wall)
		for i in 220:
			var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
			draw_circle(_g(x, rng.randf_range(40.0, 320.0)), rng.randf_range(3.0, 8.0), wall.darkened(rng.randf_range(0.15, 0.35)), true, -1.0, true)
		for i in 60:
			var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
			draw_polyline(PackedVector2Array([_g(x, 26), _g(x + 8, 60), _g(x - 4, 96), _g(x + 6, 130)]), wall.darkened(0.45), 3.0, true)
	for row in (0 if map.props == &"masts" or map.props == &"trees" else 10):
		var y := 34.0 + row * 34.0
		var shift := 40.0 if row % 2 else 0.0
		for i in int(HALF_WIDTH * 2 / 80):
			var x := -HALF_WIDTH + i * 80 + shift
			var top := _g(x + 38, y)
			var brick := Rect2(Vector2(x, top.y), Vector2(76, 30))
			var tint := rng.randf_range(-0.06, 0.06)
			draw_rect(brick, wall.darkened(0.1 + row * 0.05 + tint))
			draw_rect(Rect2(brick.position, Vector2(brick.size.x, 4)), wall.lightened(0.12 - row * 0.03))
	if map.props == &"basalt":
		# Lava glowing through the joints of the wall.
		for row in 4:
			var seam := PackedVector2Array()
			for p in surface:
				seam.append(p + Vector2(0, 33.0 + row * 34.0))
			draw_polyline(seam, Color(map.fire_color, 0.35 - row * 0.08), 2.0)

	# The top layer: a band of ground colour following the surface, a lip and an ink edge.
	var band := PackedVector2Array()
	for p in surface:
		band.append(p + Vector2(0, -2))
	for k in range(surface.size() - 1, -1, -1):
		var p := surface[k]
		band.append(p + Vector2(0, 30.0 + 3.0 * sin(p.x * 0.03) + 2.0 * sin(p.x * 0.11)))
	draw_colored_polygon(band, map.ground_top)
	var lip := PackedVector2Array()
	for p in surface:
		lip.append(p + Vector2(0, 1))
	draw_polyline(lip, map.ground_lip, 6.0, true)
	var edge := PackedVector2Array()
	for p in surface:
		edge.append(p + Vector2(0, -2))
	draw_polyline(edge, INK, 4.0, true)
	match map.weather:
		&"none":
			# Deck planks.
			for x in range(-int(HALF_WIDTH), int(HALF_WIDTH), 70):
				draw_line(_g(x + rng.randf_range(-6, 6), 4), _g(x, 28), map.ground_top.darkened(0.3), 2.0)
			for i in 200:
				draw_circle(_g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(8.0, 26.0)), 1.5, map.ground_top.darkened(0.2), true, -1.0, true)
		&"rain":
			for i in 40:
				var at := _g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(8.0, 22.0))
				draw_set_transform(at, 0.0, Vector2(1.0, 0.25))
				draw_circle(Vector2.ZERO, rng.randf_range(18.0, 40.0), Color(0.55, 0.45, 0.85, 0.35), true, -1.0, true)
			draw_set_transform(Vector2(0, _lift))
			for x in range(-int(HALF_WIDTH), int(HALF_WIDTH), 120):
				draw_line(_g(x, 2), _g(x, 30), map.ground_top.darkened(0.3), 2.0)
		&"dust":
			# Sun-baked cracks in the dirt.
			for i in 70:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				var crack := PackedVector2Array([_g(x, 6), _g(x + rng.randf_range(-14, 14), 14), _g(x + rng.randf_range(-20, 20), 24)])
				draw_polyline(crack, map.ground_top.darkened(0.3), 2.0, true)
		&"leaves", &"fireflies":
			# Grass, with fallen leaves in the dojo.
			for i in 500:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				var h := rng.randf_range(6.0, 14.0)
				draw_line(_g(x, 0), _g(x - 3, -h), map.ground_top.darkened(0.2), 2.5, true)
			if map.weather == &"leaves":
				for i in 60:
					var at := _g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(-4.0, 20.0))
					draw_set_transform(at, rng.randf_range(0, TAU), Vector2(1.0, 0.45))
					draw_circle(Vector2.ZERO, 6.0, [Color(0.95, 0.6, 0.25), Color(0.85, 0.35, 0.25), Color(0.6, 0.75, 0.3)][i % 3], true, -1.0, true)
				draw_set_transform(Vector2(0, _lift))
		&"petals":
			for i in 500:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				var h := rng.randf_range(6.0, 13.0)
				draw_line(_g(x, 0), _g(x - 3, -h), map.ground_top.darkened(0.15), 2.5, true)
			for i in 50:
				draw_circle(_g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), -5), 4.0, [Color(1, 0.7, 0.85), Color.WHITE, Color(1, 0.9, 0.4)][i % 3], true, -1.0, true)
	match map.weather:
		&"snow":
			for i in 600:
				draw_circle(_g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0)), rng.randf_range(1.0, 2.4), Color(0.7, 0.82, 0.95) if i % 3 else Color.WHITE, true, -1.0, true)
			for i in 60:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				draw_line(_g(x, 8), _g(x + rng.randf_range(-20, 20), 22), Color(0.6, 0.78, 0.95), 2.0, true)
		&"ash":
			for i in 500:
				draw_circle(_g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0)), rng.randf_range(1.0, 2.6), map.ground_top.lightened(rng.randf_range(0.05, 0.2)), true, -1.0, true)
			var pulse := 0.6 + 0.4 * sin(_time * 2.5)
			for i in 40:
				var x := rng.randf_range(-HALF_WIDTH, HALF_WIDTH)
				var crack := PackedVector2Array([_g(x, 4), _g(x + 8, 12), _g(x + 2, 20), _g(x + 12, 28)])
				draw_polyline(crack, Color(map.fire_color, 0.8 * pulse), 2.5, true)
		_:
			for i in 700:
				draw_circle(_g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(6.0, 28.0)), rng.randf_range(1.0, 2.6), map.ground_top.darkened(rng.randf_range(0.1, 0.25)), true, -1.0, true)
	for i in 30:
		var at := _g(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(10.0, 22.0))
		draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, rng.randf_range(5.0, 9.0), map.obstacle_dark, true, -1.0, true)
		draw_circle(Vector2(-2, -2), 3.0, map.obstacle_stone, true, -1.0, true)
	draw_set_transform(Vector2(0, _lift))


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
	draw_set_transform(Vector2(x, -2 + _lift), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 90.0, INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 84.0, map.fire_color, true, -1.0, true)
	draw_circle(Vector2(-10, -10), 54.0, map.fire_color.lightened(0.3 * pulse), true, -1.0, true)
	draw_set_transform(Vector2(0, _lift))
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
	glow.position = at + Vector2(0, Terrain.height_at(at.x))
	_lights.add_child(glow)
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
	flame.position = at + Vector2(0, Terrain.height_at(at.x))
	_lights.add_child(flame)


## A soft coloured glow with no flame (neon lights).
func _add_glow(at: Vector2, size: float) -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Sprite2D.new()
	glow.texture = _glow
	glow.material = additive
	glow.modulate = Color(map.fire_color, 0.5)
	glow.scale = Vector2.ONE * 7.0 * size
	glow.position = at + Vector2(0, Terrain.height_at(at.x))
	_lights.add_child(glow)
	var flicker := glow.create_tween().set_loops()
	flicker.tween_property(glow, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(glow, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)


func _add_weather() -> void:
	if map.weather == &"none":
		return
	var particles := CPUParticles2D.new()
	particles.texture = _glow
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.z_index = 15
	var ramp := Gradient.new()
	match map.weather:
		&"rain":
			var streak := GradientTexture2D.new()
			var fade := Gradient.new()
			fade.set_color(0, Color(1, 1, 1, 0))
			fade.set_color(1, Color(1, 1, 1, 1))
			streak.gradient = fade
			streak.fill_from = Vector2(0, 0)
			streak.fill_to = Vector2(0, 1)
			streak.width = 2
			streak.height = 26
			particles.texture = streak
			particles.particle_flag_align_y = true
			particles.amount = 260
			particles.lifetime = 1.4
			particles.preprocess = 1.4
			particles.emission_rect_extents = Vector2(2600, 40)
			particles.position = Vector2(0, -900)
			particles.direction = Vector2(0.15, 1)
			particles.spread = 3.0
			particles.gravity = Vector2(0, 0)
			particles.initial_velocity_min = 650.0
			particles.initial_velocity_max = 800.0
			particles.scale_amount_min = 1.0
			particles.scale_amount_max = 1.4
			ramp.set_color(0, Color(0.7, 0.75, 1.0, 0.0))
			ramp.set_color(1, Color(0.7, 0.75, 1.0, 0.0))
			ramp.add_point(0.1, Color(0.7, 0.75, 1.0, 0.55))
			ramp.add_point(0.9, Color(0.7, 0.75, 1.0, 0.55))
		&"petals":
			particles.amount = 90
			particles.lifetime = 10.0
			particles.preprocess = 10.0
			particles.emission_rect_extents = Vector2(2600, 40)
			particles.position = Vector2(0, -800)
			particles.direction = Vector2(0.4, 1)
			particles.spread = 30.0
			particles.gravity = Vector2(10, 20)
			particles.initial_velocity_min = 30.0
			particles.initial_velocity_max = 70.0
			particles.angular_velocity_min = -120.0
			particles.angular_velocity_max = 120.0
			particles.scale_amount_min = 0.16
			particles.scale_amount_max = 0.3
			ramp.set_color(0, Color(1, 0.75, 0.88, 0))
			ramp.set_color(1, Color(1, 0.75, 0.88, 0))
			ramp.add_point(0.1, Color(1, 0.75, 0.88, 0.95))
			ramp.add_point(0.9, Color(1, 0.85, 0.92, 0.95))
		&"dust":
			particles.amount = 140
			particles.lifetime = 6.0
			particles.preprocess = 6.0
			particles.emission_rect_extents = Vector2(2600, 220)
			particles.position = Vector2(-300, -200)
			particles.direction = Vector2(1, -0.05)
			particles.spread = 10.0
			particles.gravity = Vector2(20, 4)
			particles.initial_velocity_min = 90.0
			particles.initial_velocity_max = 180.0
			particles.scale_amount_min = 0.08
			particles.scale_amount_max = 0.22
			ramp.set_color(0, Color(map.ground_top, 0))
			ramp.set_color(1, Color(map.ground_top, 0))
			ramp.add_point(0.2, Color(map.ground_top.lightened(0.15), 0.7))
			ramp.add_point(0.8, Color(map.ground_top, 0.5))
		&"leaves":
			particles.amount = 70
			particles.lifetime = 10.0
			particles.preprocess = 10.0
			particles.emission_rect_extents = Vector2(2600, 40)
			particles.position = Vector2(0, -800)
			particles.direction = Vector2(0.5, 1)
			particles.spread = 30.0
			particles.gravity = Vector2(14, 20)
			particles.initial_velocity_min = 30.0
			particles.initial_velocity_max = 70.0
			particles.angular_velocity_min = -160.0
			particles.angular_velocity_max = 160.0
			particles.scale_amount_min = 0.16
			particles.scale_amount_max = 0.3
			ramp.set_color(0, Color(0.6, 0.8, 0.3, 0))
			ramp.set_color(1, Color(0.95, 0.6, 0.25, 0))
			ramp.add_point(0.1, Color(0.6, 0.82, 0.3, 0.95))
			ramp.add_point(0.9, Color(0.95, 0.62, 0.28, 0.95))
		&"fireflies":
			var glow_blend := CanvasItemMaterial.new()
			glow_blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			particles.material = glow_blend
			particles.amount = 60
			particles.lifetime = 6.0
			particles.preprocess = 6.0
			particles.emission_rect_extents = Vector2(2400, 160)
			particles.position = Vector2(0, -170)
			particles.direction = Vector2.UP
			particles.spread = 180.0
			particles.gravity = Vector2(0, -4)
			particles.initial_velocity_min = 8.0
			particles.initial_velocity_max = 30.0
			particles.scale_amount_min = 0.08
			particles.scale_amount_max = 0.18
			ramp.set_color(0, Color(map.fire_color, 0))
			ramp.set_color(1, Color(map.fire_color, 0))
			ramp.add_point(0.3, Color(map.fire_color, 0.9))
			ramp.add_point(0.5, Color(map.fire_color, 0.2))
			ramp.add_point(0.7, Color(map.fire_color, 0.9))
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
	particles.amount = maxi(10, roundi(particles.amount * Device.particle_scale()))
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


# --- pirate cove, neon rooftops, sky islands props ---

## A ship's mast with a striped sail, rigging and a crow's nest.
func _draw_mast(x: float) -> void:
	var wood := Color(0.42, 0.27, 0.16)
	draw_rect(Rect2(x - 9, -460, 18, 460), INK)
	draw_rect(Rect2(x - 6, -460, 12, 460), wood)
	draw_rect(Rect2(x - 70, -400, 140, 8), wood)
	var sail := PackedVector2Array([Vector2(x - 64, -392), Vector2(x + 64, -392), Vector2(x + 76, -230), Vector2(x - 76, -230)])
	draw_colored_polygon(sail, Color(0.96, 0.93, 0.84))
	for stripe in 3:
		var y := -360.0 + stripe * 50.0
		draw_rect(Rect2(x - 66 - stripe * 3, y, 132 + stripe * 6, 16), Color(0.82, 0.22, 0.24))
	var outline := sail.duplicate()
	outline.append(sail[0])
	draw_polyline(outline, INK, 3.0, true)
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(x, -455), Vector2(x + side * 120, 0), Color(0.3, 0.22, 0.16), 2.0, true)
	draw_rect(Rect2(x - 26, -330, 52, 22), INK)
	draw_rect(Rect2(x - 23, -327, 46, 16), wood.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(x, -460), Vector2(x + 44, -448), Vector2(x, -436)]), Color(0.1, 0.08, 0.08))


func _draw_barrels(x: float, rng: RandomNumberGenerator) -> void:
	var spots := [Vector2(-34, 0), Vector2(34, 0), Vector2(0, -62)]
	for spot: Vector2 in spots:
		var base := Vector2(x, 0) + spot
		var barrel := Rect2(base + Vector2(-28, -62), Vector2(56, 62))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.6, 0.4, 0.24).darkened(rng.randf_range(0.0, 0.15))
		box.border_color = INK
		box.set_border_width_all(3)
		box.set_corner_radius_all(14)
		box.anti_aliasing = true
		draw_style_box(box, barrel)
		for band: float in [0.22, 0.78]:
			draw_line(barrel.position + Vector2(3, barrel.size.y * band), barrel.position + Vector2(barrel.size.x - 3, barrel.size.y * band), Color(0.3, 0.3, 0.34), 5.0)


## A rooftop water tower on stilts, with a blinking antenna.
func _draw_water_tower(x: float) -> void:
	var metal := map.wall_color.lightened(0.15)
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(x + side * 40, 0), Vector2(x + side * 30, -200), INK, 7.0, true)
		draw_line(Vector2(x + side * 40, 0), Vector2(x + side * 30, -200), metal, 4.0, true)
	draw_line(Vector2(x - 36, -100), Vector2(x + 36, -100), metal, 4.0)
	var tank := Rect2(Vector2(x - 56, -330), Vector2(112, 130))
	draw_rect(tank.grow(3), INK)
	draw_rect(tank, Color(0.45, 0.32, 0.3))
	for k in 5:
		draw_line(Vector2(tank.position.x + 12 + k * 22, tank.position.y), Vector2(tank.position.x + 12 + k * 22, tank.end.y), Color(0.38, 0.27, 0.25), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 62, -330), Vector2(x, -380), Vector2(x + 62, -330)]), Color(0.3, 0.22, 0.22))
	draw_line(Vector2(x, -380), Vector2(x, -420), INK, 4.0)


## A lamp post with a glowing neon sign.
func _draw_neon_post(x: float) -> void:
	draw_line(Vector2(x, 0), Vector2(x, -150), INK, 8.0, true)
	draw_line(Vector2(x, 0), Vector2(x, -150), map.wall_color.lightened(0.25), 4.0, true)
	var sign_rect := Rect2(Vector2(x - 44, -184), Vector2(88, 34))
	draw_rect(sign_rect.grow(3), INK)
	draw_rect(sign_rect, Color(0.08, 0.04, 0.12))
	draw_rect(sign_rect.grow(-4), map.fire_color, false, 3.0)
	draw_line(sign_rect.position + Vector2(14, 17), sign_rect.end - Vector2(14, 17), map.fire_color.lightened(0.3), 3.0)


## A big round leafy tree.
func _draw_big_tree(x: float, rng: RandomNumberGenerator) -> void:
	var trunk := Rect2(Vector2(x - 14, -260), Vector2(28, 262))
	draw_rect(trunk.grow(3), INK)
	draw_rect(trunk, Color(0.48, 0.32, 0.22))
	var leaves := map.ground_top.darkened(0.1)
	var blobs := [Vector2(0, -330), Vector2(-60, -290), Vector2(60, -290), Vector2(-30, -380), Vector2(36, -370)]
	for blob: Vector2 in blobs:
		draw_circle(Vector2(x, 0) + blob, 62.0 + 3.0, INK, true, -1.0, true)
	for blob: Vector2 in blobs:
		draw_circle(Vector2(x, 0) + blob, 62.0, leaves.lightened(rng.randf_range(0.0, 0.1)), true, -1.0, true)
	for k in 6:
		draw_circle(Vector2(x + rng.randf_range(-80, 80), rng.randf_range(-400, -270)), 6.0, Color(1.0, 0.75, 0.85), true, -1.0, true)


func _draw_bush(x: float, rng: RandomNumberGenerator) -> void:
	for k in 4:
		var at := Vector2(x - 45 + k * 30, -22 - (k % 2) * 10)
		draw_circle(at, 30.0 + 3.0, INK, true, -1.0, true)
		draw_circle(at, 30.0, map.ground_top.darkened(0.2 + rng.randf_range(0.0, 0.08)), true, -1.0, true)


# --- desert canyon, bamboo dojo, haunted graveyard ---

## A big saguaro cactus.
func _draw_big_cactus(x: float, rng: RandomNumberGenerator) -> void:
	var green := Color(0.36, 0.6, 0.32)
	var h := rng.randf_range(260.0, 340.0)
	var box := StyleBoxFlat.new()
	box.bg_color = green
	box.border_color = INK
	box.set_border_width_all(4)
	box.set_corner_radius_all(22)
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	box.anti_aliasing = true
	for arm: float in [-1.0, 1.0]:
		var at := -h * rng.randf_range(0.45, 0.65)
		draw_style_box(box, Rect2(x + (22.0 if arm > 0 else -70.0), at, 48, 28))
		draw_style_box(box, Rect2(x + arm * 58.0 - 14, at - 90, 28, 112))
	draw_style_box(box, Rect2(x - 26, -h, 52, h + 4))
	for k: float in [-10.0, 10.0]:
		draw_line(Vector2(x + k, -h + 16), Vector2(x + k, -6), green.darkened(0.25), 3.0)
	draw_circle(Vector2(x, -h + 4), 8.0, Color(1.0, 0.5, 0.6), true, -1.0, true)


## A bleached cow skull on a heap of rocks.
func _draw_skull_rocks(x: float, rng: RandomNumberGenerator) -> void:
	for i in 4:
		var at := Vector2(x + rng.randf_range(-40, 40), -rng.randf_range(4, 18))
		draw_circle(at, rng.randf_range(14, 24), INK, true, -1.0, true)
		draw_circle(at, rng.randf_range(10, 18), map.obstacle_stone.darkened(rng.randf_range(0.0, 0.2)), true, -1.0, true)
	var skull := Vector2(x, -40)
	var bone := Color(0.96, 0.92, 0.84)
	draw_polyline(PackedVector2Array([skull + Vector2(-14, -6), skull + Vector2(-34, -12), skull + Vector2(-42, -30)]), INK, 8.0, true)
	draw_polyline(PackedVector2Array([skull + Vector2(14, -6), skull + Vector2(34, -12), skull + Vector2(42, -30)]), INK, 8.0, true)
	draw_polyline(PackedVector2Array([skull + Vector2(-14, -6), skull + Vector2(-34, -12), skull + Vector2(-42, -30)]), bone, 4.0, true)
	draw_polyline(PackedVector2Array([skull + Vector2(14, -6), skull + Vector2(34, -12), skull + Vector2(42, -30)]), bone, 4.0, true)
	var face := PackedVector2Array([skull + Vector2(-16, -10), skull + Vector2(16, -10), skull + Vector2(9, 22), skull + Vector2(-9, 22)])
	draw_colored_polygon(face, bone)
	var outline := face.duplicate()
	outline.append(face[0])
	draw_polyline(outline, INK, 3.0, true)
	draw_circle(skull + Vector2(-7, -1), 4.0, INK, true, -1.0, true)
	draw_circle(skull + Vector2(7, -1), 4.0, INK, true, -1.0, true)


## A stone garden lantern (lit from inside).
func _draw_stone_lantern(x: float) -> void:
	var stone := map.wall_color.lightened(0.35)
	var parts := [Rect2(x - 34, -24, 68, 24), Rect2(x - 12, -130, 24, 106), Rect2(x - 30, -150, 60, 20), Rect2(x - 24, -196, 48, 46)]
	for part: Rect2 in parts:
		draw_rect(part, stone)
		draw_rect(part, INK, false, 3.0)
	draw_rect(Rect2(x - 12, -186, 24, 26), Color(1.0, 0.8, 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 54, -196), Vector2(x, -232), Vector2(x + 54, -196)]), stone.darkened(0.15))
	draw_polyline(PackedVector2Array([Vector2(x - 54, -196), Vector2(x, -232), Vector2(x + 54, -196), Vector2(x - 54, -196)]), INK, 3.0, true)
	draw_circle(Vector2(x, -238), 7.0, stone.darkened(0.15), true, -1.0, true)


## A red paper lantern hanging from a bamboo pole.
func _draw_paper_lantern(x: float) -> void:
	draw_rect(Rect2(x - 4, -230, 8, 230), Color(0.55, 0.7, 0.3))
	draw_rect(Rect2(x - 4, -230, 8, 230), INK, false, 2.0)
	draw_line(Vector2(x, -226), Vector2(x + 50, -226), Color(0.45, 0.6, 0.25), 6.0)
	draw_line(Vector2(x + 44, -226), Vector2(x + 44, -204), INK, 2.0)
	var body := Vector2(x + 44, -172)
	draw_set_transform(body + Vector2(0, _lift), 0.0, Vector2(1.0, 1.3))
	draw_circle(Vector2.ZERO, 26.0, INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 23.0, Color(0.9, 0.22, 0.2), true, -1.0, true)
	draw_set_transform(Vector2(0, _lift))
	for k in 3:
		var y := body.y - 18 + k * 18
		draw_line(Vector2(body.x - 20, y), Vector2(body.x + 20, y), Color(0.65, 0.12, 0.12), 2.0)
	draw_rect(Rect2(body.x - 12, body.y - 36, 24, 6), INK)
	draw_rect(Rect2(body.x - 12, body.y + 30, 24, 6), INK)


## A crooked iron lamp post with a ghostly green flame.
func _draw_lamp_post(x: float) -> void:
	var iron := Color(0.16, 0.15, 0.2)
	draw_rect(Rect2(x - 20, -18, 40, 18), iron)
	draw_polyline(PackedVector2Array([Vector2(x, -18), Vector2(x + 6, -150), Vector2(x - 4, -260), Vector2(x + 2, -290)]), iron, 9.0, true)
	draw_polyline(PackedVector2Array([Vector2(x + 2, -290), Vector2(x + 30, -300), Vector2(x + 40, -284)]), iron, 5.0, true)
	var lamp := Rect2(x + 26, -284, 28, 34)
	draw_rect(lamp, Color(map.fire_color, 0.35))
	draw_rect(lamp, iron, false, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(lamp.position.x - 4, lamp.position.y), Vector2(lamp.get_center().x, lamp.position.y - 14), Vector2(lamp.end.x + 4, lamp.position.y)]), iron)


## A small grave with a candle burning on it.
func _draw_candle_grave(x: float, rng: RandomNumberGenerator) -> void:
	var stone := map.obstacle_stone.darkened(0.2)
	var tilt := rng.randf_range(-0.15, 0.15)
	draw_set_transform(Vector2(x, _lift), tilt)
	var outline := PackedVector2Array([Vector2(-26, 2)])
	for k in 9:
		var a := PI + PI * k / 8.0
		outline.append(Vector2(cos(a) * 26.0, -60 + sin(a) * 22.0))
	outline.append(Vector2(26, 2))
	draw_colored_polygon(outline, stone)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, INK, 3.0, true)
	draw_line(Vector2(0, -66), Vector2(0, -30), stone.darkened(0.3), 4.0)
	draw_line(Vector2(-10, -54), Vector2(10, -54), stone.darkened(0.3), 4.0)
	draw_set_transform(Vector2(0, _lift))
	draw_rect(Rect2(x + 30, -26, 8, 26), Color(0.95, 0.92, 0.8))
	draw_rect(Rect2(x + 30, -26, 8, 26), INK, false, 2.0)
