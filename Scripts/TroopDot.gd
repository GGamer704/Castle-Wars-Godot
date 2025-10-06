extends Node2D

var speed := 400.0
var target_pos := Vector2.ZERO
var color := Color(1, 1, 0.5)

func _process(delta):
	var dir = (target_pos - position)
	if dir.length() < 4:
		queue_free() # Remove when reached
		return
	position += dir.normalized() * speed * delta

func _draw():
	draw_circle(Vector2.ZERO, 4, color)
