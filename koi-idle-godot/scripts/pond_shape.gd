# pond_shape.gd
# The pond's outline and its banks, drawn with Godot's own shapes.
#
# Edit the outline like any Polygon2D: select the node and drag its points
# in the 2D view (add / remove points with the polygon tools at the top). The
# rough outline is smoothed into an organic curve, then drawn as bands that
# follow it: rings of bank outside it (woods, grass, reeds, the muddy shore)
# and rings of water inside it getting deeper toward the middle, the same
# stepped shading as the toilet bowl. The deepest band is left open so the
# pond's water shows through.
#
# The fish swim inside the smoothed outline (make_swim_area), and the pond's
# water effects stay inside it too.
@tool
class_name PondShape
extends Polygon2D

## Times the outline is smoothed (rounds the corners between your points).
@export_range(0, 5, 1) var smooth_steps := 3:
	set(v): smooth_steps = v; queue_redraw()

## How far inside the shoreline the fish stay, in pond pixels (so their
## tails don't swish over the shallows and bank). The water effects still
## reach the shore.
@export_range(0.0, 200.0, 1.0) var swim_inset := 45.0

@export_group("Bands")
## How far each band reaches from the outline, in pond pixels: positive =
## out onto the bank, negative = in toward the middle. Listed outermost
## first; each band is drawn from its line inward to the next one.
@export var band_offsets: PackedFloat32Array = PackedFloat32Array([64.0, 40.0, 20.0, 7.0, 0.0, -14.0, -32.0]):
	set(v): band_offsets = v; queue_redraw()
## One colour per band, same order. The last band is open in the middle
## (the water shows through there).
@export var band_colors: PackedColorArray = PackedColorArray([
	Color(0.09, 0.17, 0.11), Color(0.13, 0.25, 0.14), Color(0.18, 0.33, 0.24),
	Color(0.23, 0.30, 0.27), Color(0.10, 0.17, 0.29), Color(0.08, 0.12, 0.24),
	Color(0.065, 0.085, 0.20)]):
	set(v): band_colors = v; queue_redraw()
## Ground colour far from the pond (fills the whole view outside the bands).
@export var ground_color := Color(0.07, 0.13, 0.09):
	set(v): ground_color = v; queue_redraw()
## How far the ground reaches, in pond pixels from the centre.
@export var ground_extent := 1400.0:
	set(v): ground_extent = v; queue_redraw()
## Makes each band's edge a little uneven, like plants and mud (pond pixels).
@export_range(0.0, 20.0, 0.5) var edge_wobble := 4.0:
	set(v): edge_wobble = v; queue_redraw()
@export_group("")

var _last_polygon: PackedVector2Array


func _ready() -> void:
	color = Color(0, 0, 0, 0)   # Polygon2D's own fill stays invisible
	_last_polygon = polygon


func _process(_delta: float) -> void:
	# Redraw while the outline is being edited in the 2D view.
	if Engine.is_editor_hint() and polygon != _last_polygon:
		_last_polygon = polygon
		queue_redraw()


## The smoothed outline in this node's coordinates.
func outline() -> PackedVector2Array:
	var pts := polygon
	for i in smooth_steps:
		pts = _chaikin(pts)
	return pts


## The swim area fish use: the smoothed outline in world coordinates, pulled
## in by `inset` pond pixels (-1 = Swim Inset; 0 = the shoreline itself).
func make_swim_area(inset := -1.0) -> SwimArea:
	if inset < 0.0:
		inset = swim_inset
	var area := SwimArea.new()
	area.shape = SwimArea.Shape.POLYGON
	var line := outline()
	if inset > 0.0:
		# Biggest piece left after pulling the outline in.
		var best := PackedVector2Array()
		for poly in Geometry2D.offset_polygon(line, -inset, Geometry2D.JOIN_ROUND):
			if Geometry2D.is_polygon_clockwise(poly) == Geometry2D.is_polygon_clockwise(line) and poly.size() > best.size():
				best = poly
		if best.size() >= 3:
			line = best
	var world := PackedVector2Array()
	for p in line:
		world.append(global_transform * p)
	area.points = world
	area.center = global_transform * _centre(polygon)
	return area


func _draw() -> void:
	var line := outline()
	if line.size() < 3:
		return
	var c := _centre(line)
	draw_rect(Rect2(c - Vector2.ONE * ground_extent, Vector2.ONE * ground_extent * 2.0), ground_color)
	var n := mini(band_offsets.size(), band_colors.size())
	for i in n:
		for poly in Geometry2D.offset_polygon(line, band_offsets[i], Geometry2D.JOIN_ROUND):
			if Geometry2D.is_polygon_clockwise(poly) != Geometry2D.is_polygon_clockwise(line):
				continue   # a hole left by the offset, not a band
			var p := _wobble(poly, c, i)
			if Geometry2D.triangulate_polygon(p).is_empty():
				continue
			draw_colored_polygon(p, band_colors[i])
	# The middle is open: punch it back to the pond's water by drawing the
	# deepest band only as a ring (the water colour is the view's background).
	var last := band_offsets[n - 1] if n > 0 else 0.0
	for poly in Geometry2D.offset_polygon(line, last - 18.0, Geometry2D.JOIN_ROUND):
		if Geometry2D.is_polygon_clockwise(poly) != Geometry2D.is_polygon_clockwise(line):
			continue
		var p := _wobble(poly, c, n)
		if not Geometry2D.triangulate_polygon(p).is_empty():
			draw_colored_polygon(p, ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color(0.055, 0.067, 0.176)))


## Nudges points in and out a little, differently for each band.
func _wobble(poly: PackedVector2Array, c: Vector2, band: int) -> PackedVector2Array:
	if edge_wobble <= 0.0:
		return poly
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		var p := poly[i]
		var a := (p - c).angle()
		var k := sin(a * 7.0 + band * 1.9) * 0.6 + sin(a * 17.0 + band * 3.3) * 0.4
		out[i] = p + (p - c).normalized() * k * edge_wobble
	return out


## One round of Chaikin corner cutting on a closed outline.
static func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n < 3:
		return pts
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	return out


static func _centre(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(pts.size(), 1)
