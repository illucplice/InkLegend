class_name MatchController
extends Node2D
## Runs the game: the title screen backdrop, then matches. Sets up the arena,
## fighters and obstacles, hands turns between players (or a player and the AI),
## spawns projectiles, applies damage and ends the match on a knockout.

signal match_ended(winner: Fighter)
## The finishing throw after a knockout has hit or missed (see _finisher_throw).
signal finisher_resolved

enum State { MENU, PLAYER_AIM, AI_AIM, FLYING, SETTLING, GAME_OVER, FINISHER }
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
	preload("res://data/fighters/uryo.tres"),
	preload("res://data/fighters/yuj.tres"),
	preload("res://data/fighters/megu.tres"),
	preload("res://data/fighters/goj.tres"),
	preload("res://data/fighters/ryo.tres"),
	preload("res://data/fighters/akum.tres"),
	preload("res://data/fighters/thundr.tres"),
	preload("res://data/fighters/capt.tres"),
	preload("res://data/fighters/spydr.tres"),
	preload("res://data/fighters/batz.tres"),
	preload("res://data/fighters/jotar.tres"),
	preload("res://data/fighters/dyo.tres"),
	preload("res://data/fighters/kazma.tres"),
	preload("res://data/fighters/subaro.tres"),
	preload("res://data/fighters/aizon.tres"),
	preload("res://data/fighters/frierin.tres"),
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
## Seconds the dazed loser stands there before the winner can throw the finisher.
const FINISHER_DELAY := 1.0
## 1v1 turns time out after this many seconds.
const TURN_TIME := 12.0
const LAST_STAND_HEALTH := 20
## Longest a turn waits for ragdolls to settle, in seconds.
const MAX_SETTLE_WAIT := 3.0
## Chance a crate appears at the start of a turn (when none is waiting).
const CRATE_CHANCE := 0.4
## Every HAZARD_EVERY turns the map throws something down: a boulder, an icicle, a
## lava bomb or a lightning strike. A red ring on the ground warns where.
const HAZARD_EVERY := 5
const HAZARD_RADIUS := 90.0
const HAZARD_DAMAGE := 12
## Seconds a floating slab takes to drift to its new spot.
const DRIFT_TIME := 0.8
## Target Practice: number of targets and tries per target (stars = tries left + 1).
const PRACTICE_TARGETS := 10
const PRACTICE_TRIES := 3
## Target Practice: how much of the special meter each target hit fills.
const PRACTICE_CHARGE := 0.5
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
const BARRAGE_FISTS := 3
const BARRAGE_GAP := 0.09
const BARRAGE_SPREAD := 3.0
const BARRAGE_MULTIPLIER := 0.4
const BARRAGE_HOMING_RANGE := 220.0
const BARRAGE_HOMING_TURN := 3.0
## Moon Fang: speed, size and damage multiplier of the crescent.
const FANG_SPEED := 1500.0
const FANG_SIZE := 70.0
const FANG_MULTIPLIER := 1.7
## Damage multipliers for the newer fighters' specials (Licht Regen is per arrow).
const SPECIAL_MULTIPLIERS := {"purple": 1.7, "fuga": 1.8, "gou": 1.7, "shinku": 1.6, "rain": 0.35, "dogs": 0.6, "thunder": 1.5, "ricochet": 1.3, "webyank": 1.4, "batbomb": 0.6, "knifestorm": 0.22, "elephant": 1.5, "voll": 1.35, "icefall": 1.0, "zoltraak": 0.4}
## Licht Regen: arrows in the storm, and how far either side of the target they fall.
## Fuga's burn: turns on fire and damage at the start of each.
## Per fighter level (from duplicates): extra damage and faster special meter.
const LEVEL_DAMAGE := 0.04
const LEVEL_CHARGE := 0.06
## God of Thunder's lightning blast and the Explosive Batarangs' blasts (px).
const THUNDER_RADIUS := 170.0
const BATBOMB_RADIUS := 110.0
const BURN_TURNS := 3
const BURN_DAMAGE := 6
const BLEED_TURNS := 3
const BLEED_DAMAGE := 3
## How often a knife or Iggi bite makes them bleed.
const BLEED_CHANCE := 0.35
## Egita's homing ki, and the burst of Gok's ki blasts.
const KI_HOMING_RANGE := 180.0
const KI_HOMING_TURN := 2.4
const KI_BURST_RADIUS := 90.0
const RAIN_ARROWS := 6
const RAIN_SPREAD := 80.0
## Hollow Purple: blast radius, and how close (px) and fast (px/s at point blank) it drags the enemy.
const PURPLE_RADIUS := 240.0
const PURPLE_PULL_RANGE := 600.0
const PURPLE_PULL_SPEED := 420.0
## Blue (Goj's basic throw): a smaller, gentler pull.
const BLUE_PULL_RANGE := 420.0
const BLUE_PULL_SPEED := 300.0
## Divine Dogs: how fast the wolves run, px/s.
const DOG_SPEED := 1100.0
## The headshot cam can trigger once a throw is this close (px) to a head.
const CINEMATIC_RANGE := 260.0
## Wind strength per AI difficulty; 1v1 uses LOCAL_WIND.
const DIFFICULTY_WIND := [0.0, 0.6, 1.0, 1.0]
const LOCAL_WIND := 0.8
## Throw sound per projectile shape: [sound, pitch].
const THROW_SOUNDS := {
	&"hammer": ["whoosh", 0.75],
	&"pebble": ["sling", 1.0],
	&"iggi": ["whoosh", 1.2],
	&"knife": ["whoosh", 1.4],
	&"minya": ["zap", 1.4],
	&"byakurai": ["zap", 1.8],
	&"dark_hado": ["zap", 0.9],
	&"zoltraak": ["zap", 1.3],
	&"mana_orb": ["zap", 1.5],
	&"reiatsu": ["whoosh", 0.7],
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
## The finishing throw in progress: loser, projectiles in flight, hit, done.
var _finisher := {}
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
## The current throw is a special: a knockout from it goes straight to the fatality.
var _special_this_turn := false
## Kyoka Suigetsu turned a throw back on its thrower and knocked them out.
var _mirror_ko := false
## Aqwa's blessing: lucky throws left for each side (they find the enemy wherever aimed).
var _lucky := [0, 0]
var _empowered := [0, 0]
## The icefall target while it sweeps (empty when not in use).
var _icefall := {}
## Aizon and the enemy while Kyoka Suigetsu has them in each other's places.
var _swapped: Array = []
## Frierin's Mana Analysis: she missed last turn, so this turn shows her whole aim line.
var _analysis := [0, 0]
## Frierin's orb in flight, waiting to drop its beam; the AI's timing slack; and
## whether Mana Analysis shows a drop guide for this throw.
var _drop_orb: Projectile
var _drop_ai_offset := 0.0
var _drop_guide := false
const LUCKY_THROWS := 2

## Subaro's Emilla icefall: the target circle's size, sweep speed, and how long you get.
const ICEFALL_RADIUS := 85.0
const ICEFALL_SPEED := 650.0
const ICEFALL_TIME := 6.0
const ICEFALL_DROPS := 3
const ZOLTRAAK_CIRCLES := 7
## Frierin's dropped Zoltraak beam: body and head damage.
const ZOLTRAAK_BEAM_DAMAGE := [22, 38]
## With Mana Release, the beam bursts over this radius.
const ZOLTRAAK_BURST_RADIUS := 110.0
## The volley: how high she flies, and each sphere's little burst.
const ZOLTRAAK_SKY := 320.0
const ZOLTRAAK_VOLLEY_BURST := 55.0
## Uryo's Vollstandig: empowered throws, the heal, and how hard the arrows hit.
const VOLL_THROWS := 3
const VOLL_HEAL := 15
const VOLL_RADIUS := 90.0
const ELEPHANT_RADIUS := 150.0
## Specials that happen as soon as they're used instead of riding on a throw.
const INSTANT_SPECIALS := [&"vollstandig", &"blessing", &"illusion", &"timestop"]
## How close an enemy throw gets to Aizon before Kyoka Suigetsu swaps them.
const ILLUSION_TRIGGER := 160.0
## Aizon gets this much health back each time Kyoka Suigetsu fools someone.
const KYOKA_HEAL := 5
## Aizon's Reiatsu: two hits in a row put them under pressure, and his next hit does
## this much more damage.
const PRESSURE_HITS := 2
const PRESSURE_BONUS := 1.3
## Aizon evolves once, the first time he drops to EVOLVE_HEALTH, and hits harder after.
const EVOLVE_HEALTH := 50
const EVOLVED_DAMAGE := 1.5
## Evolved Aizon takes this share of every enemy hit.
const EVOLVED_DEFENCE := 0.8
## Frierin stops hiding her mana at this much health, and her passives switch on.
const MANA_RELEASE_HEALTH := 50
## In Mana Release she takes this share of every enemy hit (her barrier stops the rest).
const MANA_BARRIER := 0.75
## Mana Analysis: each miss lengthens her aim guide one step, up to full.
const ANALYSIS_STEPS := 4
## Who stands in for the enemy when you test a fatality in Target Practice.
const FATALITY_DUMMY := preload("res://data/fighters/quotuk.tres")
## Jotar's time stop: throws left before time moves again.
var _time_stop_left := 0
## Who stopped time, the throws hanging short of the enemy, and their hit marks.
var _stopper: Fighter
var _held: Array[Projectile] = []
var _marks: Array[Node2D] = []
const TIME_STOP_THROWS := 2
const KNIFE_STORM := 7
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
	_hud.fatality_test_requested.connect(_test_fatality)
	go_to_menu()


## Clears any match and shows the title screen over the arena.
func go_to_menu() -> void:
	_clear_match()
	get_tree().paused = false
	state = State.MENU
	tournament = {}
	_arena.set_spread(MENU_GAP / 2)
	Terrain.build(rng, MENU_GAP / 2, 0.6 * (current_map.terrain_roughness if current_map != null else 1.0), false)
	_arena.refresh_terrain()
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
	_set_map(map if map != null else MAPS[rng.randi_range(0, MAPS.size() - 1)])
	Audio.play_music(_music_for(current_map))
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
	Terrain.build(rng, gap / 2, current_map.terrain_roughness)
	_arena.refresh_terrain()
	_build_obstacles(gap, minf(left.weapon.max_speed, right.weapon.max_speed))
	var vs_ai := mode != Mode.LOCAL_2P
	fighters.append(_spawn_fighter(left, -gap / 2, 1, vs_ai and autoplay))
	fighters.append(_spawn_fighter(right, gap / 2, -1, vs_ai))
	_brains = [AiAimer.new(difficulty) if autoplay else null, AiAimer.new(difficulty) if vs_ai else null]

	_wind_strength = LOCAL_WIND if mode == Mode.LOCAL_2P else float(DIFFICULTY_WIND[difficulty])
	_special_used = [false, false]
	_lucky = [0, 0]
	_empowered = [0, 0]
	_swapped = []
	_analysis = [0, 0]
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
		_say(fighters[0], Taunts.intro_line(left.base_id(), rng), 1.3)
		await get_tree().create_timer(1.2, false).timeout
		if match_id != _match_id:
			return
		_say(fighters[1], Taunts.intro_line(right.base_id(), rng), 1.3)
		await get_tree().create_timer(1.3, false).timeout
		if match_id != _match_id:
			return
	_begin_turn()



## A speech bubble over a fighter's head for a moment.
func _say(fighter: Fighter, text: String, seconds: float = 1.6) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	var font := ThemeDB.fallback_font
	var size := 26
	var bubble := Node2D.new()
	bubble.z_index = 30
	bubble.draw.connect(func() -> void:
		var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var box := Rect2(Vector2(-extent.x / 2 - 14, -extent.y - 14), extent + Vector2(28, 20))
		bubble.draw_colored_polygon(PackedVector2Array([Vector2(-10, box.end.y - 2), Vector2(10, box.end.y - 2), Vector2(-14 * fighter.facing, box.end.y + 18)]), Color.WHITE)
		bubble.draw_style_box(UiStyle.flat(Color.WHITE, 14), box)
		bubble.draw_string(font, Vector2(-extent.x / 2, -12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.08, 0.12)))
	_actors.add_child(bubble)
	var follow := func() -> void:
		if is_instance_valid(fighter) and is_instance_valid(bubble):
			bubble.global_position = fighter.aim_point(true) + Vector2(0, -60)
			bubble.scale = Vector2.ONE / _camera.zoom.x
	follow.call()
	get_tree().process_frame.connect(follow)
	var pop := bubble.create_tween()
	pop.tween_interval(seconds)
	pop.tween_property(bubble, "modulate:a", 0.0, 0.25)
	pop.tween_callback(func() -> void:
		get_tree().process_frame.disconnect(follow)
		bubble.queue_free())

static func _empty_stats() -> Dictionary:
	return {"throws": 0, "hits": 0, "headshots": 0, "damage": 0, "longest": 0.0}


func _clear_match() -> void:
	_match_id += 1
	_drop_orb = null
	_mirror_ko = false
	if not _icefall.is_empty() and is_instance_valid(_icefall.get("marker")):
		(_icefall["marker"] as Node2D).queue_free()
	_icefall = {}
	_lucky = [0, 0]
	_empowered = [0, 0]
	_hud.hide_tip()
	_clear_time_stop()
	_launching = false
	_finisher = {}
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
	amount *= 1.0 + LEVEL_CHARGE * _level_of(fighters[side])
	var was_full := _charge[side] >= 1.0
	_charge[side] = minf(1.0, _charge[side] + amount)
	fighters[side].charge = _charge[side]
	if not was_full and _charge[side] >= 1.0:
		Audio.play("special_ready", 0.0, 1.0, 0.0)
		Audio.play("voice_charge", -6.0, fighters[side].voice_pitch(), 0.0)
	if not was_full and _charge[side] >= 1.0 and not fighters[side].is_ai:
		_hud.announce("%s: SPECIAL READY!" % fighters[side].data.short_name.to_upper(), fighters[side].data.body_color.lightened(0.35))
		if Save.tutorial_step == 2 and mode != Mode.PRACTICE and not autoplay:
			Save.tutorial_step = 3
			Save.save_progress()
			_hud.show_tip("Your SPECIAL is ready! Tap the special button, then throw to unleash it.")


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
	target.create_tween().tween_property(target, "position", Vector2(x, Terrain.height_at(x)), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Bomb: everyone in the blast takes damage (less toward the edge) and is thrown
## outward; obstacles in it are chipped.
func _on_projectile_exploded(projectile: Projectile, at: Vector2, direct: Fighter, part: StringName, collider: Object) -> void:
	if _special_finisher():
		Effects.burst(_actors, at, Color(1.0, 0.6, 0.2), 40, 700.0, 180.0, 1.8)
		if direct == _finisher["loser"] or (_finisher["loser"] as Fighter).aim_point(false).distance_to(at) < projectile.explode_radius + 30.0:
			_resolve_finisher(true)
		return
	var radius := projectile.explode_radius
	if projectile.get_meta("thunder", false):
		_lightning(at)
	if projectile.get_meta("elephant", false):
		_elephant_drop(at)
	var violet: bool = projectile.get_meta("zoltraak", false) or projectile.get_meta("zoltraak_drop", false) or projectile.weapon.shape in [&"reiatsu", &"dark_hado"]
	if violet:
		Effects.burst(_actors, at, Color(0.75, 0.6, 1.0), 26, 500.0, 180.0, 1.2)
		Effects.burst(_actors, at, Color.WHITE, 10, 260.0, 180.0, 0.9)
	elif projectile.get_meta("icefall", false):
		Effects.burst(_actors, at, Color(0.8, 0.94, 1.0), 60, 800.0, 180.0, 1.8)
		Effects.burst(_actors, at, Color.WHITE, 26, 400.0, 180.0, 1.4)
		Effects.popup(_actors, at + Vector2(0, -50), "SHATTER!", Color(0.7, 0.9, 1.0), 48, 1.0 / _camera.zoom.x, _camera.visible_rect())
	else:
		Effects.burst(_actors, at, Color(1.0, 0.6, 0.2), 40, 700.0, 180.0, 1.8)
		Effects.burst(_actors, at, Color(0.15, 0.12, 0.14, 0.9), 26, 320.0, 180.0, 2.2)
		Effects.popup(_actors, at + Vector2(0, -50), "BOOM!", Color(1.0, 0.6, 0.25), 48, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Audio.play("zap" if violet else "boom", -4.0 if violet else 0.0, 1.0, 0.1)
	Audio.play("ground", 2.0, 0.45, 0.0)
	Device.vibrate(90)
	Audio.play("hit_body", -2.0, 0.6, 0.0)
	_camera.shake(0.9)
	for fighter in fighters:
		# A throw Kyoka Suigetsu turned around blasts its own thrower and spares Aizon.
		var spared: Fighter = projectile.get_meta("mirror_of", projectile.thrower)
		if fighter == spared or fighter.is_knocked_out():
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
	if not violet:
		_blast_crater(at, radius)




## Explosions near the ground blow a crater out of it; anyone standing in it drops in.
func _blast_crater(at: Vector2, radius: float) -> void:
	var ground := Terrain.height_at(at.x)
	if at.y < ground - radius * 0.6:
		return
	var width := clampf(radius * 0.9, 60.0, 160.0)
	Terrain.crater(at.x, width, clampf(radius * 0.3, 20.0, 50.0))
	_arena.refresh_terrain()
	Effects.burst(_actors, Vector2(at.x, ground), _current_dirt(), 30, 600.0, 120.0, 1.6)
	for fighter in fighters:
		var floor_y := Terrain.height_at(fighter.position.x)
		if floor_y > fighter.position.y + 1.0:
			fighter.create_tween().tween_property(fighter, "position:y", floor_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The colour of earth thrown up by a blast.
func _current_dirt() -> Color:
	return current_map.ground_top.darkened(0.2) if current_map != null else Color(0.6, 0.5, 0.35)


## The map's hazard: a red warning ring, then something falls from the sky onto it.
func _drop_hazard() -> void:
	var kind := &"rock"
	match current_map.id if current_map != null else &"":
		&"frozen":
			kind = &"icicle"
		&"lava":
			kind = &"lava"
		&"sky", &"neon":
			kind = &"lightning"
		&"pirate":
			kind = &"cannonball"
	var x: float
	if rng.randf() < 0.35:
		x = fighters[rng.randi() % 2].position.x + rng.randf_range(-60.0, 60.0)
	else:
		x = rng.randf_range(fighters[0].position.x, fighters[1].position.x)
	var ground := Vector2(x, Terrain.height_at(x))
	_hud.announce({&"icicle": "ICICLE!", &"lava": "LAVA BOMB!", &"lightning": "LIGHTNING!", &"cannonball": "CANNON FIRE!"}.get(kind, "ROCKFALL!"), Color(1.0, 0.45, 0.3))
	var warning := Node2D.new()
	warning.z_index = 5
	warning.position = ground
	warning.draw.connect(func() -> void:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
		warning.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		warning.draw_arc(Vector2.ZERO, HAZARD_RADIUS, 0.0, TAU, 32, Color(1.0, 0.2, 0.15, pulse), 6.0, true)
		warning.draw_circle(Vector2.ZERO, HAZARD_RADIUS, Color(1.0, 0.2, 0.15, 0.15 * pulse), true, -1.0, true))
	_actors.add_child(warning)
	get_tree().process_frame.connect(warning.queue_redraw)
	Audio.play("turn", 0.0, 0.6, 0.0)
	var id := _match_id
	await get_tree().create_timer(1.0, false).timeout
	if id != _match_id:
		return
	warning.queue_free()
	if kind == &"lightning":
		_lightning(ground)
	else:
		var falling := Node2D.new()
		falling.z_index = 20
		falling.draw.connect(func() -> void:
			match kind:
				&"icicle":
					falling.draw_colored_polygon(PackedVector2Array([Vector2(-18, -70), Vector2(18, -70), Vector2(0, 30)]), Color(0.8, 0.92, 1.0))
					falling.draw_polyline(PackedVector2Array([Vector2(-18, -70), Vector2(0, 30), Vector2(18, -70), Vector2(-18, -70)]), Color(0.3, 0.45, 0.6), 3.0, true)
				&"lava":
					falling.draw_circle(Vector2.ZERO, 36.0, Color(1.0, 0.5, 0.1, 0.35), true, -1.0, true)
					falling.draw_circle(Vector2.ZERO, 24.0, Color(0.25, 0.1, 0.08), true, -1.0, true)
					falling.draw_circle(Vector2(-6, -6), 10.0, Color(1.0, 0.65, 0.2), true, -1.0, true)
				&"cannonball":
					falling.draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.12, 0.14), true, -1.0, true)
					falling.draw_circle(Vector2(-7, -7), 6.0, Color(0.4, 0.4, 0.45), true, -1.0, true)
				_:
					falling.draw_colored_polygon(PackedVector2Array([Vector2(-30, -10), Vector2(-14, -30), Vector2(16, -28), Vector2(32, -4), Vector2(20, 24), Vector2(-20, 26)]), Color(0.55, 0.45, 0.38))
					falling.draw_polyline(PackedVector2Array([Vector2(-30, -10), Vector2(-14, -30), Vector2(16, -28), Vector2(32, -4), Vector2(20, 24), Vector2(-20, 26), Vector2(-30, -10)]), Color(0.2, 0.15, 0.12), 3.0, true)
			falling.draw_set_transform(Vector2.ZERO))
		falling.position = ground + Vector2(rng.randf_range(-200.0, 200.0), -1400.0)
		_actors.add_child(falling)
		Audio.play("whoosh", 0.0, 0.5, 0.0)
		var fall := falling.create_tween()
		fall.tween_property(falling, "position", ground + Vector2(0, -20), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fall.finished
		if id != _match_id:
			return
		falling.queue_free()
		Effects.burst(_actors, ground, Color(1.0, 0.55, 0.2) if kind == &"lava" else Color(0.85, 0.92, 1.0) if kind == &"icicle" else _current_dirt(), 40, 700.0, 120.0, 1.8)
		Audio.play("ground", 3.0, 0.5, 0.0)
		_camera.shake(0.8)
	for fighter in fighters:
		if fighter.is_knocked_out() or fighter.aim_point(false).distance_to(ground) > HAZARD_RADIUS + 50.0:
			continue
		fighter.take_hit(Rules.BODY, HAZARD_DAMAGE, Vector2(signf(fighter.position.x - x) * 500.0, -400.0))
		Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -70), "-%d" % HAZARD_DAMAGE, Color(1.0, 0.45, 0.3), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
		if kind == &"lava":
			fighter.burn_turns = maxi(fighter.burn_turns, 1)
	for child in _obstacle_layer.get_children():
		var obstacle := child as Obstacle
		if obstacle != null and not obstacle.is_destroyed and obstacle.rect.grow(HAZARD_RADIUS).has_point(ground):
			obstacle.damage(2)
	_blast_crater(ground, HAZARD_RADIUS * 1.2)
	await get_tree().create_timer(0.6, false).timeout


## Each map's battle music.
static func _music_for(map: MapData) -> String:
	match map.id if map != null else &"":
		&"bamboo":
			return "battle_east"
		&"graveyard", &"lava":
			return "battle_dark"
		&"frozen", &"sky":
			return "battle_bright"
	return "battle"


## A hit sounds like what hit: metal clangs, energy zaps, blades slice, soft things splat.
static func _impact_sound(weapon: WeaponData) -> void:
	if weapon == null:
		return
	match weapon.shape:
		&"hammer", &"mjolnir", &"star_shield", &"iron_ball", &"axe", &"cleaver", &"batarang":
			Audio.play("clang", -6.0, 1.0, 0.08)
		&"ki", &"blue_orb", &"hadoken", &"quincy", &"nue", &"fire_arrow", &"gou_fireball":
			Audio.play("zap", -6.0, 1.0, 0.08)
		&"meat", &"web_ball", &"plunger":
			Audio.play("splat", -6.0, 1.0, 0.08)
		&"arrow", &"spear":
			Audio.play("slice", -8.0, 1.2, 0.08)


## First-match coaching: how to aim on the first turn, then wind and headshots.
func _tutorial_tip() -> void:
	if mode == Mode.PRACTICE or autoplay or Save.tutorial_step >= 2:
		return
	if Save.tutorial_step == 0:
		_hud.show_tip("Drag back from anywhere to aim. Pull further for more power, then let go to throw!")
	else:
		_hud.show_tip("Watch the WIND at the top: it pushes your throw. Hit the head for big damage!")
	Save.tutorial_step += 1
	Save.save_progress()


## Time stops: the world drains to grey-violet with a shockwave from the fighter.
func _stop_time(fighter: Fighter) -> void:
	_hud.set_time_stop(true, fighter.data.style != &"vampire")
	_hud.announce("TIME STOP!", Color(0.85, 0.75, 1.0))
	Audio.play("zap", 0.0, 0.4, 0.0)
	Audio.play("ko", -6.0, 0.5, 0.0)
	_camera.shake(0.5)
	var ring := Node2D.new()
	ring.z_index = 25
	ring.position = fighter.aim_point(false)
	var size := {"r": 10.0}
	ring.draw.connect(func() -> void:
		ring.draw_arc(Vector2.ZERO, size["r"], 0.0, TAU, 64, Color(0.85, 0.75, 1.0, 0.8), 14.0, true)
		ring.draw_circle(Vector2.ZERO, size["r"], Color(0.6, 0.45, 0.9, 0.15), true, -1.0, true))
	_actors.add_child(ring)
	var grow := ring.create_tween()
	grow.tween_method(func(r: float) -> void:
		size["r"] = r
		ring.queue_redraw(), 10.0, 2600.0, 0.7).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.7)
	grow.tween_callback(ring.queue_free)


## Time moves again.
func _resume_time() -> void:
	_hud.set_time_stop(false)
	_hud.announce("TIME RESUMES", Color(0.9, 0.9, 1.0))
	Audio.play("whoosh", 0.0, 0.6, 0.0)


## Dyo's special: stops time and throws a fan of knives. Each one stops dead just
## before it would hit and hangs there; when time moves again they all strike at once.
func _knife_storm(fighter: Fighter, angle: float, power: float) -> void:
	var weapon := fighter.data.weapon
	var id := _match_id
	_stopper = fighter
	if not _hud.time_stopped():
		_stop_time(fighter)
	_launching = true
	for i in KNIFE_STORM:
		fighter.play_throw()
		Audio.play("whoosh", -6.0, 1.4, 0.1)
		var offset := (i - (KNIFE_STORM - 1) / 2.0) * 2.0
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(weapon, fighter, fighter.throw_origin(), Rules.launch_velocity(angle + offset, power * rng.randf_range(0.97, 1.03), weapon.max_speed, fighter.facing), _wind_for(fighter))
		projectile.target = fighters[1 - current]
		projectile.set_meta("knifestorm", true)
		projectile.stop_short = true
		projectile.stopped_short.connect(_on_stopped_short)
		_track(projectile)
		await get_tree().create_timer(0.06, false).timeout
		if id != _match_id:
			return
	_launching = false
	if _in_flight.is_empty() and state == State.FLYING:
		_after_throw()



## Time stop: a throw stopped just short of the enemy. It hangs there with a mark on
## the spot it will hit, and counts as landed so the next stopped-time throw can go.
func _on_stopped_short(projectile: Projectile, at: Vector2) -> void:
	_in_flight.erase(projectile)
	_held.append(projectile)
	Audio.play("tick", 0.0, 0.7, 0.0)
	var mark := Node2D.new()
	mark.z_index = 26
	mark.position = at
	mark.draw.connect(func() -> void:
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		var red := Color(1.0, 0.2, 0.25, pulse)
		mark.draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, red, 3.0, true)
		mark.draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 12, red, 2.0, true)
		for k in 4:
			var dir := Vector2.from_angle(k * PI / 2.0)
			mark.draw_line(dir * 10.0, dir * 24.0, red, 3.0, true))
	_actors.add_child(mark)
	get_tree().process_frame.connect(mark.queue_redraw)
	_marks.append(mark)
	if _in_flight.is_empty() and not _launching and state == State.FLYING:
		_after_throw()


## Time moves again: every held throw carries on and hits, then the turn passes.
func _release_held() -> void:
	_special_this_turn = true
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	state = State.FLYING
	var held := _held.duplicate()
	_held.clear()
	# Kyoka Suigetsu waited out the stopped time: now they trade places, and every
	# throw hanging in front of Aizon finds its own thrower.
	for fighter in fighters:
		if not fighter.illusion or fighter.is_knocked_out():
			continue
		var incoming := held.filter(func(p: Projectile) -> bool: return is_instance_valid(p) and p.thrower != null and p.thrower != fighter)
		if incoming.is_empty():
			continue
		_swap_places(fighter, incoming[0].thrower, incoming[0])
		for projectile: Projectile in incoming.slice(1):
			_turn_on_thrower(projectile, fighter, projectile.thrower)
	for projectile: Projectile in held:
		if not is_instance_valid(projectile):
			continue
		projectile.stop_short = false
		projectile.frozen = false
		_in_flight.append(projectile)
	if _in_flight.is_empty():
		_after_throw()


## Clears time stop when a match is torn down.
func _clear_time_stop() -> void:
	_time_stop_left = 0
	_stopper = null
	_held.clear()
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	_hud.set_time_stop(false)


## Gok's ki blasts burst where they land: a flash, a ring of light and sparks.
func _ki_burst(projectile: Projectile) -> void:
	if projectile.weapon == null or projectile.weapon.id != &"ki_blast":
		return
	var at := projectile.global_position
	var glow := projectile.weapon.color.lightened(0.3)
	Effects.burst(_actors, at, glow, 34, 620.0, 180.0, 1.5)
	Effects.burst(_actors, at, Color.WHITE, 14, 300.0, 180.0, 1.0)
	var ring := Node2D.new()
	ring.z_index = 20
	ring.position = at
	var size := {"r": 8.0}
	ring.draw.connect(func() -> void:
		ring.draw_circle(Vector2.ZERO, size["r"] * 0.6, Color(1.0, 1.0, 1.0, 0.5), true, -1.0, true)
		ring.draw_arc(Vector2.ZERO, size["r"], 0.0, TAU, 32, glow, 8.0, true))
	_actors.add_child(ring)
	var grow := ring.create_tween()
	grow.tween_method(func(r: float) -> void:
		size["r"] = r
		ring.queue_redraw(), 8.0, KI_BURST_RADIUS, 0.25).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	grow.tween_callback(ring.queue_free)
	Audio.play("zap", -4.0, 0.9, 0.08)
	_camera.shake(0.25)


## Kazma's special: Lalatna throws a shield over him, and Aqwa's blessing makes this
## throw and the next lucky.
func _bless(fighter: Fighter) -> void:
	fighter.shielded = true
	_lucky[current] = LUCKY_THROWS
	_party_cameo(fighter)
	_hud.announce("LALATNA'S GUARD + AQWA'S BLESSING!", Color(0.6, 0.85, 1.0))
	Effects.burst(_actors, fighter.aim_point(false), Color(0.6, 0.85, 1.0), 30, 500.0, 180.0, 1.4)
	Effects.burst(_actors, fighter.aim_point(true) + Vector2(0, -40), Color(1.0, 0.9, 0.45), 24, 300.0, 180.0, 1.6)
	Audio.play("win", -6.0, 1.4, 0.0)


## A lucky throw: it slips past every obstacle (its path was already set straight into
## the enemy by _lucky_shot). Kazma's arrows hit softer to make up for it.
func _make_lucky(projectile: Projectile) -> void:
	projectile.pierce = true
	projectile.set_trail_color(Color(1.0, 0.88, 0.35))
	projectile.set_meta("lucky", true)
	Effects.popup(_actors, fighters[current].aim_point(true) + Vector2(0, -70), "LUCKY!", Color(1.0, 0.88, 0.35), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())


## Kyoka Suigetsu breaks: Aizon's image shatters like glass.
func _shatter_illusion(fighter: Fighter) -> void:
	fighter.illusion = false
	fighter.heal(KYOKA_HEAL)
	Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -110), "+%d" % KYOKA_HEAL, Color(0.5, 1.0, 0.6), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
	_hud.announce("KYOKA SUIGETSU!", Color(0.75, 0.55, 1.0))
	Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -70), "AN ILLUSION!", Color(0.85, 0.75, 1.0), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Effects.burst(_actors, fighter.aim_point(false), Color(0.9, 0.95, 1.0), 40, 600.0, 180.0, 1.4)
	Effects.burst(_actors, fighter.aim_point(false), Color(0.6, 0.35, 0.95), 20, 400.0, 180.0, 1.2)
	Audio.play("clang", 0.0, 1.6, 0.0)


## Max Elephant: the shikigami drops out of the sky where Megu's throw landed and
## crashes down in a burst of water.
func _elephant_drop(at: Vector2) -> void:
	var ground := Terrain.height_at(at.x)
	var beast := Node2D.new()
	beast.z_index = 20
	beast.draw.connect(func() -> void:
		var body := Color(0.86, 0.86, 0.9)
		var ink := Color(0.08, 0.07, 0.1)
		for leg: float in [-70.0, -30.0, 30.0, 70.0]:
			beast.draw_rect(Rect2(leg - 16.0, -70.0, 32.0, 70.0), ink)
			beast.draw_rect(Rect2(leg - 12.0, -70.0, 24.0, 66.0), body.darkened(0.08))
		beast.draw_set_transform(Vector2(0, -120), 0.0, Vector2(1.0, 0.68))
		beast.draw_circle(Vector2.ZERO, 112.0, ink, true, -1.0, true)
		beast.draw_circle(Vector2.ZERO, 106.0, body, true, -1.0, true)
		beast.draw_set_transform(Vector2.ZERO)
		for k in 3:
			beast.draw_arc(Vector2(-20 + k * 20.0, -120), 60.0 - k * 12.0, 0.6, 2.5, 10, ink, 3.0, true)
		beast.draw_circle(Vector2(96, -150), 46.0, ink, true, -1.0, true)
		beast.draw_circle(Vector2(96, -150), 41.0, body, true, -1.0, true)
		beast.draw_colored_polygon(PackedVector2Array([Vector2(70, -190), Vector2(20, -170), Vector2(30, -110), Vector2(70, -120)]), body.darkened(0.12))
		beast.draw_polyline(PackedVector2Array([Vector2(126, -140), Vector2(146, -100), Vector2(150, -50), Vector2(140, -20)]), ink, 22.0, true)
		beast.draw_polyline(PackedVector2Array([Vector2(126, -140), Vector2(146, -100), Vector2(150, -50), Vector2(140, -20)]), body, 16.0, true)
		beast.draw_polyline(PackedVector2Array([Vector2(118, -128), Vector2(150, -116), Vector2(166, -130)]), Color(0.97, 0.95, 0.88), 6.0, true)
		beast.draw_circle(Vector2(108, -162), 5.0, ink, true, -1.0, true))
	beast.position = Vector2(at.x, ground - 900.0)
	beast.scale = Vector2(0.8, 0.8)
	_actors.add_child(beast)
	var fall := beast.create_tween()
	fall.tween_property(beast, "position:y", ground, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(func() -> void:
		Effects.burst(_actors, Vector2(at.x, ground - 20.0), Color(0.45, 0.7, 1.0), 60, 900.0, 120.0, 2.0)
		Effects.burst(_actors, Vector2(at.x, ground - 20.0), Color(0.85, 0.95, 1.0), 30, 500.0, 120.0, 1.6)
		Audio.play("ground", 4.0, 0.4, 0.0)
		_camera.shake(0.9))
	fall.tween_interval(0.5)
	fall.tween_property(beast, "modulate:a", 0.0, 0.4)
	fall.tween_callback(beast.queue_free)


## Aqwa's luck: whatever was aimed, the throw takes the path that lands on the target.
func _lucky_shot(fighter: Fighter) -> Dictionary:
	var weapon := fighter.data.weapon
	var aim_at: Vector2
	if mode == Mode.PRACTICE and _practice_target != null:
		aim_at = _practice_target.global_position
	else:
		aim_at = fighters[1 - current].aim_point(false)
	return AiAimer.solve(fighter.throw_origin(), aim_at, weapon.max_speed, fighter.facing, 40.0, [], _wind_for(fighter), Rules.GRAVITY * weapon.gravity_scale)


## Uryo's special: Vollstandig. Wings of light, a little healing, and his next few
## arrows explode where they hit.
func _vollstandig(fighter: Fighter) -> void:
	fighter.form = &"vollstandig"
	fighter.heal(VOLL_HEAL)
	_empowered[current] = VOLL_THROWS
	_hud.announce("VOLLSTANDIG!", Color(0.75, 0.9, 1.0))
	Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -70), "+%d" % VOLL_HEAL, Color(0.5, 1.0, 0.6), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Effects.burst(_actors, fighter.aim_point(false), Color(0.8, 0.92, 1.0), 50, 600.0, 180.0, 1.8)
	Audio.play("voice_charge", 0.0, fighter.voice_pitch() * 1.1, 0.0)


## Kazma's party pops in for his special: Lalatna in armour right in front of him (far
## too keen to take the hits), and Aqwa a step further on, showing off.
func _party_cameo(fighter: Fighter) -> void:
	_cameo(fighter, &"lalatna", 95.0, "Hit me harder!", 0.0)
	_cameo(fighter, &"aqwa", 210.0, "Worship me, I'm a goddess!", 1.25)


## Someone from a fighter's story steps in beside them for a moment, saying `line`
## after `delay` seconds.
func _cameo(fighter: Fighter, who: StringName, ahead: float, line: String, delay: float) -> void:
	var side := float(fighter.facing)
	var x := fighter.position.x + side * ahead
	var member := Node2D.new()
	member.position = Vector2(x, Terrain.height_at(x))
	member.z_index = 4
	member.draw.connect(_draw_party_member.bind(member, who, side))
	_actors.add_child(member)
	member.modulate.a = 0.0
	var life := member.create_tween()
	life.tween_property(member, "modulate:a", 1.0, 0.2)
	life.tween_interval(delay + 1.6)
	life.tween_property(member, "modulate:a", 0.0, 0.4)
	life.tween_callback(member.queue_free)
	var id := _match_id
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if id == _match_id:
			_say_at(Vector2(x, Terrain.height_at(x) - 150.0), line, 1.2))


func _draw_party_member(canvas: Node2D, who: StringName, side: float) -> void:
	var ink := Color(0.08, 0.07, 0.1)
	var skin := Color(1, 0.87, 0.76)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(side, 1.0))
	canvas.draw_line(Vector2(-6, 0), Vector2(0, -36), ink, 4.0, true)
	canvas.draw_line(Vector2(6, 0), Vector2(0, -36), ink, 4.0, true)
	if who == &"lalatna":
		# Silver armour, a blue skirt, a long blond ponytail and a big sword.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-14, -30), Vector2(14, -30), Vector2(10, -44), Vector2(-10, -44)]), Color(0.2, 0.3, 0.6))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12, -44), Vector2(12, -44), Vector2(13, -74), Vector2(-13, -74)]), Color(0.82, 0.84, 0.9))
		canvas.draw_polyline(PackedVector2Array([Vector2(-12, -44), Vector2(12, -44), Vector2(13, -74), Vector2(-13, -74), Vector2(-12, -44)]), ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8, -96), Vector2(-26, -70), Vector2(-20, -40), Vector2(-12, -74)]), Color(0.98, 0.86, 0.45))
		canvas.draw_circle(Vector2(0, -88), 12.0, skin, true, -1.0, true)
		canvas.draw_arc(Vector2(0, -88), 12.0, 0.0, TAU, 16, ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, -88), Vector2(-8, -101), Vector2(8, -101), Vector2(13, -90), Vector2(4, -95)]), Color(0.98, 0.86, 0.45))
		canvas.draw_line(Vector2(3, -90), Vector2(9, -90), ink, 2.0, true)
		canvas.draw_line(Vector2(16, -60), Vector2(30, -110), Color(0.75, 0.78, 0.85), 5.0, true)
		canvas.draw_line(Vector2(10, -64), Vector2(22, -58), Color(0.6, 0.45, 0.2), 4.0, true)
	elif who == &"aqwa":
		# Long blue hair, a blue and white outfit, and a staff topped with a flower.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-14, -30), Vector2(14, -30), Vector2(10, -48), Vector2(-10, -48)]), Color(0.3, 0.55, 0.95))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11, -48), Vector2(11, -48), Vector2(12, -74), Vector2(-12, -74)]), Color(0.95, 0.96, 1.0))
		canvas.draw_polyline(PackedVector2Array([Vector2(-11, -48), Vector2(11, -48), Vector2(12, -74), Vector2(-12, -74), Vector2(-11, -48)]), ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12, -96), Vector2(8, -102), Vector2(4, -80), Vector2(-6, -40), Vector2(-20, -46), Vector2(-16, -80)]), Color(0.45, 0.72, 1.0))
		canvas.draw_circle(Vector2(0, -88), 12.0, skin, true, -1.0, true)
		canvas.draw_arc(Vector2(0, -88), 12.0, 0.0, TAU, 16, ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, -90), Vector2(-6, -101), Vector2(10, -99), Vector2(13, -89), Vector2(2, -94)]), Color(0.45, 0.72, 1.0))
		canvas.draw_circle(Vector2(-4, -103), 4.0, Color(0.45, 0.72, 1.0), true, -1.0, true)
		canvas.draw_line(Vector2(3, -89), Vector2(9, -89), ink, 2.0, true)
		canvas.draw_line(Vector2(18, -20), Vector2(22, -112), Color(0.5, 0.35, 0.2), 3.0, true)
		canvas.draw_circle(Vector2(22, -116), 7.0, Color(0.55, 0.85, 1.0), true, -1.0, true)
		canvas.draw_circle(Vector2(22, -116), 3.0, Color.WHITE, true, -1.0, true)
	elif who == &"beatris":
		# Small, in a frilly pink dress, with long cream-blond drill twin-tails.
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(side * 0.85, 0.85))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-18, -28), Vector2(18, -28), Vector2(9, -64), Vector2(-9, -64)]), Color(0.95, 0.55, 0.7))
		canvas.draw_polyline(PackedVector2Array([Vector2(-18, -28), Vector2(18, -28), Vector2(9, -64), Vector2(-9, -64), Vector2(-18, -28)]), ink, 2.0, true)
		canvas.draw_line(Vector2(-17, -32), Vector2(17, -32), Color(0.3, 0.15, 0.3), 3.0, true)
		for drill: float in [-1.0, 1.0]:
			for k in 4:
				canvas.draw_circle(Vector2(drill * 16.0, -84 + k * 11.0), 7.0 - k, Color(0.98, 0.9, 0.62), true, -1.0, true)
				canvas.draw_arc(Vector2(drill * 16.0, -84 + k * 11.0), 7.0 - k, 0.0, TAU, 12, Color(0.8, 0.65, 0.35), 1.2, true)
		canvas.draw_circle(Vector2(0, -82), 12.0, skin, true, -1.0, true)
		canvas.draw_arc(Vector2(0, -82), 12.0, 0.0, TAU, 16, ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, -84), Vector2(-8, -95), Vector2(9, -95), Vector2(13, -84), Vector2(2, -89)]), Color(0.98, 0.9, 0.62))
		canvas.draw_circle(Vector2(5, -82), 2.2, Color(0.4, 0.6, 0.95), true, -1.0, true)
		canvas.draw_circle(Vector2(-3, -97), 4.0, Color(0.3, 0.15, 0.3), true, -1.0, true)
	elif who == &"emilla":
		# Long silver hair with a white flower, a white and violet dress.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-15, -26), Vector2(15, -26), Vector2(11, -50), Vector2(-11, -50)]), Color(0.75, 0.6, 0.95))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11, -50), Vector2(11, -50), Vector2(12, -74), Vector2(-12, -74)]), Color(0.97, 0.97, 1.0))
		canvas.draw_polyline(PackedVector2Array([Vector2(-11, -50), Vector2(11, -50), Vector2(12, -74), Vector2(-12, -74), Vector2(-11, -50)]), ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12, -96), Vector2(8, -102), Vector2(6, -84), Vector2(-4, -30), Vector2(-22, -36), Vector2(-17, -82)]), Color(0.9, 0.9, 0.97))
		canvas.draw_circle(Vector2(0, -88), 12.0, skin, true, -1.0, true)
		canvas.draw_arc(Vector2(0, -88), 12.0, 0.0, TAU, 16, ink, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, -90), Vector2(-6, -101), Vector2(10, -99), Vector2(13, -89), Vector2(2, -94)]), Color(0.9, 0.9, 0.97))
		canvas.draw_circle(Vector2(5, -88), 2.2, Color(0.6, 0.35, 0.85), true, -1.0, true)
		for petal in 5:
			canvas.draw_circle(Vector2(-8, -100) + Vector2.from_angle(petal * TAU / 5.0) * 3.5, 2.5, Color.WHITE, true, -1.0, true)
		canvas.draw_circle(Vector2(-8, -100), 1.8, Color(1.0, 0.85, 0.3), true, -1.0, true)
	canvas.draw_set_transform(Vector2.ZERO)


## A speech bubble standing at `at` for a moment.
func _say_at(at: Vector2, text: String, seconds: float) -> void:
	var font := ThemeDB.fallback_font
	var bubble := Node2D.new()
	bubble.z_index = 30
	bubble.position = at
	bubble.draw.connect(func() -> void:
		var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var box := Rect2(Vector2(-extent.x / 2 - 12, -extent.y - 12), extent + Vector2(24, 18))
		bubble.draw_colored_polygon(PackedVector2Array([Vector2(-10, box.end.y - 2), Vector2(10, box.end.y - 2), Vector2(0, box.end.y + 16)]), Color.WHITE)
		bubble.draw_style_box(UiStyle.flat(Color.WHITE, 14), box)
		bubble.draw_string(font, Vector2(-extent.x / 2, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.1, 0.08, 0.12)))
	bubble.scale = Vector2.ONE / _camera.zoom.x
	# Keep the whole bubble on screen.
	var half := (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x / 2.0 + 16.0) * bubble.scale.x
	var view := _camera.visible_rect()
	bubble.position.x = clampf(at.x, view.position.x + half, maxf(view.position.x + half, view.end.x - half))
	_actors.add_child(bubble)
	var life := bubble.create_tween()
	life.tween_interval(seconds)
	life.tween_property(bubble, "modulate:a", 0.0, 0.25)
	life.tween_callback(bubble.queue_free)


## Kyoka Suigetsu: as an enemy throw closes in on Aizon, the illusion breaks. He was
## never there: the thrower is standing in his place, and takes their own hit.
func _watch_illusion() -> void:
	# In stopped time it waits: the swap comes the moment time moves again.
	if state != State.FLYING or _hud.time_stopped():
		return
	for fighter in fighters:
		if not fighter.illusion or fighter.is_knocked_out():
			continue
		for projectile in _in_flight:
			if not is_instance_valid(projectile) or projectile.frozen or projectile.thrower == null or projectile.thrower == fighter:
				continue
			if projectile.global_position.distance_to(fighter.aim_point(false)) < ILLUSION_TRIGGER and _will_hit(projectile, fighter):
				_swap_places(fighter, projectile.thrower, projectile)
				return



## Whether a throw's path over the next moment runs into this fighter.
static func _will_hit(projectile: Projectile, fighter: Fighter) -> bool:
	var body := fighter.aim_point(false)
	var head := fighter.aim_point(true)
	var t := 0.0
	while t < 0.4:
		var at := projectile.predict(t)
		if at.distance_to(body) < 42.0 or at.distance_to(head) < 26.0:
			return true
		t += 0.01
	return false


## When Kyoka Suigetsu breaks, Aizon walks off with whatever the enemy had going:
## their shield, double damage, lucky throws or empowered arrows.
func _steal_buffs(aizon: Fighter, foe: Fighter) -> void:
	var stolen := PackedStringArray()
	var mine := fighters.find(aizon)
	var theirs := fighters.find(foe)
	if foe.shielded:
		foe.shielded = false
		aizon.shielded = true
		stolen.append("SHIELD")
	if foe.powered:
		foe.powered = false
		aizon.powered = true
		stolen.append("DOUBLE DAMAGE")
	if mine >= 0 and theirs >= 0:
		if _lucky[theirs] > 0:
			_lucky[mine] += _lucky[theirs]
			_lucky[theirs] = 0
			stolen.append("LUCK")
		if _empowered[theirs] > 0:
			_empowered[mine] += _empowered[theirs]
			_empowered[theirs] = 0
			foe.form = &""
			stolen.append("POWER-UP")
	if not stolen.is_empty():
		Effects.popup(_actors, aizon.aim_point(true) + Vector2(0, -110), "STOLE: " + ", ".join(stolen), Color(0.8, 0.6, 1.0), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())

func _swap_places(aizon: Fighter, foe: Fighter, projectile: Projectile) -> void:
	aizon.illusion = false
	var spot := aizon.position
	_swapped = [aizon, foe]
	_shatter_illusion(aizon)
	_steal_buffs(aizon, foe)
	_trade_places(aizon, foe)
	_turn_on_thrower(projectile, aizon, foe)
	Effects.burst(_actors, spot + Vector2(0, -60), Color(0.9, 0.95, 1.0), 50, 700.0, 180.0, 1.6)
	_slow_time(0.45, 0.25)



## The throw now flies at its own thrower; it no longer knows to miss them.
func _turn_on_thrower(projectile: Projectile, aizon: Fighter, foe: Fighter) -> void:
	projectile.set_meta("mirror_of", aizon)
	projectile._exclude.clear()
	projectile._exclude.append_array(aizon.get_hitbox_rids())
	projectile.set_meta("mirrored", true)
	projectile.homing_target = foe
	projectile.homing_range = 400.0
	projectile.homing_turn = 12.0

## Puts them back where they really stood once the hit has settled.
func _unswap() -> void:
	if _swapped.is_empty():
		return
	var pair := _swapped
	_swapped = []
	if not is_instance_valid(pair[0]) or not is_instance_valid(pair[1]):
		return
	_trade_places(pair[0], pair[1])
	for fighter: Fighter in pair:
		Effects.burst(_actors, fighter.aim_point(false), Color(0.75, 0.6, 1.0), 24, 400.0, 180.0, 1.2)
	Audio.play("whoosh", -2.0, 1.4, 0.0)


func _trade_places(a: Fighter, b: Fighter) -> void:
	var spot := a.position
	a.position = Vector2(b.position.x, Terrain.height_at(b.position.x))
	b.position = Vector2(spot.x, Terrain.height_at(spot.x))
	a.facing = -a.facing
	b.facing = -b.facing
	a.reset_physics_interpolation()
	b.reset_physics_interpolation()


## Aizon's evolution: the first time he is beaten down to EVOLVE_HEALTH, the Hogyoku
## remakes him: white, winged, and far stronger.
func _check_evolution(fighter: Fighter, health: int) -> void:
	if fighter.data.base_id() == &"frierin" and not fighter.mana_released and health > 0 and health <= MANA_RELEASE_HEALTH and mode != Mode.PRACTICE:
		_release_mana(fighter)
		return
	if fighter.evolved or fighter.data.base_id() != &"aizon" or health <= 0 or health > EVOLVE_HEALTH or mode == Mode.PRACTICE:
		return
	fighter.evolved = true
	# His basic changes with him: a sphere of violet-black reishi that bursts.
	var evolved_data := fighter.data.duplicate() as FighterData
	var hado := fighter.data.weapon.duplicate() as WeaponData
	hado.shape = &"dark_hado"
	hado.display_name = "Hado: Kurohitsugi Sphere"
	hado.size = 52.0
	hado.color = Color(0.6, 0.35, 0.95)
	hado.explode_radius = 70.0
	hado.gravity_scale = 0.5
	evolved_data.weapon = hado
	fighter.data = evolved_data
	fighter.power_up(2.0)
	_hud.announce("AIZON EVOLVES!", Color(0.85, 0.7, 1.0))
	Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -90), "POWER x1.5", Color(0.85, 0.7, 1.0), 32, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Effects.burst(_actors, fighter.aim_point(false), Color(0.97, 0.95, 1.0), 60, 700.0, 180.0, 2.0)
	Effects.burst(_actors, fighter.aim_point(false), Color(0.6, 0.35, 0.95), 40, 500.0, 180.0, 1.8)
	Audio.play("voice_charge", 2.0, fighter.voice_pitch(), 0.0)
	_camera.shake(0.6)


## Subaro's special: a red target circle sweeps back and forth over the ground. Press
## (click, tap or Space) and Emilla drops a great icicle from the sky onto it.
func _start_icefall(fighter: Fighter) -> void:
	_launching = true
	_cameo(fighter, &"emilla", 95.0, "Leave it to me, Subaro!", 0.0)
	var foe_x := _icefall_target_x()
	var near := fighter.position.x + fighter.facing * 160.0
	var far := foe_x + fighter.facing * 320.0
	var lo := minf(near, far)
	var hi := maxf(near, far)
	var error: float = [140.0, 80.0, 40.0, 20.0][clampi(_last_difficulty, 0, 3)]
	_icefall = {"fighter": fighter, "x": near, "dir": float(fighter.facing), "lo": lo, "hi": hi, "time": 0.0,
		"ai_at": foe_x + rng.randf_range(-error, error), "error": error, "id": _match_id, "left": ICEFALL_DROPS, "cooldown": 0.0}
	var marker := Node2D.new()
	marker.z_index = 24
	marker.draw.connect(func() -> void:
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.015)
		var r := ICEFALL_RADIUS
		# A beam of red light down from the sky marks the spot.
		marker.draw_rect(Rect2(-r * 0.35, -900.0, r * 0.7, 900.0), Color(1.0, 0.2, 0.25, 0.16 * pulse))
		marker.draw_line(Vector2(0, -900), Vector2(0, -10), Color(1.0, 0.35, 0.4, 0.6 * pulse), 4.0, true)
		marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		marker.draw_circle(Vector2.ZERO, r, Color(1.0, 0.15, 0.2, 0.35 * pulse), true, -1.0, true)
		marker.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.15, 0.02, 0.04, 0.9), 14.0, true)
		marker.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.25, 0.3, 1.0), 9.0, true)
		marker.draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 32, Color(1.0, 0.3, 0.35, 0.9), 6.0, true)
		marker.draw_set_transform(Vector2.ZERO)
		marker.draw_line(Vector2(-r - 10, 0), Vector2(-r * 0.6, 0), Color.WHITE, 3.0, true)
		marker.draw_line(Vector2(r * 0.6, 0), Vector2(r + 10, 0), Color.WHITE, 3.0, true)
		# Icicles left.
		var left := int(_icefall.get("left", 0))
		for k in left:
			var x := (k - (left - 1) / 2.0) * 22.0
			marker.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, -150), Vector2(x + 7, -150), Vector2(x, -120)]), Color(0.75, 0.92, 1.0)))
	_actors.add_child(marker)
	_icefall["marker"] = marker


## Where the icicle should land to hit: the enemy, or the target in practice.
func _icefall_target_x() -> float:
	if mode == Mode.PRACTICE and _practice_target != null:
		return _practice_target.global_position.x
	return fighters[1 - current].position.x


func _process_icefall(delta: float) -> void:
	if _icefall.is_empty():
		return
	if int(_icefall["id"]) != _match_id:
		_icefall = {}
		return
	var x: float = _icefall["x"]
	var dir: float = _icefall["dir"]
	x += dir * ICEFALL_SPEED * delta
	if x > float(_icefall["hi"]):
		x = _icefall["hi"]
		_icefall["dir"] = -1.0
	elif x < float(_icefall["lo"]):
		x = _icefall["lo"]
		_icefall["dir"] = 1.0
	_icefall["x"] = x
	_icefall["time"] = float(_icefall["time"]) + delta
	var marker: Node2D = _icefall["marker"]
	marker.position = Vector2(x, Terrain.height_at(x))
	marker.queue_redraw()
	var fighter: Fighter = _icefall["fighter"]
	_icefall["cooldown"] = maxf(0.0, float(_icefall["cooldown"]) - delta)
	var ai_ready := fighter.is_ai and float(_icefall["cooldown"]) <= 0.0 and absf(x - float(_icefall["ai_at"])) < ICEFALL_SPEED * delta * 1.5
	if ai_ready:
		_drop_icefall()
	elif float(_icefall["time"]) > ICEFALL_TIME:
		if int(_icefall["left"]) == ICEFALL_DROPS:
			_drop_icefall()
		_end_icefall()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept")
	if not pressed:
		return
	if _drop_orb != null and is_instance_valid(_drop_orb) and not _drop_orb.thrower.is_ai and state == State.FLYING:
		get_viewport().set_input_as_handled()
		_drop_beam()
		return
	if not _icefall.is_empty() and not (_icefall["fighter"] as Fighter).is_ai:
		get_viewport().set_input_as_handled()
		_drop_icefall()


## Emilla's icicle comes straight down out of the sky onto the circle.
func _drop_icefall() -> void:
	if _icefall.is_empty() or int(_icefall["left"]) <= 0:
		return
	var fighter: Fighter = _icefall["fighter"]
	var x: float = _icefall["x"]
	_icefall["left"] = int(_icefall["left"]) - 1
	_icefall["cooldown"] = 0.35
	_icefall["ai_at"] = _icefall_target_x() + rng.randf_range(-float(_icefall["error"]), float(_icefall["error"]))
	var ice := fighter.data.weapon.duplicate() as WeaponData
	ice.shape = &"ice_lance"
	ice.gravity_scale = 0.0
	ice.size = 150.0
	ice.sticks = false
	ice.color = Color(0.75, 0.92, 1.0)
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	_actors.add_child(projectile)
	projectile.launch(ice, fighter, Vector2(x, Terrain.height_at(x) - 1300.0), Vector2(0, 2400.0), 0.0)
	projectile.target = fighters[1 - current]
	projectile.explode_radius = ICEFALL_RADIUS
	projectile.pierce = true
	projectile.set_trail_color(Color(0.75, 0.92, 1.0))
	projectile.set_meta("icefall", true)
	projectile.set_meta("freeze", true)
	_track(projectile)
	Audio.play("whoosh", 2.0, 0.6, 0.0)
	if int(_icefall["left"]) <= 0:
		_end_icefall()


## The circle goes; once the icicles have all landed the turn moves on.
func _end_icefall() -> void:
	if _icefall.is_empty():
		return
	(_icefall["marker"] as Node2D).queue_free()
	_icefall = {}
	_hud.hide_tip()
	_launching = false
	if _in_flight.is_empty() and state == State.FLYING:
		_after_throw()


## Frierin's special, Zoltraak: magic circles flicker open around her and pour out a
## volley of fast purple spheres of pure mana, straight through anything in the way.
func _zoltraak_barrage(fighter: Fighter, angle: float) -> void:
	var beam := fighter.data.weapon.duplicate() as WeaponData
	beam.shape = &"mana_orb"
	beam.gravity_scale = 0.0
	beam.max_speed = 2200.0
	beam.size = 34.0
	beam.color = Color(0.7, 0.4, 1.0)
	var id := _match_id
	_launching = true
	# She is already up in the sky (she rose when the special was used). Every sphere
	# converges on the aim line at the target's distance.
	await _set_floating(fighter, true)
	if id != _match_id:
		return
	if fighter.is_ai:
		angle = beam_angle(fighter.throw_origin(), fighters[1 - current].aim_point(false), fighter.facing)
	var a := deg_to_rad(angle)
	var direction := Vector2(cos(a) * fighter.facing, -sin(a))
	var reach := absf(_icefall_target_x() - fighter.position.x) / maxf(absf(direction.x), 0.25)
	var focus := fighter.throw_origin() + direction * reach
	var across := direction.orthogonal()
	var circles: Array[Node2D] = []
	for i in ZOLTRAAK_CIRCLES:
		var spot := fighter.throw_origin() + across * (i - (ZOLTRAAK_CIRCLES - 1) / 2.0) * 46.0 - direction * 20.0
		var circle := Node2D.new()
		circle.z_index = 18
		circle.position = spot
		circle.rotation = direction.angle()
		circle.draw.connect(func() -> void:
			var spin := Time.get_ticks_msec() * 0.004
			circle.draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.35, 1.0))
			circle.draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(0.75, 0.88, 1.0, 0.9), 3.0, true)
			circle.draw_arc(Vector2.ZERO, 18.0, spin, spin + TAU * 0.8, 24, Color(1.0, 0.95, 0.7, 0.9), 2.0, true)
			for k in 6:
				var p := Vector2.from_angle(spin + k * TAU / 6.0) * 22.0
				circle.draw_circle(p, 2.0, Color.WHITE, true, -1.0, true))
		_actors.add_child(circle)
		get_tree().process_frame.connect(circle.queue_redraw)
		circles.append(circle)
		Audio.play("zap", -8.0, 1.6 + i * 0.1, 0.0)
		await get_tree().create_timer(0.08, false).timeout
		if id != _match_id:
			return
	for i in circles.size():
		fighter.play_throw()
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(beam, fighter, circles[i].position, (focus - circles[i].position).normalized() * beam.max_speed, 0.0)
		projectile.target = fighters[1 - current]
		projectile.pierce = true
		projectile.set_trail_color(Color(0.8, 0.9, 1.0))
		projectile.set_meta("zoltraak", true)
		projectile.explode_radius = ZOLTRAAK_VOLLEY_BURST
		_track(projectile)
		Audio.play("zap", -2.0, 1.2, 0.05)
		var fade := circles[i].create_tween()
		fade.tween_property(circles[i], "modulate:a", 0.0, 0.4)
		fade.tween_callback(circles[i].queue_free)
		await get_tree().create_timer(0.1, false).timeout
		if id != _match_id:
			return
	# And floats back down.
	await _set_floating(fighter, false)
	if id != _match_id:
		return
	_launching = false
	if _in_flight.is_empty() and state == State.FLYING:
		_after_throw()


## Frierin's Mana Release: she stops suppressing her mana. A torrent of pale light
## pours off her, and her barrier and Mana Analysis switch on for the rest of the match.
func _release_mana(fighter: Fighter) -> void:
	fighter.mana_released = true
	fighter.barrier_ready = true
	fighter.power_up(2.0)
	_hud.announce("MANA RELEASE!", Color(0.75, 0.88, 1.0))
	Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -90), "BARRIER + MANA ANALYSIS", Color(0.75, 0.88, 1.0), 26, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Effects.burst(_actors, fighter.aim_point(false), Color(0.8, 0.9, 1.0), 70, 800.0, 180.0, 2.2)
	Audio.play("special_ready", 2.0, 0.8, 0.0)
	_camera.shake(0.6)


## Frierin's basic, step two: her mana orb is in flight, waiting for the press that
## fires a Zoltraak straight down from it.
func _arm_drop_orb(projectile: Projectile, fighter: Fighter) -> void:
	_drop_orb = projectile
	var error: float = [120.0, 70.0, 35.0, 15.0][clampi(_last_difficulty, 0, 3)]
	_drop_ai_offset = rng.randf_range(-error, error)
	if not fighter.is_ai:
		Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -80), "PRESS TO DROP ZOLTRAAK!", Color(0.8, 0.7, 1.0), 26, 1.0 / _camera.zoom.x, _camera.visible_rect())
	if _drop_guide:
		# Mana Analysis: a faint line under the orb shows where the beam would land.
		var guide := Node2D.new()
		guide.z_index = 5
		guide.draw.connect(func() -> void:
			if not is_instance_valid(projectile) or not projectile.is_flying():
				return
			var top := projectile.global_position
			var bottom := Vector2(top.x, Terrain.height_at(top.x))
			guide.draw_dashed_line(top, bottom, Color(0.8, 0.7, 1.0, 0.7), 3.0, 14.0)
			guide.draw_arc(bottom, 14.0, 0.0, TAU, 20, Color(0.8, 0.7, 1.0, 0.8), 2.5, true))
		_actors.add_child(guide)
		get_tree().process_frame.connect(guide.queue_redraw)
		projectile.tree_exiting.connect(guide.queue_free)


## Each frame: the AI drops when the orb is over its target (give or take).
func _watch_drop_orb() -> void:
	if _drop_orb == null:
		return
	if not is_instance_valid(_drop_orb) or not _drop_orb.is_flying():
		_drop_orb = null
		return
	if not _drop_orb.thrower.is_ai:
		return
	var aim_x := _icefall_target_x() + _drop_ai_offset
	if absf(_drop_orb.global_position.x - aim_x) < 26.0:
		_drop_beam()


## The Zoltraak: a beam fires straight down from the orb, which is spent.
func _drop_beam() -> void:
	var orb := _drop_orb
	_drop_orb = null
	if not is_instance_valid(orb) or not orb.is_flying():
		return
	var fighter := orb.thrower
	var top := orb.global_position
	var beam := orb.weapon.duplicate() as WeaponData
	beam.shape = &"zoltraak"
	beam.gravity_scale = 0.0
	beam.max_speed = 3200.0
	beam.size = 60.0
	beam.color = Color(0.75, 0.88, 1.0)
	beam.body_damage = ZOLTRAAK_BEAM_DAMAGE[0]
	beam.head_damage = ZOLTRAAK_BEAM_DAMAGE[1]
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	_actors.add_child(projectile)
	projectile.launch(beam, fighter, top, Vector2(0, beam.max_speed), 0.0)
	projectile.target = orb.target
	projectile.set_trail_color(Color(0.8, 0.9, 1.0))
	projectile.set_meta("zoltraak_drop", true)
	var finishing: bool = not _finisher.is_empty() and not _finisher["done"]
	# Mana Release: the beam lands in a wide burst.
	var released := fighter.mana_released
	if released:
		projectile.explode_radius = ZOLTRAAK_BURST_RADIUS
	if finishing:
		_hook_finisher(projectile)
	else:
		_track(projectile)
	# A flash of light down the whole line.
	var flash := Node2D.new()
	flash.z_index = 19
	var bottom := Vector2(top.x, Terrain.height_at(top.x))
	flash.draw.connect(func() -> void:
		var wide := 2.0 if released else 1.0
		flash.draw_line(top, bottom, Color(0.75, 0.88, 1.0, 0.4), 22.0 * wide, true)
		flash.draw_line(top, bottom, Color.WHITE, 6.0 * wide, true))
	_actors.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "modulate:a", 0.0, 0.35)
	fade.tween_callback(flash.queue_free)
	Effects.burst(_actors, top, Color(0.8, 0.7, 1.0), 20, 300.0, 180.0, 1.0)
	Audio.play("zap", 0.0, 1.1, 0.05)
	orb.visible = false
	orb._finish(false)


## Frierin rises into the sky to cast her volley (and comes back down after).
func _set_floating(fighter: Fighter, up: bool) -> void:
	var ground := Terrain.height_at(fighter.position.x)
	var goal := ground - ZOLTRAAK_SKY if up else ground
	if absf(fighter.position.y - goal) < 1.0:
		return
	if up:
		Audio.play("whoosh", 0.0, 0.5, 0.0)
	var move := fighter.create_tween()
	move.tween_property(fighter, "position:y", goal, 0.5 if up else 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if up else Tween.EASE_IN_OUT)
	await move.finished


## Each Reiatsu hit adds to the weight on them; at PRESSURE_HITS in a row their
## defence drops until his next hit, which spends it.
func _build_pressure(target: Fighter) -> void:
	var view := _camera.visible_rect()
	var at := target.aim_point(true) + Vector2(0, -100)
	if target.pressured:
		target.pressured = false
		target.pressure_stacks = 0
		Effects.popup(_actors, at, "CRUSHED!", Color(0.85, 0.6, 1.0), 34, 1.0 / _camera.zoom.x, view)
		Effects.burst(_actors, target.aim_point(false), Color(0.6, 0.35, 0.95), 40, 600.0, 180.0, 1.6)
		_camera.shake(0.6)
		return
	target.pressure_stacks += 1
	if target.pressure_stacks >= PRESSURE_HITS:
		target.pressured = true
		target.pressure_stacks = 0
		Effects.popup(_actors, at, "SPIRITUAL PRESSURE!  DEF DOWN", Color(0.75, 0.55, 1.0), 30, 1.0 / _camera.zoom.x, view)
		Audio.play("ko", -6.0, 0.4, 0.0)
	else:
		Effects.popup(_actors, at, "PRESSURE %d / %d" % [target.pressure_stacks, PRESSURE_HITS], Color(0.75, 0.55, 1.0), 26, 1.0 / _camera.zoom.x, view)
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
	Terrain.build(rng, 700.0, 0.7 * current_map.terrain_roughness, false)
	_arena.refresh_terrain()
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
	# Specials start charged so you can try yours straight away; hits refill it.
	_charge = [1.0, 0.0]
	fighters[0].charge = 1.0
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




## Target Practice: plays your fighter's fatality on a dummy, then puts practice back
## just as it was.
func _test_fatality() -> void:
	if mode != Mode.PRACTICE or state != State.PLAYER_AIM or fighters.is_empty():
		return
	var id := _match_id
	var winner := fighters[0]
	state = State.GAME_OVER
	_aim.finish()
	_hud.set_special(null, 0.0, false)
	_hud.set_turn("")
	_hud.set_fatality_test_enabled(false)
	var target_shown := _practice_target != null and _practice_target.visible
	if _practice_target != null:
		_practice_target.visible = false
	var dummy := _spawn_fighter(FATALITY_DUMMY, winner.position.x + 520.0, -1, true)
	await get_tree().create_timer(0.3, false).timeout
	if id != _match_id:
		return
	_end_slow_time()
	var fatality := Fatality.new()
	fatality.setup(winner, dummy, _camera, _hud, Save.gore)
	_actors.add_child(fatality)
	fatality.play(true)
	if not fatality.is_done():
		await fatality.finished
	if id != _match_id:
		return
	fatality.queue_free()
	dummy.queue_free()
	winner._celebrating = false
	winner.facing = 1
	winner.victory_pose = &""
	winner.holding_weapon = true
	winner.position = Vector2(-700.0, Terrain.height_at(-700.0))
	winner.reset_physics_interpolation()
	if _practice_target != null:
		_practice_target.visible = target_shown
	_hud.set_fatality_test_enabled(true)
	_camera.snap()
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
	var at := Vector2(thrower_x + distance, -height + Terrain.height_at(thrower_x + distance))
	# From the 6th target on, a wall stands in the way.
	for child in _obstacle_layer.get_children():
		child.queue_free()
	_obstacle_rects.clear()
	if index >= 5:
		var wall := Obstacle.new()
		var mid := thrower_x + distance * 0.5
		var box := Rect2(mid - 45, -rng.randf_range(160.0, 260.0), 90, 0)
		box.size.y = -box.position.y
		box.position.y += Terrain.height_at(mid)
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
	_add_charge(0, PRACTICE_CHARGE)
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
	# Stand each obstacle on the ground beneath it.
	for item in layout:
		var box: Rect2 = item["rect"]
		box.position.y += Terrain.height_at(box.get_center().x)
		item["rect"] = box
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
		var crate_x := rng.randf_range(-_gap * 0.28, _gap * 0.28)
		var at := Vector2(crate_x, rng.randf_range(-430.0, -250.0) + Terrain.height_at(crate_x))
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
	fighter.position = Vector2(x, Terrain.height_at(x))
	_actors.add_child(fighter)
	# Fighters only move when a plunger drags them, by tween, so skip interpolation.
	fighter.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fighter.reset_physics_interpolation()
	fighter.setup(data, facing, is_ai)
	fighter.health_changed.connect(_check_evolution)
	if not is_ai:
		fighter.ink_color = Save.ink_color()
	return fighter


func _begin_turn() -> void:
	var fighter := fighters[current]
	_special_this_turn = false
	# Frierin's barrier comes back up whenever her enemy starts a turn.
	for other in fighters:
		if other != fighter and other.data.base_id() == &"frierin":
			other.barrier_ready = true
	# Burning (Fuga): the fire hurts at the start of their turn.
	if fighter.burn_turns > 0 and not fighter.is_knocked_out() and mode != Mode.PRACTICE and not _hud.time_stopped():
		fighter.burn_turns -= 1
		fighter.take_hit(Rules.BODY, BURN_DAMAGE, Vector2.ZERO)
		Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -70), "BURN  -%d" % BURN_DAMAGE, Color(1.0, 0.55, 0.2), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, fighter.aim_point(false), Color(1.0, 0.5, 0.15), 20, 300.0, 180.0, 1.2)
		Audio.play("whoosh", -4.0, 0.6, 0.0)
		if fighter.is_knocked_out():
			_end_match()
			return
	# Bleeding (Dyo's knives): a little blood lost at the start of their turn.
	if fighter.bleed_turns > 0 and not fighter.is_knocked_out() and mode != Mode.PRACTICE and not _hud.time_stopped():
		fighter.bleed_turns -= 1
		fighter.take_hit(Rules.BODY, BLEED_DAMAGE, Vector2.ZERO)
		Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -70), "BLEED  -%d" % BLEED_DAMAGE, Color(0.9, 0.15, 0.2), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, fighter.aim_point(false), Color(0.7, 0.02, 0.05), 16, 260.0, 180.0, 1.0)
		if fighter.is_knocked_out():
			_end_match()
			return
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
		if _turn_count % HAZARD_EVERY == HAZARD_EVERY - 1 and not _hud.time_stopped():
			var hazard_id := _match_id
			await _drop_hazard()
			if hazard_id != _match_id or fighters[0].is_knocked_out() or fighters[1].is_knocked_out():
				if hazard_id == _match_id:
					_end_match()
				return
	_turn_count += 1
	_turn_hit = false
	if not fighter.is_ai:
		state = State.PLAYER_AIM
		var turn_text := "PLAYER %d'S TURN" % (current + 1) if mode == Mode.LOCAL_2P else "YOUR TURN"
		if mode == Mode.PRACTICE:
			turn_text = "TARGET %d/%d  ·  TRY %d/%d" % [_practice["index"] + 1, PRACTICE_TARGETS, _practice["attempt"] + 1, PRACTICE_TRIES]
		_hud.set_turn(turn_text, SIDE_COLORS[current])
		_hud.set_special(fighter.data, _charge[current], false)
		_turn_timer = TURN_TIME if mode == Mode.LOCAL_2P else -1.0
		_aim.full_guide = (_hud.time_stopped() and fighter == _stopper) or _analysis[current] >= ANALYSIS_STEPS
		_aim.guide_boost = float(_analysis[current]) / ANALYSIS_STEPS
		if _analysis[current] > 0:
			var label := "MANA ANALYSIS: FULL" if _analysis[current] >= ANALYSIS_STEPS else "MANA ANALYSIS %d / %d" % [_analysis[current], ANALYSIS_STEPS]
			Effects.popup(_actors, fighter.aim_point(true) + Vector2(0, -80), label, Color(0.75, 0.88, 1.0), 28, 1.0 / _camera.zoom.x, _camera.visible_rect())
		_tutorial_tip()
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
		if fighter.data.weapon.special == &"knifestorm":
			_stopper = fighter
			_stop_time(fighter)
		if fighter.data.weapon.special == &"barrage_zoltraak":
			var rise_id := _match_id
			await _set_floating(fighter, true)
			if rise_id != _match_id:
				return
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
	_process_icefall(delta)
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
	_pull_toward_purple(_delta)
	_watch_drop_orb()
	_watch_illusion()
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
	if (state == State.PLAYER_AIM or state == State.FINISHER) and _charge[current] >= 1.0:
		if armed and fighters[current].data.weapon.special in INSTANT_SPECIALS + [&"icefall"]:
			_use_special_now(fighters[current])
			return
		_special_armed = armed
		var data := fighters[current].data
		# The beam fires in a straight line, so the aim guide straightens and can point down.
		_aim.set_beam(armed and is_straight_special(data.weapon.special))
		if data.weapon.special == &"barrage_zoltraak":
			_set_floating(fighters[current], armed)
		# Dyo: The Warld stops time the moment the special is pressed; the knives come
		# with the throw. Un-arming lets time move again.
		if data.weapon.special == &"knifestorm":
			if armed and not _hud.time_stopped():
				_stopper = fighters[current]
				_stop_time(fighters[current])
			elif not armed and _hud.time_stopped() and _stopper == fighters[current]:
				_resume_time()
			_aim.full_guide = armed
		_aim.full_guide = (armed and data.weapon.special == &"timestop") or (_hud.time_stopped() and fighters[current] == _stopper)
		_aim.set_special(data.special_name if armed else "", data.body_color)
		if armed:
			Audio.play("win", -10.0, 1.8, 0.0)
			_hud.announce("%s ARMED!" % data.special_name.to_upper(), data.body_color.lightened(0.35))



## Spends the special: the meter empties and everyone hears about it.
func _consume_special(fighter: Fighter) -> void:
	_special_used[current] = true
	_special_this_turn = true
	_charge[current] = 0.0
	fighter.charge = 0.0
	if current == 0:
		_specials_used += 1
	_hud.announce("%s: %s!" % [fighter.data.short_name.to_upper(), fighter.data.special_name.to_upper()], fighter.data.body_color.lightened(0.3))
	Audio.play("voice_charge", -1.0, fighter.voice_pitch() * 1.1, 0.0)
	Audio.play("win", -8.0, 1.6, 0.0)


## Specials that aren't aimed (a power-up, time stop, an illusion) take effect the
## moment they're used; the throw that follows is an ordinary one.
func _apply_instant_special(fighter: Fighter, special: StringName) -> void:
	match special:
		&"vollstandig":
			_vollstandig(fighter)
		&"blessing":
			_bless(fighter)
		&"illusion":
			fighter.illusion = true
			_hud.announce("SINCE WHEN WERE YOU UNDER THE IMPRESSION...", Color(0.75, 0.55, 1.0))
			Effects.burst(_actors, fighter.aim_point(false), Color(0.6, 0.35, 0.95), 40, 600.0, 180.0, 1.6)
		&"timestop":
			_time_stop_left = TIME_STOP_THROWS - 1
			_stopper = fighter
			_stop_time(fighter)


## A player pressing the special button for one of those specials: it happens now.
## Subaro's icefall takes the whole turn; the rest leave you to aim and throw.
func _use_special_now(fighter: Fighter) -> void:
	var special := fighter.data.weapon.special
	_special_armed = false
	_consume_special(fighter)
	_hud.set_special(null, 0.0, false)
	if special == &"icefall" and not _finisher.is_empty() and not _finisher["done"]:
		_finisher["special"] = true
	if special == &"icefall":
		_aim.finish()
		_turn_timer = -1.0
		_hud.set_timer(-1)
		_hud.set_turn("")
		state = State.FLYING
		_start_icefall(fighter)
		return
	_apply_instant_special(fighter, special)
	_aim.set_special("", fighter.data.body_color)
	_aim.full_guide = _hud.time_stopped() and fighter == _stopper

func _on_player_throw(angle: float, power: float) -> void:
	if state == State.FINISHER:
		_aim.finish()
		if _special_armed:
			# Finishing with a special: it flies like any special, and touching the loser
			# earns the fatality.
			_finisher["special"] = true
			_throw(angle, power)
		else:
			_finisher_launch(angle, power)
		return
	if state != State.PLAYER_AIM:
		return
	_aim.finish()
	_turn_timer = -1.0
	_hud.set_timer(-1)
	_throw(angle, power)


func _throw(angle: float, power: float) -> void:
	_hud.hide_tip()
	# A full Mana Analysis shows the drop guide too, and is then used up.
	_drop_guide = _analysis[current] >= ANALYSIS_STEPS
	if _drop_guide:
		_analysis[current] = 0
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
		_consume_special(fighter)
	if special == &"beam":
		fighter.powered = false
		_fire_beam(fighter, angle, special)
		return
	if special in [&"thunder", &"ricochet", &"batbombs"]:
		fighter.powered = false
		_hero_throw(fighter, special, angle, power)
		return
	if special in [&"fuga", &"gou", &"rain", &"dogs", &"purple", &"shinku", &"webyank"]:
		fighter.powered = false
		_new_special(fighter, special, angle, power)
		return
	if special == &"knifestorm":
		fighter.powered = false
		_knife_storm(fighter, angle, power)
		return
	if special == &"barrage_zoltraak":
		fighter.powered = false
		_zoltraak_barrage(fighter, angle)
		return
	if special == &"icefall":
		fighter.powered = false
		_start_icefall(fighter)
		return
	if special in INSTANT_SPECIALS:
		_apply_instant_special(fighter, special)
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
	# Subaro can't cast a thing himself: Beatris throws the magic for him.
	if fighter.data.base_id() == &"subaro" and special == &"":
		_cameo(fighter, &"beatris", 80.0, "Betty will help, I suppose.", 0.0)
	if _lucky[current] > 0:
		var shot := _lucky_shot(fighter)
		angle = shot["angle"]
		power = shot["power"]
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
		if special == &"elephant":
			projectile.explode_radius = ELEPHANT_RADIUS
			projectile.set_meta("elephant", true)
		if special == &"bigboom":
			projectile.explode_radius *= 1.6
		if special == &"chop" or special == &"suck":
			projectile.set_meta(special, true)
		projectile.exploded.connect(_on_projectile_exploded)
		projectile.hit_fighter.connect(_on_projectile_hit)
		projectile.hit_ground.connect(_on_projectile_hit_ground)
		projectile.hit_crate.connect(_on_projectile_hit_crate)
		projectile.hit_target.connect(_on_practice_target_hit)
		_basic_traits(projectile, weapon, fighters[1 - current])
		# Blue drags the enemy toward it as it flies.
		if weapon.shape == &"blue_orb":
			projectile.set_meta("blue", true)
		if _lucky[current] > 0:
			_make_lucky(projectile)
		if _empowered[current] > 0:
			projectile.explode_radius = VOLL_RADIUS
			projectile.set_meta("voll", true)
			projectile.set_trail_color(Color(0.75, 0.9, 1.0))
		if _hud.time_stopped() and fighter == _stopper:
			projectile.stop_short = true
			projectile.set_meta("timestop", true)
			projectile.stopped_short.connect(_on_stopped_short)
		if weapon.id == &"zoltraak" and special == &"" and i == 0:
			_arm_drop_orb(projectile, fighter)
		if fighter.powered:
			projectile.set_meta("double", true)
		projectile.finished.connect(_on_projectile_finished)
		_in_flight.append(projectile)
	fighter.powered = false
	if _lucky[current] > 0:
		_lucky[current] -= 1
	if _empowered[current] > 0:
		_empowered[current] -= 1
		if _empowered[current] == 0:
			fighter.form = &""


## scale (bomb blasts fall off with distance) and push (the blast direction) are
## only used by explosions.
func _on_projectile_hit(projectile: Projectile, target: Fighter, part: StringName, scale: float = 1.0, push: Vector2 = Vector2.ZERO) -> void:
	if _special_finisher():
		if target == _finisher["loser"]:
			_resolve_finisher(true)
		return
	# Kyoka Suigetsu: the one they hit was never him. They were standing in his place.
	# Frierin's dropped Zoltraak is a body shot, never a headshot.
	if projectile.get_meta("zoltraak_drop", false):
		part = Rules.BODY
	var mirrored: bool = projectile.get_meta("mirrored", false)
	if target.illusion and projectile.thrower != null and projectile.thrower != target:
		_shatter_illusion(target)
		_steal_buffs(target, projectile.thrower)
		target = projectile.thrower
		mirrored = true
	var side := fighters.find(projectile.thrower)
	# Combo counts turns in a row with at least one hit.
	if side >= 0 and not _turn_hit and not mirrored:
		_turn_hit = true
		_combo[side] += 1
		if side == 0:
			_max_combo = maxi(_max_combo, _combo[side])
		if _combo[side] >= 2:
			_hud.announce("COMBO x%d!" % _combo[side], Color(1.0, 0.55, 0.9))
			Audio.play("cheer", -10.0, 1.1, 0.1)
	var combo: int = _combo[side] if side >= 0 else 0
	var damage := Rules.damage_with_bonuses(projectile.weapon, part, projectile.flight_time, combo)
	damage = roundi(damage * scale * (1.5 if projectile.get_meta("chop", false) else 1.0))
	if projectile.get_meta("beam", false):
		damage = roundi(damage * BEAM_MULTIPLIER)
	if projectile.get_meta("orb", false):
		damage = roundi(damage * ORB_MULTIPLIER)
	if projectile.get_meta("barrage", false):
		damage = maxi(1, roundi(damage * BARRAGE_MULTIPLIER))
	for kind: String in SPECIAL_MULTIPLIERS:
		if projectile.get_meta(kind, false):
			damage = maxi(1, roundi(damage * float(SPECIAL_MULTIPLIERS[kind])))
	if projectile.get_meta("fang", false):
		damage = roundi(damage * FANG_MULTIPLIER)
	if projectile.get_meta("double", false):
		damage *= 2
	# Under Aizon's spiritual pressure their defence is down: his next Reiatsu hits harder.
	var reiatsu: bool = projectile.weapon != null and projectile.weapon.shape in [&"reiatsu", &"dark_hado"] and not mirrored
	if reiatsu and target.pressured:
		damage = roundi(damage * PRESSURE_BONUS)
	if projectile.thrower != null and projectile.thrower.evolved:
		damage = roundi(damage * EVOLVED_DAMAGE)
	# Levels from duplicate chest finds: a little more damage on your side.
	if side >= 0:
		damage = roundi(damage * (1.0 + LEVEL_DAMAGE * _level_of(fighters[side])))
	# Evolved, Aizon shrugs off part of every enemy hit.
	if target.evolved and not mirrored and side >= 0 and side != fighters.find(target):
		damage = maxi(1, roundi(damage * EVOLVED_DEFENCE))
	if target.mana_released and not mirrored and side >= 0 and side != fighters.find(target):
		damage = ceili(damage * MANA_BARRIER)
		Effects.popup(_actors, target.aim_point(true) + Vector2(0, -90), "BARRIER  -%d%%" % roundi((1.0 - MANA_BARRIER) * 100.0), Color(0.7, 0.85, 1.0), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, projectile.global_position, Color(0.7, 0.85, 1.0), 26, 420.0, 180.0, 1.2)
		Audio.play("clang", -4.0, 1.5, 0.0)
	if target.shielded:
		target.shielded = false
		Effects.popup(_actors, target.aim_point(true) + Vector2(0, -60), "SHIELD BLOCK!", Color(0.6, 0.85, 1.0), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
		Effects.burst(_actors, projectile.global_position, Color(0.6, 0.85, 1.0), 26, 460.0, 180.0, 1.2)
		Audio.play("tick", 0.0, 0.6, 0.0)
		_camera.shake(0.3)
		return
	# Charge the special meters: the thrower for landing a hit, the target a little.
	if side >= 0 and mode != Mode.PRACTICE and not projectile.get_meta("barrage", false) and not projectile.get_meta("rain", false) and not projectile.get_meta("knifestorm", false) and not projectile.get_meta("timestop", false) and not projectile.get_meta("icefall", false) and not projectile.get_meta("zoltraak", false) and not mirrored:
		_add_charge(side, CHARGE_HEADSHOT if part == Rules.HEAD else CHARGE_HIT)
		_add_charge(1 - side, CHARGE_WHEN_HIT)
	var was_healthy := target.health > LAST_STAND_HEALTH
	var impact := push if push != Vector2.ZERO else projectile.current_velocity()
	target.take_hit(part, maxi(damage, Fighter.KNOCKDOWN_DAMAGE) if projectile.get_meta("chop", false) and target.health > Fighter.KNOCKDOWN_DAMAGE else damage, impact)
	if mirrored and target.is_knocked_out():
		_mirror_ko = true
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
	# Web Yank: dragged in and stuck fast for a turn.
	if projectile.get_meta("webyank", false) and not target.is_knocked_out():
		_pull_fighter(target, projectile.thrower, 380.0)
		target.pinned = true
		_hud.announce("WEBBED!", Color(0.95, 0.95, 1.0))
	if projectile.weapon != null and projectile.weapon.shape in [&"knife", &"iggi"] and not target.is_knocked_out() and rng.randf() < BLEED_CHANCE:
		target.bleed_turns = BLEED_TURNS
		if projectile.weapon.shape == &"iggi":
			Effects.popup(_actors, target.aim_point(true) + Vector2(0, -95), "CHOMP!", Color(1.0, 0.9, 0.85), 34, 1.0 / _camera.zoom.x, _camera.visible_rect())
			Audio.play("crunch", -4.0, 1.4, 0.05)
	if reiatsu and not target.is_knocked_out():
		_build_pressure(target)
	if projectile.get_meta("freeze", false) and not target.is_knocked_out() and not target.pinned:
		target.pinned = true
		_hud.announce("FROZEN!", Color(0.7, 0.9, 1.0))
		Effects.burst(_actors, target.aim_point(false), Color(0.8, 0.95, 1.0), 30, 400.0, 180.0, 1.4)
	if projectile.get_meta("fuga", false) and not target.is_knocked_out():
		target.burn_turns = BURN_TURNS
		_hud.announce("BURNING!", Color(1.0, 0.5, 0.15))
	if projectile.get_meta("pin", false) and not target.is_knocked_out():
		target.pinned = true
		_hud.announce("PINNED!", Color(0.75, 0.8, 0.95))
	if was_healthy and target.health > 0 and target.health <= LAST_STAND_HEALTH:
		_hud.announce("LAST STAND!", Color(1.0, 0.35, 0.3))

	_impact_sound(projectile.weapon)
	_ki_burst(projectile)
	var inv_zoom := 1.0 / _camera.zoom.x
	var view := _camera.visible_rect()
	var at := projectile.global_position
	match part:
		Rules.HEAD:
			Audio.play("hit_head")
			Audio.play("cheer", -8.0, 1.0, 0.1)
			Device.vibrate(60)
			Effects.burst(_actors, at, Color(1.0, 0.88, 0.3), 22, 520.0, 180.0, 1.2)
			Effects.popup(_actors, target.aim_point(true) + Vector2(0, -60), "HEADSHOT!  -%d" % damage, Color(1.0, 0.85, 0.2), 40, inv_zoom, view)
			if not target.is_knocked_out() and rng.randf() < 0.5:
				_say(projectile.thrower as Fighter, Taunts.hit_line((projectile.thrower as Fighter).data.base_id(), rng))
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
	# A wet splat on top of solid hits (blood or ink, per the Gore setting).
	if damage >= 18:
		Audio.play("splat", -8.0 + minf(damage, 60) * 0.1, randf_range(0.9, 1.2), 0.0)
	if target.is_knocked_out():
		Audio.play("ko", 0.0, 1.0, 0.0)
		Audio.play("cheer", -2.0, 1.0, 0.0)
		Audio.play("gore", -2.0, 1.0, 0.0)
		Device.vibrate(140)
		Effects.popup(_actors, target.aim_point(true) + Vector2(0, -150), "K.O.!", Color(1.0, 0.4, 0.3), 80, inv_zoom, view)
		_camera.shake(1.0)
		_slow_time(1.1, 0.3)


func _on_projectile_hit_ground(projectile: Projectile, collider: Object) -> void:
	var weapon := projectile.weapon
	var at := projectile.global_position
	_ki_burst(projectile)
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
	if _special_finisher():
		if _in_flight.is_empty() and not _launching:
			_resolve_finisher(false)
		return
	if not _in_flight.is_empty() or _launching or state != State.FLYING:
		return
	_after_throw()


## Mega Wave: gather energy, then fire a straight beam. It smashes through obstacles
## and stops at the first fighter (or the ground) it meets.
func _fire_beam(fighter: Fighter, angle: float, kind: StringName = &"beam") -> void:
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
	var struck_target: PracticeTarget = null
	var smashed: Array[Obstacle] = []
	for step in 8:
		var query := PhysicsRayQueryParameters2D.create(from, origin + direction * BEAM_RANGE, 0b1011, exclude)
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
		struck_target = collider as PracticeTarget
		break
	var beam := Beam.new()
	# Hollow Purple and the Shinku Hadoken are fatter beams in their own colours.
	var beam_color := fighter.data.weapon.color
	if kind == &"purple":
		beam_color = Color(0.72, 0.3, 1.0)
		beam.width_scale = 1.9
	elif kind == &"shinku":
		beam_color = Color(0.4, 0.75, 1.0)
		beam.width_scale = 1.5
	beam.setup(origin, end, beam_color)
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
		carrier.set_meta("purple" if kind == &"purple" else "beam", true)
		_on_projectile_hit(carrier, victim, part, 1.0, direction * 1500.0 + Vector2(0, -300))
		carrier.free()
	if struck_target != null and is_instance_valid(struck_target):
		var marker := Projectile.new()
		marker.weapon = fighter.data.weapon
		marker.thrower = fighter
		marker.position = end
		_on_practice_target_hit(marker, struck_target)
		marker.free()
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
	# A special used for the finishing throw: whatever happened, the finisher is decided.
	if not _finisher.is_empty():
		if not _finisher["done"]:
			_resolve_finisher(false)
		return
	# Aizon's pressure needs hits in a row: a miss loses it all.
	if not _turn_hit and fighters[current].data.base_id() == &"aizon":
		var foe := fighters[1 - current]
		foe.pressure_stacks = 0
		foe.pressured = false
	state = State.SETTLING
	if not _turn_hit:
		_combo[current] = 0
		if fighters[current].mana_released:
			_analysis[current] = mini(_analysis[current] + 1, ANALYSIS_STEPS)
		if _throw_closest < CLOSE_CALL_DISTANCE and _held.is_empty():
			_hud.announce("SO CLOSE!", Color(1.0, 0.85, 0.4))
	if mode == Mode.PRACTICE and _hud.time_stopped():
		# Practice moves on after every throw, so time stop ends with it.
		_time_stop_left = 0
		_resume_time()
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
	_unswap()
	for fighter in fighters:
		if fighter.is_knocked_out():
			_end_match()
			return
	if _time_stop_left > 0:
		_time_stop_left -= 1
		_hud.announce("TIME IS STOPPED  ·  %d MORE" % (_time_stop_left + 1), Color(0.8, 0.7, 1.0))
	elif _hud.time_stopped():
		_resume_time()
		if not _held.is_empty():
			_release_held()
			return
		current = 1 - current
	elif _extra_throw:
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
	# The winner gets one finishing throw at the dazed loser. A hit earns the fatality
	# (tap skips it); a miss goes straight to the result.
	var fatality_id := _match_id
	var landed := false
	if (_special_this_turn and winner == fighters[current]) or _mirror_ko:
		# Knocked out by a special (or by Kyoka Suigetsu): that counts as the finisher.
		loser.stand_dazed()
		_hud.announce("SPECIAL FINISH!", Color(0.95, 0.15, 0.18))
		Audio.play("ko", -2.0, 0.7, 0.0)
		await get_tree().create_timer(FINISHER_DELAY, false).timeout
		landed = fatality_id == _match_id
	else:
		landed = await _finisher_throw(winner, loser)
	if fatality_id != _match_id:
		return
	if landed:
		# A hit's brief slow-motion may still be running; end it so the fatality
		# doesn't take the slowed speed as normal and leave the game slow after.
		_end_slow_time()
		var fatality := Fatality.new()
		fatality.setup(winner, loser, _camera, _hud, Save.gore)
		_actors.add_child(fatality)
		fatality.play(false)
		if not fatality.is_done():
			await fatality.finished
		if fatality_id != _match_id:
			return
	else:
		_hud.announce("MISSED THE FINISHER!", Color(0.8, 0.82, 0.9))
		await get_tree().create_timer(1.0, false).timeout
		if fatality_id != _match_id:
			return
	state = State.GAME_OVER
	var winner_side := fighters.find(winner)
	winner.victory(landed)
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
	return special in [&"beam", &"fang", &"purple", &"shinku", &"gou", &"fuga", &"webyank", &"barrage_zoltraak"]


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
		projectile.homing_target = _practice_target if mode == Mode.PRACTICE else fighters[1 - current]
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
	# Hollow Purple erases obstacles outright; everything else cuts a chunk out.
	var devour: bool = projectile.get_meta("devour", false)
	obstacle.damage(999 if devour else 2)
	var at := projectile.global_position
	Effects.burst(_actors, at, projectile.weapon.color.lightened(0.3), 24, 520.0, 180.0, 1.2)
	Effects.popup(_actors, at + Vector2(0, -50), "ERASED!" if devour else "SLICED!", Color(1.0, 0.45, 0.45), 30, 1.0 / _camera.zoom.x, _camera.visible_rect())
	Audio.play("thunk", 0.0, 0.5, 0.0)
	_camera.shake(0.35)


## After a knockout: the loser staggers up and the winner gets one throw at them, like
## Bowmasters. Returns true if it hit (the fatality then plays), false on a miss.
func _finisher_throw(winner: Fighter, loser: Fighter) -> bool:
	var match_id := _match_id
	loser.stand_dazed()
	_hud.announce("FINISH THEM!", Color(0.95, 0.15, 0.18))
	Audio.play("ko", -2.0, 0.7, 0.0)
	await get_tree().create_timer(FINISHER_DELAY, false).timeout
	if match_id != _match_id:
		return false
	current = fighters.find(winner)
	winner.holding_weapon = true
	winner.is_turn = true
	_finisher = {"loser": loser, "in_flight": 0, "hit": false, "done": false}
	state = State.FINISHER
	if winner.is_ai:
		var brain := _brains[current]
		var shot := brain.aim(winner.throw_origin(), loser.aim_point(brain.wants_headshot()), winner.data.weapon.max_speed, winner.facing, _obstacle_rects, _wind_for(winner), Rules.GRAVITY * winner.data.weapon.gravity_scale)
		winner.aiming = true
		var wind_up := winner.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		wind_up.tween_property(winner, "aim_angle", float(shot["angle"]), AI_THINK_TIME * 0.8)
		wind_up.tween_property(winner, "aim_power", float(shot["power"]), AI_THINK_TIME * 0.8)
		await get_tree().create_timer(AI_THINK_TIME, false).timeout
		if match_id != _match_id:
			return false
		_finisher_launch(shot["angle"], shot["power"])
	else:
		_hud.set_turn("FINISH THEM!", Color(0.95, 0.15, 0.18))
		_special_armed = false
		_hud.set_special(winner.data, _charge[current], false)
		_aim.wind = _wind_for(winner)
		_aim.begin(winner)
	if not _finisher["done"]:
		await finisher_resolved
	if match_id != _match_id:
		return false
	winner.is_turn = false
	_hud.set_turn("")
	return _finisher["hit"]


## Throws the finishing shot (no special). It only counts if it touches the loser.
func _finisher_launch(angle: float, power: float) -> void:
	if _finisher.is_empty() or _finisher["done"]:
		return
	var winner := fighters[current]
	var weapon := winner.data.weapon
	winner.play_throw()
	var sound: Array = THROW_SOUNDS.get(weapon.shape, ["whoosh", 1.0])
	Audio.play(sound[0], -2.0, sound[1])
	for i in weapon.count:
		var offset := (i - (weapon.count - 1) / 2.0) * weapon.spread_deg
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(weapon, winner, winner.throw_origin(), Rules.launch_velocity(angle + offset, power, weapon.max_speed, winner.facing), _wind_for(winner))
		projectile.target = _finisher["loser"]
		_basic_traits(projectile, weapon, _finisher["loser"])
		_hook_finisher(projectile)
		if weapon.id == &"zoltraak" and i == 0:
			_drop_guide = false
			_arm_drop_orb(projectile, winner)
	state = State.FLYING




## What a fighter's basic throw always does, in a match or a finishing throw: Nue and
## Egita's ki bend in on the enemy as they get close.
func _basic_traits(projectile: Projectile, weapon: WeaponData, foe: Fighter) -> void:
	if weapon.shape == &"nue":
		projectile.homing_target = foe
		projectile.homing_range = 260.0
		projectile.homing_turn = 2.2
	elif weapon.id == &"ki_orb":
		projectile.homing_target = foe
		projectile.homing_range = KI_HOMING_RANGE
		projectile.homing_turn = KI_HOMING_TURN


## A finishing-throw projectile: touching the loser earns the fatality; once every one
## is gone without that, the finisher missed.
func _hook_finisher(projectile: Projectile) -> void:
	projectile.hit_fighter.connect(func(p: Projectile, who: Fighter, _part: StringName) -> void:
		if who == _finisher["loser"]:
			Effects.burst(_actors, p.global_position, Color(1, 1, 1, 0.9), 14, 420.0)
			Audio.play("hit_body", 0.0, 0.9, 0.0)
			_camera.shake(0.5)
			_resolve_finisher(true))
	projectile.exploded.connect(func(p: Projectile, at: Vector2, _direct: Fighter, _part: StringName, _collider: Object) -> void:
		if not _finisher.is_empty() and (_finisher["loser"] as Fighter).aim_point(false).distance_to(at) < p.explode_radius + 30.0:
			_resolve_finisher(true))
	projectile.finished.connect(func(p: Projectile) -> void:
		_in_flight.erase(p)
		if _finisher.is_empty():
			return
		_finisher["in_flight"] -= 1
		if _finisher["in_flight"] <= 0:
			_resolve_finisher(false))
	_finisher["in_flight"] += 1
	_in_flight.append(projectile)


## A finishing throw made with a special is in progress.
func _special_finisher() -> bool:
	return not _finisher.is_empty() and not _finisher["done"] and _finisher.get("special", false)
## Ends the finishing throw once: hit (true) or every projectile gone (false).
func _resolve_finisher(hit: bool) -> void:
	if _finisher.is_empty() or _finisher["done"]:
		return
	_finisher["done"] = true
	_finisher["hit"] = hit
	state = State.GAME_OVER
	finisher_resolved.emit()


## The newer fighters' specials: Fuga, Gou and Shinku Hadoken, Hollow Purple, Licht
## Regen and the Divine Dogs.
func _new_special(fighter: Fighter, special: StringName, angle: float, power: float) -> void:
	match special:
		&"fuga":
			_fuga(fighter, angle)
		&"gou":
			_straight_shot(fighter, angle, &"gou_fireball", 46.0, Color(0.85, 0.1, 0.18), "gou", true, 170.0, 3.4)
		&"shinku":
			_straight_shot(fighter, angle, &"hadoken", 40.0, Color(0.35, 0.7, 1.0), "shinku", true, 150.0, 2.8)
		&"purple":
			_hollow_purple(fighter, angle)
		&"rain":
			_licht_regen(fighter)
		&"dogs":
			_divine_dogs(fighter)
		&"webyank":
			_straight_shot(fighter, angle, &"web_ball", 26.0, Color(0.97, 0.97, 1.0), "webyank", false, 0.0, 1.8)


## Yuj: Sukuna takes over (tattoos and all), then looses a giant fire arrow that burns
## through obstacles and explodes on the enemy.
func _fuga(fighter: Fighter, angle: float) -> void:
	var match_id := _match_id
	fighter.power_up(2.0)
	Effects.burst(_actors, fighter.aim_point(true), Color(0.8, 0.1, 0.12), 30, 420.0, 180.0, 1.4)
	_launching = true
	await get_tree().create_timer(0.6, false).timeout
	_launching = false
	if match_id != _match_id:
		return
	_straight_shot(fighter, angle, &"fire_arrow", 64.0, Color(1.0, 0.5, 0.15), "fuga", true, 200.0, 2.2)


## A big special projectile that flies dead straight; it can burn through obstacles
## and explodes on whatever stops it.
func _straight_shot(fighter: Fighter, angle: float, shape: StringName, size: float, color: Color, meta: String, pierce: bool, blast: float, size_scale: float) -> Projectile:
	fighter.play_throw()
	var shot := fighter.data.weapon.duplicate() as WeaponData
	shot.shape = shape
	shot.size = size
	shot.color = color
	shot.spin = 0.0
	shot.sticks = false
	shot.gravity_scale = 0.0
	shot.explode_radius = blast
	shot.pull_target = 0.0
	Audio.play("whoosh", 0.0, 0.5, 0.0)
	_camera.shake(0.4)
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	_actors.add_child(projectile)
	projectile.launch(shot, fighter, fighter.throw_origin(), Rules.launch_velocity(angle, 1.0, FANG_SPEED, fighter.facing), 0.0)
	projectile.scale = Vector2.ONE * size_scale
	projectile.target = fighters[1 - current]
	projectile.pierce = pierce
	projectile.set_meta(meta, true)
	projectile.set_trail_color(color)
	_track(projectile)
	return projectile


## Goj: Hollow Purple flies dead straight and devours everything in its path: every
## obstacle it touches is erased outright, and it still drags the enemy toward it as
## it closes in, before bursting on them.
func _hollow_purple(fighter: Fighter, angle: float) -> void:
	fighter.power_up(1.5)
	var projectile := _straight_shot(fighter, angle, &"blue_orb", 30.0, Color(0.72, 0.3, 1.0), "purple", true, PURPLE_RADIUS, 2.6)
	projectile.set_meta("devour", true)
	Audio.play("whoosh", 2.0, 0.3, 0.0)


## Hollow Purple and Blue both pull: each tick one is in flight, the enemy slides toward
## it, faster the nearer it is. They are never dragged into the obstacles in the middle.
func _pull_toward_purple(delta: float) -> void:
	for projectile in _in_flight:
		if not is_instance_valid(projectile) or not projectile.is_flying():
			continue
		var purple: bool = projectile.get_meta("purple", false)
		if not purple and not projectile.get_meta("blue", false):
			continue
		var target := projectile.target
		if target == null or target.is_knocked_out():
			continue
		var reach := PURPLE_PULL_RANGE if purple else BLUE_PULL_RANGE
		var distance := projectile.global_position.distance_to(target.aim_point(false))
		if distance > reach:
			continue
		var strength := 1.0 - distance / reach
		var speed := PURPLE_PULL_SPEED if purple else BLUE_PULL_SPEED
		var x := move_toward(target.position.x, projectile.global_position.x, speed * strength * delta)
		var nearest := 450.0
		for box in _obstacle_rects:
			nearest = maxf(nearest, maxf(absf(box.position.x), absf(box.end.x)) + 150.0)
		if absf(x) < nearest:
			x = signf(target.position.x) * nearest
		target.position = Vector2(x, Terrain.height_at(x))
		target._tilt_velocity += signf(projectile.global_position.x - x) * strength * 0.6


## Uryo: a storm of spirit arrows falls out of the sky right over the target, each
## arrow bending toward them as it comes down.
func _licht_regen(fighter: Fighter) -> void:
	var weapon := fighter.data.weapon
	var target := fighters[1 - current]
	var match_id := _match_id
	fighter.play_throw()
	_launching = true
	for i in RAIN_ARROWS:
		var aim: Vector2 = _practice_target.global_position if mode == Mode.PRACTICE and _practice_target != null and is_instance_valid(_practice_target) else target.aim_point(false)
		var from := Vector2(aim.x + rng.randf_range(-RAIN_SPREAD, RAIN_SPREAD), aim.y - 1100.0)
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(weapon, fighter, from, Vector2((aim.x - from.x) * 0.9, 1250.0), 0.0)
		projectile.target = target
		projectile.homing_target = _practice_target if mode == Mode.PRACTICE else target
		projectile.homing_range = 200.0
		projectile.homing_turn = 2.5
		projectile.set_meta("rain", true)
		projectile.set_trail_color(weapon.color)
		_track(projectile)
		Audio.play("twang", -8.0, rng.randf_range(1.1, 1.4), 0.0)
		await get_tree().create_timer(0.07, false).timeout
		if match_id != _match_id:
			return
	_launching = false
	if _in_flight.is_empty() and state == State.FLYING:
		_after_throw()


## Megu: two shadow wolves, one white and one black, burst out of his shadow, race
## across the ground and maul the enemy.
func _divine_dogs(fighter: Fighter) -> void:
	var match_id := _match_id
	var target := fighters[1 - current]
	var goal_x: float = _practice_target.global_position.x if mode == Mode.PRACTICE and _practice_target != null and is_instance_valid(_practice_target) else target.global_position.x
	# Obstacles standing on the ground stop the dogs: they maul the obstacle instead.
	var blocker: Obstacle = null
	for child in _obstacle_layer.get_children():
		var obstacle := child as Obstacle
		if obstacle == null or obstacle.is_destroyed or obstacle.kind == &"floating":
			continue
		var near_edge := obstacle.rect.position.x if fighter.facing > 0 else obstacle.rect.end.x
		if (near_edge - fighter.global_position.x) * fighter.facing > 0.0 and (goal_x - near_edge) * fighter.facing > 0.0:
			if blocker == null or absf(near_edge - fighter.global_position.x) < absf(goal_x - fighter.global_position.x):
				blocker = obstacle
				goal_x = near_edge - fighter.facing * 10.0
	fighter.play_throw()
	Audio.play("ko", -4.0, 1.4, 0.0)
	_launching = true
	var running := {"left": 2}
	for dog in 2:
		var white := dog == 0
		var wolf := Node2D.new()
		wolf.z_index = 6
		var start_x := fighter.global_position.x + fighter.facing * 30.0
		var gait := {"t": 0.0}
		wolf.draw.connect(func() -> void:
			var fur := Color(0.95, 0.95, 0.97) if white else Color(0.06, 0.05, 0.1)
			var step: float = sin(float(gait["t"]) * 30.0) * 7.0
			var f := float(fighter.facing)
			var body := PackedVector2Array([Vector2(-30 * f, -26), Vector2(18 * f, -32), Vector2(30 * f, -26), Vector2(26 * f, -16), Vector2(-28 * f, -14)])
			wolf.draw_colored_polygon(body, fur)
			wolf.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[0]]), Color(0.06, 0.055, 0.07), 2.0, true)
			var head := PackedVector2Array([Vector2(24 * f, -30), Vector2(34 * f, -46), Vector2(40 * f, -38), Vector2(52 * f, -34), Vector2(40 * f, -24)])
			wolf.draw_colored_polygon(head, fur)
			wolf.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[4], head[0]]), Color(0.06, 0.055, 0.07), 2.0, true)
			wolf.draw_circle(Vector2(40 * f, -34), 2.0, Color(0.9, 0.2, 0.2) if white else Color(0.95, 0.85, 0.3), true, -1.0, true)
			for leg in 4:
				var lx := (-22.0 + leg * 14.0) * f
				var swing := step if leg % 2 == 0 else -step
				wolf.draw_line(Vector2(lx, -16), Vector2(lx + swing * f, 0), Color(0.06, 0.055, 0.07), 4.0, true)
			wolf.draw_polyline(PackedVector2Array([Vector2(-30 * f, -24), Vector2(-44 * f, -32), Vector2(-50 * f, -26)]), fur, 4.0, true))
		wolf.scale = Vector2.ONE * 1.6
		_actors.add_child(wolf)
		var run := wolf.create_tween()
		var seconds := absf(goal_x - start_x) / DOG_SPEED
		run.tween_interval(dog * 0.25)
		run.tween_method(func(x: float) -> void:
			gait["t"] = x / DOG_SPEED
			wolf.position = Vector2(x, Terrain.height_at(x))
			wolf.queue_redraw(), start_x, goal_x - fighter.facing * 20.0, seconds)
		run.tween_callback(func() -> void:
			if match_id != _match_id:
				return
			if blocker != null and is_instance_valid(blocker):
				blocker.damage(1)
				Effects.popup(_actors, wolf.position + Vector2(0, -80), "BLOCKED!", Color(0.85, 0.9, 1.0), 26, 1.0 / _camera.zoom.x, _camera.visible_rect())
				Audio.play("thunk", 0.0, 0.8, 0.0)
			else:
				_dog_bite(fighter, target, wolf.position)
			var fade := wolf.create_tween()
			fade.tween_property(wolf, "modulate:a", 0.0, 0.3)
			fade.tween_callback(wolf.queue_free)
			running["left"] = int(running["left"]) - 1
			if int(running["left"]) <= 0:
				_launching = false
				var settle := get_tree().create_timer(0.5, false)
				settle.timeout.connect(func() -> void:
					if match_id == _match_id and state == State.FLYING and _in_flight.is_empty():
						_after_throw()))
	state = State.FLYING


## One Divine Dog sinking its teeth in.
func _dog_bite(fighter: Fighter, target: Fighter, at: Vector2) -> void:
	Audio.play("hit_body", 2.0, 0.8, 0.0)
	_camera.shake(0.5)
	Effects.burst(_actors, at + Vector2(0, -40), Color(0.75, 0.05, 0.08), 18, 420.0, 180.0, 1.2)
	var carrier := Projectile.new()
	carrier.weapon = fighter.data.weapon
	carrier.thrower = fighter
	carrier.position = at + Vector2(0, -50)
	carrier.set_meta("dogs", true)
	if mode == Mode.PRACTICE:
		if _practice_target != null and is_instance_valid(_practice_target):
			_on_practice_target_hit(carrier, _practice_target)
	elif not target.is_knocked_out():
		_on_projectile_hit(carrier, target, Rules.BODY, 1.0, Vector2(fighter.facing * 500.0, -300.0))
	carrier.free()


## The level of a fighter you control (the AI's fighters are never levelled).
func _level_of(fighter: Fighter) -> int:
	if fighter == null or fighter.is_ai or fighter.data == null:
		return 0
	return Save.fighter_level(String(fighter.data.id))


## The heroes' thrown specials: God of Thunder, Shield Ricochet and Explosive Batarangs.
func _hero_throw(fighter: Fighter, special: StringName, angle: float, power: float) -> void:
	var weapon := fighter.data.weapon
	fighter.play_throw()
	Audio.play("whoosh", 0.0, 0.8, 0.0)
	var count := 3 if special == &"batbombs" else 1
	for i in count:
		var offset := (i - (count - 1) / 2.0) * 6.0
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_actors.add_child(projectile)
		projectile.launch(weapon, fighter, fighter.throw_origin(), Rules.launch_velocity(angle + offset, power, weapon.max_speed, fighter.facing), _wind_for(fighter))
		projectile.target = fighters[1 - current]
		match special:
			&"thunder":
				projectile.explode_radius = THUNDER_RADIUS
				projectile.set_meta("thunder", true)
				projectile.set_trail_color(Color(0.6, 0.8, 1.0))
			&"ricochet":
				projectile.bounces = 3
				projectile.homing_target = fighters[1 - current]
				projectile.homing_range = 420.0
				projectile.homing_turn = 3.0
				projectile.set_meta("ricochet", true)
			&"batbombs":
				projectile.explode_radius = BATBOMB_RADIUS
				projectile.set_meta("batbomb", true)
		_track(projectile)


## Lightning from the sky onto `at` (God of Thunder): a jagged white-blue bolt.
func _lightning(at: Vector2) -> void:
	var bolt := Node2D.new()
	bolt.z_index = 21
	var points := PackedVector2Array([Vector2(at.x + rng.randf_range(-60, 60), at.y - 1400)])
	for k in 12:
		var t := (k + 1) / 12.0
		points.append(Vector2(lerpf(points[0].x, at.x, t) + rng.randf_range(-40, 40) * (1.0 - t), lerpf(points[0].y, at.y, t)))
	bolt.draw.connect(func() -> void:
		bolt.draw_polyline(points, Color(0.6, 0.8, 1.0, 0.45), 26.0, true)
		bolt.draw_polyline(points, Color(0.85, 0.95, 1.0), 9.0, true)
		bolt.draw_polyline(points, Color.WHITE, 3.0, true))
	_actors.add_child(bolt)
	var fade := bolt.create_tween()
	fade.tween_property(bolt, "modulate:a", 0.0, 0.45)
	fade.tween_callback(bolt.queue_free)
	Effects.burst(_actors, at, Color(0.7, 0.88, 1.0), 40, 700.0, 180.0, 1.6)
	Audio.play("hit_head", 4.0, 0.35, 0.0)
	_camera.shake(0.9)
