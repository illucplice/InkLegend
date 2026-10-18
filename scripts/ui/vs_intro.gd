class_name VsIntro
extends Control
## The "A vs B" splash before a match: two slanted colour panels slide in with
## each fighter, "VS" pops in the middle, then "FIGHT!" and it all fades away.

signal finished

const INK := Color(0.12, 0.1, 0.14)
const SLIDE_TIME := 0.4
const HOLD_TIME := 1.0
const FIGHT_TIME := 0.6

var _colors: Array[Color] = []
var _slide := 0.0
var _vs_scale := 0.0
var _sides: Array[Control] = []
var _vs_label: Label
var _fight_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func play(left: FighterData, right: FighterData, left_name: String, right_name: String) -> void:
	for child in get_children():
		child.queue_free()
	_sides.clear()
	_colors = [left.body_color, right.body_color]
	for i in 2:
		var data := left if i == 0 else right
		var side := VBoxContainer.new()
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.add_theme_constant_override("separation", 4)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(300, 330)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fighter: Fighter = preload("res://scenes/fighter/fighter.tscn").instantiate()
		holder.add_child(fighter)
		fighter.setup(data, 1 if i == 0 else -1, false, false)
		fighter.scale = Vector2(2.2, 2.2)
		fighter.aiming = true
		fighter.aim_angle = 50.0
		fighter.aim_power = 0.7
		holder.resized.connect(func() -> void:
			fighter.position = Vector2(holder.size.x / 2, holder.size.y - 10)
			fighter.reset_physics_interpolation())
		side.add_child(holder)
		var name_label := UiStyle.game_label(data.display_name, 40, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_child(name_label)
		var player := UiStyle.game_label(left_name if i == 0 else right_name, 24)
		player.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_child(player)
		add_child(side)
		_sides.append(side)
	_vs_label = UiStyle.game_label("VS", 130, true)
	_vs_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_vs_label.add_theme_constant_override("outline_size", 26)
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_vs_label)
	_fight_label = UiStyle.game_label("FIGHT!", 150, true)
	_fight_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	_fight_label.add_theme_constant_override("outline_size", 28)
	_fight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fight_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fight_label.modulate.a = 0.0
	add_child(_fight_label)

	show()
	modulate.a = 1.0
	_slide = 0.0
	_vs_scale = 0.0
	_layout()
	Audio.play("whoosh", 0.0, 0.8, 0.0)
	var tween := create_tween()
	tween.tween_method(_set_slide, 0.0, 1.0, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Audio.play.bind("hit_head", -2.0, 0.8, 0.0))
	tween.tween_method(_set_vs, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_callback(_show_fight)
	tween.tween_interval(FIGHT_TIME)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_done)


func _set_slide(value: float) -> void:
	_slide = value
	_layout()


func _set_vs(value: float) -> void:
	_vs_scale = value
	_layout()


func _show_fight() -> void:
	Audio.play("win", -4.0, 1.3, 0.0)
	_vs_label.hide()
	for side in _sides:
		side.modulate.a = 0.35
	_fight_label.pivot_offset = _fight_label.size / 2
	_fight_label.scale = Vector2(2.0, 2.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_fight_label, "modulate:a", 1.0, 0.12)
	tween.tween_property(_fight_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _done() -> void:
	hide()
	finished.emit()


func _layout() -> void:
	var half := size.x / 2
	for i in _sides.size():
		var side := _sides[i]
		side.size = Vector2(half * 0.8, size.y * 0.8)
		var rest_x := half * 0.1 if i == 0 else half * 1.1
		var start_x := -half if i == 0 else size.x
		side.position = Vector2(lerpf(start_x, rest_x, _slide), size.y * 0.08)
	_vs_label.size = Vector2(300, 200)
	_vs_label.position = size / 2 - _vs_label.size / 2
	_vs_label.pivot_offset = _vs_label.size / 2
	_vs_label.scale = Vector2.ONE * _vs_scale
	_fight_label.size = Vector2(700, 240)
	_fight_label.position = size / 2 - _fight_label.size / 2
	queue_redraw()


func _draw() -> void:
	if _colors.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.12, 0.55 * _slide))
	var half := size.x / 2
	var slant := size.y * 0.12
	var offset := (1.0 - _slide) * (half + slant)
	var left := PackedVector2Array([
		Vector2(-offset, 0), Vector2(half + slant - offset, 0), Vector2(half - slant - offset, size.y), Vector2(-offset, size.y),
	])
	var right := PackedVector2Array([
		Vector2(half + slant + offset, 0), Vector2(size.x + offset, 0), Vector2(size.x + offset, size.y), Vector2(half - slant + offset, size.y),
	])
	draw_colored_polygon(left, Color(_colors[0].darkened(0.15), 0.9))
	draw_colored_polygon(right, Color(_colors[1].darkened(0.15), 0.9))
	# Speed streaks for energy.
	for i in 8:
		var y := size.y * (0.1 + i * 0.11)
		var length := size.x * 0.18
		draw_line(Vector2(half * 0.15 - offset + i * 9, y), Vector2(half * 0.15 + length - offset + i * 9, y), Color(1, 1, 1, 0.12), 6.0)
		draw_line(Vector2(size.x - half * 0.15 + offset - i * 9, y + 30), Vector2(size.x - half * 0.15 - length + offset - i * 9, y + 30), Color(1, 1, 1, 0.12), 6.0)
	draw_line(left[1], left[2], INK, 8.0, true)
	draw_line(right[0], right[3], INK, 8.0, true)
