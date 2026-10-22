extends SceneTree
## Headless checks until GUT is added. Run from the project folder:
##   godot --headless --path . -s res://tests/run_tests.gd

const WEAPONS := ["hammer", "slingshot", "spear", "bow"]
const WEAPON_FIGHTERS := ["quotuk", "klakla", "pipmo", "fentuk", "bomba", "rango", "grak", "plopo"]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	# Never touch the real save: point progress at a scratch file and start fresh.
	var save: Node = root.get_node("Save")
	save.progress_path = "user://test_progress.cfg"
	save.reset_progress()
	_test_damage_table()
	_test_solver_lands_on_target()
	_test_ai_sharpens()
	_test_obstacles()
	_test_terrain()
	_test_shadow_boss()
	_test_wind_solver()
	_test_destructible_obstacles()
	_test_progression(root.get_node("Save"))
	await _test_map_variety()
	await _test_ai_vs_ai_match()
	await _test_anime_match()
	await _test_straw_reaper_match()
	await _test_homing_and_balance()
	await _test_practice_specials()
	await _test_fatalities()
	await _test_practice_fatality()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _test_damage_table() -> void:
	var hammer: WeaponData = load("res://data/weapons/hammer.tres")
	_check(Rules.damage_for(hammer, Rules.BODY) == 30, "hammer body damage is 30")
	_check(Rules.damage_for(hammer, Rules.HEAD) == 52, "hammer head damage is 52")
	_check(Rules.damage_for(hammer, Rules.LEGS) == 21, "hammer leg damage is 70% of body")
	_check(Rules.damage_with_bonuses(hammer, Rules.BODY, 3.0, 1) == 35, "a sky shot adds 15%")
	_check(Rules.damage_with_bonuses(hammer, Rules.BODY, 1.0, 3) == 36, "a third hit in a row adds 20%")
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
	await _test_practice(game)
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


func _test_wind_solver() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 40:
		var wind := Rules.random_wind(rng)
		var facing := 1 if i % 2 == 0 else -1
		var gap := Rules.random_distance_px(rng)
		var origin := Vector2(-gap / 2 * facing, -92)
		var target := Vector2(gap / 2 * facing, -60)
		var shot := AiAimer.solve(origin, target, 1400.0, facing, 45.0, [], wind)
		var velocity := Rules.launch_velocity(shot["angle"], shot["power"], 1400.0, facing)
		# Step along the path and find the closest approach to the target.
		var best := INF
		var t := 0.0
		while t < 8.0:
			best = minf(best, Rules.position_at(origin, velocity, t, wind).distance_to(target))
			t += 1.0 / 600.0
		_check(best < 4.0, "throw %d lands on target in %.0f wind (off by %.1f px)" % [i, wind, best])


func _test_destructible_obstacles() -> void:
	var tower := Obstacle.new()
	tower.setup(&"tower", Rect2(-40, -300, 80, 300), 1)
	root.add_child(tower)
	var broke := {"count": 0}
	tower.destroyed.connect(func(_o: Obstacle) -> void: broke["count"] += 1)
	_check(not tower.damage(1) and not tower.damage(2), "a tower survives 3 damage")
	_check(tower.damage(1) and tower.is_destroyed and tower.collision_layer == 0, "the 4th point of damage breaks it and removes its collision")
	_check(broke["count"] == 1 and not tower.damage(5), "it breaks only once")


func _test_practice(game: Node) -> void:
	game.start_practice(game.roster()[4])
	await process_frame
	_check(game.mode == game.Mode.PRACTICE and game._practice_target != null, "practice starts with a target")
	_check(not game.fighters[1].visible, "practice has no visible opponent")
	game._practice_hit = true
	game._practice["stars"] += 3
	game._practice_next()
	_check(game._practice["index"] == 1 and game._practice["attempt"] == 0, "a hit moves practice to the next target")
	for i in 3:
		game._practice_next()
	_check(game._practice["index"] == 2, "three misses move practice on too")


func _test_progression(save: Node) -> void:
	var win := {"mode": 0, "won": true, "difficulty": 2, "headshots": 2}
	_check(Rewards.coins_for(win) == 50 + 50 + 10, "a Hard win with 2 headshots pays 110 coins")
	_check(Rewards.coins_for({"mode": 0, "won": false, "difficulty": 2}) == 10, "a loss still pays 10")
	_check(Rewards.coins_for({"mode": 1, "won": true}) == 0, "1v1 pays nothing")
	_check(Rewards.coins_for({"mode": 3, "practice_stars": 20}) == 60, "practice pays 3 coins a star")
	var earned := Rewards.new_achievements({"won": true, "headshots": 3, "damage_taken": 0, "max_combo": 1}, save, 8)
	_check(earned.has("first_win") and earned.has("headhunter") and earned.has("flawless") and not earned.has("combo"), "achievements match the match summary")
	save.achievements.append("first_win")
	_check(not Rewards.new_achievements({"won": true}, save, 8).has("first_win"), "an achievement is only earned once")

	var roster: Array[FighterData] = []
	for id: String in WEAPON_FIGHTERS:
		roster.append(load("res://data/fighters/%s.tres" % id))
	var maps: Array[MapData] = [load("res://data/maps/colosseum.tres"), load("res://data/maps/lava.tres")]
	var a := Rewards.daily("2026-10-19", roster, maps)
	var b := Rewards.daily("2026-10-19", roster, maps)
	_check(a["fighter"] == b["fighter"] and a["map"] == b["map"] and a["twist"] == b["twist"], "the daily challenge is the same all day")
	var summary := {"won": true, "fighter_id": String(a["fighter"].id), "headshots": 3, "special_used": false, "health_left": 90, "throws": 3}
	_check(Rewards.daily_met(a, summary), "winning as the daily fighter with every twist met completes it")

	var pipmo: FighterData = load("res://data/fighters/pipmo.tres")
	save.coins = 100
	_check(not save.is_unlocked(pipmo) and not save.buy_fighter(pipmo), "you can't buy a fighter you can't afford")
	save.coins = 300
	_check(save.buy_fighter(pipmo) and save.is_unlocked(pipmo) and save.coins == 50, "buying a fighter spends its price")
	_check(save.choose_cosmetic("ink", "black") and not save.choose_cosmetic("ink", "navy"), "owned inks equip; unaffordable ones don't")
	save.coins = 200
	_check(save.choose_cosmetic("trail", "gold") and save.trail == "gold" and save.coins == 120, "buying a trail equips it")
	save.reset_progress()
	_test_chests_and_levels(save)


func _test_chests_and_levels(save: Node) -> void:
	# Every fighter in the game, so each rarity has someone to roll.
	var roster: Array[FighterData] = []
	for file: String in DirAccess.get_files_at("res://data/fighters"):
		if file.ends_with(".tres"):
			roster.append(load("res://data/fighters/" + file))
	# Odds: count rarities over many seeded rolls of each chest.
	for kind: String in Chests.ORDER:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var counts := {}
		for rarity: StringName in Chests.RARITIES:
			counts[rarity] = 0
		for i in 4000:
			counts[Chests.roll(kind, roster, rng).rarity] += 1
		var odds: Array = Chests.KINDS[kind]["odds"]
		var close := true
		for r in Chests.RARITIES.size():
			close = close and absf(counts[Chests.RARITIES[r]] / 40.0 - float(odds[r])) < 3.0
		_check(close, "%s chest rolls rarities at its odds %s (got %s)" % [kind, odds, counts.values()])
	var repeat_a := RandomNumberGenerator.new()
	repeat_a.seed = 99
	var repeat_b := RandomNumberGenerator.new()
	repeat_b.seed = 99
	_check(Chests.roll("silver", roster, repeat_a) == Chests.roll("silver", roster, repeat_b), "a seeded chest roll is repeatable")

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	save.coins = 100
	_check(Chests.open("wood", roster, save, rng).is_empty() and save.coins == 100, "you can't open a chest you can't afford")
	save.coins = 5000
	var first := Chests.open("gold", roster, save, rng)
	var fighter: FighterData = first["fighter"]
	_check(first["new"] and save.is_unlocked(fighter) and save.coins == 4100, "a chest unlocks a new fighter and costs its price")
	# Own everything, so the next chest must be a duplicate: it levels the fighter up.
	for f in roster:
		if not save.is_unlocked(f):
			save.unlocked.append(String(f.id))
	var dupe := Chests.open("wood", roster, save, rng)
	var dupe_id := String((dupe["fighter"] as FighterData).id)
	_check(not dupe["new"] and dupe["level"] == 1 and save.fighter_level(dupe_id) == 1 and save.coins == 4100 - 150 + Chests.LEVEL_UP_COINS, "a duplicate levels the fighter up")
	for f in roster:
		save.fighter_levels[String(f.id)] = Chests.MAX_LEVEL
	var maxed := Chests.open("wood", roster, save, rng)
	_check(not maxed.is_empty() and maxed["coins"] == Chests.DUPLICATE_COINS[(maxed["fighter"] as FighterData).rarity], "a maxed fighter's duplicate turns into coins")
	_check(save.unlocked.size() == roster.size(), "duplicates don't add a fighter twice")
	for f in roster:
		var r := f.rarity
		if not Chests.RARITIES.has(r):
			_check(false, "%s has a known rarity" % f.id)
	_check(roster.any(func(f: FighterData) -> bool: return f.rarity == &"legendary"), "there is at least one legendary fighter")

	save.reset_progress()
	_check(save.level_info()["level"] == 1 and save.level_info()["into"] == 0, "you start at level 1 with no XP")
	var needed: int = save.level_info()["needed"]
	_check(save.add_xp(needed - 1) == 0 and save.level_info()["level"] == 1, "XP short of the bar doesn't level up")
	_check(save.add_xp(1) == 1 and save.level_info()["level"] == 2 and save.level_info()["into"] == 0, "filling the bar levels up")
	var two_levels: int = save.level_info()["needed"] + save.xp_for_level(3)
	_check(save.add_xp(two_levels) == 2 and save.level_info()["level"] == 4, "a big XP gain can level up more than once")
	_check(Rewards.xp_for({"mode": 0, "won": true, "difficulty": 2}) > Rewards.xp_for({"mode": 0, "won": false, "difficulty": 2}), "winning earns more XP than losing")
	_check(Rewards.xp_for({"mode": 1, "won": true}) == 0, "1v1 with a friend earns no XP")
	save.reset_progress()


func _test_anime_match() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	game.autoplay = true
	root.add_child(game)
	await process_frame
	var roster: Array = game.roster()
	var gok: FighterData = roster.filter(func(f: FighterData) -> bool: return f.id == &"gok")[0]
	var egita: FighterData = roster.filter(func(f: FighterData) -> bool: return f.id == &"egita")[0]
	var result := {}
	game.match_ended.connect(func(winner: Fighter) -> void: result["winner"] = winner)
	Engine.time_scale = 6.0
	game.start_match(gok, egita, game.Mode.VS_AI, AiAimer.Difficulty.HARD)
	# Fill both meters so the AI gets to use the beam and the orb.
	for frame in 9000:
		if not result.is_empty():
			break
		if frame % 200 == 0:
			game._charge[0] = 1.0
			game._charge[1] = 1.0
		await physics_frame
	Engine.time_scale = 1.0
	_check(not result.is_empty(), "a Gok vs Egita match ends in a knockout")
	_check(game._special_used[0] or game._special_used[1], "the AI used an anime special")
	game.queue_free()


## Phase J: every map has its own distance range and obstacle set, and every layout
## still leaves both fighters a clear throw.
func _test_map_variety() -> void:
	var ids := ["colosseum", "frozen", "lava", "pirate", "neon", "sky", "canyon", "bamboo", "graveyard"]
	var slowest: WeaponData = load("res://data/weapons/hammer.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var styles := {}
	for id: String in ids:
		var map: MapData = load("res://data/maps/%s.tres" % id)
		styles[map.obstacle_style] = true
		_check(map.min_distance_m >= 50.0 and map.max_distance_m <= 105.0 and map.min_distance_m < map.max_distance_m, "%s stands fighters a sensible distance apart" % id)
		var in_range := true
		for i in 20:
			var gap := Rules.random_distance_px(rng, map) / Rules.PX_PER_M
			in_range = in_range and gap >= map.min_distance_m and gap <= map.max_distance_m
		_check(in_range, "%s picks distances in its own range" % id)
		var all_clear := true
		var in_middle := true
		var kinds := {}
		for i in 15:
			var gap := Rules.random_distance_px(rng, map)
			var layout := ObstacleLayout.generate(rng, gap, slowest.max_speed, map.obstacle_patterns)
			var boxes := ObstacleLayout.rects(layout)
			for item in layout:
				kinds[item["kind"]] = true
			for box in boxes:
				in_middle = in_middle and box.position.x > -gap / 2 + 250 and box.end.x < gap / 2 - 250
			for facing: int in [1, -1]:
				var from := Vector2(-gap / 2 * facing + Fighter.HAND_REST.x * facing, Fighter.HAND_REST.y)
				var to := Vector2(gap / 2 * facing, 0) + Fighter.BODY_CENTER
				all_clear = all_clear and AiAimer.solve(from, to, slowest.max_speed, facing, 45.0, boxes)["clear"]
		_check(all_clear, "%s layouts always leave both fighters a clear throw" % id)
		_check(in_middle, "%s obstacles stay clear of both fighters" % id)
		for pattern: String in map.obstacle_patterns:
			_check(ObstacleLayout.PATTERNS.has(pattern), "%s uses a known pattern (%s)" % [id, pattern])
		if id in ["frozen", "pirate", "canyon", "bamboo", "graveyard"]:
			_check(kinds.has(&"spire"), "%s puts up its own spires" % id)
		if id == "sky":
			_check(kinds.keys() == [&"floating"], "Sky Islands only has floating islands")
	_check(styles.size() == ids.size(), "every map has its own obstacle style")
	var near: MapData = load("res://data/maps/bamboo.tres")
	var far: MapData = load("res://data/maps/sky.tres")
	_check(near.max_distance_m < far.min_distance_m, "some maps are close quarters, others far apart")
	_check(Obstacle.hit_points(&"ice", &"spire") == 2 and Obstacle.hit_points(&"sand", &"tower") == 5 and Obstacle.hit_points(&"stone", &"tower") == 4, "brittle and tough obstacle styles")

	# Draw every style and kind once so a broken drawing shows up here.
	var holder := Node2D.new()
	root.add_child(holder)
	for id: String in ids:
		var map: MapData = load("res://data/maps/%s.tres" % id)
		for kind: StringName in [&"tower", &"wall", &"floating", &"spire"]:
			var obstacle := Obstacle.new()
			var box := Rect2(0, -300, 60, 300) if kind == &"spire" else (Rect2(0, -300, 220, 70) if kind == &"floating" else Rect2(0, -200, 140, 200))
			obstacle.setup(kind, box, 7, map)
			holder.add_child(obstacle)
	await process_frame
	await process_frame
	_check(holder.get_child_count() == ids.size() * 4, "every obstacle style draws")
	holder.queue_free()


## Phase K: Lufi (Gum Barrage) against Ichi (Moon Fang) plays through to a knockout,
## with both specials going off.
func _test_straw_reaper_match() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	game.autoplay = true
	root.add_child(game)
	await process_frame
	var lufi: FighterData = load("res://data/fighters/lufi.tres")
	var ichi: FighterData = load("res://data/fighters/ichi.tres")
	_check(game.roster().has(lufi) and game.roster().has(ichi), "Lufi and Ichi are in the roster")
	_check(lufi.rarity == &"legendary" and ichi.rarity == &"legendary", "Lufi and Ichi are legendary chest finds")
	_check(game.is_straight_special(&"fang") and not game.is_straight_special(&"barrage"), "Moon Fang aims straight; Gum Barrage arcs")
	var result := {}
	var hits := {"barrage": 0, "fang": 0}
	game.match_ended.connect(func(winner: Fighter) -> void: result["winner"] = winner)
	Engine.time_scale = 6.0
	game.start_match(lufi, ichi, game.Mode.VS_AI, AiAimer.Difficulty.HARD, load("res://data/maps/frozen.tres"))
	for frame in 9000:
		if not result.is_empty():
			break
		# Arm each side's special the first time it lines up, so both always go off.
		if game.state == game.State.AI_AIM and not game._special_used[game.current]:
			game._charge[game.current] = 1.0
			game._special_armed = true
		for projectile: Projectile in game._in_flight:
			for kind: String in hits:
				if projectile.get_meta(kind, false):
					hits[kind] = maxi(hits[kind], 1)
		await physics_frame
	Engine.time_scale = 1.0
	_check(not result.is_empty(), "a Lufi vs Ichi match ends in a knockout")
	_check(hits["barrage"] > 0, "Lufi threw a Gum Barrage")
	_check(hits["fang"] > 0, "Ichi fired a Moon Fang")
	_check(not game._launching, "no special is left half-launched")
	game.queue_free()


## Gum Barrage fists bend into a nearby target (and only a nearby one), and the
## specials stay within sensible damage.
func _test_homing_and_balance() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for child in game._obstacle_layer.get_children():
		child.queue_free()
	var lufi: FighterData = load("res://data/fighters/lufi.tres")
	var target: Fighter = game._spawn_fighter(lufi, 400, -1, true)
	var thrower: Fighter = game._spawn_fighter(lufi, -2000, 1, true)
	var results := []
	for homing: bool in [true, false]:
		var fist := lufi.weapon.duplicate() as WeaponData
		fist.shape = &"fist"
		fist.spin = 0.0
		fist.gravity_scale = 0.0
		var projectile: Projectile = game.PROJECTILE_SCENE.instantiate()
		game._actors.add_child(projectile)
		# Just over their head, whatever height the (random) ground puts them at.
		projectile.launch(fist, thrower, Vector2(-200, target.position.y - 170.0), Vector2(900, 0))
		if homing:
			projectile.homing_target = target
			projectile.homing_range = game.BARRAGE_HOMING_RANGE
			projectile.homing_turn = game.BARRAGE_HOMING_TURN
		var hit := {"hit": false}
		projectile.hit_fighter.connect(func(_p: Projectile, who: Fighter, _part: StringName) -> void: hit["hit"] = who == target)
		for frame in 150:
			if not projectile.is_flying():
				break
			await physics_frame
		results.append(hit["hit"])
		if is_instance_valid(projectile):
			projectile.queue_free()
	_check(results[0], "a homing fist bends down into a target it flies just over")
	_check(not results[1], "the same fist without homing sails over")
	var full_barrage: int = game.BARRAGE_FISTS * roundi(lufi.weapon.body_damage * game.BARRAGE_MULTIPLIER)
	_check(full_barrage <= 60, "a full Gum Barrage body hit is at most 60 (%d)" % full_barrage)
	var gok: FighterData = load("res://data/fighters/gok.tres")
	_check(roundi(gok.weapon.head_damage * game.BEAM_MULTIPLIER) <= 60, "Mega Wave headshots are no longer near one-hit kills")
	game.queue_free()


## Target Practice lets you use your special: it starts charged, straight specials
## hit the target they are pointed at, and the round carries on afterwards.
func _test_practice_specials() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for id: String in ["gok", "ichi", "egita", "lufi", "uryo", "yuj", "megu", "goj", "ryo", "akum", "thundr", "capt", "spydr", "batz", "jotar", "dyo", "kazma", "subaro", "aizon"]:
		var pick: FighterData = load("res://data/fighters/%s.tres" % id)
		game.start_practice(pick)
		for frame in 300:
			if game.state == game.State.PLAYER_AIM:
				break
			await process_frame
		# Let the target finish popping in before aiming at it.
		for frame in 30:
			await process_frame
		_check(game._charge[0] >= 1.0 and game._hud._special_button.visible, "%s starts practice with the special ready" % id)
		game._on_special_toggled(true)
		var origin: Vector2 = game.fighters[0].throw_origin()
		var target: Vector2 = game._practice_target.global_position
		var angle := 0.0
		var power := 1.0
		if game.is_straight_special(pick.weapon.special):
			angle = game.beam_angle(origin, target, 1)
		else:
			var shot := AiAimer.solve(origin, target, pick.weapon.max_speed, 1, 40.0, [], 0.0, Rules.GRAVITY * pick.weapon.gravity_scale)
			angle = shot["angle"]
			power = shot["power"]
		var stars_before: int = game._practice["stars"]
		game._on_player_throw(angle, power)
		_check(game._special_used[0], "%s used the special in practice" % id)
		for frame in 900:
			if game.state == game.State.PLAYER_AIM:
				break
			await process_frame
		_check(game.state == game.State.PLAYER_AIM, "practice carries on after %s's special" % id)
		_check(not game._hud.time_stopped(), "time is moving again after %s's special in practice" % id)
		if game.is_straight_special(pick.weapon.special):
			_check(int(game._practice["stars"]) > stars_before, "%s's straight special hits the practice target" % id)
	game.queue_free()


## Fatalities: after a KO the winner gets a finishing throw. A hit plays the winner's
## fatality (and a tap skips it); a miss goes straight to the result.
func _test_fatalities() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	game.autoplay = true
	root.add_child(game)
	await process_frame
	var roster: Array = game.roster()
	# Loaded at runtime: the Fatality class uses autoloads, which this script cannot see.
	var fatality_script: GDScript = load("res://scripts/match/fatality.gd")
	var names: Dictionary = fatality_script.NAMES
	_check(roster.all(func(f: FighterData) -> bool: return names.has(f.id)), "every fighter has a fatality")
	for case: String in ["hit", "miss", "skip"]:
		game.start_match(roster[1], roster[0], game.Mode.VS_AI, 1, load("res://data/maps/colosseum.tres"))
		await process_frame
		game._match_id += 1
		var loser: Fighter = game.fighters[1]
		loser.take_hit(&"body", 100, Vector2(-300, 0))
		for k in 40:
			await physics_frame
		var ended := {"done": false}
		game.match_ended.connect(func(_w: Fighter) -> void: ended["done"] = true, CONNECT_ONE_SHOT)
		game._end_match()
		var saw_finisher := false
		var fatality: Node = null
		for k in 1200:
			await process_frame
			if game.state == game.State.FINISHER:
				saw_finisher = true
			if game.state == game.State.FLYING and not game._finisher.is_empty() and not game._finisher["done"]:
				game._resolve_finisher(case != "miss")
			for child in game._actors.get_children():
				if child.get_script() == fatality_script:
					fatality = child
			if case == "skip" and fatality != null and not fatality.is_done():
				var tap := InputEventMouseButton.new()
				tap.button_index = MOUSE_BUTTON_LEFT
				tap.pressed = true
				fatality._unhandled_input(tap)
			if ended["done"]:
				break
		_check(saw_finisher, "%s: the winner gets a finishing throw" % case)
		_check(ended["done"], "%s: the match ends after the finisher" % case)
		if case == "miss":
			_check(fatality == null and loser.visible, "a missed finisher plays no fatality")
		elif case == "hit":
			_check(fatality != null and fatality.is_done() and not loser.visible, "a hit finisher plays the fatality")
		else:
			_check(fatality != null and fatality.is_done(), "tapping skips the fatality")
	game.queue_free()


## Hilly ground: each fighter stands on a flat plateau, the valley between them is
## lower than both, and the ground never jumps.
func _test_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var all_good := true
	for i in 20:
		var half_gap := rng.randf_range(550.0, 1050.0)
		Terrain.build(rng, half_gap, rng.randf_range(0.3, 1.3))
		for side: float in [-1.0, 1.0]:
			var stand := Terrain.height_at(side * half_gap)
			all_good = all_good and is_equal_approx(Terrain.height_at(side * half_gap + 120.0), stand) and is_equal_approx(Terrain.height_at(side * half_gap - 120.0), stand)
		var valley := Terrain.height_at(0.0)
		all_good = all_good and valley > Terrain.height_at(-half_gap) and valley > Terrain.height_at(half_gap)
		var previous := Terrain.height_at(-Terrain.HALF_WIDTH)
		var x := -Terrain.HALF_WIDTH
		while x < Terrain.HALF_WIDTH:
			x += 10.0
			var now := Terrain.height_at(x)
			all_good = all_good and absf(now - previous) < 12.0
			previous = now
	_check(all_good, "fighters stand on flat plateaus above a smooth valley")
	Terrain.flat()
	_check(Terrain.height_at(123.0) == 0.0, "flat ground is at y = 0")


## The tournament boss is a shadow copy; it must still use the original's fatality.
func _test_shadow_boss() -> void:
	var controller: GDScript = load("res://scripts/match/match_controller.gd")
	var dyo: FighterData = load("res://data/fighters/dyo.tres")
	var shadow: FighterData = controller._shadow_of(dyo)
	_check(shadow.id == &"shadow_dyo", "the boss copy has its own id")
	_check(shadow.base_id() == &"dyo", "the boss copy finishes like the original")
	var saved := Terrain._heights.duplicate()
	var crater_before := Terrain.height_at(0.0)
	Terrain.crater(0.0, 100.0, 40.0)
	_check(Terrain.height_at(0.0) > crater_before, "a blast digs a crater")
	Terrain._heights = saved


## Target Practice can play your fatality on a dummy and then carry on.
func _test_practice_fatality() -> void:
	var game: Node = load("res://scenes/match/match.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_practice(load("res://data/fighters/aizon.tres"))
	for frame in 300:
		if game.state == game.State.PLAYER_AIM:
			break
		await process_frame
	_check(game._hud._fatality_button.visible, "practice shows the Test Fatality button")
	var stars_before: int = game._practice["stars"]
	game._test_fatality()
	_check(game.state != game.State.PLAYER_AIM, "the fatality test takes over from aiming")
	Engine.time_scale = 4.0
	for frame in 3000:
		if game.state == game.State.PLAYER_AIM:
			break
		await process_frame
	Engine.time_scale = 1.0
	_check(game.state == game.State.PLAYER_AIM, "practice carries on after a fatality test")
	_check(game._practice["stars"] == stars_before and game._practice_target != null and game._practice_target.visible, "the practice run is just as it was")
	game.queue_free()
	await process_frame
