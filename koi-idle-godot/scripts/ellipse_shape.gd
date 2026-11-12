# ellipse_shape.gd
# A filled ellipse drawn with Godot's own shapes (no image), with optional
# shading: it darkens in steps toward a spot inside it, like the hole of a
# drain. Used for the toilet water and drain; edits show live in the editor.
# In the toilet / pond views the low resolution pixelates it like the art.
@tool
class_name EllipseShape
extends Node2D

## Half the width / height.
@export var size := Vector2(100, 120):
	set(v): size = v; queue_redraw()
@export var color := Color(0.6, 0.67, 0.71):
	set(v): color = v; queue_redraw()

@export_group("Shading")
## The colour at the darkest spot (same as Color = no shading).
@export var shade_color := Color(0.6, 0.67, 0.71):
	set(v): shade_color = v; queue_redraw()
## Where the darkest spot is, as a share of the size: (0, 0) = centre,
## (0, -0.5) = halfway to the top edge.
@export var shade_center := Vector2.ZERO:
	set(v): shade_center = v; queue_redraw()
## How far the shading reaches in from the edge (1 = all the way to the spot,
## 0.5 = only the inner half is shaded).
@export_range(0.0, 1.0, 0.01) var shade_reach := 1.0:
	set(v): shade_reach = v; queue_redraw()
## Steps of shading (pixel-art bands). 0 = a smooth blend.
@export_range(0, 16, 1) var bands := 4:
	set(v): bands = v; queue_redraw()
@export_group("")

## Points around the edge.
@export_range(8, 256, 1) var segments := 72:
	set(v): segments = v; queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_points(size, Vector2.ZERO), color)
	if shade_color == color or shade_reach <= 0.0:
		return
	var spot := shade_center * size
	if bands <= 0:
		# Smooth: a fan from the spot, edge colour to shade colour.
		var pts := _points(size * shade_reach, spot * shade_reach)
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(color)
		pts.append(spot)
		cols.append(shade_color)
		for i in pts.size() - 1:
			var j := (i + 1) % (pts.size() - 1)
			draw_polygon(PackedVector2Array([pts[i], pts[j], spot]),
				PackedColorArray([cols[i], cols[j], shade_color]))
		return
	# Banded: smaller and smaller ellipses sliding toward the spot.
	for k in range(1, bands + 1):
		var sc := 1.0 - shade_reach * float(k) / (bands + 1)
		draw_colored_polygon(_points(size * sc, spot * (1.0 - sc)),
			color.lerp(shade_color, float(k) / bands))


func _points(half: Vector2, centre: Vector2) -> PackedVector2Array:
	var n := maxi(segments, 8)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = centre + Vector2(cos(a), sin(a)) * half
	return pts
