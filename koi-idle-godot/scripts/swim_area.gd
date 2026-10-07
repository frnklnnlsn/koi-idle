# swim_area.gd
# Resource defining the boundary shape fish must stay within.
# Assign to fish_steering.swim_area at spawn time.
# Multiple fish can share the same resource — change it once, all fish respond.
class_name SwimArea
extends Resource

enum Shape { CIRCLE, ELLIPSE, RECTANGLE }

@export var shape:  Shape   = Shape.ELLIPSE
@export var center: Vector2 = Vector2.ZERO
## CIRCLE  — only size.x is used (radius)
## ELLIPSE — size.x = half-width, size.y = half-height
## RECTANGLE — size.x = half-width, size.y = half-height
@export var size:   Vector2 = Vector2(800.0, 500.0)


func is_inside(pos: Vector2) -> bool:
	var local = pos - center
	match shape:
		Shape.CIRCLE:
			return local.length() < size.x
		Shape.ELLIPSE:
			return pow(local.x / size.x, 2.0) + pow(local.y / size.y, 2.0) < 1.0
		Shape.RECTANGLE:
			return abs(local.x) < size.x and abs(local.y) < size.y
	return true


## Returns approximate distance from the boundary edge.
## Positive = inside, negative = outside.
func distance_from_edge(pos: Vector2) -> float:
	var local = pos - center
	match shape:
		Shape.CIRCLE:
			return size.x - local.length()
		Shape.ELLIPSE:
			# Normalised radial distance: 1.0 = on edge, <1.0 = inside
			var n = sqrt(pow(local.x / size.x, 2.0) + pow(local.y / size.y, 2.0))
			return (1.0 - n) * size.length() * 0.5
		Shape.RECTANGLE:
			return min(size.x - abs(local.x), size.y - abs(local.y))
	return 9999.0


## Snap a position back inside the boundary.
func clamp_to_boundary(pos: Vector2) -> Vector2:
	if is_inside(pos):
		return pos
	match shape:
		Shape.CIRCLE:
			return center + (pos - center).normalized() * size.x * 0.99
		Shape.ELLIPSE:
			var angle = (pos - center).angle()
			return center + Vector2(cos(angle) * size.x, sin(angle) * size.y) * 0.99
		Shape.RECTANGLE:
			var local = pos - center
			return center + Vector2(
				clamp(local.x, -size.x, size.x),
				clamp(local.y, -size.y, size.y)
			)
	return pos


## Unit vector pointing from pos toward the safest interior direction.
func direction_to_safety(pos: Vector2) -> Vector2:
	var local = pos - center
	match shape:
		Shape.CIRCLE, Shape.ELLIPSE:
			return (center - pos).normalized()
		Shape.RECTANGLE:
			# Push toward the nearest face rather than toward center
			var dist_x = size.x - abs(local.x)
			var dist_y = size.y - abs(local.y)
			if dist_x < dist_y:
				return Vector2(-sign(local.x), 0.0)
			return Vector2(0.0, -sign(local.y))
	return (center - pos).normalized()


## Returns a random point well inside the boundary (useful for wander targets).
func get_random_interior_point() -> Vector2:
	match shape:
		Shape.CIRCLE:
			var angle = randf() * TAU
			var r     = sqrt(randf()) * size.x * 0.85
			return center + Vector2(cos(angle), sin(angle)) * r
		Shape.ELLIPSE:
			var angle = randf() * TAU
			var r     = sqrt(randf()) * 0.85
			return center + Vector2(cos(angle) * size.x * r, sin(angle) * size.y * r)
		Shape.RECTANGLE:
			return center + Vector2(
				randf_range(-size.x * 0.85, size.x * 0.85),
				randf_range(-size.y * 0.85, size.y * 0.85)
			)
	return center
