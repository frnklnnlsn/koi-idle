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
## The seat is a rounded oval (not pointed like the lid): its half width,
## and how boxy its ends are (2 = plain ellipse, higher = squarer ends).
@export var seat_width := 118.0:
	set(v): seat_width = v; queue_redraw()
@export_range(2.0, 6.0, 0.1) var seat_squareness := 2.6:
	set(v): seat_squareness = v; queue_redraw()
## Thickness of the shaded lip along the lid's and seat's front edges.
@export var lip := 4.0:
	set(v): lip = v; queue_redraw()

@export_group("Hole")
## The sliver of hole in the seat: half width, and where its back and front
## edges are (from the hinge line). Hole Ends Y is unused (kept for scenes).
@export var hole_width := 84.0:
	set(v): hole_width = v; queue_redraw()
@export var hole_ends_y := 4.0:
	set(v): hole_ends_y = v; queue_redraw()
@export var hole_back := 6.0:
	set(v): hole_back = v; queue_redraw()
@export var hole_front := 14.0:
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
	# (only down to the seat's middle, so it doesn't poke out round its ends)
	var mid := (seat_back + seat_front) * 0.5
	_lens(width + 2.0, y0, lid_back - 2.0, mid, outline)
	_lens(width, y0, lid_back, mid, gap_color)

	# Hinges peek out under the seat's front edge.
	for side in [-1.0, 1.0]:
		var c := Vector2(side * hinge_spacing, hinge_y)
		draw_circle(c, hinge_radius + 1.0, outline)
		draw_circle(c, hinge_radius, metal)
		draw_circle(c + Vector2(-2, -2), hinge_radius * 0.4, metal_shine)
	# Lid: top, then its shaded front lip.
	_lens(width, y0, lid_back, lid_front, shade_color)
	_lens(width, y0, lid_back, lid_front - lip, seat_color)

	# Seat: a rounded oval from Seat Back to Seat Front, with a shaded lip
	# along the front, then the sliver of hole.
	var c := Vector2(0, y0 + (seat_back + seat_front) * 0.5)
	var half := Vector2(seat_width, (seat_front - seat_back) * 0.5)
	_oval(c, half + Vector2(1.5, 1.5), outline)
	_oval(c, half, shade_color)
	_oval(c + Vector2(0, -lip * 0.5), half - Vector2(lip * 0.5, lip * 0.5), seat_color)
	if hole_front > hole_back:
		var hc := Vector2(0, y0 + (hole_back + hole_front) * 0.5)
		var hh := Vector2(hole_width, (hole_front - hole_back) * 0.5)
		_oval(hc, hh + Vector2(1, 1), shade_color)
		_oval(hc, hh, hole_color)


## A rounded oval (superellipse): squareness 2 = ellipse.
func _oval(centre: Vector2, half: Vector2, col: Color) -> void:
	var e := 2.0 / seat_squareness
	var pts := PackedVector2Array()
	for i in 72:
		var a := TAU * i / 72.0
		var cx := cos(a)
		var sy := sin(a)
		pts.append(centre + Vector2(signf(cx) * pow(absf(cx), e) * half.x,
			signf(sy) * pow(absf(sy), e) * half.y))
	draw_colored_polygon(pts, col)


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
