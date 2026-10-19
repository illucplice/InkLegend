class_name Fighter
extends Node2D
## Ink-silhouette stickman: tapered brush limbs, a solid head, headgear per FighterData.style
## and a coloured scarf,
## drawn in code and wobbling on a spring. Phase 2 can swap the drawing for ragdoll parts; the
## hitboxes and this API stay the same.

signal health_changed(fighter: Fighter, health: int)
signal knocked_out(fighter: Fighter)

const OUTLINE := Color(0.12, 0.1, 0.14)
## The silhouette colour, like a heavy ink pen.
const INK := Color(0.06, 0.055, 0.07)
const STEEL := Color(0.7, 0.73, 0.8)
const GOLD := Color(1.0, 0.8, 0.3)
const LEATHER := Color(0.36, 0.22, 0.15)
## All offsets are from the feet, for a fighter facing right.
const BODY_CENTER := Vector2(0, -52)
const BODY_SIZE := Vector2(38, 60)
## Feet to hips: hits below this are leg hits.
const HIP_HEIGHT := 44.0
const HEAD_CENTER := Vector2(0, -104)
const HEAD_RADIUS := 19.0
const SHOULDER := Vector2(5, -77)
const BACK_SHOULDER := Vector2(3, -77)
const ARM_LENGTH := 26.0
## Slingshot and bow users hold their weapon out at arm's length, lowered when idle.
const RANGED_ARM_LENGTH := 33.0
const RANGED_REST_ANGLE := 0.45
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
## Shows a bouncing arrow above the head while it is this fighter's turn.
var is_turn := false
## Pin special: this fighter skips its next turn (drawn in chains).
var pinned := false

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
var _hitboxes: Array[Hitbox] = []
## Spears and arrows that hit stay stuck in the body: [{weapon, xf}] in body space.
var _stuck: Array[Dictionary] = []
var _body_xf := Transform2D.IDENTITY
var _celebrating := false
const MAX_STUCK := 6


## with_hitboxes is false for menu previews, which must never be hit.
func setup(fighter_data: FighterData, facing_dir: int, ai: bool, with_hitboxes: bool = true) -> void:
	data = fighter_data
	facing = facing_dir
	is_ai = ai
	health = Rules.MAX_HEALTH
	_time = randf() * TAU
	_next_blink = _time + randf_range(1.0, 3.0)
	if not with_hitboxes:
		return
	# Legs from the feet to the hips, body from the hips to the neck, head on top.
	var top := -HEAD_CENTER.y - HEAD_RADIUS
	var legs_shape := RectangleShape2D.new()
	legs_shape.size = Vector2(BODY_SIZE.x + 4, HIP_HEIGHT)
	_add_hitbox(Rules.LEGS, legs_shape, Vector2(0, -HIP_HEIGHT / 2))
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(BODY_SIZE.x + 4, top - HIP_HEIGHT)
	_add_hitbox(Rules.BODY, body_shape, Vector2(0, -HIP_HEIGHT - body_shape.size.y / 2))
	var head_shape := CircleShape2D.new()
	head_shape.radius = HEAD_RADIUS + 2
	_add_hitbox(Rules.HEAD, head_shape, HEAD_CENTER)


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


func take_hit(part: StringName, damage: int, impact_velocity: Vector2) -> void:
	if is_knocked_out():
		return
	health = maxi(0, health - damage)
	_tilt_velocity += clampf(impact_velocity.x * 0.0055, -6.0, 6.0) * (1.6 if part == Rules.HEAD else 1.0)
	_flash = 1.0
	_squash = 1.0
	_ouch = 1.0
	health_changed.emit(self, health)
	if health == 0:
		var fall_dir := signf(impact_velocity.x) if impact_velocity.x != 0.0 else float(-facing)
		_rest_tilt = fall_dir * KO_TILT
		knocked_out.emit(self)


## Leaves a copy of a sticking weapon in the body where it hit, angled along its flight.
func stick(weapon: WeaponData, global_point: Vector2, velocity: Vector2) -> void:
	var to_body := Transform2D(0.0, global_position) * _body_xf
	var local_point := to_body.affine_inverse() * global_point
	var local_dir := to_body.affine_inverse().basis_xform(velocity.normalized())
	# Sink the tip a little way in.
	var xf := Transform2D(local_dir.angle(), local_point) * Transform2D(0.0, Vector2(-weapon.size * 0.32, 0))
	_stuck.append({"weapon": weapon, "xf": xf})
	if _stuck.size() > MAX_STUCK:
		_stuck.pop_front()


## Victory: hop on the spot waving the weapon overhead.
func celebrate() -> void:
	_celebrating = true
	holding_weapon = true
	aiming = false


func play_throw() -> void:
	aiming = false
	holding_weapon = false
	var tween := create_tween()
	tween.tween_property(self, "_swing", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_swing", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _is_ranged() -> bool:
	return data != null and (data.weapon.shape == &"pebble" or data.weapon.shape == &"arrow")


func _add_hitbox(part: StringName, shape: Shape2D, at: Vector2) -> void:
	var box := Hitbox.new()
	box.fighter = self
	box.part = part
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
	var ranged := _is_ranged()
	var arm_target := RANGED_REST_ANGLE if ranged else ARM_REST_ANGLE
	if _celebrating:
		arm_target = -1.9 + sin(_time * 10.0) * 0.4
	elif aiming:
		# Throwers wind up behind the head; archers point straight down the aim line.
		arm_target = -deg_to_rad(aim_angle) - (0.0 if ranged else aim_power * 0.9)
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
	draw_circle(Vector2.ZERO, 32.0 - absf(_tilt) * 6.0, Color(0, 0, 0, 0.3), true, -1.0, true)

	var breathe := 0.0 if knocked else sin(_time * 3.0)
	var wobble := sin(_time * 18.0) * 0.12 * _squash
	var stretch := Vector2(1.0 + 0.12 * _squash, 1.0 - 0.12 * _squash)
	var sway := 0.0 if knocked else sin(_time * 2.2) * 0.03
	var hop := -absf(sin(_time * 7.0)) * 16.0 if _celebrating else 0.0
	var body_xf := Transform2D(_tilt + sway + wobble, Vector2(facing * stretch.x, stretch.y), 0.0, Vector2(0, hop))
	_body_xf = body_xf
	draw_set_transform_matrix(body_xf)

	# Solid ink silhouette (flashes white on a hit); back limbs a shade lighter for depth.
	var ink := INK.lerp(Color.WHITE, _flash * 0.85)
	var back_ink := ink.lerp(Color(0.32, 0.3, 0.36), 0.45)
	var scarf := data.cape_color.lerp(Color.WHITE, _flash * 0.6)
	var flutter := sin(_time * 3.4) * 5.0 + sin(_time * 7.1) * 2.0 - _tilt_velocity * 4.0
	var bob := breathe * 1.5
	# A lunging stance: hips low, torso leaning into the throw.
	var hip := Vector2(-1, -46 + bob * 0.6)
	var neck := Vector2(5, -83 + bob)

	_draw_scarf(neck, scarf, flutter)
	if data.style == &"ranger":
		_draw_quiver(neck)

	# Back arm: a fist held up in front of the chest (or waving when celebrating).
	var back_hand := BACK_SHOULDER + Vector2(15, -6 + sin(_time * 2.2) * 2.0)
	var back_elbow := BACK_SHOULDER + Vector2(10, 9)
	if _celebrating:
		back_hand = BACK_SHOULDER + Vector2(-12 + sin(_time * 10.0 + 1.0) * 5.0, -28)
		back_elbow = BACK_SHOULDER + Vector2(-12, -10)
	_taper(BACK_SHOULDER, back_elbow, 6.5, 5.0, back_ink)
	_taper(back_elbow, back_hand, 5.0, 4.0, back_ink)
	draw_circle(back_hand, 5.5, back_ink, true, -1.0, true)

	# Legs: the back one stretched out behind, the front one bent forward.
	var knee_bend := breathe * 1.2 + _squash * 6.0
	var back_knee := Vector2(-11 - knee_bend * 0.5, -25)
	var back_foot := Vector2(-24, -2)
	var front_knee := Vector2(15 + knee_bend, -27)
	var front_foot := Vector2(11, -2)
	_taper(hip, back_knee, 9.0, 6.5, back_ink)
	_taper(back_knee, back_foot, 6.5, 4.0, back_ink)
	_foot(back_foot, back_ink)
	_taper(hip, front_knee, 9.5, 7.0, ink)
	_taper(front_knee, front_foot, 7.0, 4.5, ink)
	_foot(front_foot, ink)

	_taper(hip, neck, 9.0, 6.0, ink)
	if data.style == &"knight":
		_draw_tabard(hip, neck)

	_draw_head(knocked, ink)
	for stuck in _stuck:
		Projectile.draw_weapon(self, stuck["weapon"], body_xf * stuck["xf"])
	draw_set_transform_matrix(body_xf)

	var arm_angle := _arm + _swing * (0.4 if _is_ranged() else 1.6)
	var hand := SHOULDER + Vector2.from_angle(arm_angle) * (RANGED_ARM_LENGTH if _is_ranged() else ARM_LENGTH)
	var pull := aim_power if aiming else 0.0
	Projectile.draw_held(self, data.weapon, body_xf * Transform2D(arm_angle, hand), holding_weapon, pull)
	draw_set_transform_matrix(body_xf)
	var elbow := SHOULDER.lerp(hand, 0.5) + Vector2.from_angle(arm_angle + PI / 2) * 6.0
	_taper(SHOULDER, elbow, 7.0, 5.5, ink)
	_taper(elbow, hand, 5.5, 4.5, ink)
	draw_circle(hand, 6.0, ink, true, -1.0, true)

	if pinned and not knocked:
		_draw_chains()

	if is_turn and not knocked:
		draw_set_transform(Vector2.ZERO)
		var tip := Vector2(0, -158 - absf(sin(_time * 5.0)) * 12.0)
		_poly([tip, tip + Vector2(-15, -20), tip + Vector2(-6, -20), tip + Vector2(-6, -34), tip + Vector2(6, -34), tip + Vector2(6, -20), tip + Vector2(15, -20)], data.body_color.lightened(0.25), 3.5)

	if knocked:
		var head := body_xf * HEAD_CENTER
		draw_set_transform(Vector2.ZERO)
		for i in 3:
			var a := _time * 4.0 + i * TAU / 3.0
			_draw_star(head + Vector2(cos(a) * 26.0, sin(a) * 8.0 - 36.0), 7.0)


## Pin: a stake in the ground with a chain looped round the legs.
func _draw_chains() -> void:
	draw_set_transform(Vector2.ZERO)
	var stake := Vector2(-30.0 * facing, 0)
	draw_line(stake + Vector2(0, 4), stake + Vector2(-6.0 * facing, -34), OUTLINE, 9.0, true)
	draw_line(stake + Vector2(0, 4), stake + Vector2(-6.0 * facing, -34), Color(0.6, 0.4, 0.22), 5.0, true)
	for i in 7:
		var at := stake.lerp(Vector2(0, -24), i / 6.0) + Vector2(0, -sin(i / 6.0 * PI) * 8.0)
		draw_arc(at, 5.0, 0.0, TAU, 10, OUTLINE, 4.5, true)
		draw_arc(at, 5.0, 0.0, TAU, 10, Color(0.75, 0.78, 0.85), 2.0, true)
	draw_arc(Vector2(0, -22), 14.0, 0.0, TAU, 16, OUTLINE, 5.0, true)
	draw_arc(Vector2(0, -22), 14.0, 0.0, TAU, 16, Color(0.75, 0.78, 0.85), 2.5, true)


# --- ink silhouette parts (local space, facing right) ---

## A brush-like stroke: width `from_width` at one end narrowing to `to_width`, with
## round ends, like an ink pen pressed harder at the joints.
func _taper(from: Vector2, to: Vector2, from_width: float, to_width: float, color: Color) -> void:
	var along := to - from
	if along.length() < 0.5:
		return
	var side := along.normalized().orthogonal()
	draw_colored_polygon(PackedVector2Array([
		from + side * from_width * 0.5, to + side * to_width * 0.5,
		to - side * to_width * 0.5, from - side * from_width * 0.5,
	]), color)
	draw_circle(from, from_width * 0.5, color, true, -1.0, true)
	draw_circle(to, to_width * 0.5, color, true, -1.0, true)


## A pointed foot, heel to toe.
func _foot(at: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -4), at + Vector2(13, 1), at + Vector2(-3, 2)]), color)


## A scarf in the fighter's colour streaming back from the neck.
func _draw_scarf(neck: Vector2, color: Color, flutter: float) -> void:
	var tail := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var t := float(i) / steps
		var wave := sin(_time * 6.0 - t * 4.0) * 6.0 * t
		tail.append(neck + Vector2(-4 - t * (50 + flutter), 2 + t * 8 + wave))
	var thick := PackedVector2Array()
	for i in tail.size():
		thick.append(tail[i] + Vector2(0, -5.0 * (1.0 - float(i) / tail.size()) - 1.5))
	for i in range(tail.size() - 1, -1, -1):
		thick.append(tail[i] + Vector2(0, 5.0 * (1.0 - float(i) / tail.size()) + 1.5))
	draw_colored_polygon(thick, color)
	thick.append(thick[0])
	draw_polyline(thick, INK, 2.0, true)
	draw_circle(neck + Vector2(0, 2), 6.0, INK, true, -1.0, true)
	draw_circle(neck + Vector2(0, 2), 4.0, color, true, -1.0, true)


func _draw_quiver(neck: Vector2) -> void:
	var quiver := Rect2(neck + Vector2(-17, -4), Vector2(9, 32))
	_rounded(quiver.grow(1.5), INK, 4)
	_rounded(quiver, INK.lightened(0.15), 4)
	for i in 3:
		var x := quiver.position.x + 2 + i * 3.0
		draw_line(Vector2(x, quiver.position.y), Vector2(x - 2, quiver.position.y - 12), INK, 2.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, quiver.position.y - 12), Vector2(x - 6, quiver.position.y - 18), Vector2(x + 1, quiver.position.y - 16)]), data.cape_color)


func _draw_tabard(hip: Vector2, neck: Vector2) -> void:
	var top := neck.lerp(hip, 0.18)
	var mid := top.lerp(hip, 0.4)
	_poly([top + Vector2(-7, 0), top + Vector2(7, 0), hip + Vector2(7, 6), hip + Vector2(0, 12), hip + Vector2(-7, 6)], data.body_color, 2.0)
	_poly([mid + Vector2(0, -5), mid + Vector2(4, 0), mid + Vector2(0, 6), mid + Vector2(-4, 0)], GOLD, 1.0)


## A solid ink head with the fighter's headgear in silhouette (plus one colour
## accent so you can tell them apart). Faceless, except white X eyes when knocked out.
func _draw_head(knocked: bool, ink: Color) -> void:
	var c := HEAD_CENTER
	var r := HEAD_RADIUS
	match data.style:
		&"viking":
			for side: float in [-1.0, 1.0]:
				_poly([c + Vector2(side * 10, -12), c + Vector2(side * 18, -6), c + Vector2(side * 30, -22), c + Vector2(side * 33, -44), c + Vector2(side * 23, -26)], ink, 0.0)
		&"ranger":
			# Hood pulled to a point behind the head.
			_poly([c + Vector2(4, -r - 3), c + Vector2(-r - 22, 6), c + Vector2(-r + 4, 12)], ink, 0.0)
		&"knight":
			for i in 5:
				var a := PI * 1.2 + i * 0.22
				var plume := c + Vector2(-3, -6) + Vector2.from_angle(a) * 21.0 + Vector2(sin(_time * 3.0 + i) * 1.5, 0)
				draw_circle(plume, 8.5 - i * 0.6, data.cape_color.lerp(Color.WHITE, _flash * 0.6), true, -1.0, true)
	draw_circle(c, r, ink, true, -1.0, true)
	match data.style:
		&"viking":
			draw_line(c + Vector2(-r + 1, -9), c + Vector2(r - 1, -11), GOLD, 3.0, true)
		&"rogue":
			# Headband with two tails that whip in the wind.
			draw_line(c + Vector2(-r, -7), c + Vector2(r - 1, -9), data.accent_color, 4.5, true)
			for k in 2:
				var tail := PackedVector2Array()
				var base := c + Vector2(-r + 1, -7)
				for i in 6:
					var t := float(i) / 5.0
					tail.append(base + Vector2(-t * (32 + k * 9), t * (6 + k * 8) + sin(_time * 9.0 - t * 5.0 + k) * 5.0 * t))
				draw_polyline(tail, data.accent_color, 4.0, true)
		&"knight":
			draw_line(c + Vector2(5, -3), c + Vector2(r - 1, -3), Color(0.8, 0.82, 0.88), 3.0, true)
		&"ranger":
			draw_arc(c, r - 2, -PI * 0.15, PI * 0.35, 8, data.cape_color, 3.0, true)
	if knocked:
		var eye := c + Vector2(8, -2)
		for e: Vector2 in [eye, eye + Vector2(-10, 0)]:
			draw_line(e + Vector2(-3, -3), e + Vector2(3, 3), Color.WHITE, 2.5, true)
			draw_line(e + Vector2(-3, 3), e + Vector2(3, -3), Color.WHITE, 2.5, true)


# --- drawing helpers ---

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
