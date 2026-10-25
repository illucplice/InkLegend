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
## Ichi's Final Getsuga Tensho hair: near black, with grey sheen strands.
const MUGETSU_HAIR := Color(0.13, 0.11, 0.15)
const MUGETSU_SHEEN := Color(0.42, 0.4, 0.48)
const MUGETSU_BANDAGE := Color(0.4, 0.47, 0.56)
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
## Aizon's Kyoka Suigetsu: the next hit meant for him lands on the attacker.
var illusion := false
## Aizon has evolved (once per match): wings, a white robe, harder hits.
var evolved := false
## Aizon's Reiatsu: hits landed in a row, and whether the pressure (defence down) is on.
var pressure_stacks := 0
var pressured := false
## Spiritual pressure from normal Aizon: their next throw is wobbly.
var shaken := false
## Pressured for good (Aizon has evolved): it never wears off this match.
## Under evolved Aizon's pressure for the rest of the match: aiming is heavy.
var heavy_aim := false
## Crushing pressure (evolved Aizon's two-hit combo): turns of damage left.
var crush_turns := 0
## Frierin's barrier: halves the first hit she takes each enemy turn.
var barrier_ready := true
## Frierin has let loose her suppressed mana (at MANA_RELEASE_HEALTH): passives on.
var mana_released := false
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
## A transformation drawn instead of the usual look: "mugetsu" (Ichi's Final Getsuga Tensho form).
var form: StringName = &""
var _bankai_sword: WeaponData
## Turns left on fire (Fuga): burning hurts at the start of each of their turns.
var burn_turns := 0
## Dyo's knives: turns of bleeding left (a little damage at the start of each turn).
var bleed_turns := 0
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
	if health == 0:
		_say_sound("voice_die", -2.0, voice_pitch())
	else:
		_say_sound("voice_hurt", -5.0, voice_pitch() * randf_range(0.94, 1.08))
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
	return data != null and data.weapon.shape in [&"pebble", &"arrow", &"ki", &"fist", &"quincy", &"blue_orb", &"hadoken", &"minya", &"byakurai", &"dark_hado", &"zoltraak", &"mana_orb", &"reiatsu"]


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
	if has_stand():
		_update_stand()
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
	var turned := -1.0 if victory_pose in BACK_POSES else 1.0
	var xf := Transform2D(_tilt + sway + wobble, Vector2(facing * turned * stretch.x, stretch.y), 0.0, Vector2(0, hop))
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
	# Crushed by spiritual pressure: hunched, head hanging, knees buckling, panting.
	if (pressured or shaken) and not is_knocked_out():
		var pant := sin(_time * 6.0) * 1.5
		body[&"hip"] = (body[&"hip"] as Vector2) + Vector2(-2, 8)
		body[&"neck"] = (body[&"neck"] as Vector2) + Vector2(5, 7 + pant)
		body[&"head"] = (body[&"head"] as Vector2) + Vector2(9, 12 + pant)
		body[&"fknee"] = (body[&"fknee"] as Vector2) + Vector2(4, 6)
		body[&"bknee"] = (body[&"bknee"] as Vector2) + Vector2(-2, 6)
		body[&"belbow"] = (body[&"belbow"] as Vector2) + Vector2(2, 14)
		body[&"bhand"] = (body[&"bhand"] as Vector2) + Vector2(6, 30)
	if victory_pose != &"" and not is_knocked_out():
		_apply_victory_pose(body, bob)
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
	if form == &"vollstandig" and not is_knocked_out():
		_draw_light_wings(p)
	if evolved and not is_knocked_out():
		_draw_butterfly_wings(p)
	if mana_released and not is_knocked_out():
		_draw_mana_release(p)
	if illusion and not is_knocked_out():
		_draw_reiatsu(p)
	if (pressured or shaken) and not is_knocked_out():
		_draw_pressure(p)
	if crush_turns > 0 and not is_knocked_out():
		_draw_crush(p)
	if form == &"ssj3" and _is_anime() and not is_knocked_out():
		_draw_ssj3_mane(p)
	if _gear2():
		_draw_haki(p)

	# Pen-and-ink: every line solid black (flashing white on a hit).
	var ink := ink_color.lerp(Color.WHITE, _flash * 0.85)
	# Powered-up anime fighters glow gold from head to toe, with a shimmer.
	if _is_anime() and (charge >= 1.0 or _powering > 0.0) and not is_knocked_out():
		ink = POWER_GOLD.lerp(Color(1.0, 0.95, 0.6), 0.25 + 0.25 * sin(_time * 9.0)).lerp(Color.WHITE, _flash * 0.85)
	if form == &"mugetsu":
		ink = Color(0.03, 0.02, 0.04).lerp(Color(1.0, 0.3, 0.3), _flash * 0.6)
	elif _gear2():
		ink = Color(0.62, 0.14, 0.2).lerp(Color.WHITE, _flash * 0.85)
	var shoulder: Vector2 = (p[&"neck"] as Vector2).lerp(p[&"hip"], 0.15)

	if form == &"mugetsu":
		_draw_mugetsu_hair(p)
	_taper(shoulder, p[&"belbow"], LINE, LINE * 0.85, ink)
	_taper(p[&"belbow"], p[&"bhand"], LINE * 0.85, LINE * 0.8, ink)
	draw_circle(p[&"bhand"], 4.5, ink, true, -1.0, true)
	if _skin_head():
		draw_circle(p[&"bhand"], 3.0, _hand_color(), true, -1.0, true)
	_taper(p[&"hip"], p[&"bknee"], LINE * 1.15, LINE, ink)
	_taper(p[&"bknee"], p[&"bfoot"], LINE, LINE * 0.8, ink)
	_foot(p[&"bfoot"], p[&"bknee"], ink)
	_taper(p[&"hip"], p[&"fknee"], LINE * 1.15, LINE, ink)
	_taper(p[&"fknee"], p[&"ffoot"], LINE, LINE * 0.8, ink)
	_foot(p[&"ffoot"], p[&"fknee"], ink)
	if _skin_head():
		var sock := Color(0.96, 0.95, 0.92) if data.style in [&"reaper", &"quincy"] else data.skin_color
		if data.style in HERO_STYLES:
			sock = {&"thunder": Color(0.2, 0.2, 0.25), &"captain": Color(0.5, 0.3, 0.15), &"spider": Color(0.9, 0.12, 0.15), &"bat": Color(0.08, 0.08, 0.1), &"stardust": Color(0.1, 0.1, 0.15), &"vampire": Color(0.28, 0.5, 0.32), &"adventurer": Color(0.35, 0.22, 0.12), &"tracksuit": Color(0.92, 0.92, 0.95), &"lord": Color(0.11, 0.11, 0.13), &"elf": Color(0.3, 0.2, 0.15)}[data.style]
		for foot: StringName in [&"bfoot", &"ffoot"]:
			draw_circle((p[foot] as Vector2) + Vector2(facing * 3.0, -1.0), 4.5, OUTLINE, true, -1.0, true)
			draw_circle((p[foot] as Vector2) + Vector2(facing * 3.0, -1.0), 3.0, sock, true, -1.0, true)
	_taper(p[&"hip"], p[&"neck"], LINE * 1.2, LINE, ink)
	_draw_outfit(p, shoulder, ink)

	var head: Vector2 = p[&"head"]
	draw_circle(head, HEAD_RADIUS, ink, true, -1.0, true)
	if _skin_head():
		draw_circle(head, HEAD_RADIUS - 2.2, data.skin_color, true, -1.0, true)
	if data.style in NEW_STYLES:
		_draw_new_head(head, p[&"neck"])
	if _is_anime():
		_draw_hair(head, p[&"neck"], ink)
	elif data.style == &"straw":
		_draw_straw_hat(head, p[&"neck"], ink)
	elif data.style == &"reaper" and form != &"mugetsu":
		_draw_reaper_hair(head, p[&"neck"], ink)
	if form == &"mugetsu":
		_draw_mugetsu_details(p)
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
	if data.weapon.shape in [&"cleaver", &"getsuga"] and form == &"" and not _bankai() and not aiming and _swing < 0.05 and not _celebrating and _ragdoll == null:
		arm = 0.9 if facing == 1 else PI - 0.9
	var pull := aim_power if aiming else 0.0
	Projectile.draw_held(self, _held_weapon(), Transform2D(arm, Vector2(1, f), 0.0, hand), holding_weapon, pull)
	draw_set_transform(Vector2.ZERO)
	_taper(shoulder, p[&"felbow"], LINE, LINE * 0.85, ink)
	_taper(p[&"felbow"], hand, LINE * 0.85, LINE * 0.8, ink)
	draw_circle(hand, 4.5, ink, true, -1.0, true)
	if _skin_head():
		draw_circle(hand, 3.0, _hand_color(), true, -1.0, true)
	_draw_sleeve(shoulder, p[&"felbow"])
	if form == &"mugetsu":
		_draw_mugetsu_arm(shoulder, p[&"felbow"], hand)
	_draw_sukuna_marks(p)
	_draw_burning(p)
	_draw_bleeding(p)

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
	if form == &"ssj3":
		color = POWER_GOLD.lightened(0.2).lerp(Color.WHITE, 0.12 * sin(_time * 10.0))
	var r := HEAD_RADIUS
	var gok := data.style == &"anime"
	var spikes: Array = [[-40.0, 9.0, 6.0], [-72.0, 14.0, 8.0], [-104.0, 18.0, 9.0], [-136.0, 19.0, 9.0], [-166.0, 16.0, 8.0], [-196.0, 11.0, 7.0]] if gok \
		else [[-28.0, 12.0, 9.0], [-45.0, 21.0, 10.0], [-62.0, 28.0, 10.0], [-79.0, 32.0, 10.0], [-95.0, 32.0, 10.0], [-111.0, 29.0, 10.0], [-128.0, 23.0, 10.0], [-145.0, 16.0, 9.0], [-162.0, 10.0, 8.0]]
	var grow := ((1.55 if gok else 1.2) if powered else 1.0) * (0.75 if form == &"ssj3" else 1.0)
	var bob := sin(_time * 8.0) * 1.5 if powered else 0.0
	if gok and form == &"ssj3":
		# The mane is drawn behind the body; up top only the cap and bangs.
		spikes = []
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
	if not gok and form == &"majin":
		# Majin: the M branded on his forehead, and dark veins by the eyes.
		var brand := Color(0.08, 0.05, 0.1)
		draw_polyline(PackedVector2Array([Vector2(r * 0.15, -r * 0.2), Vector2(r * 0.22, -r * 0.6), Vector2(r * 0.4, -r * 0.38), Vector2(r * 0.58, -r * 0.6), Vector2(r * 0.65, -r * 0.2)]), brand, 2.5, true)
		draw_line(Vector2(r * 0.75, -r * 0.05), Vector2(r * 0.95, -r * 0.3), brand, 1.5, true)
		draw_line(Vector2(r * 0.7, r * 0.15), Vector2(r * 0.95, r * 0.35), brand, 1.5, true)
	draw_set_transform(Vector2.ZERO)


## A flickering flame aura around the body in the fighter's colour.
func _draw_aura(p: Dictionary) -> void:
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"head"], 0.4)
	var glow := data.body_color.lightened(0.3)
	if data.style in NEW_STYLES:
		glow = _new_aura_color()
	if data.style == &"straw":
		glow = Color(1.0, 0.72, 0.72)
	elif data.style == &"reaper":
		glow = Color(0.85, 0.1, 0.18)
		if form == &"mugetsu":
			glow = Color(0.12, 0.02, 0.06)
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
	return _is_anime() or (data != null and (data.style == &"straw" or data.style == &"reaper" or data.style in NEW_STYLES))


## Sets the canvas to head space: origin at the head, x pointing the way they face,
## tilted with the head.
func _head_space(head: Vector2, neck: Vector2) -> void:
	var rest := Vector2((HEAD_CENTER - NECK_REST).x * facing, (HEAD_CENTER - NECK_REST).y)
	var tilt := (head - neck).angle() - rest.angle()
	draw_set_transform_matrix(Transform2D(tilt, Vector2(facing, 1), 0.0, head))


## Clothes drawn over the stick body, before the head: Lufi's open red vest, sash and
## blue shorts; Ichi's black robe, sword strap, wide sleeve and flared trousers.
func _draw_outfit(p: Dictionary, shoulder: Vector2, ink: Color) -> void:
	if data.style in NEW_STYLES:
		_draw_outfit_new(p, shoulder, ink)
		return
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
	if form == &"mugetsu":
		# Final Getsuga Tensho: bare, bandaged chest; only the trousers stay.
		_draw_hakama(p, side, Color(0.1, 0.09, 0.12))
		return
	if _bankai():
		_draw_bankai_coat(p, side)
		_poly([neck + side * 10.0, hip + side * 11.0, hip - side * 11.0, neck - side * 10.0], Color(0.08, 0.07, 0.1), 2.5)
		draw_colored_polygon(PackedVector2Array([neck + side * 6.0, neck.lerp(hip, 0.35), neck - side * 6.0]), Color(0.95, 0.94, 0.9))
		_taper(neck + side * 9.0, hip - side * 10.0, 4.0, 4.0, Color(0.55, 0.15, 0.15))
		_draw_sleeve(shoulder, p[&"belbow"])
		return
	var robe := Color(0.14, 0.13, 0.17)
	_draw_hakama(p, side, robe)
	_poly([neck + side * 10.0, hip + side * 11.0, hip - side * 11.0, neck - side * 10.0], robe, 2.5)
	draw_colored_polygon(PackedVector2Array([neck + side * 6.0, neck.lerp(hip, 0.35), neck - side * 6.0]), Color(0.95, 0.94, 0.9))
	_taper(neck + side * 9.0, hip - side * 10.0, 4.0, 4.0, Color(0.55, 0.15, 0.15))
	_taper(hip + side * 12.0, hip - side * 12.0, 7.0, 7.0, Color(0.95, 0.94, 0.9))
	_draw_sleeve(shoulder, p[&"belbow"])


## Flared trousers: the hull of the hips and both hems, so the shape never twists.
func _draw_hakama(p: Dictionary, side: Vector2, color: Color) -> void:
	var hip: Vector2 = p[&"hip"]
	# Wide trousers down to the ankles.
	var hem_f: Vector2 = (p[&"ffoot"] as Vector2) + Vector2(0, -7)
	var hem_b: Vector2 = (p[&"bfoot"] as Vector2) + Vector2(0, -7)
	var hakama := Geometry2D.convex_hull(PackedVector2Array([hip + side * 11.0, hip - side * 11.0, hem_b + Vector2(-12, 0), hem_b + Vector2(12, 0), hem_f + Vector2(-12, 0), hem_f + Vector2(12, 0)]))
	hakama.remove_at(hakama.size() - 1)
	_poly(hakama, color, 2.5)


## Ichi's wide black sleeve hanging from the shoulder past the elbow.
func _draw_sleeve(shoulder: Vector2, elbow: Vector2) -> void:
	if data.style != &"reaper" or form == &"mugetsu":
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
	if not _bankai() and form != &"mugetsu":
		return data.weapon
	if _bankai_sword == null:
		_bankai_sword = data.weapon.duplicate() as WeaponData
		_bankai_sword.shape = &"katana"
		_bankai_sword.size = 56.0
	return _bankai_sword


## Ichi with his special charged (or firing it): hollow mask and bankai coat.
func _bankai() -> bool:
	return data != null and data.style == &"reaper" and form == &"" and (charge >= 1.0 or _powering > 0.0) and not is_knocked_out()


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


## Final Getsuga Tensho: a great mane of long, spiky black hair falling down his back
## to the waist, with grey sheen strands so it reads against the black body.
func _draw_mugetsu_hair(p: Dictionary) -> void:
	var head: Vector2 = p[&"head"]
	var back := Vector2(-facing, 0)
	var flow := sin(_time * 3.0) * 4.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	outer.append(head + Vector2(facing * 8.0, -HEAD_RADIUS - 6.0))
	for k in 9:
		var t := k / 8.0
		var sway := flow * t
		var spine_point := head + back * lerpf(HEAD_RADIUS, 18.0, t) + Vector2(sway, lerpf(-6.0, 104.0, t))
		# Jagged spikes sticking out behind.
		outer.append(spine_point + back * (14.0 if k % 2 == 0 else 4.0) + Vector2(0, 4.0 if k % 2 == 0 else 0.0))
		inner.append(head + back * lerpf(2.0, 6.0, t) + Vector2(sway * 0.5, lerpf(4.0, 96.0, t)))
	outer.append(head + back * 10.0 + Vector2(flow, 118.0))
	var hair := outer.duplicate()
	for k in range(inner.size() - 1, -1, -1):
		hair.append(inner[k])
	if Geometry2D.triangulate_polygon(hair).is_empty():
		# A ragdoll can fold the hair over itself; fall back to its outline.
		hair = Geometry2D.convex_hull(hair)
		hair.remove_at(hair.size() - 1)
	_poly(hair, MUGETSU_HAIR, 2.5)
	for k in 5:
		var t := (k + 1) / 6.0
		var top := head + back * lerpf(8.0, 16.0, t)
		var bottom := head + back * lerpf(16.0, 22.0, t) + Vector2(flow * t, lerpf(70.0, 108.0, t))
		draw_line(top, bottom, MUGETSU_SHEEN, 1.4, true)


## Grey bandages wound round the chest and down the sword arm (tails fluttering at the
## waist), the hair falling over the head and shoulders, glowing red eyes.
func _draw_mugetsu_details(p: Dictionary) -> void:
	var neck: Vector2 = p[&"neck"]
	var hip: Vector2 = p[&"hip"]
	var spine := (neck - hip).normalized()
	var side := spine.orthogonal()
	var bandage := MUGETSU_BANDAGE
	var crease := MUGETSU_BANDAGE.darkened(0.35)
	# A broad black upper body behind the bandages, as in the reference.
	_poly([neck + side * 15.0 - spine * 2.0, hip + side * 11.0, hip - side * 11.0, neck - side * 15.0 - spine * 2.0], Color(0.03, 0.02, 0.04), 2.0)
	_poly([neck + side * 9.0, hip + side * 8.0, hip - side * 8.0, neck - side * 9.0], bandage, 2.0)
	# Wrapped feet below the black trousers.
	for foot: StringName in [&"bfoot", &"ffoot"]:
		var at: Vector2 = (p[foot] as Vector2) + Vector2(facing * 3.0, -2.0)
		draw_circle(at, 6.0, OUTLINE, true, -1.0, true)
		draw_circle(at, 4.5, bandage, true, -1.0, true)
		draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), crease, 1.2, true)
	for k in 7:
		var t := (k + 0.5) / 7.0
		var at := neck.lerp(hip, t)
		draw_line(at + side * 8.5 + spine * 3.0, at - side * 8.5 - spine * 3.0, crease, 1.6, true)
	var wave := sin(_time * 5.0) * 4.0
	for tail in 2:
		var root := hip + side * (4.0 - tail * 8.0)
		draw_polyline(PackedVector2Array([root, root + Vector2(-facing * 10.0, 10 + wave), root + Vector2(-facing * 22.0, 16 - wave)]), bandage, 3.0, true)
	var head: Vector2 = p[&"head"]
	_head_space(head, neck)
	var r := HEAD_RADIUS
	# Hair over the top of the head and a fringe hanging over the brow.
	var cap := PackedVector2Array()
	for i in 13:
		cap.append(Vector2.from_angle(lerpf(PI * 0.95, TAU * 1.02, i / 12.0)) * (r + 3.0))
	cap.append(Vector2(r * 0.9, r * 0.1))
	cap.append(Vector2(r * 0.5, -r * 0.35))
	cap.append(Vector2(r * 0.15, -r * 0.1))
	cap.append(Vector2(-r * 0.3, -r * 0.4))
	cap.append(Vector2(-r * 0.8, r * 0.4))
	_poly(cap, MUGETSU_HAIR, 2.0)
	for k in 3:
		var x := r * (-0.5 + k * 0.45)
		draw_line(Vector2(x, -r * 0.95), Vector2(x + r * 0.2, -r * 0.3), MUGETSU_SHEEN, 1.3, true)
	var glow := 0.7 + 0.3 * sin(_time * 6.0)
	for eye: Vector2 in [Vector2(r * 0.55, r * 0.05), Vector2(r * 0.22, r * 0.02)]:
		draw_circle(eye, 5.0, Color(1.0, 0.1, 0.1, 0.35 * glow), true, -1.0, true)
		draw_circle(eye, 2.0, Color(1.0, 0.2, 0.15), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


# --- Lufi's Gear Second and Conqueror's Haki ---

## Lufi with his special charged (or firing it): Gear Second and Conqueror's Haki.
func _gear2() -> bool:
	return data != null and data.style == &"straw" and (charge >= 1.0 or _powering > 0.0) and not is_knocked_out()


## Steam rising off the body and black lightning crackling round it with a red glow.
func _draw_haki(p: Dictionary) -> void:
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"head"], 0.45)
	for k in 7:
		var rise := fmod(_time * 0.9 + k * 0.143, 1.0)
		var at := centre + Vector2(sin(k * 2.3 + _time) * 18.0, 30.0 - rise * 110.0)
		draw_circle(at, 6.0 + rise * 10.0, Color(1.0, 0.92, 0.94, 0.35 * (1.0 - rise)), true, -1.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 14.0) + get_instance_id()
	for bolt in 3:
		var a := rng.randf() * TAU
		var point := centre + Vector2.from_angle(a) * 24.0
		var line := PackedVector2Array([point])
		for step in 4:
			a += rng.randf_range(-0.9, 0.9)
			point += Vector2.from_angle(a) * rng.randf_range(10.0, 18.0)
			line.append(point)
		draw_polyline(line, Color(0.9, 0.1, 0.12, 0.55), 6.0, true)
		draw_polyline(line, Color(0.05, 0.02, 0.04), 2.5, true)


## Grey bandages wound down the sword arm (drawn over the arm).
func _draw_mugetsu_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2) -> void:
	var bandage := MUGETSU_BANDAGE
	var crease := MUGETSU_BANDAGE.darkened(0.35)
	for pair: Array in [[shoulder, elbow], [elbow, hand]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var along := (b - a).normalized()
		var across := along.orthogonal()
		draw_line(a, b, OUTLINE, 8.0, true)
		draw_line(a, b, bandage, 5.5, true)
		for k in 3:
			var at := a.lerp(b, (k + 0.5) / 3.0)
			draw_line(at - across * 3.0 + along * 2.0, at + across * 3.0 - along * 2.0, crease, 1.2, true)


## Ichi (as a shinigami, bankai or not) shows a face, hands and white socks.
func _skin_head() -> bool:
	return data != null and ((data.style == &"reaper" and form == &"") or data.style in NEW_STYLES)


# --- Uryo, Yuj, Megu, Goj, Ryo and Akum ---

const NEW_STYLES := [&"quincy", &"jujutsu", &"shadow", &"infinity", &"gi", &"demon", &"thunder", &"captain", &"spider", &"bat", &"stardust", &"vampire", &"adventurer", &"tracksuit", &"lord", &"elf"]


## Special charged (or firing): changes Goj's eyes, Yuj's face and so on.
func _charged() -> bool:
	return (charge >= 1.0 or _powering > 0.0) and not is_knocked_out()


## Outfits for the newer fighters: jackets, gis and coats over the stick body.
func _draw_outfit_new(p: Dictionary, shoulder: Vector2, ink: Color) -> void:
	if data.style in HERO_STYLES:
		_draw_hero_outfit(p)
		return
	var hip: Vector2 = p[&"hip"]
	var neck: Vector2 = p[&"neck"]
	var spine := (neck - hip).normalized()
	var side := spine.orthogonal()
	match data.style:
		&"quincy":
			_draw_hakama(p, side, Color(0.96, 0.97, 1.0))
			_poly([neck + side * 11.0, hip + side * 12.0, hip - side * 12.0, neck - side * 11.0], Color(0.97, 0.98, 1.0), 2.5)
			_taper(neck.lerp(hip, 0.1), hip, 2.5, 2.5, Color(0.3, 0.5, 0.9))
			var cross := neck.lerp(hip, 0.35) + side * 5.0
			draw_line(cross + spine * 5.0, cross - spine * 5.0, Color(0.3, 0.5, 0.9), 2.5, true)
			draw_line(cross + side * 4.0, cross - side * 4.0, Color(0.3, 0.5, 0.9), 2.5, true)
			_taper(hip + side * 12.0, hip - side * 12.0, 4.0, 4.0, Color(0.3, 0.5, 0.9))
		&"jujutsu" when form == &"sukuna" or _charged():
			# Sukuna takes over: the jacket comes off and his tattoos show.
			_draw_pants(p, Color(0.1, 0.11, 0.2))
			_poly([neck + side * 9.0, hip + side * 8.0, hip - side * 8.0, neck - side * 9.0], data.skin_color, 2.5)
			for band in 2:
				var at := neck.lerp(hip, 0.18 + band * 0.14)
				draw_line(at + side * 9.0, at - side * 9.0 + spine * 2.0, OUTLINE, 2.2, true)
			var belly := neck.lerp(hip, 0.62)
			draw_line(belly + side * 7.0, belly - side * 7.0, OUTLINE, 2.0, true)
			draw_line(belly + side * 4.0 - spine * 4.0, belly + side * 6.0 - spine * 12.0, OUTLINE, 1.6, true)
			draw_line(belly - side * 4.0 - spine * 4.0, belly - side * 6.0 - spine * 12.0, OUTLINE, 1.6, true)
		&"jujutsu", &"shadow", &"infinity":
			var cloth := Color(0.1, 0.11, 0.2)
			if data.style == &"shadow":
				_draw_shadow_pool(p)
			_draw_pants(p, cloth)
			_poly([neck + side * 11.0, hip + side * 12.0, hip - side * 12.0, neck - side * 11.0], cloth, 2.5)
			for k in 3:
				draw_circle(neck.lerp(hip, 0.25 + k * 0.22), 1.8, Color(0.85, 0.75, 0.3), true, -1.0, true)
			if data.style == &"jujutsu":
				# Red hood bunched behind the neck.
				draw_circle(neck - Vector2(facing * 7.0, 2.0), 7.0, OUTLINE, true, -1.0, true)
				draw_circle(neck - Vector2(facing * 7.0, 2.0), 5.5, Color(0.8, 0.15, 0.18), true, -1.0, true)
			else:
				# A tall stiff collar.
				_poly([neck + side * 8.0 + spine * 7.0, neck + side * 10.0, neck - side * 10.0, neck - side * 8.0 + spine * 7.0], cloth, 2.0)
		&"gi":
			var gi := Color(0.62, 0.62, 0.66) if form == &"satsui" else Color(0.97, 0.97, 0.95)
			_draw_pants(p, gi)
			if form == &"satsui":
				# Gi top torn off: a bare chest with a burning hole in it.
				_poly([neck + side * 9.0, hip + side * 8.0, hip - side * 8.0, neck - side * 9.0], data.skin_color, 2.5)
				var wound := neck.lerp(hip, 0.32)
				draw_circle(wound, 8.0, Color(0.95, 0.15, 0.1, 0.5 + 0.3 * sin(_time * 8.0)), true, -1.0, true)
				draw_circle(wound, 5.0, Color(0.03, 0.0, 0.02), true, -1.0, true)
			else:
				_poly([neck + side * 11.0, hip + side * 12.0, hip - side * 12.0, neck - side * 11.0], gi, 2.5)
				draw_colored_polygon(PackedVector2Array([neck + side * 6.0, neck.lerp(hip, 0.4), neck - side * 6.0]), data.skin_color)
			_taper(hip + side * 12.0, hip - side * 12.0, 5.0, 5.0, Color(0.1, 0.08, 0.1))
		&"demon":
			var gi := Color(0.22, 0.22, 0.26)
			_draw_pants(p, gi)
			_poly([neck + side * 11.0, hip + side * 12.0, hip - side * 12.0, neck - side * 11.0], gi, 2.5)
			draw_colored_polygon(PackedVector2Array([neck + side * 6.0, neck.lerp(hip, 0.4), neck - side * 6.0]), data.skin_color)
			_taper(hip + side * 12.0, hip - side * 12.0, 5.0, 5.0, Color(0.55, 0.4, 0.22))
			# Prayer beads round the neck.
			for k in 9:
				var a := k * TAU / 9.0
				var at := neck.lerp(hip, 0.12) + Vector2(cos(a) * 9.0, sin(a) * 6.0)
				draw_circle(at, 2.6, OUTLINE, true, -1.0, true)
				draw_circle(at, 1.8, Color(0.5, 0.33, 0.2), true, -1.0, true)


## Thick trousers over both legs.
func _draw_pants(p: Dictionary, color: Color) -> void:
	for leg: Array in [[&"bknee", &"bfoot"], [&"fknee", &"ffoot"]]:
		var knee: Vector2 = p[leg[0]]
		var foot: Vector2 = p[leg[1]]
		var ankle := knee.lerp(foot, 0.85)
		_taper(p[&"hip"], knee, 15.0, 13.0, OUTLINE)
		_taper(knee, ankle, 13.0, 11.0, OUTLINE)
		_taper(p[&"hip"], knee, 12.0, 10.0, color)
		_taper(knee, ankle, 10.0, 8.0, color)


## Hair and faces, in head space.
func _draw_new_head(head: Vector2, neck: Vector2) -> void:
	if data.style in HERO_STYLES:
		_draw_hero_head(head, neck)
		return
	_head_space(head, neck)
	var r := HEAD_RADIUS
	var hair := data.hair_color
	match data.style:
		&"quincy":
			# Neat black hair with a side part, falling over one eye, and glasses.
			var cap := PackedVector2Array()
			for i in 13:
				cap.append(Vector2.from_angle(lerpf(PI * 0.9, TAU * 1.02, i / 12.0)) * (r + 2.0))
			cap.append(Vector2(r * 0.85, r * 0.15))
			cap.append(Vector2(r * 0.55, -r * 0.4))
			cap.append(Vector2(-r * 0.6, r * 0.5))
			_poly(cap, hair, 2.0)
			for x: float in [0.18, 0.62]:
				draw_rect(Rect2(Vector2(r * x, -r * 0.08), Vector2(r * 0.36, r * 0.26)), Color(0.9, 0.97, 1.0, 0.85))
				draw_rect(Rect2(Vector2(r * x, -r * 0.08), Vector2(r * 0.36, r * 0.26)), OUTLINE, false, 1.5)
			draw_line(Vector2(r * 0.54, r * 0.04), Vector2(r * 0.62, r * 0.04), OUTLINE, 1.5)
		&"jujutsu":
			var sukuna := form == &"sukuna" or _charged()
			if sukuna:
				# Sukuna: the hair swept up and back.
				_spiky_cap(hair, [[-80.0, 9.0], [-105.0, 12.0], [-130.0, 13.0], [-155.0, 12.0], [-180.0, 9.0]], 2.0)
			else:
				# Short spiky pink hair.
				_spiky_cap(hair, [[-40.0, 6.0], [-65.0, 8.0], [-90.0, 9.0], [-115.0, 8.0], [-140.0, 7.0], [-165.0, 5.0]], 2.0)
			if sukuna:
				# Tattoo lines across the brow and cheeks.
				draw_line(Vector2(-r * 0.2, -r * 0.6), Vector2(r * 0.9, -r * 0.45), OUTLINE, 2.0, true)
				draw_line(Vector2(r * 0.9, r * 0.6), Vector2(r * 0.4, r * 0.75), OUTLINE, 2.0, true)
				# Sukuna surfaces: black markings and a second pair of eyes.
				draw_line(Vector2(r * 0.25, r * 0.15), Vector2(r * 0.85, r * 0.15), OUTLINE, 2.0, true)
				draw_line(Vector2(r * 0.3, r * 0.45), Vector2(r * 0.8, r * 0.45), OUTLINE, 2.0, true)
				for eye: Vector2 in [Vector2(r * 0.55, -r * 0.1), Vector2(r * 0.6, r * 0.3)]:
					draw_circle(eye, 2.6, Color(0.9, 0.1, 0.12), true, -1.0, true)
				draw_line(Vector2(-r * 0.1, -r * 0.7), Vector2(r * 0.2, -r * 0.3), OUTLINE, 2.0, true)
		&"shadow":
			# A big, wild, spiky black sea-urchin of hair and sharp eyes.
			_spiky_cap(hair, [[0.0, 10.0], [-22.0, 16.0], [-44.0, 19.0], [-66.0, 21.0], [-88.0, 22.0], [-110.0, 21.0], [-132.0, 20.0], [-154.0, 18.0], [-176.0, 16.0], [-198.0, 13.0], [-220.0, 9.0]], 2.0)
			for eye: Vector2 in [Vector2(r * 0.55, r * 0.02), Vector2(r * 0.22, 0.0)]:
				draw_line(eye + Vector2(-3.0, -1.0), eye + Vector2(3.0, 1.0), OUTLINE, 2.2, true)
				draw_circle(eye + Vector2(0.5, 0.8), 1.2, Color(0.3, 0.4, 0.8), true, -1.0, true)
		&"infinity":
			# Tall white hair standing straight up, and a blindfold (off when charged).
			_spiky_cap(hair, [[-50.0, 12.0], [-70.0, 16.0], [-90.0, 18.0], [-110.0, 16.0], [-130.0, 12.0], [-150.0, 9.0]], 2.0)
			if _charged():
				for eye: Vector2 in [Vector2(r * 0.55, -r * 0.08), Vector2(r * 0.2, -r * 0.1)]:
					draw_circle(eye, 5.0, Color(0.3, 0.75, 1.0, 0.35), true, -1.0, true)
					draw_circle(eye, 2.4, Color(0.55, 0.9, 1.0), true, -1.0, true)
			else:
				draw_rect(Rect2(Vector2(-r * 0.9, -r * 0.3), Vector2(r * 1.95, r * 0.42)), OUTLINE)
		&"gi":
			# Short brown hair and a red headband with its tails flying behind.
			_spiky_cap(hair, [[-45.0, 6.0], [-75.0, 8.0], [-105.0, 8.0], [-135.0, 7.0], [-160.0, 5.0]], 2.0)
			draw_rect(Rect2(Vector2(-r * 0.95, -r * 0.55), Vector2(r * 1.95, r * 0.32)), Color(0.85, 0.12, 0.15))
			var wave := sin(_time * 6.0) * 3.0
			for k in 2:
				draw_polyline(PackedVector2Array([Vector2(-r * 0.9, -r * 0.4), Vector2(-r * 1.7, -r * 0.3 + wave + k * 4.0), Vector2(-r * 2.5, -r * 0.1 - wave + k * 6.0)]), Color(0.85, 0.12, 0.15), 3.0, true)
			if form == &"satsui":
				draw_circle(Vector2(r * 0.55, -r * 0.05), 2.6, Color(1.0, 0.15, 0.15), true, -1.0, true)
		&"demon":
			# Wild red hair swept up and back, and glowing red eyes.
			_spiky_cap(hair, [[-30.0, 9.0], [-60.0, 14.0], [-90.0, 15.0], [-120.0, 15.0], [-150.0, 13.0], [-180.0, 10.0]], 2.0)
			draw_circle(Vector2(r * 0.55, -r * 0.05), 4.5, Color(1.0, 0.15, 0.1, 0.35), true, -1.0, true)
			draw_circle(Vector2(r * 0.55, -r * 0.05), 2.2, Color(1.0, 0.2, 0.15), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


## Spiky hair over the top of the head in head space: each spike is [angle, length].
func _spiky_cap(color: Color, spikes: Array, outline: float) -> void:
	var r := HEAD_RADIUS
	for pass_index in 2:
		for spike: Array in spikes:
			var a := deg_to_rad(float(spike[0]))
			var grow := outline if pass_index == 0 else 0.0
			var base := Vector2.from_angle(a) * (r - 3.0)
			var tip := Vector2.from_angle(a - 0.2) * (r + float(spike[1]) + grow)
			var across := Vector2.from_angle(a + PI / 2) * (6.0 + grow)
			draw_colored_polygon(PackedVector2Array([base - across, tip, base + across]), OUTLINE if pass_index == 0 else color)
	var cap := PackedVector2Array()
	for i in 13:
		cap.append(Vector2.from_angle(lerpf(PI * 1.0, TAU * 0.99, i / 12.0)) * (r + 1.0))
	cap.append(Vector2(r * 0.55, -r * 0.2))
	cap.append(Vector2(-r * 0.7, r * 0.15))
	draw_colored_polygon(cap, color)


## Aura colour for each of the newer fighters when charged.
func _new_aura_color() -> Color:
	match data.style:
		&"thunder":
			return Color(0.6, 0.8, 1.0)
		&"captain":
			return Color(0.4, 0.55, 1.0)
		&"spider":
			return Color(1.0, 0.3, 0.3)
		&"bat":
			return Color(0.35, 0.35, 0.45)
		&"stardust":
			return Color(0.6, 0.4, 0.95)
		&"vampire":
			return Color(1.0, 0.82, 0.3)
		&"adventurer":
			return Color(0.95, 0.85, 0.45)
		&"tracksuit":
			return Color(0.7, 0.85, 1.0)
		&"lord":
			return Color(0.6, 0.35, 0.95)
		&"elf":
			return Color(0.75, 0.88, 1.0)
		&"quincy":
			return Color(0.55, 0.85, 1.0)
		&"jujutsu":
			return Color(0.9, 0.15, 0.2) if form == &"sukuna" or _charged() else Color(0.95, 0.5, 0.6)
		&"shadow":
			return Color(0.25, 0.2, 0.45)
		&"infinity":
			return Color(0.6, 0.85, 1.0)
		&"gi":
			return Color(0.9, 0.1, 0.1) if form == &"satsui" else Color(0.45, 0.7, 1.0)
		&"demon":
			return Color(0.75, 0.08, 0.15)
	return data.body_color


## Ryo fights in red gloves; everyone else's hands are bare.
func _hand_color() -> Color:
	match data.style:
		&"gi", &"captain", &"spider":
			return Color(0.85, 0.15, 0.15)
		&"bat":
			return Color(0.08, 0.08, 0.1)
		&"lord":
			return Color(0.93, 0.92, 0.97) if evolved else Color(0.11, 0.11, 0.13)
	return data.skin_color


## Megu always stands in a pool of shadow; charged, the Divine Dogs rise out of it.
func _draw_shadow_pool(p: Dictionary) -> void:
	var feet: Vector2 = (p[&"bfoot"] as Vector2).lerp(p[&"ffoot"], 0.5)
	draw_set_transform(feet + Vector2(0, 2), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 42.0 + sin(_time * 2.0) * 3.0, Color(0.03, 0.02, 0.07, 0.75), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if not _charged():
		return
	for dog in 2:
		var white := dog == 0
		var at := feet + Vector2(float(facing) * (34.0 if white else -38.0), -4.0 + sin(_time * 3.0 + dog) * 2.0)
		var fur := Color(0.95, 0.95, 0.97) if white else Color(0.05, 0.04, 0.08)
		var dir := float(facing) if white else -float(facing)
		var head := PackedVector2Array([at + Vector2(-dir * 12.0, 0), at + Vector2(-dir * 10.0, -22.0), at + Vector2(-dir * 4.0, -34.0), at + Vector2(dir * 2.0, -24.0), at + Vector2(dir * 18.0, -20.0), at + Vector2(dir * 20.0, -14.0), at + Vector2(dir * 6.0, -8.0), at + Vector2(dir * 4.0, 0)])
		_poly(head, fur, 2.0)
		draw_circle(at + Vector2(dir * 6.0, -20.0), 1.8, Color(0.9, 0.2, 0.2) if white else Color(0.9, 0.85, 0.3), true, -1.0, true)


## Sukuna's tattoos ring Yuj's wrists when he takes over.
func _draw_sukuna_marks(p: Dictionary) -> void:
	if data.style != &"jujutsu" or not (form == &"sukuna" or _charged()):
		return
	for hand: StringName in [&"bhand", &"fhand"]:
		draw_arc(p[hand], 5.0, 0.0, TAU, 12, OUTLINE, 2.0, true)
		draw_line((p[hand] as Vector2) + Vector2(-3, -3), (p[hand] as Vector2) + Vector2(3, 3), OUTLINE, 1.5, true)


## Flames licking off a burning fighter.
func _draw_burning(p: Dictionary) -> void:
	if burn_turns <= 0 or is_knocked_out():
		return
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"neck"], 0.5)
	for k in 7:
		var rise := fmod(_time * 1.8 + k * 0.143, 1.0)
		var at := centre + Vector2(sin(k * 2.6 + _time * 3.0) * 14.0, 20.0 - rise * 70.0)
		draw_circle(at, 9.0 * (1.0 - rise), Color(1.0, 0.45 + rise * 0.4, 0.1, 0.75 * (1.0 - rise)), true, -1.0, true)



## Bleeding: red drops running down from the wounds and dripping to the ground.
func _draw_bleeding(p: Dictionary) -> void:
	if bleed_turns <= 0 or is_knocked_out():
		return
	var wound: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"neck"], 0.55)
	for k in 5:
		var fall := fmod(_time * 1.1 + k * 0.2, 1.0)
		var at := wound + Vector2(-6.0 + k * 3.0, fall * 70.0)
		draw_circle(at, 3.2 * (1.0 - fall * 0.5), Color(0.7, 0.02, 0.05, 0.9 * (1.0 - fall)), true, -1.0, true)
	draw_circle(wound, 4.0, Color(0.6, 0.0, 0.04), true, -1.0, true)

# --- Thundr, Capt, Spydr and Batz ---

const HERO_STYLES := [&"thunder", &"captain", &"spider", &"bat", &"stardust", &"vampire", &"adventurer", &"tracksuit", &"lord", &"elf"]


## Outfits for the four heroes.
func _draw_hero_outfit(p: Dictionary) -> void:
	var hip: Vector2 = p[&"hip"]
	var neck: Vector2 = p[&"neck"]
	var spine := (neck - hip).normalized()
	var side := spine.orthogonal()
	var torso := [neck + side * 11.0, hip + side * 12.0, hip - side * 12.0, neck - side * 11.0]
	match data.style:
		&"thunder":
			_draw_cape(p, Color(0.8, 0.12, 0.14))
			_draw_pants(p, Color(0.15, 0.15, 0.2))
			_poly(torso, Color(0.25, 0.26, 0.32), 2.5)
			for k in 4:
				var at := neck.lerp(hip, 0.2 + (k / 2) * 0.28) + side * (5.0 if k % 2 == 0 else -5.0)
				draw_circle(at, 4.5, OUTLINE, true, -1.0, true)
				draw_circle(at, 3.5, Color(0.8, 0.82, 0.88), true, -1.0, true)
		&"captain":
			_draw_pants(p, Color(0.2, 0.32, 0.72))
			_poly(torso, Color(0.2, 0.35, 0.8), 2.5)
			for k in 3:
				var y := hip.lerp(neck, 0.08 + k * 0.08)
				draw_line(y + side * 11.0, y - side * 11.0, Color(0.85, 0.15, 0.2) if k % 2 == 0 else Color(0.96, 0.96, 0.98), 3.0)
			var star_at := neck.lerp(hip, 0.32)
			var star := PackedVector2Array()
			for k in 10:
				star.append(star_at + Vector2.from_angle(-PI / 2 + k * PI / 5.0) * (7.0 if k % 2 == 0 else 3.0))
			draw_colored_polygon(star, Color.WHITE)
		&"spider":
			_draw_pants(p, Color(0.15, 0.3, 0.8))
			_poly(torso, Color(0.9, 0.12, 0.15), 2.5)
			for k in 4:
				var a := neck.lerp(hip, 0.2 + k * 0.18)
				draw_line(a + side * 10.0, a - side * 10.0, Color(0.15, 0.05, 0.08), 1.0, true)
			draw_line(neck, hip, Color(0.15, 0.05, 0.08), 1.0, true)
			var spider := neck.lerp(hip, 0.32)
			draw_circle(spider, 3.0, OUTLINE, true, -1.0, true)
			for leg in 4:
				var dir := Vector2.from_angle(-PI * 0.8 + leg * PI * 0.53)
				draw_line(spider, spider + dir * 7.0, OUTLINE, 1.2, true)
				draw_line(spider, spider + Vector2(-dir.x, dir.y) * 7.0, OUTLINE, 1.2, true)
		&"bat":
			_draw_cape(p, Color(0.08, 0.08, 0.1))
			_draw_pants(p, Color(0.28, 0.28, 0.32))
			_poly(torso, Color(0.32, 0.32, 0.36), 2.5)
			var emblem := neck.lerp(hip, 0.3)
			var bat := PackedVector2Array([emblem + Vector2(-9, -2), emblem + Vector2(-4, -4), emblem + Vector2(0, -6), emblem + Vector2(4, -4), emblem + Vector2(9, -2), emblem + Vector2(4, 1), emblem + Vector2(0, 4), emblem + Vector2(-4, 1)])
			draw_colored_polygon(bat, Color(0.05, 0.05, 0.06))
			_taper(hip + side * 12.0, hip - side * 12.0, 5.0, 5.0, Color(0.95, 0.8, 0.2))
		&"stardust":
			# Jotar: a long black school coat with tails to the knees, a high collar and
			# a gold chain hanging from it.
			var back := Vector2(-facing, 0)
			var tails := PackedVector2Array([hip + side * 12.0, hip + back * 18.0 + Vector2(0, 46), hip + back * 4.0 + Vector2(0, 50), hip - side * 12.0])
			if Geometry2D.triangulate_polygon(tails).is_empty():
				tails = Geometry2D.convex_hull(tails)
				tails.remove_at(tails.size() - 1)
			_poly(tails, Color(0.1, 0.1, 0.15), 2.5)
			_draw_pants(p, Color(0.1, 0.1, 0.15))
			_poly(torso, Color(0.13, 0.13, 0.2), 2.5)
			_poly([neck + side * 12.0, neck + side * 8.0 + spine * 8.0, neck - side * 8.0 + spine * 8.0, neck - side * 12.0], Color(0.1, 0.1, 0.15), 2.0)
			var chain := neck.lerp(hip, 0.12) + side * 8.0 * facing
			draw_polyline(PackedVector2Array([chain, chain.lerp(hip, 0.3) + Vector2(facing * 4.0, 0), chain.lerp(hip, 0.55)]), Color(0.95, 0.8, 0.3), 2.0, true)
			draw_line(hip + side * 12.0, hip - side * 12.0, Color(0.95, 0.8, 0.3), 2.5, true)
		&"vampire":
			# Dyo: a sleeveless yellow jacket over black, green trousers with heart knee
			# pads.
			_draw_pants(p, Color(0.28, 0.5, 0.32))
			for knee: StringName in [&"bknee", &"fknee"]:
				_draw_heart(p[knee], 5.0, Color(0.95, 0.8, 0.22))
			_poly(torso, Color(0.1, 0.1, 0.12), 2.5)
			_poly([neck + side * 11.0, hip + side * 12.0, hip + side * 5.0, neck + side * 3.0], Color(0.96, 0.8, 0.22), 2.0)
			_poly([neck - side * 3.0, hip - side * 5.0, hip - side * 12.0, neck - side * 11.0], Color(0.96, 0.8, 0.22), 2.0)
			_draw_heart(neck.lerp(hip, 0.35), 5.0, Color(0.3, 0.62, 0.35))
		&"adventurer":
			# Kazma: a green cape, a tan tunic belted at the waist, dark trousers and a
			# quiver on his back.
			_draw_cape(p, Color(0.25, 0.52, 0.3))
			_draw_pants(p, Color(0.3, 0.25, 0.2))
			var back := Vector2(-facing, 0)
			_poly([neck + back * 6.0 + Vector2(0, 4), neck + back * 16.0 + Vector2(0, 6), hip + back * 14.0 + Vector2(0, -8), hip + back * 4.0 + Vector2(0, -10)], Color(0.45, 0.3, 0.18), 2.0)
			for arrow in 3:
				var top := neck + back * (8.0 + arrow * 3.0) + Vector2(0, -2 - arrow * 2.0)
				draw_line(top, top + Vector2(-facing * 3.0, -8), Color(0.9, 0.9, 0.85), 2.0, true)
			_poly(torso, Color(0.72, 0.58, 0.38), 2.5)
			draw_line(hip.lerp(neck, 0.12) + side * 12.0, hip.lerp(neck, 0.12) - side * 12.0, Color(0.35, 0.22, 0.12), 4.0, true)
			draw_line(neck + side * 10.0, neck.lerp(hip, 0.6) - side * 10.0, Color(0.35, 0.22, 0.12), 2.5, true)
		&"tracksuit":
			# Subaro: a black tracksuit with orange stripes down the sides and a white zip.
			_draw_pants(p, Color(0.16, 0.16, 0.19))
			for leg: StringName in [&"bknee", &"fknee"]:
				draw_line((p[&"hip"] as Vector2).lerp(p[leg], 0.2), p[leg], Color(0.95, 0.55, 0.15), 2.0, true)
			_poly(torso, Color(0.16, 0.16, 0.19), 2.5)
			draw_line(neck + side * 10.0, hip + side * 11.0, Color(0.95, 0.55, 0.15), 3.0, true)
			draw_line(neck - side * 10.0, hip - side * 11.0, Color(0.95, 0.55, 0.15), 3.0, true)
			draw_line(neck, hip, Color(0.9, 0.9, 0.92), 1.5, true)
			_poly([neck + side * 9.0, neck + side * 3.0 + spine * 6.0, neck - side * 3.0 + spine * 6.0, neck - side * 9.0], Color(0.95, 0.55, 0.15), 1.5)
		&"lord":
			# Aizon in the Thousand-Year Blood War: a long black robe flaring down to his
			# ankles, black sleeves, and a great white fur collar across his shoulders.
			var feet_y: float = ((p[&"bfoot"] as Vector2).y + (p[&"ffoot"] as Vector2).y) * 0.5 - 10.0
			var flare := Vector2(1, 0)
			var robe := PackedVector2Array([neck + side * 11.0, neck - side * 11.0, Vector2(hip.x, feet_y) - flare * 30.0, Vector2(hip.x, feet_y) + flare * 30.0])
			robe = Geometry2D.convex_hull(robe)
			robe.remove_at(robe.size() - 1)
			_poly(robe, Color(0.93, 0.92, 0.97) if evolved else Color(0.11, 0.11, 0.13), 2.5)
			var collar := PackedVector2Array()
			for k in 13:
				var u := k / 12.0
				var x := lerpf(-36.0, 36.0, u)
				var drop := 14.0 + (7.0 if k % 2 == 0 else 0.0) - absf(x) * 0.12
				collar.append(neck + Vector2(x, drop))
			collar.append(neck + Vector2(30, -2))
			collar.append(neck + Vector2(10, -8))
			collar.append(neck + Vector2(-10, -8))
			collar.append(neck + Vector2(-30, -2))
			if Geometry2D.triangulate_polygon(collar).is_empty():
				collar = Geometry2D.convex_hull(collar)
				collar.remove_at(collar.size() - 1)
			draw_colored_polygon(collar, Color(0.95, 0.95, 0.96))
			var trim := collar.duplicate()
			trim.append(collar[0])
			draw_polyline(trim, Color(0.75, 0.75, 0.8), 1.5, true)
		&"elf":
			# Frierin: a white mage's coat trimmed in gold over black, a short white skirt
			# and dark tights.
			_draw_pants(p, Color(0.12, 0.11, 0.14))
			var hem := hip + Vector2(0, 16)
			_poly([hip + side * 13.0, hip - side * 13.0, hem - side * 19.0, hem + side * 19.0], Color(0.96, 0.96, 0.98), 2.0)
			draw_line(hem - side * 18.0, hem + side * 18.0, Color(0.85, 0.7, 0.3), 2.5, true)
			_poly(torso, Color(0.96, 0.96, 0.98), 2.5)
			draw_line(neck, hip, Color(0.12, 0.11, 0.14), 4.0, true)
			draw_line(neck + side * 10.0, hip + side * 11.0, Color(0.85, 0.7, 0.3), 2.0, true)
			draw_line(neck - side * 10.0, hip - side * 11.0, Color(0.85, 0.7, 0.3), 2.0, true)
			_poly([neck + side * 12.0, neck + side * 6.0 + spine * 10.0, neck - side * 6.0 + spine * 10.0, neck - side * 12.0], Color(0.96, 0.96, 0.98), 1.5)
			draw_circle(neck.lerp(hip, 0.2), 2.5, Color(0.85, 0.7, 0.3), true, -1.0, true)


## A cape hanging from the shoulders down the back, rippling.
func _draw_cape(p: Dictionary, color: Color) -> void:
	var neck: Vector2 = p[&"neck"]
	var back := Vector2(-facing, 0)
	var wave := sin(_time * 3.0) * 5.0
	var cape := PackedVector2Array([neck + back * 4.0, neck + back * 10.0 + Vector2(0, 4), neck + back * 26.0 + Vector2(wave, 60), neck + back * 30.0 + Vector2(wave * 1.5, 92), neck + back * 6.0 + Vector2(wave, 96), neck + Vector2(0, 20)])
	if Geometry2D.triangulate_polygon(cape).is_empty():
		cape = Geometry2D.convex_hull(cape)
		cape.remove_at(cape.size() - 1)
	_poly(cape, color, 2.5)


## Heads for the four heroes (in head space).
func _draw_hero_head(head: Vector2, neck: Vector2) -> void:
	_head_space(head, neck)
	var r := HEAD_RADIUS
	match data.style:
		&"thunder":
			# Long blond hair falling to the shoulders.
			var hair := PackedVector2Array([Vector2(r * 0.6, -r * 0.8), Vector2(-r * 0.2, -r * 1.15), Vector2(-r * 1.1, -r * 0.4), Vector2(-r * 1.3, r * 1.4), Vector2(-r * 0.4, r * 1.2), Vector2(-r * 0.2, -r * 0.3)])
			_poly(hair, data.hair_color, 2.0)
			draw_line(Vector2(r * 0.1, -r * 0.95), Vector2(r * 0.9, -r * 0.5), data.hair_color.darkened(0.2), 3.0, true)
		&"captain":
			# A blue helmet with a white A and little wings.
			var helmet := PackedVector2Array()
			for i in 13:
				helmet.append(Vector2.from_angle(lerpf(PI * 1.0, TAU, i / 12.0)) * (r + 1.5))
			helmet.append(Vector2(r * 0.9, -r * 0.05))
			helmet.append(Vector2(-r * 0.9, r * 0.2))
			_poly(helmet, Color(0.2, 0.35, 0.8), 2.0)
			draw_line(Vector2(r * 0.3, -r * 0.35), Vector2(r * 0.45, -r * 0.8), Color.WHITE, 2.0, true)
			draw_line(Vector2(r * 0.6, -r * 0.35), Vector2(r * 0.45, -r * 0.8), Color.WHITE, 2.0, true)
			draw_line(Vector2(r * 0.36, -r * 0.5), Vector2(r * 0.55, -r * 0.5), Color.WHITE, 1.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.4, -r * 0.6), Vector2(-r * 0.95, -r * 0.95), Vector2(-r * 0.75, -r * 0.4)]), Color.WHITE)
		&"spider":
			# A red mask over the whole head, webbed, with big white eyes.
			draw_circle(Vector2.ZERO, r - 0.5, Color(0.9, 0.12, 0.15), true, -1.0, true)
			for k in 3:
				draw_arc(Vector2(r * 0.3, 0), r * (0.35 + k * 0.3), 0.0, TAU, 16, Color(0.15, 0.05, 0.08), 1.0, true)
			for k in 6:
				draw_line(Vector2(r * 0.3, 0), Vector2(r * 0.3, 0) + Vector2.from_angle(k * TAU / 6.0) * r * 1.2, Color(0.15, 0.05, 0.08), 1.0, true)
			for eye: Vector2 in [Vector2(r * 0.55, -r * 0.15), Vector2(r * 0.05, -r * 0.18)]:
				var lens := PackedVector2Array([eye + Vector2(-5, 2), eye + Vector2(0, -6), eye + Vector2(6, 0), eye + Vector2(1, 4)])
				_poly(lens, Color.WHITE, 2.0)
		&"bat":
			# A black cowl with pointed ears; only the jaw shows.
			var cowl := PackedVector2Array()
			for i in 13:
				cowl.append(Vector2.from_angle(lerpf(PI * 0.95, TAU * 1.04, i / 12.0)) * (r + 1.0))
			cowl.append(Vector2(r * 0.95, r * 0.25))
			cowl.append(Vector2(-r * 0.8, r * 0.45))
			_poly(cowl, Color(0.08, 0.08, 0.1), 2.0)
			for ear: float in [-0.35, 0.45]:
				draw_colored_polygon(PackedVector2Array([Vector2(r * ear - 4.0, -r * 0.85), Vector2(r * ear, -r * 1.65), Vector2(r * ear + 4.0, -r * 0.85)]), Color(0.08, 0.08, 0.1))
			for eye: Vector2 in [Vector2(r * 0.55, -r * 0.1), Vector2(r * 0.15, -r * 0.12)]:
				draw_line(eye + Vector2(-3, 1), eye + Vector2(3, -1), Color.WHITE, 2.0, true)
		&"stardust":
			# A cap that melts into his hair at the back, with a gold badge and a hard
			# brim; a fixed glare under it.
			var hair := PackedVector2Array([Vector2(-r * 0.2, -r * 0.7), Vector2(-r * 1.2, -r * 0.6), Vector2(-r * 1.7, -r * 0.1), Vector2(-r * 1.3, r * 0.2), Vector2(-r * 1.6, r * 0.6), Vector2(-r * 0.7, r * 0.4)])
			_poly(hair, data.hair_color, 2.0)
			var cap := PackedVector2Array()
			for i in 13:
				cap.append(Vector2.from_angle(lerpf(PI * 1.0, TAU, i / 12.0)) * (r + 2.0) + Vector2(0, -r * 0.1))
			_poly(cap, Color(0.12, 0.12, 0.18), 2.0)
			_poly([Vector2(r * 0.3, -r * 0.3), Vector2(r * 1.6, -r * 0.25), Vector2(r * 1.5, -r * 0.05), Vector2(r * 0.3, -r * 0.05)], Color(0.12, 0.12, 0.18), 2.0)
			draw_circle(Vector2(r * 0.25, -r * 0.7), 3.5, Color(0.95, 0.8, 0.3), true, -1.0, true)
			draw_line(Vector2(r * 0.15, -r * 0.05), Vector2(r * 0.7, -r * 0.12), OUTLINE, 2.5, true)
			draw_line(Vector2(r * 0.35, r * 0.1), Vector2(r * 0.6, r * 0.08), OUTLINE, 2.0, true)
		&"vampire":
			# Swept-back blond hair, a green heart headband and a cruel smile.
			var hair := PackedVector2Array([Vector2(r * 0.7, -r * 0.7), Vector2(-r * 0.1, -r * 1.25), Vector2(-r * 1.2, -r * 0.8), Vector2(-r * 1.5, r * 0.3), Vector2(-r * 0.9, r * 0.9), Vector2(-r * 0.6, r * 0.1), Vector2(-r * 0.1, -r * 0.5)])
			_poly(hair, data.hair_color, 2.0)
			draw_line(Vector2(-r * 0.8, -r * 0.45), Vector2(r * 0.9, -r * 0.5), Color(0.3, 0.62, 0.35), 4.0, true)
			_draw_heart(Vector2(r * 0.55, -r * 0.5), 3.5, Color(0.3, 0.62, 0.35))
			draw_line(Vector2(r * 0.3, -r * 0.12), Vector2(r * 0.75, -r * 0.2), OUTLINE, 2.0, true)
			draw_arc(Vector2(r * 0.5, r * 0.35), r * 0.25, 0.2, PI - 0.4, 8, OUTLINE, 1.8, true)
		&"adventurer":
			# Messy brown hair and a sly grin.
			var hair := PackedVector2Array([Vector2(r * 0.95, -r * 0.35), Vector2(r * 0.6, -r * 0.95), Vector2(r * 0.2, -r * 0.8), Vector2(-r * 0.1, -r * 1.25), Vector2(-r * 0.5, -r * 0.95), Vector2(-r * 1.0, -r * 1.05), Vector2(-r * 1.1, -r * 0.4), Vector2(-r * 1.25, r * 0.1), Vector2(-r * 0.7, r * 0.2), Vector2(-r * 0.2, -r * 0.4), Vector2(r * 0.4, -r * 0.45)])
			_poly(hair, data.hair_color, 2.0)
			draw_line(Vector2(r * 0.35, -r * 0.1), Vector2(r * 0.55, -r * 0.12), OUTLINE, 2.0, true)
			draw_arc(Vector2(r * 0.55, r * 0.35), r * 0.2, 0.1, PI * 0.7, 6, OUTLINE, 1.6, true)
		&"tracksuit":
			# Spiky black hair and sharp, small-pupilled eyes.
			var spikes := PackedVector2Array([Vector2(r * 1.0, -r * 0.3), Vector2(r * 0.85, -r * 0.85), Vector2(r * 0.45, -r * 0.75), Vector2(r * 0.3, -r * 1.3), Vector2(-r * 0.1, -r * 0.95), Vector2(-r * 0.5, -r * 1.3), Vector2(-r * 0.7, -r * 0.85), Vector2(-r * 1.3, -r * 0.8), Vector2(-r * 1.05, -r * 0.3), Vector2(-r * 1.3, r * 0.2), Vector2(-r * 0.7, r * 0.15), Vector2(-r * 0.2, -r * 0.45), Vector2(r * 0.4, -r * 0.4)])
			_poly(spikes, data.hair_color, 2.0)
			draw_arc(Vector2(r * 0.5, -r * 0.1), r * 0.22, 0.0, TAU, 10, OUTLINE, 1.6, true)
			draw_circle(Vector2(r * 0.55, -r * 0.1), 1.5, OUTLINE, true, -1.0, true)
		&"lord":
			# Messy brown hair, swept back but falling loose around his face.
			var hair := PackedVector2Array([Vector2(r * 0.85, -r * 0.5), Vector2(r * 0.6, -r * 1.05), Vector2(r * 0.2, -r * 1.25), Vector2(-r * 0.3, -r * 1.35), Vector2(-r * 0.8, -r * 1.2), Vector2(-r * 1.25, -r * 0.8), Vector2(-r * 1.35, -r * 0.1), Vector2(-r * 1.2, r * 0.6), Vector2(-r * 0.8, r * 0.75), Vector2(-r * 0.6, 0), Vector2(-r * 0.1, -r * 0.5), Vector2(r * 0.4, -r * 0.55)])
			_poly(hair, data.hair_color, 2.0)
			for strand: float in [-0.2, 0.25, 0.6]:
				draw_line(Vector2(r * strand, -r * 1.1), Vector2(r * (strand - 0.25), -r * 0.6), data.hair_color.darkened(0.25), 1.5, true)
			draw_polyline(PackedVector2Array([Vector2(r * 0.45, -r * 0.9), Vector2(r * 0.7, -r * 0.45), Vector2(r * 0.55, r * 0.05)]), data.hair_color.darkened(0.15), 2.5, true)
			draw_line(Vector2(r * 0.3, -r * 0.12), Vector2(r * 0.75, -r * 0.16), OUTLINE, 2.0, true)
			draw_line(Vector2(r * 0.45, r * 0.4), Vector2(r * 0.7, r * 0.36), OUTLINE, 1.5, true)
		&"elf":
			# Long silver twin-tails, a fringe, a pointed elf ear and a red drop earring.
			var hair := data.hair_color
			for tail: float in [0.0, 1.0]:
				var root := Vector2(-r * (0.7 + tail * 0.25), -r * (0.55 - tail * 0.2))
				var strand := PackedVector2Array([root + Vector2(r * 0.25, -r * 0.2), root + Vector2(-r * 0.55, r * 0.6), root + Vector2(-r * 0.75, r * 2.4), root + Vector2(-r * 0.4, r * 4.2), root + Vector2(-r * 0.1, r * 2.4), root + Vector2(r * 0.05, r * 0.6)])
				_poly(strand, hair.darkened(0.06 * tail), 1.5)
				draw_circle(root, 3.0, Color(0.85, 0.7, 0.3), true, -1.0, true)
			var cap := PackedVector2Array()
			for i in 13:
				cap.append(Vector2.from_angle(lerpf(PI * 1.0, TAU, i / 12.0)) * (r + 1.5))
			cap.append(Vector2(r * 0.95, -r * 0.05))
			cap.append(Vector2(r * 0.5, -r * 0.35))
			cap.append(Vector2(r * 0.2, -r * 0.1))
			cap.append(Vector2(-r * 0.3, -r * 0.35))
			cap.append(Vector2(-r * 0.9, r * 0.2))
			if Geometry2D.triangulate_polygon(cap).is_empty():
				cap = Geometry2D.convex_hull(cap)
				cap.remove_at(cap.size() - 1)
			_poly(cap, hair, 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.15, -r * 0.05), Vector2(-r * 0.85, -r * 0.55), Vector2(-r * 0.05, r * 0.25)]), data.skin_color)
			draw_polyline(PackedVector2Array([Vector2(-r * 0.15, -r * 0.05), Vector2(-r * 0.85, -r * 0.55), Vector2(-r * 0.05, r * 0.25)]), OUTLINE, 1.5, true)
			draw_line(Vector2(r * 0.35, -r * 0.1), Vector2(r * 0.7, -r * 0.12), OUTLINE, 2.0, true)
			draw_circle(Vector2(r * 0.55, -r * 0.08), 1.6, Color(0.3, 0.6, 0.45), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


# --- Stands (Jotar and Dyo) ---

## How much of the stand shows (fatalities set it); it also comes out with every throw
## and hovers faintly once the special is charged.
var stand_out := 0.0
## The stand throwing a flurry of fists (ORA / MUDA).
var stand_barrage := false


func has_stand() -> bool:
	return data != null and data.style in [&"stardust", &"vampire"]


## A small heart.
func _draw_heart(at: Vector2, size: float, color: Color) -> void:
	var heart := PackedVector2Array([at + Vector2(0, size), at + Vector2(-size, -size * 0.1), at + Vector2(-size * 0.6, -size * 0.8), at + Vector2(0, -size * 0.35), at + Vector2(size * 0.6, -size * 0.8), at + Vector2(size, -size * 0.1)])
	draw_colored_polygon(heart, color)




## How high their voice is: big bruisers growl low, little ones squeak.
const VOICE_PITCH := {
	&"frierin": 1.18, &"aizon": 0.84, &"kazma": 1.06, &"subaro": 1.08, &"grak": 0.68, &"akum": 0.74, &"thundr": 0.78, &"jotar": 0.76, &"batz": 0.74, &"capt": 0.84, &"dyo": 0.9,
	&"bomba": 0.86, &"ryo": 0.88, &"egita": 0.98, &"goj": 0.95, &"ichi": 0.92, &"uryo": 1.02, &"megu": 0.96,
	&"yuj": 1.0, &"gok": 1.04, &"lufi": 1.12, &"spydr": 1.1, &"rango": 0.9, &"quotuk": 1.0, &"fentuk": 1.08,
	&"klakla": 1.35, &"pipmo": 1.5, &"plopo": 1.6,
}


func voice_pitch() -> float:
	return float(VOICE_PITCH.get(data.base_id(), 1.0)) if data != null else 1.0


## Plays one of their voice sounds (looked up at run time, so this class compiles
## without the Audio autoload).
func _say_sound(sound: String, volume_db: float, pitch: float) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.call("play", sound, volume_db, pitch, 0.0)


var _stand: Stand


## Keeps the stand over their shoulder: it comes out with every throw, hovers faintly
## once the special is charged, and fatalities can call it out fully.
func _update_stand() -> void:
	if _stand == null:
		_stand = Stand.new()
		_stand.kind = data.style
		add_child(_stand)
	var hip: Vector2 = _points.get(&"hip", Vector2(0, -50))
	_stand.position = hip + Vector2(-facing * 30.0, -26.0)
	_stand.facing = facing
	_stand.punch = _swing
	_stand.barrage = stand_barrage
	_stand.show = 0.0 if is_knocked_out() else maxf(stand_out, maxf(_swing * 1.4, 0.35 if _charged() else 0.0))




## Uryo's Vollstandig: great wings of light spread behind him and a star-shaped halo
## floats over his head.
func _draw_light_wings(p: Dictionary) -> void:
	var root: Vector2 = (p[&"neck"] as Vector2).lerp(p[&"hip"], 0.25)
	var beat := sin(_time * 3.0) * 0.08
	var glow := Color(0.8, 0.92, 1.0)
	for wing: float in [-1.0, 1.0]:
		for feather in 6:
			var a := -PI / 2 + wing * (0.35 + feather * 0.2 + beat)
			var length := 70.0 + feather * 14.0 - (feather * feather) * 1.5
			var tip := root + Vector2.from_angle(a) * length
			var side := Vector2.from_angle(a + PI / 2) * 9.0
			draw_colored_polygon(PackedVector2Array([root + side * 0.4, tip, root + Vector2.from_angle(a) * length * 0.5 - side, root - side * 0.4]), Color(glow, 0.35 + 0.08 * feather))
			draw_line(root, tip, Color(1, 1, 1, 0.8), 1.5, true)
	var halo: Vector2 = (p[&"head"] as Vector2) + Vector2(0, -32)
	var star := PackedVector2Array()
	for k in 10:
		star.append(halo + Vector2.from_angle(-PI / 2 + _time + k * PI / 5.0) * (14.0 if k % 2 == 0 else 6.0))
	draw_colored_polygon(star, Color(glow, 0.85))
	draw_arc(halo, 18.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0, true)


## Super Saiyan 3: a huge spiky golden mane, drawn behind the head and body, sweeping
## back from the crown down past the waist. Lighter than the glowing body so it reads.
func _draw_ssj3_mane(p: Dictionary) -> void:
	_head_space(p[&"head"], p[&"neck"])
	var r := HEAD_RADIUS
	var sway := sin(_time * 4.0) * r * 0.08
	var mane := PackedVector2Array([
		Vector2(r * 0.3, -r * 1.0), Vector2(-r * 0.2, -r * 1.5), Vector2(-r * 1.6, -r * 1.75),
		Vector2(-r * 1.3, -r * 0.9), Vector2(-r * 2.6, -r * 0.6), Vector2(-r * 1.8, r * 0.2),
		Vector2(-r * 2.9 + sway, r * 1.6), Vector2(-r * 1.9 + sway, r * 1.9), Vector2(-r * 2.7 + sway, r * 3.4),
		Vector2(-r * 1.7 + sway, r * 3.4), Vector2(-r * 2.2 + sway, r * 5.0), Vector2(-r * 1.2 + sway, r * 3.9),
		Vector2(-r * 0.9 + sway, r * 5.1), Vector2(-r * 0.6, r * 3.2), Vector2(-r * 0.4, r * 1.2), Vector2(0, r * 0.2),
	])
	if Geometry2D.triangulate_polygon(mane).is_empty():
		mane = Geometry2D.convex_hull(mane)
		mane.remove_at(mane.size() - 1)
	var hair := Color(1.0, 0.9, 0.42).lerp(Color.WHITE, 0.1 * sin(_time * 10.0))
	draw_colored_polygon(mane, hair)
	var edge := mane.duplicate()
	edge.append(mane[0])
	draw_polyline(edge, Color(0.85, 0.55, 0.08), 2.0, true)
	draw_set_transform(Vector2.ZERO)


## Aizon's Kyoka Suigetsu: crushing violet spiritual pressure pours off him.
func _draw_reiatsu(p: Dictionary) -> void:
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"head"], 0.45)
	var violet := Color(0.6, 0.35, 0.95)
	for layer in 4:
		var points := PackedVector2Array()
		for i in 22:
			var a := TAU * i / 22.0
			var flame := 1.0 + 0.3 * sin(_time * 12.0 + i * 2.3 + layer) + (0.5 if sin(a) < -0.3 else 0.0)
			var radius := Vector2(70.0, 105.0) * (1.0 - layer * 0.18) * flame
			points.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y - (14.0 if sin(a) < 0.0 else 0.0)))
		draw_colored_polygon(points, Color(violet, 0.12 + layer * 0.06))
	for i in 8:
		var rise := fmod(_time * 1.4 + i * 0.125, 1.0)
		draw_circle(centre + Vector2(sin(i * 2.7) * 50.0, 60.0 - rise * 170.0), 4.0 * (1.0 - rise), Color(0.85, 0.7, 1.0, 0.9), true, -1.0, true)


# --- Victory poses ---

## The pose struck after winning (empty: none). Set by victory().
var victory_pose: StringName = &""

## Pose shapes, standing facing right (feet on y = 0). Any joint left out keeps its
## usual standing place.
const POSES := {
	&"fist_up": {&"felbow": Vector2(12, -100), &"fhand": Vector2(8, -124), &"belbow": Vector2(-12, -70), &"bhand": Vector2(-4, -56),
		&"bknee": Vector2(-9, -24), &"bfoot": Vector2(-16, -2), &"fknee": Vector2(10, -24), &"ffoot": Vector2(16, -2)},
	&"hands_hips": {&"felbow": Vector2(17, -70), &"fhand": Vector2(7, -55), &"belbow": Vector2(-14, -70), &"bhand": Vector2(-5, -55),
		&"bknee": Vector2(-9, -24), &"bfoot": Vector2(-16, -2), &"fknee": Vector2(10, -24), &"ffoot": Vector2(16, -2)},
	&"flex": {&"felbow": Vector2(19, -84), &"fhand": Vector2(17, -104), &"belbow": Vector2(-16, -84), &"bhand": Vector2(-15, -104),
		&"bknee": Vector2(-10, -24), &"bfoot": Vector2(-18, -2), &"fknee": Vector2(11, -24), &"ffoot": Vector2(18, -2)},
	&"thumbs_up": {&"felbow": Vector2(14, -72), &"fhand": Vector2(25, -88), &"belbow": Vector2(-12, -70), &"bhand": Vector2(-4, -56)},
	&"point": {&"felbow": Vector2(15, -84), &"fhand": Vector2(29, -86), &"belbow": Vector2(-12, -70), &"bhand": Vector2(-4, -56),
		&"bknee": Vector2(-9, -24), &"bfoot": Vector2(-16, -2), &"fknee": Vector2(10, -24), &"ffoot": Vector2(16, -2)},
	&"sky_point": {&"felbow": Vector2(10, -104), &"fhand": Vector2(15, -126), &"belbow": Vector2(-12, -70), &"bhand": Vector2(-4, -56)},
	&"arms_crossed": {&"felbow": Vector2(13, -72), &"fhand": Vector2(-6, -75), &"belbow": Vector2(-10, -72), &"bhand": Vector2(11, -77),
		&"bknee": Vector2(-9, -24), &"bfoot": Vector2(-16, -2), &"fknee": Vector2(10, -24), &"ffoot": Vector2(16, -2)},
	&"hand_out": {&"felbow": Vector2(13, -76), &"fhand": Vector2(27, -82), &"belbow": Vector2(-6, -66), &"bhand": Vector2(-8, -52)},
	&"kneel": {&"head": Vector2(9, -86), &"neck": Vector2(6, -70), &"hip": Vector2(0, -30),
		&"fknee": Vector2(13, -22), &"ffoot": Vector2(15, -2), &"bknee": Vector2(-10, -4), &"bfoot": Vector2(-27, -2),
		&"felbow": Vector2(11, -40), &"fhand": Vector2(17, -4), &"belbow": Vector2(-13, -60), &"bhand": Vector2(-27, -55)},
	&"glasses_push": {&"felbow": Vector2(15, -84), &"fhand": Vector2(7, -103), &"belbow": Vector2(-6, -66), &"bhand": Vector2(-8, -52)},
	&"bow": {&"neck": Vector2(14, -82), &"head": Vector2(25, -94), &"felbow": Vector2(16, -66), &"fhand": Vector2(17, -52),
		&"belbow": Vector2(9, -66), &"bhand": Vector2(8, -52)},
	&"back_turned": {&"felbow": Vector2(13, -72), &"fhand": Vector2(-6, -75), &"belbow": Vector2(-10, -72), &"bhand": Vector2(11, -77)},
	&"peace": {&"felbow": Vector2(16, -88), &"fhand": Vector2(11, -108), &"belbow": Vector2(-12, -70), &"bhand": Vector2(-4, -56)},
	&"hand_sign": {&"felbow": Vector2(13, -70), &"fhand": Vector2(15, -82), &"belbow": Vector2(4, -70), &"bhand": Vector2(12, -84)},
	&"wryyy": {&"hip": Vector2(-2, -42), &"neck": Vector2(-20, -76), &"head": Vector2(-34, -84),
		&"fknee": Vector2(14, -54), &"ffoot": Vector2(8, -28), &"bknee": Vector2(-6, -22), &"bfoot": Vector2(-12, -2),
		&"felbow": Vector2(2, -64), &"fhand": Vector2(15, -60), &"belbow": Vector2(-26, -98), &"bhand": Vector2(-11, -114)},
	&"carry": {&"neck": Vector2(7, -86), &"head": Vector2(10, -101), &"belbow": Vector2(-10, -66), &"bhand": Vector2(-17, -57),
		&"felbow": Vector2(-3, -66), &"fhand": Vector2(-12, -59)},
	&"slick_back": {&"felbow": Vector2(15, -104), &"fhand": Vector2(0, -119), &"belbow": Vector2(-6, -66), &"bhand": Vector2(-8, -52)},
}

## Poses struck with the back to the camera.
const BACK_POSES := [&"back_turned"]

## Each fighter's [normal win, fatality win] poses.
const VICTORY := {
	&"quotuk": [&"fist_up", &"hands_hips"], &"klakla": [&"flex", &"fist_up"], &"pipmo": [&"fist_up", &"thumbs_up"],
	&"fentuk": [&"hands_hips", &"point"], &"bomba": [&"thumbs_up", &"fist_up"], &"rango": [&"hands_hips", &"point"],
	&"grak": [&"flex", &"fist_up"], &"plopo": [&"fist_up", &"thumbs_up"],
	&"gok": [&"thumbs_up", &"sky_point"], &"egita": [&"arms_crossed", &"point"], &"lufi": [&"fist_up", &"flex"],
	&"ichi": [&"arms_crossed", &"kneel"], &"uryo": [&"glasses_push", &"hands_hips"], &"yuj": [&"thumbs_up", &"fist_up"],
	&"megu": [&"hand_sign", &"arms_crossed"], &"goj": [&"peace", &"hand_out"], &"ryo": [&"bow", &"fist_up"],
	&"akum": [&"arms_crossed", &"back_turned"], &"thundr": [&"fist_up", &"kneel"], &"capt": [&"hands_hips", &"thumbs_up"],
	&"spydr": [&"kneel", &"point"], &"batz": [&"arms_crossed", &"kneel"], &"jotar": [&"point", &"back_turned"],
	&"dyo": [&"arms_crossed", &"wryyy"], &"kazma": [&"thumbs_up", &"carry"], &"subaro": [&"sky_point", &"kneel"],
	&"aizon": [&"slick_back", &"hand_out"], &"frierin": [&"hand_out", &"hand_sign"],
}


## Strikes this fighter's victory pose: one for a normal win, another after a fatality.
func victory(after_fatality: bool) -> void:
	var pair: Array = VICTORY.get(data.base_id(), [&"fist_up", &"fist_up"])
	victory_pose = pair[1] if after_fatality else pair[0]
	_celebrating = false
	_dazed = false
	aiming = false
	holding_weapon = false


## Puts the posed joints over the standing skeleton (with a little breathing).
func _apply_victory_pose(body: Dictionary, bob: float) -> void:
	var pose: Dictionary = POSES.get(victory_pose, {})
	for point: StringName in pose:
		var lift := Vector2(0, bob) if point in [&"head", &"neck", &"felbow", &"fhand", &"belbow", &"bhand"] else Vector2.ZERO
		body[point] = (pose[point] as Vector2) + lift


## Aizon evolved: four great butterfly wings, dark violet with pale veins and eye
## spots, beating slowly behind him.
func _draw_butterfly_wings(p: Dictionary) -> void:
	var root: Vector2 = (p[&"neck"] as Vector2).lerp(p[&"hip"], 0.3)
	var beat := 0.88 + 0.12 * sin(_time * 2.5)
	var dark := Color(0.22, 0.1, 0.35, 0.85)
	var vein := Color(0.85, 0.75, 1.0, 0.7)
	for wing: float in [-1.0, 1.0]:
		for lobe in 2:
			var upper := lobe == 0
			var radii := Vector2(52.0, 30.0) * beat if upper else Vector2(36.0, 20.0) * beat
			var centre := root + Vector2(wing * radii.x * 0.95, -30.0 if upper else 22.0)
			var tilt := wing * (-0.45 if upper else 0.4)
			var shape := PackedVector2Array()
			for i in 24:
				var a := i * TAU / 24.0
				shape.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt))
			draw_colored_polygon(shape, dark)
			var edge := shape.duplicate()
			edge.append(shape[0])
			draw_polyline(edge, Color(0.6, 0.35, 0.95, 0.9), 2.0, true)
			for k in 4:
				var a := (k - 1.5) * 0.5 + (0.0 if wing > 0 else PI)
				draw_line(root, centre + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt) * 1.0 - centre + centre, vein, 1.2, true)
			var spot := centre + Vector2(wing * radii.x * 0.35, 0).rotated(tilt)
			draw_circle(spot, 7.0 if upper else 5.0, Color(0.6, 0.35, 0.95, 0.9), true, -1.0, true)
			draw_circle(spot, 2.8, Color(1, 1, 1, 0.9), true, -1.0, true)


## Frierin's Mana Release: tall wavering ribbons of pale light pour up around her,
## branching like frost, over a soft blue glow.
func _draw_mana_release(p: Dictionary) -> void:
	# Her barrier: a faint hexagonal bubble around her.
	var core: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"head"], 0.45)
	var shell := PackedVector2Array()
	for k in 7:
		shell.append(core + Vector2.from_angle(k * TAU / 6.0 + _time * 0.3) * Vector2(66.0, 84.0))
	draw_colored_polygon(shell, Color(0.7, 0.85, 1.0, 0.1))
	draw_polyline(shell, Color(0.85, 0.94, 1.0, 0.55 + 0.2 * sin(_time * 4.0)), 2.5, true)
	var feet: Vector2 = ((p[&"bfoot"] as Vector2) + (p[&"ffoot"] as Vector2)) * 0.5
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 90.0, Color(0.7, 0.85, 1.0, 0.25), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	# A thick flame of pale mana wrapped around her.
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"head"], 0.4)
	for layer in 4:
		var flame := PackedVector2Array()
		for i in 22:
			var a := TAU * i / 22.0
			var lick := 1.0 + 0.3 * sin(_time * 10.0 + i * 2.1 + layer) + (0.6 if sin(a) < -0.3 else 0.0)
			var radius := Vector2(62.0, 92.0) * (1.0 - layer * 0.18) * lick
			flame.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y - (16.0 if sin(a) < 0.0 else 0.0)))
		draw_colored_polygon(flame, Color(0.75, 0.88, 1.0, 0.14 + layer * 0.07))
	for k in 8:
		var base := feet + Vector2((k - 3.5) * 20.0, 0)
		var ribbon := PackedVector2Array()
		var phase := _time * 1.6 + k * 1.3
		for i in 14:
			var u := i / 13.0
			ribbon.append(base + Vector2(sin(phase + u * 5.0) * (10.0 + u * 28.0), -u * (170.0 + k % 3 * 30.0)))
		draw_polyline(ribbon, Color(0.75, 0.88, 1.0, 0.22), 24.0, true)
		draw_polyline(ribbon, Color(0.9, 0.96, 1.0, 0.55), 6.0, true)
		# A few frost-like branches off each ribbon.
		for j in [4, 8, 11]:
			var at: Vector2 = ribbon[j]
			var dir := (ribbon[j] - ribbon[j - 1]).normalized().rotated(0.9 if (k + j) % 2 == 0 else -0.9)
			draw_line(at, at + dir * 22.0, Color(0.9, 0.96, 1.0, 0.4), 2.0, true)


## Under Aizon's spiritual pressure: a column of crushing violet force pours down
## over the whole body, streaks driving through it into rings at the feet.
func _draw_pressure(p: Dictionary) -> void:
	var head: Vector2 = p[&"head"]
	var feet: Vector2 = ((p[&"bfoot"] as Vector2) + (p[&"ffoot"] as Vector2)) * 0.5
	var top := head + Vector2(0, -90)
	var height := feet.y - top.y
	var throb := 0.75 + 0.25 * sin(_time * 7.0)
	# The column itself, brightest at its core.
	for layer in 3:
		var half := 46.0 - layer * 13.0
		draw_colored_polygon(PackedVector2Array([Vector2(top.x - half * 0.6, top.y), Vector2(top.x + half * 0.6, top.y), Vector2(feet.x + half, feet.y), Vector2(feet.x - half, feet.y)]), Color(0.55, 0.3, 0.95, (0.13 + layer * 0.08) * throb))
	# Streaks falling the whole way down through the body.
	for k in 9:
		var x := (k - 4) * 9.0 + sin(k * 2.3) * 4.0
		var fall := fmod(_time * 2.4 + k * 0.137, 1.0)
		var y := top.y + fall * height
		var a := Vector2(lerpf(top.x, feet.x, fall) + x * (0.6 + fall * 0.6), y)
		draw_line(a, a + Vector2(0, 26), Color(0.85, 0.7, 1.0, 0.85 * sin(fall * PI)), 2.5, true)
	# Shock rings pressed into the ground.
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
	for ring in 2:
		var spread := fmod(_time * 1.5 + ring * 0.5, 1.0)
		draw_arc(Vector2.ZERO, 26.0 + spread * 40.0, 0.0, TAU, 28, Color(0.65, 0.4, 1.0, 0.8 * (1.0 - spread)), 3.0, true)
	draw_set_transform(Vector2.ZERO)
	# A weight pressing on the head.
	draw_arc(head + Vector2(0, -22), 18.0, PI * 1.1, PI * 1.9, 12, Color(0.75, 0.55, 1.0, 0.9 * throb), 4.0, true)
	# Sweat flying off.
	for drop in 3:
		var t := fmod(_time * 1.2 + drop * 0.33, 1.0)
		var at := head + Vector2(facing * (6.0 + drop * 7.0) + facing * t * 18.0, -12.0 + t * 26.0 - sin(t * PI) * 12.0)
		draw_circle(at, 3.0 * (1.0 - t * 0.4), Color(0.6, 0.85, 1.0, 0.9 * (1.0 - t)), true, -1.0, true)


## Crushing pressure: violet cracks of force pressing in on the body.
func _draw_crush(p: Dictionary) -> void:
	var centre: Vector2 = (p[&"hip"] as Vector2).lerp(p[&"neck"], 0.5)
	for k in 4:
		var a := k * TAU / 4.0 + _time * 1.5
		var from := centre + Vector2.from_angle(a) * 46.0
		var to := centre + Vector2.from_angle(a) * (20.0 + 6.0 * sin(_time * 8.0 + k))
		draw_line(from, to, Color(0.7, 0.45, 1.0, 0.85), 3.0, true)
		draw_colored_polygon(PackedVector2Array([to + Vector2.from_angle(a + 0.4) * 7.0, to, to + Vector2.from_angle(a - 0.4) * 7.0]), Color(0.7, 0.45, 1.0, 0.85))
	draw_arc(centre, 30.0 + 4.0 * sin(_time * 6.0), 0.0, TAU, 24, Color(0.6, 0.35, 0.95, 0.5), 2.5, true)
