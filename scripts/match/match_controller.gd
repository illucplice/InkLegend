extends Node2D
## Runs a match: sets up the arena and fighters, hands turns between the player and
## the AI, spawns projectiles, applies damage and ends the match on a knockout.

signal match_ended(winner: Fighter)

enum State { MENU, PLAYER_AIM, AI_AIM, FLYING, SETTLING, GAME_OVER }

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile/projectile.tscn")
const ROSTER := [
	preload("res://data/fighters/quotuk.tres"),
	preload("res://data/fighters/klakla.tres"),
	preload("res://data/fighters/pipmo.tres"),
	preload("res://data/fighters/fentuk.tres"),
]
const AI_THINK_TIME := 0.9
const SETTLE_TIME := 0.9
const INK := Color(0.12, 0.1, 0.14)

## When true the left fighter is also played by the AI (used by the headless tests).
var autoplay := false
var state := State.MENU
var fighters: Array[Fighter] = []
var current := 0
var rng := RandomNumberGenerator.new()

## Bumped on every new match so timers from an old match do nothing.
var _match_id := 0
var _brains: Array[AiAimer] = []
var _in_flight: Array[Projectile] = []
var _last_pick: FighterData
var _last_difficulty: int = AiAimer.Difficulty.NORMAL
var _actors: Node2D
var _aim: AimInput
var _camera: CameraRig
var _hud: Hud


static func roster() -> Array[FighterData]:
	var list: Array[FighterData] = []
	for fighter: FighterData in ROSTER:
		list.append(fighter)
	return list


func _ready() -> void:
	rng.randomize()
	add_child(Arena.new())
	_actors = Node2D.new()
	add_child(_actors)

	_aim = AimInput.new()
	_aim.z_index = 20
	add_child(_aim)
	_aim.finish()
	_aim.throw_requested.connect(_on_player_throw)

	_camera = CameraRig.new()
	add_child(_camera)
	_camera.points_provider = _camera_points
	_camera.make_current()
	_camera.snap()

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(roster())
	_hud.start_requested.connect(start_match)
	_hud.rematch_requested.connect(func() -> void: start_match(_last_pick, _last_difficulty))
	_hud.change_fighter_requested.connect(_hud.show_start)
	_hud.show_start()


func start_match(player_pick: FighterData, difficulty: int) -> void:
	_match_id += 1
	_last_pick = player_pick
	_last_difficulty = difficulty
	for child in _actors.get_children():
		child.queue_free()
	fighters.clear()
	_in_flight.clear()

	var foes: Array[FighterData] = []
	for fighter in roster():
		if fighter != player_pick:
			foes.append(fighter)
	var foe := foes[rng.randi_range(0, foes.size() - 1)]
	var gap := Rules.random_distance_px(rng)
	fighters.append(_spawn_fighter(player_pick, -gap / 2, 1, autoplay))
	fighters.append(_spawn_fighter(foe, gap / 2, -1, true))
	_brains = [AiAimer.new(difficulty) if autoplay else null, AiAimer.new(difficulty)]

	_hud.bind_fighters(fighters)
	_hud.hide_overlays()
	_hud.show_hint(not autoplay)
	_camera.snap()
	current = 0
	_begin_turn()


func _spawn_fighter(data: FighterData, x: float, facing: int, is_ai: bool) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.position = Vector2(x, 0)
	_actors.add_child(fighter)
	fighter.setup(data, facing, is_ai)
	return fighter


func _begin_turn() -> void:
	var fighter := fighters[current]
	fighter.holding_weapon = true
	if not fighter.is_ai:
		state = State.PLAYER_AIM
		_hud.set_turn("Your turn")
		_aim.begin(fighter)
		return

	state = State.AI_AIM
	_aim.finish()
	_hud.set_turn("%s is aiming…" % fighter.data.short_name)
	var match_id := _match_id
	await get_tree().create_timer(AI_THINK_TIME).timeout
	if match_id != _match_id:
		return
	var brain := _brains[current]
	var target := fighters[1 - current].aim_point(brain.wants_headshot())
	var shot := brain.aim(fighter.throw_origin(), target, fighter.data.weapon.max_speed, fighter.facing)
	_throw(shot["angle"], shot["power"])


func _on_player_throw(angle: float, power: float) -> void:
	if state != State.PLAYER_AIM:
		return
	_aim.finish()
	_throw(angle, power)


func _throw(angle: float, power: float) -> void:
	state = State.FLYING
	_hud.set_turn("")
	var fighter := fighters[current]
	var weapon := fighter.data.weapon
	fighter.play_throw()
	for i in weapon.count:
		var offset := (i - (weapon.count - 1) / 2.0) * weapon.spread_deg
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(weapon, fighter, fighter.throw_origin(), Rules.launch_velocity(angle + offset, power, weapon.max_speed, fighter.facing))
		projectile.hit_fighter.connect(_on_projectile_hit)
		projectile.finished.connect(_on_projectile_finished)
		_in_flight.append(projectile)


func _on_projectile_hit(projectile: Projectile, target: Fighter, is_head: bool) -> void:
	var damage := Rules.damage_for(projectile.weapon, is_head)
	target.take_hit(is_head, damage, projectile.current_velocity())
	var text := ("HEADSHOT!  -%d" if is_head else "-%d") % damage
	_popup(target.aim_point(true) + Vector2(0, -50), text, Color(1.0, 0.85, 0.2) if is_head else Color.WHITE)


func _on_projectile_finished(projectile: Projectile) -> void:
	_in_flight.erase(projectile)
	if not _in_flight.is_empty() or state != State.FLYING:
		return
	state = State.SETTLING
	var match_id := _match_id
	await get_tree().create_timer(SETTLE_TIME).timeout
	if match_id != _match_id:
		return
	for fighter in fighters:
		if fighter.is_knocked_out():
			_end_match()
			return
	current = 1 - current
	_begin_turn()


func _end_match() -> void:
	state = State.GAME_OVER
	_aim.finish()
	_hud.show_hint(false)
	_hud.set_turn("")
	var winner := fighters[1] if fighters[0].is_knocked_out() else fighters[0]
	var loser := fighters[0] if winner == fighters[1] else fighters[1]
	var title := "You win!" if winner == fighters[0] and not autoplay else "%s wins!" % winner.data.short_name
	_hud.show_result(title, "%s knocked out %s with %d health left." % [winner.data.short_name, loser.data.short_name, winner.health])
	match_ended.emit(winner)


func _camera_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if fighters.is_empty():
		points.append(Vector2(-550, -120))
		points.append(Vector2(550, 0))
		return points
	for fighter in fighters:
		points.append(fighter.global_position)
		points.append(fighter.aim_point(true))
	for projectile in _in_flight:
		points.append(projectile.global_position)
	return points


func _popup(at: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 9)
	label.size = Vector2(320, 50)
	label.pivot_offset = label.size / 2
	var inv_zoom := 1.0 / _camera.zoom.x
	label.scale = Vector2(inv_zoom, inv_zoom)
	label.position = at - label.size / 2
	label.z_index = 30
	_actors.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0 * inv_zoom, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.7)
	tween.chain().tween_callback(label.queue_free)
