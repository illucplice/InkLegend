extends SceneTree
## Headless checks until GUT is added. Run from the project folder:
##   godot --headless --path . -s res://tests/run_tests.gd

const WEAPONS := ["hammer", "slingshot", "spear", "bow"]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_damage_table()
	_test_solver_lands_on_target()
	_test_ai_sharpens()
	_test_obstacles()
	await _test_ai_vs_ai_match()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _test_damage_table() -> void:
	var hammer: WeaponData = load("res://data/weapons/hammer.tres")
	_check(Rules.damage_for(hammer, false) == 30, "hammer body damage is 30")
	_check(Rules.damage_for(hammer, true) == 52, "hammer head damage is 52")
	for id: String in WEAPONS:
		var weapon: WeaponData = load("res://data/weapons/%s.tres" % id)
		var ratio := float(weapon.head_damage) / weapon.body_damage
		_check(absf(ratio - 1.75) < 0.05, "%s headshot is about 1.75x (got %.2f)" % [id, ratio])


func _test_solver_lands_on_target() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var gap := Rules.random_distance_px(rng)
		var facing := 1 if i % 2 == 0 else -1
		var origin := Vector2(-gap / 2 * facing, -92)
		var target := Vector2(gap / 2 * facing, -52 - rng.randf_range(0, 50))
		var shot := AiAimer.solve(origin, target, 1210.0, facing, rng.randf_range(35, 55))
		var velocity := Rules.launch_velocity(shot["angle"], shot["power"], 1210.0, facing)
		var t := (target.x - origin.x) / velocity.x
		var landed := Rules.position_at(origin, velocity, t)
		_check(landed.distance_to(target) < 1.0, "perfect throw %d lands on target (off by %.2f px)" % [i, landed.distance_to(target)])
		_check(float(shot["power"]) <= 1.0, "perfect throw %d is within max power" % i)


func _test_ai_sharpens() -> void:
	var origin := Vector2(-500, -92)
	var target := Vector2(500, -52)
	var perfect := AiAimer.solve(origin, target, 1210.0, 1)
	var first_error := 0.0
	var late_error := 0.0
	for trial in 200:
		var ai := AiAimer.new(AiAimer.Difficulty.NORMAL, trial)
		first_error += absf(float(ai.aim(origin, target, 1210.0, 1)["power"]) - float(perfect["power"]))
		for turn in 6:
			ai.aim(origin, target, 1210.0, 1)
		late_error += absf(float(ai.aim(origin, target, 1210.0, 1)["power"]) - float(perfect["power"]))
	_check(late_error < first_error * 0.6, "AI is more accurate on turn 8 than turn 1")


func _test_ai_vs_ai_match() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	game.autoplay = true
	root.add_child(game)
	await process_frame
	var result := {}
	game.match_ended.connect(func(winner: Fighter) -> void: result["winner"] = winner)
	var turns := {"count": 0}
	Engine.time_scale = 6.0
	# Mode is read off the instance: naming MatchController here would compile it before
	# the Audio autoload exists.
	game.start_match(game.roster()[0], game.roster()[1], game.Mode.VS_AI, AiAimer.Difficulty.HARD)
	var last_turn: int = game.current
	for frame in 8000:
		if not result.is_empty():
			break
		if game.current != last_turn:
			turns["count"] += 1
			last_turn = game.current
		await physics_frame
	Engine.time_scale = 1.0
	_check(not result.is_empty(), "an AI vs AI match ends in a knockout")
	if result.is_empty():
		return
	var winner: Fighter = result["winner"]
	_check(not winner.is_knocked_out(), "the winner is still standing")
	var knocked_out := 0
	for fighter: Fighter in game.fighters:
		if fighter.is_knocked_out():
			knocked_out += 1
	_check(knocked_out == 1, "exactly one fighter is knocked out")
	_check(turns["count"] >= 2, "turns alternated (%d turn changes)" % turns["count"])
	print("AI vs AI: %s won after %d turn changes" % [winner.data.short_name, turns["count"]])
	await _test_maps_and_tournament(game)
	game.queue_free()


func _test_obstacles() -> void:
	var tower: Array[Rect2] = [Rect2(-45, -300, 90, 300)]
	var origin := Vector2(-700, -92)
	var target := Vector2(700, -52)
	var flat := Rules.launch_velocity(15.0, 1.0, 1285.0, 1)
	_check(not AiAimer.path_is_clear(origin, flat, target, tower), "a flat throw is blocked by a tall tower")
	var shot := AiAimer.solve(origin, target, 1285.0, 1, 30.0, tower)
	var velocity := Rules.launch_velocity(shot["angle"], shot["power"], 1285.0, 1)
	_check(shot["clear"] and AiAimer.path_is_clear(origin, velocity, target, tower), "the AI finds a lob over the tower")

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var slowest: WeaponData = load("res://data/weapons/hammer.tres")
	for i in 40:
		var gap := Rules.random_distance_px(rng)
		var layout := ObstacleLayout.generate(rng, gap, slowest.max_speed)
		var boxes := ObstacleLayout.rects(layout)
		_check(not boxes.is_empty(), "layout %d has obstacles" % i)
		var in_middle := true
		for box in boxes:
			in_middle = in_middle and box.position.x > -gap / 2 + 250 and box.end.x < gap / 2 - 250
		_check(in_middle, "layout %d stays clear of both fighters" % i)
		for facing: int in [1, -1]:
			var from := Vector2(-gap / 2 * facing + Fighter.HAND_REST.x * facing, Fighter.HAND_REST.y)
			var to := Vector2(gap / 2 * facing, 0) + Fighter.BODY_CENTER
			var clear_shot := AiAimer.solve(from, to, slowest.max_speed, facing, 45.0, boxes)
			_check(clear_shot["clear"], "layout %d: the %s fighter has a clear throw" % [i, "left" if facing == 1 else "right"])


func _test_maps_and_tournament(game: Node) -> void:
	for map: MapData in game.maps():
		game._set_map(map)
		await process_frame
		_check(game.current_map == map and game._arena.map == map, "the %s map builds" % map.display_name)

	var pick: FighterData = game.roster()[2]
	game.start_tournament(pick)
	var rounds: Array = game.tournament["rounds"]
	_check(rounds.size() == 4, "a tournament has 4 rounds")
	var harder := true
	for i in range(1, rounds.size()):
		harder = harder and int(rounds[i]["difficulty"]) > int(rounds[i - 1]["difficulty"])
	_check(harder, "each tournament round is harder than the last")
	var opponents := {}
	for i in 3:
		opponents[rounds[i]["opponent"]] = true
	_check(opponents.size() == 3 and not opponents.has(pick), "rounds 1-3 are the three other fighters")
	var boss: FighterData = rounds[3]["opponent"]
	_check(boss.weapon == pick.weapon and boss.display_name.begins_with("Shadow"), "the final boss is a shadow of your fighter")
	_check(rounds[3]["map"].id == &"lava", "the final is in the Lava Forge")
