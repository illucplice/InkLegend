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
## The caption shown for each fighter's finisher.
const NAMES := {
	&"quotuk": "PANCAKED!", &"klakla": "PERFORATED!", &"pipmo": "SKEWERED!", &"fentuk": "PINCUSHION!",
	&"bomba": "KABOOM!", &"rango": "SLICED & DICED!", &"grak": "SPLIT IN TWO!", &"plopo": "HEAD SUCKER!",
	&"gok": "THROUGH AND THROUGH!", &"egita": "OBLITERATED!", &"lufi": "GEAR 4 BARRAGE!", &"ichi": "CERO!",
}

var winner: Fighter
var loser: Fighter
var camera: CameraRig
var hud: Hud
var gore := true

var _done := false
var _drops := 0
## Gear Fourth's bounce (a looping tween to stop if the finisher is skipped).
var _bounce: Tween
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
	camera.release_focus()
	# Undo anything a skipped finisher left half-done on the winner.
	if _bounce != null:
		_bounce.kill()
	if is_instance_valid(winner):
		winner.scale = Vector2.ONE
		winner.form = &""
		winner.global_position.y = 0.0
		winner.aiming = false
	finished.emit()


func _exit_tree() -> void:
	if not _done and is_instance_valid(camera):
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
			flat.append(Vector2(at.x + (p.x - at.x) * 1.8, -3.0 - absf(p.y) * 0.03))
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
		var stuck := Vector2(hit.x, 0) + dir * 30.0
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
		drop.tween_property(arrow, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
	rang.position.y = -36.0
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
	_spray(Vector2(loser.global_position.x, -36), Vector2(-side, -0.3), 30, 520.0, 0.6)
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
	for flare in 4:
		Effects.burst(self, winner.aim_point(false), Color(1.0, 0.85, 0.3), 26, 420.0, 40.0, 1.3)
		camera.shake(0.15)
		if not await _wait(0.12):
			return
	Audio.play("whoosh", 0.0, 0.45, 0.0)
	var start := winner.global_position
	var streak := _prop(func(canvas: Node2D) -> void:
		var now := winner.global_position + Vector2(0, -60)
		canvas.draw_line(start + Vector2(0, -60), now, Color(1.0, 0.85, 0.3, 0.35), 40.0, true)
		canvas.draw_line(start + Vector2(0, -60), now, Color(1.0, 0.95, 0.7, 0.7), 12.0, true))
	get_tree().process_frame.connect(streak.queue_redraw)
	await _move_winner(Vector2(loser.global_position.x - side * 44.0, 0.0), 0.16, 0.0)
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
	_hide_loser_and_explode(at - Vector2(side * 30.0, 30.0), 1100.0, -1.8)
	# The dragon: a thick glowing serpent spiralling up out of the wound.
	var state := {"t": 0.0}
	var gold := Color(1.0, 0.76, 0.16)
	var light := Color(1.0, 0.96, 0.7)
	var dragon := _prop(func(canvas: Node2D) -> void:
		var length := 60
		var head_index := int(state["t"] * length)
		if head_index < 3:
			return
		var path := PackedVector2Array()
		var widths := PackedFloat32Array()
		for i in head_index + 1:
			var u := i / float(length)
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
	rise.tween_method(func(t: float) -> void:
		state["t"] = t
		dragon.queue_redraw(), 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_interval(1.1)
	rise.tween_property(dragon, "modulate:a", 0.0, 0.5)
	_frame_around(Vector2(at.x, 0.0), 440.0, 1100.0)
	await rise.finished


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
	var above := Vector2(loser.global_position.x - side * 60.0, -430.0)
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
	_scorch(at.x, 220.0)
	await beam.finished
	if _done:
		return
	winner.aiming = false
	await _move_winner(Vector2(above.x, 0.0), 0.5, 0.0)


## Lufi: bites his arm and blows up into Gear Fourth: huge, puffed up and bouncing.
## Then a barrage of giant fists, and one last one that sends the pieces flying.
func _home_run() -> void:
	var side := _toward_loser()
	winner.power_up(6.0)
	hud.announce("GEAR FOURTH!", Color(1.0, 0.5, 0.55))
	Audio.play("whoosh", 0.0, 0.4, 0.0)
	var grow := winner.create_tween()
	grow.tween_property(winner, "scale", Vector2.ONE * 1.55, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for puff in 4:
		Effects.burst(self, winner.aim_point(false), Color(1.0, 0.8, 0.84, 0.85), 24, 260.0, 180.0, 2.0)
		if not await _wait(0.12):
			return
	await _move_winner(Vector2(loser.global_position.x - side * 130.0, 0.0), 0.35, 120.0)
	if _done:
		return
	# Boundman bounces on the spot while he punches.
	_bounce = winner.create_tween().set_loops()
	_bounce.tween_property(winner, "position:y", -40.0, 0.18).set_trans(Tween.TRANS_SINE)
	_bounce.tween_property(winner, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	var fist_weapon := winner.data.weapon.duplicate() as WeaponData
	fist_weapon.shape = &"fist"
	fist_weapon.size = 30.0
	fist_weapon.color = winner.data.body_color
	var elapsed := 0.0
	var hits := 0
	while elapsed < 1.4:
		var b := loser.body_points()
		var hit: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"head"], randf()) + Vector2(randf_range(-12, 12), randf_range(-10, 10))
		var from := winner.global_position + Vector2(side * 30.0, randf_range(-170, -80))
		var fist := _weapon_prop(fist_weapon, randf_range(2.2, 2.8))
		fist.position = from
		fist.rotation = (hit - from).angle()
		var jab := fist.create_tween()
		jab.tween_property(fist, "position", hit, 0.06)
		jab.tween_property(fist, "position", from, 0.06)
		jab.tween_callback(fist.queue_free)
		hits += 1
		loser._tilt_velocity += side * 2.4
		loser._flash = 0.7
		camera.shake(0.12)
		if hits % 2 == 0:
			_spray(hit, Vector2(side, -0.5), 8, 460.0, 0.7)
			Audio.play("hit_body", -4.0, randf_range(0.8, 1.1), 0.0)
		if not await _wait(0.05):
			return
		elapsed += 0.05
	_bounce.kill()
	_bounce = null
	# The finishing blow: a gigantic fist.
	var b := loser.body_points()
	var finish: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.6)
	var big := _weapon_prop(fist_weapon, 5.5)
	big.position = winner.global_position + Vector2(-side * 60.0, -160.0)
	big.rotation = (finish - big.position).angle()
	var punch := create_tween()
	punch.tween_property(big, "position", finish, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await punch.finished
	if _done:
		return
	Audio.play("hit_head", 5.0, 0.5, 0.0)
	_impact(finish, 1.0)
	_flash_ring(finish, Color(1.0, 0.7, 0.75), 360.0)
	_hide_loser_and_explode(finish - Vector2(side * 40.0, 0), 1500.0, -0.7)
	var back := big.create_tween().set_parallel()
	back.tween_property(big, "position", winner.throw_origin(), 0.25)
	back.tween_property(big, "modulate:a", 0.0, 0.3)
	# Deflate.
	if not await _wait(0.6):
		return
	var shrink := winner.create_tween().set_parallel()
	shrink.tween_property(winner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	shrink.tween_property(winner, "position:y", 0.0, 0.2)


## Ichi: the hollow takes over. He becomes his Vasto Lorde form, cuts them three times
## too fast to see, then blasts what is left with a huge red Cero from between the horns.
func _moon_slash() -> void:
	var side := _toward_loser()
	winner.power_up(8.0)
	winner.holding_weapon = false
	winner.form = &"vasto"
	hud.announce("VASTO LORDE!", Color(0.95, 0.15, 0.2))
	Audio.play("ko", 2.0, 0.4, 0.0)
	camera.shake(0.7)
	for burst in 3:
		Effects.burst(self, winner.aim_point(false), Color(0.85, 0.1, 0.15), 30, 520.0, 180.0, 1.8)
		Effects.burst(self, winner.aim_point(false), Color(0.05, 0.03, 0.06), 20, 380.0, 180.0, 1.5)
		if not await _wait(0.15):
			return
	if not await _wait(0.3):
		return
	var b := loser.body_points()
	var centre: Vector2 = (b[&"hip"] as Vector2).lerp(b[&"neck"], 0.4)
	winner.global_position.x = loser.global_position.x - side * 120.0
	winner.reset_physics_interpolation()
	for i in 3:
		var angle := [-0.6, 0.5, -0.1][i] as float
		var slash := _prop(func(canvas: Node2D) -> void:
			var points := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				points.append(Vector2(lerpf(-130, 130, t), sin(t * PI) * -28.0))
			canvas.draw_polyline(points, Color(0.9, 0.1, 0.15, 0.6), 16.0, true)
			canvas.draw_polyline(points, Color.WHITE, 4.0, true))
		slash.position = centre + Vector2(0, (i - 1) * 24.0)
		slash.rotation = angle
		var fade := slash.create_tween()
		fade.tween_property(slash, "modulate:a", 0.0, 0.35)
		fade.tween_callback(slash.queue_free)
		Audio.play("whoosh", -2.0, 1.4 + i * 0.1, 0.0)
		loser._flash = 1.0
		_spray(centre + Vector2(0, (i - 1) * 24.0), Vector2(randf_range(-1, 1), -1.0).normalized(), 14, 380.0, 0.6)
		if not await _wait(0.14):
			return
	# Behind them in a blink, then point blank: Cero.
	winner.global_position.x = loser.global_position.x + side * 120.0
	winner.facing = -winner.facing
	winner.reset_physics_interpolation()
	if not await _wait(0.4):
		return
	hud.announce("CERO!", Color(1.0, 0.15, 0.2))
	var dir := float(winner.facing)
	var horns: Vector2 = winner.body_points()[&"head"] + Vector2(dir * 26.0, -10.0)
	var cero := Beam.new()
	cero.width_scale = 2.6
	cero.setup(horns, horns + Vector2(dir * 2200.0, 60.0), Color(1.0, 0.1, 0.15))
	add_child(cero)
	Audio.play("whoosh", 2.0, 0.3, 0.0)
	_frame_around(loser.global_position + Vector2(dir * 300.0, 0), 560.0, 520.0)
	await cero.fired
	if _done:
		return
	Audio.play("hit_head", 5.0, 0.3, 0.0)
	Audio.play("ground", 3.0, 0.4, 0.0)
	_impact(centre, 1.0)
	_flash_ring(centre, Color(1.0, 0.2, 0.25), 560.0)
	Effects.burst(self, centre, Color(1.0, 0.25, 0.3), 70, 1100.0, 180.0, 2.6)
	_hide_loser()
	# Every piece cut in two and blown away down the beam.
	for part: Array in _parts(b):
		var points: PackedVector2Array = part[0]
		if part[1] > 0.0:
			for half: int in [-1, 1]:
				var piece := _gib(points, Vector2(dir * randf_range(900, 1300), -300.0 + half * 120.0), half * 8.0, 0.9, part[1])
				piece.half = half
			continue
		var cut := points[0].lerp(points[points.size() - 1], 0.5)
		for piece_points: PackedVector2Array in [PackedVector2Array([points[0], cut]), PackedVector2Array([cut, points[points.size() - 1]])]:
			_gib(piece_points, Vector2(dir * randf_range(700, 1300), randf_range(-420, -80)), randf_range(-10, 10), 1.0)
	for k in 3:
		_spray(centre + Vector2(0, (k - 1) * 24.0), Vector2(dir, -0.15), 40, 1100.0, 0.35)
	await cero.finished


## Moves the winner to `to` over `seconds`, hopping `arc` px high on the way.
func _move_winner(to: Vector2, seconds: float, arc: float) -> void:
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
	mark.position = Vector2(x, -2)
	mark.z_index = -1


## A burst of blood drops along `direction`, spread by up to `spread` radians.
func _spray(at: Vector2, direction: Vector2, amount: int, speed: float, spread: float) -> void:
	var count := maxi(4, roundi(amount * Device.particle_scale()))
	for i in count:
		var dir := direction.normalized().rotated(randf_range(-spread, spread))
		_drip(at, dir * speed * randf_range(0.3, 1.0))


## Blood pumping out of `at` for a while.
func _fountain(at: Vector2, seconds: float, direction: Vector2) -> void:
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
			low = maxf(low, (global_transform * p).y + reach)
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
		if position.y >= -1.0:
			position.y = -1.0
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
