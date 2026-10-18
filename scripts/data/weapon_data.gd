class_name WeaponData
extends Resource
## One weapon's numbers. Fighters point at one of these; projectiles are set up from it.

@export var id: StringName = &""
@export var display_name: String = ""
## Launch speed at 100% power, in px/s (20 px = 1 m).
@export var max_speed: float = 1300.0
@export var body_damage: int = 20
@export var head_damage: int = 35
## Projectiles per throw (the slingshot fires several).
@export var count: int = 1
## Degrees between projectiles when count > 1.
@export var spread_deg: float = 0.0
## Spin in rad/s while flying. 0 means the projectile points along its path.
@export var spin: float = 0.0
## Stays stuck where it lands instead of disappearing straight away.
@export var sticks: bool = false
## How the greybox draws it: hammer, pebble, spear or arrow.
@export var shape: StringName = &"pebble"
## Drawn length (or diameter for pebbles), in px.
@export var size: float = 30.0
@export var color: Color = Color.WHITE
