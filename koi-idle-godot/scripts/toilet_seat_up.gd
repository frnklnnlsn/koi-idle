# toilet_seat_up.gd
# The toilet seat and lid lifted up against the tank, seen from above, drawn
# with Godot's own shapes: from straight above a raised seat is only its edge,
# a long thin oval with a sliver of its hole showing, and the lid is a thicker
# band leaning on the tank behind it. Plus the two chrome hinges.
# Sits above the water and the bowl rim (in ToiletArea/AboveWater). Sizes are
# in toilet pixels around the bowl's centre; edits show live in the editor.
@tool
class_name ToiletSeatUp
extends Node2D

@export_group("Colours")
@export var seat_color := Color(0.97, 0.97, 0.98):
	set(v): seat_color = v; queue_redraw()
## The shaded underside / edges of the seat and lid.
@export var shade_color := Color(0.80, 0.83, 0.87):
	set(v): shade_color = v; queue_redraw()
## What shows through the sliver of the seat's hole (the lid behind it).
@export var hole_color := Color(0.68, 0.72, 0.77):
	set(v): hole_color = v; queue_redraw()
@export var outline := Color(0.62, 0.68, 0.75):
	set(v): outline = v; queue_redraw()
@export var metal := Color(0.70, 0.73, 0.78):
	set(v): metal = v; queue_redraw()
@export var metal_shine := Color(0.93, 0.95, 0.98):
	set(v): metal_shine = v; queue_redraw()

@export_group("Lid")
## Centre and half width / half depth of the lid band.
@export var lid_center := Vector2(0, -170):
	set(v): lid_center = v; queue_redraw()
@export var lid_size := Vector2(126, 15):
	set(v): lid_size = v; queue_redraw()

@export_group("Seat")
@export var seat_center := Vector2(0, -150):
	set(v): seat_center = v; queue_redraw()
@export var seat_size := Vector2(122, 18):
	set(v): seat_size = v; queue_redraw()
## Half width / half depth of the sliver of hole (0 depth = hidden).
@export var hole_size := Vector2(86, 6):
	set(v): hole_size = v; queue_redraw()
## Moves the hole forward or back within the seat edge.
@export var hole_offset := Vector2(0, -2):
	set(v): hole_offset = v; queue_redraw()

@export_group("Hinges")
@export var hinge_spacing := 60.0:
	set(v): hinge_spacing = v; queue_redraw()
@export var hinge_y := -133.0:
	set(v): hinge_y = v; queue_redraw()
@export var hinge_radius := 7.0:
	set(v): hinge_radius = v; queue_redraw()
@export_group("")


func _draw() -> void:
	# Lid: outline, shaded underside, lighter top edge.
	_ellipse(lid_center, lid_size + Vector2(2, 2), outline)
	_ellipse(lid_center, lid_size, shade_color)
	_ellipse(lid_center + Vector2(0, -2), lid_size - Vector2(3, 3), seat_color)

	# Hinges sit under the seat's front edge.
	for side in [-1.0, 1.0]:
		var c := Vector2(side * hinge_spacing, hinge_y)
		draw_circle(c, hinge_radius + 1.0, outline)
		draw_circle(c, hinge_radius, metal)
		draw_circle(c + Vector2(-2, -2), hinge_radius * 0.4, metal_shine)

	# Seat edge with the sliver of hole.
	_ellipse(seat_center, seat_size + Vector2(2, 2), outline)
	_ellipse(seat_center, seat_size, shade_color)
	_ellipse(seat_center + Vector2(0, -2), seat_size - Vector2(3, 3), seat_color)
	if hole_size.y > 0.0:
		_ellipse(seat_center + hole_offset, hole_size + Vector2(1, 1), shade_color)
		_ellipse(seat_center + hole_offset, hole_size, hole_color)


func _ellipse(centre: Vector2, half: Vector2, col: Color) -> void:
	var n := 72
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = centre + Vector2(cos(a), sin(a)) * half
	draw_colored_polygon(pts, col)
