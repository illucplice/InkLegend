class_name Crate
extends Area2D
## A supply crate floating under a balloon. Any throw that touches it collects it for
## the thrower (and keeps flying). Kinds: shield (blocks the next hit), double (next
## throw does double damage), heal (+25 health), extra (throw again this turn).

const INK := Color(0.06, 0.055, 0.07)
const KINDS := [&"shield", &"double", &"heal", &"extra"]
const COLORS := {&"shield": Color(0.35, 0.65, 1.0), &"double": Color(0.95, 0.3, 0.3), &"heal": Color(0.4, 0.85, 0.4), &"extra": Color(1.0, 0.8, 0.25)}
const LABELS := {&"shield": "SHIELD!", &"double": "DOUBLE DAMAGE!", &"heal": "+25 HEALTH!", &"extra": "EXTRA THROW!"}
const SIZE := 34.0
## Collision layer 3 (value 4), so only projectiles' raycasts find it.
const LAYER := 4

var kind: StringName = &"shield"
var collected := false
var _time := 0.0
var _home := Vector2.ZERO


func setup(crate_kind: StringName, at: Vector2) -> void:
	kind = crate_kind
	_home = at
	position = at
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE + 10, SIZE + 70)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -24)
	add_child(collision)
	_time = randf() * TAU
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func collect() -> void:
	collected = true
	collision_layer = 0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	position = _home + Vector2(sin(_time * 0.9) * 10.0, sin(_time * 1.7) * 6.0)
	queue_redraw()


func _draw() -> void:
	var color: Color = COLORS[kind]
	var sway := sin(_time * 1.3) * 0.08
	# Balloon on a string.
	var balloon := Vector2(sin(sway) * 40.0, -70)
	draw_line(Vector2(0, -SIZE * 0.5), balloon + Vector2(0, 22), INK, 2.0, true)
	draw_set_transform(balloon, sway, Vector2(1.0, 1.15))
	draw_circle(Vector2.ZERO, 22.0, INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 19.5, color, true, -1.0, true)
	draw_circle(Vector2(-7, -8), 5.0, Color(1, 1, 1, 0.5), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	# Wooden box with planks and the kind's symbol.
	var box := Rect2(Vector2(-SIZE / 2, -SIZE / 2), Vector2(SIZE, SIZE))
	draw_rect(box.grow(3), INK)
	draw_rect(box, Color(0.72, 0.5, 0.3))
	draw_line(box.position, box.end, Color(0.5, 0.34, 0.2), 4.0)
	draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), Color(0.5, 0.34, 0.2), 4.0)
	draw_circle(Vector2.ZERO, 11.0, INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 9.0, color, true, -1.0, true)
	var font := UiStyle.title_font()
	var symbol := {&"shield": "◆", &"double": "x2", &"heal": "+", &"extra": "+1"}[kind] as String
	draw_string(font, Vector2(-11, 5), symbol, HORIZONTAL_ALIGNMENT_CENTER, 22, 15, Color.WHITE)
