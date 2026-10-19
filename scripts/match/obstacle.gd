class_name Obstacle
extends StaticBody2D
## A solid block between the fighters. Throws that touch it stop (spears and arrows
## stick) and chip it: it cracks as it takes damage, then crumbles away. Kinds: tower
## (broken stone column), wall (low battlement), floating (hovering rune slab, which
## drifts to a new spot each turn) and spire (tall and thin). Each map draws them in its
## own style: icicles and ice blocks, ship masts and crate stacks, neon billboards,
## sky islands, mesas and cacti, bamboo and paper screens, tombstones and dead trees.

const INK := Color(0.12, 0.1, 0.14)
## Colours come from the map (see setup); these are the defaults.
var stone := Color(0.8, 0.82, 0.88)
var stone_dark := Color(0.55, 0.57, 0.66)
var rune := Color(0.45, 0.95, 1.0)
## Floating obstacles: marble slab thickness; the rest of the box is the rock below.
const SLAB := 36.0
## Hit points per kind, and per "style/kind" where a style is tougher or more brittle.
const HIT_POINTS := {&"tower": 4, &"wall": 3, &"floating": 3, &"spire": 3}
const STYLE_HIT_POINTS := {
	"ice/spire": 2, "ice/wall": 2, "wood/tower": 2, "wood/wall": 2, "bamboo/spire": 2, "bamboo/wall": 2,
	"grave/spire": 2, "sand/spire": 2, "neon/spire": 2, "sand/tower": 5, "basalt/tower": 5,
}
const WOOD := Color(0.72, 0.5, 0.3)
const WOOD_DARK := Color(0.45, 0.3, 0.18)

signal destroyed(obstacle: Obstacle)

var kind: StringName = &"tower"
var style: StringName = &"stone"
## World-space box this obstacle fills (also its collision).
var rect := Rect2()

var hp := 3
var max_hp := 3
var is_destroyed := false

var _time := 0.0
var _seed := 0
var _shake := 0.0


func setup(obstacle_kind: StringName, box: Rect2, seed_value: int, map: MapData = null) -> void:
	if map != null:
		stone = map.obstacle_stone
		stone_dark = map.obstacle_dark
		rune = map.rune_color
		style = map.obstacle_style
	kind = obstacle_kind
	rect = box
	max_hp = hit_points(style, kind)
	hp = max_hp
	_seed = seed_value
	collision_layer = 1
	collision_mask = 0
	position = box.position
	var shape := RectangleShape2D.new()
	shape.size = box.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = box.size / 2
	add_child(collision)
	if kind == &"floating" and style != &"cloud":
		_add_rune_glow()


func _process(delta: float) -> void:
	if kind == &"floating" or _shake > 0.0 or style == &"neon" or style == &"bamboo":
		_time += delta
		_shake = maxf(0.0, _shake - delta * 4.0)
		queue_redraw()


## Chips the obstacle. Returns true if that broke it.
func damage(amount: int) -> bool:
	if is_destroyed:
		return false
	hp -= amount
	_shake = 1.0
	queue_redraw()
	if hp > 0:
		return false
	_crumble()
	return true


## Floating slabs only: slide to a new left edge over `seconds`. The logical rect
## (used by the AI) jumps to the destination straight away.
func drift_to(x: float, seconds: float) -> void:
	rect.position.x = x
	create_tween().tween_property(self, "position:x", x, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _crumble() -> void:
	is_destroyed = true
	collision_layer = 0
	destroyed.emit(self)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "position:y", position.y + 40.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if _shake > 0.0:
		draw_set_transform(Vector2(sin(_time * 70.0) * 4.0 * _shake, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var size := rect.size
	_draw_styled(size, rng)
	_draw_cracks(size)


static func hit_points(obstacle_style: StringName, obstacle_kind: StringName) -> int:
	return STYLE_HIT_POINTS.get("%s/%s" % [obstacle_style, obstacle_kind], HIT_POINTS.get(obstacle_kind, 3))


## Picks the drawing for this style and kind; anything a style doesn't redraw falls
## back to the classic stone look.
func _draw_styled(size: Vector2, rng: RandomNumberGenerator) -> void:
	match style:
		&"ice":
			if kind == &"floating":
				_draw_floating(size, rng)
			else:
				_draw_ice(size, rng)
			return
		&"basalt":
			if kind != &"floating":
				_draw_basalt(size, rng)
				return
		&"wood":
			if kind == &"spire":
				_draw_mast(size)
			else:
				_draw_crates(size, rng)
			return
		&"neon":
			match kind:
				&"floating":
					_draw_billboard(size, rng)
				&"spire":
					_draw_antenna(size)
				_:
					_draw_vent(size, rng)
			return
		&"cloud":
			if kind == &"floating":
				_draw_sky_island(size, rng)
				return
		&"sand":
			if kind == &"spire":
				_draw_cactus(size, rng)
				return
			if kind != &"floating":
				_draw_mesa(size, rng)
				return
		&"bamboo":
			if kind == &"spire":
				_draw_bamboo(size, rng)
				return
			if kind != &"floating":
				_draw_screen(size)
				return
		&"grave":
			if kind == &"spire":
				_draw_dead_tree(size, rng)
				return
			if kind != &"floating":
				_draw_tombstone(size, rng)
				return
	match kind:
		&"wall":
			_draw_wall(size, rng)
		&"floating":
			_draw_floating(size, rng)
		_:
			_draw_tower(size, rng)

## More cracks the more damage it has taken.
func _draw_cracks(size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 99
	var height := minf(size.y, SLAB) if kind == &"floating" else size.y
	for k in max_hp - hp:
		var point := Vector2(rng.randf_range(size.x * 0.2, size.x * 0.8), rng.randf_range(height * 0.1, height * 0.5))
		var crack := PackedVector2Array([point])
		for step in 4:
			point += Vector2(rng.randf_range(-10, 10), rng.randf_range(8, height * 0.18))
			crack.append(point)
		draw_polyline(crack, INK, 3.0, true)
		draw_polyline(crack, Color(1, 1, 1, 0.25), 1.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_tower(size: Vector2, rng: RandomNumberGenerator) -> void:
	# Jagged broken top, drawn slightly above the collision box so it looks ruined.
	var outline := PackedVector2Array([Vector2(0, size.y), Vector2(0, 8)])
	var steps := 5
	for i in steps + 1:
		outline.append(Vector2(size.x * i / steps, rng.randf_range(-6.0, 12.0)))
	outline.append(Vector2(size.x, size.y))
	_shape(outline, stone)
	# Stone courses with offset joints.
	var row_h := 34.0
	var rows := int(size.y / row_h)
	for row in rows:
		var y := size.y - (row + 1) * row_h
		draw_line(Vector2(3, y), Vector2(size.x - 3, y), stone_dark, 3.0)
		var joint := size.x * (0.35 if row % 2 else 0.65)
		draw_line(Vector2(joint, y), Vector2(joint, y + row_h), stone_dark, 3.0)
	draw_rect(Rect2(size.x - 18, 10, 14, size.y - 12), Color(0.45, 0.25, 0.35, 0.22))
	draw_rect(Rect2(4, 10, 8, size.y - 12), Color(1, 1, 1, 0.12))
	# A crack and some moss.
	var crack := PackedVector2Array([Vector2(size.x * 0.45, 20), Vector2(size.x * 0.55, 60), Vector2(size.x * 0.4, 95), Vector2(size.x * 0.5, 130)])
	draw_polyline(crack, INK, 2.5, true)
	for i in 6:
		draw_circle(Vector2(rng.randf_range(4, size.x - 4), rng.randf_range(0, 16)), rng.randf_range(4, 8), Color(0.42, 0.6, 0.32), true, -1.0, true)
	draw_rect(Rect2(-6, size.y - 22, size.x + 12, 22), stone_dark)
	draw_rect(Rect2(-6, size.y - 22, size.x + 12, 22), INK, false, 3.0)


func _draw_wall(size: Vector2, rng: RandomNumberGenerator) -> void:
	var merlon := 30.0
	var outline := PackedVector2Array([Vector2(0, size.y)])
	var x := 0.0
	var up := true
	while x < size.x:
		var y := 0.0 if up else 22.0
		outline.append(Vector2(x, y))
		x = minf(x + merlon, size.x)
		outline.append(Vector2(x, y))
		up = not up
	outline.append(Vector2(size.x, size.y))
	_shape(outline, stone)
	var row_h := 26.0
	for row in int((size.y - 22) / row_h):
		var y := size.y - (row + 1) * row_h
		draw_line(Vector2(3, y), Vector2(size.x - 3, y), stone_dark, 3.0)
		var offset := 0.0 if row % 2 else 30.0
		var jx := offset + 20.0
		while jx < size.x - 10:
			draw_line(Vector2(jx, y), Vector2(jx, y + row_h), stone_dark, 3.0)
			jx += 60.0
	# A shield hanging on the wall.
	var center := Vector2(size.x / 2, size.y * 0.58)
	var color := Color(0.82, 0.2, 0.25) if rng.randf() < 0.5 else Color(0.22, 0.38, 0.78)
	_shape(PackedVector2Array([center + Vector2(-18, -20), center + Vector2(18, -20), center + Vector2(18, 4), center + Vector2(0, 24), center + Vector2(-18, 4)]), color)
	draw_line(center + Vector2(0, -18), center + Vector2(0, 20), Color(1.0, 0.82, 0.35), 4.0)


func _draw_floating(size: Vector2, rng: RandomNumberGenerator) -> void:
	var bob := sin(_time * 1.6) * 3.0
	draw_set_transform(Vector2(0, bob))
	# Rocky underside hanging below the slab.
	var under := PackedVector2Array([Vector2(6, SLAB - 4.0)])
	var points := 6
	for i in points + 1:
		var px := size.x * (0.1 + 0.8 * i / points)
		var depth := sin(PI * i / points) * (size.y - SLAB) * rng.randf_range(0.85, 1.0)
		under.append(Vector2(px, SLAB - 4.0 + depth))
	under.append(Vector2(size.x - 6, SLAB - 4.0))
	_shape(under, Color(0.52, 0.38, 0.42))
	# Glowing runes on the rock.
	var pulse := 0.6 + 0.4 * sin(_time * 3.0)
	for i in 3:
		var at := Vector2(size.x * (0.3 + i * 0.2), SLAB + 10 + (i % 2) * 6)
		draw_circle(at, 6.0, Color(rune, 0.25 * pulse), true, -1.0, true)
		draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), Color(rune, pulse), 2.5, true)
		draw_line(at + Vector2(4, -4), at + Vector2(-4, 4), Color(rune, pulse), 2.5, true)
	# The marble slab itself.
	var slab := Rect2(Vector2.ZERO, Vector2(size.x, SLAB))
	var box := StyleBoxFlat.new()
	box.bg_color = stone
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	box.anti_aliasing = true
	draw_style_box(box, slab)
	draw_rect(Rect2(6, 4, size.x - 12, 7), Color(1, 1, 1, 0.25))
	for i in int(size.x / 50):
		var jx := 30.0 + i * 50.0
		draw_line(Vector2(jx, 12), Vector2(jx, SLAB - 4), stone_dark, 3.0)
	for i in 5:
		draw_circle(Vector2(rng.randf_range(10, size.x - 10), 2), rng.randf_range(4, 7), Color(0.42, 0.6, 0.32), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _shape(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, INK, 3.0, true)


func _add_rune_glow() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(rune, 0.5))
	gradient.set_color(1, Color(rune, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var glow := Sprite2D.new()
	glow.texture = texture
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.position = Vector2(rect.size.x / 2, rect.size.y)
	glow.scale = Vector2(rect.size.x / 40.0, 1.6)
	glow.show_behind_parent = true
	add_child(glow)


# --- map styles ---

## Ice: a jagged icicle (spire) or a faceted ice block with snow on top.
func _draw_ice(size: Vector2, rng: RandomNumberGenerator) -> void:
	if kind == &"spire":
		var outline := PackedVector2Array([Vector2(-4, size.y), Vector2(size.x * 0.15, size.y * 0.55), Vector2(size.x * 0.3, size.y * 0.2), Vector2(size.x * 0.5, -10), Vector2(size.x * 0.68, size.y * 0.25), Vector2(size.x * 0.85, size.y * 0.6), Vector2(size.x + 4, size.y)])
		_shape(outline, stone)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5, -6), Vector2(size.x * 0.62, size.y * 0.3), Vector2(size.x * 0.52, size.y * 0.95), Vector2(size.x * 0.42, size.y * 0.35)]), Color(1, 1, 1, 0.35))
		draw_line(Vector2(size.x * 0.3, size.y * 0.2), Vector2(size.x * 0.45, size.y), stone_dark, 2.0, true)
		draw_line(Vector2(size.x * 0.68, size.y * 0.25), Vector2(size.x * 0.6, size.y), stone_dark, 2.0, true)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = stone
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.anti_aliasing = true
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	for i in 4:
		var x := rng.randf_range(size.x * 0.1, size.x * 0.9)
		draw_line(Vector2(x, 6), Vector2(x + rng.randf_range(-30, 30), size.y - 6), stone_dark, 2.5, true)
	draw_rect(Rect2(8, 8, size.x * 0.18, size.y - 16), Color(1, 1, 1, 0.28))
	# Snow on top and icicles hanging off the edge.
	var cap := PackedVector2Array()
	for i in 9:
		cap.append(Vector2(size.x * i / 8.0, 4.0 - sin(PI * i / 8.0) * 10.0 - rng.randf_range(0, 3)))
	cap.append(Vector2(size.x, 12))
	cap.append(Vector2(0, 12))
	draw_colored_polygon(cap, Color(0.97, 0.99, 1.0))
	for i in int(size.x / 26.0):
		var x := 10.0 + i * 26.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 11), Vector2(x + 5, 11), Vector2(x, 11 + rng.randf_range(10, 22))]), Color(0.9, 0.97, 1.0))


## Basalt: a clump of hexagonal columns at different heights, lava glowing between.
func _draw_basalt(size: Vector2, rng: RandomNumberGenerator) -> void:
	var count := maxi(1, int(size.x / 34.0))
	var column := size.x / count
	var pulse := 0.6 + 0.4 * sin(_time * 3.0 + _seed)
	draw_rect(Rect2(2, 20, size.x - 4, size.y - 20), Color(rune, 0.5 * pulse))
	for i in count:
		var x := i * column
		var top := rng.randf_range(0.0, minf(26.0, size.y * 0.15))
		var shade := stone.darkened(rng.randf_range(0.0, 0.2))
		_shape(PackedVector2Array([Vector2(x + 2, size.y), Vector2(x + 2, top + 8), Vector2(x + column * 0.5, top), Vector2(x + column - 2, top + 8), Vector2(x + column - 2, size.y)]), shade)
		draw_line(Vector2(x + column * 0.5, top + 2), Vector2(x + column * 0.5, size.y), stone_dark, 2.0)
		var joint := top + rng.randf_range(40.0, 90.0)
		while joint < size.y - 10.0:
			draw_line(Vector2(x + 4, joint), Vector2(x + column - 4, joint + 4), stone_dark, 2.0)
			joint += rng.randf_range(50.0, 90.0)


## Wood: a stack of crates with braces and painted marks.
func _draw_crates(size: Vector2, rng: RandomNumberGenerator) -> void:
	var cols := maxi(1, roundi(size.x / 70.0))
	var w := size.x / cols
	var rows := maxi(1, roundi(size.y / w))
	var h := size.y / rows
	for row in rows:
		for col in cols:
			var box := Rect2(col * w, size.y - (row + 1) * h, w, h).grow(-1.5)
			draw_rect(box, WOOD.darkened(rng.randf_range(0.0, 0.18)))
			for plank in range(1, 3):
				var y := box.position.y + box.size.y * plank / 3.0
				draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), WOOD_DARK, 2.0)
			draw_line(box.position + Vector2(6, 6), box.end - Vector2(6, 6), WOOD_DARK, 4.0)
			draw_rect(box.grow(-4), WOOD_DARK, false, 3.0)
			draw_rect(box, INK, false, 3.0)
			if rng.randf() < 0.3:
				draw_circle(box.get_center(), minf(box.size.x, box.size.y) * 0.16, Color(0.85, 0.2, 0.2, 0.7), false, 3.0, true)


## Wood spire: a ship's mast with furled sails, a crow's nest and a pennant.
func _draw_mast(size: Vector2) -> void:
	var cx := size.x / 2
	var pole := Rect2(cx - 8, 0, 16, size.y)
	draw_rect(pole, WOOD)
	draw_rect(Rect2(cx - 8, 0, 5, size.y), WOOD.lightened(0.15))
	draw_rect(pole, INK, false, 3.0)
	for y: float in [size.y * 0.35, size.y * 0.7]:
		var yard := Rect2(cx - size.x * 0.5 - 14, y, size.x + 28, 9)
		draw_rect(yard, WOOD_DARK)
		draw_rect(yard, INK, false, 2.0)
		var sail := Rect2(cx - size.x * 0.45 - 8, y + 9, size.x * 0.9 + 16, 16)
		draw_rect(sail, Color(0.95, 0.9, 0.78))
		draw_rect(sail, INK, false, 2.0)
	var nest := Rect2(cx - 20, 30, 40, 22)
	draw_rect(nest, WOOD_DARK)
	draw_rect(nest, INK, false, 3.0)
	var wave := sin(_time * 4.0) * 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(cx, 0), Vector2(cx + 34, 8 + wave), Vector2(cx, 18)]), Color(0.85, 0.2, 0.22))


## Neon: a floating billboard with a glowing frame and a flickering sign.
func _draw_billboard(size: Vector2, rng: RandomNumberGenerator) -> void:
	var bob := sin(_time * 1.6) * 3.0
	draw_set_transform(Vector2(0, bob))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.07, 0.18)
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var flicker := 0.75 + 0.25 * sin(_time * 9.0 + _seed) if fmod(_time + (_seed % 40) * 0.1, 4.0) > 0.15 else 0.2
	draw_rect(Rect2(6, 6, size.x - 12, size.y - 12), Color(rune, flicker), false, 3.0)
	var x := 18.0
	while x < size.x - 30.0:
		var w := rng.randf_range(14.0, 34.0)
		draw_rect(Rect2(x, size.y * 0.35, w, size.y * 0.3), Color(1.0, 0.45, 0.8, flicker * 0.9))
		x += w + 8.0
	for i in 2:
		var leg := size.x * (0.25 + i * 0.5)
		draw_line(Vector2(leg, size.y), Vector2(leg, size.y + 16), INK, 4.0)
	draw_set_transform(Vector2.ZERO)


## Neon block: a rooftop air-con unit with a spinning fan.
func _draw_vent(size: Vector2, rng: RandomNumberGenerator) -> void:
	_shape(PackedVector2Array([Vector2(0, size.y), Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y)]), Color(0.6, 0.62, 0.7))
	for y in range(14, int(size.y) - 8, 12):
		draw_line(Vector2(8, y), Vector2(size.x - 8, y), Color(0.42, 0.44, 0.52), 2.0)
	var fan := Vector2(size.x / 2, minf(size.y * 0.35, 60.0))
	var radius := minf(size.x, size.y) * 0.24
	draw_circle(fan, radius + 4, INK, true, -1.0, true)
	draw_circle(fan, radius, Color(0.3, 0.32, 0.4), true, -1.0, true)
	for blade in 3:
		var a := _time * 6.0 + blade * TAU / 3.0
		draw_line(fan, fan + Vector2.from_angle(a) * radius * 0.9, Color(0.75, 0.78, 0.85), 5.0, true)
	draw_rect(Rect2(6, size.y - 16, size.x - 12, 6), Color(rune, 0.7))
	if rng.randf() < 0.5:
		draw_line(Vector2(size.x - 10, 0), Vector2(size.x - 10, -30), Color(0.4, 0.42, 0.5), 6.0)


## Neon spire: a lattice radio mast with a blinking red light.
func _draw_antenna(size: Vector2) -> void:
	var cx := size.x / 2
	var left := [Vector2(2, size.y), Vector2(cx - 3, 0)]
	var right := [Vector2(size.x - 2, size.y), Vector2(cx + 3, 0)]
	var steps := int(size.y / 30.0)
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var a: Vector2 = (left[0] as Vector2).lerp(left[1], t0)
		var b: Vector2 = (right[0] as Vector2).lerp(right[1], t1)
		var c: Vector2 = (right[0] as Vector2).lerp(right[1], t0)
		draw_line(a, b, Color(0.55, 0.58, 0.68), 2.0)
		draw_line(a, c, Color(0.55, 0.58, 0.68), 2.0)
	draw_line(left[0], left[1], INK, 5.0, true)
	draw_line(right[0], right[1], INK, 5.0, true)
	var blink := 1.0 if fmod(_time, 1.2) < 0.6 else 0.25
	draw_circle(Vector2(cx, -4), 7.0, Color(1.0, 0.2, 0.3, blink), true, -1.0, true)
	draw_circle(Vector2(cx, -4), 16.0, Color(1.0, 0.2, 0.3, 0.2 * blink), true, -1.0, true)


## Cloud: a little grassy island with a rocky underside, bobbing in the sky.
func _draw_sky_island(size: Vector2, rng: RandomNumberGenerator) -> void:
	var bob := sin(_time * 1.3 + _seed % 10) * 4.0
	draw_set_transform(Vector2(0, bob))
	var under := PackedVector2Array([Vector2(0, 16)])
	for i in 9:
		var t := i / 8.0
		under.append(Vector2(size.x * t, 16 + sin(PI * t) * (size.y + 40.0) * rng.randf_range(0.7, 1.0)))
	under.append(Vector2(size.x, 16))
	_shape(under, Color(0.62, 0.5, 0.46))
	draw_line(Vector2(size.x * 0.3, 30), Vector2(size.x * 0.4, size.y + 10), Color(0.48, 0.38, 0.36), 3.0)
	var top := StyleBoxFlat.new()
	top.bg_color = Color(0.45, 0.78, 0.35)
	top.border_color = INK
	top.set_border_width_all(3)
	top.set_corner_radius_all(12)
	top.anti_aliasing = true
	draw_style_box(top, Rect2(-6, 0, size.x + 12, 24))
	draw_rect(Rect2(4, 4, size.x - 8, 5), Color(1, 1, 1, 0.22))
	for i in 4:
		var at := Vector2(rng.randf_range(12, size.x - 12), 2)
		draw_circle(at, 4.0, [Color(1, 0.7, 0.85), Color.WHITE, Color(1, 0.9, 0.4)][i % 3], true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


## Sand: a flat-topped mesa with stripes of red and orange rock.
func _draw_mesa(size: Vector2, rng: RandomNumberGenerator) -> void:
	var outline := PackedVector2Array([Vector2(-8, size.y), Vector2(4, size.y * 0.55), Vector2(-2, size.y * 0.3), Vector2(6, 6), Vector2(size.x * 0.3, -4), Vector2(size.x * 0.75, -2), Vector2(size.x - 6, 6), Vector2(size.x + 2, size.y * 0.4), Vector2(size.x - 4, size.y * 0.7), Vector2(size.x + 8, size.y)])
	_shape(outline, stone)
	var y := 18.0
	var i := 0
	while y < size.y - 12.0:
		var color := stone_dark if i % 2 == 0 else stone.lightened(0.12)
		draw_rect(Rect2(4, y, size.x - 8, 10), Color(color, 0.8))
		y += 22.0 + rng.randf_range(-4, 6)
		i += 1
	draw_rect(Rect2(size.x - 22, 10, 16, size.y - 12), Color(0.35, 0.15, 0.1, 0.18))


## Sand spire: a saguaro cactus with two arms.
func _draw_cactus(size: Vector2, rng: RandomNumberGenerator) -> void:
	var green := Color(0.36, 0.62, 0.32)
	var cx := size.x / 2
	var trunk_w := size.x * 0.62
	var box := StyleBoxFlat.new()
	box.bg_color = green
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(int(trunk_w / 2))
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	box.anti_aliasing = true
	var arm_box := box.duplicate() as StyleBoxFlat
	arm_box.set_corner_radius_all(9)
	for arm: float in [-1.0, 1.0]:
		var at := size.y * rng.randf_range(0.35, 0.55)
		var reach := size.x * 0.6
		var elbow := cx + arm * (trunk_w / 2 + reach)
		draw_style_box(arm_box, Rect2(minf(cx, elbow), at, absf(elbow - cx), 18))
		draw_style_box(arm_box, Rect2(elbow - 9.0 - arm * 6.0, at - 60, 18, 78))
	draw_style_box(box, Rect2(cx - trunk_w / 2, 0, trunk_w, size.y))
	for x: float in [cx - trunk_w * 0.2, cx + trunk_w * 0.2]:
		draw_line(Vector2(x, 12), Vector2(x, size.y - 4), green.darkened(0.25), 2.0)
	draw_circle(Vector2(cx, 4), 5.0, Color(1.0, 0.5, 0.6), true, -1.0, true)


## Bamboo: a clump of stalks with joints and swaying leaves at the top.
func _draw_bamboo(size: Vector2, rng: RandomNumberGenerator) -> void:
	var green := Color(0.55, 0.75, 0.3)
	var stalks := 3
	var w := size.x / stalks
	for i in stalks:
		var top := rng.randf_range(0.0, size.y * 0.12)
		var stalk := Rect2(i * w + 2, top, w - 4, size.y - top)
		draw_rect(stalk, green.darkened(rng.randf_range(0.0, 0.15)))
		draw_rect(Rect2(stalk.position, Vector2(4, stalk.size.y)), Color(1, 1, 1, 0.2))
		draw_rect(stalk, INK, false, 2.5)
		var joint := top + rng.randf_range(30.0, 50.0)
		while joint < size.y - 10.0:
			draw_line(Vector2(stalk.position.x - 1, joint), Vector2(stalk.end.x + 1, joint), green.darkened(0.45), 3.0)
			joint += rng.randf_range(44.0, 62.0)
		var sway := sin(_time * 1.5 + i) * 4.0
		for leaf in 3:
			var base := Vector2(stalk.get_center().x, top + 6.0 + leaf * 10.0)
			var dir := -1.0 if (leaf + i) % 2 else 1.0
			draw_colored_polygon(PackedVector2Array([base, base + Vector2(dir * 34.0 + sway, -10.0 + leaf * 4.0), base + Vector2(dir * 10.0, 6.0)]), Color(0.42, 0.65, 0.28))


## Bamboo block: a paper shoji screen in a dark wooden frame, lit from behind.
func _draw_screen(size: Vector2) -> void:
	_shape(PackedVector2Array([Vector2(0, size.y), Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y)]), Color(0.98, 0.94, 0.84))
	draw_circle(size * 0.5, minf(size.x, size.y) * 0.4, Color(1.0, 0.75, 0.4, 0.14 + 0.05 * sin(_time * 2.0)), true, -1.0, true)
	var frame := Color(0.32, 0.2, 0.14)
	var cols := maxi(2, int(size.x / 40.0))
	var rows := maxi(2, int(size.y / 40.0))
	for c in range(1, cols):
		draw_line(Vector2(size.x * c / cols, 0), Vector2(size.x * c / cols, size.y), frame, 3.0)
	for r in range(1, rows):
		draw_line(Vector2(0, size.y * r / rows), Vector2(size.x, size.y * r / rows), frame, 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), frame, false, 8.0)
	draw_rect(Rect2(Vector2.ZERO, size), INK, false, 3.0)


## Grave: a mossy tombstone with a cross carved in it (two stones if it is wide).
func _draw_tombstone(size: Vector2, rng: RandomNumberGenerator) -> void:
	var stones := 2 if size.x > 140.0 else 1
	var w := size.x / stones
	for i in stones:
		var x := i * w
		var h := size.y * (1.0 if i == 0 else rng.randf_range(0.75, 0.95))
		var top := size.y - h
		var round_h := minf(w / 2, h * 0.4)
		var outline := PackedVector2Array([Vector2(x + 2, size.y)])
		for k in 9:
			var a := PI + PI * k / 8.0
			outline.append(Vector2(x + w / 2 + cos(a) * (w / 2 - 2), top + round_h + sin(a) * round_h))
		outline.append(Vector2(x + w - 2, size.y))
		_shape(outline, stone.darkened(rng.randf_range(0.0, 0.15)))
		var cx := x + w / 2
		var cy := top + h * 0.45
		draw_line(Vector2(cx, cy - h * 0.18), Vector2(cx, cy + h * 0.2), stone_dark, 6.0)
		draw_line(Vector2(cx - w * 0.16, cy - h * 0.06), Vector2(cx + w * 0.16, cy - h * 0.06), stone_dark, 6.0)
		for m in 4:
			draw_circle(Vector2(x + rng.randf_range(6, w - 6), size.y - rng.randf_range(0, 18)), rng.randf_range(4, 8), Color(0.35, 0.5, 0.3), true, -1.0, true)


## Grave spire: a gnarled dead tree with bare twisting branches.
func _draw_dead_tree(size: Vector2, rng: RandomNumberGenerator) -> void:
	var bark := Color(0.28, 0.22, 0.24)
	var cx := size.x / 2
	for i in 4:
		var y := size.y * rng.randf_range(0.1, 0.55)
		var dir := -1.0 if i % 2 else 1.0
		var start := Vector2(cx + dir * size.x * 0.1, y)
		var mid := start + Vector2(dir * rng.randf_range(24, 40), -rng.randf_range(16, 30))
		var tip := mid + Vector2(dir * rng.randf_range(14, 26), -rng.randf_range(10, 24))
		draw_polyline(PackedVector2Array([start, mid, tip]), INK, 7.0, true)
		draw_polyline(PackedVector2Array([start, mid, tip]), bark.lightened(0.1), 3.5, true)
	var trunk := PackedVector2Array([Vector2(cx - size.x * 0.55, size.y), Vector2(cx - size.x * 0.2, size.y * 0.6), Vector2(cx - size.x * 0.28, size.y * 0.25), Vector2(cx - 4, 0), Vector2(cx + size.x * 0.22, size.y * 0.3), Vector2(cx + size.x * 0.18, size.y * 0.65), Vector2(cx + size.x * 0.55, size.y)])
	_shape(trunk, bark)
	draw_circle(Vector2(cx - 2, size.y * 0.45), 6.0, INK, true, -1.0, true)
