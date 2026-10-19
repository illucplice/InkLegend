class_name Obstacle
extends StaticBody2D
## A solid block between the fighters. Throws that touch it stop (spears and arrows
## stick) and chip it: it cracks as it takes damage, then crumbles away. Kinds: tower
## (broken stone column), wall (low battlement), floating (hovering rune slab, which
## drifts to a new spot each turn).

const INK := Color(0.12, 0.1, 0.14)
## Colours come from the map (see setup); these are the defaults.
var stone := Color(0.8, 0.82, 0.88)
var stone_dark := Color(0.55, 0.57, 0.66)
var rune := Color(0.45, 0.95, 1.0)
## Floating obstacles: marble slab thickness; the rest of the box is the rock below.
const SLAB := 36.0
## Hit points per kind.
const HIT_POINTS := {&"tower": 4, &"wall": 3, &"floating": 3}

signal destroyed(obstacle: Obstacle)

var kind: StringName = &"tower"
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
	kind = obstacle_kind
	rect = box
	max_hp = HIT_POINTS.get(kind, 3)
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
	if kind == &"floating":
		_add_rune_glow()


func _process(delta: float) -> void:
	if kind == &"floating" or _shake > 0.0:
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
	match kind:
		&"tower":
			_draw_tower(size, rng)
		&"wall":
			_draw_wall(size, rng)
		&"floating":
			_draw_floating(size, rng)
	_draw_cracks(size)


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
