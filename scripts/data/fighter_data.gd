class_name FighterData
extends Resource
## One fighter in the roster. Adding a fighter means adding a .tres, not code.

@export var id: StringName = &""
@export var display_name: String = ""
@export var short_name: String = ""
@export var body_color: Color = Color.WHITE
@export var accent_color: Color = Color.GRAY
@export var skin_color: Color = Color(1.0, 0.85, 0.7)
## Outfit the greybox draws: viking, rogue, knight or ranger.
@export var style: StringName = &"viking"
@export var cape_color: Color = Color(0.6, 0.2, 0.2)
@export var hair_color: Color = Color(0.35, 0.22, 0.12)
@export var weapon: WeaponData
@export var special_name: String = ""
@export_multiline var special_description: String = ""
@export var unlocked_by_default: bool = false
