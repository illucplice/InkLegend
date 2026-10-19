class_name Effects
extends RefCounted
## One-shot visual effects: particle bursts and floating text.

const INK := Color(0.12, 0.1, 0.14)

static var _dot: GradientTexture2D


## A burst of soft dots. spread_deg 180 sprays in all directions; less sprays upward.
static func burst(parent: Node, at: Vector2, color: Color, amount: int, speed: float, spread_deg: float = 180.0, size: float = 1.0) -> void:
	var particles := CPUParticles2D.new()
	particles.texture = _dot_texture()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = maxi(2, roundi(amount * Device.particle_scale()))
	particles.lifetime = 0.7
	particles.direction = Vector2.UP
	particles.spread = spread_deg
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, 900)
	particles.damping_min = 60.0
	particles.damping_max = 120.0
	particles.scale_amount_min = 0.35 * size
	particles.scale_amount_max = 0.8 * size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	particles.scale_amount_curve = shrink
	particles.color = color
	particles.position = at
	particles.z_index = 25
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.restart()


## Text that pops in, floats up and fades. inv_zoom keeps it the same size on screen,
## and it is nudged inside `bounds` (the visible world rect) so it never runs off-screen.
static func popup(parent: Node, at: Vector2, text: String, color: Color, font_size: int, inv_zoom: float, bounds: Rect2) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiStyle.title_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(8, font_size / 4))
	var text_width := UiStyle.title_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size
	label.size = Vector2(text_width, font_size * 1.5)
	var half := label.size.x * 0.5 * inv_zoom * 1.25
	at.x = clampf(at.x, bounds.position.x + half, maxf(bounds.end.x - half, bounds.position.x + half))
	label.pivot_offset = label.size / 2
	label.position = at - label.size / 2
	label.z_index = 30
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	label.scale = Vector2.ZERO
	parent.add_child(label)
	var full := Vector2(inv_zoom, inv_zoom)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", full * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", full, 0.1)
	tween.tween_property(label, "position:y", label.position.y - 70.0 * inv_zoom, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_callback(label.queue_free)


static func _dot_texture() -> GradientTexture2D:
	if _dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.55, Color(1, 1, 1, 0.9))
		_dot = GradientTexture2D.new()
		_dot.gradient = gradient
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot
