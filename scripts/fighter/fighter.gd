class_name Fighter
extends Node2D
## Pen-and-ink stickman drawn like the hand sketch: thin black lines, a solid round
## head, sharp feet and an oversized weapon, drawn in code from a skeleton of points.
## Standing, the points come from an animated pose that wobbles on a spring. A big
## hit hands them to a StickRagdoll so the fighter flies and tumbles, then blends
## back to the pose as they get up; a knockout leaves them limp. Hitboxes stay in
## the standing pose.

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
const HEAD_RADIUS := 15.0
const HIP_REST := Vector2(0, -46)
const NECK_REST := Vector2(2, -88)
const ARM_LENGTH := 26.0
## Slingshot and bow users hold their weapon out at arm's length, lowered when idle.
const RANGED_ARM_LENGTH := 33.0
const RANGED_REST_ANGLE := 0.45
const ARM_REST_ANGLE := -0.9
## The hammer hangs low across the body, like the sketch.
const HAMMER_REST_ANGLE := 0.75
## Pen line width for the limbs.
const LINE := 4.5
const HAND_REST := Vector2(20, -92)
const SPRING := 60.0
const DAMPING := 7.0
const ARM_FOLLOW_SPEED := 14.0
const MAX_STUCK := 6
## Hits doing at least this much damage knock the fighter over.
const KNOCKDOWN_DAMAGE := 24
## Share of the projectile's velocity passed to the body on a knockdown.
const RAGDOLL_PUSH := 0.55
## Time on the floor before getting up, and how long getting up takes.
const DOWN_TIME := 1.1
const GETUP_TIME := 0.55

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
## Crate buffs: a shield that blocks the next hit, and double damage on the next throw.
var shielded := false
var powered := false

var _tilt := 0.0
var _tilt_velocity := 0.0
var _arm := ARM_REST_ANGLE
var _swing := 0.0
var _flash := 0.0
var _squash := 0.0
var _ouch := 0.0
var _time := 0.0
var _hitboxes: Array[Hitbox] = []
## Spears and arrows that hit stay stuck in the body: [{weapon, xf}] in torso space.
var _stuck: Array[Dictionary] = []
var _torso_xf := Transform2D.IDENTITY
var _celebrating := false
var _ragdoll: StickRagdoll
var _ragdoll_time := 0.0
var _getup := 0.0
## The skeleton drawn last frame, in node space.
var _points := {}


## with_hitboxes is false for menu previews, which must never be hit.
func setup(fighter_data: FighterData, facing_dir: int, ai: bool, with_hitboxes: bool = true) -> void:
	data = fighter_data
	facing = facing_dir
	is_ai = ai
	health = Rules.MAX_HEALTH
	_time = randf() * TAU
	_points = _posed_points()
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


## True once the fighter is standing still (or a knocked-out body has stopped moving).
func is_settled() -> bool:
	if _ragdoll == null:
		return true
	if is_knocked_out():
		return _ragdoll_time > 0.6 and _ragdoll.speed() < 25.0
	return false


## Where the head is right now (it moves when knocked over).
func head_position() -> Vector2:
	return global_position + _points.get(&"head", HEAD_CENTER)


func get_hitbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for box in _hitboxes:
		rids.append(box.get_rid())
	return rids


func take_hit(part: StringName, damage: int, impact_velocity: Vector2) -> void:
	if is_knocked_out():
		return
	health = maxi(0, health - damage)
	_flash = 1.0
	_squash = 1.0
	_ouch = 1.0
	health_changed.emit(self, health)
	if health == 0 or damage >= KNOCKDOWN_DAMAGE:
		_knock_down(part, impact_velocity)
	else:
		_tilt_velocity += clampf(impact_velocity.x * 0.0055, -6.0, 6.0) * (1.6 if part == Rules.HEAD else 1.0)
	if health == 0:
		knocked_out.emit(self)


## Leaves a copy of a sticking weapon in the body where it hit, angled along its flight.
func stick(weapon: WeaponData, global_point: Vector2, velocity: Vector2) -> void:
	var to_torso := Transform2D(0.0, global_position) * _torso_xf
	var local_point := to_torso.affine_inverse() * global_point
	var local_dir := to_torso.affine_inverse().basis_xform(velocity.normalized())
	# Sink the tip a little way in.
	var xf := Transform2D(local_dir.angle(), local_point) * Transform2D(0.0, Vector2(-weapon.size * 0.32, 0))
	_stuck.append({"weapon": weapon, "xf": xf})
	if _stuck.size() > MAX_STUCK:
		_stuck.pop_front()


## Victory: hop on the spot waving the weapon overhead.
func heal(amount: int) -> void:
	health = mini(Rules.MAX_HEALTH, health + amount)
	health_changed.emit(self, health)


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


## Hands the current pose to the ragdoll and kicks the part that was hit.
func _knock_down(part: StringName, impact_velocity: Vector2) -> void:
	if _ragdoll == null:
		_ragdoll = StickRagdoll.new()
		_ragdoll.start(_points, HEAD_RADIUS)
	_ragdoll_time = 0.0
	_getup = 0.0
	var kick := impact_velocity * RAGDOLL_PUSH + Vector2(0, -260)
	var struck: Array = [&"neck", &"hip"]
	match part:
		Rules.HEAD:
			struck = [&"head", &"neck"]
		Rules.LEGS:
			struck = [&"bknee", &"fknee", &"bfoot", &"ffoot"]
	_ragdoll.push_all(kick, 0.45)
	for point: StringName in struck:
		_ragdoll.push(point, kick * 1.3)


func _process(delta: float) -> void:
	_time += delta
	var accel := -SPRING * _tilt - DAMPING * _tilt_velocity
	_tilt_velocity += accel * delta
	_tilt += _tilt_velocity * delta
	var ranged := _is_ranged()
	var arm_target := RANGED_REST_ANGLE if ranged else ARM_REST_ANGLE
	if data != null and data.weapon.shape == &"hammer":
		arm_target = HAMMER_REST_ANGLE
	if _celebrating:
		arm_target = -1.9 + sin(_time * 10.0) * 0.4
	elif aiming:
		# Throwers wind up behind the head; archers point straight down the aim line.
		arm_target = -deg_to_rad(aim_angle) - (0.0 if ranged else aim_power * 0.9)
	_arm = lerp_angle(_arm, arm_target, 1.0 - exp(-ARM_FOLLOW_SPEED * delta))
	_flash = maxf(0.0, _flash - delta * 5.0)
	_squash = maxf(0.0, _squash - delta * 4.0)
	_ouch = maxf(0.0, _ouch - delta * 1.5)

	var posed := _posed_points()
	if _ragdoll == null:
		_points = posed
	else:
		_ragdoll_time += delta
		if is_knocked_out() or _ragdoll_time < DOWN_TIME:
			_ragdoll.step(delta)
			_points = _ragdoll.pos.duplicate()
		else:
			# Get up: blend from where the body lies back into the standing pose.
			_getup = minf(1.0, _getup + delta / GETUP_TIME)
			var t := ease(_getup, -2.0)
			_points = {}
			for point: StringName in StickRagdoll.POINTS:
				_points[point] = (_ragdoll.pos[point] as Vector2).lerp(posed[point], t)
			if _getup >= 1.0:
				_ragdoll = null
	_torso_xf = _torso_transform(_points)
	queue_redraw()


## The standing (animated) skeleton in node space, posed like the sketch: torso
## upright, one leg straight back, the other knee bent forward, back fist raised.
## The throwing arm follows the aim; small hits add wobble and squash.
func _posed_points() -> Dictionary:
	var breathe := sin(_time * 3.0)
	var wobble := sin(_time * 18.0) * 0.12 * _squash
	var stretch := Vector2(1.0 + 0.12 * _squash, 1.0 - 0.12 * _squash)
	var sway := sin(_time * 2.2) * 0.025
	var hop := -absf(sin(_time * 7.0)) * 16.0 if _celebrating else 0.0
	var xf := Transform2D(_tilt + sway + wobble, Vector2(facing * stretch.x, stretch.y), 0.0, Vector2(0, hop))
	var bob := breathe * 1.2
	var hip := HIP_REST + Vector2(0, bob * 0.6)
	var neck := NECK_REST + Vector2(0, bob)
	var shoulder := neck.lerp(hip, 0.15)
	var knee_bend := breathe * 1.0 + _squash * 6.0
	var back_elbow := shoulder + Vector2(12, 7)
	var back_hand := shoulder + Vector2(16, -7 + sin(_time * 2.2) * 1.5)
	if _celebrating:
		back_hand = shoulder + Vector2(-10 + sin(_time * 10.0 + 1.0) * 5.0, -28)
		back_elbow = shoulder + Vector2(-10, -10)
	var arm_angle := _arm + _swing * (0.4 if _is_ranged() else 1.6)
	var hand := shoulder + Vector2.from_angle(arm_angle) * (RANGED_ARM_LENGTH if _is_ranged() else ARM_LENGTH)
	var elbow := shoulder.lerp(hand, 0.5) + Vector2.from_angle(arm_angle + PI / 2) * 5.0
	var body := {
		&"head": HEAD_CENTER + Vector2(2, bob),
		&"neck": neck,
		&"hip": hip,
		&"bknee": Vector2(-8, -24),
		&"bfoot": Vector2(-17, -2),
		&"fknee": Vector2(14 + knee_bend, -30),
		&"ffoot": Vector2(3, -2),
		&"belbow": back_elbow,
		&"bhand": back_hand,
		&"felbow": elbow,
		&"fhand": hand,
	}
	var points := {}
	for point: StringName in body:
		points[point] = xf * (body[point] as Vector2)
	return points


## Maps torso space (standing, facing right) onto the torso as it is now, so weapons
## stuck in the body follow it when it tumbles.
func _torso_transform(points: Dictionary) -> Transform2D:
	var rest_dir := Vector2((NECK_REST - HIP_REST).x * facing, (NECK_REST - HIP_REST).y)
	var now_dir: Vector2 = points[&"neck"] - points[&"hip"]
	var mirror := Transform2D(0.0, Vector2(facing, 1), 0.0, Vector2.ZERO)
	var turn := Transform2D(now_dir.angle() - rest_dir.angle(), Vector2.ZERO)
	return Transform2D(0.0, points[&"hip"]) * turn * mirror * Transform2D(0.0, -HIP_REST)


func _draw() -> void:
	if data == null or _points.is_empty():
		return
	var p := _points
	var knocked := is_knocked_out()
	var f := float(facing)

	# A soft shadow with a faint ring in the fighter's colour, to tell the sides apart.
	var ground_x: float = (p[&"hip"] as Vector2).x
	draw_set_transform(Vector2(ground_x, 1), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.28), true, -1.0, true)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color(data.body_color, 0.55), 6.0, true)
	draw_set_transform(Vector2.ZERO)

	# Pen-and-ink: every line solid black (flashing white on a hit).
	var ink := INK.lerp(Color.WHITE, _flash * 0.85)
	var shoulder: Vector2 = (p[&"neck"] as Vector2).lerp(p[&"hip"], 0.15)

	_taper(shoulder, p[&"belbow"], LINE, LINE * 0.85, ink)
	_taper(p[&"belbow"], p[&"bhand"], LINE * 0.85, LINE * 0.8, ink)
	draw_circle(p[&"bhand"], 4.5, ink, true, -1.0, true)
	_taper(p[&"hip"], p[&"bknee"], LINE * 1.15, LINE, ink)
	_taper(p[&"bknee"], p[&"bfoot"], LINE, LINE * 0.8, ink)
	_foot(p[&"bfoot"], p[&"bknee"], ink)
	_taper(p[&"hip"], p[&"fknee"], LINE * 1.15, LINE, ink)
	_taper(p[&"fknee"], p[&"ffoot"], LINE, LINE * 0.8, ink)
	_foot(p[&"ffoot"], p[&"fknee"], ink)
	_taper(p[&"hip"], p[&"neck"], LINE * 1.2, LINE, ink)

	var head: Vector2 = p[&"head"]
	draw_circle(head, HEAD_RADIUS, ink, true, -1.0, true)
	if knocked:
		var tilt := (head - (p[&"neck"] as Vector2)).angle() + PI / 2
		draw_set_transform_matrix(Transform2D(tilt, Vector2(f, 1), 0.0, head))
		for e: Vector2 in [Vector2(6, -2), Vector2(-3, -2)]:
			draw_line(e + Vector2(-2.5, -2.5), e + Vector2(2.5, 2.5), Color.WHITE, 2.0, true)
			draw_line(e + Vector2(-2.5, 2.5), e + Vector2(2.5, -2.5), Color.WHITE, 2.0, true)
		draw_set_transform(Vector2.ZERO)

	for stuck in _stuck:
		Projectile.draw_weapon(self, stuck["weapon"], _torso_xf * stuck["xf"])
	draw_set_transform(Vector2.ZERO)

	var hand: Vector2 = p[&"fhand"]
	var arm := (hand - shoulder).angle()
	# The hammer is carried level, like the sketch, until the wind-up swings it.
	if data.weapon.shape == &"hammer" and not aiming and _swing < 0.05 and not _celebrating and _ragdoll == null:
		arm = 0.08 if facing == 1 else PI - 0.08
	var pull := aim_power if aiming else 0.0
	Projectile.draw_held(self, data.weapon, Transform2D(arm, Vector2(1, f), 0.0, hand), holding_weapon, pull)
	draw_set_transform(Vector2.ZERO)
	_taper(shoulder, p[&"felbow"], LINE, LINE * 0.85, ink)
	_taper(p[&"felbow"], hand, LINE * 0.85, LINE * 0.8, ink)
	draw_circle(hand, 4.5, ink, true, -1.0, true)

	if pinned and not knocked:
		_draw_chains()
	if shielded and not knocked:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		var centre: Vector2 = (p[&"hip"] as Vector2).lerp(head, 0.45)
		draw_circle(centre, 62.0, Color(0.4, 0.7, 1.0, 0.1 + 0.05 * pulse), true, -1.0, true)
		draw_arc(centre, 62.0, 0.0, TAU, 40, Color(0.55, 0.85, 1.0, 0.7), 3.0, true)
	if powered and not knocked:
		draw_circle(hand, 12.0 + sin(_time * 8.0) * 2.0, Color(1.0, 0.3, 0.25, 0.35), true, -1.0, true)
		draw_string(UiStyle.title_font(), head + Vector2(18, -18), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.4, 0.3))

	if is_turn and not knocked:
		var tip := head + Vector2(0, -46 - absf(sin(_time * 5.0)) * 12.0)
		_poly([tip, tip + Vector2(-15, -20), tip + Vector2(-6, -20), tip + Vector2(-6, -34), tip + Vector2(6, -34), tip + Vector2(6, -20), tip + Vector2(15, -20)], data.body_color.lightened(0.25), 3.5)
	if knocked:
		for i in 3:
			var a := _time * 4.0 + i * TAU / 3.0
			_draw_star(head + Vector2(cos(a) * 24.0, sin(a) * 8.0 - 28.0), 7.0)


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


# --- pen-and-ink parts ---

## A pen stroke: `from_width` at one end narrowing to `to_width`, with round ends.
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


## A sharp pointed foot at the end of the shin, toes pointing the way the fighter faces.
func _foot(at: Vector2, knee: Vector2, color: Color) -> void:
	var down := (at - knee).normalized()
	var toe := down.orthogonal() * float(facing) if down.length() > 0.0 else Vector2(facing, 0)
	draw_colored_polygon(PackedVector2Array([at - toe * 3.0 - down * 2.0, at + toe * 14.0 + down * 1.5, at - toe * 2.0 + down * 2.5]), color)


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


func _draw_star(at: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var rr := radius if i % 2 == 0 else radius * 0.45
		points.append(at + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
	draw_colored_polygon(points, Color(1.0, 0.86, 0.25))
	points.append(points[0])
	draw_polyline(points, OUTLINE, 1.5, true)
