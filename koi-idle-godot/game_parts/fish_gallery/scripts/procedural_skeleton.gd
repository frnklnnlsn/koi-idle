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
@export var very_slow_ellipse_size := Vector2(16, 7)
@export var accelerating_ellipse_size := Vector2(19, 9)
@export var slow_ellipse_size := Vector2(20, 10)
@export var fast_ellipse_size := Vector2(24, 12)
@export var decelerating_ellipse_size := Vector2(21, 9)

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
		koi.FishState.VERY_SLOW_SWIM:
			ellipse_size = very_slow_ellipse_size
		koi.FishState.ACCELERATING:
			# Interpolate size during acceleration
			var progress = koi.state_timer / koi.acceleration_duration
			var start_size = very_slow_ellipse_size
			var target_size = slow_ellipse_size if koi.target_state == koi.FishState.SLOW_SWIM else fast_ellipse_size
			ellipse_size = start_size.lerp(target_size, ease_out_quad(progress))
		koi.FishState.SLOW_SWIM:
			ellipse_size = slow_ellipse_size
		koi.FishState.FAST_SWIM:
			ellipse_size = fast_ellipse_size
		koi.FishState.DECELERATING:
			# Interpolate size during deceleration
			var progress = koi.state_timer / koi.deceleration_duration
			var start_size = fast_ellipse_size if koi.start_speed > 0.6 else slow_ellipse_size
			var target_size = very_slow_ellipse_size if koi.target_state == koi.FishState.VERY_SLOW_SWIM else slow_ellipse_size
			ellipse_size = start_size.lerp(target_size, ease_in_quad(progress))
		koi.FishState.EATING:
			ellipse_size = Vector2(22, 14)  # Slightly larger for eating

func _draw():
	# Draw fins at different positions based on state
	var current_state = koi.get_current_state() if koi else 0
	
	match current_state:
		koi.FishState.VERY_SLOW_SWIM:
			# Static fins for very slow swimming
			draw_ellipses_at_index(2, ellipse_offset2 * 0.9)
		koi.FishState.ACCELERATING:
			# Normal fins during acceleration
			draw_ellipses_at_index(2, ellipse_offset2)
		koi.FishState.DECELERATING:
			# Normal fins during deceleration
			draw_ellipses_at_index(2, ellipse_offset2)
		koi.FishState.SLOW_SWIM:
			# Normal swimming fins
			draw_ellipses_at_index(2, ellipse_offset2)
		koi.FishState.FAST_SWIM:
			# Fast swimming with additional fins
			draw_ellipses_at_index(2, ellipse_offset2)
			draw_ellipses_at_index(1, ellipse_offset1 * 0.6)  # Additional smaller fins
		koi.FishState.EATING:
			# Eating fins
			draw_ellipses_at_index(2, ellipse_offset2 * 1.1)
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

# Custom easing functions
func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t
