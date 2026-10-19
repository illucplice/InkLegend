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
## Body colour of a powered-up anime fighter.
const POWER_GOLD := Color(0.98, 0.74, 0.16)
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
## Special meter (0..1), mirrored from the match; anime fighters glow when it is full.
var charge := 0.0
## Seconds left of a special's power-up glow (set while charging a beam or orb).
var _powering := 0.0
## Pen colour (a Shop cosmetic for the player's fighter).
var ink_color := INK

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
## Fatality: a knocked-out fighter staggers back up, dazed, to take the finisher.
var _dazed := false
## A transformation drawn instead of the usual look: "vasto" (Ichi's Vasto Lorde).
var form: StringName = &""
var _bankai_sword: WeaponData
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
## Fatality: stand a knocked-out fighter back up, swaying and seeing stars.
func stand_dazed() -> void:
	_dazed = true
	_celebrating = false
	aiming = false
	if _ragdoll != null:
		_ragdoll_time = maxf(_ragdoll_time, DOWN_TIME)
		_getup = 0.0


## Where each joint is in the world right now, plus the shoulder.
func body_points() -> Dictionary:
	var out := {}
	for point: StringName in _points:
		out[point] = to_global(_points[point])
	out[&"shoulder"] = (out[&"neck"] as Vector2).lerp(out[&"hip"], 0.15)
	return out


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
	return data != null and (data.weapon.shape == &"pebble" or data.weapon.shape == &"arrow" or data.weapon.shape == &"ki" or data.weapon.shape == &"fist")


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
	_powering = maxf(0.0, _powering - delta)

	var posed := _posed_points()
	if _ragdoll == null:
		_points = posed
	else:
		_ragdoll_time += delta
		if (is_knocked_out() and not _dazed) or _ragdoll_time < DOWN_TIME:
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
	if _dazed:
		sway = sin(_time * 3.1) * 0.16
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

	if _has_aura() and (charge >= 1.0 or _powering > 0.0) and not is_knocked_out():
		_draw_aura(p)

	# Pen-and-ink: every line solid black (flashing white on a hit).
	var ink := ink_color.lerp(Color.WHITE, _flash * 0.85)
	# Powered-up anime fighters glow gold from head to toe, with a shimmer.
	if _is_anime() and (charge >= 1.0 or _powering > 0.0) and not is_knocked_out():
		ink = POWER_GOLD.lerp(Color(1.0, 0.95, 0.6), 0.25 + 0.25 * sin(_time * 9.0)).lerp(Color.WHITE, _flash * 0.85)
	if form == &"vasto":
		ink = Color(0.96, 0.95, 0.92).lerp(Color(1.0, 0.6, 0.6), _flash * 0.6)
	var shoulder: Vector2 = (p[&"neck"] as Vector2).lerp(p[&"hip"], 0.15)

	if form == &"vasto":
		_draw_vasto_outline(p, shoulder)
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
	_draw_outfit(p, shoulder, ink)

	var head: Vector2 = p[&"head"]
	draw_circle(head, HEAD_RADIUS, ink, true, -1.0, true)
	if _is_anime():
		_draw_hair(head, p[&"neck"], ink)
	elif data.style == &"straw":
		_draw_straw_hat(head, p[&"neck"], ink)
	elif data.style == &"reaper" and form != &"vasto":
		_draw_reaper_hair(head, p[&"neck"], ink)
	if form == &"vasto":
		_draw_vasto_details(p)
	elif _bankai():
		_draw_hollow_mask(head, p[&"neck"])
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
	# The cleaver is carried low in front, the blade slanting up across the back.
	if data.weapon.shape == &"cleaver" and not _bankai() and not aiming and _swing < 0.05 and not _celebrating and _ragdoll == null:
		arm = 0.9 if facing == 1 else PI - 0.9
	var pull := aim_power if aiming else 0.0
	Projectile.draw_held(self, _held_weapon(), Transform2D(arm, Vector2(1, f), 0.0, hand), holding_weapon, pull)
	draw_set_transform(Vector2.ZERO)
	_taper(shoulder, p[&"felbow"], LINE, LINE * 0.85, ink)
	_taper(p[&"felbow"], hand, LINE * 0.85, LINE * 0.8, ink)
	draw_circle(hand, 4.5, ink, true, -1.0, true)
	_draw_sleeve(shoulder, p[&"felbow"])

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


# --- anime fighters ---

func _is_anime() -> bool:
	return data != null and (data.style == &"anime" or data.style == &"anime2")


## Glow while powering up for a special.
func power_up(seconds: float) -> void:
	_powering = seconds


## Anime hair in head space. "anime" (Gok): a handful of chunky spikes swept up and
## back, with bangs over the brow. "anime2" (Egita): a widow's peak and a tall flame
## of spikes standing straight up. Each spike is [angle on the head (degrees, -90 is
## straight up), length, width]. When the special meter is full the hair turns gold
## and rises, longer and more upright.
func _draw_hair(head: Vector2, neck: Vector2, ink: Color) -> void:
	var rest := Vector2((HEAD_CENTER - NECK_REST).x * facing, (HEAD_CENTER - NECK_REST).y)
	var tilt := (head - neck).angle() - rest.angle()
	draw_set_transform_matrix(Transform2D(tilt, Vector2(facing, 1), 0.0, head))
	var powered := charge >= 1.0 or _powering > 0.0
	# Powered hair is a shade brighter than the golden body so it still reads.
	var color := data.hair_color.lightened(0.15).lerp(Color.WHITE, 0.15 * sin(_time * 10.0)) if powered else ink
	var r := HEAD_RADIUS
	var gok := data.style == &"anime"
	var spikes: Array = [[-40.0, 9.0, 6.0], [-72.0, 14.0, 8.0], [-104.0, 18.0, 9.0], [-136.0, 19.0, 9.0], [-166.0, 16.0, 8.0], [-196.0, 11.0, 7.0]] if gok \
		else [[-28.0, 12.0, 9.0], [-45.0, 21.0, 10.0], [-62.0, 28.0, 10.0], [-79.0, 32.0, 10.0], [-95.0, 32.0, 10.0], [-111.0, 29.0, 10.0], [-128.0, 23.0, 10.0], [-145.0, 16.0, 9.0], [-162.0, 10.0, 8.0]]
	var grow := (1.55 if gok else 1.2) if powered else 1.0
	var bob := sin(_time * 8.0) * 1.5 if powered else 0.0
	for spike: Array in spikes:
		var angle: float = spike[0]
		if powered:
			angle = lerpf(angle, -92.0, 0.3)
		var a := deg_to_rad(angle)
		# Gok's spikes curl back a little; Egita's flare up into a tall flame.
		var lean := -0.28 if gok else (deg_to_rad(-90.0) - a) * 0.12
		var base := Vector2.from_angle(a) * (r - 4.0)
		var tip := Vector2.from_angle(a + lean) * (r + float(spike[1]) * grow) + Vector2(0, bob)
		var side := Vector2.from_angle(a + PI / 2) * float(spike[2])
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), color)
	var cap := PackedVector2Array()
	for i in 13:
		cap.append(Vector2.from_angle(lerpf(PI * 1.02, TAU * 0.99, i / 12.0)) * (r + 1.0))
	cap.append(Vector2(r * 0.55, -r * 0.1))
	cap.append(Vector2(-r * 0.7, r * 0.15))
	draw_colored_polygon(cap, color)
	if gok:
		# Bangs falling over the forehead.
		draw_colored_polygon(PackedVector2Array([Vector2(2, -r + 2), Vector2(r + 3, -4), Vector2(r * 0.35, -r * 0.3)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(r * 0.3, -r + 4), Vector2(r * 0.85, 3), Vector2(r * 0.5, -r * 0.25)]), color)
	else:
		# A sharp widow's peak.
		draw_colored_polygon(PackedVector2Array([Vector2(r * 0.2, -r * 0.85), Vector2(r * 0.95, -r * 0.4), Vector2(r * 0.6, -r * 0.05)]), color)
	draw_set_transform(Vector2.ZERO)


## A flickering flame aura around the body in the fighter's colour.
func _draw_aura(p: Dictionary) -> void:
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"head"], 0.4)
	var glow := data.body_color.lightened(0.3)
	if data.style == &"straw":
		glow = Color(1.0, 0.72, 0.72)
	elif data.style == &"reaper":
		glow = Color(0.85, 0.1, 0.18)
	for layer in 3:
		var points := PackedVector2Array()
		var count := 18
		for i in count:
			var a := TAU * i / count
			var flame := 1.0 + 0.25 * sin(_time * 14.0 + i * 2.7 + layer) + (0.35 if sin(a) < -0.3 else 0.0)
			var radius := Vector2(46.0, 70.0) * (1.0 - layer * 0.22) * flame
			points.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y - (8.0 if sin(a) < 0.0 else 0.0)))
		draw_colored_polygon(points, Color(glow, 0.16 + layer * 0.08))
	for i in 5:
		var rise := fmod(_time * 1.6 + i * 0.2, 1.0)
		draw_circle(centre + Vector2(sin(i * 2.1) * 30.0, 40.0 - rise * 110.0), 3.0 * (1.0 - rise), Color(glow, 0.8), true, -1.0, true)


# --- straw hat and reaper ---

## Fighters with a power-up aura when their meter is full (only the anime pair turn gold).
func _has_aura() -> bool:
	return _is_anime() or (data != null and (data.style == &"straw" or data.style == &"reaper"))


## Sets the canvas to head space: origin at the head, x pointing the way they face,
## tilted with the head.
func _head_space(head: Vector2, neck: Vector2) -> void:
	var rest := Vector2((HEAD_CENTER - NECK_REST).x * facing, (HEAD_CENTER - NECK_REST).y)
	var tilt := (head - neck).angle() - rest.angle()
	draw_set_transform_matrix(Transform2D(tilt, Vector2(facing, 1), 0.0, head))


## Clothes drawn over the stick body, before the head: Lufi's open red vest, sash and
## blue shorts; Ichi's black robe, sword strap, wide sleeve and flared trousers.
func _draw_outfit(p: Dictionary, shoulder: Vector2, ink: Color) -> void:
	if data.style != &"straw" and data.style != &"reaper":
		return
	var hip: Vector2 = p[&"hip"]
	var neck: Vector2 = p[&"neck"]
	var spine := (neck - hip).normalized()
	var side := Vector2(-spine.y, spine.x)
	if data.style == &"straw":
		for knee: StringName in [&"bknee", &"fknee"]:
			_taper(hip, hip.lerp(p[knee], 0.7), 11.0, 10.0, Color(0.25, 0.4, 0.8))
		var chest := neck.lerp(hip, 0.1)
		var waist := neck.lerp(hip, 0.8)
		_poly([chest + side * 9.0, waist + side * 10.0, waist - side * 10.0, chest - side * 9.0], data.body_color, 2.5)
		_taper(neck, hip, LINE * 1.6, LINE * 1.6, ink)
		_taper(hip + side * 9.0 + spine * 2.0, hip - side * 9.0 + spine * 2.0, 5.0, 5.0, Color(0.98, 0.82, 0.35))
		return
	if form == &"vasto":
		return
	if _bankai():
		_draw_bankai_coat(p, side)
		_poly([neck + side * 10.0, hip + side * 11.0, hip - side * 11.0, neck - side * 10.0], Color(0.08, 0.07, 0.1), 2.5)
		draw_colored_polygon(PackedVector2Array([neck + side * 6.0, neck.lerp(hip, 0.35), neck - side * 6.0]), Color(0.95, 0.94, 0.9))
		_taper(neck + side * 9.0, hip - side * 10.0, 4.0, 4.0, Color(0.55, 0.15, 0.15))
		_draw_sleeve(shoulder, p[&"belbow"])
		return
	var robe := Color(0.14, 0.13, 0.17)
	var fknee: Vector2 = p[&"fknee"]
	var bknee: Vector2 = p[&"bknee"]
	var hem_f := hip.lerp(fknee, 1.15)
	var hem_b := hip.lerp(bknee, 1.15)
	# Flared trousers: the hull of the hips and both hems, so the shape never twists.
	var hakama := Geometry2D.convex_hull(PackedVector2Array([hip + side * 10.0, hip - side * 10.0, hem_b + Vector2(-11, 0), hem_b + Vector2(11, 0), hem_f + Vector2(-11, 0), hem_f + Vector2(11, 0)]))
	hakama.remove_at(hakama.size() - 1)
	_poly(hakama, robe, 2.5)
	_poly([neck + side * 10.0, hip + side * 11.0, hip - side * 11.0, neck - side * 10.0], robe, 2.5)
	draw_colored_polygon(PackedVector2Array([neck + side * 6.0, neck.lerp(hip, 0.35), neck - side * 6.0]), Color(0.95, 0.94, 0.9))
	_taper(neck + side * 9.0, hip - side * 10.0, 4.0, 4.0, Color(0.55, 0.15, 0.15))
	_taper(hip + side * 11.0, hip - side * 11.0, 4.0, 4.0, Color(0.95, 0.94, 0.9))
	_draw_sleeve(shoulder, p[&"belbow"])


## Ichi's wide black sleeve hanging from the shoulder past the elbow.
func _draw_sleeve(shoulder: Vector2, elbow: Vector2) -> void:
	if data.style != &"reaper" or form == &"vasto":
		return
	var along := elbow - shoulder
	var across := along.normalized().orthogonal()
	var cuff := shoulder + along * 1.2
	_poly([shoulder + across * 6.0, cuff + across * 13.0 + Vector2(0, 8), cuff - across * 13.0 + Vector2(0, 8), shoulder - across * 6.0], Color(0.14, 0.13, 0.17), 2.5)


## Lufi's straw hat with its red band, over a mop of black hair.
func _draw_straw_hat(head: Vector2, neck: Vector2, ink: Color) -> void:
	_head_space(head, neck)
	var r := HEAD_RADIUS
	for spike in 5:
		var a := deg_to_rad(lerpf(150.0, 215.0, spike / 4.0))
		var base := Vector2.from_angle(a) * (r - 3.0)
		var tip := Vector2.from_angle(a) * (r + 7.0) + Vector2(0, 3)
		var across := Vector2.from_angle(a + PI / 2) * 4.0
		draw_colored_polygon(PackedVector2Array([base - across, tip, base + across]), ink)
	var straw := data.hair_color
	var brim_y := -r * 0.45
	var brim := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		brim.append(Vector2(cos(a) * r * 1.55, brim_y + sin(a) * r * 0.32))
	draw_colored_polygon(brim, straw)
	var brim_line := brim.duplicate()
	brim_line.append(brim[0])
	draw_polyline(brim_line, OUTLINE, 2.5, true)
	var crown := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		crown.append(Vector2(cos(a) * r * 0.85, brim_y - 2.0 + sin(a) * r * 0.85))
	draw_colored_polygon(crown, straw)
	var crown_line := crown.duplicate()
	draw_polyline(crown_line, OUTLINE, 2.5, true)
	draw_line(Vector2(-r * 0.83, brim_y - 5.0), Vector2(r * 0.83, brim_y - 5.0), Color(0.85, 0.15, 0.15), 5.0, true)
	for k in 4:
		var x := lerpf(-r * 1.2, r * 1.2, k / 3.0)
		draw_line(Vector2(x, brim_y - 1.0), Vector2(x * 1.08, brim_y + 3.0), straw.darkened(0.25), 1.5, true)
	draw_set_transform(Vector2.ZERO)


## Ichi's spiky orange hair, sticking out every which way.
func _draw_reaper_hair(head: Vector2, neck: Vector2, ink: Color) -> void:
	_head_space(head, neck)
	var r := HEAD_RADIUS
	var color := data.hair_color
	var spikes := [[-15.0, 9.0], [-40.0, 13.0], [-62.0, 15.0], [-84.0, 16.0], [-106.0, 16.0], [-128.0, 15.0], [-150.0, 14.0], [-172.0, 12.0], [-194.0, 10.0], [-214.0, 7.0]]
	for pass_index in 2:
		for spike: Array in spikes:
			var a := deg_to_rad(float(spike[0]))
			var grow := 2.5 if pass_index == 0 else 0.0
			var base := Vector2.from_angle(a) * (r - 3.0)
			var tip := Vector2.from_angle(a - 0.25) * (r + float(spike[1]) + grow)
			var across := Vector2.from_angle(a + PI / 2) * (7.0 + grow)
			draw_colored_polygon(PackedVector2Array([base - across, tip, base + across]), OUTLINE if pass_index == 0 else color)
	var cap := PackedVector2Array()
	for i in 13:
		cap.append(Vector2.from_angle(lerpf(PI * 1.05, TAU * 0.98, i / 12.0)) * (r + 1.0))
	cap.append(Vector2(r * 0.6, -r * 0.05))
	cap.append(Vector2(-r * 0.7, r * 0.2))
	draw_colored_polygon(cap, color)
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.1, -r * 0.9), Vector2(r * 1.05, -r * 0.15), Vector2(r * 0.55, -r * 0.35)]), color)
	draw_set_transform(Vector2.ZERO)


# --- Ichi's hollow powers ---

## The weapon drawn in the hand: Ichi swaps his cleaver for the bankai sword.
func _held_weapon() -> WeaponData:
	if not _bankai():
		return data.weapon
	if _bankai_sword == null:
		_bankai_sword = data.weapon.duplicate() as WeaponData
		_bankai_sword.shape = &"katana"
		_bankai_sword.size = 56.0
	return _bankai_sword


## Ichi with his special charged (or firing it): hollow mask and bankai coat.
func _bankai() -> bool:
	return data != null and data.style == &"reaper" and form != &"vasto" and (charge >= 1.0 or _powering > 0.0) and not is_knocked_out()


## Bankai: a long black coat to the ankles with a tattered hem and red lining.
func _draw_bankai_coat(p: Dictionary, side: Vector2) -> void:
	var hip: Vector2 = p[&"hip"]
	var neck: Vector2 = p[&"neck"]
	var feet: Vector2 = (p[&"bfoot"] as Vector2).lerp(p[&"ffoot"], 0.5)
	var hem := feet + Vector2(0, -4)
	var coat := PackedVector2Array([neck + side * 11.0, hip + side * 13.0, hem + Vector2(-30, 0) * float(facing), hem + Vector2(30, 0) * float(facing), hip - side * 13.0, neck - side * 11.0])
	coat = Geometry2D.convex_hull(coat)
	coat.remove_at(coat.size() - 1)
	_poly(coat, Color(0.08, 0.07, 0.1), 2.5)
	# Ragged hem.
	var left := hem + Vector2(-30, 0)
	for k in 6:
		var a := left + Vector2(k * 10.0, 0)
		draw_colored_polygon(PackedVector2Array([a, a + Vector2(10, 0), a + Vector2(5, 9 + (k % 2) * 6)]), Color(0.08, 0.07, 0.1))
	# Red lining down the open front.
	draw_line(hip.lerp(neck, 0.3) + side * 3.0, hem + Vector2(4.0 * facing, -2), Color(0.75, 0.12, 0.15), 3.0, true)


## The hollow mask over the front of the face: bone white, red stripes, a yellow eye.
func _draw_hollow_mask(head: Vector2, neck: Vector2) -> void:
	_head_space(head, neck)
	var r := HEAD_RADIUS
	var mask := PackedVector2Array()
	for i in 15:
		var a := lerpf(-1.75, 1.6, i / 14.0)
		mask.append(Vector2.from_angle(a) * (r + 1.5))
	mask.append(Vector2(-r * 0.15, r * 0.9))
	mask.append(Vector2(-r * 0.25, -r * 0.95))
	draw_colored_polygon(mask, Color(0.97, 0.96, 0.92))
	var rim := mask.duplicate()
	rim.append(mask[0])
	draw_polyline(rim, OUTLINE, 2.0, true)
	for k in 2:
		var x := r * (0.15 + k * 0.32)
		draw_line(Vector2(x, -r * 0.95), Vector2(x + 2.0, -r * 0.2), Color(0.8, 0.1, 0.12), 3.0, true)
	draw_circle(Vector2(r * 0.45, -r * 0.05), 4.5, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(r * 0.5, -r * 0.05), 2.0, Color(1.0, 0.85, 0.1), true, -1.0, true)
	for k in 4:
		var x := r * (0.2 + k * 0.18)
		draw_line(Vector2(x, r * 0.45), Vector2(x, r * 0.75), OUTLINE, 1.5, true)
	draw_set_transform(Vector2.ZERO)


## Vasto Lorde: a black outline drawn under the white limbs, so the body reads.
func _draw_vasto_outline(p: Dictionary, shoulder: Vector2) -> void:
	var w := LINE + 3.5
	for pair: Array in [[shoulder, p[&"belbow"]], [p[&"belbow"], p[&"bhand"]], [p[&"hip"], p[&"bknee"]], [p[&"bknee"], p[&"bfoot"]], [p[&"hip"], p[&"fknee"]], [p[&"fknee"], p[&"ffoot"]], [p[&"hip"], p[&"neck"]], [shoulder, p[&"felbow"]], [p[&"felbow"], p[&"fhand"]]]:
		draw_line(pair[0], pair[1], OUTLINE, w, true)
	for joint: StringName in [&"bhand", &"fhand", &"bfoot", &"ffoot"]:
		draw_circle(p[joint], 7.0, OUTLINE, true, -1.0, true)
	draw_circle(p[&"head"], HEAD_RADIUS + 2.0, OUTLINE, true, -1.0, true)
	# Long orange hair streaming down the back.
	var head: Vector2 = p[&"head"]
	var back := Vector2(-facing, 0)
	var flow := sin(_time * 4.0) * 4.0
	var hair := PackedVector2Array([head + Vector2(0, -HEAD_RADIUS), head + back * HEAD_RADIUS, head + back * 26.0 + Vector2(flow, 40), head + back * 18.0 + Vector2(flow * 1.5, 92), head + back * 4.0 + Vector2(0, 60), head + back * 4.0])
	_poly(hair, data.hair_color, 2.5)


## Vasto Lorde's details over the white body: fur, a hole in the chest, the skull
## face with horns and red markings.
func _draw_vasto_details(p: Dictionary) -> void:
	var fur := Color(0.98, 0.97, 0.94)
	for joint: StringName in [&"neck", &"bhand", &"fhand", &"bfoot", &"ffoot"]:
		for k in 3:
			var at: Vector2 = (p[joint] as Vector2) + Vector2.from_angle(k * TAU / 3.0 + _time) * 4.0
			draw_circle(at, 5.5, OUTLINE, true, -1.0, true)
			draw_circle(at, 4.0, fur, true, -1.0, true)
	var chest: Vector2 = (p[&"neck"] as Vector2).lerp(p[&"hip"], 0.3)
	draw_circle(chest, 8.0, OUTLINE, true, -1.0, true)
	draw_circle(chest, 5.0, Color(0.02, 0.02, 0.03), true, -1.0, true)
	var head: Vector2 = p[&"head"]
	_head_space(head, p[&"neck"])
	var r := HEAD_RADIUS
	for horn: float in [-1.0, 1.0]:
		var base := Vector2(r * 0.1, -r * 0.6 + horn * 4.0)
		var horn_line := PackedVector2Array([base, base + Vector2(r * 0.9, -r * 0.9 + horn * 3.0), base + Vector2(r * 2.1, -r * 0.6 + horn * 4.0)])
		draw_polyline(horn_line, OUTLINE, 6.5, true)
		draw_polyline(horn_line, Color(0.98, 0.97, 0.94), 3.5, true)
	for k in 2:
		draw_line(Vector2(r * (0.2 + k * 0.3), -r * 0.95), Vector2(r * (0.25 + k * 0.3), r * 0.1), Color(0.85, 0.1, 0.12), 2.5, true)
	draw_circle(Vector2(r * 0.45, -r * 0.1), 4.0, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(r * 0.5, -r * 0.1), 1.8, Color(1.0, 0.85, 0.1), true, -1.0, true)
	for k in 4:
		var x := r * (0.2 + k * 0.18)
		draw_line(Vector2(x, r * 0.4), Vector2(x, r * 0.75), OUTLINE, 1.5, true)
	draw_set_transform(Vector2.ZERO)
