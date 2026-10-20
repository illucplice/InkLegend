class_name MapData
extends Resource
## One arena's look. The Backdrop, Arena and Obstacles read their colours and
## scenery from here, so a new map is a new .tres (plus scenery code if it needs a
## new kind of set piece).

@export var id: StringName = &""
@export var display_name: String = ""
@export var tagline: String = ""
## Main colour for this map's button and ribbon.
@export var accent: Color = Color.WHITE

@export_group("Sky")
@export var sky_top: Color = Color(0.12, 0.09, 0.3)
@export var sky_mid: Color = Color(0.48, 0.24, 0.5)
@export var sky_low: Color = Color(0.97, 0.5, 0.38)
@export var sky_horizon: Color = Color(1.0, 0.78, 0.48)
@export var star_amount: float = 1.0
@export var sun_color: Color = Color(1.0, 0.9, 0.62)
@export var sun_glow: Color = Color(1.0, 0.75, 0.45)
@export var cloud_color: Color = Color(1.0, 0.72, 0.62)
@export var cloud_shade: Color = Color(0.75, 0.38, 0.45)

@export_group("Scenery")
@export var far_color: Color = Color(0.36, 0.22, 0.42)
@export var near_color: Color = Color(0.5, 0.29, 0.43)
## colosseum, forest or volcano: what stands behind the arena.
@export var scenery: StringName = &"colosseum"
## sun or aurora: what lights the sky.
@export var sky_feature: StringName = &"sun"

@export_group("Ground")
@export var ground_top: Color = Color(0.9, 0.72, 0.5)
@export var ground_lip: Color = Color(1.0, 0.86, 0.66)
@export var wall_color: Color = Color(0.5, 0.36, 0.38)
## pillars, ice or basalt: the props standing beside the fighters.
@export var props: StringName = &"pillars"
@export var fire_color: Color = Color(1.0, 0.55, 0.15)
## embers, snow or ash.
@export var weather: StringName = &"embers"

@export_group("Obstacles")
@export var obstacle_stone: Color = Color(0.8, 0.82, 0.88)
@export var obstacle_dark: Color = Color(0.55, 0.57, 0.66)
@export var rune_color: Color = Color(0.45, 0.95, 1.0)

@export_group("Battle")
## How far apart the fighters stand on this map, in metres (picked at random between).
@export var min_distance_m: float = 65.0
@export var max_distance_m: float = 85.0
## How this map's obstacles look: stone, ice, basalt, wood, neon, cloud, sand, bamboo
## or grave.
@export var obstacle_style: StringName = &"stone"
## Obstacle layouts this map picks from (see ObstacleLayout.PATTERNS). Empty = the
## classic stone set.
@export var obstacle_patterns: PackedStringArray = PackedStringArray()
## How hilly the ground is (0 = flat, 1 = rolling hills, more = steeper).
@export var terrain_roughness: float = 1.0
