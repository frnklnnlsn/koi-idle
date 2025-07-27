extends Line2D

var rotation_offset := PI / 4 
@onready var koi = $".."
@onready var fish_body = %"fish body"

@export var ellipse_size := Vector2(20, 10)
@export var ellipse_spacing := 5
@export var ellipse_offset1 := 20
@export var ellipse_offset2 := 35
@export var ellipse_color := Color(1, 0.498039, 0.313726, 1)

# State-specific visual parameters
@export var straight_ellipse_size := Vector2(20, 10)
@export var squiggling_ellipse_size := Vector2(24, 12)

var time := 0.0

func _ready():
	pass

func _process(delta):
	time += delta
	var parent = get_parent()
	var num_points = parent.num_points
	
	# Adjust visual parameters based on state
	update_visuals_for_state()

func update_visuals_for_state():
	if not koi:
		return
	
	var current_state = koi.get_current_state()
	
	# Adjust ellipse size based on state
	match current_state:
		koi.FishState.STRAIGHT:
			ellipse_size = straight_ellipse_size
		koi.FishState.SQUIGGLING:
			# Make fins slightly larger and more dynamic during squiggling
			var squiggle_intensity = abs(sin(time * koi.squiggle_frequency * TAU))
			var base_size = squiggling_ellipse_size
			var size_variation = Vector2(4, 2) * squiggle_intensity
			ellipse_size = base_size + size_variation

func _draw():
	if not koi:
		return
		
	# Draw fins at different positions based on state
	var current_state = koi.get_current_state()
	
	match current_state:
		koi.FishState.STRAIGHT:
			# Static fins for straight swimming
			draw_ellipses_at_index(2, ellipse_offset2)
		koi.FishState.SQUIGGLING:
			# Dynamic fins during squiggling - add movement to fin position
			var squiggle_intensity = sin(time * koi.squiggle_frequency * TAU) * 0.3
			var dynamic_offset1 = ellipse_offset1 + (ellipse_offset1 * squiggle_intensity * 0.2)
			var dynamic_offset2 = ellipse_offset2 + (ellipse_offset2 * squiggle_intensity * 0.1)
			
			# Draw main fins with slight offset variation
			draw_ellipses_at_index(2, dynamic_offset2)
			# Add additional smaller fins during active propulsion
			if abs(squiggle_intensity) > 0.5:
				draw_ellipses_at_index(1, dynamic_offset1 * 0.6)
		_:
			# Default case
			draw_ellipses_at_index(2, ellipse_offset2)

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
		var angle1 = dir.angle() + PI / 2 + rotation_offset
		var angle2 = dir.angle() + PI / 1 + rotation_offset
		
		# Add slight rotation variation during squiggling
		if koi and koi.get_current_state() == koi.FishState.SQUIGGLING:
			var rotation_variation = sin(time * koi.squiggle_frequency * TAU) * 0.1
			angle1 += rotation_variation
			angle2 += rotation_variation
		
		# Draw mirrored ellipses with inverted rotation (left side)
		draw_rotated_ellipse(ellipse1_pos, angle2 + PI)
		# Draw ellipses with rotation (right side)
		draw_rotated_ellipse(ellipse2_pos, angle1)

func draw_rotated_ellipse(center: Vector2, angle: float):
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

# Custom easing functions (kept for potential future use)
func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t
