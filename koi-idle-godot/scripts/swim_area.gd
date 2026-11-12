# swim_area.gd
# Resource defining the boundary shape fish must stay within.
# Assign to fish_steering.swim_area at spawn time.
# Multiple fish can share the same resource — change it once, all fish respond.
#
# The pond and the toilet build theirs from a SwimShape node you can see and
# drag in the editor (SwimShape.make_swim_area(), scripts/swim_shape.gd).
class_name SwimArea
extends Resource

enum Shape { CIRCLE, ELLIPSE, RECTANGLE, CAPSULE, POLYGON }

@export var shape:  Shape   = Shape.ELLIPSE
@export var center: Vector2 = Vector2.ZERO
## CIRCLE    — only size.x is used (radius)
## ELLIPSE   — size.x = half-width, size.y = half-height
## RECTANGLE — size.x = half-width, size.y = half-height
## CAPSULE   — size.x = radius, size.y = half the total height (vertical)
@export var size:   Vector2 = Vector2(800.0, 500.0)
## Turns the shape (radians), e.g. PI / 2 for a sideways capsule.
@export var rotation: float = 0.0
## POLYGON — the outline, in world coordinates (any shape, e.g. the pond's
## organic outline from PondShape). center / size / rotation are unused.
@export var points: PackedVector2Array = PackedVector2Array()

## Most points sent to the water shaders for a POLYGON (water_area.gdshaderinc).
const SHADER_POINTS := 64


# --- Polygon helpers ---------------------------------------------------------

## The closest point on the outline to `pos`.
func _nearest_edge_point(pos: Vector2) -> Vector2:
	var best := pos
	var best_d := INF
	var n := points.size()
	for i in n:
		var q := Geometry2D.get_closest_point_to_segment(pos, points[i], points[(i + 1) % n])
		var d := pos.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


func _polygon_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	return r


## The outline with at most `count` points, evenly spaced along it.
func resampled(count: int) -> PackedVector2Array:
	var n := points.size()
	if n <= count:
		return points
	var total := 0.0
	for i in n:
		total += points[i].distance_to(points[(i + 1) % n])
	var out := PackedVector2Array()
	var step := total / count
	var seg := 0
	var seg_start := 0.0
	for k in count:
		var at := k * step
		while seg < n and seg_start + points[seg].distance_to(points[(seg + 1) % n]) < at:
			seg_start += points[seg].distance_to(points[(seg + 1) % n])
			seg += 1
		var a := points[seg % n]
		var b := points[(seg + 1) % n]
		var seg_len := a.distance_to(b)
		out.append(a.lerp(b, (at - seg_start) / seg_len if seg_len > 0.0 else 0.0))
	return out


# Positions are turned into the shape's own unrotated frame first.
func _local(pos: Vector2) -> Vector2:
	return (pos - center).rotated(-rotation)


func _world(local: Vector2) -> Vector2:
	return center + local.rotated(rotation)


# Capsule: the point on its middle segment closest to `local`.
func _spine(local: Vector2) -> Vector2:
	var half := maxf(size.y - size.x, 0.0)
	return Vector2(0.0, clampf(local.y, -half, half))


func is_inside(pos: Vector2) -> bool:
	if shape == Shape.POLYGON:
		return points.size() < 3 or Geometry2D.is_point_in_polygon(pos, points)
	var local = _local(pos)
	match shape:
		Shape.CIRCLE:
			return local.length() < size.x
		Shape.ELLIPSE:
			return pow(local.x / size.x, 2.0) + pow(local.y / size.y, 2.0) < 1.0
		Shape.RECTANGLE:
			return abs(local.x) < size.x and abs(local.y) < size.y
		Shape.CAPSULE:
			return (local - _spine(local)).length() < size.x
	return true


## Returns approximate distance from the boundary edge.
## Positive = inside, negative = outside.
func distance_from_edge(pos: Vector2) -> float:
	if shape == Shape.POLYGON:
		if points.size() < 3:
			return 9999.0
		var d := pos.distance_to(_nearest_edge_point(pos))
		return d if Geometry2D.is_point_in_polygon(pos, points) else -d
	var local = _local(pos)
	match shape:
		Shape.CIRCLE:
			return size.x - local.length()
		Shape.ELLIPSE:
			# Normalised radial distance: 1.0 = on edge, <1.0 = inside
			var n = sqrt(pow(local.x / size.x, 2.0) + pow(local.y / size.y, 2.0))
			return (1.0 - n) * size.length() * 0.5
		Shape.RECTANGLE:
			return min(size.x - abs(local.x), size.y - abs(local.y))
		Shape.CAPSULE:
			return size.x - (local - _spine(local)).length()
	return 9999.0


## Snap a position back inside the boundary.
func clamp_to_boundary(pos: Vector2) -> Vector2:
	if is_inside(pos):
		return pos
	if shape == Shape.POLYGON:
		# Onto the edge, then a pixel inward.
		var e := _nearest_edge_point(pos)
		return e + (e - pos).normalized() * 1.0
	var local = _local(pos)
	match shape:
		Shape.CIRCLE:
			return _world(local.normalized() * size.x * 0.99)
		Shape.ELLIPSE:
			var angle = local.angle()
			return _world(Vector2(cos(angle) * size.x, sin(angle) * size.y) * 0.99)
		Shape.RECTANGLE:
			return _world(Vector2(
				clamp(local.x, -size.x, size.x),
				clamp(local.y, -size.y, size.y)
			))
		Shape.CAPSULE:
			var s := _spine(local)
			return _world(s + (local - s).normalized() * size.x * 0.99)
	return pos


## Unit vector pointing from pos toward the safest interior direction.
func direction_to_safety(pos: Vector2) -> Vector2:
	if shape == Shape.POLYGON:
		# Away from the nearest bit of shore (toward it if outside).
		var e := _nearest_edge_point(pos)
		var away := pos - e
		if away.length() < 0.001:
			return (_polygon_bounds().get_center() - pos).normalized()
		return away.normalized() if Geometry2D.is_point_in_polygon(pos, points) else -away.normalized()
	var local = _local(pos)
	match shape:
		Shape.CIRCLE, Shape.ELLIPSE:
			return (center - pos).normalized()
		Shape.RECTANGLE:
			# Push toward the nearest face rather than toward center
			var dist_x = size.x - abs(local.x)
			var dist_y = size.y - abs(local.y)
			if dist_x < dist_y:
				return Vector2(-sign(local.x), 0.0).rotated(rotation)
			return Vector2(0.0, -sign(local.y)).rotated(rotation)
		Shape.CAPSULE:
			# Toward the capsule's middle line, not its centre point
			var to_spine: Vector2 = _spine(local) - local
			if to_spine.length() < 0.001:
				return (center - pos).normalized()
			return to_spine.normalized().rotated(rotation)
	return (center - pos).normalized()


## Returns a random point well inside the boundary (useful for wander targets).
func get_random_interior_point() -> Vector2:
	if shape == Shape.POLYGON:
		var r := _polygon_bounds()
		var margin := minf(r.size.x, r.size.y) * 0.08
		for i in 60:
			var p := r.position + Vector2(randf(), randf()) * r.size
			if distance_from_edge(p) > margin:
				return p
		return r.get_center()
	match shape:
		Shape.CIRCLE:
			var angle = randf() * TAU
			var r     = sqrt(randf()) * size.x * 0.85
			return center + Vector2(cos(angle), sin(angle)) * r
		Shape.ELLIPSE:
			var angle = randf() * TAU
			var r     = sqrt(randf()) * 0.85
			return _world(Vector2(cos(angle) * size.x * r, sin(angle) * size.y * r))
		Shape.RECTANGLE:
			return _world(Vector2(
				randf_range(-size.x * 0.85, size.x * 0.85),
				randf_range(-size.y * 0.85, size.y * 0.85)
			))
		Shape.CAPSULE:
			var half := maxf(size.y - size.x, 0.0)
			var angle = randf() * TAU
			var r     = sqrt(randf()) * size.x * 0.85
			return _world(Vector2(cos(angle) * r, randf_range(-half, half) * 0.85 + sin(angle) * r))
	return center


## Sets up a view's water layers (nodes with a water ShaderMaterial): each
## gets its own copy of its material (the toilet and pond can share one
## material file but have different shapes), with this shape filled in.
## clip = only draw inside the water (pond_water's clip_to_area).
func setup_water_layers(nodes: Array, clip: bool) -> void:
	for n in nodes:
		var item := n as CanvasItem
		if item == null or not (item.material is ShaderMaterial):
			continue
		var mat: ShaderMaterial = item.material.duplicate()
		item.material = mat
		apply_to_material(mat)
		mat.set_shader_parameter("clip_to_area", clip)


## Gives this shape to a water shader that includes water_area.gdshaderinc
## (pond_water / underwater), so it can stay inside the water or draw along
## the edge.
func apply_to_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	var kind := 0
	var s := size
	match shape:
		Shape.CIRCLE:
			kind = 1
			s = Vector2(size.x, size.x)
		Shape.ELLIPSE:
			kind = 1
		Shape.CAPSULE:
			kind = 2
		Shape.RECTANGLE:
			kind = 3
		Shape.POLYGON:
			kind = 4
			var pts := resampled(SHADER_POINTS)
			mat.set_shader_parameter("area_point_count", pts.size())
			pts.resize(SHADER_POINTS)
			mat.set_shader_parameter("area_points", pts)
	mat.set_shader_parameter("area_shape", kind)
	mat.set_shader_parameter("area_center", center)
	mat.set_shader_parameter("area_size", s)
	mat.set_shader_parameter("area_rotation", rotation)
