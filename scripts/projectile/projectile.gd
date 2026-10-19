class_name Projectile
extends Node2D
## A thrown weapon. It follows Rules.position_at exactly and raycasts each step,
## so fast throws can't pass through a limb between frames. Physics interpolation
## smooths its motion between physics ticks on high-refresh screens.

## part is Rules.HEAD, BODY or LEGS.
signal hit_fighter(projectile: Projectile, fighter: Fighter, part: StringName)
## collider is the ground, or the Obstacle that was hit.
signal hit_ground(projectile: Projectile, collider: Object)
signal finished(projectile: Projectile)
## Bombs: went off at `at`. direct is the fighter it struck (or null), part where;
## collider is what it touched.
signal exploded(projectile: Projectile, at: Vector2, direct: Fighter, part: StringName, collider: Object)
## Target Practice: a bullseye was hit (the throw stops there).
signal hit_target(projectile: Projectile, target: PracticeTarget)
## A crate was touched; the projectile keeps flying.
signal hit_crate(projectile: Projectile, crate: Crate)

const INK := Color(0.12, 0.1, 0.14)
## Ground and obstacles (1), hitboxes (2), crates (4), practice targets (8).
const COLLISION_MASK := 0b1111
const MAX_LIFETIME := 8.0
const KILL_DEPTH := 300.0
const KILL_RANGE := 4000.0
const TRAIL_POINTS := 16

var weapon: WeaponData
var thrower: Fighter
## Sideways push in px/s² (see Rules.MAX_WIND).
var wind := 0.0
## Shockwave: how many more times this bounces off the ground or obstacles.
var bounces := 0
## The fighter being aimed at, to measure near misses.
var target: Fighter
## Closest this came to the target's head or body, in px.
var closest := INF
## Seconds in the air since launch, including bounces.
var flight_time := 0.0
## Blast radius (bombs), set from the weapon; Big Boom makes it bigger.
var explode_radius := 0.0

var _origin := Vector2.ZERO
var _velocity := Vector2.ZERO
var _t := 0.0
var _done := false
var _exclude: Array[RID] = []
var _trail: Line2D


func launch(from_weapon: WeaponData, from_fighter: Fighter, from: Vector2, velocity: Vector2, wind_accel: float = 0.0) -> void:
	wind = wind_accel
	weapon = from_weapon
	explode_radius = from_weapon.explode_radius
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


## Where this will be dt seconds from now if nothing gets in the way.
func predict(dt: float) -> Vector2:
	return Rules.position_at(_origin, _velocity, _t + dt, wind)


func is_flying() -> bool:
	return not _done


func current_velocity() -> Vector2:
	return Rules.velocity_at(_velocity, _t, wind)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	flight_time += delta
	if target != null:
		closest = minf(closest, minf(global_position.distance_to(target.aim_point(true)), global_position.distance_to(target.aim_point(false))))
	# The trail stops at the last tick's position; the interpolated sprite covers the gap.
	_trail.add_point(global_position)
	if _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)
	var next := Rules.position_at(_origin, _velocity, _t, wind)
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

	var practice := hit["collider"] as PracticeTarget
	if practice != null:
		global_position = hit["position"]
		hit_target.emit(self, practice)
		_finish(weapon.sticks)
		return
	var crate := hit["collider"] as Crate
	if crate != null:
		_exclude.append(crate.get_rid())
		hit_crate.emit(self, crate)
		return
	global_position = hit["position"]
	var box := hit["collider"] as Hitbox
	if explode_radius > 0.0:
		exploded.emit(self, global_position, box.fighter if box != null else null, box.part if box != null else Rules.BODY, hit["collider"])
		_finish(false)
		return
	if box != null:
		hit_fighter.emit(self, box.fighter, box.part)
		_finish(weapon.sticks)
		return
	hit_ground.emit(self, hit["collider"])
	if bounces > 0:
		_bounce(hit["normal"])
		return
	_finish(weapon.sticks)


## Shockwave: rebound off the surface with some energy lost, and keep flying.
func _bounce(normal: Vector2) -> void:
	bounces -= 1
	var velocity := current_velocity().bounce(normal) * 0.62
	_origin = global_position + normal * 3.0
	_velocity = velocity
	_t = 0.0


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
	var ink := Color(0.06, 0.055, 0.07)
	var steel := Color(0.78, 0.8, 0.86)
	match w.shape:
		&"hammer":
			# A war hammer like the sketch: a long shaft with a spike at the butt and a
			# big rounded block for a head, with a keyhole emblem punched through it.
			var length := s * 1.7
			canvas.draw_line(Vector2(-length * 0.55, 0), Vector2(length * 0.35, 0), ink, 5.0, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-length * 0.55, -4), Vector2(-length * 0.55 - 16, 0), Vector2(-length * 0.55, 4)]), ink)
			canvas.draw_circle(Vector2(-length * 0.5, 0), 4.0, ink, true, -1.0, true)
			var head := Rect2(Vector2(length * 0.28, -s * 0.5), Vector2(s * 0.62, s * 1.0))
			var block := StyleBoxFlat.new()
			block.bg_color = ink
			block.set_corner_radius_all(int(s * 0.12))
			block.anti_aliasing = true
			canvas.draw_style_box(block, head)
			canvas.draw_line(head.position + Vector2(5, 4), head.position + Vector2(5, head.size.y - 4), steel.darkened(0.3), 2.0, true)
			canvas.draw_line(head.position + Vector2(head.size.x - 5, 4), head.position + Vector2(head.size.x - 5, head.size.y - 4), steel.darkened(0.3), 2.0, true)
			var mid := head.get_center()
			canvas.draw_circle(mid + Vector2(0, -3), s * 0.11, w.color.lightened(0.4), true, -1.0, true)
			canvas.draw_colored_polygon(PackedVector2Array([mid + Vector2(-s * 0.07, -2), mid + Vector2(s * 0.07, -2), mid + Vector2(s * 0.03, s * 0.2), mid + Vector2(-s * 0.03, s * 0.2)]), w.color.lightened(0.4))
		&"spear", &"arrow":
			var is_spear := w.shape == &"spear"
			var tip_len := s * (0.26 if is_spear else 0.16)
			var shaft := 4.5 if is_spear else 3.0
			canvas.draw_line(Vector2(-s * 0.5, 0), Vector2(s * 0.5, 0), ink, shaft, true)
			# A leaf-shaped steel blade.
			var blade := PackedVector2Array([
				Vector2(s * 0.46, 0), Vector2(s * 0.5 + tip_len * 0.35, -tip_len * 0.32), Vector2(s * 0.5 + tip_len, 0), Vector2(s * 0.5 + tip_len * 0.35, tip_len * 0.32),
			])
			canvas.draw_colored_polygon(blade, steel)
			blade.append(blade[0])
			canvas.draw_polyline(blade, ink, 2.0, true)
			if is_spear:
				canvas.draw_line(Vector2(s * 0.4, -4), Vector2(s * 0.4, 4), ink, 3.0, true)
			else:
				for side: float in [-1.0, 1.0]:
					canvas.draw_colored_polygon(PackedVector2Array([
						Vector2(-s * 0.5, 0), Vector2(-s * 0.5 + 12, 0), Vector2(-s * 0.5 - 2, side * 7),
					]), Color(0.9, 0.3, 0.3))
		&"bomb":
			canvas.draw_circle(Vector2.ZERO, s * 0.5, ink, true, -1.0, true)
			canvas.draw_circle(Vector2(-s * 0.16, -s * 0.16), s * 0.12, Color(0.6, 0.6, 0.66), true, -1.0, true)
			canvas.draw_rect(Rect2(Vector2(s * 0.3, -s * 0.12), Vector2(s * 0.2, s * 0.24)), ink)
			canvas.draw_line(Vector2(s * 0.5, 0), Vector2(s * 0.68, -s * 0.14), Color(0.6, 0.45, 0.3), 2.0, true)
			canvas.draw_circle(Vector2(s * 0.7, -s * 0.16), 3.5, Color(1.0, 0.8, 0.3), true, -1.0, true)
			canvas.draw_circle(Vector2(s * 0.7, -s * 0.16), 6.0, Color(1.0, 0.5, 0.2, 0.4), true, -1.0, true)
		&"boomerang":
			var arm := PackedVector2Array([Vector2(-s * 0.5, s * 0.22), Vector2(0, -s * 0.18), Vector2(s * 0.5, s * 0.22), Vector2(s * 0.38, s * 0.3), Vector2(0, 0), Vector2(-s * 0.38, s * 0.3)])
			canvas.draw_colored_polygon(arm, ink)
			canvas.draw_line(Vector2(-s * 0.36, s * 0.16), Vector2(-s * 0.12, -s * 0.02), w.color, 2.5, true)
			canvas.draw_line(Vector2(s * 0.36, s * 0.16), Vector2(s * 0.12, -s * 0.02), w.color, 2.5, true)
		&"axe":
			canvas.draw_line(Vector2(-s * 0.55, 0), Vector2(s * 0.5, 0), ink, 5.0, true)
			var blade := PackedVector2Array([Vector2(s * 0.22, -3), Vector2(s * 0.48, -3), Vector2(s * 0.62, -s * 0.42), Vector2(s * 0.7, 0), Vector2(s * 0.62, s * 0.42), Vector2(s * 0.48, 3), Vector2(s * 0.22, 3)])
			canvas.draw_colored_polygon(blade, ink)
			canvas.draw_polyline(PackedVector2Array([Vector2(s * 0.62, -s * 0.38), Vector2(s * 0.68, 0), Vector2(s * 0.62, s * 0.38)]), steel, 3.0, true)
		&"plunger":
			canvas.draw_line(Vector2(-s * 0.5, 0), Vector2(s * 0.32, 0), Color(0.55, 0.36, 0.2), 4.0, true)
			canvas.draw_line(Vector2(-s * 0.5, 0), Vector2(s * 0.32, 0), ink, 1.0, true)
			var cup := PackedVector2Array([Vector2(s * 0.3, -s * 0.12), Vector2(s * 0.5, -s * 0.28), Vector2(s * 0.56, 0), Vector2(s * 0.5, s * 0.28), Vector2(s * 0.3, s * 0.12)])
			canvas.draw_colored_polygon(cup, w.color)
			cup.append(cup[0])
			canvas.draw_polyline(cup, ink, 2.5, true)
		_:
			canvas.draw_circle(Vector2.ZERO, s * 0.5 + 1.5, ink, true, -1.0, true)
			canvas.draw_circle(Vector2.ZERO, s * 0.5 - 1.0, Color(0.32, 0.3, 0.34), true, -1.0, true)
			canvas.draw_circle(Vector2(-s * 0.15, -s * 0.15), s * 0.16, Color(0.75, 0.75, 0.8), true, -1.0, true)


## Draws the weapon as held in the hand, in hand space (+x points where the throw goes).
## Hammers and spears are the projectile itself, so they vanish once thrown (loaded is
## false). The slingshot and bow stay in the hand; only the pebble or arrow leaves.
## pull (0..1) draws the band or string back while aiming.
static func draw_held(canvas: CanvasItem, w: WeaponData, xf: Transform2D, loaded: bool, pull: float) -> void:
	var ink := Color(0.06, 0.055, 0.07)
	match w.shape:
		&"pebble":
			canvas.draw_set_transform_matrix(xf)
			# Y-shaped frame in ink: stem from the fist, two prongs ahead.
			canvas.draw_line(Vector2(-2, 0), Vector2(11, 0), ink, 5.0, true)
			for side: float in [-1.0, 1.0]:
				canvas.draw_line(Vector2(10, 0), Vector2(20, side * 11), ink, 4.5, true)
				canvas.draw_circle(Vector2(20, side * 11), 2.5, ink, true, -1.0, true)
			var pouch := Vector2(4 - pull * 22, 0)
			for side: float in [-1.0, 1.0]:
				canvas.draw_line(Vector2(20, side * 11), pouch, Color(0.9, 0.3, 0.3), 2.0, true)
			canvas.draw_circle(pouch, 4.0, ink, true, -1.0, true)
			if loaded:
				canvas.draw_circle(pouch, w.size * 0.42 + 1.5, ink, true, -1.0, true)
				canvas.draw_circle(pouch, w.size * 0.42 - 1.0, Color(0.32, 0.3, 0.34), true, -1.0, true)
		&"arrow":
			canvas.draw_set_transform_matrix(xf)
			# A recurve bow across the aim line, string drawn back to the nock.
			var limb := PackedVector2Array()
			for i in 15:
				var a := lerpf(-1.2, 1.2, i / 14.0)
				limb.append(Vector2(4 + cos(a) * 10.0 - absf(a) * absf(a) * 2.0, sin(a) * 26.0))
			canvas.draw_polyline(limb, ink, 5.0, true)
			var nock := Vector2(2 - pull * 18, 0)
			canvas.draw_line(limb[0], nock, Color(0.92, 0.9, 0.85), 1.5, true)
			canvas.draw_line(limb[limb.size() - 1], nock, Color(0.92, 0.9, 0.85), 1.5, true)
			if loaded:
				draw_weapon(canvas, w, xf * Transform2D(0.0, nock + Vector2(w.size * 0.5, 0)))
		&"hammer":
			# Held low across the body by the middle of the shaft, head out front.
			if loaded:
				draw_weapon(canvas, w, xf * Transform2D(0.0, Vector2(-w.size * 0.08, 0)))
		_:
			if loaded:
				draw_weapon(canvas, w, xf * Transform2D(-0.7, Vector2.ZERO))


static func _stick(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(from, to, INK, width + 4.0, true)
	canvas.draw_line(from, to, color, width, true)
