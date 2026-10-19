class_name MatchController
extends Node2D
## Runs the game: the title screen backdrop, then matches. Sets up the arena,
## fighters and obstacles, hands turns between players (or a player and the AI),
## spawns projectiles, applies damage and ends the match on a knockout.

signal match_ended(winner: Fighter)

enum State { MENU, PLAYER_AIM, AI_AIM, FLYING, SETTLING, GAME_OVER }
## VS_AI: the left fighter is the player, the right one the AI.
## LOCAL_2P: two players take turns on the same device.
## TOURNAMENT: like VS_AI, as one round of a ladder that gets harder each win.
## PRACTICE: alone against 10 targets at growing distances (see start_practice).
enum Mode { VS_AI, LOCAL_2P, TOURNAMENT, PRACTICE }

## Gap used for the decorative obstacles behind the title screen.
const MENU_GAP := 1500.0

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile/projectile.tscn")
const ROSTER := [
	preload("res://data/fighters/quotuk.tres"),
	preload("res://data/fighters/klakla.tres"),
	preload("res://data/fighters/pipmo.tres"),
	preload("res://data/fighters/fentuk.tres"),
	preload("res://data/fighters/bomba.tres"),
	preload("res://data/fighters/rango.tres"),
	preload("res://data/fighters/grak.tres"),
	preload("res://data/fighters/plopo.tres"),
]
const MAPS := [
	preload("res://data/maps/colosseum.tres"),
	preload("res://data/maps/frozen.tres"),
	preload("res://data/maps/lava.tres"),
	preload("res://data/maps/pirate.tres"),
	preload("res://data/maps/neon.tres"),
	preload("res://data/maps/sky.tres"),
]
## Tournament rounds: AI difficulty per round. The last round is the Champion boss.
const TOURNAMENT_DIFFICULTIES := [AiAimer.Difficulty.EASY, AiAimer.Difficulty.NORMAL, AiAimer.Difficulty.HARD, AiAimer.Difficulty.CHAMPION]
const AI_THINK_TIME := 1.0
const SETTLE_TIME := 0.9
const RESULT_DELAY := 0.6
## 1v1 turns time out after this many seconds.
const TURN_TIME := 12.0
const LAST_STAND_HEALTH := 20
## Longest a turn waits for ragdolls to settle, in seconds.
const MAX_SETTLE_WAIT := 3.0
## Chance a crate appears at the start of a turn (when none is waiting).
const CRATE_CHANCE := 0.4
## Seconds a floating slab takes to drift to its new spot.
const DRIFT_TIME := 0.8
## Target Practice: number of targets and tries per target (stars = tries left + 1).
const PRACTICE_TARGETS := 10
const PRACTICE_TRIES := 3
## A miss passing this close (px) to the target gets a "SO CLOSE!".
const CLOSE_CALL_DISTANCE := 45.0
## The headshot cam can trigger once a throw is this close (px) to a head.
const CINEMATIC_RANGE := 260.0
## Wind strength per AI difficulty; 1v1 uses LOCAL_WIND.
const DIFFICULTY_WIND := [0.0, 0.6, 1.0, 1.0]
const LOCAL_WIND := 0.8
## Throw sound per projectile shape: [sound, pitch].
const THROW_SOUNDS := {
	&"hammer": ["whoosh", 0.75],
	&"pebble": ["sling", 1.0],
	&"spear": ["whoosh", 1.1],
	&"arrow": ["twang", 1.0],
}

## When true the left fighter is also played by the AI (used by the headless tests).
var autoplay := false
var state := State.MENU
var mode: int = Mode.VS_AI
var fighters: Array[Fighter] = []
var current := 0
var rng := RandomNumberGenerator.new()
var current_map: MapData
## Empty when no tournament is running; otherwise pick, round and rounds (see start_tournament).
var tournament := {}

## Bumped on every new match so timers from an old match do nothing.
var _match_id := 0
var _brains: Array[AiAimer] = []
var _in_flight: Array[Projectile] = []
var _last_left: FighterData
var _last_right: FighterData
var _last_difficulty: int = AiAimer.Difficulty.NORMAL
var _last_map: MapData
var _backdrop: Backdrop
var _arena: Arena
var _actors: Node2D
var _obstacle_layer: Node2D
var _obstacle_rects: Array[Rect2] = []
var _aim: AimInput
var _camera: CameraRig
var _hud: Hud
var _slow_active := false
var _slow_token := 0
var _time_base := 1.0
## So a multi-pebble throw only says "Blocked!" once.
var _blocked_shown := false
var _sky_shown := false
## Wind for this turn (px/s²) and how strong winds get this match (0 = calm).
var wind := 0.0
var _wind_strength := 1.0
var _special_used: Array[bool] = [false, false]
var _special_armed := false
var _combo: Array[int] = [0, 0]
var _turn_hit := false
var _throw_closest := INF
var _turn_timer := -1.0
## One slow-mo headshot cam per throw at most.
var _cinematic_used := false
## Phase D: distance between the fighters, the current supply crate, turns played,
## and whether the thrower collected an extra throw.
var _gap := 1500.0
var _crate: Crate
var _turn_count := 0
var _extra_throw := false
## Target Practice progress: index, attempt, stars, and whether this throw hit.
var _practice := {}
var _practice_target: PracticeTarget
var _practice_hit := false
## Per side: throws, hits, headshots, damage, longest (metres).
var _stats: Array[Dictionary] = []
## Turn banner colours for the left and right side.
const SIDE_COLORS := [Color(0.3, 0.55, 0.95), Color(0.92, 0.3, 0.3)]


static func maps() -> Array[MapData]:
	var list: Array[MapData] = []
	for map: MapData in MAPS:
		list.append(map)
	return list


static func roster() -> Array[FighterData]:
	var list: Array[FighterData] = []
	for fighter: FighterData in ROSTER:
		list.append(fighter)
	return list


func _ready() -> void:
	rng.randomize()
	_obstacle_layer = Node2D.new()
	add_child(_obstacle_layer)
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
	_set_map(MAPS[0])

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(roster(), maps())
	_hud.play_requested.connect(_on_play_requested)
	_hud.rematch_requested.connect(func() -> void:
		if mode == Mode.PRACTICE:
			start_practice(_last_left)
		else:
			start_match(_last_left, _last_right, mode, _last_difficulty, _last_map))
	_hud.round_requested.connect(play_tournament_round)
	_hud.special_toggled.connect(_on_special_toggled)
	_hud.ladder_requested.connect(func() -> void: _hud.show_ladder(_ladder_info()))
	_hud.menu_requested.connect(go_to_menu)
	_hud.pause_changed.connect(func(paused: bool) -> void: get_tree().paused = paused)
	go_to_menu()


## Clears any match and shows the title screen over the arena.
func go_to_menu() -> void:
	_clear_match()
	get_tree().paused = false
	state = State.MENU
	tournament = {}
	_build_obstacles(MENU_GAP, 1210.0)
	_camera.snap()
	_hud.show_title()
	Audio.play_music("menu")


## In VS_AI mode `right` may be null to pick a random opponent; a null map is random.
func start_match(left: FighterData, right: FighterData, match_mode: int, difficulty: int, map: MapData = null) -> void:
	_clear_match()
	get_tree().paused = false
	mode = match_mode
	if mode != Mode.TOURNAMENT:
		tournament = {}
	_last_map = map
	Audio.play_music("battle")
	_set_map(map if map != null else MAPS[rng.randi_range(0, MAPS.size() - 1)])
	if right == null:
		var foes: Array[FighterData] = []
		for fighter in roster():
			if fighter != left:
				foes.append(fighter)
		right = foes[rng.randi_range(0, foes.size() - 1)]
	_last_left = left
	_last_right = right
	_last_difficulty = difficulty

	var gap := Rules.random_distance_px(rng)
	_gap = gap
	_build_obstacles(gap, minf(left.weapon.max_speed, right.weapon.max_speed))
	var vs_ai := mode != Mode.LOCAL_2P
	fighters.append(_spawn_fighter(left, -gap / 2, 1, vs_ai and autoplay))
	fighters.append(_spawn_fighter(right, gap / 2, -1, vs_ai))
	_brains = [AiAimer.new(difficulty) if autoplay else null, AiAimer.new(difficulty) if vs_ai else null]

	_wind_strength = LOCAL_WIND if mode == Mode.LOCAL_2P else float(DIFFICULTY_WIND[difficulty])
	_special_used = [false, false]
	_combo = [0, 0]
	_turn_count = 0
	_extra_throw = false
	_crate = null
	_maybe_spawn_crate(0.5)
	_turn_timer = -1.0
	var names := _player_names()
	_stats = [_empty_stats(), _empty_stats()]
	_hud.bind_fighters(fighters, names)
	_hud.show_match()
	_hud.set_practice(false)
	_camera.snap()
	current = 0
	if not autoplay:
		var match_id := _match_id
		await _hud.play_intro(left, right, names)
		if match_id != _match_id:
			return
	_begin_turn()


static func _empty_stats() -> Dictionary:
	return {"throws": 0, "hits": 0, "headshots": 0, "damage": 0, "longest": 0.0}


func _clear_match() -> void:
	_match_id += 1
	_end_slow_time()
	_aim.finish()
	for child in _actors.get_children():
		child.queue_free()
	fighters.clear()
	_in_flight.clear()
	_practice_target = null
	_practice_hit = false


## Swaps the backdrop and arena for another map's (no-op if it is already shown).
func _set_map(map: MapData) -> void:
	if map == current_map:
		return
	current_map = map
	if _backdrop != null:
		_backdrop.queue_free()
		_arena.queue_free()
	_backdrop = Backdrop.new()
	_backdrop.map = map
	_backdrop.camera = _camera
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_arena = Arena.new()
	_arena.map = map
	add_child(_arena)
	move_child(_arena, 1)


func _on_play_requested(left: FighterData, right: FighterData, match_mode: int, difficulty: int, map: MapData) -> void:
	if match_mode == Mode.TOURNAMENT:
		start_tournament(left)
	elif match_mode == Mode.PRACTICE:
		start_practice(left)
	else:
		start_match(left, right, match_mode, difficulty, map)


## Sets up a ladder: the other fighters in random order on random maps, getting
## harder each round, then a Champion-level shadow copy of your fighter in the Lava Forge.
func start_tournament(pick: FighterData) -> void:
	var foes: Array[FighterData] = []
	for fighter in roster():
		if fighter != pick:
			foes.append(fighter)
	foes.shuffle()
	foes = foes.slice(0, TOURNAMENT_DIFFICULTIES.size() - 1)
	foes.append(_shadow_of(pick))
	var map_order := maps()
	map_order.shuffle()
	var rounds: Array[Dictionary] = []
	var last := TOURNAMENT_DIFFICULTIES.size() - 1
	for i in TOURNAMENT_DIFFICULTIES.size():
		var map: MapData = MAPS[2] if i == last else map_order[i % map_order.size()]
		rounds.append({"opponent": foes[i], "map": map, "difficulty": TOURNAMENT_DIFFICULTIES[i]})
	tournament = {"pick": pick, "round": 0, "rounds": rounds}
	_hud.show_ladder(_ladder_info())


## The sideways push a fighter's throws feel: the turn's wind, plus a boomerang's
## pull back toward the thrower.
func _wind_for(fighter: Fighter) -> float:
	return wind - fighter.facing * fighter.data.weapon.pull_back


## Plunger: drag the target toward the thrower, but never into the obstacle zone.
func _pull_fighter(target: Fighter, thrower: Fighter, amount: float) -> void:
	var nearest := 450.0
	for box in _obstacle_rects:
		nearest = maxf(nearest, maxf(absf(box.position.x), absf(box.end.x)) + 150.0)
	var direction := signf(thrower.global_position.x - target.global_position.x)
	var x := target.position.x + direction * amount
	if absf(x) < nearest:
		x = signf(target.position.x) * nearest
	if absf(x - target.position.x) < 2.0:
		return
	Effects.popup(_actors, target.aim_point(true) + Vector2(0, -90), "PULLED!", Color(1.0, 0.55, 0.75), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
	target.create_tween().tween_property(target, "position:x", x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Bomb: everyone in the blast takes damage (less toward the edge) and is thrown
## outward; obstacles in it are chipped.
func _on_projectile_exploded(projectile: Projectile, at: Vector2, direct: Fighter, part: StringName, collider: Object) -> void:
	var radius := projectile.explode_radius
	Effects.burst(_actors, at, Color(1.0, 0.6, 0.2), 40, 700.0, 180.0, 1.8)
	Effects.burst(_actors, at, Color(0.15, 0.12, 0.14, 0.9), 26, 320.0, 180.0, 2.2)
	Effects.popup(_actors, at + Vector2(0, -50), "BOOM!", Color(1.0, 0.6, 0.25), 48, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Audio.play("ground", 2.0, 0.45, 0.0)
	Audio.play("hit_body", -2.0, 0.6, 0.0)
	_camera.shake(0.9)
	for fighter in fighters:
		if fighter == projectile.thrower or fighter.is_knocked_out():
			continue
		var centre := fighter.aim_point(false)
		var distance := 0.0 if fighter == direct else centre.distance_to(at)
		if distance > radius:
			continue
		var falloff := lerpf(1.0, 0.35, distance / radius)
		var push := (centre - at).normalized() * 900.0 + Vector2(0, -500)
		_on_projectile_hit(projectile, fighter, part if fighter == direct else Rules.BODY, falloff, push)
	for child in _obstacle_layer.get_children():
		var obstacle := child as Obstacle
		if obstacle != null and not obstacle.is_destroyed and (obstacle == collider or obstacle.rect.grow(radius * 0.5).has_point(at)):
			obstacle.damage(2)


## Target Practice: you alone against 10 targets, each further away (and from the
## 4th, higher up, with wind and walls in the way). Three tries each; a first-try hit
## earns 3 stars, second 2, third 1.
func start_practice(pick: FighterData) -> void:
	_clear_match()
	get_tree().paused = false
	mode = Mode.PRACTICE
	tournament = {}
	_last_left = pick
	_set_map(MAPS[0])
	Audio.play_music("battle")
	for child in _obstacle_layer.get_children():
		child.queue_free()
	_obstacle_rects.clear()
	_gap = 2000.0
	fighters.append(_spawn_fighter(pick, -700, 1, false))
	# An invisible stand-in opponent keeps the two-sided turn code happy; it can't be hit.
	var stand_in := _spawn_fighter(pick, 3600, -1, true)
	stand_in.visible = false
	for child in stand_in.get_children():
		if child is Hitbox:
			(child as Hitbox).collision_layer = 0
	fighters.append(stand_in)
	_brains = [null, null]
	_stats = [_empty_stats(), _empty_stats()]
	_special_used = [true, true]  # no specials in practice
	_combo = [0, 0]
	_turn_count = 0
	_extra_throw = false
	_crate = null
	_practice = {"index": 0, "attempt": 0, "stars": 0}
	_hud.bind_fighters(fighters, ["You", ""])
	_hud.show_match()
	_hud.set_practice(true)
	_spawn_practice_target()
	_camera.snap()
	current = 0
	_begin_turn()


func _practice_wind() -> float:
	var index: int = _practice["index"]
	if index < 3:
		return 0.0
	return Rules.random_wind(rng, 0.5 if index < 7 else 1.0)


func _spawn_practice_target() -> void:
	var index: int = _practice["index"]
	var thrower_x := fighters[0].global_position.x
	var distance := (25.0 + index * 6.0) * Rules.PX_PER_M
	var floating := index >= 3 and index % 2 == 1
	var height := rng.randf_range(160.0, 340.0) if floating else 70.0
	var at := Vector2(thrower_x + distance, -height)
	# From the 6th target on, a wall stands in the way.
	for child in _obstacle_layer.get_children():
		child.queue_free()
	_obstacle_rects.clear()
	if index >= 5:
		var wall := Obstacle.new()
		var mid := thrower_x + distance * 0.5
		var box := Rect2(mid - 45, -rng.randf_range(160.0, 260.0), 90, 0)
		box.size.y = -box.position.y
		wall.setup(&"tower", box, rng.randi(), current_map)
		wall.destroyed.connect(_on_obstacle_destroyed)
		_obstacle_layer.add_child(wall)
		_obstacle_rects.append(box)
	_practice_target = PracticeTarget.new()
	_practice_target.setup(at, floating)
	_actors.add_child(_practice_target)


func _on_practice_target_hit(projectile: Projectile, target: PracticeTarget) -> void:
	if _practice_hit:
		return
	_practice_hit = true
	var stars := PRACTICE_TRIES - int(_practice["attempt"])
	var bullseye := target.is_bullseye(projectile.global_position)
	_practice["stars"] += stars
	_stats[0]["hits"] += 1
	target.pop()
	Effects.burst(_actors, target.global_position, Color(1.0, 0.85, 0.3), 30, 520.0, 180.0, 1.3)
	Audio.play("hit_head" if bullseye else "hit_body")
	_hud.announce(("BULLSEYE!  " if bullseye else "HIT!  ") + "★".repeat(stars), Color(1.0, 0.85, 0.3))
	_camera.shake(0.35)


## After each practice throw: score it, move on to the next target, or finish.
func _practice_next() -> void:
	var hit := _practice_hit
	_practice_hit = false
	if hit or int(_practice["attempt"]) + 1 >= PRACTICE_TRIES:
		if not hit:
			_hud.announce("MISSED  ☆☆☆", Color(0.8, 0.82, 0.9))
			if _practice_target != null and is_instance_valid(_practice_target):
				_practice_target.pop()
		_practice["index"] += 1
		_practice["attempt"] = 0
		if int(_practice["index"]) >= PRACTICE_TARGETS:
			_end_practice()
			return
		_spawn_practice_target()
	else:
		_practice["attempt"] += 1
	_begin_turn()


func _end_practice() -> void:
	state = State.GAME_OVER
	_aim.finish()
	_hud.show_hint(false)
	_hud.set_turn("")
	fighters[0].celebrate()
	var stars: int = _practice["stars"]
	var best := PRACTICE_TARGETS * PRACTICE_TRIES
	var rating := "Sharpshooter!" if stars >= best * 0.8 else ("Nice aim!" if stars >= best * 0.5 else "Keep practising!")
	Audio.play("win", -3.0, 1.0, 0.0)
	_hud.show_result({
		"title": "PRACTICE DONE",
		"color": Color(0.3, 0.55, 0.95),
		"detail": "★ %d / %d   ·   %s" % [stars, best, rating],
		"winner": fighters[0].data,
		"winner_facing": 1,
		"names": ["You", ""],
		"stats": _stats,
		"practice": stars,
	})


## Plays the current tournament round (also used to retry after a loss).
func play_tournament_round() -> void:
	if tournament.is_empty():
		return
	var round_info: Dictionary = tournament["rounds"][tournament["round"]]
	start_match(tournament["pick"], round_info["opponent"], Mode.TOURNAMENT, round_info["difficulty"], round_info["map"])


## What the ladder screen shows: each round with its state (won, next or locked).
func _ladder_info() -> Dictionary:
	var rounds: Array[Dictionary] = []
	for i in tournament["rounds"].size():
		var round_info: Dictionary = tournament["rounds"][i].duplicate()
		round_info["state"] = "won" if i < tournament["round"] else ("next" if i == tournament["round"] else "locked")
		rounds.append(round_info)
	return {"pick": tournament["pick"], "round": tournament["round"], "rounds": rounds}


## A dark, glowing copy of a fighter for the final boss.
static func _shadow_of(fighter: FighterData) -> FighterData:
	var shadow: FighterData = fighter.duplicate()
	shadow.id = StringName("shadow_" + fighter.id)
	shadow.display_name = "Shadow " + fighter.short_name
	shadow.short_name = "Shadow"
	shadow.body_color = Color(0.45, 0.25, 0.65)
	shadow.cape_color = Color(0.55, 0.12, 0.65)
	shadow.accent_color = Color(0.85, 0.45, 1.0)
	shadow.skin_color = Color(0.72, 0.66, 0.85)
	return shadow


## What the HUD calls each side: "You"/"AI", or "Player 1"/"Player 2".
func _player_names() -> Array[String]:
	if mode == Mode.LOCAL_2P:
		return ["Player 1", "Player 2"]
	if autoplay:
		return ["AI", "AI"]
	return ["You", "AI"]


func _build_obstacles(gap: float, slowest_speed: float) -> void:
	for child in _obstacle_layer.get_children():
		child.queue_free()
	var layout := ObstacleLayout.generate(rng, gap, slowest_speed)
	_obstacle_rects = ObstacleLayout.rects(layout)
	for item in layout:
		var obstacle := Obstacle.new()
		obstacle.setup(item["kind"], item["rect"], rng.randi(), current_map)
		obstacle.destroyed.connect(_on_obstacle_destroyed)
		_obstacle_layer.add_child(obstacle)
		obstacle.reset_physics_interpolation()


## The rects the AI plans around: obstacles still standing, where they are now.
func _refresh_obstacle_rects() -> void:
	_obstacle_rects.clear()
	for child in _obstacle_layer.get_children():
		var obstacle := child as Obstacle
		if obstacle != null and not obstacle.is_destroyed:
			_obstacle_rects.append(obstacle.rect)


func _on_obstacle_destroyed(obstacle: Obstacle) -> void:
	var centre := obstacle.rect.get_center()
	Effects.burst(_actors, centre, obstacle.stone, 40, 620.0, 180.0, 1.6)
	Effects.burst(_actors, centre + Vector2(0, obstacle.rect.size.y * 0.3), obstacle.stone_dark, 30, 420.0, 180.0, 1.3)
	Effects.popup(_actors, centre + Vector2(0, -obstacle.rect.size.y * 0.5 - 30), "SMASHED!", Color(1.0, 0.75, 0.35), 36, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Audio.play("ground", 0.0, 0.55, 0.0)
	_camera.shake(0.6)
	_refresh_obstacle_rects()


## Each turn the floating slabs drift to a new spot in the middle of the arena.
func _drift_obstacles() -> void:
	var limit := _gap * 0.5 - 420.0
	for child in _obstacle_layer.get_children():
		var obstacle := child as Obstacle
		if obstacle == null or obstacle.is_destroyed or obstacle.kind != &"floating":
			continue
		var centre := clampf(obstacle.rect.get_center().x + rng.randf_range(-160.0, 160.0), -limit, limit)
		obstacle.drift_to(centre - obstacle.rect.size.x * 0.5, DRIFT_TIME)
	_refresh_obstacle_rects()


## Sometimes a supply crate floats down into the middle, clear of the obstacles.
func _maybe_spawn_crate(chance: float) -> void:
	if _crate != null and is_instance_valid(_crate) and not _crate.collected:
		return
	if rng.randf() > chance:
		return
	for attempt in 12:
		var at := Vector2(rng.randf_range(-_gap * 0.28, _gap * 0.28), rng.randf_range(-430.0, -250.0))
		var space := Rect2(at - Vector2(40, 110), Vector2(80, 140))
		var clear := true
		for box in _obstacle_rects:
			clear = clear and not box.grow(30).intersects(space)
		if clear:
			_crate = Crate.new()
			_crate.setup(Crate.KINDS[rng.randi_range(0, Crate.KINDS.size() - 1)], at)
			_actors.add_child(_crate)
			return


func _on_projectile_hit_crate(projectile: Projectile, crate: Crate) -> void:
	if crate.collected:
		return
	var side := fighters.find(projectile.thrower)
	if side < 0:
		return
	var owner_fighter := fighters[side]
	crate.collect()
	Effects.burst(_actors, crate.global_position, Crate.COLORS[crate.kind], 24, 480.0, 180.0, 1.2)
	Audio.play("win", -6.0, 1.8, 0.0)
	_hud.announce("%s: %s" % [owner_fighter.data.short_name.to_upper(), Crate.LABELS[crate.kind]], Crate.COLORS[crate.kind].lightened(0.2))
	match crate.kind:
		&"shield":
			owner_fighter.shielded = true
		&"double":
			owner_fighter.powered = true
		&"heal":
			owner_fighter.heal(25)
		&"extra":
			_extra_throw = true


func _spawn_fighter(data: FighterData, x: float, facing: int, is_ai: bool) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.position = Vector2(x, 0)
	_actors.add_child(fighter)
	# Fighters only move when a plunger drags them, by tween, so skip interpolation.
	fighter.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fighter.reset_physics_interpolation()
	fighter.setup(data, facing, is_ai)
	return fighter


func _begin_turn() -> void:
	var fighter := fighters[current]
	# Pin: a pinned fighter loses this turn.
	if fighter.pinned:
		fighter.pinned = false
		_hud.announce("%s IS PINNED!" % fighter.data.short_name.to_upper(), Color(0.75, 0.8, 0.95))
		var pin_id := _match_id
		await get_tree().create_timer(1.2, false).timeout
		if pin_id != _match_id:
			return
		current = 1 - current
		fighter = fighters[current]
	for other in fighters:
		other.is_turn = other == fighter
	fighter.holding_weapon = true
	wind = _practice_wind() if mode == Mode.PRACTICE else Rules.random_wind(rng, _wind_strength)
	_aim.wind = _wind_for(fighter)
	_hud.set_wind(wind)
	_special_armed = false
	_throw_closest = INF
	if _turn_count > 0 and mode != Mode.PRACTICE:
		_drift_obstacles()
		_maybe_spawn_crate(CRATE_CHANCE)
	_turn_count += 1
	_turn_hit = false
	if not fighter.is_ai:
		state = State.PLAYER_AIM
		var turn_text := "PLAYER %d'S TURN" % (current + 1) if mode == Mode.LOCAL_2P else "YOUR TURN"
		if mode == Mode.PRACTICE:
			turn_text = "TARGET %d/%d  ·  TRY %d/%d" % [_practice["index"] + 1, PRACTICE_TARGETS, _practice["attempt"] + 1, PRACTICE_TRIES]
		_hud.set_turn(turn_text, SIDE_COLORS[current])
		_hud.set_special(fighter.data, not _special_used[current], false)
		_turn_timer = TURN_TIME if mode == Mode.LOCAL_2P else -1.0
		Audio.play("turn", -6.0)
		_aim.begin(fighter)
		return

	state = State.AI_AIM
	_aim.finish()
	_hud.set_special(null, false, false)
	_hud.set_timer(-1)
	_hud.set_turn("%s IS AIMING…" % fighter.data.short_name.to_upper(), SIDE_COLORS[current])
	var brain := _brains[current]
	if not _special_used[current] and brain.wants_special(fighter.health):
		_special_armed = true
	var target := fighters[1 - current].aim_point(brain.wants_headshot())
	var shot := brain.aim(fighter.throw_origin(), target, fighter.data.weapon.max_speed, fighter.facing, _obstacle_rects, _wind_for(fighter))
	# Let the player watch the AI line up its throw.
	fighter.aiming = true
	fighter.aim_angle = 30.0
	fighter.aim_power = 0.0
	var wind_up := fighter.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wind_up.tween_property(fighter, "aim_angle", float(shot["angle"]), AI_THINK_TIME * 0.8)
	wind_up.tween_property(fighter, "aim_power", float(shot["power"]), AI_THINK_TIME * 0.8)
	var match_id := _match_id
	await get_tree().create_timer(AI_THINK_TIME, false).timeout
	if match_id != _match_id:
		return
	_throw(shot["angle"], shot["power"])


func _process(delta: float) -> void:
	# 1v1 turn timer: throw whatever is aimed when time runs out.
	if state != State.PLAYER_AIM or _turn_timer < 0.0:
		return
	_turn_timer -= delta
	_hud.set_timer(ceili(_turn_timer))
	if _turn_timer <= 0.0:
		_turn_timer = -1.0
		_hud.announce("TIME!", Color(1.0, 0.6, 0.3))
		_on_player_throw(_aim.angle, _aim.power)


## Slow-mo cam: if a throw is about to hit a head, slow time and swoop in on it.
func _physics_process(_delta: float) -> void:
	if state != State.FLYING or _cinematic_used or autoplay:
		return
	for projectile in _in_flight:
		if not is_instance_valid(projectile) or not projectile.is_flying() or projectile.target == null:
			continue
		var head := projectile.target.aim_point(true)
		if projectile.global_position.distance_to(head) > CINEMATIC_RANGE:
			continue
		for step in 30:
			if projectile.predict(step / 60.0).distance_to(head) < Fighter.HEAD_RADIUS + 4.0:
				_start_cinematic(projectile)
				return


func _start_cinematic(projectile: Projectile) -> void:
	_cinematic_used = true
	var target := projectile.target
	var framing := func() -> PackedVector2Array:
		var points := PackedVector2Array()
		if is_instance_valid(target):
			points.append(target.aim_point(true))
			points.append(target.global_position)
		if is_instance_valid(projectile):
			points.append(projectile.global_position)
		return points
	_camera.focus_on(framing, 1.1)
	_slow_time(0.8, 0.2)
	Audio.play("whoosh", -4.0, 0.5, 0.0)


func _on_special_toggled(armed: bool) -> void:
	if state == State.PLAYER_AIM and not _special_used[current]:
		_special_armed = armed


func _on_player_throw(angle: float, power: float) -> void:
	if state != State.PLAYER_AIM:
		return
	_aim.finish()
	_turn_timer = -1.0
	_hud.set_timer(-1)
	_throw(angle, power)


func _throw(angle: float, power: float) -> void:
	state = State.FLYING
	_hud.set_turn("")
	_hud.set_special(null, false, false)
	_blocked_shown = false
	_sky_shown = false
	_cinematic_used = false
	var fighter := fighters[current]
	var weapon := fighter.data.weapon
	fighter.play_throw()
	fighter.is_turn = false
	_stats[current]["throws"] += 1
	var sound: Array = THROW_SOUNDS.get(weapon.shape, ["whoosh", 1.0])
	Audio.play(sound[0], -2.0, sound[1] * lerpf(0.9, 1.1, power))

	var count := weapon.count
	var spread := weapon.spread_deg
	var special := weapon.special if _special_armed else &""
	if special != &"":
		_special_used[current] = true
		_hud.announce("%s: %s!" % [fighter.data.short_name.to_upper(), fighter.data.special_name.to_upper()], fighter.data.body_color.lightened(0.3))
		Audio.play("win", -8.0, 1.6, 0.0)
	match special:
		&"lucky":
			count = 5
		&"triple":
			count = 3
			spread = 3.0
		&"twin":
			count = 2
			spread = 7.0
	for i in count:
		var offset := (i - (count - 1) / 2.0) * spread
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(weapon, fighter, fighter.throw_origin(), Rules.launch_velocity(angle + offset, power, weapon.max_speed, fighter.facing), _wind_for(fighter))
		projectile.target = fighters[1 - current]
		if special == &"shockwave":
			projectile.bounces = 1
		if special == &"pin":
			projectile.set_meta("pin", true)
		if special == &"bigboom":
			projectile.explode_radius *= 1.6
		if special == &"chop" or special == &"suck":
			projectile.set_meta(special, true)
		projectile.exploded.connect(_on_projectile_exploded)
		projectile.hit_fighter.connect(_on_projectile_hit)
		projectile.hit_ground.connect(_on_projectile_hit_ground)
		projectile.hit_crate.connect(_on_projectile_hit_crate)
		projectile.hit_target.connect(_on_practice_target_hit)
		if fighter.powered:
			projectile.set_meta("double", true)
		projectile.finished.connect(_on_projectile_finished)
		_in_flight.append(projectile)
	fighter.powered = false


## scale (bomb blasts fall off with distance) and push (the blast direction) are
## only used by explosions.
func _on_projectile_hit(projectile: Projectile, target: Fighter, part: StringName, scale: float = 1.0, push: Vector2 = Vector2.ZERO) -> void:
	var side := fighters.find(projectile.thrower)
	# Combo counts turns in a row with at least one hit.
	if side >= 0 and not _turn_hit:
		_turn_hit = true
		_combo[side] += 1
		if _combo[side] >= 2:
			_hud.announce("COMBO x%d!" % _combo[side], Color(1.0, 0.55, 0.9))
	var combo: int = _combo[side] if side >= 0 else 0
	var damage := Rules.damage_with_bonuses(projectile.weapon, part, projectile.flight_time, combo)
	damage = roundi(damage * scale * (1.5 if projectile.get_meta("chop", false) else 1.0))
	if projectile.get_meta("double", false):
		damage *= 2
	if target.shielded:
		target.shielded = false
		Effects.popup(_actors, target.aim_point(true) + Vector2(0, -60), "SHIELD BLOCK!", Color(0.6, 0.85, 1.0), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, projectile.global_position, Color(0.6, 0.85, 1.0), 26, 460.0, 180.0, 1.2)
		Audio.play("tick", 0.0, 0.6, 0.0)
		_camera.shake(0.3)
		return
	var was_healthy := target.health > LAST_STAND_HEALTH
	var impact := push if push != Vector2.ZERO else projectile.current_velocity()
	target.take_hit(part, maxi(damage, Fighter.KNOCKDOWN_DAMAGE) if projectile.get_meta("chop", false) and target.health > Fighter.KNOCKDOWN_DAMAGE else damage, impact)
	var pull := projectile.weapon.pull_target * (2.2 if projectile.get_meta("suck", false) else 1.0)
	if pull > 0.0 and not target.is_knocked_out():
		_pull_fighter(target, projectile.thrower, pull)
	if projectile.get_meta("suck", false) and side >= 0:
		var stolen := mini(10, target.health)
		target.health -= stolen
		target.health_changed.emit(target, target.health)
		fighters[side].heal(stolen)
		_hud.announce("SUPER SUCK! +%d" % stolen, Color(1.0, 0.5, 0.75))
	if projectile.weapon.sticks:
		target.stick(projectile.weapon, projectile.global_position, projectile.current_velocity())
		projectile.visible = false
	if side >= 0:
		_stats[side]["hits"] += 1
		_stats[side]["headshots"] += 1 if part == Rules.HEAD else 0
		_stats[side]["damage"] += damage
		var metres := absf(target.global_position.x - projectile.thrower.global_position.x) / Rules.PX_PER_M
		_stats[side]["longest"] = maxf(_stats[side]["longest"], metres)
	if projectile.flight_time >= Rules.SKY_SHOT_TIME and not _sky_shown:
		_sky_shown = true
		_hud.announce("SKY SHOT!", Color(0.5, 0.85, 1.0))
	if projectile.get_meta("pin", false) and not target.is_knocked_out():
		target.pinned = true
		_hud.announce("PINNED!", Color(0.75, 0.8, 0.95))
	if was_healthy and target.health > 0 and target.health <= LAST_STAND_HEALTH:
		_hud.announce("LAST STAND!", Color(1.0, 0.35, 0.3))

	var inv_zoom := 1.0 / _camera.zoom.x
	var view := _camera.visible_rect()
	var at := projectile.global_position
	match part:
		Rules.HEAD:
			Audio.play("hit_head")
			Effects.burst(_actors, at, Color(1.0, 0.88, 0.3), 22, 520.0, 180.0, 1.2)
			Effects.popup(_actors, target.aim_point(true) + Vector2(0, -60), "HEADSHOT!  -%d" % damage, Color(1.0, 0.85, 0.2), 40, inv_zoom, view)
			_camera.shake(0.7)
			_slow_time(0.14, 0.1)
		Rules.LEGS:
			Audio.play("hit_body", -3.0, 1.2)
			Effects.burst(_actors, at, Color(1, 1, 1, 0.8), 8, 300.0)
			Effects.popup(_actors, target.aim_point(true) + Vector2(0, -50), "LEG  -%d" % damage, Color(0.85, 0.9, 1.0), 28, inv_zoom, view)
			_camera.shake(0.3)
		_:
			Audio.play("hit_body", 0.0 if projectile.weapon.count == 1 else -5.0, 1.0 if projectile.weapon.count == 1 else 1.4)
			Effects.burst(_actors, at, Color(1, 1, 1, 0.9), 12, 380.0)
			Effects.popup(_actors, target.aim_point(true) + Vector2(0, -50), "-%d" % damage, Color.WHITE, 34, inv_zoom, view)
			_camera.shake(0.45 if projectile.weapon.count == 1 else 0.25)
			_slow_time(0.06, 0.15)
	if target.is_knocked_out():
		Audio.play("ko", 0.0, 1.0, 0.0)
		Effects.popup(_actors, target.aim_point(true) + Vector2(0, -150), "K.O.!", Color(1.0, 0.4, 0.3), 80, inv_zoom, view)
		_camera.shake(1.0)
		_slow_time(1.1, 0.3)


func _on_projectile_hit_ground(projectile: Projectile, collider: Object) -> void:
	var weapon := projectile.weapon
	var at := projectile.global_position
	if projectile.bounces > 0:
		Effects.popup(_actors, at + Vector2(0, -40), "SHOCKWAVE!", Color(1.0, 0.8, 0.35), 28, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, at, Color(1.0, 0.85, 0.4, 0.95), 18, 420.0, 70.0, 1.1)
		_camera.shake(0.4)
	if collider is Obstacle:
		var heavy := weapon.body_damage >= Fighter.KNOCKDOWN_DAMAGE
		(collider as Obstacle).damage(2 if heavy else 1)
		Audio.play("thunk", 0.0, 0.65 if weapon.sticks else 0.5)
		Effects.burst(_actors, at, Color(0.85, 0.78, 0.72, 0.95), 14 if weapon.count == 1 else 5, 340.0, 180.0, 0.9)
		if not _blocked_shown and projectile.bounces == 0:
			_blocked_shown = true
			Effects.popup(_actors, at + Vector2(0, -40), "Blocked!", Color(0.85, 0.9, 1.0), 26, 1.0 / _camera.zoom.x, _camera.visible_rect())
		_camera.shake(0.25)
		return
	if weapon.shape == &"pebble":
		Audio.play("tick", -6.0)
	elif weapon.sticks:
		Audio.play("thunk", -2.0)
	else:
		Audio.play("ground", -2.0)
	Effects.burst(_actors, at, Color(0.62, 0.48, 0.34, 0.9), 10 if weapon.count == 1 else 4, 260.0, 50.0)
	_camera.shake(0.12)


func _on_projectile_finished(projectile: Projectile) -> void:
	_throw_closest = minf(_throw_closest, projectile.closest)
	_in_flight.erase(projectile)
	if not _in_flight.is_empty() or state != State.FLYING:
		return
	state = State.SETTLING
	if not _turn_hit:
		_combo[current] = 0
		if _throw_closest < CLOSE_CALL_DISTANCE:
			_hud.announce("SO CLOSE!", Color(1.0, 0.85, 0.4))
	if mode == Mode.PRACTICE:
		var practice_id := _match_id
		await get_tree().create_timer(SETTLE_TIME, false).timeout
		if practice_id == _match_id:
			_practice_next()
		return
	var match_id := _match_id
	await get_tree().create_timer(SETTLE_TIME, false).timeout
	if match_id != _match_id:
		return
	# Wait for knocked-down fighters to land and get back up (or lie still).
	var waited := 0.0
	while waited < MAX_SETTLE_WAIT and not _all_settled():
		await get_tree().process_frame
		if match_id != _match_id:
			return
		waited += get_process_delta_time()
	for fighter in fighters:
		if fighter.is_knocked_out():
			_end_match()
			return
	if _extra_throw:
		_extra_throw = false
		_hud.announce("EXTRA THROW!", Color(1.0, 0.8, 0.25))
	else:
		current = 1 - current
	_begin_turn()


func _all_settled() -> bool:
	for fighter in fighters:
		if not fighter.is_settled():
			return false
	return true


func _end_match() -> void:
	state = State.GAME_OVER
	_aim.finish()
	_hud.show_hint(false)
	_hud.set_turn("")
	var winner := fighters[1] if fighters[0].is_knocked_out() else fighters[0]
	var loser := fighters[0] if winner == fighters[1] else fighters[1]
	for fighter in fighters:
		fighter.is_turn = false
	var winner_side := fighters.find(winner)
	winner.celebrate()
	var player_won := (winner_side == 0 and not autoplay) or mode == Mode.LOCAL_2P
	var title := "DEFEAT"
	var color := Color(0.92, 0.3, 0.3)
	if mode == Mode.LOCAL_2P:
		title = "PLAYER %d WINS!" % (winner_side + 1)
		color = SIDE_COLORS[winner_side]
	elif player_won:
		title = "VICTORY!"
		color = Color(0.4, 0.8, 0.32)
	# In a tournament a win moves the ladder on; winning the last round makes you champion.
	var ladder := {}
	if mode == Mode.TOURNAMENT and not tournament.is_empty():
		var total: int = tournament["rounds"].size()
		var round_number: int = tournament["round"] + 1
		var final := round_number == total
		ladder = {"won": player_won, "final": final, "round": round_number, "total": total}
		if player_won:
			tournament["round"] = round_number
			if final:
				title = "CHAMPION!"
				color = Color(1.0, 0.75, 0.2)
	match_ended.emit(winner)
	var match_id := _match_id
	await get_tree().create_timer(RESULT_DELAY, false).timeout
	if match_id != _match_id:
		return
	Audio.play("win" if player_won or autoplay else "lose", -3.0, 1.0, 0.0)
	_hud.show_result({
		"title": title,
		"color": color,
		"detail": "%s knocked out %s with %d health left." % [winner.data.short_name, loser.data.short_name, winner.health],
		"winner": winner.data,
		"winner_facing": 1,
		"names": _player_names(),
		"stats": _stats,
		"tournament": ladder,
	})


## Slows the game for `duration` real seconds. A newer call replaces an older one.
func _slow_time(duration: float, time_scale: float) -> void:
	if not _slow_active:
		_time_base = Engine.time_scale
		_slow_active = true
	_slow_token += 1
	var token := _slow_token
	Engine.time_scale = _time_base * time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _slow_token:
		_end_slow_time()


func _end_slow_time() -> void:
	if _slow_active:
		Engine.time_scale = _time_base
		_slow_active = false
	_slow_token += 1


func _camera_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if fighters.is_empty():
		points.append(Vector2(-550, -120))
		points.append(Vector2(550, 0))
		return points
	for fighter in fighters:
		if not fighter.visible:
			continue
		points.append(fighter.global_position)
		points.append(fighter.aim_point(true))
	if _practice_target != null and is_instance_valid(_practice_target):
		points.append(_practice_target.global_position + Vector2(0, 60))
	for box in _obstacle_rects:
		points.append(Vector2(box.get_center().x, box.position.y))
	for projectile in _in_flight:
		points.append(projectile.global_position)
	return points
