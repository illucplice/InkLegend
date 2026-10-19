class_name WavyTitle
extends Control
## The game logo: each letter bobs on its own sine wave, coloured orange to yellow,
## with a thick outline and a drop shadow.

const INK := Color(0.12, 0.1, 0.14)
const TOP := Color(1.0, 0.86, 0.3)
const BOTTOM := Color(1.0, 0.5, 0.18)

var lines: PackedStringArray = ["WOBBLE", "WARS"]
var font_size := 84
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := UiStyle.title_font()
	custom_minimum_size = Vector2(_line_width(font, lines[0]) + 20, font_size * 0.95 * lines.size() + 20)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var font := UiStyle.title_font()
	var line_height := font_size * 0.92
	var index := 0
	for row in lines.size():
		var text := lines[row]
		var width := _line_width(font, text)
		var x := (size.x - width) / 2
		var baseline := font_size * 0.85 + row * line_height
		for i in text.length():
			var letter := text[i]
			var advance := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var bob := sin(_time * 3.0 - index * 0.55) * 6.0
			var tilt := sin(_time * 2.2 - index * 0.7) * 0.06
			var at := Vector2(x + advance / 2, baseline + bob)
			draw_set_transform(at, tilt)
			var origin := Vector2(-advance / 2, 0)
			var tint := TOP.lerp(BOTTOM, float(row) / maxf(lines.size() - 1, 1) * 0.6 + 0.2 * sin(index))
			draw_string_outline(font, origin + Vector2(0, 7), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 22, Color(0, 0, 0, 0.35))
			draw_string_outline(font, origin, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 20, INK)
			draw_string(font, origin, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
			x += advance
			index += 1
	draw_set_transform(Vector2.ZERO)


func _line_width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
