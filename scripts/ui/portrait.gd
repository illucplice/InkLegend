class_name Portrait
extends Control
## A fighter's head and shoulders in a framed badge, for the HUD and VS splash.

const INK := Color(0.12, 0.1, 0.14)

var _fighter: Fighter
var _zoom := 1.0
var _color := Color.WHITE


static func make(data: FighterData, facing: int, badge_size: float = 72.0) -> Portrait:
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(badge_size, badge_size)
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait._zoom = badge_size / 64.0
	portrait._color = data.body_color
	var fighter: Fighter = preload("res://scenes/fighter/fighter.tscn").instantiate()
	portrait.add_child(fighter)
	fighter.setup(data, facing, false, false)
	fighter.scale = Vector2.ONE * portrait._zoom * 0.95
	portrait._fighter = fighter
	portrait.resized.connect(portrait._place)
	return portrait


func _place() -> void:
	# Centre the head, a little above the middle so the shoulders show.
	var head := Fighter.HEAD_CENTER * _fighter.scale.y
	_fighter.position = Vector2(size.x / 2, size.y * 0.42 - head.y)
	_fighter.reset_physics_interpolation()


func _draw() -> void:
	draw_style_box(UiStyle.flat(_color.lerp(Color.WHITE, 0.55), 14), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(_color, 0.35))


## The border is a child Panel added last, so it draws on top of the fighter.
func _ready() -> void:
	var frame := Panel.new()
	var border := UiStyle.flat(Color(0, 0, 0, 0), 14, 4)
	frame.add_theme_stylebox_override("panel", border)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
