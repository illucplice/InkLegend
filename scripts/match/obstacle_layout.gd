class_name ObstacleLayout
extends RefCounted
## Picks a random set of obstacles for the space between the fighters, and only
## keeps layouts where both fighters have at least one clear throw. Each map picks from
## its own list of patterns (MapData.obstacle_patterns), so maps play differently.

const MAX_TRIES := 40
## The classic stone set, used when a map lists no patterns of its own.
const CLASSIC := ["tower", "tower_floating", "wall_floating", "twin_towers", "floating_high", "wall_tower"]
const PATTERNS := ["tower", "tower_floating", "wall_floating", "twin_towers", "floating_high", "wall_tower",
	"spire", "spire_pair", "spire_grove", "spire_wall", "spire_floating", "islands", "islands_tall", "mesa", "mesa_spire", "low_walls"]


## Returns [{"kind": StringName, "rect": Rect2}, ...]. gap is the distance between the
## fighters' feet; max_speed is the slower of the two weapons, so both can clear it.
static func generate(rng: RandomNumberGenerator, gap: float, max_speed: float, patterns: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var pool: Array = Array(patterns) if not patterns.is_empty() else CLASSIC
	for attempt in MAX_TRIES:
		var layout := _pattern(rng, gap, pool[rng.randi_range(0, pool.size() - 1)])
		if _both_sides_clear(layout, gap, max_speed):
			return layout
	var fallback: Array[Dictionary] = [_tower(0.0, 70.0, 180.0)]
	return fallback


static func rects(layout: Array[Dictionary]) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for item in layout:
		boxes.append(item["rect"])
	return boxes


static func _pattern(rng: RandomNumberGenerator, gap: float, pattern: String) -> Array[Dictionary]:
	var spread := gap * 0.5 - 380.0  # keep obstacles well clear of both fighters
	var layout: Array[Dictionary] = []
	match pattern:
		"tower":
			layout.append(_tower(rng.randf_range(-spread, spread) * 0.4, rng.randf_range(80, 110), rng.randf_range(220, 360)))
		"tower_floating":
			var height := rng.randf_range(160, 260)
			var x := rng.randf_range(-spread, spread) * 0.3
			layout.append(_tower(x, rng.randf_range(70, 100), height))
			layout.append(_floating(x + rng.randf_range(-120, 120), -height - rng.randf_range(170, 230), rng.randf_range(180, 260)))
		"wall_floating":
			layout.append(_wall(rng.randf_range(-spread, spread) * 0.3, rng.randf_range(220, 320), rng.randf_range(90, 130)))
			layout.append(_floating(rng.randf_range(-spread, spread) * 0.5, -rng.randf_range(300, 380), rng.randf_range(200, 280)))
		"twin_towers":
			var offset := rng.randf_range(0.35, 0.6) * spread
			layout.append(_tower(-offset, rng.randf_range(70, 95), rng.randf_range(170, 280)))
			layout.append(_tower(offset, rng.randf_range(70, 95), rng.randf_range(170, 280)))
		"floating_high":
			layout.append(_floating(rng.randf_range(-spread, spread) * 0.3, -rng.randf_range(240, 330), rng.randf_range(260, 360)))
		"wall_tower":
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			layout.append(_wall(side * spread * 0.5, rng.randf_range(200, 280), rng.randf_range(90, 120)))
			layout.append(_tower(-side * spread * 0.2, rng.randf_range(80, 100), rng.randf_range(240, 340)))
		"spire":
			layout.append(_spire(rng.randf_range(-spread, spread) * 0.3, rng.randf_range(44, 60), rng.randf_range(300, 420)))
		"spire_pair":
			var offset := rng.randf_range(0.3, 0.55) * spread
			layout.append(_spire(-offset, rng.randf_range(40, 56), rng.randf_range(240, 380)))
			layout.append(_spire(offset, rng.randf_range(40, 56), rng.randf_range(240, 380)))
		"spire_grove":
			var step := rng.randf_range(0.28, 0.4) * spread
			var middle := rng.randf_range(-0.15, 0.15) * spread
			for k in 3:
				layout.append(_spire(middle + (k - 1) * step, rng.randf_range(36, 50), rng.randf_range(200, 400)))
		"spire_wall":
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			layout.append(_wall(side * spread * 0.45, rng.randf_range(180, 260), rng.randf_range(90, 130)))
			layout.append(_spire(-side * spread * 0.2, rng.randf_range(44, 60), rng.randf_range(280, 400)))
		"spire_floating":
			var x := rng.randf_range(-spread, spread) * 0.25
			var height := rng.randf_range(200, 300)
			layout.append(_spire(x, rng.randf_range(44, 56), height))
			layout.append(_floating(x + rng.randf_range(-260, 260), -height - rng.randf_range(160, 230), rng.randf_range(180, 240)))
		"islands":
			var offset := rng.randf_range(0.3, 0.5) * spread
			layout.append(_floating(-offset, -rng.randf_range(200, 300), rng.randf_range(200, 280)))
			layout.append(_floating(offset, -rng.randf_range(330, 430), rng.randf_range(200, 280)))
		"islands_tall":
			var step := rng.randf_range(0.35, 0.5) * spread
			for k in 3:
				layout.append(_floating((k - 1) * step, -rng.randf_range(200, 300) - (k % 2) * 150.0, rng.randf_range(170, 230)))
		"mesa":
			layout.append(_tower(rng.randf_range(-spread, spread) * 0.25, rng.randf_range(170, 240), rng.randf_range(200, 300)))
		"mesa_spire":
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			layout.append(_tower(side * spread * 0.3, rng.randf_range(150, 210), rng.randf_range(180, 260)))
			layout.append(_spire(-side * spread * 0.4, rng.randf_range(44, 56), rng.randf_range(240, 340)))
		"low_walls":
			var offset := rng.randf_range(0.25, 0.5) * spread
			layout.append(_wall(-offset, rng.randf_range(110, 160), rng.randf_range(110, 170)))
			layout.append(_wall(offset, rng.randf_range(110, 160), rng.randf_range(110, 170)))
	return layout


static func _tower(center_x: float, width: float, height: float) -> Dictionary:
	return {"kind": &"tower", "rect": Rect2(center_x - width / 2, -height, width, height)}


static func _wall(center_x: float, width: float, height: float) -> Dictionary:
	return {"kind": &"wall", "rect": Rect2(center_x - width / 2, -height, width, height)}


## A tall thin obstacle: an icicle, mast, cactus, bamboo or dead tree.
static func _spire(center_x: float, width: float, height: float) -> Dictionary:
	return {"kind": &"spire", "rect": Rect2(center_x - width / 2, -height, width, height)}


## bottom_y is the underside of the hanging rock (negative is up). The box is 70 px tall.
static func _floating(center_x: float, bottom_y: float, width: float) -> Dictionary:
	return {"kind": &"floating", "rect": Rect2(center_x - width / 2, bottom_y - 70.0, width, 70.0)}


static func _both_sides_clear(layout: Array[Dictionary], gap: float, max_speed: float) -> bool:
	var boxes := rects(layout)
	for facing: int in [1, -1]:
		var feet := Vector2(-gap / 2 * facing, 0)
		var target_feet := Vector2(gap / 2 * facing, 0)
		var origin := feet + Vector2(Fighter.HAND_REST.x * facing, Fighter.HAND_REST.y)
		var shot := AiAimer.solve(origin, target_feet + Fighter.BODY_CENTER, max_speed, facing, 45.0, boxes)
		if not shot["clear"]:
			return false
	return true
