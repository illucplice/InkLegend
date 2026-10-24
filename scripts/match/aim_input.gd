class_name AimInput
extends Node2D
## Player aiming: drag back anywhere and release to throw, or use the keyboard.
## Draws the angle/power readout and a short dotted arc in world space.

signal throw_requested(angle: float, power: float)

const FULL_POWER_DRAG := 260.0
const CANCEL_RADIUS := 28.0
## Aim guide length in seconds of flight; Settings can make it longer.
const PREVIEW_TIME := 0.55
const LONG_PREVIEW_TIME := 1.1
## How far the guide reaches at the last Mana Analysis step before full.
const ANALYSIS_PREVIEW_TIME := 2.4
const PREVIEW_DOTS := 9
const KEY_ANGLE_SPEED := 45.0
const KEY_POWER_SPEED := 0.5

var fighter: Fighter
var angle := 45.0
var power := 0.6
## Current wind, so the aim guide bends with it.
var wind := 0.0
## Beam special: aim in a straight line, allowed to point below level.
var straight := false
## Time stop: show the whole flight, out to where it lands, with a marker there.
var full_guide := false
## Frierin's Mana Analysis: 0 is the normal guide, 1 reaches all the way.
var guide_boost := 0.0
## Under Aizon's spiritual pressure: no trajectory dots at all.
var hide_guide := false
var min_angle := Rules.MIN_ANGLE
## An armed special: its name shows on the readout and the guide takes its colour.
var special_name := ""
var special_color := Color.WHITE

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
	fighter.aiming = true
	show()


func set_beam(on: bool) -> void:
	straight = on
	min_angle = -25.0 if on else Rules.MIN_ANGLE
	angle = clampf(angle, min_angle, Rules.MAX_ANGLE)
	if not on and angle < Rules.MIN_ANGLE:
		angle = 20.0


## Shows (or clears, with an empty name) that a special is armed for this throw.
func set_special(special: String, color: Color) -> void:
	special_name = special
	special_color = color


func finish() -> void:
	set_beam(false)
	set_special("", Color.WHITE)
	_active = false
	_dragging = false
	if fighter != null:
		fighter.aiming = false
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
	angle = clampf(rad_to_deg(atan2(-drag.y, drag.x * fighter.facing)), min_angle, Rules.MAX_ANGLE)
	power = clampf(drag.length() / FULL_POWER_DRAG, 0.05, 1.0)


func _throw() -> void:
	_cancelling = false
	throw_requested.emit(angle, power)


func _process(delta: float) -> void:
	if not _active:
		return
	angle = clampf(angle + Input.get_axis("ui_down", "ui_up") * KEY_ANGLE_SPEED * delta, min_angle, Rules.MAX_ANGLE)
	power = clampf(power + Input.get_axis("ui_left", "ui_right") * KEY_POWER_SPEED * delta, 0.05, 1.0)
	fighter.aim_angle = angle
	fighter.aim_power = power
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
	if straight:
		var a := deg_to_rad(angle)
		var direction := Vector2(cos(a) * fighter.facing, -sin(a))
		for i in range(1, 22):
			draw_circle(origin + direction * i * 34.0, 6.0 * inv_zoom, Color(fighter.data.weapon.color, alpha * (1.0 - i / 24.0)), true, -1.0, true)
		_draw_angle_arc(origin, inv_zoom, alpha)
		return
	if hide_guide:
		_draw_angle_arc(origin, inv_zoom, alpha)
		_draw_power_gauge(inv_zoom, alpha)
		return
	if full_guide:
		_draw_full_guide(origin, velocity, inv_zoom, alpha)
		_draw_angle_arc(origin, inv_zoom, alpha)
		_draw_power_gauge(inv_zoom, alpha)
		return
	var guide_time := LONG_PREVIEW_TIME if Save.long_aim_guide else PREVIEW_TIME
	guide_time = lerpf(guide_time, ANALYSIS_PREVIEW_TIME, guide_boost)
	var dots := int(PREVIEW_DOTS * guide_time / PREVIEW_TIME)
	for i in range(1, dots + 1):
		var t := guide_time * i / dots
		var fade := 1.0 - float(i) / (dots + 2)
		var dot_color := special_color.lightened(0.3) if not special_name.is_empty() else Color.WHITE
		var dot_size := (5.0 - i * 0.3 * PREVIEW_DOTS / dots) * (1.4 if not special_name.is_empty() else 1.0)
		draw_circle(Rules.position_at(origin, velocity, t, wind, Rules.GRAVITY * fighter.data.weapon.gravity_scale), dot_size * inv_zoom, Color(dot_color, alpha * fade))

	_draw_angle_arc(origin, inv_zoom, alpha)
	_draw_power_gauge(inv_zoom, alpha)

	var font := UiStyle.title_font()
	var font_size := int(26 * inv_zoom)
	var text := "release to cancel" if faded else "%d°   %d%%" % [roundi(angle), roundi(power * 100)]
	if not faded and not special_name.is_empty():
		text = "★ %s   %s" % [special_name.to_upper(), text]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 28.0 * inv_zoom
	var pill := Rect2(fighter.global_position + Vector2(-width / 2, -230.0 * minf(inv_zoom, 1.4) - 38.0 * inv_zoom), Vector2(width, 38.0 * inv_zoom))
	draw_style_box(UiStyle.flat(Color(0.08, 0.05, 0.12, 0.75 * alpha), int(12 * inv_zoom), int(3 * inv_zoom)), pill)
	var baseline := pill.position + Vector2(0, pill.size.y * 0.5 + font_size * 0.36)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(1, 1, 1, alpha))


## An arc from the ground line up to the aim angle, around the hand.
func _draw_angle_arc(origin: Vector2, inv_zoom: float, alpha: float) -> void:
	var radius := 54.0 * inv_zoom
	var a := deg_to_rad(angle)
	var start := 0.0 if fighter.facing == 1 else PI
	var finish := -a if fighter.facing == 1 else PI + a
	draw_arc(origin, radius, start, finish, 24, Color(0.12, 0.1, 0.14, 0.6 * alpha), 7.0 * inv_zoom, true)
	draw_arc(origin, radius, start, finish, 24, Color(1.0, 0.9, 0.5, alpha), 3.5 * inv_zoom, true)
	draw_line(origin, origin + Vector2.from_angle(finish) * radius * 1.25, Color(1, 1, 1, 0.8 * alpha), 2.5 * inv_zoom, true)


## A vertical meter behind the fighter that fills green to yellow to red with power.
func _draw_power_gauge(inv_zoom: float, alpha: float) -> void:
	var height := 110.0 * inv_zoom
	var width := 18.0 * inv_zoom
	var base := fighter.global_position + Vector2(-58.0 * fighter.facing * inv_zoom - width / 2, -40.0 * inv_zoom)
	var frame := Rect2(base - Vector2(0, height), Vector2(width, height))
	draw_style_box(UiStyle.flat(Color(0.08, 0.05, 0.12, 0.75 * alpha), int(8 * inv_zoom), int(3 * inv_zoom)), frame)
	var fill_height := (height - 6.0 * inv_zoom) * power
	var color := Color(0.4, 0.85, 0.35).lerp(Color(1.0, 0.85, 0.25), clampf(power * 2.0, 0.0, 1.0))
	color = color.lerp(Color(1.0, 0.35, 0.25), clampf(power * 2.0 - 1.0, 0.0, 1.0))
	color.a = alpha
	var fill := Rect2(base + Vector2(3.0 * inv_zoom, -3.0 * inv_zoom - fill_height), Vector2(width - 6.0 * inv_zoom, fill_height))
	draw_style_box(UiStyle.flat(color, int(5 * inv_zoom)), fill)


## The whole flight path in stopped time, dot by dot until it meets the ground, with
## a marker where it comes down.
func _draw_full_guide(origin: Vector2, velocity: Vector2, inv_zoom: float, alpha: float) -> void:
	var gravity := Rules.GRAVITY * fighter.data.weapon.gravity_scale
	var color := Color(0.8, 0.7, 1.0)
	var last := origin
	var t := 0.0
	var step := 0
	while t < 3.0:
		t += 0.03
		step += 1
		var at := Rules.position_at(origin, velocity, t, wind, gravity)
		if at.y > Terrain.height_at(at.x) - 4.0:
			break
		last = at
		if step % 2 == 0:
			draw_circle(at, 4.0 * inv_zoom, Color(color, alpha * 0.9), true, -1.0, true)
	var r := 12.0 * inv_zoom
	draw_arc(last, r, 0.0, TAU, 20, Color(1.0, 0.35, 0.4, alpha), 2.5 * inv_zoom, true)
	draw_line(last + Vector2(-r * 1.6, 0), last + Vector2(r * 1.6, 0), Color(1.0, 0.35, 0.4, alpha), 2.0 * inv_zoom, true)
	draw_line(last + Vector2(0, -r * 1.6), last + Vector2(0, r * 1.6), Color(1.0, 0.35, 0.4, alpha), 2.0 * inv_zoom, true)
