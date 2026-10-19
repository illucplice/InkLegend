class_name PracticeTarget
extends Area2D
## A bullseye for Target Practice: on a wooden stand, or floating under a balloon.
## Throws stop when they hit it.

const INK := Color(0.06, 0.055, 0.07)
const RADIUS := 34.0
const BULLSEYE := 12.0
## Collision layer 4 (value 8): only projectiles' raycasts look for it.
const LAYER := 8

var floating := false
var _time := 0.0


func setup(at: Vector2, is_floating: bool) -> void:
	position = at
	floating = is_floating
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True if a hit at this world point is in the bullseye.
func is_bullseye(point: Vector2) -> bool:
	return point.distance_to(global_position) <= BULLSEYE + 4.0


func pop() -> void:
	collision_layer = 0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if floating:
		var balloon := Vector2(sin(_time * 1.2) * 6.0, -RADIUS - 70)
		draw_line(Vector2(0, -RADIUS), balloon + Vector2(0, 20), INK, 2.0, true)
		draw_circle(balloon, 22.0, INK, true, -1.0, true)
		draw_circle(balloon, 19.0, Color(0.95, 0.35, 0.35), true, -1.0, true)
		draw_circle(balloon + Vector2(-7, -8), 5.0, Color(1, 1, 1, 0.5), true, -1.0, true)
	else:
		var foot := -position.y
		for side: float in [-1.0, 1.0]:
			draw_line(Vector2(side * 6, RADIUS - 4), Vector2(side * 22, foot), INK, 6.0, true)
			draw_line(Vector2(side * 6, RADIUS - 4), Vector2(side * 22, foot), Color(0.6, 0.42, 0.26), 3.0, true)
	var colors := [Color.WHITE, Color(0.9, 0.25, 0.25), Color.WHITE, Color(0.9, 0.25, 0.25)]
	draw_circle(Vector2.ZERO, RADIUS + 3.0, INK, true, -1.0, true)
	for ring in colors.size():
		draw_circle(Vector2.ZERO, RADIUS - ring * (RADIUS - BULLSEYE) / colors.size(), colors[ring], true, -1.0, true)
	draw_circle(Vector2.ZERO, BULLSEYE, Color(1.0, 0.8, 0.25), true, -1.0, true)
	draw_circle(Vector2.ZERO, BULLSEYE, INK, false, 2.0, true)
