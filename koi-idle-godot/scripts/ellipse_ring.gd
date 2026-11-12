# ellipse_ring.gd
# A flat ring shaped like an ellipse (e.g. the toilet seat), drawn with
# Godot's own shapes instead of an image. Set the outer and inner sizes and
# the colour in the Inspector; it updates live in the editor.
# In the toilet / pond views it's drawn at their low resolution and blown up
# (the SubViewportContainer's stretch_shrink), so it comes out pixelated like
# the rest of the art.
@tool
class_name EllipseRing
extends Node2D

## Half the width / height of the outside edge.
@export var outer_size := Vector2(126, 144):
	set(v): outer_size = v; queue_redraw()
## Half the width / height of the hole.
@export var inner_size := Vector2(96, 116):
	set(v): inner_size = v; queue_redraw()
## Moves the hole off centre (e.g. a thicker band at the front).
@export var inner_offset := Vector2.ZERO:
	set(v): inner_offset = v; queue_redraw()
@export var color := Color.WHITE:
	set(v): color = v; queue_redraw()
## Points around the edge (more = smoother before pixelation).
@export_range(8, 256, 1) var segments := 96:
	set(v): segments = v; queue_redraw()


func _draw() -> void:
	var n := maxi(segments, 8)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var quad := PackedVector2Array([
			d0 * outer_size, d1 * outer_size,
			inner_offset + d1 * inner_size, inner_offset + d0 * inner_size])
		draw_colored_polygon(quad, color)
