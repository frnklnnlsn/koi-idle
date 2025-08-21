extends Line2D

var rotation_offset := PI / 4 

@onready var koi = $".."
@onready var fish_body = %"fish body"

@export var ellipse_size := Vector2(20, 10)  # Width, height of ellipses
@export var ellipse_spacing := 5  # Every 5 points on the line
@export var ellipse_offset1 := 20  # Distance from the line
@export var ellipse_offset2 := 35  # Distance from the line
@export var ellipse_color := Color(1, 0.498039, 0.313726, 1)



func _ready():
	
	pass 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var parent = get_parent()
	var num_points = parent.num_points
	
	#ellipse_color = fish_body.default_color
	
	#for i in range(num_points):
		#print("this is point"+ str(i) + ": " + str(get_point_position(i)))


func _draw():
	draw_ellipses_at_index(2, ellipse_offset2)
#
	# Draw second pair of ellipses at point 7
	#draw_ellipses_at_index(7, ellipse_offset1)




func draw_ellipses_at_index(index: int, ellipse_offset):
	if index < get_point_count() - 1 and ellipse_offset != null:
		var pos = get_point_position(index)
		var next_pos = get_point_position(index + 1)
		var dir = (next_pos - pos).normalized()

		# Get perpendicular vector to the line direction
		var perp_dir = dir.rotated(PI / 2) * ellipse_offset

		# Place ellipses on both sides
		var ellipse1_pos = pos + perp_dir
		var ellipse2_pos = pos - perp_dir

		# Rotate the ellipses based on the direction of movement
		var angle1 = dir.angle() + PI / 2 + rotation_offset  # Adjusted to point between down and further down
		var angle2 = dir.angle() + PI / 1 + rotation_offset
		# Draw mirrored ellipses with inverted rotation (left side)
		_draw_rotated_ellipse(ellipse1_pos, angle2 + PI)  # Invert the angle for left side

		# Draw ellipses with rotation (right side)
		_draw_rotated_ellipse(ellipse2_pos, angle1)  # No inversion on right side


func _draw_rotated_ellipse(center: Vector2, angle: float):
	var num_points = 32
	var points = PackedVector2Array()
	
	# Generate ellipse points and apply rotation
	for i in range(num_points):
		var angle_offset = TAU * i / num_points
		var x = ellipse_size.x * cos(angle_offset)
		var y = ellipse_size.y * sin(angle_offset)

		# Apply rotation using the given angle
		var rotated_x = x * cos(angle) - y * sin(angle)
		var rotated_y = x * sin(angle) + y * cos(angle)

		points.append(center + Vector2(rotated_x, rotated_y))

	draw_colored_polygon(points, ellipse_color)
