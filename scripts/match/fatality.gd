class_name Fatality
extends Node2D
## Bowmasters-style finishers. After a knockout the loser staggers up, dazed, and the
## winner finishes them in their own way: the body comes apart into stick pieces that
## tumble and bleed, giant copies of the winner's weapon do the work, and blood (or
## ink, with Gore off in Settings) sprays and splats on the ground. Tap to skip.

signal finished

const GRAVITY := 1500.0
const INK := Color(0.06, 0.055, 0.07)
const BLOOD := Color(0.72, 0.04, 0.07)
const INK_SPLAT := Color(0.1, 0.08, 0.14)
## Most blood drops alive at once, so a big finisher can't slow the game down.
const MAX_DROPS := 420
## Fatalities play a little slower than the match (everything, gore physics too).
const PACE := 0.7
## The caption shown for each fighter's finisher.
const NAMES := {
	&"quotuk": "PANCAKED!", &"klakla": "PERFORATED!", &"pipmo": "SKEWERED!", &"fentuk": "PINCUSHION!",
	&"bomba": "KABOOM!", &"rango": "SLICED & DICED!", &"grak": "SPLIT IN TWO!", &"plopo": "HEAD SUCKER!",
	&"gok": "THROUGH AND THROUGH!", &"egita": "OBLITERATED!", &"lufi": "RED HAWK!", &"ichi": "MUGETSU!",
	&"uryo": "SPRENGER!", &"yuj": "DISMANTLED!", &"megu": "MAHORAGA!", &"goj": "INFINITY!", &"ryo": "METSU HADOKEN!", &"akum": "SHUN GOKU SATSU!",
	&"thundr": "STRUCK DOWN!", &"capt": "SHIELD SLICED!", &"spydr": "WEB SMASHED!", &"batz": "ROADKILL!",
	&"jotar": "ORA ORA ORA!", &"dyo": "ROAD ROLLER!",
}

var _screamed := false
var winner: Fighter
var loser: Fighter
var camera: CameraRig
var hud: Hud
var gore := true

var _done := false
var _drops := 0
## Gear Fourth's bounce (a looping tween to stop if the finisher is skipped).
var _bounce: Tween
## The game speed before the fatality, put back when it ends.
var _base_scale := 1.0
## When each gore sound last played (see _sfx).
var _last_sfx := {}
## What the camera frames while the finisher plays.
var _frame := PackedVector2Array()


func setup(by: Fighter, victim: Fighter, rig: CameraRig, screen: Hud, with_gore: bool) -> void:
	winner = by
	loser = victim
	camera = rig
	hud = screen
	gore = with_gore
	z_index = 4


## Plays the finisher; `finished` fires when it is over or the player taps to skip.
## intro: first stand the loser up, dazed (false when a finishing throw already did).
func play(intro: bool = true) -> void:
	_run(intro)


func is_done() -> bool:
	return _done


func _run(intro: bool) -> void:
	_base_scale = Engine.time_scale
	Engine.time_scale = _base_scale * PACE
	_frame_around(loser.global_position, 260.0, 420.0)
	camera.focus_on(func() -> PackedVector2Array: return _frame, 30.0)
	if intro:
		loser.stand_dazed()
		winner.celebrate()
		if not await _wait(1.0):
			return
		winner._celebrating = false
	hud.announce("FATALITY!", Color(0.95, 0.12, 0.15))
	Audio.play("ko", 0.0, 0.55, 0.0)
	Audio.play("voice_laugh", 0.0, winner.voice_pitch(), 0.0)
	if not await _wait(0.6 if intro else 0.35):
		return
	var id := winner.data.id
	match id:
		&"quotuk":
			await _pancake()
		&"klakla":
			await _perforate()
		&"pipmo":
			await _skewer()
		&"fentuk":
			await _pincushion()
		&"bomba":
			await _kaboom()
		&"rango":
			await _boomerang()
		&"grak":
			await _split()
		&"plopo":
			await _head_sucker()
		&"gok":
			await _vaporize()
		&"egita":
			await _obliterate()
		&"lufi":
			await _home_run()
		&"ichi":
			await _moon_slash()
		&"uryo":
			await _sprenger()
		&"yuj":
			await _malevolent_shrine()
		&"megu":
			await _mahoraga()
		&"goj":
			await _unlimited_void()
		&"ryo":
			await _metsu_hadoken()
		&"akum":
			await _raging_demon()
		&"thundr":
			await _thunder_god()
		&"capt":
			await _shield_slice()
		&"spydr":
			await _web_slam()
		&"batz":
			await _bat_beatdown()
		&"jotar":
			await _ora_rush()
		&"dyo":
			await _road_roller()
		_:
			await _kaboom()
	if _done:
		return
	hud.announce(NAMES.get(id, "FINISHED!"), Color(1.0, 0.3, 0.25))
	winner.celebrate()
	if not await _wait(1.6):
		return
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = _base_scale
	camera.release_focus()
	# Undo anything a skipped finisher left half-done on the winner.
	if _bounce != null:
		_bounce.kill()
	if is_instance_valid(winner):
		winner.scale = Vector2.ONE
		winner.form = &""
		winner.stand_out = 0.0
		winner.stand_barrage = false
		winner.global_position.y = Terrain.height_at(winner.global_position.x)
		winner.aiming = false
	finished.emit()


func _exit_tree() -> void:
	if not _done:
		Engine.time_scale = _base_scale
		if is_instance_valid(camera):
			camera.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or event.is_action_pressed("ui_accept")
	if tap:
		get_viewport().set_input_as_handled()
		_finish()


## Waits (in game time, so slow motion stretches it). False once skipped.
func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds, false).timeout
	return not _done


## A beat of extra slow motion for `real_seconds` (real time), then back to PACE.
func _slowmo(factor: float, real_seconds: float) -> void:
	Engine.time_scale = _base_scale * PACE * factor
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if not _done:
		Engine.time_scale = _base_scale * PACE


func _frame_around(centre: Vector2, half_width: float, height: float) -> void:
	_frame = PackedVector2Array([centre + Vector2(-half_width, -height), centre + Vector2(half_width, 40)])


func _blood_color() -> Color:
	return BLOOD if gore else INK_SPLAT


func _toward_loser() -> float:
	return signf(loser.global_position.x - winner.global_position.x)


# --- the finishers ---

## Quotuk: a giant hammer drops from the sky and flattens them.
func _pancake() -> void:
	var weapon := winner.data.weapon
	var hammer := _weapon_prop(weapon, 4.0)
	var at := loser.global_position
	hammer.rotation = PI / 2
	hammer.position = at + Vector2(0, -1900)
	var land := at + Vector2(0, -weapon.size * 1.1 * 4.0)
	Audio.play("whoosh", 0.0, 0.5, 0.0)
	var drop := create_tween()
	drop.tween_property(hammer, "position", land, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	if _done:
		return
	var b := loser.body_points()
	_hide_loser()
	# The flattened body, splayed out on the ground.
	for part: Array in _parts(b):
		var points: PackedVector2Array = part[0]
		var flat := PackedVector2Array()
		for p in points:
			var fx := at.x + (p.x - at.x) * 1.8
			flat.append(Vector2(fx, Terrain.height_at(fx) - 3.0 - absf(p.y - at.y) * 0.03))
		_gib(flat, Vector2.ZERO, 0.0, 0.0, 6.0 if part[1] > 0.0 else 0.0)
	_impact(at, 1.0)
	_spray(at + Vector2(0, -6), Vector2.LEFT, 60, 900.0, 0.5)
	_spray(at + Vector2(0, -6), Vector2.RIGHT, 60, 900.0, 0.5)
	_spray(at + Vector2(0, -6), Vector2.UP, 30, 600.0, 0.6)
	await _wait(0.8)
	if _done:
		return
	var lift := create_tween().set_parallel()
	lift.tween_property(hammer, "position:y", hammer.position.y - 700.0, 0.6).set_trans(Tween.TRANS_SINE)
	lift.tween_property(hammer, "modulate:a", 0.0, 0.6)


## Klakla: a hail of pebbles riddles the body, and the last one pops the head off.
func _perforate() -> void:
	var weapon := winner.data.weapon
	var side := _toward_loser()
	for i in 11:
		var b := loser.body_points()
		var last := i == 10
		var hit: Vector2 = b[&"head"] if last else (b[&"hip"] as Vector2).lerp(b[&"neck"], randf()) + Vector2(randf_range(-8, 8), 0)
		var pebble := _weapon_prop(weapon, 2.2 if last else 1.4)
		pebble.position = hit + Vector2(-side * 700.0, randf_range(-260, -60))
		var fly := create_tween()
		fly.tween_property(pebble, "position", hit, 0.12)
		await fly.finished
		if _done:
			return
		pebble.queue_free()
		Audio.play("tick", -2.0, randf_range(0.8, 1.2), 0.0)
		if last:
			break
		loser._tilt_velocity += side * 3.0
		loser._flash = 1.0
		_spray(hit, Vector2(side, -0.3), 10, 420.0, 0.6)
		if not await _wait(0.05):
			return
	_behead(Vector2(side * 420.0, -900.0), 18.0)


## Pipmo: spears rain down and pin them to the ground.
func _skewer() -> void:
	var weapon := winner.data.weapon
	var at := loser.global_position
	for i in 5:
		var b := loser.body_points()
		var hit: Vector2 = [b[&"head"], b[&"neck"], b[&"hip"], b[&"bknee"], b[&"fknee"]][i]
		var spear := _weapon_prop(weapon, 1.6)
		var angle := deg_to_rad(randf_range(70, 110))
		var dir := Vector2.from_angle(angle)
		spear.rotation = angle
		var stuck := Vector2(hit.x, Terrain.height_at(hit.x)) + dir * 30.0
		spear.position = stuck - dir * 2000.0
		var fall := create_tween()
		fall.tween_property(spear, "position", stuck - dir * weapon.size * 0.8, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fall.finished
		if _done:
			return
		Audio.play("thunk", 0.0, 0.8, 0.0)
		loser._flash = 1.0
		_spray(hit, Vector2(randf_range(-0.6, 0.6), -1.0), 18, 520.0, 0.7)
		camera.shake(0.3)
		if not await _wait(0.1):
			return
	var b := loser.body_points()
	_hide_loser()
	for part: Array in _parts(b):
		var centre := _centre(part[0])
		var push := Vector2((centre.x - at.x) * 3.0, -120.0)
		_gib(part[0], push, randf_range(-3, 3), 1.2, part[1])
	_spray(b[&"hip"], Vector2.UP, 40, 700.0, 0.7)


## Fentuk: a volley of arrows, then a last one that bursts the head.
func _pincushion() -> void:
	var weapon := winner.data.weapon
	var side := _toward_loser()
	var arrows: Array[Node2D] = []
	var b := loser.body_points()
	var targets: Array = [b[&"neck"], b[&"hip"], b[&"belbow"], b[&"felbow"], b[&"bknee"], b[&"fknee"]]
	for hit: Vector2 in targets:
		var arrow := _weapon_prop(weapon, 1.3)
		var dir := Vector2(side, 0.8).normalized()
		arrow.rotation = dir.angle()
		arrow.position = hit - dir * 1600.0
		var fly := create_tween()
		fly.tween_property(arrow, "position", hit - dir * weapon.size * 0.35, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		arrows.append(arrow)
		Audio.play("twang", -4.0, randf_range(0.9, 1.1), 0.0)
		if not await _wait(0.07):
			return
	if not await _wait(0.2):
		return
	for hit: Vector2 in targets:
		_spray(hit, Vector2(side, -0.4), 8, 380.0, 0.6)
	loser._flash = 1.0
	Audio.play("hit_body", 0.0, 0.8, 0.0)
	if not await _wait(0.5):
		return
	var head: Vector2 = loser.body_points()[&"head"]
	var last := _weapon_prop(weapon, 2.0)
	var dir := Vector2(side, -0.05).normalized()
	last.rotation = dir.angle()
	last.position = head - dir * 1400.0
	last.modulate = Color(1.4, 0.8, 0.4)
	var shot := create_tween()
	shot.tween_property(last, "position", head + dir * 120.0, 0.18)
	await shot.finished
	if _done:
		return
	for arrow in arrows:
		var drop := arrow.create_tween().set_parallel()
		drop.tween_property(arrow, "position:y", Terrain.height_at(arrow.position.x) - 6.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drop.tween_property(arrow, "rotation", arrow.rotation + randf_range(-1.0, 1.0), 0.5)
	_shatter_head(head, Vector2(side, -0.4))
	_collapse(true)


## Bomba: a huge bomb lands at their feet. Then it goes off.
func _kaboom() -> void:
	var bomb_weapon: WeaponData = load("res://data/weapons/bomb.tres")
	var at := loser.global_position + Vector2(_toward_loser() * -26.0, 0)
	var bomb := _weapon_prop(bomb_weapon, 3.4)
	bomb.position = Vector2(at.x, -1500)
	var drop := create_tween()
	drop.tween_property(bomb, "position", at + Vector2(0, -bomb_weapon.size * 1.7), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await drop.finished
	if _done:
		return
	Audio.play("tick", 0.0, 0.7, 0.0)
	var pulse := bomb.create_tween().set_loops()
	pulse.tween_property(bomb, "scale", Vector2.ONE * 3.8, 0.12)
	pulse.tween_property(bomb, "scale", Vector2.ONE * 3.4, 0.12)
	if not await _wait(0.9):
		return
	bomb.queue_free()
	_hide_loser_and_explode(at + Vector2(0, -30), 1200.0)
	_scorch(at.x, 150.0)
	Effects.burst(self, at + Vector2(0, -40), Color(1.0, 0.65, 0.2), 60, 900.0, 180.0, 2.4)
	Effects.burst(self, at + Vector2(0, -40), Color(1.0, 0.95, 0.7), 30, 600.0, 180.0, 2.0)
	_impact(at, 1.0)
	Audio.play("hit_head", 3.0, 0.4, 0.0)


## Rango: a giant boomerang takes the head off, then comes back for the legs.
func _boomerang() -> void:
	var weapon := winner.data.weapon
	var side := _toward_loser()
	var b := loser.body_points()
	var rang := _weapon_prop(weapon, 3.0)
	var spin := rang.create_tween().set_loops()
	spin.tween_property(rang, "rotation", TAU, 0.18).as_relative()
	var neck_y: float = (b[&"neck"] as Vector2).y - 8.0
	rang.position = Vector2(loser.global_position.x - side * 900.0, neck_y)
	Audio.play("whoosh", 0.0, 0.7, 0.0)
	var pass1 := create_tween()
	pass1.tween_property(rang, "position:x", loser.global_position.x + side * 900.0, 0.4)
	await get_tree().create_timer(0.2, false).timeout
	if _done:
		return
	# The head goes; the body stands there a moment, headless.
	_hide_loser()
	var pieces: Array[Gib] = []
	for part: Array in _parts(b):
		if part[1] > 0.0:
			var head := _gib(part[0], Vector2(side * 380.0, -760.0), side * 14.0, 1.0, part[1])
			head.z_index = 1
		else:
			var piece := _gib(part[0], Vector2.ZERO, 0.0, 0.0, 0.0)
			piece.frozen = true
			pieces.append(piece)
	_fountain(b[&"neck"], 1.4, Vector2.UP)
	await pass1.finished
	if not await _wait(0.25):
		return
	rang.position.y = loser.global_position.y - 36.0
	Audio.play("whoosh", 0.0, 0.8, 0.0)
	var pass2 := create_tween()
	pass2.tween_property(rang, "position:x", loser.global_position.x - side * 1200.0, 0.45)
	await get_tree().create_timer(0.22, false).timeout
	if _done:
		return
	for piece in pieces:
		piece.frozen = false
		piece.velocity = Vector2(randf_range(-160, 160), -220.0)
		piece.spin = randf_range(-5, 5)
		piece.bleed = 0.8
	_spray(Vector2(loser.global_position.x, loser.global_position.y - 36.0), Vector2(-side, -0.3), 30, 520.0, 0.6)
	Audio.play("hit_body", 0.0, 0.7, 0.0)
	await pass2.finished
	rang.queue_free()


## Grak: hurls a giant spinning axe that buries itself in their skull. They stagger
## about, bleeding buckets from the head, then drop.
func _split() -> void:
	var weapon := winner.data.weapon
	var side := _toward_loser()
	winner.play_throw()
	winner.holding_weapon = false
	var axe := _weapon_prop(weapon, 2.0)
	var from := winner.throw_origin()
	axe.position = from
	var head: Vector2 = loser.body_points()[&"head"]
	var arc := (from + head) / 2 + Vector2(0, -220)
	Audio.play("whoosh", 0.0, 0.55, 0.0)
	var fly := create_tween()
	fly.tween_method(func(t: float) -> void:
		axe.position = from.lerp(arc, t).lerp(arc.lerp(head, t), t)
		axe.rotation = side * t * TAU * 2.25, 0.0, 1.0, 0.55)
	await fly.finished
	if _done:
		return
	# Thunk: the blade sinks in, handle sticking out of the head.
	Audio.play("thunk", 2.0, 0.55, 0.0)
	Audio.play("hit_head", 2.0, 0.6, 0.0)
	_impact(head, 0.8)
	loser._flash = 1.0
	_spray(head, Vector2(side, -0.6), 50, 700.0, 0.7)
	var stuck_angle := axe.rotation
	var gush := {"on": true}
	_head_gusher(gush)
	# Staggering around with an axe in the head.
	for wobble in 8:
		loser._tilt_velocity += (2.5 if wobble % 2 == 0 else -2.5)
		var b := loser.body_points()
		axe.position = (b[&"head"] as Vector2) + Vector2.from_angle(stuck_angle) * -weapon.size * 0.9
		if not await _wait(0.16):
			gush["on"] = false
			return
	var b := loser.body_points()
	_hide_loser()
	# The head (axe and all) falls with the body.
	var skull := _gib(PackedVector2Array([b[&"head"]]), Vector2(side * 140.0, -160.0), side * 2.4, 2.2, Fighter.HEAD_RADIUS)
	remove_child(axe)
	skull.add_child(axe)
	axe.position = Vector2.from_angle(stuck_angle) * -weapon.size * 0.9
	axe.rotation = stuck_angle
	for part: Array in _parts(b):
		if part[1] <= 0.0:
			_gib(part[0], Vector2(randf_range(-80, 80), -60.0), randf_range(-2, 2), 0.8)
	gush["on"] = false
	_fountain(b[&"neck"], 1.0, Vector2.UP)
	Audio.play("ground", 0.0, 0.8, 0.0)


## Blood pumping out of the loser's head (wherever it is) until gush.on goes false.
func _head_gusher(gush: Dictionary) -> void:
	var beat := 0.0
	while gush["on"] and not _done and is_inside_tree():
		var head: Vector2 = loser.body_points()[&"head"]
		beat += 0.04
		var pump := 0.6 + 0.4 * absf(sin(beat * 6.0))
		_spray(head + Vector2(0, -10), Vector2(randf_range(-0.5, 0.5), -1.0).normalized(), 6, 760.0 * pump, 0.35)
		await get_tree().create_timer(0.04, false).timeout


## Plopo: a giant plunger sticks to the head and yanks it clean off.
func _head_sucker() -> void:
	var weapon := winner.data.weapon
	var side := _toward_loser()
	var hand := winner.throw_origin()
	var plunger := _weapon_prop(weapon, 2.0)
	plunger.rotation = 0.0 if side > 0 else PI
	plunger.position = hand
	var rope := _prop(func(canvas: Node2D) -> void:
		canvas.draw_line(winner.throw_origin(), plunger.position, Color(0.55, 0.36, 0.2), 4.0, true))
	get_tree().process_frame.connect(rope.queue_redraw)
	var head: Vector2 = loser.body_points()[&"head"]
	var shot := create_tween()
	shot.tween_property(plunger, "position", head - Vector2(side * weapon.size, 0), 0.25)
	await shot.finished
	if _done:
		return
	Audio.play("thunk", 0.0, 1.3, 0.0)
	# Tug, tug...
	for tug in 3:
		loser._tilt_velocity -= side * 5.0
		rope.queue_redraw()
		if not await _wait(0.22):
			return
	var b := loser.body_points()
	_hide_loser()
	var flying := _gib(PackedVector2Array([b[&"head"]]), Vector2(-side * 900.0, -380.0), -side * 9.0, 1.0, Fighter.HEAD_RADIUS)
	var follow := plunger.create_tween()
	follow.tween_method(func(_t: float) -> void:
		if is_instance_valid(flying):
			plunger.position = flying.global_position - Vector2(side * weapon.size * 0.9, 0)
		rope.queue_redraw(), 0.0, 1.0, 1.2)
	for part: Array in _parts(b):
		if part[1] <= 0.0:
			_gib(part[0], Vector2(randf_range(-60, 60), -80.0), randf_range(-2, 2), 0.5)
	_fountain(b[&"neck"], 1.4, Vector2(-side * 0.4, -1.0).normalized())
	Audio.play("hit_head", 0.0, 1.4, 0.0)


## Gok: powers up in a blaze of gold, dashes in and drives a Dragon Fist through them.
## A huge golden dragon tears out of the body and spirals up into the sky.
func _vaporize() -> void:
	var side := _toward_loser()
	winner.power_up(5.0)
	hud.announce("DRAGON FIST!", Color(1.0, 0.82, 0.25))
	# Power-up: gold sparks rising off him, a flare of light.
	for flare in 5:
		Effects.burst(self, winner.aim_point(false), Color(1.0, 0.85, 0.3), 26, 420.0, 40.0, 1.3)
		camera.shake(0.12)
		if not await _wait(0.12):
			return
	Audio.play("whoosh", 0.0, 0.45, 0.0)
	var start := winner.global_position
	var streak := _prop(func(canvas: Node2D) -> void:
		var now := winner.global_position + Vector2(0, -60)
		canvas.draw_line(start + Vector2(0, -60), now, Color(1.0, 0.85, 0.3, 0.35), 40.0, true)
		canvas.draw_line(start + Vector2(0, -60), now, Color(1.0, 0.95, 0.7, 0.7), 12.0, true))
	get_tree().process_frame.connect(streak.queue_redraw)
	await _move_winner(Vector2(loser.global_position.x - side * 44.0, 0.0), 0.28, 0.0)
	if _done:
		return
	var streak_fade := streak.create_tween()
	streak_fade.tween_property(streak, "modulate:a", 0.0, 0.3)
	winner.play_throw()
	var b := loser.body_points()
	var at: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.5)
	Audio.play("hit_head", 5.0, 0.4, 0.0)
	Audio.play("ground", 2.0, 0.5, 0.0)
	_impact(at, 1.0)
	_flash_ring(at, Color(1.0, 0.9, 0.5), 520.0)
	Effects.burst(self, at, Color(1.0, 0.92, 0.5), 60, 1000.0, 180.0, 2.4)
	_hide_loser_and_explode(at - Vector2(side * 10.0, -40.0), 1200.0, -2.6)
	# Punch in close on the uppercut, in slow motion, as he rises through them.
	var close := PackedVector2Array([at + Vector2(-110, -150), at + Vector2(110, 70)])
	camera.focus_on(func() -> PackedVector2Array: return close, 30.0, 2.8)
	_slowmo(0.3, 0.7)
	winner.aiming = true
	winner.aim_angle = 85.0
	winner.aim_power = 1.0
	await _move_winner(Vector2(at.x - side * 10.0, -110.0), 0.4, 0.0)
	if _done:
		return
	_flash_ring(at, Color(1.0, 0.85, 0.35), 380.0)
	camera.focus_on(func() -> PackedVector2Array: return _frame, 30.0)
	# The dragon: a thick glowing serpent spiralling up out of the wound.
	var state := {"t": 0.0}
	var gold := Color(1.0, 0.76, 0.16)
	var light := Color(1.0, 0.96, 0.7)
	var dragon := _prop(func(canvas: Node2D) -> void:
		var length := 60
		var head_index := int(ceil(float(state["t"]) * length))
		if head_index < 3:
			return
		var path := PackedVector2Array()
		var widths := PackedFloat32Array()
		for i in head_index + 1:
			# The last point rides exactly at t, so the dragon grows smoothly.
			var u := minf(i / float(length), float(state["t"]))
			var turn := u * TAU * 1.6
			path.append(at + Vector2(side * sin(turn) * (70.0 + u * 120.0), -u * 1050.0))
			# Wider where the spiral swings toward the camera.
			widths.append(lerpf(20.0, 54.0, minf(1.0, u * 3.0)) * (0.8 + 0.25 * cos(turn)))
		for i in path.size() - 1:
			canvas.draw_line(path[i], path[i + 1], Color(1.0, 0.8, 0.3, 0.16), widths[i] * 2.4, true)
		for i in path.size() - 1:
			canvas.draw_line(path[i], path[i + 1], INK, widths[i] + 7.0, true)
		for i in path.size() - 1:
			canvas.draw_line(path[i], path[i + 1], gold, widths[i], true)
			canvas.draw_line(path[i], path[i + 1], light, widths[i] * 0.35, true)
			if i % 3 == 0:
				var dir := (path[i + 1] - path[i]).normalized()
				var across := dir.orthogonal()
				canvas.draw_arc(path[i], widths[i] * 0.42, across.angle() - 1.2, across.angle() + 1.2, 8, gold.darkened(0.35), 3.0, true)
				# Spine fins.
				var fin := path[i] - across * widths[i] * 0.5
				canvas.draw_colored_polygon(PackedVector2Array([fin + dir * 8.0, fin - across * 18.0, fin - dir * 8.0]), gold.darkened(0.15))
		# The head: open jaws, horns, whiskers and a burning eye.
		var tip := path[path.size() - 1]
		var heading := (tip - path[path.size() - 2]).normalized()
		var across := heading.orthogonal()
		var snout := tip + heading * 70.0
		var upper := PackedVector2Array([tip - across * 30.0, snout - across * 6.0, snout + heading * 6.0 - across * 22.0, tip + heading * 30.0 - across * 4.0])
		var lower := PackedVector2Array([tip + across * 30.0, snout + across * 10.0, tip + heading * 34.0 + across * 6.0])
		for jaw_points: PackedVector2Array in [upper, lower]:
			var jaw := Geometry2D.convex_hull(jaw_points)
			jaw.remove_at(jaw.size() - 1)
			canvas.draw_colored_polygon(jaw, gold)
			var outline := jaw.duplicate()
			outline.append(jaw[0])
			canvas.draw_polyline(outline, INK, 4.0, true)
		for k in 4:
			var fang := tip + heading * (36.0 + k * 9.0)
			canvas.draw_colored_polygon(PackedVector2Array([fang - across * 2.0, fang + across * 9.0, fang + heading * 5.0]), Color.WHITE)
		for horn: float in [-1.0, 1.0]:
			canvas.draw_polyline(PackedVector2Array([tip + across * horn * 20.0, tip - heading * 30.0 + across * horn * 40.0, tip - heading * 60.0 + across * horn * 36.0]), INK, 8.0, true)
			canvas.draw_polyline(PackedVector2Array([tip + across * horn * 20.0, tip - heading * 30.0 + across * horn * 40.0, tip - heading * 60.0 + across * horn * 36.0]), light, 4.0, true)
		var whisker_wave: float = sin(float(state["t"]) * 30.0) * 14.0
		for whisker: float in [-1.0, 1.0]:
			var root := snout - across * whisker * 8.0
			canvas.draw_polyline(PackedVector2Array([root, root + heading * 30.0 + across * whisker * 30.0, root + heading * 10.0 + across * (whisker * 70.0 + whisker_wave), root - heading * 40.0 + across * whisker * 90.0]), gold.lightened(0.2), 4.0, true)
		var eye := tip + heading * 18.0 - across * 12.0
		canvas.draw_circle(eye, 12.0, Color(1.0, 0.3, 0.1, 0.4), true, -1.0, true)
		canvas.draw_circle(eye, 6.0, Color(1.0, 0.25, 0.1), true, -1.0, true)
		canvas.draw_circle(eye, 2.5, Color.WHITE, true, -1.0, true))
	dragon.z_index = 9
	var rise := create_tween()
	var launch := winner.global_position
	rise.tween_method(func(t: float) -> void:
		state["t"] = t
		dragon.queue_redraw()
		# He rides up with it, just behind the head, fist still raised.
		var u := maxf(0.0, t - 0.1)
		var on_path := at + Vector2(side * sin(u * TAU * 1.6) * (70.0 + u * 120.0), -u * 1050.0) + Vector2(0, 90)
		winner.global_position = launch.lerp(on_path, minf(1.0, t * 4.0)),  0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.tween_interval(1.0)
	rise.tween_property(dragon, "modulate:a", 0.0, 0.5)
	_frame_around(Vector2(at.x, 0.0), 440.0, 1100.0)
	await rise.finished
	if _done:
		return
	winner.aiming = false
	await _move_winner(Vector2(at.x + side * 60.0, 0.0), 0.8, 0.0)


## A bright ring that expands and fades (shockwaves).
func _flash_ring(at: Vector2, color: Color, radius: float) -> void:
	var ring := {"r": 10.0}
	var node := _prop(func(canvas: Node2D) -> void:
		var r: float = ring["r"]
		canvas.draw_arc(at, r, 0.0, TAU, 48, color, 16.0 * (1.0 - r / radius) + 2.0, true)
		canvas.draw_circle(at, r * 0.6, Color(color, 0.25 * (1.0 - r / radius)), true, -1.0, true))
	var grow := node.create_tween()
	grow.tween_method(func(r: float) -> void:
		ring["r"] = r
		node.queue_redraw(), 10.0, radius, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_callback(node.queue_free)


## Egita: rises above them and fires a Final Flash straight down.
func _obliterate() -> void:
	var side := _toward_loser()
	winner.power_up(4.0)
	var above := Vector2(loser.global_position.x - side * 60.0, loser.global_position.y - 430.0)
	_frame_around(loser.global_position, 320.0, 620.0)
	Audio.play("whoosh", 0.0, 0.4, 0.0)
	await _move_winner(above, 0.7, 0.0)
	if _done:
		return
	winner.aiming = true
	winner.aim_angle = -62.0
	winner.aim_power = 1.0
	hud.announce("FINAL FLASH!", Color(1.0, 0.92, 0.35))
	# Charging between the hands.
	var hands := winner.throw_origin()
	var charge := {"r": 0.0}
	var glow := _prop(func(canvas: Node2D) -> void:
		var r: float = charge["r"]
		for ring in 4:
			canvas.draw_circle(hands, r * (1.5 - ring * 0.18), Color(1.0, 0.9, 0.35, 0.14 + ring * 0.07), true, -1.0, true)
		canvas.draw_circle(hands, r * 0.55, Color.WHITE, true, -1.0, true))
	var grow := create_tween()
	grow.tween_method(func(r: float) -> void:
		charge["r"] = r
		glow.queue_redraw(), 4.0, 46.0, 0.9)
	Audio.play("whoosh", -2.0, 0.3, 0.0)
	await grow.finished
	if _done:
		return
	glow.queue_free()
	var target := loser.global_position + Vector2(side * 40.0, 30.0)
	var beam := Beam.new()
	beam.setup(hands, hands + (target - hands) * 1.25, Color(1.0, 0.88, 0.3))
	beam.width_scale = 3.2
	add_child(beam)
	await beam.fired
	if _done:
		return
	Audio.play("hit_head", 4.0, 0.35, 0.0)
	_impact(loser.global_position, 1.0)
	var at := loser.global_position + Vector2(0, -20)
	Effects.burst(self, at, Color(1.0, 0.9, 0.4), 70, 1100.0, 180.0, 2.8)
	Effects.burst(self, at, Color.WHITE, 30, 700.0, 180.0, 2.0)
	_hide_loser_and_explode(at, 1500.0, -1.3)
	_scorch(at.x, 300.0)
	await beam.finished
	if _done:
		return
	winner.aiming = false
	await _move_winner(Vector2(above.x, 0.0), 0.5, 0.0)


## Lufi: Conqueror's Haki pins them in place, then he leaps above them and comes down
## with a blazing Red Hawk.
func _home_run() -> void:
	var side := _toward_loser()
	winner.power_up(9.0)
	hud.announce("CONQUEROR'S HAKI!", Color(0.95, 0.2, 0.25))
	_wash(Color(0.85, 0.02, 0.06), 0.45, 0.12, 0.6, 0.45)
	Audio.play("ko", 3.0, 0.35, 0.0)
	# Waves of will roll out from him; they freeze, shaking.
	for wave in 3:
		_flash_ring(winner.aim_point(false), Color(0.08, 0.02, 0.05), 700.0)
		_flash_ring(winner.aim_point(false), Color(0.9, 0.1, 0.15, 0.6), 760.0)
		Effects.burst(self, winner.aim_point(false), Color(0.06, 0.02, 0.05), 24, 700.0, 180.0, 1.4)
		camera.shake(0.5)
		for jitter in 4:
			loser._tilt_velocity += (3.0 if jitter % 2 == 0 else -3.0)
			if not await _wait(0.06):
				return
	loser._flash = 1.0
	Effects.popup(self, loser.aim_point(true) + Vector2(0, -70), "STUNNED!", Color(0.9, 0.85, 1.0), 32, 1.0 / camera.zoom.x, camera.visible_rect())
	if not await _wait(0.5):
		return
	# Up and over.
	var above := Vector2(loser.global_position.x - side * 30.0, loser.global_position.y - 380.0)
	_frame_around(loser.global_position + Vector2(0, -60), 300.0, 620.0)
	Audio.play("whoosh", 0.0, 0.7, 0.0)
	await _move_winner(above, 0.55, 160.0)
	if _done:
		return
	hud.announce("RED HAWK!", Color(1.0, 0.45, 0.15))
	# The arm turns black with haki and the fist bursts into flame.
	var fist_weapon := winner.data.weapon.duplicate() as WeaponData
	fist_weapon.shape = &"fist"
	fist_weapon.size = 30.0
	fist_weapon.color = Color(0.9, 0.3, 0.1)
	var hand := winner.throw_origin()
	for flare in 5:
		Effects.burst(self, hand, Color(1.0, 0.55, 0.15), 14, 240.0, 180.0, 1.3)
		Effects.burst(self, hand, Color(1.0, 0.9, 0.4), 6, 160.0, 180.0, 1.0)
		if not await _wait(0.08):
			return
	var b := loser.body_points()
	var target: Vector2 = (b[&"neck"] as Vector2).lerp(b[&"hip"], 0.3)
	var fist := _weapon_prop(fist_weapon, 3.2)
	fist.modulate = Color(0.55, 0.45, 0.45)
	fist.position = hand
	fist.rotation = (target - hand).angle()
	winner.play_throw()
	Audio.play("whoosh", 2.0, 0.6, 0.0)
	var strike := create_tween()
	strike.tween_method(func(t: float) -> void:
		fist.position = hand.lerp(target, t)
		Effects.burst(self, fist.position, Color(1.0, 0.5, 0.12), 3, 120.0, 180.0, 1.2), 0.0, 1.0, 0.14)
	await strike.finished
	if _done:
		return
	# Boom: fire everywhere.
	_slowmo(0.3, 0.45)
	Audio.play("hit_head", 5.0, 0.45, 0.0)
	Audio.play("ground", 3.0, 0.5, 0.0)
	_impact(target, 1.0)
	_flash_ring(target, Color(1.0, 0.6, 0.15), 520.0)
	Effects.burst(self, target, Color(1.0, 0.5, 0.12), 80, 1100.0, 180.0, 2.6)
	Effects.burst(self, target, Color(1.0, 0.92, 0.5), 40, 700.0, 180.0, 2.0)
	_hide_loser_and_explode(target + Vector2(0, -30), 1300.0, -0.4)
	_scorch(loser.global_position.x, 200.0)
	for ember in 6:
		Effects.burst(self, Vector2(loser.global_position.x + randf_range(-150, 150), -6), Color(1.0, 0.55, 0.15), 8, 160.0, 30.0, 1.0)
	var fade := fist.create_tween()
	fade.tween_property(fist, "modulate:a", 0.0, 0.4)
	if not await _wait(0.4):
		return
	await _move_winner(Vector2(above.x - side * 60.0, 0.0), 0.45, 0.0)


## Ichi: becomes the Final Getsuga Tensho, his hair grown long and black, his body
## bound in bandages. Three cuts too fast to see, then Mugetsu: the light goes out and
## a gigantic wave of black swallows them whole.
func _moon_slash() -> void:
	var side := _toward_loser()
	winner.power_up(10.0)
	winner.holding_weapon = true
	winner.form = &"mugetsu"
	hud.announce("FINAL GETSUGA TENSHO!", Color(0.85, 0.12, 0.15))
	Audio.play("ko", 2.0, 0.35, 0.0)
	camera.shake(0.6)
	_wash(Color.BLACK, 0.3, 0.5, 2.6, 0.6, 2)
	for burst in 4:
		Effects.burst(self, winner.aim_point(false), Color(0.06, 0.02, 0.05), 30, 520.0, 180.0, 1.8)
		Effects.burst(self, winner.aim_point(false), Color(0.75, 0.08, 0.12), 12, 360.0, 180.0, 1.2)
		if not await _wait(0.16):
			return
	if not await _wait(0.4):
		return
	var b := loser.body_points()
	var centre: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.4)
	_place_winner(loser.global_position.x - side * 120.0)
	winner.reset_physics_interpolation()
	for i in 3:
		var angle := [-0.6, 0.5, -0.1][i] as float
		var slash := _prop(func(canvas: Node2D) -> void:
			var points := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				points.append(Vector2(lerpf(-130, 130, t), sin(t * PI) * -28.0))
			canvas.draw_polyline(points, Color(0.05, 0.02, 0.05, 0.8), 16.0, true)
			canvas.draw_polyline(points, Color(0.9, 0.15, 0.2), 3.0, true))
		slash.position = centre + Vector2(0, (i - 1) * 24.0)
		slash.rotation = angle
		var fade := slash.create_tween()
		fade.tween_property(slash, "modulate:a", 0.0, 0.4)
		fade.tween_callback(slash.queue_free)
		Audio.play("whoosh", -2.0, 1.4 + i * 0.1, 0.0)
		_sfx("slice", 0.0, 1.0 + i * 0.1)
		loser._flash = 1.0
		_spray(centre + Vector2(0, (i - 1) * 24.0), Vector2(randf_range(-1, 1), -1.0).normalized(), 14, 380.0, 0.6)
		if not await _wait(0.16):
			return
	# Back off and raise the arm: Mugetsu.
	_place_winner(loser.global_position.x - side * 260.0)
	winner.reset_physics_interpolation()
	winner.aiming = true
	winner.aim_angle = 88.0
	if not await _wait(0.35):
		return
	hud.announce("MUGETSU", Color(0.75, 0.75, 0.8))
	_wash(Color.BLACK, 0.7, 0.6, 1.8, 0.9, 3)
	Audio.play("whoosh", 4.0, 0.22, 0.0)
	# A colossal pillar of pure black rises out of his arm, chunks of dark drifting off it.
	var height := 1300.0
	var pillar := {"h": 0.0}
	var hand := winner.throw_origin()
	var column := _prop(func(canvas: Node2D) -> void:
		var h: float = pillar["h"]
		if h < 4.0:
			return
		var shape := PackedVector2Array([Vector2(-22, 0)])
		for k in 13:
			var t := k / 12.0
			shape.append(Vector2(-lerpf(26.0, 150.0, t) + sin(t * 17.0 + _frame_time() * 3.0) * 14.0, -h * t))
		for k in range(12, -1, -1):
			var t := k / 12.0
			shape.append(Vector2(lerpf(26.0, 150.0, t) + cos(t * 13.0 + _frame_time() * 3.0) * 14.0, -h * t))
		canvas.draw_colored_polygon(shape, Color.BLACK)
		for k in 12:
			var drift := fmod(_frame_time() * 0.6 + k * 0.083, 1.0)
			var chunk := Vector2(sin(k * 2.7) * 190.0, -h * (0.5 + 0.55 * drift))
			var size := 14.0 + (k % 3) * 8.0
			var rock := PackedVector2Array([chunk + Vector2(-size, 0), chunk + Vector2(-size * 0.3, -size * 1.2), chunk + Vector2(size, -size * 0.5), chunk + Vector2(size * 0.6, size * 0.7)])
			canvas.draw_colored_polygon(rock, Color(0, 0, 0, 1.0 - drift)))
	column.position = hand
	column.z_index = 14
	var rise := create_tween()
	rise.tween_method(func(h: float) -> void:
		pillar["h"] = h
		column.queue_redraw(), 0.0, height, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_around(winner.global_position + Vector2(side * 360.0, 0), 720.0, 1450.0)
	await rise.finished
	if _done:
		return
	if not await _wait(0.45):
		return
	# Down it comes, right on top of them.
	Audio.play("whoosh", 4.0, 0.18, 0.0)
	var flat := acos(clampf(-(-hand.y) / height, -1.0, 1.0))
	var slam := create_tween()
	slam.tween_property(column, "rotation", side * flat, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await slam.finished
	if _done:
		return
	var at := loser.global_position
	Audio.play("ground", 6.0, 0.25, 0.0)
	Audio.play("hit_head", 4.0, 0.3, 0.0)
	camera.shake(1.0)
	_mugetsu_hit(b, centre, side)
	_flash_ring(at + Vector2(0, -40), Color.BLACK, 620.0)
	for k in 6:
		# Black debris bursting up all along where the pillar landed.
		Effects.burst(self, Vector2(hand.x + side * (k + 1) * 200.0, -8.0), Color.BLACK, 24, 800.0, 70.0, 2.2)
	_scorch(at.x, 260.0)
	if not await _wait(0.6):
		return
	var fade_column := column.create_tween()
	fade_column.tween_property(column, "modulate:a", 0.0, 0.8)
	await fade_column.finished
	winner.aiming = false


## Mugetsu reaching them: torn into scraps and swept away in the dark.
func _mugetsu_hit(b: Dictionary, centre: Vector2, side: float) -> void:
	if _done:
		return
	_hide_loser()
	Audio.play("hit_body", 4.0, 0.4, 0.0)
	Audio.play("ground", 3.0, 0.35, 0.0)
	_slowmo(0.35, 0.5)
	for part: Array in _parts(b):
		var points: PackedVector2Array = part[0]
		if part[1] > 0.0:
			for half: int in [-1, 1]:
				var piece := _gib(points, Vector2(side * randf_range(700, 1000), -400.0 + half * 140.0), half * 9.0, 1.0, part[1])
				piece.half = half
			continue
		# Every limb in three.
		var a := points[0]
		var z := points[points.size() - 1]
		for k in 3:
			var piece_points := PackedVector2Array([a.lerp(z, k / 3.0), a.lerp(z, (k + 1) / 3.0)])
			_gib(piece_points, Vector2(side * randf_range(600, 1200), randf_range(-700, -120)), randf_range(-12, 12), 1.0)
	for k in 4:
		_spray(centre + Vector2(0, (k - 1.5) * 22.0), Vector2(side, -0.35).normalized(), 40, 1100.0, 0.45)


func _frame_time() -> float:
	return Time.get_ticks_msec() / 1000.0


## A colour washed over the whole view (over the arena, under the HUD and anything
## with a higher z): fades up to `peak` alpha, holds, then fades away.
func _wash(color: Color, peak: float, fade_in: float, hold: float, fade_out: float, z: int = 10) -> Node2D:
	var tint := {"a": 0.0}
	var node := _prop(func(canvas: Node2D) -> void:
		canvas.draw_rect(camera.visible_rect().grow(600.0), Color(color, tint["a"])))
	node.z_index = z
	get_tree().process_frame.connect(node.queue_redraw)
	var tween := node.create_tween()
	tween.tween_method(func(a: float) -> void: tint["a"] = a, 0.0, peak, fade_in)
	tween.tween_interval(hold)
	tween.tween_method(func(a: float) -> void: tint["a"] = a, peak, 0.0, fade_out)
	tween.tween_callback(node.queue_free)
	return node


## Uryo: leaps into the air and rains a storm of spirit arrows down on them, lands,
## and the five blades around them light into a pentagram. Sprenger: a pillar of blue
## light erupts out of the star.
func _sprenger() -> void:
	var weapon := winner.data.weapon
	var side := _toward_loser()
	var at := loser.global_position
	winner.power_up(8.0)
	# Hirenkyaku: a blink up into the sky.
	hud.announce("HIRENKYAKU", Color(0.6, 0.85, 1.0))
	Audio.play("whoosh", 2.0, 1.7, 0.0)
	var start := winner.global_position
	await _move_winner(Vector2(at.x - side * 230.0, at.y - 420.0), 0.3, 0.0)
	if _done:
		return
	winner.aiming = true
	winner.aim_angle = -55.0
	winner.aim_power = 1.0
	_frame_around(Vector2(at.x - side * 110.0, 0), 360.0, 620.0)
	hud.announce("LICHT REGEN", Color(0.6, 0.85, 1.0))
	var storm: Array[Node2D] = []
	# A storm of arrows hammering down on them.
	for k in 28:
		var hit := (loser.body_points()[&"hip"] as Vector2).lerp(loser.body_points()[&"head"], randf()) + Vector2(randf_range(-40, 40), 0)
		if k % 3 == 2:
			var ground_x := at.x + randf_range(-140, 140)
			hit = Vector2(ground_x, Terrain.height_at(ground_x) - 6.0)
		var arrow := _weapon_prop(weapon, 1.2)
		var from := winner.throw_origin()
		arrow.position = from
		arrow.rotation = (hit - from).angle()
		var fly := arrow.create_tween()
		fly.tween_property(arrow, "position", hit, 0.12)
		# Arrows stay stuck in the body and the ground, glowing, until the blast.
		storm.append(arrow)
		if k % 2 == 0:
			Audio.play("twang", -6.0, randf_range(1.2, 1.6), 0.0)
		if k % 3 != 2:
			loser._flash = 0.7
			loser._tilt_velocity += randf_range(-2.5, 2.5)
			_spray(hit, Vector2(0, -1), 5, 340.0, 0.8)
		if not await _wait(0.045):
			return
	winner.aiming = false
	await _move_winner(Vector2(start.x + (at.x - start.x) * 0.3, 0.0), 0.35, 0.0)
	if _done:
		return
	# Seele Schneider: five blades driven into the ground around them.
	var points: Array[Vector2] = []
	for k in 5:
		var a := -PI / 2 + k * TAU / 5.0
		var px := at.x + cos(a) * 160.0
		points.append(Vector2(px, Terrain.height_at(px) + sin(a) * 36.0))
	for k in 5:
		var blade := _weapon_prop(weapon, 1.8)
		var from := winner.throw_origin()
		blade.position = from
		blade.rotation = (points[k] - from).angle()
		winner.play_throw()
		Audio.play("twang", -2.0, 1.1 + k * 0.06, 0.0)
		var fly := create_tween()
		fly.tween_property(blade, "position", points[k] + Vector2(0, -28), 0.13)
		await fly.finished
		if _done:
			return
		blade.rotation = PI / 2
		Effects.burst(self, points[k], weapon.color, 12, 260.0, 180.0, 1.1)
	# The pentagram burns into the ground between them.
	var glow := {"t": 0.0}
	var star := _prop(func(canvas: Node2D) -> void:
		var t: float = glow["t"]
		var ring := PackedVector2Array()
		for k in 41:
			var a := k * TAU / 40.0
			ring.append(at + Vector2(cos(a) * 175.0, sin(a) * 40.0))
		canvas.draw_polyline(ring, Color(weapon.color, minf(1.0, t * 2.0)), 5.0, true)
		var order := [0, 2, 4, 1, 3, 0]
		for k in 5:
			var a: Vector2 = points[order[k]]
			var b: Vector2 = points[order[k + 1]]
			var reach := clampf(t * 5.0 - k, 0.0, 1.0)
			canvas.draw_line(a, a.lerp(b, reach), Color(weapon.color, 0.5), 14.0, true)
			canvas.draw_line(a, a.lerp(b, reach), Color.WHITE, 3.0, true))
	var draw_star := create_tween()
	draw_star.tween_method(func(t: float) -> void:
		glow["t"] = t
		star.queue_redraw(), 0.0, 1.0, 0.8)
	Audio.play("whoosh", -2.0, 1.6, 0.0)
	await draw_star.finished
	if _done:
		return
	hud.announce("SPRENGER!", Color(0.6, 0.9, 1.0))
	if not await _wait(0.25):
		return
	# A pillar of blue light tears up out of the star into the sky.
	var pillar := {"h": 0.0}
	var column := _prop(func(canvas: Node2D) -> void:
		var h: float = pillar["h"]
		for k in 4:
			var w := 190.0 - k * 42.0
			var colour := Color(weapon.color, 0.25 + k * 0.15) if k < 3 else Color(1, 1, 1, 0.9)
			canvas.draw_rect(Rect2(at.x - w / 2, -h, w, h), colour)
		for k in 14:
			var rise := fmod(_frame_time() * 1.4 + k * 0.07, 1.0)
			canvas.draw_circle(Vector2(at.x + sin(k * 2.3) * 110.0, -rise * h), 5.0 * (1.0 - rise), Color(1, 1, 1, 0.8 * (1.0 - rise)), true, -1.0, true))
	column.z_index = 10
	var erupt := create_tween()
	erupt.tween_method(func(h: float) -> void:
		pillar["h"] = h
		column.queue_redraw(), 0.0, 1300.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	erupt.tween_interval(0.8)
	erupt.tween_property(column, "modulate:a", 0.0, 0.7)
	_wash(Color(0.8, 0.94, 1.0), 0.55, 0.08, 0.3, 0.6, 8)
	_flash_ring(at + Vector2(0, -40), weapon.color, 600.0)
	Effects.burst(self, at + Vector2(0, -60), weapon.color.lightened(0.3), 80, 1100.0, 180.0, 2.6)
	_impact(at, 1.0)
	Audio.play("hit_head", 5.0, 0.4, 0.0)
	Audio.play("ground", 4.0, 0.4, 0.0)
	_hide_loser_and_explode(at + Vector2(0, 20), 1500.0, -2.2)
	for arrow in storm:
		if is_instance_valid(arrow):
			var burn := arrow.create_tween()
			burn.tween_property(arrow, "modulate:a", 0.0, 0.5)
			burn.tween_callback(arrow.queue_free)
	_frame_around(Vector2(at.x, 0), 420.0, 1000.0)
	var fade := star.create_tween()
	fade.tween_property(star, "modulate:a", 0.0, 1.4)
	await erupt.finished


## Yuj: Sukuna surfaces and opens his domain, Malevolent Shrine. Dismantle shreds
## them where they stand.
func _malevolent_shrine() -> void:
	var side := _toward_loser()
	# The jacket comes off as Sukuna takes over.
	var jacket := _prop(func(canvas: Node2D) -> void:
		var cloth := PackedVector2Array([Vector2(-14, -26), Vector2(14, -26), Vector2(18, 24), Vector2(-18, 24)])
		canvas.draw_colored_polygon(cloth, Color(0.1, 0.11, 0.2))
		canvas.draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[3], cloth[0]]), INK, 2.5, true)
		for k in 3:
			canvas.draw_circle(Vector2(0, -14 + k * 12), 2.0, Color(0.85, 0.75, 0.3), true, -1.0, true))
	jacket.position = winner.aim_point(false)
	var toss := jacket.create_tween().set_parallel()
	toss.tween_property(jacket, "position", jacket.position + Vector2(-side * 170.0, -50.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	toss.tween_property(jacket, "rotation", -side * 3.0, 0.7)
	toss.chain().tween_property(jacket, "position:y", Terrain.height_at(jacket.position.x - side * 170.0) - 8.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	winner.form = &"sukuna"
	winner.power_up(8.0)
	hud.announce("DOMAIN EXPANSION", Color(0.95, 0.2, 0.2))
	Audio.play("ko", 3.0, 0.3, 0.0)
	_wash(Color(0.25, 0.0, 0.02), 0.55, 0.6, 3.2, 0.8, 2)
	# The shrine looms up behind him.
	var rise := {"s": 0.0}
	var base := Vector2(winner.global_position.x - side * 140.0, Terrain.height_at(winner.global_position.x - side * 140.0))
	var shrine := _prop(func(canvas: Node2D) -> void:
		var s: float = rise["s"]
		if s <= 0.01:
			return
		canvas.draw_set_transform(base, 0.0, Vector2(1.0, s))
		var dark := Color(0.12, 0.04, 0.05)
		canvas.draw_rect(Rect2(-160, -40, 320, 40), dark)
		for x: float in [-120.0, -60.0, 60.0, 120.0]:
			canvas.draw_rect(Rect2(x - 10, -300, 20, 260), dark)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-210, -290), Vector2(0, -360), Vector2(210, -290), Vector2(180, -270), Vector2(-180, -270)]), dark)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-150, -360), Vector2(0, -420), Vector2(150, -360), Vector2(120, -345), Vector2(-120, -345)]), dark)
		for horn: float in [-1.0, 1.0]:
			canvas.draw_polyline(PackedVector2Array([Vector2(horn * 210, -290), Vector2(horn * 250, -330), Vector2(horn * 240, -380)]), dark, 10.0, true)
		# The maw in the middle and a heap of skulls at the base.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-50, -230), Vector2(50, -230), Vector2(40, -120), Vector2(-40, -120)]), Color(0.4, 0.02, 0.04))
		for k in 5:
			canvas.draw_line(Vector2(-40 + k * 20, -230), Vector2(-40 + k * 20, -210), Color(0.9, 0.88, 0.8), 4.0)
		for k in 9:
			var skull := Vector2(-140 + k * 35.0, -20.0 - (k % 3) * 14.0)
			canvas.draw_circle(skull, 13.0, Color(0.88, 0.85, 0.78), true, -1.0, true)
			canvas.draw_circle(skull + Vector2(-4, 0), 3.0, dark, true, -1.0, true)
			canvas.draw_circle(skull + Vector2(4, 0), 3.0, dark, true, -1.0, true)
		canvas.draw_set_transform(Vector2.ZERO))
	shrine.z_index = -2
	var grow := create_tween()
	grow.tween_method(func(s: float) -> void:
		rise["s"] = s
		shrine.queue_redraw(), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var left := minf(base.x - 240.0, loser.global_position.x - 120.0)
	var right := maxf(base.x + 240.0, loser.global_position.x + 120.0)
	_frame = PackedVector2Array([Vector2(left, -470.0), Vector2(right, 40.0)])
	await grow.finished
	if _done:
		return
	hud.announce("MALEVOLENT SHRINE", Color(0.95, 0.2, 0.2))
	# Dismantle: a storm of invisible cuts.
	var b := loser.body_points()
	var centre: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.4)
	for cut in 18:
		var angle := randf_range(-PI, PI)
		var slash := _prop(func(canvas: Node2D) -> void:
			canvas.draw_line(Vector2(-240, 0), Vector2(240, 0), Color(0.9, 0.1, 0.1, 0.45), 20.0, true)
			canvas.draw_line(Vector2(-240, 0), Vector2(240, 0), Color(1.0, 0.9, 0.9), 6.0, true))
		slash.position = centre + Vector2(randf_range(-30, 30), randf_range(-60, 60))
		slash.rotation = angle
		slash.z_index = 9
		var fade := slash.create_tween()
		fade.tween_property(slash, "modulate:a", 0.0, 0.18)
		fade.tween_callback(slash.queue_free)
		loser._flash = 1.0
		loser._tilt_velocity += randf_range(-3, 3)
		if cut % 2 == 0:
			_spray(slash.position, Vector2.from_angle(angle + PI / 2), 8, 420.0, 0.5)
			_sfx("slice", -2.0, randf_range(0.9, 1.3))
		if not await _wait(0.06):
			return
	# Cleave: one enormous cut right across the screen.
	var cleave := _prop(func(canvas: Node2D) -> void:
		canvas.draw_line(Vector2(-900, 0), Vector2(900, 0), Color(0.95, 0.1, 0.12, 0.5), 46.0, true)
		canvas.draw_line(Vector2(-900, 0), Vector2(900, 0), Color.WHITE, 12.0, true))
	cleave.position = centre
	cleave.rotation = -0.35
	cleave.z_index = 9
	cleave.scale = Vector2(0.05, 1.0)
	var swipe := cleave.create_tween()
	swipe.tween_property(cleave, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swipe.tween_property(cleave, "modulate:a", 0.0, 0.4)
	swipe.tween_callback(cleave.queue_free)
	hud.announce("CLEAVE", Color(1.0, 0.3, 0.3))
	Audio.play("whoosh", 4.0, 0.6, 0.0)
	_slowmo(0.3, 0.4)
	# Then they fall apart, cut into pieces.
	_hide_loser()
	Audio.play("hit_body", 4.0, 0.5, 0.0)
	camera.shake(0.8)
	for part: Array in _parts(b):
		var points: PackedVector2Array = part[0]
		if part[1] > 0.0:
			for half: int in [-1, 1]:
				var piece := _gib(points, Vector2(half * 60.0, -120.0), half * 3.0, 1.0, part[1])
				piece.half = half
			continue
		var a := points[0]
		var z := points[points.size() - 1]
		for k in 3:
			_gib(PackedVector2Array([a.lerp(z, k / 3.0), a.lerp(z, (k + 1) / 3.0)]), Vector2(randf_range(-120, 120), randf_range(-200, -40)), randf_range(-6, 6), 1.0)
	_fountain(centre, 1.2, Vector2.UP)
	if not await _wait(0.8):
		return
	var fade_shrine := shrine.create_tween()
	fade_shrine.tween_property(shrine, "modulate:a", 0.0, 0.8)


## Megu: summons Mahoraga out of the shadows. The wheel turns once; the blade falls.
func _mahoraga() -> void:
	var side := _toward_loser()
	winner.power_up(6.0)
	hud.announce("I SUMMON... MAHORAGA!", Color(0.85, 0.85, 0.95))
	# He rises out of the shadow right beside the enemy.
	var spot := Vector2(loser.global_position.x - side * 170.0, Terrain.height_at(loser.global_position.x - side * 170.0))
	var shadow := _prop(func(canvas: Node2D) -> void:
		canvas.draw_set_transform(spot, 0.0, Vector2(1.0, 0.14))
		canvas.draw_circle(Vector2.ZERO, 170.0, Color(0.03, 0.02, 0.06, 0.9), true, -1.0, true)
		canvas.draw_set_transform(Vector2.ZERO))
	shadow.z_index = -1
	_wash(Color(0.03, 0.02, 0.06), 0.4, 0.5, 3.6, 0.8, 2)
	var pose := {"rise": 0.0, "wheel": 0.0, "arm": -2.2}
	var body := Color(0.93, 0.92, 0.9)
	var shade := Color(0.76, 0.75, 0.74)
	var giant := _prop(func(canvas: Node2D) -> void:
		var rise: float = pose["rise"]
		if rise <= 0.01:
			return
		canvas.draw_set_transform(spot, 0.0, Vector2(float(side), rise))
		# Black hakama trousers with a grey sash and its tail.
		var pants := PackedVector2Array([Vector2(-48, -175), Vector2(52, -175), Vector2(86, 0), Vector2(-74, 0)])
		canvas.draw_colored_polygon(pants, Color(0.08, 0.07, 0.1))
		canvas.draw_line(Vector2(6, -170), Vector2(10, 0), Color(0.2, 0.19, 0.24), 3.0, true)
		var sash := PackedVector2Array([Vector2(-56, -188), Vector2(60, -190), Vector2(62, -164), Vector2(-54, -162)])
		canvas.draw_colored_polygon(sash, Color(0.6, 0.6, 0.64))
		canvas.draw_polyline(PackedVector2Array([Vector2(40, -168), Vector2(70, -120), Vector2(58, -80)]), Color(0.6, 0.6, 0.64), 12.0, true)
		# The hunched, heavy torso leaning forward.
		var torso := PackedVector2Array([Vector2(-58, -182), Vector2(-86, -262), Vector2(-62, -340), Vector2(-10, -378), Vector2(52, -366), Vector2(92, -320), Vector2(86, -252), Vector2(54, -186)])
		canvas.draw_colored_polygon(torso, body)
		var torso_line := torso.duplicate()
		torso_line.append(torso[0])
		canvas.draw_polyline(torso_line, INK, 4.0, true)
		for k in 3:
			canvas.draw_arc(Vector2(20, -300 + k * 34), 34.0, 0.4, 2.6, 12, shade, 3.0, true)
		canvas.draw_polyline(PackedVector2Array([Vector2(-50, -330), Vector2(-62, -260), Vector2(-44, -200)]), shade, 3.0, true)
		# Chain hanging across the chest.
		for k in 6:
			canvas.draw_arc(Vector2(34 + k * 3.0, -350 + k * 14.0), 5.0, 0.0, TAU, 10, Color(0.35, 0.35, 0.4), 2.5, true)
		# Thick neck and the long, pointed face jutting forward.
		canvas.draw_line(Vector2(40, -350), Vector2(96, -384), INK, 34.0, true)
		canvas.draw_line(Vector2(40, -350), Vector2(96, -384), body, 28.0, true)
		# The head: a heavy skull sweeping forward into a long tapered snout, two pairs of
		# feathered wings at the sides, a slit of an eye and a line of teeth.
		var head := PackedVector2Array([Vector2(62, -398), Vector2(86, -424), Vector2(124, -426), Vector2(160, -408), Vector2(196, -382), Vector2(204, -372), Vector2(184, -362), Vector2(140, -350), Vector2(96, -346), Vector2(70, -358)])
		canvas.draw_colored_polygon(head, body)
		var head_line := head.duplicate()
		head_line.append(head[0])
		canvas.draw_polyline(head_line, INK, 3.5, true)
		canvas.draw_polyline(PackedVector2Array([Vector2(90, -414), Vector2(140, -410), Vector2(186, -384)]), shade, 3.0, true)
		canvas.draw_polyline(PackedVector2Array([Vector2(118, -372), Vector2(150, -366), Vector2(198, -370)]), INK, 2.0, true)
		for tooth in 5:
			var x := 150.0 + tooth * 9.0
			canvas.draw_line(Vector2(x, -369 + tooth * 0.4), Vector2(x - 2.0, -363 + tooth * 0.4), INK, 1.5, true)
		canvas.draw_line(Vector2(128, -392), Vector2(158, -388), INK, 3.0, true)
		canvas.draw_line(Vector2(132, -392), Vector2(152, -389), Color(0.5, 0.1, 0.4), 1.5, true)
		for pair in 2:
			for k in 3:
				var root := Vector2(88 + pair * 6.0, -408 + pair * 44.0)
				var tip := root + Vector2(-34 - k * 8.0, (-30 + k * 14.0) if pair == 0 else (6.0 + k * 12.0))
				var feather := PackedVector2Array([root, tip, root + Vector2(6, 4)])
				canvas.draw_colored_polygon(feather, body)
				canvas.draw_polyline(PackedVector2Array([root, tip, root + Vector2(6, 4)]), INK, 2.0, true)
		# The back arm: a huge hanging fist.
		_thick(canvas, Vector2(-30, -334), Vector2(-74, -248), 34.0, body)
		_thick(canvas, Vector2(-74, -248), Vector2(-48, -168), 30.0, body)
		canvas.draw_circle(Vector2(-46, -158), 24.0, INK, true, -1.0, true)
		canvas.draw_circle(Vector2(-46, -158), 20.0, Color(0.95, 0.82, 0.74), true, -1.0, true)
		canvas.draw_line(Vector2(-62, -190), Vector2(-34, -186), Color(0.2, 0.2, 0.25), 5.0, true)
		# The front arm ends in the long curved Sword of Extermination.
		var shoulder := Vector2(64, -334)
		var arm: float = pose["arm"]
		var elbow := shoulder + Vector2.from_angle(arm) * 100.0
		_thick(canvas, shoulder, elbow, 32.0, body)
		var blade := PackedVector2Array()
		for k in 9:
			var t := k / 8.0
			blade.append(elbow + Vector2.from_angle(arm + t * 0.5) * (t * 300.0) + Vector2.from_angle(arm + PI / 2) * (sin(t * PI) * 18.0))
		for k in range(blade.size() - 1):
			var t := k / 8.0
			var colour := body.lerp(Color(1.0, 0.72, 0.62), t)
			canvas.draw_line(blade[k], blade[k + 1], INK, lerpf(24.0, 6.0, t) + 5.0, true)
			canvas.draw_line(blade[k], blade[k + 1], colour, lerpf(24.0, 6.0, t), true)
		# The wheel behind the head, its eight spokes tipped with knobs.
		var hub := Vector2(40, -470)
		var turn: float = pose["wheel"]
		canvas.draw_arc(hub, 54.0, 0.0, TAU, 32, INK, 8.0, true)
		canvas.draw_arc(hub, 54.0, 0.0, TAU, 32, Color(0.32, 0.32, 0.36), 4.0, true)
		for k in 8:
			var a := turn + k * TAU / 8.0
			var tip := hub + Vector2.from_angle(a) * 70.0
			canvas.draw_line(hub, tip, INK, 6.0, true)
			canvas.draw_line(hub, tip, Color(0.4, 0.4, 0.45), 3.0, true)
			canvas.draw_circle(tip, 10.0, INK, true, -1.0, true)
			canvas.draw_circle(tip, 7.5, Color(0.42, 0.42, 0.46), true, -1.0, true)
		canvas.draw_circle(hub, 12.0, Color(0.42, 0.42, 0.46), true, -1.0, true)
		canvas.draw_set_transform(Vector2.ZERO))
	giant.z_index = 7
	var emerge := create_tween()
	emerge.tween_method(func(r: float) -> void:
		pose["rise"] = r
		giant.queue_redraw(), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.play("ko", 4.0, 0.3, 0.0)
	_frame_around(Vector2(spot.x + side * 60.0, 0), 380.0, 640.0)
	await emerge.finished
	if _done:
		return
	# Ka-chunk: the wheel turns an eighth.
	var wheel := create_tween()
	wheel.tween_method(func(a: float) -> void:
		pose["wheel"] = a
		giant.queue_redraw(), 0.0, TAU / 8.0, 0.4).set_trans(Tween.TRANS_BACK)
	Audio.play("thunk", 3.0, 0.4, 0.0)
	await wheel.finished
	if _done:
		return
	if not await _wait(0.3):
		return
	# The blade comes down.
	var swing := create_tween()
	swing.tween_method(func(a: float) -> void:
		pose["arm"] = a
		giant.queue_redraw(), -2.2, 0.9, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Audio.play("whoosh", 4.0, 0.4, 0.0)
	await swing.finished
	if _done:
		return
	var b := loser.body_points()
	_hide_loser()
	Audio.play("hit_head", 5.0, 0.35, 0.0)
	_impact(loser.global_position, 1.0)
	var head: Vector2 = b[&"head"]
	for half_side: float in [-1.0, 1.0]:
		var push := Vector2(half_side * 220.0, -180.0)
		var offset := Vector2(half_side * 4.0, 0)
		_gib(PackedVector2Array([(b[&"neck"] as Vector2) + offset, (b[&"hip"] as Vector2) + offset]), push, half_side * 2.0, 1.2, 0.0, 3.2)
		var piece := _gib(PackedVector2Array([head + offset]), push + Vector2(0, -80), half_side * 2.0, 1.0, Fighter.HEAD_RADIUS)
		piece.half = int(half_side)
		var arm_key := &"b" if half_side < 0 else &"f"
		_gib(PackedVector2Array([b[&"shoulder"], b[StringName(arm_key + "elbow")], b[StringName(arm_key + "hand")]]), push, half_side * 2.0, 0.6)
		_gib(PackedVector2Array([b[&"hip"], b[StringName(arm_key + "knee")], b[StringName(arm_key + "foot")]]), push, half_side * 2.0, 0.6)
	_fountain(Vector2(head.x, (b[&"hip"] as Vector2).y), 1.4, Vector2.UP)
	_spray(loser.global_position + Vector2(0, -60), Vector2.LEFT, 40, 700.0, 0.5)
	_spray(loser.global_position + Vector2(0, -60), Vector2.RIGHT, 40, 700.0, 0.5)
	if not await _wait(1.0):
		return
	var sink := create_tween()
	sink.tween_method(func(r: float) -> void:
		pose["rise"] = r
		giant.queue_redraw(), 1.0, 0.0, 0.8)
	sink.tween_callback(shadow.queue_free)


## A thick limb with an ink outline (for Mahoraga).
func _thick(canvas: Node2D, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(a, b, INK, width + 6.0, true)
	canvas.draw_line(a, b, color, width, true)
	canvas.draw_circle(b, width * 0.5, color, true, -1.0, true)


## Goj: Domain Expansion: Unlimited Void. Endless information floods them, frozen;
## then he blinks in behind them and pulls their head clean off.
func _unlimited_void() -> void:
	winner.power_up(8.0)
	hud.announce("DOMAIN EXPANSION", Color(0.6, 0.85, 1.0))
	Audio.play("ko", 3.0, 0.45, 0.0)
	_wash(Color.BLACK, 0.92, 0.5, 1.7, 0.6, 7)
	var at: Vector2 = loser.aim_point(false)
	var void_state := {"t": 0.0}
	var stars := _prop(func(canvas: Node2D) -> void:
		var t: float = void_state["t"]
		var view := camera.visible_rect()
		# Streaks of light pouring in toward them from everywhere.
		for k in 90:
			var a := k * 2.399
			var dist := fmod(1.0 - (t * 0.8 + k * 0.011), 1.0) * view.size.length() * 0.6
			var p := at + Vector2.from_angle(a) * dist
			canvas.draw_line(p, p + Vector2.from_angle(a) * 18.0, Color(0.85, 0.95, 1.0, 0.9), 2.0, true)
		for ring in 4:
			var r := 80.0 + ring * 70.0 + sin(t * 3.0 + ring) * 10.0
			canvas.draw_arc(at, r, t + ring, t + ring + 2.5, 24, Color(0.55, 0.4, 1.0, 0.5), 4.0, true)
		canvas.draw_circle(at, 26.0, Color(0.9, 0.95, 1.0, 0.25), true, -1.0, true))
	stars.z_index = 12
	var spin := stars.create_tween()
	spin.tween_method(func(t: float) -> void:
		void_state["t"] = t
		stars.queue_redraw(), 0.0, 4.0, 3.2)
	if not await _wait(0.8):
		return
	hud.announce("UNLIMITED VOID", Color(0.6, 0.85, 1.0))
	# Frozen, twitching, overloaded.
	for k in 10:
		loser._tilt_velocity += (2.0 if k % 2 == 0 else -2.0)
		loser._flash = 0.5
		if not await _wait(0.12):
			return
	# He blinks in behind them, takes hold of the head, and pulls.
	var void_fade := stars.create_tween()
	void_fade.tween_property(stars, "modulate:a", 0.0, 0.5)
	var side := _toward_loser()
	_place_winner(loser.global_position.x + side * 46.0)
	winner.facing = -winner.facing
	winner.reset_physics_interpolation()
	winner.aiming = true
	winner.aim_angle = 40.0
	Audio.play("whoosh", 2.0, 1.8, 0.0)
	_frame_around(loser.global_position, 220.0, 360.0)
	if not await _wait(0.45):
		return
	for tug in 3:
		loser._tilt_velocity += side * 4.0
		loser._flash = 0.6
		Audio.play("thunk", -2.0, 0.6 + tug * 0.1, 0.0)
		if not await _wait(0.2):
			return
	var b := loser.body_points()
	_hide_loser()
	Audio.play("hit_head", 4.0, 0.9, 0.0)
	camera.shake(0.8)
	_gib(PackedVector2Array([b[&"head"]]), Vector2(side * 420.0, -620.0), side * 8.0, 1.6, Fighter.HEAD_RADIUS)
	for part: Array in _parts(b):
		if part[1] <= 0.0:
			_gib(part[0], Vector2(-side * randf_range(40, 120), -60.0), randf_range(-2, 2), 0.6)
	_fountain(b[&"neck"], 1.6, Vector2(side * 0.3, -1.0).normalized())
	_spray(b[&"neck"], Vector2(side, -0.5), 40, 700.0, 0.6)
	if not await _wait(0.4):
		return
	winner.aiming = false


## Ryo: gives in to the Satsui no Hado, closes in, and fires a Metsu Hadoken point blank.
func _metsu_hadoken() -> void:
	var side := _toward_loser()
	# He tears off his gi top and throws it aside.
	var top := _prop(func(canvas: Node2D) -> void:
		var cloth := PackedVector2Array([Vector2(-14, -26), Vector2(14, -26), Vector2(18, 24), Vector2(-18, 24)])
		canvas.draw_colored_polygon(cloth, Color(0.97, 0.97, 0.95))
		canvas.draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[3], cloth[0]]), INK, 2.5, true)
		canvas.draw_line(Vector2(-18, 14), Vector2(18, 14), Color(0.1, 0.08, 0.1), 4.0))
	top.position = winner.aim_point(false)
	var toss := top.create_tween().set_parallel()
	toss.tween_property(top, "position", top.position + Vector2(-side * 180.0, -40.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	toss.tween_property(top, "rotation", -side * 3.0, 0.7)
	toss.chain().tween_property(top, "position:y", Terrain.height_at(top.position.x - side * 180.0) - 8.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	winner.form = &"satsui"
	Audio.play("whoosh", 0.0, 1.2, 0.0)
	if not await _wait(0.5):
		return
	winner.power_up(8.0)
	hud.announce("SATSUI NO HADO", Color(0.95, 0.15, 0.15))
	Audio.play("ko", 3.0, 0.4, 0.0)
	_wash(Color(0.25, 0.0, 0.02), 0.4, 0.4, 2.4, 0.7, 2)
	for flare in 4:
		Effects.burst(self, winner.aim_point(false), Color(0.9, 0.1, 0.1), 26, 460.0, 180.0, 1.6)
		Effects.burst(self, winner.aim_point(false), Color(0.05, 0.0, 0.05), 16, 360.0, 180.0, 1.2)
		if not await _wait(0.15):
			return
	Audio.play("whoosh", 0.0, 0.8, 0.0)
	await _move_winner(Vector2(loser.global_position.x - side * 70.0, 0.0), 0.25, 0.0)
	if _done:
		return
	winner.aiming = true
	winner.aim_angle = 0.0
	winner.aim_power = 1.0
	hud.announce("METSU HADOKEN!", Color(1.0, 0.2, 0.2))
	var b := loser.body_points()
	var centre: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.5)
	var beam := Beam.new()
	beam.width_scale = 2.4
	beam.setup(winner.throw_origin(), winner.throw_origin() + Vector2(side * 1800.0, 0), Color(0.9, 0.08, 0.1))
	add_child(beam)
	await beam.fired
	if _done:
		return
	Audio.play("hit_head", 5.0, 0.35, 0.0)
	_impact(centre, 1.0)
	_flash_ring(centre, Color(1.0, 0.2, 0.15), 560.0)
	Effects.burst(self, centre, Color(1.0, 0.3, 0.2), 70, 1100.0, 180.0, 2.4)
	_hide_loser_and_explode(centre - Vector2(side * 50.0, 0), 1500.0, -0.5)
	await beam.finished
	winner.aiming = false


## Akum: Shun Goku Satsu. He glides in, the screen goes black, and all you see are the
## hits. When the light comes back he stands with his back turned under the mark of Heaven.
func _raging_demon() -> void:
	var side := _toward_loser()
	winner.power_up(9.0)
	hud.announce("SHUN GOKU SATSU", Color(0.9, 0.15, 0.15))
	Audio.play("ko", 4.0, 0.3, 0.0)
	await _move_winner(Vector2(loser.global_position.x - side * 60.0, 0.0), 0.7, 0.0)
	if _done:
		return
	var at: Vector2 = loser.aim_point(false)
	# Lights out.
	_wash(Color.BLACK, 1.0, 0.08, 1.9, 0.35, 16)
	if not await _wait(0.15):
		return
	var b := loser.body_points()
	_hide_loser()
	for part: Array in _parts(b):
		_gib(part[0], Vector2(randf_range(-160, 160), randf_range(-300, -80)), randf_range(-8, 8), 1.2, part[1])
	_spray(at, Vector2.UP, 60, 600.0, 1.4)
	# Nothing but the hits.
	for hit in 15:
		var spot := at + Vector2(randf_range(-70, 70), randf_range(-80, 50))
		var color := Color.WHITE if hit % 3 else Color(1.0, 0.2, 0.15)
		var flash := _prop(func(canvas: Node2D) -> void:
			for k in 8:
				var a := k * TAU / 8.0
				canvas.draw_line(Vector2.ZERO, Vector2.from_angle(a) * (26.0 if k % 2 == 0 else 14.0), color, 4.0, true))
		flash.position = spot
		flash.z_index = 20
		var pop := flash.create_tween()
		pop.tween_property(flash, "scale", Vector2.ONE * 1.6, 0.06)
		pop.tween_property(flash, "modulate:a", 0.0, 0.08)
		pop.tween_callback(flash.queue_free)
		Audio.play("hit_body" if hit % 2 else "hit_head", 0.0, randf_range(0.8, 1.3), 0.0)
		camera.shake(0.3)
		if not await _wait(0.1):
			return
	if not await _wait(0.4):
		return
	# Light returns: his back to us, the mark of Heaven burning behind him.
	winner.facing = -winner.facing
	winner.reset_physics_interpolation()
	var mark := {"a": 0.0}
	var heaven := _prop(func(canvas: Node2D) -> void:
		var a: float = mark["a"]
		var c := winner.global_position + Vector2(0, -150)
		var red := Color(0.95, 0.1, 0.1, a)
		var glow := Color(1.0, 0.3, 0.2, a * 0.35)
		for pass_width: float in [22.0, 9.0]:
			var col := glow if pass_width > 10.0 else red
			canvas.draw_line(c + Vector2(-50, -70), c + Vector2(50, -70), col, pass_width, true)
			canvas.draw_line(c + Vector2(-80, -15), c + Vector2(80, -15), col, pass_width, true)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(0, -110), c + Vector2(-5, -15), c + Vector2(-80, 90)]), col, pass_width, true)
			canvas.draw_line(c + Vector2(-2, -12), c + Vector2(85, 90), col, pass_width, true))
	heaven.z_index = -1
	var show := create_tween()
	show.tween_method(func(a: float) -> void:
		mark["a"] = a
		heaven.queue_redraw(), 0.0, 1.0, 0.6)
	show.tween_interval(1.4)
	show.tween_method(func(a: float) -> void:
		mark["a"] = a
		heaven.queue_redraw(), 1.0, 0.0, 0.6)
	_frame_around(winner.global_position, 300.0, 420.0)
	Audio.play("ground", 3.0, 0.3, 0.0)
	await show.finished


## Thundr: rises into a gathering storm, lightning strikes them three times, then
## Mjolnir comes down on what is left.
func _thunder_god() -> void:
	var side := _toward_loser()
	winner.power_up(8.0)
	hud.announce("GOD OF THUNDER", Color(0.7, 0.85, 1.0))
	_wash(Color(0.05, 0.08, 0.2), 0.5, 0.4, 3.0, 0.7, 2)
	var above := Vector2(loser.global_position.x - side * 160.0, loser.global_position.y - 320.0)
	_frame_around(loser.global_position, 320.0, 620.0)
	Audio.play("whoosh", 0.0, 0.5, 0.0)
	await _move_winner(above, 0.6, 0.0)
	if _done:
		return
	winner.aiming = true
	winner.aim_angle = 80.0
	for strike in 3:
		_bolt(loser.aim_point(strike == 2))
		loser._flash = 1.0
		loser._tilt_velocity += randf_range(-3, 3)
		_spray(loser.aim_point(false), Vector2.UP, 12, 400.0, 0.8)
		if not await _wait(0.35):
			return
	# Mjolnir, thrown straight down.
	var hammer := _weapon_prop(winner.data.weapon, 1.0)
	var from := winner.throw_origin()
	var target := loser.aim_point(false)
	hammer.position = from
	hammer.rotation = (target - from).angle()
	winner.play_throw()
	var fall := create_tween()
	fall.tween_property(hammer, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	if _done:
		return
	_bolt(target)
	_impact(target, 1.0)
	_flash_ring(target, Color(0.7, 0.88, 1.0), 520.0)
	var b := loser.body_points()
	_hide_loser()
	for part: Array in _parts(b):
		var piece := _gib(part[0], Vector2(randf_range(-900, 900), randf_range(-1100, -300)), randf_range(-12, 12), 0.8, part[1])
		piece.color = Color(0.18, 0.14, 0.12)
	_spray(target, Vector2.UP, 60, 900.0, 1.4)
	winner.aiming = false
	await _move_winner(Vector2(above.x, 0.0), 0.5, 0.0)


## A lightning bolt from the sky onto `at`.
func _bolt(at: Vector2) -> void:
	var points := PackedVector2Array([Vector2(at.x + randf_range(-60, 60), at.y - 1300)])
	for k in 12:
		var t := (k + 1) / 12.0
		points.append(Vector2(lerpf(points[0].x, at.x, t) + randf_range(-36, 36) * (1.0 - t), lerpf(points[0].y, at.y, t)))
	var bolt := _prop(func(canvas: Node2D) -> void:
		canvas.draw_polyline(points, Color(0.6, 0.8, 1.0, 0.45), 26.0, true)
		canvas.draw_polyline(points, Color(0.85, 0.95, 1.0), 9.0, true)
		canvas.draw_polyline(points, Color.WHITE, 3.0, true))
	bolt.z_index = 14
	var fade := bolt.create_tween()
	fade.tween_property(bolt, "modulate:a", 0.0, 0.4)
	fade.tween_callback(bolt.queue_free)
	_wash(Color(0.85, 0.92, 1.0), 0.45, 0.03, 0.05, 0.25, 9)
	Effects.burst(self, at, Color(0.7, 0.88, 1.0), 30, 600.0, 180.0, 1.4)
	Audio.play("hit_head", 4.0, 0.35, 0.0)
	camera.shake(0.8)


## Capt: hurls the shield at neck height; it takes the head clean off, rings off the
## ground and curves back into his hand.
func _shield_slice() -> void:
	var side := _toward_loser()
	winner.power_up(4.0)
	var shield := _weapon_prop(winner.data.weapon, 1.8)
	var from := winner.throw_origin()
	var b := loser.body_points()
	var neck: Vector2 = b[&"neck"]
	shield.position = from
	var spin := shield.create_tween().set_loops()
	spin.tween_property(shield, "rotation", TAU, 0.2).as_relative()
	winner.play_throw()
	Audio.play("whoosh", 2.0, 1.1, 0.0)
	var fly := create_tween()
	fly.tween_property(shield, "position", neck + Vector2(0, -4), 0.32)
	await fly.finished
	if _done:
		return
	_sfx("slice", 2.0, 1.0)
	_behead(Vector2(side * 380.0, -760.0), side * 14.0)
	# Off the ground and back to his hand.
	var bounce := Vector2(loser.global_position.x + side * 160.0, Terrain.height_at(loser.global_position.x + side * 160.0) - 10.0)
	var back := create_tween()
	back.tween_property(shield, "position", bounce, 0.18)
	back.tween_callback(func() -> void: Audio.play("thunk", 2.0, 1.4, 0.0))
	back.tween_property(shield, "position", winner.throw_origin(), 0.45).set_trans(Tween.TRANS_SINE)
	await back.finished
	spin.kill()
	shield.queue_free()


## Spydr: swings in on a web line and kicks them, wraps them in a cocoon, whirls it round
## his head and slams it into the ground, harder each time, until it bursts.
func _web_slam() -> void:
	var side := _toward_loser()
	winner.power_up(5.0)
	var b := loser.body_points()
	var centre: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.4)
	# Thwip: a line up into the sky, and a swing down into a kick.
	var anchor := Vector2((winner.global_position.x + loser.global_position.x) / 2, loser.global_position.y - 620.0)
	var start := winner.global_position
	var line := _prop(func(canvas: Node2D) -> void:
		canvas.draw_line(anchor, winner.throw_origin(), Color(0.95, 0.95, 1.0, 0.9), 2.0, true))
	get_tree().process_frame.connect(line.queue_redraw)
	Audio.play("twang", 0.0, 1.7, 0.0)
	var swing := create_tween()
	var kick_at := loser.global_position + Vector2(-side * 40.0, -30.0)
	swing.tween_method(func(t: float) -> void:
		winner.global_position = start.lerp(kick_at, t) + Vector2(0, -sin(t * PI) * 220.0), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	await swing.finished
	if _done:
		return
	line.queue_free()
	_sfx("punch", 4.0, 0.9)
	_impact(centre, 0.7)
	_spray(centre, Vector2(side, -0.4), 16, 500.0, 0.6)
	_place_winner(loser.global_position.x - side * 120.0)
	# Strands shooting out and wrapping them up.
	var strands := {"t": 0.0}
	var web := _prop(func(canvas: Node2D) -> void:
		var t: float = strands["t"]
		var from := winner.throw_origin()
		for k in 6:
			var to := centre + Vector2(0, (k - 2.5) * 16.0)
			canvas.draw_line(from, from.lerp(to, minf(1.0, t * 1.6)), Color(0.95, 0.95, 1.0, 0.9), 2.0, true))
	var shoot := create_tween()
	shoot.tween_method(func(t: float) -> void:
		strands["t"] = t
		web.queue_redraw(), 0.0, 1.0, 0.35)
	Audio.play("twang", 0.0, 1.5, 0.0)
	await shoot.finished
	if _done:
		return
	_hide_loser()
	web.queue_free()
	var cocoon := _prop(func(canvas: Node2D) -> void:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.55, 1.0))
		canvas.draw_circle(Vector2.ZERO, 60.0, Color(0.6, 0.62, 0.7), true, -1.0, true)
		canvas.draw_circle(Vector2.ZERO, 56.0, Color(0.95, 0.95, 1.0), true, -1.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
		for k in 7:
			var y := -48.0 + k * 16.0
			canvas.draw_line(Vector2(-30, y - 6), Vector2(30, y + 6), Color(0.7, 0.72, 0.8), 1.5, true))
	cocoon.position = centre
	var tether := _prop(func(canvas: Node2D) -> void:
		canvas.draw_line(winner.throw_origin(), cocoon.position, Color(0.95, 0.95, 1.0, 0.9), 2.5, true))
	get_tree().process_frame.connect(tether.queue_redraw)
	# Whirled round his head...
	var pivot := winner.throw_origin() + Vector2(0, -40)
	var radius := centre.distance_to(pivot)
	var start_angle := (centre - pivot).angle()
	var whirl := create_tween()
	whirl.tween_method(func(a: float) -> void:
		cocoon.position = pivot + Vector2.from_angle(start_angle - side * a) * radius
		cocoon.rotation = -side * a, 0.0, TAU * 1.5, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	Audio.play("whoosh", 0.0, 0.7, 0.0)
	await whirl.finished
	if _done:
		return
	# ...and slammed down, three times, harder each time.
	for slam in 3:
		var ground_x := pivot.x + side * (110.0 + slam * 20.0)
		var down := create_tween()
		down.tween_property(cocoon, "position", Vector2(ground_x, Terrain.height_at(ground_x) - 50.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await down.finished
		if _done:
			return
		_impact(cocoon.position + Vector2(0, 50), 0.6 + slam * 0.2)
		_spray(cocoon.position, Vector2.UP, 14 + slam * 14, 500.0 + slam * 150.0, 0.9)
		_sfx("crunch", 2.0 + slam, 0.9 + slam * 0.1)
		if slam < 2:
			var lift := create_tween()
			lift.tween_property(cocoon, "position", pivot + Vector2(side * 40.0, -200.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await lift.finished
			if _done:
				return
	tether.queue_free()
	# The cocoon bursts.
	var burst_at := cocoon.position
	cocoon.queue_free()
	for part: Array in _parts(b):
		var shifted := PackedVector2Array()
		for p: Vector2 in part[0]:
			shifted.append(p - centre + burst_at)
		_gib(shifted, Vector2(randf_range(-700, 700), randf_range(-800, -200)), randf_range(-12, 12), 1.0, part[1])
	_spray(burst_at, Vector2.UP, 60, 800.0, 1.4)


## Batz: the Batmobile roars in along the ground and runs them down. Then the
## Bat-Signal lights up the sky.
func _bat_beatdown() -> void:
	var side := _toward_loser()
	winner.power_up(4.0)
	hud.announce("BATMOBILE!", Color(1.0, 0.85, 0.2))
	var target_x := loser.global_position.x
	var start_x := winner.global_position.x - side * 900.0
	var end_x := target_x + side * 1400.0
	var car := {"x": start_x}
	var mobile := _prop(func(canvas: Node2D) -> void:
		var x: float = car["x"]
		var ground := Terrain.height_at(x)
		var tilt := (Terrain.height_at(x + 40.0) - Terrain.height_at(x - 40.0)) / 80.0
		canvas.draw_set_transform(Vector2(x, ground), atan(tilt), Vector2(float(side), 1.0))
		# Jet flame out of the back.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-150, -40), Vector2(-150 - 70.0 - randf() * 30.0, -30), Vector2(-150, -20)]), Color(0.4, 0.75, 1.0, 0.8))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-150, -36), Vector2(-150 - 35.0, -30), Vector2(-150, -24)]), Color.WHITE)
		# The body: long, low and armoured, with fins.
		var body := PackedVector2Array([Vector2(-150, -18), Vector2(-150, -52), Vector2(-120, -58), Vector2(-150, -96), Vector2(-90, -64), Vector2(-20, -78), Vector2(40, -74), Vector2(110, -46), Vector2(150, -40), Vector2(150, -18)])
		canvas.draw_colored_polygon(body, Color(0.1, 0.1, 0.12))
		canvas.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[6], body[7], body[8], body[9], body[0]]), Color(0.3, 0.3, 0.36), 2.5, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-20, -74), Vector2(30, -70), Vector2(60, -54), Vector2(-10, -56)]), Color(0.25, 0.35, 0.45))
		canvas.draw_circle(Vector2(146, -32), 6.0, Color(1.0, 0.95, 0.6), true, -1.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(150, -32), Vector2(260, -54), Vector2(260, -10)]), Color(1.0, 0.95, 0.6, 0.25))
		for wheel: float in [-95.0, 90.0]:
			canvas.draw_circle(Vector2(wheel, -16), 20.0, Color(0.03, 0.03, 0.04), true, -1.0, true)
			canvas.draw_circle(Vector2(wheel, -16), 9.0, Color(0.35, 0.35, 0.4), true, -1.0, true)
		canvas.draw_set_transform(Vector2.ZERO))
	mobile.z_index = 9
	_frame_around(Vector2(target_x - side * 200.0, loser.global_position.y), 560.0, 420.0)
	Audio.play("whoosh", 4.0, 0.4, 0.0)
	var hit := {"done": false}
	var drive := mobile.create_tween()
	drive.tween_method(func(x: float) -> void:
		car["x"] = x
		mobile.queue_redraw()
		if not hit["done"] and (x + side * 150.0 - target_x) * side >= 0.0:
			hit["done"] = true
			_run_over(side), start_x, end_x, 1.2)
	await drive.finished
	if _done:
		return
	mobile.queue_free()
	if not await _wait(0.4):
		return
	# The Bat-Signal.
	var signal_at := camera.visible_rect().position + Vector2(camera.visible_rect().size.x * 0.5, 110.0)
	var beacon := _prop(func(canvas: Node2D) -> void:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-40, 900), Vector2(40, 900), Vector2(70, 0), Vector2(-70, 0)]), Color(1.0, 0.95, 0.6, 0.15))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		canvas.draw_circle(Vector2.ZERO, 80.0, Color(1.0, 0.92, 0.45, 0.9), true, -1.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
		var bat := PackedVector2Array([Vector2(-60, -6), Vector2(-28, -18), Vector2(-14, -30), Vector2(-8, -16), Vector2(0, -22), Vector2(8, -16), Vector2(14, -30), Vector2(28, -18), Vector2(60, -6), Vector2(30, 2), Vector2(14, 22), Vector2(0, 10), Vector2(-14, 22), Vector2(-30, 2)])
		canvas.draw_colored_polygon(bat, INK))
	beacon.position = signal_at
	beacon.z_index = -1
	beacon.modulate.a = 0.0
	var shine := beacon.create_tween()
	shine.tween_property(beacon, "modulate:a", 1.0, 0.5)
	await shine.finished


## The Batmobile hitting them: the body flies apart down the road.
func _run_over(side: float) -> void:
	if _done:
		return
	var b := loser.body_points()
	_hide_loser()
	_sfx("punch", 6.0, 0.6)
	_impact(loser.aim_point(false), 1.0)
	for part: Array in _parts(b):
		_gib(part[0], Vector2(side * randf_range(900, 1500), randf_range(-700, -250)), randf_range(-14, 14), 1.2, part[1])
	_spray(loser.aim_point(false), Vector2(side, -0.4), 70, 1000.0, 0.6)


## Jotar: Star Platina steps out and buries them in a barrage, ORA ORA ORA, then one
## last punch sends them flying apart.
func _ora_rush() -> void:
	var side := _toward_loser()
	winner.power_up(6.0)
	hud.announce("STAR PLATINA!", Color(0.7, 0.5, 1.0))
	await _move_winner(Vector2(loser.global_position.x - side * 70.0, 0.0), 0.5, 0.0)
	if _done:
		return
	_frame_around(loser.global_position, 300.0, 420.0)
	await _stand_barrage("ORA", Color(0.75, 0.55, 1.0), 24)
	if _done:
		return
	_final_punch(side, "ORA!", Color(0.75, 0.55, 1.0))
	if not await _wait(0.6):
		return
	_put_stand_away()


## Dyo: stops time, hammers them with MUDA MUDA, hangs a ring of knives round them and
## drops a road roller on top. Then time moves again and every knife lands.
func _road_roller() -> void:
	var side := _toward_loser()
	winner.power_up(9.0)
	hud.announce("THE WARLD!  TIME STOP!", Color(1.0, 0.85, 0.3))
	Audio.play("zap", 0.0, 0.4, 0.0)
	Audio.play("ko", -4.0, 0.5, 0.0)
	var stop := _wash(Color(0.4, 0.28, 0.65), 0.45, 0.2, 60.0, 0.3, 8)
	await _move_winner(Vector2(loser.global_position.x - side * 70.0, 0.0), 0.4, 0.0)
	if _done:
		return
	_frame_around(loser.global_position, 360.0, 520.0)
	await _stand_barrage("MUDA", Color(1.0, 0.85, 0.3), 16)
	if _done:
		return
	winner.stand_barrage = false
	# Knives thrown from every side, hanging still in the stopped time.
	var centre := loser.aim_point(false)
	var knives: Array[Node2D] = []
	for k in 12:
		var a := -PI + k * PI / 11.0
		var knife := _weapon_prop(winner.data.weapon, 1.0)
		knife.global_position = winner.throw_origin()
		knife.rotation = a + PI
		knife.z_index = 14
		knives.append(knife)
		var spot := centre + Vector2.from_angle(a) * 150.0
		knife.create_tween().tween_property(knife, "global_position", spot, 0.12)
		_sfx("whoosh", -4.0, 1.5)
		if not await _wait(0.05):
			return
	if not await _wait(0.3):
		return
	# Leaps high, and the road roller comes down.
	var ground_x := loser.global_position.x
	var ground := Terrain.height_at(ground_x)
	await _move_winner(Vector2(ground_x - side * 40.0, ground - 520.0), 0.45, 0.0)
	if _done:
		return
	hud.announce("ROAD ROLLER!", Color(1.0, 0.75, 0.2))
	var roller := _prop(func(canvas: Node2D) -> void: _draw_road_roller(canvas))
	roller.z_index = 12
	roller.position = Vector2(ground_x, ground - 1400.0)
	roller.rotation = side * -0.35
	roller.scale = Vector2(side, 1.0)
	var drop := roller.create_tween()
	drop.tween_property(roller, "position:y", ground, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.parallel().tween_property(roller, "rotation", 0.0, 0.35)
	await drop.finished
	if _done:
		return
	var b := loser.body_points()
	_hide_loser()
	for part: Array in _parts(b):
		var flat := PackedVector2Array()
		for p: Vector2 in part[0]:
			flat.append(Vector2(p.x + (p.x - ground_x) * 0.8, ground - 4.0))
		_gib(flat, Vector2(randf_range(-500, 500), randf_range(-200, -60)), randf_range(-4, 4), 1.4, part[1] * 0.5)
	_spray(Vector2(ground_x, ground - 10.0), Vector2.UP, 80, 900.0, 1.6)
	_spray(Vector2(ground_x, ground - 10.0), Vector2(side, -0.2), 40, 900.0, 0.5)
	_impact(Vector2(ground_x, ground), 1.3)
	_sfx("crunch", 6.0, 0.6)
	_place_winner(ground_x)
	winner.global_position.y = ground - 190.0
	winner.reset_physics_interpolation()
	# Pounding the roller from on top.
	winner.stand_barrage = true
	for hit in 8:
		roller.position.y = ground + (6.0 if hit % 2 == 0 else 0.0)
		Effects.popup(self, Vector2(ground_x + randf_range(-90, 90), ground - randf_range(220, 300)), "MUDA", Color(1.0, 0.85, 0.3), 40, 1.0 / camera.zoom.x, camera.visible_rect())
		_sfx("punch", 0.0, randf_range(0.8, 1.2))
		camera.shake(0.4)
		if not await _wait(0.1):
			return
	winner.stand_barrage = false
	if not await _wait(0.3):
		return
	# Time moves again: every knife flies home, and the roller blows up.
	stop.queue_free()
	hud.announce("TIME RESUMES", Color(0.95, 0.95, 1.0))
	for knife in knives:
		knife.create_tween().tween_property(knife, "global_position", Vector2(ground_x + randf_range(-60, 60), ground - randf_range(10, 80)), 0.15)
	_sfx("slice", 4.0, 1.1)
	if not await _wait(0.2):
		return
	Audio.play("boom", 4.0, 0.8, 0.0)
	Effects.burst(self, Vector2(ground_x, ground - 60.0), Color(1.0, 0.6, 0.2), 70, 1000.0, 180.0, 2.6)
	_impact(Vector2(ground_x, ground), 1.2)
	roller.queue_free()
	for knife in knives:
		knife.queue_free()
	await _move_winner(Vector2(ground_x - side * 160.0, 0.0), 0.5, 0.0)
	_put_stand_away()


## The stand comes out and punches non-stop, shouting `word` with each blow.
func _stand_barrage(word: String, color: Color, hits: int) -> void:
	var appear := create_tween()
	appear.tween_property(winner, "stand_out", 1.0, 0.25)
	winner.stand_barrage = true
	_sfx("whoosh", 0.0, 0.6)
	var at := loser.aim_point(false)
	var side := _toward_loser()
	for hit in hits:
		var spot := at + Vector2(randf_range(-60, 60), randf_range(-90, 30))
		Effects.popup(self, spot + Vector2(0, -60), word, color, 30 + mini(hit, 20), 1.0 / camera.zoom.x, camera.visible_rect())
		_sfx("punch" if hit % 2 == 0 else "hit_body", -2.0, randf_range(0.85, 1.25))
		loser._flash = 1.0
		loser._tilt_velocity += 4.0 if hit % 2 == 0 else -4.0
		_spray(spot, Vector2(side, -0.5), 4, 400.0, 0.8)
		if hit % 3 == 0:
			camera.shake(0.35)
		if not await _wait(maxf(0.05, 0.1 - hit * 0.002)):
			return


## The barrage's last blow: a straight punch that blows them apart away from him.
func _final_punch(side: float, word: String, color: Color) -> void:
	winner.stand_barrage = false
	winner.play_throw()
	winner.stand_out = 1.0
	Effects.popup(self, loser.aim_point(true) + Vector2(0, -90), word, color, 72, 1.0 / camera.zoom.x, camera.visible_rect())
	_sfx("punch", 6.0, 0.7)
	_impact(loser.aim_point(false), 1.2)
	_hide_loser_and_explode(loser.aim_point(false) - Vector2(side * 60.0, 0), 1500.0, -0.45)


func _put_stand_away() -> void:
	if is_instance_valid(winner):
		winner.stand_barrage = false
		winner.create_tween().tween_property(winner, "stand_out", 0.0, 0.4)


## A yellow road roller: a heavy front drum, an engine body and a little cab.
func _draw_road_roller(canvas: Node2D) -> void:
	var yellow := Color(0.98, 0.74, 0.15)
	var body := PackedVector2Array([Vector2(-150, -24), Vector2(-150, -140), Vector2(10, -140), Vector2(40, -100), Vector2(40, -24)])
	canvas.draw_colored_polygon(body, yellow)
	canvas.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[0]]), INK, 4.0, true)
	var cab := PackedVector2Array([Vector2(-130, -140), Vector2(-130, -200), Vector2(-50, -200), Vector2(-40, -140)])
	canvas.draw_colored_polygon(cab, yellow.darkened(0.1))
	canvas.draw_polyline(PackedVector2Array([cab[0], cab[1], cab[2], cab[3]]), INK, 4.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-120, -150), Vector2(-120, -190), Vector2(-62, -190), Vector2(-54, -150)]), Color(0.55, 0.75, 0.9))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(-140, -70), "ROAD ROLLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	canvas.draw_circle(Vector2(90, -62), 62.0, INK, true, -1.0, true)
	canvas.draw_circle(Vector2(90, -62), 56.0, Color(0.35, 0.35, 0.38), true, -1.0, true)
	canvas.draw_line(Vector2(40, -62), Vector2(90, -62), INK, 8.0, true)
	canvas.draw_circle(Vector2(90, -62), 14.0, yellow, true, -1.0, true)
	canvas.draw_circle(Vector2(-110, -30), 30.0, INK, true, -1.0, true)
	canvas.draw_circle(Vector2(-110, -30), 12.0, Color(0.5, 0.5, 0.55), true, -1.0, true)


## Moves the winner to `to` over `seconds`, hopping `arc` px high on the way.
func _move_winner(to: Vector2, seconds: float, arc: float) -> void:
	# y = 0 means "on the ground there".
	if is_zero_approx(to.y):
		to.y = Terrain.height_at(to.x)
	var start := winner.global_position
	var move := winner.create_tween()
	move.tween_method(func(t: float) -> void:
		winner.global_position = start.lerp(to, t) + Vector2(0, -sin(t * PI) * arc), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	await move.finished


# --- building blocks ---

## Head, torso and the four limbs as [polyline, head radius] (radius 0 for limbs).
func _parts(b: Dictionary) -> Array:
	return [
		[PackedVector2Array([b[&"head"]]), Fighter.HEAD_RADIUS],
		[PackedVector2Array([b[&"neck"], b[&"hip"]]), 0.0],
		[PackedVector2Array([b[&"shoulder"], b[&"belbow"], b[&"bhand"]]), 0.0],
		[PackedVector2Array([b[&"shoulder"], b[&"felbow"], b[&"fhand"]]), 0.0],
		[PackedVector2Array([b[&"hip"], b[&"bknee"], b[&"bfoot"]]), 0.0],
		[PackedVector2Array([b[&"hip"], b[&"fknee"], b[&"ffoot"]]), 0.0],
	]


func _centre(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / points.size()


## A loose body part: `points` in world space, flying off with `velocity`, bleeding
## from its first point for `bleed` seconds.
func _gib(points: PackedVector2Array, velocity: Vector2, spin: float, bleed: float, radius: float = 0.0, width: float = 4.5) -> Gib:
	var gib := Gib.new()
	var centre := _centre(points)
	gib.position = centre
	for p in points:
		gib.points.append(p - centre)
	gib.head_radius = radius
	gib.width = width
	gib.color = INK
	gib.velocity = velocity
	gib.spin = spin
	gib.bleed = bleed
	gib.blood = _drip
	add_child(gib)
	return gib


func _hide_loser() -> void:
	if not _screamed:
		_screamed = true
		Audio.play("voice_die", 2.0, loser.voice_pitch() * 1.1, 0.0)
	_sfx("gore", 2.0, randf_range(0.9, 1.05))
	_sfx("crunch", -2.0, randf_range(0.9, 1.1))
	loser.visible = false
	for box in loser.get_children():
		if box is Hitbox:
			(box as Hitbox).collision_layer = 0


## Blows the whole body apart from `at`. lift scales how much of the push goes up.
func _hide_loser_and_explode(at: Vector2, power: float, lift: float = -0.9) -> void:
	var b := loser.body_points()
	_hide_loser()
	for part: Array in _parts(b):
		var centre := _centre(part[0])
		var away := (centre - at)
		if away.length() < 1.0:
			away = Vector2(randf_range(-1, 1), -1)
		var velocity := away.normalized() * power * randf_range(0.5, 1.0) + Vector2(randf_range(-200, 200), power * lift * randf_range(0.5, 1.0))
		_gib(part[0], velocity, randf_range(-14, 14), 1.4, part[1])
	_spray(at, Vector2.UP, 90, power * 0.8, 1.6)


## Head off, upward; the body crumples and the neck fountains.
func _behead(head_velocity: Vector2, head_spin: float) -> void:
	var b := loser.body_points()
	_hide_loser()
	_gib(PackedVector2Array([b[&"head"]]), head_velocity, head_spin, 1.0, Fighter.HEAD_RADIUS)
	for part: Array in _parts(b):
		if part[1] <= 0.0:
			_gib(part[0], Vector2(randf_range(-80, 80), -60.0), randf_range(-2, 2), 0.4)
	_fountain(b[&"neck"], 1.5, Vector2.UP)
	Audio.play("hit_head", 2.0, 1.2, 0.0)


## The head bursts into little chunks.
func _shatter_head(head: Vector2, push: Vector2) -> void:
	for k in 6:
		var dir := (push + Vector2(randf_range(-1, 1), randf_range(-1, 0.4))).normalized()
		_gib(PackedVector2Array([head]), dir * randf_range(300, 700), randf_range(-12, 12), 0.6, randf_range(4.0, 7.0))
	_spray(head, push.normalized(), 50, 700.0, 0.9)
	Audio.play("hit_head", 3.0, 0.9, 0.0)


## The headless body drops where it stands.
func _collapse(headless: bool) -> void:
	var b := loser.body_points()
	_hide_loser()
	for part: Array in _parts(b):
		if headless and part[1] > 0.0:
			continue
		_gib(part[0], Vector2(randf_range(-80, 80), -40.0), randf_range(-2, 2), 0.6, part[1])
	if headless:
		_fountain(b[&"neck"], 1.2, Vector2.UP)


func _impact(at: Vector2, strength: float) -> void:
	camera.shake(strength)
	Device.vibrate(int(160 * strength))
	Audio.play("ground", 0.0, 0.6, 0.0)
	Effects.burst(self, at, Color(0.85, 0.78, 0.72, 0.9), 24, 520.0, 70.0, 1.4)


## A burnt patch on the ground.
func _scorch(x: float, radius: float) -> void:
	var mark := _prop(func(canvas: Node2D) -> void:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.16))
		canvas.draw_circle(Vector2.ZERO, radius, Color(0.08, 0.06, 0.06, 0.55), true, -1.0, true)
		canvas.draw_circle(Vector2.ZERO, radius * 0.6, Color(0.05, 0.04, 0.04, 0.6), true, -1.0, true))
	mark.position = Vector2(x, Terrain.height_at(x) - 2.0)
	mark.z_index = -1


## A burst of blood drops along `direction`, spread by up to `spread` radians.
func _spray(at: Vector2, direction: Vector2, amount: int, speed: float, spread: float) -> void:
	_sfx("splat", -6.0 + minf(amount, 60) * 0.08, randf_range(0.85, 1.15))
	var count := maxi(4, roundi(amount * Device.particle_scale()))
	for i in count:
		var dir := direction.normalized().rotated(randf_range(-spread, spread))
		_drip(at, dir * speed * randf_range(0.3, 1.0))


## Blood pumping out of `at` for a while.
func _fountain(at: Vector2, seconds: float, direction: Vector2) -> void:
	_sfx("gush", 0.0, randf_range(0.9, 1.1))
	var left := seconds
	while left > 0.0 and not _done and is_inside_tree():
		_spray(at, direction, 4, 620.0 * (0.4 + left / seconds), 0.25)
		await get_tree().create_timer(0.04, false).timeout
		left -= 0.04


func _drip(at: Vector2, velocity: Vector2) -> void:
	if _drops >= MAX_DROPS:
		return
	_drops += 1
	var drop := Drop.new()
	drop.position = at
	drop.velocity = velocity
	drop.color = _blood_color().darkened(randf_range(0.0, 0.25))
	drop.size = randf_range(2.0, 4.5)
	add_child(drop)


func _prop(painter: Callable) -> Node2D:
	var node := Node2D.new()
	node.z_index = 6
	node.draw.connect(painter.bind(node))
	add_child(node)
	return node


## A big copy of a weapon to swing, drop or throw.
func _weapon_prop(weapon: WeaponData, size_scale: float) -> Node2D:
	var node := _prop(func(canvas: Node2D) -> void: Projectile.draw_weapon(canvas, weapon, Transform2D.IDENTITY))
	node.scale = Vector2.ONE * size_scale
	return node


## A loose stick-figure part that falls, bounces and bleeds.
class Gib extends Node2D:
	var points := PackedVector2Array()
	var width := 4.5
	var head_radius := 0.0
	## Half a head (split down the middle): -1 or 1; 0 for a whole one.
	var half := 0
	var color := INK
	var velocity := Vector2.ZERO
	var spin := 0.0
	var bleed := 0.0
	## Hangs in place (a headless body standing for a moment) until unfrozen.
	var frozen := false
	var blood: Callable
	var _resting := false
	var _drip := 0.0

	func _physics_process(delta: float) -> void:
		if frozen or _resting:
			_bleed(delta)
			return
		velocity.y += GRAVITY * delta
		position += velocity * delta
		rotation += spin * delta
		var low := _lowest()
		if low > 0.0:
			position.y -= low
			if velocity.y > 160.0:
				velocity = Vector2(velocity.x * 0.5, -velocity.y * 0.28)
				spin *= 0.5
			else:
				velocity = Vector2.ZERO
				spin = 0.0
				_resting = true
		_bleed(delta)

	func _bleed(delta: float) -> void:
		if bleed <= 0.0 or not blood.is_valid():
			return
		bleed -= delta
		_drip -= delta
		if _drip <= 0.0:
			_drip = 0.035
			var from := global_transform * (points[0] if not points.is_empty() else Vector2.ZERO)
			blood.call(from, velocity * 0.3 + Vector2(randf_range(-90, 90), randf_range(-160, 20)))

	## How far below the ground the lowest bit of this part is (positive = under).
	func _lowest() -> float:
		var reach := maxf(head_radius, width * 0.5)
		var low := -INF
		for p in points:
			var world := global_transform * p
			low = maxf(low, world.y + reach - Terrain.height_at(world.x))
		return low

	func _draw() -> void:
		if head_radius > 0.0:
			for p in points:
				if half == 0:
					draw_circle(p, head_radius, color, true, -1.0, true)
				else:
					var disc := PackedVector2Array()
					for k in 13:
						var a := PI / 2 + half * PI * k / 12.0
						disc.append(p + Vector2.from_angle(a) * head_radius)
					draw_colored_polygon(disc, color)
			return
		if points.size() >= 2:
			draw_polyline(points, color, width, true)
		for p in points:
			draw_circle(p, width * 0.5, color, true, -1.0, true)


## A drop of blood: flies, then splats flat on the ground and stays there.
class Drop extends Node2D:
	var velocity := Vector2.ZERO
	var color := BLOOD
	var size := 3.0
	var _landed := false

	func _physics_process(delta: float) -> void:
		velocity.y += GRAVITY * delta
		position += velocity * delta
		var ground := Terrain.height_at(position.x) - 1.0
		if position.y >= ground:
			position.y = ground
			_landed = true
			size *= randf_range(1.6, 2.6)
			z_index = -1
			set_physics_process(false)
		queue_redraw()

	func _draw() -> void:
		if _landed:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, size * 1.6, color, true, -1.0, true)
		else:
			draw_circle(Vector2.ZERO, size, color, true, -1.0, true)


## Moves the winner straight to x, standing on the ground there.
func _place_winner(x: float) -> void:
	winner.global_position = Vector2(x, Terrain.height_at(x))
	winner.reset_physics_interpolation()


## Plays a gore sound, but not the same one twice within a few frames, so a big
## finisher doesn't turn into noise.
func _sfx(sound: String, volume_db: float, pitch: float) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx.get(sound, -1000)) < 90:
		return
	_last_sfx[sound] = now
	Audio.play(sound, volume_db, pitch, 0.05)
