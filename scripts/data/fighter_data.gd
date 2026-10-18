class_name FighterData
extends Resource
## One fighter in the roster. Adding a fighter means adding a .tres, not code.

@export var id: StringName = &""
@export var display_name: String = ""
@export var short_name: String = ""
@export var body_color: Color = Color.WHITE
@export var accent_color: Color = Color.GRAY
@export var skin_color: Color = Color(1.0, 0.85, 0.7)
@export var weapon: WeaponData
@export var special_name: String = ""
@export_multiline var special_description: String = ""
@export var unlocked_by_default: bool = false
