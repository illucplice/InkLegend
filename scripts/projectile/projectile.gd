class_name Projectile
extends Node2D
## A thrown weapon. It follows Rules.position_at exactly and raycasts each step,
## so fast throws can't pass through a limb between frames. Physics interpolation
## smooths its motion between physics ticks on high-refresh screens.

signal hit_fighter(projectile: Projectile, fighter: Fighter, is_head: bool)
## collider is the ground, or the Obstacle that was hit.
signal hit_ground(projectile: Projectile, collider: Object)
signal finished(projectile: Projectile)

const INK := Color(0.12, 0.1, 0.14)
const COLLISION_MASK := 0b11
const MAX_LIFETIME := 8.0
const KILL_DEPTH := 300.0
const KILL_RANGE := 4000.0
const TRAIL_POINTS := 16

var weapon: WeaponData
var thrower: Fighter

var _origin := Vector2.ZERO
var _velocity := Vector2.ZERO
var _t := 0.0
var _done := false
var _exclude: Array[RID] = []
var _trail: Line2D


func launch(from_weapon: WeaponData, from_fighter: Fighter, from: Vector2, velocity: Vector2) -> void:
	weapon = from_weapon
	thrower = from_fighter
	_origin = from
	_velocity = velocity
	_exclude = from_fighter.get_hitbox_rids()
	global_position = from
	rotation = velocity.angle()
	reset_physics_interpolation()
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_trail.width = clampf(weapon.size * 0.35, 6.0, 14.0)
	_trail.antialiased = true
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var taper := Curve.new()
	taper.add_point(Vector2(0, 0))
	taper.add_point(Vector2(1, 1))
	_trail.width_curve = taper
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0.55))
	_trail.gradient = fade
	_trail.z_index = -1
	add_child(_trail)


func current_velocity() -> Vector2:
	return _velocity + Vector2(0.0, Rules.GRAVITY * _t)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# The trail stops at the last tick's position; the interpolated sprite covers the gap.
	_trail.add_point(global_position)
	if _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)
	var next := Rules.position_at(_origin, _velocity, _t)
	var query := PhysicsRayQueryParameters2D.create(global_position, next, COLLISION_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
		if weapon.spin != 0.0:
			rotation += weapon.spin * delta * signf(_velocity.x)
		else:
			rotation = current_velocity().angle()
		if _t > MAX_LIFETIME or next.y > KILL_DEPTH or absf(next.x) > KILL_RANGE:
			_finish(false)
		return

	global_position = hit["position"]
	var box := hit["collider"] as Hitbox
	if box != null:
		hit_fighter.emit(self, box.fighter, box.is_head)
	else:
		hit_ground.emit(self, hit["collider"])
	_finish(weapon.sticks)


func _finish(linger: bool) -> void:
	_done = true
	finished.emit(self)
	var trail_fade := create_tween()
	trail_fade.tween_property(_trail, "modulate:a", 0.0, 0.25)
	var tween := create_tween()
	tween.tween_interval(2.5 if linger else 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
	if not linger:
		tween.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.4)


func _draw() -> void:
	draw_weapon(self, weapon, Transform2D.IDENTITY)


## Draws a weapon pointing along +x and centred on 0, so fighters can draw it in hand too.
static func draw_weapon(canvas: CanvasItem, w: WeaponData, xf: Transform2D) -> void:
	canvas.draw_set_transform_matrix(xf)
	var s := w.size
	match w.shape:
		&"hammer":
			_stick(canvas, Vector2(-s * 0.5, 0), Vector2(s * 0.3, 0), 6.0, Color(0.55, 0.36, 0.2))
			var head := Rect2(Vector2(s * 0.22, -s * 0.28), Vector2(s * 0.32, s * 0.56))
			canvas.draw_rect(head.grow(2.5), INK)
			canvas.draw_rect(head, w.color)
			canvas.draw_rect(Rect2(head.position, Vector2(head.size.x, head.size.y * 0.3)), w.color.lightened(0.3))
		&"spear", &"arrow":
			var is_spear := w.shape == &"spear"
			var tip_len := s * (0.22 if is_spear else 0.16)
			_stick(canvas, Vector2(-s * 0.5, 0), Vector2(s * 0.5, 0), 5.0 if is_spear else 3.5, w.color)
			var tip := PackedVector2Array([
				Vector2(s * 0.5, -tip_len * 0.4), Vector2(s * 0.5 + tip_len, 0), Vector2(s * 0.5, tip_len * 0.4),
			])
			canvas.draw_colored_polygon(tip, Color(0.82, 0.84, 0.88))
			tip.append(tip[0])
			canvas.draw_polyline(tip, INK, 2.0, true)
			if not is_spear:
				for side: float in [-1.0, 1.0]:
					canvas.draw_colored_polygon(PackedVector2Array([
						Vector2(-s * 0.5, 0), Vector2(-s * 0.5 + 10, 0), Vector2(-s * 0.5 - 2, side * 7),
					]), Color(0.9, 0.3, 0.3))
		_:
			canvas.draw_circle(Vector2.ZERO, s * 0.5 + 2.5, INK, true, -1.0, true)
			canvas.draw_circle(Vector2.ZERO, s * 0.5, w.color, true, -1.0, true)
			canvas.draw_circle(Vector2(-s * 0.15, -s * 0.15), s * 0.18, w.color.lightened(0.35), true, -1.0, true)


static func _stick(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(from, to, INK, width + 4.0, true)
	canvas.draw_line(from, to, color, width, true)
