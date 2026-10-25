class_name Backdrop
extends Node2D
## Everything behind the arena, themed by a MapData: sky, stars, sun or aurora,
## clouds, two mountain ridges, then the map's scenery (colosseum stands with a
## crowd, a pine forest with an ice castle, a smoking volcano, desert mesas, a bamboo
## grove with a pagoda, or a foggy graveyard).
## Each layer has a depth from 0 (pinned to the screen) to 1 (moves with the world).

const INK := Color(0.12, 0.1, 0.14)
const HALF_WIDTH := 3200.0
const CLOUD_WRAP := 2600.0
const ARCH_SPACING := 120.0
const STONE := Color(0.78, 0.55, 0.47)
const STONE_SHADE := Color(0.6, 0.4, 0.4)
const ARCH_DARK := Color(0.24, 0.13, 0.24)
const BANNER_COLORS := [Color(0.82, 0.2, 0.25), Color(0.22, 0.38, 0.78), Color(0.95, 0.72, 0.2)]

var camera: Camera2D
## Set before adding to the tree.
var map: MapData

var _layers: Array[Node2D] = []
var _depths: Array[float] = []
var _animated: Array[Node2D] = []
var _clouds: Array[Dictionary] = []
var _stars := PackedVector3Array()
var _crowd: Array[Dictionary] = []
var _time := 0.0
## How worked up the crowd is (0..1): big moments raise it and it calms down again.
var excitement := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_physics_priority = 10  # after the camera has moved this tick
	_noise.seed = 4 + map.id.hash() % 7
	_noise.frequency = 0.0015
	_rng.seed = 11
	_add_sky()
	_animated.append(_add_layer(0.0, _draw_stars))
	match map.sky_feature:
		&"aurora":
			_animated.append(_add_layer(0.02, _draw_aurora))
		&"moon":
			_animated.append(_add_layer(0.02, _draw_moon))
		_:
			_animated.append(_add_layer(0.02, _draw_sun))
	_animated.append(_add_layer(0.06, _draw_clouds))
	match map.scenery:
		&"ocean":
			_add_layer(0.16, _draw_far_islands)
			_animated.append(_add_layer(0.3, _draw_sea))
			_animated.append(_add_layer(0.36, _draw_ships))
		&"city":
			_add_layer(0.18, _draw_skyline_far)
			_animated.append(_add_layer(0.42, _draw_skyline_near))
		&"islands":
			_animated.append(_add_layer(0.16, _draw_floating_islands_far))
			_animated.append(_add_layer(0.34, _draw_cloud_sea))
			_animated.append(_add_layer(0.46, _draw_floating_islands_near))
		_:
			_animated.append(_add_layer(0.16, _draw_far_mountains))
	match map.scenery:
		&"ocean", &"city", &"islands":
			pass
		&"desert":
			_add_layer(0.3, _draw_mesas)
			_add_layer(0.5, _draw_dunes)
		&"bamboo":
			_add_layer(0.2, _draw_pagoda)
			_animated.append(_add_layer(0.36, _draw_bamboo_back))
			_animated.append(_add_layer(0.52, _draw_bamboo_front))
		&"graveyard":
			_add_layer(0.3, _draw_near_mountains)
			_add_layer(0.46, _draw_graves)
			_animated.append(_add_layer(0.5, _draw_fog))
		&"forest":
			_add_layer(0.3, _draw_near_mountains)
			_add_layer(0.42, _draw_forest_back)
			_add_layer(0.55, _draw_forest_front)
		&"volcano":
			_animated.append(_add_layer(0.3, _draw_volcano))
			_animated.append(_add_layer(0.48, _draw_spires))
		_:
			_add_layer(0.3, _draw_near_mountains)
			_add_layer(0.48, _draw_stands)
			_animated.append(_add_layer(0.48, _draw_crowd_and_banners))

	for i in 80:
		_stars.append(Vector3(_rng.randf_range(-1100, 1100), _rng.randf_range(-420, -150), _rng.randf_range(0, TAU)))
	for i in 8:
		_clouds.append({
			"x": _rng.randf_range(-CLOUD_WRAP, CLOUD_WRAP),
			"y": _rng.randf_range(-330.0, -140.0),
			"scale": _rng.randf_range(0.8, 1.8),
			"speed": _rng.randf_range(6.0, 16.0),
		})
	for arch in range(-int(HALF_WIDTH / ARCH_SPACING), int(HALF_WIDTH / ARCH_SPACING)):
		for seat in 3:
			_crowd.append({
				"x": arch * ARCH_SPACING + 26.0 + seat * 22.0 + _rng.randf_range(-3, 3),
				"tier": seat % 2,
				"phase": _rng.randf_range(0, TAU),
				"color": Color.from_hsv(_rng.randf(), 0.35, 0.45),
			})


func _process(delta: float) -> void:
	_time += delta
	excitement = maxf(0.0, excitement - delta * 0.45)
	for cloud in _clouds:
		cloud["x"] = wrapf(cloud["x"] + cloud["speed"] * delta, -CLOUD_WRAP, CLOUD_WRAP)
	for layer in _animated:
		layer.queue_redraw()


## Layers move on physics ticks, like the camera, so both are interpolated together.
func _physics_process(_delta: float) -> void:
	if camera == null:
		return
	# A layer at depth d scrolls and zooms by d of the camera's amount.
	var zoom := camera.zoom.x
	for i in _layers.size():
		var depth := _depths[i]
		var layer_scale := lerpf(1.0 / zoom, 1.0, depth)
		_layers[i].scale = Vector2(layer_scale, layer_scale)
		_layers[i].position = camera.get_screen_center_position() * (1.0 - depth)


func _add_sky() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -100
	var gradient := Gradient.new()
	gradient.set_color(0, map.sky_top)
	gradient.set_color(1, map.sky_horizon)
	gradient.add_point(0.42, map.sky_mid)
	gradient.add_point(0.75, map.sky_low)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(rect)
	add_child(sky)


func _add_layer(depth: float, painter: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.draw.connect(painter.bind(layer))
	add_child(layer)
	_layers.append(layer)
	_depths.append(depth)
	return layer


func _draw_stars(canvas: Node2D) -> void:
	for star in _stars:
		var fade := clampf((-star.y - 150.0) / 200.0, 0.0, 1.0) * clampf(map.star_amount, 0.0, 1.0)
		var twinkle := 0.55 + 0.45 * sin(_time * 2.0 + star.z)
		var size := 1.2 + twinkle * clampf(map.star_amount, 0.5, 1.5)
		canvas.draw_circle(Vector2(star.x, star.y), size, Color(1, 0.95, 0.85, fade * twinkle), true, -1.0, true)


func _draw_sun(canvas: Node2D) -> void:
	var at := Vector2(-150, -120)
	for i in 12:
		var a := _time * 0.05 + i * TAU / 12
		var ray := PackedVector2Array([at, at + Vector2.from_angle(a - 0.06) * 1400, at + Vector2.from_angle(a + 0.06) * 1400])
		canvas.draw_colored_polygon(ray, Color(map.sun_color, 0.05))
	for i in 5:
		canvas.draw_circle(at, 110.0 + i * 40.0, Color(map.sun_glow, 0.08), true, -1.0, true)
	canvas.draw_circle(at, 95.0, map.sun_color.darkened(0.05), true, -1.0, true)
	canvas.draw_circle(at, 80.0, map.sun_color.lightened(0.3), true, -1.0, true)


## Waving ribbons of green and violet light, plus a small cold moon.
func _draw_aurora(canvas: Node2D) -> void:
	var moon := Vector2(420, -300)
	for i in 4:
		canvas.draw_circle(moon, 46.0 + i * 22.0, Color(map.sun_glow, 0.07), true, -1.0, true)
	canvas.draw_circle(moon, 40.0, map.sun_color, true, -1.0, true)
	canvas.draw_circle(moon + Vector2(12, -8), 9.0, map.sun_color.darkened(0.08), true, -1.0, true)
	for band in 3:
		var color := Color(0.35, 1.0, 0.65, 0.16) if band != 1 else Color(0.65, 0.45, 1.0, 0.14)
		for strand in 2:
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for k in 40:
				var x := -1300.0 + k * 66.0
				var y := -360.0 + band * 55.0 + sin(x * 0.004 + _time * 0.4 + band) * 50.0 + sin(x * 0.011 - _time * 0.7) * 18.0
				top.append(Vector2(x, y - 40.0 - strand * 30.0))
				bottom.append(Vector2(x, y + 30.0))
			var ribbon := top.duplicate()
			bottom.reverse()
			ribbon.append_array(bottom)
			canvas.draw_colored_polygon(ribbon, color)


func _draw_clouds(canvas: Node2D) -> void:
	for cloud in _clouds:
		var at := Vector2(cloud["x"], cloud["y"])
		var s: float = cloud["scale"]
		for p in 4:
			var offset := Vector2(-70 + p * 48, sin(p * 1.7) * 6) * s
			canvas.draw_set_transform(at + offset + Vector2(0, 6 * s), 0.0, Vector2(2.4, 0.7))
			canvas.draw_circle(Vector2.ZERO, 26.0 * s, Color(map.cloud_shade, 0.55), true, -1.0, true)
			canvas.draw_set_transform(at + offset, 0.0, Vector2(2.4, 0.7))
			canvas.draw_circle(Vector2.ZERO, 24.0 * s, Color(map.cloud_color, 0.7), true, -1.0, true)
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_far_mountains(canvas: Node2D) -> void:
	_draw_ridge(canvas, -40.0, 280.0, 0.6, map.far_color)
	if map.scenery == &"forest":
		# Snow caps on the higher peaks.
		for x in range(-int(HALF_WIDTH), int(HALF_WIDTH), 24):
			var h := _ridge_height(float(x), 280.0, 0.6)
			if h > 220.0:
				canvas.draw_circle(Vector2(x, -40.0 - h + 8.0), 14.0, Color(0.92, 0.96, 1.0, 0.9), true, -1.0, true)
	if map.scenery == &"volcano" or map.scenery == &"desert" or map.scenery == &"bamboo":
		return
	# A castle on the tallest nearby peak (an ice castle in the snow).
	var castle_x := -760.0
	var ground := -40.0 - _ridge_height(castle_x, 280.0, 0.6) + 10.0
	var color := map.far_color.darkened(0.25)
	var light := Color(1.0, 0.8, 0.4) if map.scenery != &"forest" else Color(0.6, 0.95, 1.0)
	var towers := [[-60.0, 90.0, 22.0], [-20.0, 60.0, 50.0], [30.0, 130.0, 26.0], [70.0, 70.0, 34.0]]
	for tower: Array in towers:
		var x: float = castle_x + tower[0]
		var h: float = tower[1]
		var w: float = tower[2]
		canvas.draw_rect(Rect2(x, ground - h, w, h + 40), color)
		for k in int(w / 8):
			canvas.draw_rect(Rect2(x + k * 8, ground - h - 7, 5, 8), color)
		if h > 80:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, ground - h), Vector2(x + w / 2, ground - h - 34), Vector2(x + w + 4, ground - h)]), color)
			canvas.draw_line(Vector2(x + w / 2, ground - h - 34), Vector2(x + w / 2, ground - h - 54), color, 2.0)
			var wave := sin(_time) * 2.0
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + w / 2, ground - h - 54), Vector2(x + w / 2 + 16, ground - h - 50 + wave), Vector2(x + w / 2, ground - h - 45)]), Color(0.9, 0.35, 0.3))
		canvas.draw_rect(Rect2(x + w * 0.4, ground - h * 0.6, 3, 6), light)


func _draw_near_mountains(canvas: Node2D) -> void:
	_draw_ridge(canvas, 0.0, 200.0, 1.3, map.near_color)


# --- colosseum ---

## Two tiers of arches. Some stretches are ruined down to the lower tier.
func _draw_stands(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	canvas.draw_rect(Rect2(-HALF_WIDTH, -40, HALF_WIDTH * 2, 2000), STONE_SHADE)
	for i in range(-int(HALF_WIDTH / ARCH_SPACING), int(HALF_WIDTH / ARCH_SPACING)):
		var x := i * ARCH_SPACING
		var ruined := rng.randf() < 0.22
		var top := -110.0 if ruined else -190.0 - rng.randf_range(0, 10)
		canvas.draw_rect(Rect2(x, top, ARCH_SPACING, 2000), STONE)
		canvas.draw_rect(Rect2(x, top, ARCH_SPACING, 6), STONE.lightened(0.2))
		_arch(canvas, Rect2(x + 24, -92, ARCH_SPACING - 48, 66))
		if not ruined:
			_arch(canvas, Rect2(x + 32, -172, ARCH_SPACING - 64, 52))
			canvas.draw_rect(Rect2(x, -116, ARCH_SPACING, 10), STONE_SHADE)
		else:
			for k in 3:
				canvas.draw_rect(Rect2(x + rng.randf_range(0, ARCH_SPACING - 20), top - rng.randf_range(4, 22), rng.randf_range(10, 24), 24), STONE)
		canvas.draw_rect(Rect2(x - 5, top, 10, 2000), STONE.lightened(0.08))
	canvas.draw_rect(Rect2(-HALF_WIDTH, -26, HALF_WIDTH * 2, 30), STONE_SHADE.darkened(0.15))


func _arch(canvas: Node2D, rect: Rect2) -> void:
	var r := rect.size.x / 2
	var points := PackedVector2Array([rect.position + Vector2(0, rect.size.y), rect.position + Vector2(0, r)])
	for k in 13:
		points.append(rect.position + Vector2(r, r) + Vector2.from_angle(PI + PI * k / 12.0) * r)
	points.append(rect.end)
	canvas.draw_colored_polygon(points, ARCH_DARK)


func _draw_crowd_and_banners(canvas: Node2D) -> void:
	for fan in _crowd:
		var bounce := maxf(0.0, sin(_time * (5.0 + excitement * 7.0) + fan["phase"])) * (5.0 + excitement * 16.0)
		var base := Vector2(fan["x"], -30.0 - bounce - fan["tier"] * 8.0)
		var color: Color = fan["color"]
		canvas.draw_circle(base + Vector2(0, -10), 9.0, color, true, -1.0, true)
		canvas.draw_rect(Rect2(base + Vector2(-9, -2), Vector2(18, 20)), color)
		if int(fan["phase"] * 10) % 3 == 0 or excitement > 0.35:
			canvas.draw_line(base + Vector2(6, -2), base + Vector2(12, -24 - bounce), color, 4.0, true)
	for i in range(-int(HALF_WIDTH / ARCH_SPACING), int(HALF_WIDTH / ARCH_SPACING), 4):
		var x := i * ARCH_SPACING + ARCH_SPACING * 0.5
		var color: Color = BANNER_COLORS[posmod(i / 4, BANNER_COLORS.size())]
		var sway := sin(_time * 1.6 + i) * 4.0
		var banner := PackedVector2Array([
			Vector2(x - 16, -186), Vector2(x + 16, -186),
			Vector2(x + 16 + sway, -126), Vector2(x + sway, -110), Vector2(x - 16 + sway, -126),
		])
		canvas.draw_colored_polygon(banner, color)
		canvas.draw_line(Vector2(x - 21, -186), Vector2(x + 21, -186), Color(0.35, 0.22, 0.15), 5.0)
		canvas.draw_circle(Vector2(x + sway * 0.5, -152), 8.0, Color(1.0, 0.85, 0.4), true, -1.0, true)
		canvas.draw_circle(Vector2(x + sway * 0.5, -152), 4.5, color.darkened(0.2), true, -1.0, true)


# --- frozen peaks ---

func _draw_forest_back(canvas: Node2D) -> void:
	_draw_forest(canvas, 0)


func _draw_forest_front(canvas: Node2D) -> void:
	_draw_forest(canvas, 1)


## Rows of snowy pines. row 0 is further back (bluer, smaller).
func _draw_forest(canvas: Node2D, row: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + row
	var base := map.near_color.lerp(map.far_color, 0.4 - row * 0.4)
	var trunk := base.darkened(0.35)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -20, HALF_WIDTH * 2, 2000), base.darkened(0.15 + row * 0.1))
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var s := rng.randf_range(0.7, 1.3) * (0.8 + row * 0.35)
		var tree := base.darkened(rng.randf_range(0.0, 0.15) + row * 0.12)
		var ground := -10.0 + rng.randf_range(-6, 6)
		canvas.draw_rect(Rect2(x - 5 * s, ground - 20 * s, 10 * s, 24 * s), trunk)
		for tier in 3:
			var top := Vector2(x, ground - (150 - tier * 38) * s)
			var w := (30.0 + tier * 14.0) * s
			canvas.draw_colored_polygon(PackedVector2Array([top, top + Vector2(w, 62 * s), top + Vector2(-w, 62 * s)]), tree)
			# Snow sitting on each tier.
			canvas.draw_colored_polygon(PackedVector2Array([top, top + Vector2(w * 0.55, 34 * s), top + Vector2(w * 0.1, 30 * s), top + Vector2(-w * 0.3, 36 * s), top + Vector2(-w * 0.55, 34 * s)]), Color(0.93, 0.97, 1.0, 0.95))
		x += rng.randf_range(70, 130) * (0.8 + row * 0.3)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -14, HALF_WIDTH * 2, 20), Color(0.88, 0.94, 1.0, 0.9 if row == 1 else 0.6))


# --- lava forge ---

## A big volcano with a glowing crater, lava streams and a smoke plume.
func _draw_volcano(canvas: Node2D) -> void:
	_draw_ridge(canvas, 0.0, 160.0, 1.3, map.near_color)
	var peak := Vector2(180, -330)
	var cone := PackedVector2Array([Vector2(-700, 40), peak + Vector2(-70, 0), peak + Vector2(70, 0), Vector2(1100, 40)])
	canvas.draw_colored_polygon(cone, map.far_color.darkened(0.1))
	var pulse := 0.6 + 0.4 * sin(_time * 2.0)
	for i in 4:
		canvas.draw_circle(peak + Vector2(0, -10), 80.0 + i * 40.0, Color(map.fire_color, 0.08 * pulse), true, -1.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([peak + Vector2(-70, 0), peak + Vector2(-40, -14), peak + Vector2(40, -14), peak + Vector2(70, 0)]), map.fire_color.lightened(0.3))
	for stream in 3:
		var points := PackedVector2Array()
		var start := peak + Vector2(-40 + stream * 40, 0)
		for k in 12:
			var t := k / 11.0
			points.append(start + Vector2(sin(t * 6.0 + stream) * 24.0 + (stream - 1) * t * 200.0, t * 330.0))
		canvas.draw_polyline(points, Color(map.fire_color, 0.85), 10.0 - stream * 2.0, true)
		canvas.draw_polyline(points, Color(1.0, 0.85, 0.4, 0.7 * pulse), 3.0, true)
	for i in 10:
		var t := fmod(_time * 0.08 + i * 0.1, 1.0)
		var puff := peak + Vector2(sin(i * 2.3) * 40.0 + t * 260.0, -30.0 - t * 380.0)
		canvas.draw_circle(puff, 40.0 + t * 90.0, Color(0.15, 0.1, 0.12, 0.35 * (1.0 - t)), true, -1.0, true)


## Jagged basalt spires with glowing lava cracks, closer to the arena.
func _draw_spires(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var dark := map.near_color.darkened(0.3)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -30, HALF_WIDTH * 2, 2000), dark)
	var pulse := 0.6 + 0.4 * sin(_time * 3.0)
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var w := rng.randf_range(40, 90)
		var h := rng.randf_range(90, 240)
		var tip := Vector2(x + w * rng.randf_range(0.3, 0.7), -30 - h)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, -20), Vector2(x + w * 0.15, -30 - h * 0.6), tip, Vector2(x + w * 0.85, -30 - h * 0.5), Vector2(x + w, -20)]), dark.lightened(rng.randf_range(0.0, 0.08)))
		if rng.randf() < 0.5:
			var crack := PackedVector2Array([tip + Vector2(0, 30), tip + Vector2(-6, 70), tip + Vector2(4, 110)])
			canvas.draw_polyline(crack, Color(map.fire_color, 0.8 * pulse), 3.0, true)
		x += w * rng.randf_range(0.7, 1.4)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -26, HALF_WIDTH * 2, 6), Color(map.fire_color, 0.5 * pulse))


func _ridge_height(x: float, height: float, frequency: float) -> float:
	var n := _noise.get_noise_1d(x * frequency) * 0.7 + _noise.get_noise_1d(x * frequency * 3.1 + 500.0) * 0.3
	return height * (0.55 + 0.45 * n)


## A filled silhouette from noise. It runs well below the horizon so no gap shows.
func _draw_ridge(canvas: Node2D, base_y: float, height: float, frequency: float, color: Color) -> void:
	var points := PackedVector2Array()
	for x in range(-int(HALF_WIDTH), int(HALF_WIDTH) + 1, 40):
		points.append(Vector2(x, base_y - _ridge_height(float(x), height, frequency)))
	points.append(Vector2(HALF_WIDTH, 2000))
	points.append(Vector2(-HALF_WIDTH, 2000))
	canvas.draw_colored_polygon(points, color)


# --- neon rooftops / pirate cove / sky islands ---

func _draw_moon(canvas: Node2D) -> void:
	var moon := Vector2(380, -280)
	for i in 5:
		canvas.draw_circle(moon, 50.0 + i * 26.0, Color(map.sun_glow, 0.06), true, -1.0, true)
	canvas.draw_circle(moon, 44.0, map.sun_color, true, -1.0, true)
	canvas.draw_circle(moon + Vector2(14, -10), 10.0, map.sun_color.darkened(0.08), true, -1.0, true)
	canvas.draw_circle(moon + Vector2(-12, 12), 6.0, map.sun_color.darkened(0.08), true, -1.0, true)


## Low green islands on the horizon.
func _draw_far_islands(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var w := rng.randf_range(160, 420)
		var h := rng.randf_range(30, 90)
		var hump := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			hump.append(Vector2(x + w * t, -30 - sin(t * PI) * h))
		hump.append(Vector2(x + w, 40))
		hump.append(Vector2(x, 40))
		canvas.draw_colored_polygon(hump, map.far_color)
		if rng.randf() < 0.5:
			var palm := Vector2(x + w * 0.5, -30 - h)
			canvas.draw_line(palm, palm + Vector2(6, -34), map.far_color.darkened(0.25), 4.0, true)
			for k in 4:
				canvas.draw_line(palm + Vector2(6, -34), palm + Vector2(6, -34) + Vector2.from_angle(PI + k * PI / 3) * 18.0, map.far_color.darkened(0.25), 3.0, true)
		x += w + rng.randf_range(200, 600)


## Open sea with rolling wave lines.
func _draw_sea(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(-HALF_WIDTH, -40, HALF_WIDTH * 2, 2000), map.near_color)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -40, HALF_WIDTH * 2, 8), map.near_color.lightened(0.35))
	for row in 6:
		var y := -24.0 + row * 22.0
		var wave := PackedVector2Array()
		for k in 90:
			var x := -HALF_WIDTH + k * 72.0
			wave.append(Vector2(x, y + sin(x * 0.02 + _time * (1.2 + row * 0.2) + row) * 4.0))
		canvas.draw_polyline(wave, Color(1, 1, 1, 0.22 - row * 0.025), 3.0, true)


## Distant sailing ships drifting along the horizon.
func _draw_ships(canvas: Node2D) -> void:
	for i in 3:
		var x := fmod(-1400.0 + i * 1100.0 + _time * (10.0 + i * 4.0), 3200.0) - 1600.0
		var bob := sin(_time * 1.5 + i) * 3.0
		var base := Vector2(x, -44 + bob)
		var hull := PackedVector2Array([base + Vector2(-70, 0), base + Vector2(70, 0), base + Vector2(52, 22), base + Vector2(-52, 22)])
		canvas.draw_colored_polygon(hull, Color(0.2, 0.15, 0.14))
		for m in 2:
			var mast := base + Vector2(-20 + m * 44, 0)
			canvas.draw_line(mast, mast + Vector2(0, -110), Color(0.2, 0.15, 0.14), 4.0)
			canvas.draw_colored_polygon(PackedVector2Array([mast + Vector2(2, -100), mast + Vector2(34, -72), mast + Vector2(2, -30)]), Color(0.95, 0.93, 0.85))
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-20, -110), base + Vector2(-2, -104), base + Vector2(-20, -98)]), Color(0.1, 0.08, 0.08))


## Far towers: dark blocks with a scatter of lit windows.
func _draw_skyline_far(canvas: Node2D) -> void:
	_draw_skyline(canvas, 41, map.far_color, 120.0, 330.0, 0.12)


func _draw_skyline(canvas: Node2D, seed_value: int, color: Color, min_height: float, max_height: float, lit: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	canvas.draw_rect(Rect2(-HALF_WIDTH, -30, HALF_WIDTH * 2, 2000), color)
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var w := rng.randf_range(60, 150)
		var h := rng.randf_range(min_height, max_height)
		canvas.draw_rect(Rect2(x, -30 - h, w, h + 40), color)
		if rng.randf() < 0.3:
			canvas.draw_line(Vector2(x + w * 0.5, -30 - h), Vector2(x + w * 0.5, -30 - h - 40), color, 3.0)
		for wy in range(int(-h) + 12, -10, 16):
			for wx in range(6, int(w) - 8, 14):
				if rng.randf() < lit:
					canvas.draw_rect(Rect2(x + wx, -30 + wy, 6, 8), Color(1.0, 0.85, 0.5, 0.75))
		x += w + rng.randf_range(4, 30)


## Nearer towers with flickering neon signs and blinking antenna lights.
func _draw_skyline_near(canvas: Node2D) -> void:
	_draw_skyline(canvas, 57, map.near_color, 80.0, 220.0, 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 58
	var neon := [Color(1.0, 0.3, 0.8), Color(0.3, 1.0, 0.9), Color(1.0, 0.85, 0.3), Color(0.5, 0.6, 1.0)]
	for i in 14:
		var at := Vector2(rng.randf_range(-HALF_WIDTH, HALF_WIDTH), rng.randf_range(-200, -90))
		var color: Color = neon[i % neon.size()]
		var flicker := 1.0 if sin(_time * (3.0 + i) + i * 7.0) > -0.85 else 0.25
		var sign_rect := Rect2(at, Vector2(rng.randf_range(50, 90), 22))
		canvas.draw_rect(sign_rect.grow(6), Color(color, 0.15 * flicker))
		canvas.draw_rect(sign_rect, Color(0.08, 0.04, 0.12))
		canvas.draw_rect(sign_rect, Color(color, 0.9 * flicker), false, 3.0)
		canvas.draw_line(sign_rect.position + Vector2(8, 11), sign_rect.end - Vector2(8, 11), Color(color, flicker), 3.0)
	for i in 10:
		var light := Vector2(-HALF_WIDTH + 300 + i * 620, -260 + (i % 3) * 30)
		if fmod(_time + i * 0.37, 1.4) < 0.5:
			canvas.draw_circle(light, 5.0, Color(1.0, 0.25, 0.25), true, -1.0, true)


## A floating island: grassy top, hanging rock, sometimes a waterfall.
func _draw_island(canvas: Node2D, centre: Vector2, width: float, grass: Color, rock: Color, waterfall: bool) -> void:
	var top := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		top.append(centre + Vector2(-width * 0.5 + width * t, -sin(t * PI) * 10.0))
	for i in range(8, -1, -1):
		var t := i / 8.0
		top.append(centre + Vector2(-width * 0.5 + width * t, sin(t * PI) * width * 0.45 + 4.0))
	canvas.draw_colored_polygon(top, rock)
	canvas.draw_rect(Rect2(centre + Vector2(-width * 0.5, -8), Vector2(width, 12)), grass)
	if waterfall:
		var fall := Rect2(centre + Vector2(width * 0.15, 0), Vector2(10, width * 0.7))
		canvas.draw_rect(fall, Color(0.85, 0.95, 1.0, 0.7))
	for k in 3:
		canvas.draw_circle(centre + Vector2(-width * 0.3 + k * width * 0.3, -18), width * 0.08, grass.darkened(0.15), true, -1.0, true)


func _draw_floating_islands_far(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for i in 9:
		var bob := sin(_time * 0.6 + i) * 6.0
		var centre := Vector2(-HALF_WIDTH + 200 + i * 760 + rng.randf_range(-100, 100), rng.randf_range(-320, -160) + bob)
		_draw_island(canvas, centre, rng.randf_range(120, 220), map.far_color.lerp(Color(0.5, 0.8, 0.5), 0.4), map.far_color, rng.randf() < 0.5)


## A sea of cloud under the arena.
func _draw_cloud_sea(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(-HALF_WIDTH, -40, HALF_WIDTH * 2, 2000), Color(0.96, 0.97, 1.0))
	for i in 70:
		var x := -HALF_WIDTH + i * 95.0 + sin(_time * 0.3 + i) * 12.0
		canvas.draw_circle(Vector2(x, -38 + sin(i * 1.7) * 8.0), 44.0 + sin(i * 2.3) * 12.0, Color(1, 1, 1), true, -1.0, true)
		canvas.draw_circle(Vector2(x + 40, -10), 30.0, Color(0.88, 0.92, 1.0), true, -1.0, true)


func _draw_floating_islands_near(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for i in 6:
		var bob := sin(_time * 0.8 + i * 2.0) * 8.0
		var centre := Vector2(-HALF_WIDTH + 400 + i * 1150 + rng.randf_range(-150, 150), rng.randf_range(-230, -120) + bob)
		_draw_island(canvas, centre, rng.randf_range(160, 260), map.near_color, map.near_color.darkened(0.35).lerp(Color(0.5, 0.36, 0.26), 0.5), rng.randf() < 0.6)


# --- desert canyon ---

## Flat-topped buttes and mesas striped with rock layers.
func _draw_mesas(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var color := map.near_color
	canvas.draw_rect(Rect2(-HALF_WIDTH, -30, HALF_WIDTH * 2, 2000), color.darkened(0.1))
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var w := rng.randf_range(160, 420)
		var h := rng.randf_range(90, 230)
		var lean := rng.randf_range(10, 40)
		var top := -30.0 - h
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, -20), Vector2(x + lean, top + 10), Vector2(x + lean + 12, top), Vector2(x + w - lean - 12, top), Vector2(x + w - lean, top + 10), Vector2(x + w, -20)]), color.lightened(rng.randf_range(-0.05, 0.06)))
		for band in 3:
			var y := top + 24.0 + band * h * 0.28
			canvas.draw_line(Vector2(x + lean + 4, y), Vector2(x + w - lean - 4, y), color.darkened(0.18), 6.0)
		canvas.draw_rect(Rect2(x + w - lean - 30, top + 6, 26, h + 10), Color(0.3, 0.12, 0.1, 0.12))
		x += w + rng.randf_range(60, 260)


## Dunes with cactus silhouettes, right behind the arena.
func _draw_dunes(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	_draw_ridge(canvas, 0.0, 70.0, 2.0, map.ground_top.darkened(0.2))
	var dark := map.ground_top.darkened(0.42)
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var h := rng.randf_range(50, 110)
		var ground := -10.0
		canvas.draw_rect(Rect2(x - 7, ground - h, 14, h + 20), dark)
		canvas.draw_circle(Vector2(x, ground - h), 7.0, dark, true, -1.0, true)
		for arm: float in [-1.0, 1.0]:
			if rng.randf() < 0.75:
				var at := ground - h * rng.randf_range(0.4, 0.65)
				canvas.draw_rect(Rect2(x + (arm * 7.0 if arm > 0 else -22.0), at, 15, 9), dark)
				canvas.draw_rect(Rect2(x + arm * 18.0 - 5, at - 28, 10, 34), dark)
				canvas.draw_circle(Vector2(x + arm * 18.0, at - 28), 5.0, dark, true, -1.0, true)
		x += rng.randf_range(180, 420)


# --- bamboo dojo ---

## A pagoda on the misty hillside.
func _draw_pagoda(canvas: Node2D) -> void:
	var base := Vector2(520, -40.0 - _ridge_height(520.0, 280.0, 0.6) + 20.0)
	var color := map.far_color.darkened(0.25)
	var lit := Color(1.0, 0.75, 0.45, 0.8)
	for tier in 4:
		var w := 120.0 - tier * 22.0
		var y := base.y - tier * 52.0
		canvas.draw_rect(Rect2(base.x - w * 0.36, y - 40, w * 0.72, 40), color)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w * 0.62, y - 34), Vector2(base.x - w * 0.36, y - 52), Vector2(base.x + w * 0.36, y - 52), Vector2(base.x + w * 0.62, y - 34), Vector2(base.x + w * 0.4, y - 40), Vector2(base.x - w * 0.4, y - 40)]), color.darkened(0.2))
		canvas.draw_rect(Rect2(base.x - 6, y - 30, 12, 14), lit)
	canvas.draw_line(Vector2(base.x, base.y - 4 * 52.0 + 2), Vector2(base.x, base.y - 4 * 52.0 - 36), color, 4.0)


func _draw_bamboo_back(canvas: Node2D) -> void:
	_draw_bamboo_grove(canvas, 0)


func _draw_bamboo_front(canvas: Node2D) -> void:
	_draw_bamboo_grove(canvas, 1)


## Rows of tall bamboo stalks swaying in the breeze. row 0 is further back.
func _draw_bamboo_grove(canvas: Node2D, row: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60 + row
	var base := map.near_color.lerp(map.far_color, 0.45 - row * 0.45)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -20, HALF_WIDTH * 2, 2000), base.darkened(0.2 + row * 0.1))
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var w := rng.randf_range(8, 14) * (0.8 + row * 0.4)
		var h := rng.randf_range(260, 420) * (0.8 + row * 0.25)
		var sway := sin(_time * 0.8 + x * 0.01) * 6.0 * (1 + row)
		var stalk := base.darkened(rng.randf_range(0.0, 0.18) + row * 0.08)
		var top := Vector2(x + sway, -10.0 - h)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - w / 2, 0), top + Vector2(-w * 0.4, 0), top + Vector2(w * 0.4, 0), Vector2(x + w / 2, 0)]), stalk)
		var joint := 40.0
		while joint < h:
			var t := joint / h
			var at := Vector2(x + sway * t, -10.0 - joint)
			canvas.draw_line(at + Vector2(-w * 0.6, 0), at + Vector2(w * 0.6, 0), stalk.darkened(0.3), 2.0)
			joint += rng.randf_range(50, 80)
		for leaf in 4:
			var at := top + Vector2(0, leaf * 16.0)
			var dir := -1.0 if leaf % 2 else 1.0
			canvas.draw_colored_polygon(PackedVector2Array([at, at + Vector2(dir * 40.0, 10.0), at + Vector2(dir * 12.0, 8.0)]), stalk.lightened(0.05))
		x += rng.randf_range(26, 70) * (0.9 + row * 0.3)
	canvas.draw_rect(Rect2(-HALF_WIDTH, -16, HALF_WIDTH * 2, 22), base.darkened(0.3 + row * 0.1))


# --- haunted graveyard ---

## Crooked crosses, headstones, dead trees and an iron fence.
func _draw_graves(canvas: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var dark := map.near_color.darkened(0.2)
	_draw_ridge(canvas, 0.0, 60.0, 1.6, dark)
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var pick := rng.randf()
		var ground := -14.0
		if pick < 0.35:
			var tilt := rng.randf_range(-0.2, 0.2)
			canvas.draw_set_transform(Vector2(x, ground), tilt)
			canvas.draw_rect(Rect2(-4, -60, 8, 62), dark)
			canvas.draw_rect(Rect2(-18, -46, 36, 8), dark)
			canvas.draw_set_transform(Vector2.ZERO)
		elif pick < 0.7:
			canvas.draw_rect(Rect2(x - 18, ground - 34, 36, 36), dark)
			canvas.draw_circle(Vector2(x, ground - 34), 18.0, dark, true, -1.0, true)
		else:
			var trunk := PackedVector2Array([Vector2(x - 10, ground + 4), Vector2(x - 4, ground - 140), Vector2(x + 4, ground - 140), Vector2(x + 10, ground + 4)])
			canvas.draw_colored_polygon(trunk, dark)
			for b in 4:
				var y := ground - rng.randf_range(60, 135)
				var dir := -1.0 if b % 2 else 1.0
				canvas.draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + dir * 30, y - 24), Vector2(x + dir * 46, y - 50)]), dark, 4.0, true)
		x += rng.randf_range(90, 200)
	# The iron fence along the front.
	for fx in range(-int(HALF_WIDTH), int(HALF_WIDTH), 18):
		canvas.draw_line(Vector2(fx, -6), Vector2(fx, -54), dark.darkened(0.3), 3.0)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, -54), Vector2(fx, -64), Vector2(fx + 4, -54)]), dark.darkened(0.3))
	canvas.draw_line(Vector2(-HALF_WIDTH, -44), Vector2(HALF_WIDTH, -44), dark.darkened(0.3), 3.0)
	canvas.draw_line(Vector2(-HALF_WIDTH, -16), Vector2(HALF_WIDTH, -16), dark.darkened(0.3), 3.0)


## Slow rolling bands of fog close to the ground.
func _draw_fog(canvas: Node2D) -> void:
	for band in 3:
		var y := -20.0 - band * 30.0
		var drift := fmod(_time * (12.0 + band * 6.0), 400.0)
		var x := -HALF_WIDTH - 400.0 + drift
		while x < HALF_WIDTH:
			canvas.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.3))
			canvas.draw_circle(Vector2.ZERO, 160.0, Color(0.7, 0.85, 0.8, 0.07), true, -1.0, true)
			canvas.draw_set_transform(Vector2.ZERO)
			x += 260.0


## Something big happened: the crowd leaps up and cheers (amount 0..1 adds up).
func hype(amount: float) -> void:
	excitement = minf(1.0, excitement + amount)
