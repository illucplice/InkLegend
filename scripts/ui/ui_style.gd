class_name UiStyle
extends RefCounted
## The game's look in one place: colours, fonts, glossy "candy" buttons (textures
## generated at startup, cached per colour), ribbons, panels and label helpers.

const INK := Color(0.12, 0.1, 0.14)
const PAPER := Color(1.0, 0.96, 0.88)
const YELLOW := Color(1.0, 0.78, 0.25)
const GREEN := Color(0.4, 0.8, 0.32)
const BLUE := Color(0.3, 0.55, 0.95)
const RED := Color(0.92, 0.3, 0.3)
const PURPLE := Color(0.6, 0.4, 0.85)
const ORANGE := Color(1.0, 0.58, 0.2)
const GREY := Color(0.78, 0.76, 0.8)

## Lilita One and Rubik (Google Fonts, OFL licence; see fonts/OFL-*.txt). If a file is
## missing, Godot's default font is used instead.
const TITLE_FONT_PATH := "res://fonts/LilitaOne-Regular.ttf"
const BODY_FONT_PATH := "res://fonts/Rubik-Variable.ttf"
## Rubik is a variable font; this picks its weight (400 regular, 700 bold).
const BODY_WEIGHT := 600

const TEX_SIZE := 64
const RADIUS := 18.0
const BORDER := 3.0
const LIP := 7.0

static var _cache := {}
static var _title_font: Font
static var _body_font: Font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(TITLE_FONT_PATH) if ResourceLoader.exists(TITLE_FONT_PATH) else ThemeDB.fallback_font
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		if ResourceLoader.exists(BODY_FONT_PATH):
			var weighted := FontVariation.new()
			weighted.base_font = load(BODY_FONT_PATH)
			weighted.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): BODY_WEIGHT}
			_body_font = weighted
		else:
			_body_font = ThemeDB.fallback_font
	return _body_font


## A glossy button face: light top, gloss band, darker lip underneath, ink border.
## Pressed faces lose most of the lip and move their content down, so they "sink".
static func candy(color: Color, pressed: bool = false) -> StyleBoxTexture:
	var key := "candy_%s_%s" % [color.to_html(), pressed]
	if not _cache.has(key):
		var lip := 2.0 if pressed else LIP
		var box := StyleBoxTexture.new()
		box.texture = ImageTexture.create_from_image(_candy_image(color, lip))
		box.texture_margin_left = RADIUS + 4
		box.texture_margin_right = RADIUS + 4
		box.texture_margin_top = RADIUS + 4
		box.texture_margin_bottom = RADIUS + 4 + lip
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 10 + (LIP - lip)
		box.content_margin_bottom = 8 + lip
		_cache[key] = box
	return _cache[key]


## A flat rounded panel with a border and soft shadow, for cards and plates.
static func panel(color: Color, radius: int = 22, border: int = 4, padding: float = 26.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 6)
	box.anti_aliasing = true
	return box


static func flat(color: Color, radius: int, border: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


static func theme() -> Theme:
	if _cache.has("theme"):
		return _cache["theme"]
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", candy(YELLOW.lerp(PAPER, 0.35)))
	t.set_stylebox("hover", "Button", candy(YELLOW.lerp(PAPER, 0.15)))
	t.set_stylebox("pressed", "Button", candy(YELLOW, true))
	t.set_stylebox("hover_pressed", "Button", candy(YELLOW.lightened(0.1), true))
	t.set_stylebox("disabled", "Button", candy(GREY))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(color_name, "Button", INK)
	var track := flat(INK.lightened(0.25), 8)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", flat(YELLOW, 8))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(YELLOW.lightened(0.2), 8))
	_cache["theme"] = t
	return t


## Give a Button a candy face in its own colour.
static func paint_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", candy(color))
	button.add_theme_stylebox_override("hover", candy(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", candy(color.darkened(0.08), true))
	button.add_theme_stylebox_override("hover_pressed", candy(color.lightened(0.05), true))


## White text with a thick ink outline and drop shadow, for text over the arena.
static func game_label(text: String, size: int, title: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", title_font() if title else body_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(6, size / 4))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_y", maxi(2, size / 12))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Dark text for use on paper panels.
static func ink_label(text: String, size: int, title: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", title_font() if title else body_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A coloured banner with a title, used as the header of every card.
static func ribbon(text: String, color: Color, size: int = 38) -> PanelContainer:
	var ribbon_panel := PanelContainer.new()
	ribbon_panel.add_theme_stylebox_override("panel", candy(color))
	ribbon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := game_label(text, size, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon_panel.add_child(label)
	ribbon_panel.set_meta("label", label)
	return ribbon_panel


static func _candy_image(base: Color, lip: float) -> Image:
	var size := TEX_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bounds := Rect2(0, 0, size, size)
	var face_bottom := size - BORDER - lip
	var top := base.lightened(0.28)
	var shade := base.darkened(0.32)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _round_rect_distance(p, bounds, RADIUS)
			var coverage := clampf(0.5 - d, 0.0, 1.0)
			if coverage <= 0.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var fill: Color
			if p.y >= face_bottom:
				fill = shade
			else:
				var t := clampf(p.y / face_bottom, 0.0, 1.0)
				fill = top.lerp(base, smoothstep(0.0, 0.55, t))
				# Gloss band across the upper part of the face.
				if p.y > BORDER + 3.0 and p.y < face_bottom * 0.42:
					var inset := _round_rect_distance(p, bounds.grow(-BORDER - 4.0), RADIUS - BORDER - 4.0)
					if inset < 0.0:
						fill = fill.lerp(Color.WHITE, 0.22 * clampf(-inset / 2.0, 0.0, 1.0))
			# Ink border, anti-aliased on the inside edge too.
			var inner := clampf(-d - BORDER + 0.5, 0.0, 1.0)
			var color := INK.lerp(fill, inner)
			color.a = coverage
			image.set_pixel(x, y, color)
	return image


## Signed distance to a rounded rectangle: negative inside.
static func _round_rect_distance(p: Vector2, rect: Rect2, radius: float) -> float:
	var half := rect.size / 2
	var q := (p - rect.get_center()).abs() - half + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
