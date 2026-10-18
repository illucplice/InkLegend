class_name Fighter
extends Node2D
## Greybox fighter: drawn in code with an outfit per FighterData.style, and wobbles
## on a spring. Phase 2 swaps the drawing for Blender-rendered ragdoll parts; the
## hitboxes and this API stay the same.

signal health_changed(fighter: Fighter, health: int)
signal knocked_out(fighter: Fighter)

const OUTLINE := Color(0.12, 0.1, 0.14)
const STEEL := Color(0.7, 0.73, 0.8)
const GOLD := Color(1.0, 0.8, 0.3)
const LEATHER := Color(0.36, 0.22, 0.15)
## All offsets are from the feet, for a fighter facing right.
const BODY_CENTER := Vector2(0, -52)
const BODY_SIZE := Vector2(38, 60)
const HEAD_CENTER := Vector2(0, -104)
const HEAD_RADIUS := 19.0
const SHOULDER := Vector2(4, -72)
const BACK_SHOULDER := Vector2(-8, -72)
const ARM_LENGTH := 26.0
const ARM_REST_ANGLE := -0.9
const HAND_REST := Vector2(20, -92)
const KO_TILT := 1.5
const SPRING := 60.0
const DAMPING := 7.0
const ARM_FOLLOW_SPEED := 14.0

var data: FighterData
var facing := 1
var health := Rules.MAX_HEALTH
var is_ai := false
var holding_weapon := true
## While aiming, the arm follows aim_angle (degrees) and pulls back with aim_power.
var aiming := false
var aim_angle := 45.0
var aim_power := 0.0

var _tilt := 0.0
var _tilt_velocity := 0.0
var _rest_tilt := 0.0
var _arm := ARM_REST_ANGLE
var _swing := 0.0
var _flash := 0.0
var _squash := 0.0
var _ouch := 0.0
var _time := 0.0
var _next_blink := 2.0
var _body_style: StyleBoxFlat
var _shine_style: StyleBoxFlat
var _hitboxes: Array[Hitbox] = []


func setup(fighter_data: FighterData, facing_dir: int, ai: bool) -> void:
	data = fighter_data
	facing = facing_dir
	is_ai = ai
	health = Rules.MAX_HEALTH
	_time = randf() * TAU
	_next_blink = _time + randf_range(1.0, 3.0)
	_body_style = StyleBoxFlat.new()
	_body_style.border_color = OUTLINE
	_body_style.set_border_width_all(3)
	_body_style.set_corner_radius_all(16)
	_body_style.corner_radius_top_left = 12
	_body_style.corner_radius_top_right = 12
	_body_style.anti_aliasing = true
	_shine_style = StyleBoxFlat.new()
	_shine_style.bg_color = Color(1, 1, 1, 0.18)
	_shine_style.set_corner_radius_all(6)
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(BODY_SIZE.x + 4, -HEAD_CENTER.y - HEAD_RADIUS)
	_add_hitbox(false, body_shape, Vector2(0, -body_shape.size.y / 2))
	var head_shape := CircleShape2D.new()
	head_shape.radius = HEAD_RADIUS + 2
	_add_hitbox(true, head_shape, HEAD_CENTER)


func throw_origin() -> Vector2:
	return global_position + Vector2(HAND_REST.x * facing, HAND_REST.y)


func aim_point(head: bool) -> Vector2:
	return global_position + (HEAD_CENTER if head else BODY_CENTER)


func is_knocked_out() -> bool:
	return health <= 0


func get_hitbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for box in _hitboxes:
		rids.append(box.get_rid())
	return rids


func take_hit(is_head: bool, damage: int, impact_velocity: Vector2) -> void:
	if is_knocked_out():
		return
	health = maxi(0, health - damage)
	_tilt_velocity += clampf(impact_velocity.x * 0.004, -6.0, 6.0) * (1.6 if is_head else 1.0)
	_flash = 1.0
	_squash = 1.0
	_ouch = 1.0
	health_changed.emit(self, health)
	if health == 0:
		var fall_dir := signf(impact_velocity.x) if impact_velocity.x != 0.0 else float(-facing)
		_rest_tilt = fall_dir * KO_TILT
		knocked_out.emit(self)


func play_throw() -> void:
	aiming = false
	holding_weapon = false
	var tween := create_tween()
	tween.tween_property(self, "_swing", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_swing", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _add_hitbox(is_head: bool, shape: Shape2D, at: Vector2) -> void:
	var box := Hitbox.new()
	box.fighter = self
	box.is_head = is_head
	box.collision_layer = 2
	box.collision_mask = 0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = at
	box.add_child(collision)
	add_child(box)
	_hitboxes.append(box)


func _process(delta: float) -> void:
	_time += delta
	var accel := -SPRING * (_tilt - _rest_tilt) - DAMPING * _tilt_velocity
	_tilt_velocity += accel * delta
	_tilt += _tilt_velocity * delta
	var arm_target := ARM_REST_ANGLE
	if aiming:
		arm_target = -deg_to_rad(aim_angle) - aim_power * 0.9
	_arm = lerp_angle(_arm, arm_target, 1.0 - exp(-ARM_FOLLOW_SPEED * delta))
	_flash = maxf(0.0, _flash - delta * 5.0)
	_squash = maxf(0.0, _squash - delta * 4.0)
	_ouch = maxf(0.0, _ouch - delta * 1.5)
	if _time > _next_blink + 0.12:
		_next_blink = _time + randf_range(2.0, 4.5)
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var knocked := is_knocked_out()

	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 34.0 - absf(_tilt) * 6.0, Color(0, 0, 0, 0.25), true, -1.0, true)

	var breathe := 0.0 if knocked else sin(_time * 3.0) * 0.015
	var wobble := sin(_time * 18.0) * 0.12 * _squash
	var stretch := Vector2(1.0 + 0.12 * _squash - breathe, 1.0 - 0.12 * _squash + breathe)
	var sway := 0.0 if knocked else sin(_time * 2.2) * 0.035
	var body_xf := Transform2D(_tilt + sway + wobble, Vector2(facing * stretch.x, stretch.y), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(body_xf)

	var white_out := _flash * 0.7
	var body := data.body_color.lerp(Color.WHITE, white_out)
	var skin := data.skin_color.lerp(Color.WHITE, white_out)
	var cape := data.cape_color.lerp(Color.WHITE, white_out)
	# The cape trails behind and flutters more after a hit.
	var flutter := sin(_time * 3.4) * 4.0 + sin(_time * 7.1) * 1.5 - _tilt_velocity * 3.0

	_draw_back_gear(cape, flutter)
	_draw_back_arm(body, skin)
	_draw_legs()
	_draw_torso(body)
	_draw_head(skin, knocked)

	var arm_angle := _arm + _swing * 1.6
	var hand := SHOULDER + Vector2.from_angle(arm_angle) * ARM_LENGTH
	if holding_weapon:
		Projectile.draw_weapon(self, data.weapon, body_xf * Transform2D(arm_angle - 0.7, hand))
		draw_set_transform_matrix(body_xf)
	_limb(SHOULDER, hand, body, 7.0)
	var cuff := SHOULDER.lerp(hand, 0.7)
	draw_line(cuff, SHOULDER.lerp(hand, 0.95), LEATHER, 8.0, true)
	draw_circle(hand, 6.5, OUTLINE, true, -1.0, true)
	draw_circle(hand, 4.8, skin, true, -1.0, true)

	if knocked:
		var head := body_xf * HEAD_CENTER
		draw_set_transform(Vector2.ZERO)
		for i in 3:
			var a := _time * 4.0 + i * TAU / 3.0
			_draw_star(head + Vector2(cos(a) * 26.0, sin(a) * 8.0 - 36.0), 7.0)


# --- body parts (local space, facing right) ---

func _draw_back_gear(cape: Color, flutter: float) -> void:
	if data.style == &"rogue":
		_poly([Vector2(-6, -88), Vector2(6, -88), Vector2(6, -79), Vector2(-24 + flutter, -71), Vector2(-42 + flutter * 1.4, -74 + flutter * 0.3), Vector2(-24 + flutter, -82)], cape)
		return
	if data.style == &"ranger":
		var quiver := Rect2(Vector2(-24, -94), Vector2(13, 40))
		_rounded(quiver.grow(2.5), OUTLINE, 5)
		_rounded(quiver, LEATHER, 4)
		for i in 3:
			var x := -22.0 + i * 4.5
			draw_line(Vector2(x, -94), Vector2(x - 2, -108), Color(0.6, 0.45, 0.3), 2.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2, -108), Vector2(x - 6, -114), Vector2(x + 1, -112)]), Color(0.9, 0.3, 0.3))
	var bottom := -18.0 if data.style == &"knight" else -24.0
	_poly([Vector2(8, -88), Vector2(-14, -88), Vector2(-26 + flutter, bottom + 6), Vector2(-12 + flutter * 0.6, bottom), Vector2(4 + flutter * 0.2, bottom + 4)], cape)
	draw_line(Vector2(-10, -84), Vector2(-20 + flutter * 0.8, bottom + 8), cape.darkened(0.25), 3.0, true)


func _draw_back_arm(body: Color, skin: Color) -> void:
	var hand := BACK_SHOULDER + Vector2(-8 + sin(_time * 2.2) * 2.0, 22)
	_limb(BACK_SHOULDER, hand, body.darkened(0.25), 6.0)
	draw_circle(hand, 5.5, OUTLINE, true, -1.0, true)
	draw_circle(hand, 4.0, skin.darkened(0.15), true, -1.0, true)


func _draw_legs() -> void:
	var pants := data.body_color.darkened(0.55)
	for x: float in [-9.0, 9.0]:
		var hip := Vector2(x, -28)
		var foot := Vector2(x * 1.3, -6)
		_limb(hip, foot, pants if x < 0 else pants.lightened(0.12), 8.0)
		var boot := Rect2(foot + Vector2(-7, -6), Vector2(19, 11))
		_rounded(boot.grow(2.5), OUTLINE, 6)
		_rounded(boot, LEATHER, 5)
		draw_line(boot.position + Vector2(2, 2), boot.position + Vector2(14, 2), LEATHER.lightened(0.3), 2.0, true)


func _draw_torso(body: Color) -> void:
	var rect := Rect2(BODY_CENTER - BODY_SIZE / 2, BODY_SIZE)
	_body_style.bg_color = body
	draw_style_box(_body_style, rect)
	draw_style_box(_shine_style, Rect2(rect.position + Vector2(rect.size.x - 15, 7), Vector2(8, rect.size.y - 22)))
	match data.style:
		&"viking":
			var fur := PackedVector2Array()
			for i in 9:
				fur.append(Vector2(-20 + i * 5, -84 + (6 if i % 2 else 0)))
			fur.append(Vector2(20, -90))
			fur.append(Vector2(-20, -90))
			draw_colored_polygon(fur, data.cape_color.lightened(0.15))
		&"rogue":
			_poly([Vector2(-4, -82), Vector2(19, -82), Vector2(19, -40), Vector2(10, -40)], data.accent_color.darkened(0.2), 2.0)
			for y: float in [-70.0, -58.0, -46.0]:
				draw_circle(Vector2(13, y), 2.2, GOLD, true, -1.0, true)
		&"knight":
			var plate := Rect2(Vector2(-16, -80), Vector2(34, 36))
			_rounded(plate.grow(2.5), OUTLINE, 10)
			_rounded(plate, STEEL, 9)
			draw_line(Vector2(1, -76), Vector2(1, -48), STEEL.lightened(0.4), 3.0, true)
			_poly([Vector2(1, -70), Vector2(9, -64), Vector2(1, -52), Vector2(-7, -64)], data.cape_color, 2.0)
		&"ranger":
			draw_line(Vector2(-16, -82), Vector2(16, -42), OUTLINE, 7.0, true)
			draw_line(Vector2(-16, -82), Vector2(16, -42), LEATHER, 4.0, true)
	var belt := Rect2(Vector2(-19, -38), Vector2(38, 7))
	draw_rect(belt.grow(1.5), OUTLINE)
	draw_rect(belt, LEATHER)
	var buckle := Rect2(Vector2(5, -40), Vector2(9, 11))
	draw_rect(buckle.grow(1.5), OUTLINE)
	draw_rect(buckle, GOLD)


func _draw_head(skin: Color, knocked: bool) -> void:
	var c := HEAD_CENTER
	var r := HEAD_RADIUS
	draw_circle(c, r + 3, OUTLINE, true, -1.0, true)
	draw_circle(c, r, skin, true, -1.0, true)
	draw_circle(c + Vector2(-6, 6), r * 0.75, skin.darkened(0.08), true, -1.0, true)
	draw_circle(c, r * 0.8, skin, true, -1.0, true)
	draw_circle(c + Vector2(-5, 2), 5.0, OUTLINE, true, -1.0, true)
	draw_circle(c + Vector2(-5, 2), 3.5, skin.darkened(0.1), true, -1.0, true)

	if data.style == &"ranger":
		_poly([c + Vector2(-4, -27), c + Vector2(14, -22), c + Vector2(23, -6), c + Vector2(20, 14), c + Vector2(-12, 22), c + Vector2(-36, 6), c + Vector2(-26, -18)], data.cape_color)
		_poly(_ellipse(c + Vector2(9, 2), Vector2(11, 15), 16), skin, 2.0)

	_draw_face(c, skin, knocked)

	match data.style:
		&"viking":
			_poly([c + Vector2(-3, 6), c + Vector2(18, 4), c + Vector2(20, 14), c + Vector2(10, 28), c + Vector2(0, 22), c + Vector2(-6, 12)], data.hair_color)
			draw_line(c + Vector2(6, 9), c + Vector2(15, 9), data.hair_color.darkened(0.3), 3.0, true)
			if _ouch > 0.3 or knocked:
				draw_circle(c + Vector2(11, 11), 3.0, OUTLINE, true, -1.0, true)
			var dome := _arc(c + Vector2(0, -11), r + 2, PI, TAU, 14)
			_poly(dome, STEEL)
			draw_line(c + Vector2(-4, -30), c + Vector2(-4, -12), STEEL.lightened(0.35), 3.0, true)
			var band := Rect2(c + Vector2(-r - 3, -15), Vector2(2 * r + 6, 6))
			draw_rect(band, GOLD)
			draw_rect(band, OUTLINE, false, 2.0)
			for side: float in [-1.0, 1.0]:
				_poly([c + Vector2(side * 12, -20), c + Vector2(side * 20, -15), c + Vector2(side * 30, -28), c + Vector2(side * 33, -46), c + Vector2(side * 24, -32)], Color(0.97, 0.92, 0.78))
		&"rogue":
			for i in 3:
				draw_circle(c + Vector2(5 + i * 3.5, 6 + (i % 2) * 2), 1.2, Color(0.75, 0.45, 0.3), true, -1.0, true)
			_poly(_arc(c + Vector2(-2, -6), r + 1, PI * 1.05, TAU * 0.98, 12), data.accent_color)
			_poly([c + Vector2(-8, -10), c + Vector2(28, -10), c + Vector2(26, -5), c + Vector2(-6, -5)], data.accent_color.darkened(0.15), 2.5)
			_poly([c + Vector2(-12, -20), c + Vector2(-30, -42), c + Vector2(-22, -40), c + Vector2(-6, -24)], data.cape_color, 2.0)
			draw_line(c + Vector2(-10, -22), c + Vector2(-26, -40), Color.WHITE, 1.5, true)
		&"knight":
			var helm := _arc(c + Vector2(0, -1), r + 5, PI * 0.95, TAU * 1.03, 16)
			helm.append(c + Vector2(r + 3, 8))
			helm.append(c + Vector2(-r - 4, 10))
			_poly(helm, STEEL)
			_poly([c + Vector2(4, -6), c + Vector2(22, -6), c + Vector2(20, 2), c + Vector2(4, 2)], OUTLINE, 0.0)
			draw_line(c + Vector2(6, -2), c + Vector2(19, -2), Color(1, 0.85, 0.4, 0.9), 2.0, true)
			draw_line(c + Vector2(-2, -24), c + Vector2(-2, 8), STEEL.lightened(0.35), 3.0, true)
			for i in 5:
				var a := PI * 1.2 + i * 0.22
				var plume := c + Vector2(-6, -12) + Vector2.from_angle(a) * 26.0 + Vector2(sin(_time * 3.0 + i) * 1.5, 0)
				draw_circle(plume, 9.0 - i * 0.6, OUTLINE, true, -1.0, true)
				draw_circle(plume, 7.0 - i * 0.6, data.cape_color, true, -1.0, true)
		&"ranger":
			pass


func _draw_face(c: Vector2, skin: Color, knocked: bool) -> void:
	var visor := data.style == &"knight"
	var eye := c + Vector2(9, -3)
	if not visor:
		var brow_tilt := 4.0 if aiming else (-3.0 if _ouch > 0.2 else 0.0)
		draw_line(eye + Vector2(-6, -8 - brow_tilt * 0.5), eye + Vector2(6, -8 + brow_tilt * 0.5), data.hair_color.darkened(0.3), 3.0, true)
	if knocked:
		draw_line(eye + Vector2(-3, -3), eye + Vector2(3, 3), OUTLINE, 2.5, true)
		draw_line(eye + Vector2(-3, 3), eye + Vector2(3, -3), OUTLINE, 2.5, true)
	elif visor:
		draw_circle(eye + Vector2(0, 1), 2.6, Color(1, 0.9, 0.5), true, -1.0, true)
	elif _time > _next_blink:
		draw_line(eye + Vector2(-4, 0), eye + Vector2(4, 0), OUTLINE, 2.0, true)
	else:
		var look := Vector2.from_angle(-deg_to_rad(aim_angle)) * 1.6 if aiming else Vector2(1.2, 0.4)
		draw_circle(eye, 5.4, OUTLINE, true, -1.0, true)
		draw_circle(eye, 4.0, Color.WHITE, true, -1.0, true)
		draw_circle(eye + look, 2.5, OUTLINE, true, -1.0, true)
		draw_circle(eye + look + Vector2(-0.8, -0.9), 0.9, Color.WHITE, true, -1.0, true)
	if visor:
		return
	draw_circle(c + Vector2(19, 3), 4.0, OUTLINE, true, -1.0, true)
	draw_circle(c + Vector2(19, 3), 2.8, skin.darkened(0.12), true, -1.0, true)
	draw_circle(c + Vector2(9, 6), 3.5, Color(1.0, 0.5, 0.5, 0.35), true, -1.0, true)
	if data.style == &"viking":
		return
	var mouth := c + Vector2(11, 11)
	if _ouch > 0.3 or knocked:
		draw_circle(mouth, 3.4, OUTLINE, true, -1.0, true)
	elif aiming:
		draw_rect(Rect2(mouth + Vector2(-4, -2), Vector2(8, 4)), Color.WHITE)
		draw_rect(Rect2(mouth + Vector2(-4, -2), Vector2(8, 4)), OUTLINE, false, 1.5)
	else:
		draw_arc(mouth + Vector2(0, -4), 5.0, 0.4, 2.0, 8, OUTLINE, 2.0, true)


# --- drawing helpers ---

func _limb(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, OUTLINE, width + 5.0, true)
	draw_circle(from, (width + 5.0) / 2, OUTLINE, true, -1.0, true)
	draw_circle(to, (width + 5.0) / 2, OUTLINE, true, -1.0, true)
	draw_line(from, to, color, width, true)
	draw_circle(from, width / 2, color, true, -1.0, true)


func _poly(points: Variant, fill: Color, outline_width: float = 3.0) -> void:
	var shape := PackedVector2Array(points)
	draw_colored_polygon(shape, fill)
	if outline_width > 0.0:
		shape.append(shape[0])
		draw_polyline(shape, OUTLINE, outline_width, true)


func _rounded(rect: Rect2, color: Color, radius: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _arc(center: Vector2, radius: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * radius)
	return points


func _ellipse(center: Vector2, radii: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points


func _draw_star(at: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var rr := radius if i % 2 == 0 else radius * 0.45
		points.append(at + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
	draw_colored_polygon(points, Color(1.0, 0.86, 0.25))
	points.append(points[0])
	draw_polyline(points, OUTLINE, 1.5, true)
