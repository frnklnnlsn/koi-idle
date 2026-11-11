# toilet_body.gd
# The porcelain around the bowl, seen from above, drawn with Godot's own
# shapes (no image): the tank with its lid and flush handle, the back that
# joins the tank to the bowl, the seat hinges and the outside of the bowl.
# The seat ring (EllipseRing) and the water (EllipseShape) are separate nodes.
# All sizes are in toilet pixels around the bowl's centre; edits show live in
# the editor.
@tool
class_name ToiletBody
extends Node2D

@export_group("Colours")
@export var porcelain := Color(0.95, 0.96, 0.97):
	set(v): porcelain = v; queue_redraw()
## Edges and the shaded side of the porcelain.
@export var porcelain_shade := Color(0.80, 0.84, 0.88):
	set(v): porcelain_shade = v; queue_redraw()
## Outline around the whole toilet.
@export var outline := Color(0.62, 0.68, 0.75):
	set(v): outline = v; queue_redraw()
@export var metal := Color(0.70, 0.73, 0.78):
	set(v): metal = v; queue_redraw()
@export var metal_shine := Color(0.92, 0.94, 0.97):
	set(v): metal_shine = v; queue_redraw()
@export_range(0.0, 6.0, 1.0) var outline_width := 2.0:
	set(v): outline_width = v; queue_redraw()

@export_group("Bowl")
## Half the width / height of the outside of the bowl (a little bigger than
## the seat, so a band of porcelain shows round it).
@export var bowl_size := Vector2(134, 154):
	set(v): bowl_size = v; queue_redraw()
@export var bowl_offset := Vector2(0, 4):
	set(v): bowl_offset = v; queue_redraw()

@export_group("Tank")
## The tank: centre and full size.
@export var tank_center := Vector2(0, -212):
	set(v): tank_center = v; queue_redraw()
@export var tank_size := Vector2(300, 76):
	set(v): tank_size = v; queue_redraw()
@export var tank_corner := 14:
	set(v): tank_corner = v; queue_redraw()
## How far the lid sits in from the tank's edge.
@export var lid_inset := 7.0:
	set(v): lid_inset = v; queue_redraw()
## The back that joins tank and bowl: width, and how far down it reaches.
@export var neck_width := 170.0:
	set(v): neck_width = v; queue_redraw()
@export var neck_bottom := -100.0:
	set(v): neck_bottom = v; queue_redraw()

@export_group("Handle")
## Where the handle's round base sits (on the tank's front, left side).
@export var handle_base := Vector2(-118, -178):
	set(v): handle_base = v; queue_redraw()
@export var handle_base_radius := 8.0:
	set(v): handle_base_radius = v; queue_redraw()
## How far the lever sticks out to the left, and how thick it is.
@export var handle_length := 44.0:
	set(v): handle_length = v; queue_redraw()
@export var handle_thickness := 8.0:
	set(v): handle_thickness = v; queue_redraw()

@export_group("Hinges")
## The seat hinges, either side of the middle at the back of the bowl.
@export var hinge_spacing := 46.0:
	set(v): hinge_spacing = v; queue_redraw()
@export var hinge_y := -150.0:
	set(v): hinge_y = v; queue_redraw()
@export var hinge_size := Vector2(22, 12):
	set(v): hinge_size = v; queue_redraw()
@export_group("")


func _draw() -> void:
	var tank := Rect2(tank_center - tank_size * 0.5, tank_size)
	var neck := Rect2(Vector2(-neck_width * 0.5, tank.end.y - tank_corner),
		Vector2(neck_width, neck_bottom - tank.end.y + tank_corner))
	var o := outline_width

	# Outline: everything a little bigger, in the outline colour.
	if o > 0.0:
		_ellipse(bowl_offset, bowl_size + Vector2.ONE * o, outline)
		_box(neck.grow(o), 0, outline)
		_box(tank.grow(o), tank_corner + int(o), outline)

	# Bowl outside: shaded rim, lighter top.
	_ellipse(bowl_offset, bowl_size, porcelain_shade)
	_ellipse(bowl_offset + Vector2(0, -3), bowl_size - Vector2(4, 5), porcelain)

	# Back between tank and bowl.
	_box(neck, 0, porcelain)

	# Tank: shaded front edge, then the lid inset on top.
	_box(tank, tank_corner, porcelain_shade)
	var lid := Rect2(tank.position + Vector2.ONE * lid_inset,
		tank.size - Vector2(lid_inset * 2.0, lid_inset * 2.0 + 3.0))
	_box(lid, maxi(tank_corner - int(lid_inset * 0.5), 0), porcelain)

	# Seat hinges.
	for side in [-1.0, 1.0]:
		var c := Vector2(side * hinge_spacing, hinge_y)
		_box(Rect2(c - hinge_size * 0.5, hinge_size).grow(1.0), 3, outline)
		_box(Rect2(c - hinge_size * 0.5, hinge_size), 3, metal)

	# Flush handle: a lever out to the left, then its round base.
	var lever := Rect2(handle_base + Vector2(-handle_length, -handle_thickness * 0.5),
		Vector2(handle_length, handle_thickness))
	_box(lever.grow(1.0), int(handle_thickness * 0.5) + 1, outline)
	_box(lever, int(handle_thickness * 0.5), metal)
	_box(Rect2(lever.position + Vector2(3, 1), Vector2(lever.size.x - 6, 2)), 1, metal_shine)
	draw_circle(handle_base, handle_base_radius + 1.0, outline)
	draw_circle(handle_base, handle_base_radius, metal)
	draw_circle(handle_base + Vector2(-2, -2), handle_base_radius * 0.4, metal_shine)


func _ellipse(centre: Vector2, half: Vector2, col: Color) -> void:
	var n := 72
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = centre + Vector2(cos(a), sin(a)) * half
	draw_colored_polygon(pts, col)


## A rounded box, using Godot's StyleBoxFlat.
func _box(r: Rect2, corner: int, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(corner)
	sb.anti_aliasing = false
	draw_style_box(sb, r)
