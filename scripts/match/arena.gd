class_name Arena
extends Node2D
## Flat greybox ground at y = 0, with a tick every 5 m.

const HALF_WIDTH := 4000.0
const DEPTH := 1200.0
const INK := Color(0.12, 0.1, 0.14)


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_WIDTH * 2, DEPTH)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, DEPTH / 2)
	body.add_child(collision)
	add_child(body)


func _draw() -> void:
	for i in range(-6, 7):
		var center := Vector2(i * 700.0 + 200.0 * sin(i), 300.0)
		draw_circle(center, 520.0 + 80.0 * cos(i * 1.7), Color(0.58, 0.8, 0.6))
	draw_rect(Rect2(-HALF_WIDTH, 0, HALF_WIDTH * 2, DEPTH), Color(0.47, 0.34, 0.24))
	draw_rect(Rect2(-HALF_WIDTH, 0, HALF_WIDTH * 2, 18), Color(0.38, 0.66, 0.32))
	draw_line(Vector2(-HALF_WIDTH, 0), Vector2(HALF_WIDTH, 0), INK, 4.0)
	for metres in range(-100, 101, 5):
		var x := metres * Rules.PX_PER_M
		draw_line(Vector2(x, 18), Vector2(x, 32), Color(0.3, 0.2, 0.14), 3.0)
