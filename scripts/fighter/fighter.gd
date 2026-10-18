class_name Fighter
extends Node2D
## Greybox fighter: drawn from shapes and wobbles on a spring. Phase 2 swaps the
## drawing for the ragdoll; the hitboxes and this API stay the same.

signal health_changed(fighter: Fighter, health: int)
signal knocked_out(fighter: Fighter)

const OUTLINE := Color(0.12, 0.1, 0.14)
## All offsets are from the feet, for a fighter facing right.
const BODY_CENTER := Vector2(0, -52)
const BODY_SIZE := Vector2(38, 60)
const HEAD_CENTER := Vector2(0, -104)
const HEAD_RADIUS := 19.0
const SHOULDER := Vector2(4, -72)
const ARM_LENGTH := 26.0
const ARM_REST_ANGLE := -0.9
const HAND_REST := Vector2(20, -92)
const KO_TILT := 1.5
const SPRING := 60.0
const DAMPING := 7.0

var data: FighterData
var facing := 1
var health := Rules.MAX_HEALTH
var is_ai := false
var holding_weapon := true

var _tilt := 0.0
var _tilt_velocity := 0.0
var _rest_tilt := 0.0
var _swing := 0.0
var _time := 0.0
var _body_style: StyleBoxFlat
var _hitboxes: Array[Hitbox] = []


func setup(fighter_data: FighterData, facing_dir: int, ai: bool) -> void:
	data = fighter_data
	facing = facing_dir
	is_ai = ai
	health = Rules.MAX_HEALTH
	_time = randf() * TAU
	_body_style = StyleBoxFlat.new()
	_body_style.bg_color = data.body_color
	_body_style.border_color = OUTLINE
	_body_style.set_border_width_all(3)
	_body_style.set_corner_radius_all(16)
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
	health_changed.emit(self, health)
	if health == 0:
		var fall_dir := signf(impact_velocity.x) if impact_velocity.x != 0.0 else float(-facing)
		_rest_tilt = fall_dir * KO_TILT
		knocked_out.emit(self)


func play_throw() -> void:
	holding_weapon = false
	var tween := create_tween()
	tween.tween_property(self, "_swing", 1.0, 0.1)
	tween.tween_property(self, "_swing", 0.0, 0.4)


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
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var sway := 0.0 if is_knocked_out() else sin(_time * 2.2) * 0.035
	var body_xf := Transform2D(_tilt + sway, Vector2(facing, 1), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(body_xf)

	for x: float in [-9.0, 9.0]:
		var hip := Vector2(x, -26)
		var foot := Vector2(x * 1.3, -2)
		draw_line(hip, foot, OUTLINE, 12.0)
		draw_line(hip, foot, data.body_color.darkened(0.3), 7.0)
		draw_circle(foot + Vector2(4, 0), 6.0, OUTLINE)

	draw_style_box(_body_style, Rect2(BODY_CENTER - BODY_SIZE / 2, BODY_SIZE))

	draw_circle(HEAD_CENTER, HEAD_RADIUS + 3, OUTLINE)
	draw_circle(HEAD_CENTER, HEAD_RADIUS, data.skin_color)
	var eye := HEAD_CENTER + Vector2(8, -3)
	if is_knocked_out():
		draw_line(eye + Vector2(-3, -3), eye + Vector2(3, 3), OUTLINE, 2.5)
		draw_line(eye + Vector2(-3, 3), eye + Vector2(3, -3), OUTLINE, 2.5)
	else:
		draw_circle(eye, 3.2, OUTLINE)
	draw_line(HEAD_CENTER + Vector2(5, 9), HEAD_CENTER + Vector2(13, 7), OUTLINE, 2.0)

	var crown := Rect2(HEAD_CENTER + Vector2(-14, -36), Vector2(28, 18))
	var brim := Rect2(HEAD_CENTER + Vector2(-22, -20), Vector2(44, 8))
	for part: Rect2 in [crown, brim]:
		draw_rect(part.grow(2.5), OUTLINE)
		draw_rect(part, data.accent_color)

	var arm_angle := lerpf(ARM_REST_ANGLE, 0.5, _swing)
	var hand := SHOULDER + Vector2.from_angle(arm_angle) * ARM_LENGTH
	if holding_weapon:
		Projectile.draw_weapon(self, data.weapon, body_xf * Transform2D(arm_angle - 0.7, hand))
		draw_set_transform_matrix(body_xf)
	draw_line(SHOULDER, hand, OUTLINE, 11.0)
	draw_line(SHOULDER, hand, data.body_color, 7.0)
	draw_circle(hand, 6.5, OUTLINE)
	draw_circle(hand, 4.5, data.skin_color)
