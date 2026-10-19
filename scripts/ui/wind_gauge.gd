class_name WindGauge
extends Control
## A small pill under the turn banner: an arrow showing which way the wind blows
## and a 0-10 strength number, or "CALM".

const INK := Color(0.12, 0.1, 0.14)

var _wind := 0.0
var _shown := 0.0
var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(210, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_wind(wind: float) -> void:
	_wind = wind


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, _wind, 1.0 - exp(-6.0 * delta))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(UiStyle.flat(Color(0.08, 0.05, 0.12, 0.72), 18, 3), r)
	var font := UiStyle.title_font()
	draw_string(font, Vector2(14, size.y * 0.5 + 8), "WIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 0.9, 1.0))
	var strength := roundi(absf(_wind) / Rules.MAX_WIND * 10.0)
	if strength == 0:
		draw_string(font, Vector2(72, size.y * 0.5 + 8), "CALM", HORIZONTAL_ALIGNMENT_CENTER, size.x - 86, 20, Color.WHITE)
		return
	var center := Vector2(72 + (size.x - 86) * 0.42, size.y * 0.5)
	var direction := signf(_shown)
	var length := 18.0 + absf(_shown) / Rules.MAX_WIND * 46.0
	var wobble := sin(_time * 6.0) * 2.0
	var tail := center - Vector2(direction * length * 0.5, 0)
	var tip := center + Vector2(direction * (length * 0.5 + wobble), 0)
	var color := Color(0.55, 0.9, 1.0).lerp(Color(1.0, 0.55, 0.35), absf(_shown) / Rules.MAX_WIND)
	draw_line(tail, tip, INK, 9.0, true)
	draw_line(tail, tip, color, 5.0, true)
	var head := PackedVector2Array([tip + Vector2(direction * 10, 0), tip + Vector2(-direction * 4, -9), tip + Vector2(-direction * 4, 9)])
	draw_colored_polygon(head, color)
	head.append(head[0])
	draw_polyline(head, INK, 2.5, true)
	draw_string(font, Vector2(size.x - 46, size.y * 0.5 + 8), str(strength), HORIZONTAL_ALIGNMENT_CENTER, 34, 22, Color.WHITE)
