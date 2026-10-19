class_name Fighter
extends Node2D
## Stickman fighter: ink limbs, a coloured scarf and headgear per FighterData.style,
## drawn in code and wobbling on a spring. Phase 2 can swap the drawing for ragdoll parts; the
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
const SHOULDER := Vector2(2, -75)
const BACK_SHOULDER := Vector2(-1, -75)
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
	_tilt_velocity += clampf(impact_velocity.x * 0.0055, -6.0, 6.0) * (1.6 if is_head else 1.0)
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


func _is_ranged() -> bool:
	return data != null and (data.weapon.shape == &"pebble" or data.weapon.shape == &"arrow")


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
	var ranged := _is_ranged()
	var arm_target := RANGED_REST_ANGLE if ranged else ARM_REST_ANGLE
	if aiming:
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
	draw_circle(Vector2.ZERO, 30.0 - absf(_tilt) * 6.0, Color(0, 0, 0, 0.28), true, -1.0, true)

	var breathe := 0.0 if knocked else sin(_time * 3.0)
	var wobble := sin(_time * 18.0) * 0.12 * _squash
	var stretch := Vector2(1.0 + 0.12 * _squash, 1.0 - 0.12 * _squash)
	var sway := 0.0 if knocked else sin(_time * 2.2) * 0.035
	var body_xf := Transform2D(_tilt + sway + wobble, Vector2(facing * stretch.x, stretch.y), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(body_xf)

	# Lines flash white on a hit; accessories keep their colours.
	var ink := OUTLINE.lerp(Color.WHITE, _flash * 0.8)
	var scarf := data.cape_color.lerp(Color.WHITE, _flash * 0.6)
	var flutter := sin(_time * 3.4) * 5.0 + sin(_time * 7.1) * 2.0 - _tilt_velocity * 4.0
	var bob := breathe * 1.5
	var hip := Vector2(0, -44 + bob * 0.5)
	var neck := Vector2(1, -82 + bob)

	_draw_scarf(neck, scarf, flutter)
	if data.style == &"ranger":
		_draw_quiver(neck)

	# Back arm hangs loose, then legs, torso, head, and the throwing arm in front.
	var back_hand := BACK_SHOULDER + Vector2(-10 + sin(_time * 2.2) * 3.0, 26)
	_bone(BACK_SHOULDER, BACK_SHOULDER + Vector2(-9, 12), back_hand, ink, true)
	var knee_bend := 2.0 + breathe * 1.2 + _squash * 6.0
	_bone(hip + Vector2(-2, 0), Vector2(-9 - knee_bend, -22), Vector2(-15, -3), ink, true)
	_bone(hip + Vector2(2, 0), Vector2(10 + knee_bend, -22), Vector2(14, -3), ink, false)
	_foot(Vector2(-15, -3), ink)
	_foot(Vector2(14, -3), ink)
	_stroke(hip, neck, ink, 8.0)
	draw_circle(hip, 5.0, ink, true, -1.0, true)
	if data.style == &"knight":
		_draw_tabard(hip, neck)

	_draw_head(knocked, ink)

	var arm_angle := _arm + _swing * (0.4 if _is_ranged() else 1.6)
	var hand := SHOULDER + Vector2.from_angle(arm_angle) * (RANGED_ARM_LENGTH if _is_ranged() else ARM_LENGTH)
	var pull := aim_power if aiming else 0.0
	Projectile.draw_held(self, data.weapon, body_xf * Transform2D(arm_angle, hand), holding_weapon, pull)
	draw_set_transform_matrix(body_xf)
	var elbow := SHOULDER.lerp(hand, 0.5) + Vector2.from_angle(arm_angle + PI / 2) * 6.0
	_bone(SHOULDER, elbow, hand, ink, false)
	draw_circle(hand, 6.5, ink, true, -1.0, true)
	draw_circle(hand, 3.5, data.accent_color, true, -1.0, true)

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


# --- stickman parts (local space, facing right) ---

## A crisp, solid ink stroke with round ends.
func _stroke(from: Vector2, to: Vector2, ink: Color, width: float) -> void:
	draw_line(from, to, ink, width, true)
	draw_circle(from, width / 2, ink, true, -1.0, true)
	draw_circle(to, width / 2, ink, true, -1.0, true)


## A two-segment limb (thigh and shin, or upper arm and forearm). Back limbs are a
## little thinner and greyer so the body reads with some depth.
func _bone(from: Vector2, joint: Vector2, to: Vector2, ink: Color, back: bool) -> void:
	var width := 6.0 if back else 7.5
	var color := ink.lerp(Color(0.3, 0.27, 0.34), 0.35) if back else ink
	_stroke(from, joint, color, width)
	_stroke(joint, to, color, width)


func _foot(at: Vector2, ink: Color) -> void:
	_stroke(at, at + Vector2(9, 1), ink, 7.0)


## A scarf in the fighter's colour streaming back from the neck.
func _draw_scarf(neck: Vector2, color: Color, flutter: float) -> void:
	var tail := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var t := float(i) / steps
		var wave := sin(_time * 6.0 - t * 4.0) * 6.0 * t
		tail.append(neck + Vector2(-4 - t * (46 + flutter), 2 + t * 10 + wave))
	var thick := PackedVector2Array()
	for i in tail.size():
		thick.append(tail[i] + Vector2(0, -6.0 * (1.0 - float(i) / tail.size()) - 2))
	for i in range(tail.size() - 1, -1, -1):
		thick.append(tail[i] + Vector2(0, 6.0 * (1.0 - float(i) / tail.size()) + 2))
	draw_colored_polygon(thick, color)
	thick.append(thick[0])
	draw_polyline(thick, OUTLINE, 2.5, true)
	draw_circle(neck + Vector2(0, 2), 7.0, OUTLINE, true, -1.0, true)
	draw_circle(neck + Vector2(0, 2), 5.0, color, true, -1.0, true)


func _draw_quiver(neck: Vector2) -> void:
	var quiver := Rect2(neck + Vector2(-16, -6), Vector2(10, 34))
	_rounded(quiver.grow(2.5), OUTLINE, 5)
	_rounded(quiver, LEATHER, 4)
	for i in 3:
		var x := quiver.position.x + 2 + i * 3.5
		draw_line(Vector2(x, quiver.position.y), Vector2(x - 2, quiver.position.y - 12), Color(0.6, 0.45, 0.3), 2.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, quiver.position.y - 12), Vector2(x - 6, quiver.position.y - 18), Vector2(x + 1, quiver.position.y - 16)]), Color(0.9, 0.3, 0.3))


func _draw_tabard(hip: Vector2, neck: Vector2) -> void:
	var top := neck.lerp(hip, 0.15)
	var mid := top.lerp(hip, 0.35)
	_poly([top + Vector2(-9, 0), top + Vector2(9, 0), hip + Vector2(8, 8), hip + Vector2(0, 14), hip + Vector2(-8, 8)], data.body_color, 2.5)
	_poly([mid + Vector2(0, -6), mid + Vector2(5, 0), mid + Vector2(0, 8), mid + Vector2(-5, 0)], GOLD, 1.5)


func _draw_head(knocked: bool, ink: Color) -> void:
	var c := HEAD_CENTER
	var r := HEAD_RADIUS
	draw_circle(c, r + 3.5, ink, true, -1.0, true)
	draw_circle(c, r - 0.5, Color.WHITE.lerp(data.skin_color, 0.15), true, -1.0, true)
	# A crisp crescent of shade on the back of the head.
	draw_arc(c, r - 3.5, PI * 0.55, PI * 1.25, 12, Color(0.82, 0.8, 0.86), 4.0, true)

	match data.style:
		&"viking":
			_poly(_arc(c + Vector2(0, -6), r + 3, PI, TAU, 14), STEEL)
			var band := Rect2(c + Vector2(-r - 3, -9), Vector2(2 * r + 6, 5))
			draw_rect(band, GOLD)
			draw_rect(band, OUTLINE, false, 2.0)
			for side: float in [-1.0, 1.0]:
				_poly([c + Vector2(side * 12, -15), c + Vector2(side * 19, -10), c + Vector2(side * 29, -24), c + Vector2(side * 32, -42), c + Vector2(side * 23, -28)], Color(0.97, 0.92, 0.78))
		&"rogue":
			# Ninja-style headband with two tails that whip in the wind.
			_poly([c + Vector2(-r - 2, -10), c + Vector2(r + 2, -12), c + Vector2(r + 2, -4), c + Vector2(-r - 2, -2)], data.accent_color, 2.5)
			for k in 2:
				var tail := PackedVector2Array()
				var base := c + Vector2(-r - 1, -6)
				for i in 6:
					var t := float(i) / 5.0
					tail.append(base + Vector2(-t * (30 + k * 8), t * (6 + k * 8) + sin(_time * 9.0 - t * 5.0 + k) * 5.0 * t))
				draw_polyline(tail, OUTLINE, 7.0, true)
				draw_polyline(tail, data.accent_color, 4.0, true)
		&"knight":
			var helm := _arc(c + Vector2(0, -1), r + 5, PI * 0.95, TAU * 1.03, 16)
			helm.append(c + Vector2(r + 3, 8))
			helm.append(c + Vector2(-r - 4, 10))
			_poly(helm, STEEL)
			_poly([c + Vector2(4, -6), c + Vector2(22, -6), c + Vector2(20, 2), c + Vector2(4, 2)], OUTLINE, 0.0)
			draw_line(c + Vector2(6, -2), c + Vector2(19, -2), Color(1, 0.85, 0.4, 0.9), 2.0, true)
			for i in 5:
				var a := PI * 1.2 + i * 0.22
				var plume := c + Vector2(-6, -12) + Vector2.from_angle(a) * 26.0 + Vector2(sin(_time * 3.0 + i) * 1.5, 0)
				draw_circle(plume, 9.0 - i * 0.6, OUTLINE, true, -1.0, true)
				draw_circle(plume, 7.0 - i * 0.6, data.cape_color, true, -1.0, true)
			return
		&"ranger":
			_poly([c + Vector2(-2, -r - 6), c + Vector2(14, -18), c + Vector2(r + 4, -4), c + Vector2(14, -10), c + Vector2(-6, -14), c + Vector2(-r + 2, -2), c + Vector2(-r - 14, 4), c + Vector2(-r - 4, -12)], data.cape_color)
	_draw_face(c, knocked)


func _draw_face(c: Vector2, knocked: bool) -> void:
	var eye := c + Vector2(9, -1)
	if knocked:
		draw_line(eye + Vector2(-4, -4), eye + Vector2(4, 4), OUTLINE, 3.0, true)
		draw_line(eye + Vector2(-4, 4), eye + Vector2(4, -4), OUTLINE, 3.0, true)
	elif _time > _next_blink:
		draw_line(eye + Vector2(-4, 0), eye + Vector2(4, 0), OUTLINE, 3.0, true)
	else:
		var look := Vector2.from_angle(-deg_to_rad(aim_angle)) * 1.5 if aiming else Vector2(1.0, 0.0)
		draw_colored_polygon(_ellipse(eye + look, Vector2(3.2, 4.6), 14), OUTLINE)
		draw_circle(eye + look + Vector2(-0.8, -1.6), 1.2, Color.WHITE, true, -1.0, true)
	# Brow: angry while aiming, raised when hurt.
	var brow_tilt := 4.0 if aiming else (-3.0 if _ouch > 0.2 else 0.0)
	draw_line(eye + Vector2(-5, -8 - brow_tilt * 0.5), eye + Vector2(5, -8 + brow_tilt * 0.5), OUTLINE, 3.0, true)
	var mouth := c + Vector2(10, 9)
	if _ouch > 0.3 or knocked:
		draw_colored_polygon(_ellipse(mouth, Vector2(3.0, 4.0), 14), OUTLINE)
	elif aiming:
		draw_line(mouth + Vector2(-4, 0), mouth + Vector2(4, -1), OUTLINE, 2.5, true)
	else:
		draw_arc(mouth + Vector2(0, -4), 5.0, 0.5, 2.0, 8, OUTLINE, 2.5, true)


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
