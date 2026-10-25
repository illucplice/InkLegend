class_name Trap
extends Crate
## A map hazard hanging high over a fighter's head: an icicle in the Frozen Peaks, an
## anchor in Pirate Cove, a storm cloud over the Sky Islands and so on. Any throw that
## touches it brings it down on whoever stands below (and keeps flying), so hit the one
## over your enemy, not your own.

const THEMES := {
	&"frozen": "icicle", &"lava": "magma", &"pirate": "anchor", &"colosseum": "mace",
	&"neon": "sign", &"sky": "cloud", &"canyon": "boulder", &"bamboo": "bell", &"graveyard": "coffin",
}
## How high over the fighter's feet it hangs.
const HEIGHT := 330.0

## Who it falls on, and what it looks like.
var victim: Fighter
var look := "boulder"


func setup_trap(map_id: StringName, under: Fighter) -> void:
	kind = &"trap"
	victim = under
	look = THEMES.get(map_id, "boulder")
	_home = under.global_position + Vector2(0, -HEIGHT)
	position = _home
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 64)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	_time = randf() * TAU
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## It has been hit: it can't be hit again while it falls.
func collect() -> void:
	collected = true
	collision_layer = 0


func _process(delta: float) -> void:
	_time += delta
	if not collected:
		position = _home + Vector2(sin(_time * 1.1) * 4.0, sin(_time * 1.9) * 3.0)
	queue_redraw()


func _draw() -> void:
	# What it hangs from: a chain up out of sight (the cloud floats on its own).
	if look != "cloud" and not collected:
		draw_line(Vector2(0, -34), Vector2(0, -260), INK, 3.0, true)
		for k in 8:
			draw_arc(Vector2(0, -44 - k * 26.0), 6.0, 0.0, TAU, 10, Color(0.55, 0.55, 0.6), 2.0, true)
	match look:
		"icicle":
			var spike := PackedVector2Array([Vector2(-26, -26), Vector2(26, -26), Vector2(8, 4), Vector2(0, 40), Vector2(-8, 4)])
			_shape(spike, Color(0.78, 0.92, 1.0))
			draw_line(Vector2(-6, -20), Vector2(-2, 24), Color(1, 1, 1, 0.8), 2.5, true)
		"magma":
			draw_circle(Vector2.ZERO, 30.0, INK, true, -1.0, true)
			draw_circle(Vector2.ZERO, 27.0, Color(0.25, 0.14, 0.12), true, -1.0, true)
			for k in 4:
				var a := k * 1.7 + _time * 0.5
				draw_line(Vector2.from_angle(a) * 6.0, Vector2.from_angle(a + 0.4) * 24.0, Color(1.0, 0.5 + 0.2 * sin(_time * 6.0 + k), 0.1), 3.0, true)
		"anchor":
			var iron := Color(0.35, 0.37, 0.42)
			draw_line(Vector2(0, -28), Vector2(0, 28), INK, 9.0, true)
			draw_line(Vector2(0, -28), Vector2(0, 28), iron, 5.0, true)
			draw_arc(Vector2(0, 10), 24.0, 0.15, PI - 0.15, 14, INK, 9.0, true)
			draw_arc(Vector2(0, 10), 24.0, 0.15, PI - 0.15, 14, iron, 5.0, true)
			draw_line(Vector2(-14, -16), Vector2(14, -16), iron, 5.0, true)
			draw_arc(Vector2(0, -32), 7.0, 0.0, TAU, 12, iron, 4.0, true)
		"mace":
			for k in 8:
				var a := k * TAU / 8.0
				draw_colored_polygon(PackedVector2Array([Vector2.from_angle(a - 0.25) * 22.0, Vector2.from_angle(a) * 36.0, Vector2.from_angle(a + 0.25) * 22.0]), INK)
			draw_circle(Vector2.ZERO, 25.0, INK, true, -1.0, true)
			draw_circle(Vector2.ZERO, 22.0, Color(0.42, 0.42, 0.48), true, -1.0, true)
			draw_circle(Vector2(-7, -7), 6.0, Color(0.7, 0.7, 0.76), true, -1.0, true)
		"sign":
			var glow := 0.7 + 0.3 * sin(_time * 9.0)
			draw_rect(Rect2(-38, -22, 76, 44), INK)
			draw_rect(Rect2(-34, -18, 68, 36), Color(0.12, 0.05, 0.18))
			draw_rect(Rect2(-30, -14, 60, 28), Color(1.0, 0.3, 0.75, glow), false, 3.0)
			draw_string(UiStyle.title_font(), Vector2(-24, 7), "OPEN", HORIZONTAL_ALIGNMENT_CENTER, 48, 16, Color(0.4, 0.95, 1.0, glow))
		"cloud":
			var dark := Color(0.32, 0.32, 0.42)
			for puff: Vector3 in [Vector3(-24, 4, 18), Vector3(0, -6, 24), Vector3(24, 4, 18), Vector3(0, 10, 20)]:
				draw_circle(Vector2(puff.x, puff.y), puff.z + 2.5, INK, true, -1.0, true)
			for puff: Vector3 in [Vector3(-24, 4, 18), Vector3(0, -6, 24), Vector3(24, 4, 18), Vector3(0, 10, 20)]:
				draw_circle(Vector2(puff.x, puff.y), puff.z, dark, true, -1.0, true)
			if sin(_time * 3.0) > 0.85:
				draw_polyline(PackedVector2Array([Vector2(-4, 20), Vector2(6, 34), Vector2(-2, 40), Vector2(8, 56)]), Color(1.0, 0.95, 0.5), 3.0, true)
		"bell":
			var bronze := Color(0.78, 0.55, 0.22)
			_shape(PackedVector2Array([Vector2(-12, -28), Vector2(12, -28), Vector2(18, -6), Vector2(30, 26), Vector2(-30, 26), Vector2(-18, -6)]), bronze)
			draw_line(Vector2(-26, 18), Vector2(26, 18), bronze.darkened(0.35), 3.0, true)
			draw_circle(Vector2(0, 32), 6.0, INK, true, -1.0, true)
		"coffin":
			_shape(PackedVector2Array([Vector2(-14, -34), Vector2(14, -34), Vector2(24, -14), Vector2(16, 34), Vector2(-16, 34), Vector2(-24, -14)]), Color(0.35, 0.22, 0.15))
			draw_line(Vector2(0, -22), Vector2(0, 8), Color(0.85, 0.82, 0.75), 4.0, true)
			draw_line(Vector2(-9, -12), Vector2(9, -12), Color(0.85, 0.82, 0.75), 4.0, true)
		_:
			draw_circle(Vector2.ZERO, 30.0, INK, true, -1.0, true)
			draw_circle(Vector2.ZERO, 27.0, Color(0.6, 0.48, 0.36), true, -1.0, true)
			draw_arc(Vector2(-6, -6), 14.0, PI, PI * 1.6, 8, Color(0.75, 0.62, 0.48), 4.0, true)
	# A faint warning glow while it hangs, so you can see what it threatens.
	if not collected:
		draw_arc(Vector2.ZERO, 44.0 + sin(_time * 4.0) * 3.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.3, 0.35), 2.0, true)


func _shape(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var rim := points.duplicate()
	rim.append(points[0])
	draw_polyline(rim, INK, 3.0, true)
