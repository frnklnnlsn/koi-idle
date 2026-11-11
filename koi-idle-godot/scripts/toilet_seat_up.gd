# toilet_seat_up.gd
# The toilet seat and lid lifted up against the tank, seen from above, drawn
# with Godot's own shapes. From straight above a raised seat is only its edge:
# the lid is an outer shell behind it, and both swing on the same hinge line,
# so they meet at the sides and part in the middle, with a shadow between.
#
# Every edge is an arc between the same two side points (± Width, Hinge Y);
# the "depth" settings say how far each arc bulges at the middle (negative =
# back toward the tank, positive = forward toward the bowl).
# Sits above the water and the bowl rim (in ToiletArea/AboveWater). Sizes are
# in toilet pixels around the bowl's centre; edits show live in the editor.
@tool
class_name ToiletSeatUp
extends Node2D

@export_group("Colours")
@export var seat_color := Color(0.97, 0.97, 0.98):
	set(v): seat_color = v; queue_redraw()
## The shaded lips of the seat and lid.
@export var shade_color := Color(0.80, 0.83, 0.87):
	set(v): shade_color = v; queue_redraw()
## The shadow in the gap between lid and seat.
@export var gap_color := Color(0.42, 0.47, 0.55):
	set(v): gap_color = v; queue_redraw()
## What shows through the sliver of the seat's hole.
@export var hole_color := Color(0.62, 0.67, 0.73):
	set(v): hole_color = v; queue_redraw()
@export var outline := Color(0.55, 0.61, 0.69):
	set(v): outline = v; queue_redraw()
@export var metal := Color(0.70, 0.73, 0.78):
	set(v): metal = v; queue_redraw()
@export var metal_shine := Color(0.93, 0.95, 0.98):
	set(v): metal_shine = v; queue_redraw()

@export_group("Shape")
## Half the width of seat and lid (they share it, so they meet at the sides).
@export var width := 124.0:
	set(v): width = v; queue_redraw()
## Height of the hinge line, where the sides meet.
@export var hinge_line_y := -158.0:
	set(v): hinge_line_y = v; queue_redraw()
## How far the lid's back reaches toward the tank (negative = back).
@export var lid_back := -24.0:
	set(v): lid_back = v; queue_redraw()
## The lid's front edge and the seat's back edge: the gap between them is
## the shadow (bigger difference = wider shadow in the middle).
@export var lid_front := -9.0:
	set(v): lid_front = v; queue_redraw()
@export var seat_back := -1.0:
	set(v): seat_back = v; queue_redraw()
## How far the seat's front reaches toward the bowl.
@export var seat_front := 26.0:
	set(v): seat_front = v; queue_redraw()
## Thickness of the shaded lip along the lid's and seat's front edges.
@export var lip := 4.0:
	set(v): lip = v; queue_redraw()

@export_group("Hole")
## The sliver of hole in the seat: half width, where its ends sit (from the
## hinge line), and how far its back and front edges bulge.
@export var hole_width := 86.0:
	set(v): hole_width = v; queue_redraw()
@export var hole_ends_y := 4.0:
	set(v): hole_ends_y = v; queue_redraw()
@export var hole_back := 3.0:
	set(v): hole_back = v; queue_redraw()
@export var hole_front := 12.0:
	set(v): hole_front = v; queue_redraw()

@export_group("Hinges")
@export var hinge_spacing := 60.0:
	set(v): hinge_spacing = v; queue_redraw()
@export var hinge_y := -133.0:
	set(v): hinge_y = v; queue_redraw()
@export var hinge_radius := 7.0:
	set(v): hinge_radius = v; queue_redraw()
@export_group("")

const STEPS := 40


func _draw() -> void:
	var y0 := hinge_line_y
	# Outline and the shadow underneath everything.
	_lens(width + 2.0, y0, lid_back - 2.0, seat_front + 2.0, outline)
	_lens(width, y0, lid_back, seat_front, gap_color)

	# Hinges peek out under the seat's front edge.
	for side in [-1.0, 1.0]:
		var c := Vector2(side * hinge_spacing, hinge_y)
		draw_circle(c, hinge_radius + 1.0, outline)
		draw_circle(c, hinge_radius, metal)
		draw_circle(c + Vector2(-2, -2), hinge_radius * 0.4, metal_shine)
	# Lid: top, then its shaded front lip.
	_lens(width, y0, lid_back, lid_front, shade_color)
	_lens(width, y0, lid_back, lid_front - lip, seat_color)

	# Seat: shaded front lip, top, then the sliver of hole.
	_lens(width, y0, seat_back, seat_front, shade_color)
	_lens(width, y0, seat_back, seat_front - lip, seat_color)
	if hole_front > hole_back:
		var hy := y0 + hole_ends_y
		_lens(hole_width + 1.0, hy, hole_back - 1.0, hole_front + 1.0, shade_color)
		_lens(hole_width, hy, hole_back, hole_front, hole_color)


## The shape between two elliptical arcs from (-half, y) to (half, y): one
## bulging `back` at the middle, the other `front`.
func _lens(half: float, y: float, back: float, front: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in STEPS + 1:
		var x := lerpf(-half, half, float(i) / STEPS)
		pts.append(Vector2(x, y + back * _bulge(x, half)))
	for i in range(STEPS - 1, 0, -1):
		var x := lerpf(-half, half, float(i) / STEPS)
		pts.append(Vector2(x, y + front * _bulge(x, half)))
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, col)


func _bulge(x: float, half: float) -> float:
	return sqrt(maxf(1.0 - (x / half) * (x / half), 0.0))
