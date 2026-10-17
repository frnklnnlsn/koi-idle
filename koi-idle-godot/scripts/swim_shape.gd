# swim_shape.gd
# Put this on a CollisionShape2D to make it a fish swim boundary you can see
# and drag in the editor. Move, resize, scale or rotate it there; fish stay
# inside its outline.
#
#   CircleShape2D       circle (or an ellipse, if you scale it unevenly)
#   RectangleShape2D    rectangle
#   CapsuleShape2D      capsule (rotate the node 90° for a sideways one)
#
# The toilet and the pond each have one: ToiletArea/SwimShape and
# PondArea/SwimShape. In game, Debug > Visible Collision Shapes shows it.
class_name SwimShape
extends CollisionShape2D


## Builds the SwimArea fish use, in the same world coordinates as the fish.
func make_swim_area() -> SwimArea:
	var area := SwimArea.new()
	var xf := global_transform
	var sc := xf.get_scale().abs()
	area.center = xf.origin
	area.rotation = xf.get_rotation()
	if shape is CircleShape2D:
		var r: float = shape.radius
		if is_equal_approx(sc.x, sc.y):
			area.shape = SwimArea.Shape.CIRCLE
			area.size = Vector2.ONE * r * sc.x
		else:
			area.shape = SwimArea.Shape.ELLIPSE
			area.size = Vector2(r * sc.x, r * sc.y)
	elif shape is RectangleShape2D:
		area.shape = SwimArea.Shape.RECTANGLE
		area.size = shape.size * 0.5 * sc
	elif shape is CapsuleShape2D:
		area.shape = SwimArea.Shape.CAPSULE
		area.size = Vector2(shape.radius * sc.x, shape.height * 0.5 * sc.y)
	else:
		push_warning("SwimShape %s: use a circle, rectangle or capsule; using a circle of radius 100." % get_path())
		area.shape = SwimArea.Shape.CIRCLE
		area.size = Vector2.ONE * 100.0
	return area
