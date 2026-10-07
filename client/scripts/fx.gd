class_name WorldFx
extends Node2D
## Top layer in world space: things that cross town borders (armies at war).

var m: Node


func _draw() -> void:
	m.draw_fx(self)
