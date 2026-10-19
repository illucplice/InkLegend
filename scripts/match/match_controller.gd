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
	preload("res://data/fighters/gok.tres"),
	preload("res://data/fighters/egita.tres"),
	preload("res://data/fighters/lufi.tres"),
	preload("res://data/fighters/ichi.tres"),
]
const MAPS := [
	preload("res://data/maps/colosseum.tres"),
	preload("res://data/maps/frozen.tres"),
	preload("res://data/maps/lava.tres"),
	preload("res://data/maps/pirate.tres"),
	preload("res://data/maps/neon.tres"),
	preload("res://data/maps/sky.tres"),
	preload("res://data/maps/canyon.tres"),
	preload("res://data/maps/bamboo.tres"),
	preload("res://data/maps/graveyard.tres"),
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
## Special meter gains: per hit, per headshot, and when you get hit.
const CHARGE_HIT := 0.4
const CHARGE_HEADSHOT := 0.6
const CHARGE_WHEN_HIT := 0.2
## Anime specials: the beam's reach and damage, and the Spirit Orb's blast.
const BEAM_RANGE := 3600.0
const BEAM_MULTIPLIER := 1.5
const ORB_RADIUS := 240.0
const ORB_MULTIPLIER := 2.4
const ORB_RAISE_TIME := 0.9
## Gum Barrage: fists thrown, seconds between them, random aim wobble (degrees), the
## damage each does compared with a thrown weapon, and how close (px) a fist must get
## before it homes in and how fast it can turn (rad/s).
const BARRAGE_FISTS := 5
const BARRAGE_GAP := 0.09
const BARRAGE_SPREAD := 3.0
const BARRAGE_MULTIPLIER := 0.4
const BARRAGE_HOMING_RANGE := 320.0
const BARRAGE_HOMING_TURN := 5.0
## Moon Fang: speed, size and damage multiplier of the crescent.
const FANG_SPEED := 1500.0
const FANG_SIZE := 70.0
const FANG_MULTIPLIER := 1.7
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
## True while a special is still launching projectiles (Gum Gatling), so the turn
## does not end when the first punch lands.
var _launching := false
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
## Special meter per side (0..1): fills as you land hits (and a little when hit). Full
## means the special can be armed for the next throw; using it empties the meter.
var _charge: Array[float] = [0.0, 0.0]
## Whether each side has used its special this match (for the daily challenge).
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
## Phase F: per-match tracking for rewards (your side only), and the daily
## challenge being played (empty if none).
var _max_combo := 0
var _smashed := 0
var _crates_collected := 0
var _specials_used := 0
var _daily := {}
## Where a Mega Wave beam ends, to keep it on camera (INF when there is none).
var _beam_end := Vector2.INF
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
	# Phones: a lower physics rate (interpolation keeps motion smooth).
	if Device.is_mobile():
		Engine.physics_ticks_per_second = 45
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
	_hud.daily_requested.connect(start_daily)
	_hud.resume_requested.connect(resume_tournament)
	_hud.give_up_requested.connect(func() -> void:
		Save.tournament = {}
		Save.save_progress()
		go_to_menu())
	_hud.pause_changed.connect(func(paused: bool) -> void: get_tree().paused = paused)
	go_to_menu()


## Clears any match and shows the title screen over the arena.
func go_to_menu() -> void:
	_clear_match()
	get_tree().paused = false
	state = State.MENU
	tournament = {}
	_arena.set_spread(MENU_GAP / 2)
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

	var gap := Rules.random_distance_px(rng, current_map)
	_gap = gap
	_arena.set_spread(gap / 2)
	_build_obstacles(gap, minf(left.weapon.max_speed, right.weapon.max_speed))
	var vs_ai := mode != Mode.LOCAL_2P
	fighters.append(_spawn_fighter(left, -gap / 2, 1, vs_ai and autoplay))
	fighters.append(_spawn_fighter(right, gap / 2, -1, vs_ai))
	_brains = [AiAimer.new(difficulty) if autoplay else null, AiAimer.new(difficulty) if vs_ai else null]

	_wind_strength = LOCAL_WIND if mode == Mode.LOCAL_2P else float(DIFFICULTY_WIND[difficulty])
	_special_used = [false, false]
	_charge = [0.0, 0.0]
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
	_launching = false
	_end_slow_time()
	_aim.finish()
	for child in _actors.get_children():
		child.queue_free()
	fighters.clear()
	_in_flight.clear()
	_max_combo = 0
	_smashed = 0
	_crates_collected = 0
	_specials_used = 0
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
	_daily = {}
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
	_daily = {}
	tournament = {"pick": pick, "round": 0, "rounds": rounds}
	_save_tournament()
	_hud.show_ladder(_ladder_info())


## Adds to a side's special meter; says so when the player's fills up.
func _add_charge(side: int, amount: float) -> void:
	var was_full := _charge[side] >= 1.0
	_charge[side] = minf(1.0, _charge[side] + amount)
	fighters[side].charge = _charge[side]
	if not was_full and _charge[side] >= 1.0 and not fighters[side].is_ai:
		_hud.announce("%s: SPECIAL READY!" % fighters[side].data.short_name.to_upper(), fighters[side].data.body_color.lightened(0.35))


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
	Device.vibrate(90)
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
	_arena.set_spread(700.0)
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
	_special_used = [false, false]
	_charge = [0.0, 0.0]
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
	var payout := _pay_out({"mode": mode, "won": false, "practice_stars": stars, "fighter_id": String(fighters[0].data.id), "map_id": String(current_map.id)})
	Audio.play("win", -3.0, 1.0, 0.0)
	_hud.show_result({
		"title": "PRACTICE DONE",
		"color": Color(0.3, 0.55, 0.95),
		"detail": "★ %d / %d   ·   %s
+%d coins" % [stars, best, rating, payout["coins"]],
		"winner": fighters[0].data,
		"winner_facing": 1,
		"names": ["You", ""],
		"stats": _stats,
		"practice": stars,
	})
	for id: String in payout["achievements"]:
		_hud.toast("Achievement: %s  +%d" % [Rewards.achievement(id)["name"], Rewards.ACHIEVEMENT_COINS], Color(1.0, 0.8, 0.3))


## Today's daily challenge: a set fighter, map and AI difficulty, plus a twist.
func start_daily() -> void:
	var challenge := Rewards.daily(Rewards.today(), roster(), maps())
	start_match(challenge["fighter"], null, Mode.VS_AI, challenge["difficulty"], challenge["map"])
	_daily = challenge


## Stores the tournament in progress so it can be continued after closing the game.
func _save_tournament() -> void:
	var rounds := []
	for round_info: Dictionary in tournament["rounds"]:
		var opponent: FighterData = round_info["opponent"]
		rounds.append({"opponent": String(opponent.id), "map": String(round_info["map"].id), "difficulty": round_info["difficulty"]})
	Save.tournament = {"pick": String(tournament["pick"].id), "round": tournament["round"], "rounds": rounds}
	Save.save_progress()


## Picks up a saved tournament and shows its ladder.
func resume_tournament() -> void:
	var saved: Dictionary = Save.tournament
	if saved.is_empty():
		return
	var pick := _fighter_by_id(saved["pick"])
	if pick == null:
		Save.tournament = {}
		return
	var rounds: Array[Dictionary] = []
	for round_info: Dictionary in saved["rounds"]:
		var id: String = round_info["opponent"]
		var opponent := _shadow_of(pick) if id.begins_with("shadow_") else _fighter_by_id(id)
		var map: MapData = MAPS[0]
		for candidate: MapData in MAPS:
			if String(candidate.id) == round_info["map"]:
				map = candidate
		rounds.append({"opponent": opponent, "map": map, "difficulty": round_info["difficulty"]})
	_daily = {}
	tournament = {"pick": pick, "round": saved["round"], "rounds": rounds}
	_hud.show_ladder(_ladder_info())


func _fighter_by_id(id: String) -> FighterData:
	for fighter in roster():
		if String(fighter.id) == id:
			return fighter
	return null


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
	var layout := ObstacleLayout.generate(rng, gap, slowest_speed, current_map.obstacle_patterns if current_map != null else PackedStringArray())
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
	_smashed += 1
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
	if side == 0:
		_crates_collected += 1
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
	if not is_ai:
		fighter.ink_color = Save.ink_color()
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
		_hud.set_special(null if mode == Mode.PRACTICE else fighter.data, _charge[current], false)
		_turn_timer = TURN_TIME if mode == Mode.LOCAL_2P else -1.0
		Audio.play("turn", -6.0)
		_aim.begin(fighter)
		return

	state = State.AI_AIM
	_aim.finish()
	_hud.set_special(null, 0.0, false)
	_hud.set_timer(-1)
	_hud.set_turn("%s IS AIMING…" % fighter.data.short_name.to_upper(), SIDE_COLORS[current])
	var brain := _brains[current]
	if _charge[current] >= 1.0 and brain.wants_special(fighter.health):
		_special_armed = true
	var target := fighters[1 - current].aim_point(brain.wants_headshot())
	var shot := brain.aim(fighter.throw_origin(), target, fighter.data.weapon.max_speed, fighter.facing, _obstacle_rects, _wind_for(fighter), Rules.GRAVITY * fighter.data.weapon.gravity_scale)
	if _special_armed and is_straight_special(fighter.data.weapon.special):
		shot = {"angle": beam_angle(fighter.throw_origin(), fighters[1 - current].aim_point(brain.wants_headshot()), fighter.facing) + brain.rng.randfn(0.0, 2.0), "power": 1.0}
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
	if state == State.PLAYER_AIM and _charge[current] >= 1.0:
		_special_armed = armed
		var data := fighters[current].data
		# The beam fires in a straight line, so the aim guide straightens and can point down.
		_aim.set_beam(armed and is_straight_special(data.weapon.special))
		_aim.set_special(data.special_name if armed else "", data.body_color)
		if armed:
			Audio.play("win", -10.0, 1.8, 0.0)
			_hud.announce("%s ARMED!" % data.special_name.to_upper(), data.body_color.lightened(0.35))


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
	_hud.set_special(null, 0.0, false)
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
		_charge[current] = 0.0
		fighter.charge = 0.0
		if current == 0:
			_specials_used += 1
		_hud.announce("%s: %s!" % [fighter.data.short_name.to_upper(), fighter.data.special_name.to_upper()], fighter.data.body_color.lightened(0.3))
		Audio.play("win", -8.0, 1.6, 0.0)
	if special == &"beam":
		fighter.powered = false
		_fire_beam(fighter, angle)
		return
	if special == &"orb":
		fighter.powered = false
		_throw_orb(fighter, angle, power)
		return
	if special == &"barrage":
		fighter.powered = false
		_barrage(fighter, angle, power)
		return
	if special == &"fang":
		fighter.powered = false
		_moon_fang(fighter, angle)
		return
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
		if not fighter.is_ai and weapon.shape != &"ki":
			projectile.set_trail_color(Save.trail_color())
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
		if side == 0:
			_max_combo = maxi(_max_combo, _combo[side])
		if _combo[side] >= 2:
			_hud.announce("COMBO x%d!" % _combo[side], Color(1.0, 0.55, 0.9))
	var combo: int = _combo[side] if side >= 0 else 0
	var damage := Rules.damage_with_bonuses(projectile.weapon, part, projectile.flight_time, combo)
	damage = roundi(damage * scale * (1.5 if projectile.get_meta("chop", false) else 1.0))
	if projectile.get_meta("beam", false):
		damage = roundi(damage * BEAM_MULTIPLIER)
	if projectile.get_meta("orb", false):
		damage = roundi(damage * ORB_MULTIPLIER)
	if projectile.get_meta("barrage", false):
		damage = maxi(1, roundi(damage * BARRAGE_MULTIPLIER))
	if projectile.get_meta("fang", false):
		damage = roundi(damage * FANG_MULTIPLIER)
	if projectile.get_meta("double", false):
		damage *= 2
	if target.shielded:
		target.shielded = false
		Effects.popup(_actors, target.aim_point(true) + Vector2(0, -60), "SHIELD BLOCK!", Color(0.6, 0.85, 1.0), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, projectile.global_position, Color(0.6, 0.85, 1.0), 26, 460.0, 180.0, 1.2)
		Audio.play("tick", 0.0, 0.6, 0.0)
		_camera.shake(0.3)
		return
	# Charge the special meters: the thrower for landing a hit, the target a little.
	if side >= 0 and mode != Mode.PRACTICE and not projectile.get_meta("barrage", false):
		_add_charge(side, CHARGE_HEADSHOT if part == Rules.HEAD else CHARGE_HIT)
		_add_charge(1 - side, CHARGE_WHEN_HIT)
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
			Device.vibrate(60)
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
			Device.vibrate(30)
			Audio.play("hit_body", 0.0 if projectile.weapon.count == 1 else -5.0, 1.0 if projectile.weapon.count == 1 else 1.4)
			Effects.burst(_actors, at, Color(1, 1, 1, 0.9), 12, 380.0)
			Effects.popup(_actors, target.aim_point(true) + Vector2(0, -50), "-%d" % damage, Color.WHITE, 34, inv_zoom, view)
			_camera.shake(0.45 if projectile.weapon.count == 1 else 0.25)
			_slow_time(0.06, 0.15)
	if target.is_knocked_out():
		Audio.play("ko", 0.0, 1.0, 0.0)
		Device.vibrate(140)
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
	if not _in_flight.is_empty() or _launching or state != State.FLYING:
		return
	_after_throw()


## Mega Wave: gather energy, then fire a straight beam. It smashes through obstacles
## and stops at the first fighter (or the ground) it meets.
func _fire_beam(fighter: Fighter, angle: float) -> void:
	fighter.power_up(1.8)
	var origin := fighter.throw_origin()
	var a := deg_to_rad(angle)
	var direction := Vector2(cos(a) * fighter.facing, -sin(a))
	var exclude := fighter.get_hitbox_rids()
	var space := get_world_2d().direct_space_state
	var from := origin
	var end := origin + direction * BEAM_RANGE
	var victim: Fighter = null
	var part := Rules.BODY
	var smashed: Array[Obstacle] = []
	for step in 8:
		var query := PhysicsRayQueryParameters2D.create(from, origin + direction * BEAM_RANGE, 0b11, exclude)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit["collider"]
		if collider is Obstacle:
			smashed.append(collider)
			exclude.append((collider as Obstacle).get_rid())
			from = hit["position"]
			continue
		end = hit["position"]
		if collider is Hitbox:
			victim = (collider as Hitbox).fighter
			part = (collider as Hitbox).part
		break
	var beam := Beam.new()
	beam.setup(origin, end, fighter.data.weapon.color)
	_actors.add_child(beam)
	_beam_end = end
	Audio.play("whoosh", -2.0, 0.4, 0.0)
	var match_id := _match_id
	await beam.fired
	if match_id != _match_id:
		return
	Audio.play("hit_head", 2.0, 0.45, 0.0)
	Audio.play("ground", 0.0, 0.7, 0.0)
	Device.vibrate(160)
	_camera.shake(1.0)
	_slow_time(0.25, 0.4)
	for obstacle in smashed:
		if is_instance_valid(obstacle) and not obstacle.is_destroyed:
			obstacle.damage(3)
	Effects.burst(_actors, end, fighter.data.weapon.color.lightened(0.3), 34, 620.0, 180.0, 1.6)
	if victim != null:
		# Damage goes through the usual hit code, via a stand-in projectile.
		var carrier := Projectile.new()
		carrier.weapon = fighter.data.weapon
		carrier.thrower = fighter
		carrier.position = end
		carrier.set_meta("beam", true)
		_on_projectile_hit(carrier, victim, part, 1.0, direction * 1500.0 + Vector2(0, -300))
		carrier.free()
	await beam.finished
	_beam_end = Vector2.INF
	if match_id == _match_id:
		_after_throw()


## Spirit Orb: raise a giant ball of energy overhead, then hurl it; it bursts in a
## huge blast wherever it lands.
func _throw_orb(fighter: Fighter, angle: float, power: float) -> void:
	fighter.power_up(2.2)
	fighter.aiming = true
	fighter.aim_angle = 80.0
	var weapon := fighter.data.weapon
	var glow := Node2D.new()
	glow.z_index = 22
	glow.position = fighter.global_position + Vector2(0, -200)
	_actors.add_child(glow)
	var grow := {"size": 0.0}
	glow.draw.connect(func() -> void:
		var r: float = 12.0 + grow["size"] * 58.0
		for ring in 4:
			glow.draw_circle(Vector2.ZERO, r * (1.35 - ring * 0.15), Color(weapon.color, 0.12 + ring * 0.08), true, -1.0, true)
		glow.draw_circle(Vector2.ZERO, r * 0.7, weapon.color.lightened(0.4), true, -1.0, true)
		glow.draw_circle(Vector2.ZERO, r * 0.4, Color.WHITE, true, -1.0, true))
	var tween := glow.create_tween()
	tween.tween_method(func(value: float) -> void:
		grow["size"] = value
		glow.queue_redraw(), 0.0, 1.0, ORB_RAISE_TIME)
	Audio.play("whoosh", -2.0, 0.35, 0.0)
	var match_id := _match_id
	await get_tree().create_timer(ORB_RAISE_TIME, false).timeout
	glow.queue_free()
	if match_id != _match_id:
		return
	fighter.aiming = false
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	_actors.add_child(projectile)
	projectile.launch(weapon, fighter, fighter.throw_origin(), Rules.launch_velocity(angle, power, weapon.max_speed, fighter.facing), _wind_for(fighter))
	projectile.target = fighters[1 - current]
	projectile.scale = Vector2(3.0, 3.0)
	projectile.explode_radius = ORB_RADIUS
	projectile.set_meta("orb", true)
	projectile.hit_fighter.connect(_on_projectile_hit)
	projectile.hit_ground.connect(_on_projectile_hit_ground)
	projectile.hit_crate.connect(_on_projectile_hit_crate)
	projectile.hit_target.connect(_on_practice_target_hit)
	projectile.exploded.connect(_on_projectile_exploded)
	projectile.finished.connect(_on_projectile_finished)
	_in_flight.append(projectile)


## The angle that points a beam straight at a target.
static func beam_angle(origin: Vector2, target: Vector2, facing: int) -> float:
	var to := target - origin
	return rad_to_deg(atan2(-to.y, to.x * facing))


## Once everything thrown has landed: combos, close calls, settling, then the next turn.
func _after_throw() -> void:
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
	_hud.set_special(null, 0.0, false)
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
	if mode == Mode.TOURNAMENT and not tournament.is_empty():
		if ladder["won"] and ladder["final"]:
			Save.tournament = {}
		else:
			_save_tournament()
	var summary := {
		"mode": mode,
		"won": winner_side == 0 and not autoplay,
		"difficulty": _last_difficulty,
		"round": ladder.get("round", 0),
		"champion": ladder.get("won", false) and ladder.get("final", false),
		"headshots": _stats[0]["headshots"],
		"longest": _stats[0]["longest"],
		"damage_taken": _stats[1]["damage"],
		"max_combo": _max_combo,
		"throws": _stats[0]["throws"],
		"special_used": _special_used[0],
		"health_left": fighters[0].health,
		"fighter_id": String(fighters[0].data.id),
		"map_id": String(current_map.id),
	}
	var payout := _pay_out(summary)
	match_ended.emit(winner)
	var match_id := _match_id
	await get_tree().create_timer(RESULT_DELAY, false).timeout
	if match_id != _match_id:
		return
	Audio.play("win" if player_won or autoplay else "lose", -3.0, 1.0, 0.0)
	var detail := "%s knocked out %s with %d health left." % [winner.data.short_name, loser.data.short_name, winner.health]
	if payout["coins"] > 0:
		detail += "\n+%d coins" % payout["coins"]
	if payout["daily"]:
		detail += "  ·  Daily challenge complete!"
	_hud.show_result({
		"title": title,
		"color": color,
		"detail": detail,
		"winner": winner.data,
		"winner_facing": 1,
		"names": _player_names(),
		"stats": _stats,
		"tournament": ladder,
	})
	if payout["levels"] > 0:
		_hud.toast("LEVEL UP!  Level %d  +%d" % [Save.level_info()["level"], payout["levels"] * Rewards.LEVEL_UP_COINS], Color(0.55, 0.9, 1.0))
	for id: String in payout["achievements"]:
		var entry := Rewards.achievement(id)
		_hud.toast("Achievement: %s  +%d" % [entry["name"], Rewards.ACHIEVEMENT_COINS], Color(1.0, 0.8, 0.3))


## Banks a finished match (not 1v1, not test autoplay): coins, fighter stats,
## running totals, achievements and the daily challenge. Returns what was earned:
## {coins, achievements (ids), daily (bool)}.
func _pay_out(summary: Dictionary) -> Dictionary:
	var result := {"coins": 0, "achievements": [], "daily": false, "levels": 0}
	if autoplay or mode == Mode.LOCAL_2P:
		return result
	var coins := Rewards.coins_for(summary)
	var stats := Save.stats_for(summary["fighter_id"])
	if mode != Mode.PRACTICE:
		stats["matches"] += 1
		stats["wins"] += 1 if summary["won"] else 0
	stats["headshots"] += int(summary.get("headshots", 0))
	stats["longest"] = maxf(stats["longest"], float(summary.get("longest", 0.0)))
	stats["damage"] += int(_stats[0]["damage"])
	Save.counters["smashed"] = int(Save.counters.get("smashed", 0)) + _smashed
	Save.counters["crates"] = int(Save.counters.get("crates", 0)) + _crates_collected
	Save.counters["specials"] = int(Save.counters.get("specials", 0)) + _specials_used
	if summary["won"]:
		var maps_won: Array = Save.counters.get("maps_won", [])
		if not maps_won.has(summary["map_id"]):
			maps_won.append(summary["map_id"])
		Save.counters["maps_won"] = maps_won
	var earned := Rewards.new_achievements(summary, Save, ROSTER.size())
	for id in earned:
		Save.achievements.append(id)
		coins += Rewards.ACHIEVEMENT_COINS
	if not _daily.is_empty() and Save.daily_done != _daily["date"] and Rewards.daily_met(_daily, summary):
		Save.daily_done = _daily["date"]
		coins += Rewards.DAILY_COINS
		result["daily"] = true
	var levels := Save.add_xp(Rewards.xp_for(summary))
	coins += levels * Rewards.LEVEL_UP_COINS
	result["levels"] = levels
	Save.coins += coins
	Save.save_progress()
	result["coins"] = coins
	result["achievements"] = earned
	return result


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
	if _beam_end != Vector2.INF:
		points.append(_beam_end)
	for box in _obstacle_rects:
		points.append(Vector2(box.get_center().x, box.position.y))
	for projectile in _in_flight:
		points.append(projectile.global_position)
	return points


## Specials that fly dead straight, so the aim guide is a straight line.
static func is_straight_special(special: StringName) -> bool:
	return special == &"beam" or special == &"fang"


## Hooks a projectile up to the usual hit handlers and counts it as in flight.
func _track(projectile: Projectile) -> void:
	projectile.hit_fighter.connect(_on_projectile_hit)
	projectile.hit_ground.connect(_on_projectile_hit_ground)
	projectile.hit_crate.connect(_on_projectile_hit_crate)
	projectile.hit_target.connect(_on_practice_target_hit)
	projectile.exploded.connect(_on_projectile_exploded)
	projectile.pierced.connect(_on_projectile_pierced)
	projectile.finished.connect(_on_projectile_finished)
	_in_flight.append(projectile)


## Gum Barrage: a rapid flurry of stretchy punches, each a little off the aim. A fist
## that gets close to the target bends toward it, so a decent aim lands most of them.
func _barrage(fighter: Fighter, angle: float, power: float) -> void:
	var fist := fighter.data.weapon.duplicate() as WeaponData
	fist.shape = &"fist"
	fist.size = 30.0
	fist.spin = 0.0
	fist.sticks = false
	fist.gravity_scale = 0.8
	var match_id := _match_id
	_launching = true
	for i in BARRAGE_FISTS:
		if i > 0:
			await get_tree().create_timer(BARRAGE_GAP, false).timeout
			if match_id != _match_id:
				return
		fighter.play_throw()
		Audio.play("whoosh", -6.0, randf_range(1.2, 1.5), 0.0)
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		var spread := rng.randf_range(-BARRAGE_SPREAD, BARRAGE_SPREAD)
		projectile.launch(fist, fighter, fighter.throw_origin(), Rules.launch_velocity(angle + spread, power * rng.randf_range(0.97, 1.03), fist.max_speed, fighter.facing), _wind_for(fighter))
		projectile.target = fighters[1 - current]
		projectile.homing_target = fighters[1 - current]
		projectile.homing_range = BARRAGE_HOMING_RANGE
		projectile.homing_turn = BARRAGE_HOMING_TURN
		projectile.set_meta("barrage", true)
		_track(projectile)
	_launching = false
	if _in_flight.is_empty() and state == State.FLYING:
		_after_throw()


## Moon Fang: a giant crescent slash that flies dead straight, ignores the wind and
## cuts through every obstacle in its way.
func _moon_fang(fighter: Fighter, angle: float) -> void:
	fighter.power_up(1.2)
	fighter.play_throw()
	var fang := fighter.data.weapon.duplicate() as WeaponData
	fang.shape = &"crescent"
	fang.size = FANG_SIZE
	fang.spin = 0.0
	fang.sticks = false
	fang.gravity_scale = 0.0
	Audio.play("whoosh", 0.0, 0.5, 0.0)
	_camera.shake(0.4)
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	_actors.add_child(projectile)
	projectile.launch(fang, fighter, fighter.throw_origin(), Rules.launch_velocity(angle, 1.0, FANG_SPEED, fighter.facing), 0.0)
	projectile.target = fighters[1 - current]
	projectile.pierce = true
	projectile.set_meta("fang", true)
	projectile.set_trail_color(fang.color)
	_track(projectile)


## Moon Fang slicing through an obstacle on its way.
func _on_projectile_pierced(projectile: Projectile, obstacle: Obstacle) -> void:
	obstacle.damage(2)
	var at := projectile.global_position
	Effects.burst(_actors, at, projectile.weapon.color.lightened(0.3), 24, 520.0, 180.0, 1.2)
	Effects.popup(_actors, at + Vector2(0, -50), "SLICED!", Color(1.0, 0.45, 0.45), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Audio.play("thunk", 0.0, 0.5, 0.0)
	_camera.shake(0.35)
