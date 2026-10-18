class_name Projectile
extends Node2D
## A thrown weapon. It follows Rules.position_at exactly and raycasts each step,
## so fast throws can't pass through a limb between frames.

signal hit_fighter(projectile: Projectile, fighter: Fighter, is_head: bool)
signal finished(projectile: Projectile)

const INK := Color(0.12, 0.1, 0.14)
const COLLISION_MASK := 0b11
const MAX_LIFETIME := 8.0
const KILL_DEPTH := 300.0
const KILL_RANGE := 4000.0

var weapon: WeaponData
var thrower: Fighter

var _origin := Vector2.ZERO
var _velocity := Vector2.ZERO
var _t := 0.0
var _done := false
var _exclude: Array[RID] = []


func launch(from_weapon: WeaponData, from_fighter: Fighter, from: Vector2, velocity: Vector2) -> void:
	weapon = from_weapon
	thrower = from_fighter
	_origin = from
	_velocity = velocity
	_exclude = from_fighter.get_hitbox_rids()
	global_position = from
	rotation = velocity.angle()


func current_velocity() -> Vector2:
	return _velocity + Vector2(0.0, Rules.GRAVITY * _t)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
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
	_finish(weapon.sticks)


func _finish(linger: bool) -> void:
	_done = true
	finished.emit(self)
	var tween := create_tween()
	tween.tween_interval(2.5 if linger else 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


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
		&"spear", &"arrow":
			var is_spear := w.shape == &"spear"
			var tip_len := s * (0.22 if is_spear else 0.16)
			_stick(canvas, Vector2(-s * 0.5, 0), Vector2(s * 0.5, 0), 5.0 if is_spear else 3.5, w.color)
			var tip := PackedVector2Array([
				Vector2(s * 0.5, -tip_len * 0.4), Vector2(s * 0.5 + tip_len, 0), Vector2(s * 0.5, tip_len * 0.4),
			])
			canvas.draw_colored_polygon(tip, Color(0.82, 0.84, 0.88))
			tip.append(tip[0])
			canvas.draw_polyline(tip, INK, 2.0)
			if not is_spear:
				for side: float in [-1.0, 1.0]:
					canvas.draw_colored_polygon(PackedVector2Array([
						Vector2(-s * 0.5, 0), Vector2(-s * 0.5 + 10, 0), Vector2(-s * 0.5 - 2, side * 7),
					]), Color(0.9, 0.3, 0.3))
		_:
			canvas.draw_circle(Vector2.ZERO, s * 0.5 + 2.5, INK)
			canvas.draw_circle(Vector2.ZERO, s * 0.5, w.color)


static func _stick(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(from, to, INK, width + 4.0)
	canvas.draw_line(from, to, color, width)
