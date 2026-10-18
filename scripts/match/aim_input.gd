class_name AimInput
extends Node2D
## Player aiming: drag back anywhere and release to throw, or use the keyboard.
## Draws the angle/power readout and a short dotted arc in world space.

signal throw_requested(angle: float, power: float)

const FULL_POWER_DRAG := 260.0
const CANCEL_RADIUS := 28.0
const PREVIEW_TIME := 0.4
const PREVIEW_DOTS := 9
const KEY_ANGLE_SPEED := 45.0
const KEY_POWER_SPEED := 0.5

var fighter: Fighter
var angle := 45.0
var power := 0.6

var _active := false
var _dragging := false
## True while a drag is still inside the cancel circle; releasing then throws nothing.
var _cancelling := false
var _drag_start := Vector2.ZERO


func begin(for_fighter: Fighter) -> void:
	fighter = for_fighter
	_active = true
	_dragging = false
	_cancelling = false
	show()


func finish() -> void:
	_active = false
	_dragging = false
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_cancelling = true
			_drag_start = button.position
		elif _dragging:
			_dragging = false
			if not _cancelling:
				_throw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_apply_drag(_drag_start - (event as InputEventMouseMotion).position)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_throw()
		get_viewport().set_input_as_handled()


func _apply_drag(drag: Vector2) -> void:
	_cancelling = drag.length() < CANCEL_RADIUS
	if _cancelling:
		return
	angle = clampf(rad_to_deg(atan2(-drag.y, drag.x * fighter.facing)), Rules.MIN_ANGLE, Rules.MAX_ANGLE)
	power = clampf(drag.length() / FULL_POWER_DRAG, 0.05, 1.0)


func _throw() -> void:
	_cancelling = false
	throw_requested.emit(angle, power)


func _process(delta: float) -> void:
	if not _active:
		return
	angle = clampf(angle + Input.get_axis("ui_down", "ui_up") * KEY_ANGLE_SPEED * delta, Rules.MIN_ANGLE, Rules.MAX_ANGLE)
	power = clampf(power + Input.get_axis("ui_left", "ui_right") * KEY_POWER_SPEED * delta, 0.05, 1.0)
	queue_redraw()


func _draw() -> void:
	if fighter == null:
		return
	var camera := get_viewport().get_camera_2d()
	var inv_zoom := 1.0 / camera.zoom.x if camera else 1.0
	var faded := _dragging and _cancelling
	var alpha := 0.35 if faded else 1.0
	var origin := fighter.throw_origin()
	var velocity := Rules.launch_velocity(angle, power, fighter.data.weapon.max_speed, fighter.facing)
	for i in range(1, PREVIEW_DOTS + 1):
		var t := PREVIEW_TIME * i / PREVIEW_DOTS
		var fade := 1.0 - float(i) / (PREVIEW_DOTS + 2)
		draw_circle(Rules.position_at(origin, velocity, t), (5.0 - i * 0.3) * inv_zoom, Color(1, 1, 1, alpha * fade))

	var font := ThemeDB.fallback_font
	var font_size := int(26 * inv_zoom)
	var text := "release to cancel" if faded else "%d°   %d%%" % [roundi(angle), roundi(power * 100)]
	var width := 300.0 * inv_zoom
	var at := fighter.global_position + Vector2(-width / 2, -150.0 - 14.0 * inv_zoom)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, int(7 * inv_zoom), Color(0.12, 0.1, 0.14, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(1, 1, 1, alpha))
