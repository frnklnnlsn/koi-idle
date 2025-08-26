extends Control

@export var peak_position: float = 2.0  # Where the curve peaks
@export var decay_rate: float = 0.3  # Controls right-side decay (lower = longer tail)
@export var left_steepness: float = 10.0  # Controls left-side steepness (higher = steeper)
@export var num_points: int = 200
@export var range_min: float = 0.0  # Start of the range
@export var range_max: float = 10.0  # End of the range

# Dynamic scaling based on control size
@export var margin_percent: Vector2 = Vector2(0.1, 0.2)  # 10% horizontal, 20% vertical margins
@export var curve_height_percent: float = 0.6  # Use 60% of available height for curve

# Axis properties
@export var axis_color: Color = Color.BLACK
@export var axis_width: float = 2.0
@export var tick_length: float = 10.0
@export var num_x_ticks: int = 11  # Number of ticks on X axis (0 to 10)

# Bell curve line properties
@export var curve_color: Color = Color.WHITE
@export var curve_width: float = 3.0

# Fish marker properties
@export var fish_marker_color: Color = Color.YELLOW
@export var fish_marker_radius: float = 8.0
@export var fish_line_width: float = 2.0
@export var dash_length: float = 10.0
@export var dash_gap: float = 5.0

var center_x: float
var center_y: float
var max_y_value: float
var scale_x: float
var scale_y: float

# Fish marker variables
var fish_value: float = -1.0  # -1 indicates no fish is being hovered
var is_fish_hovered: bool = false

func _ready():
	# Wait for the control to be properly sized
	await get_tree().process_frame
	calculate_dynamic_positioning()
	
	# Connect the resized signal to recalculate positioning
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	queue_redraw()

# Public functions to control the fish marker
func set_fish_value(value: float):
	#print("float: " + str(value))
	"""Set the fish value and show the marker on the graph"""
	fish_value = value
	is_fish_hovered = true
	queue_redraw()

func clear_fish_value():
	"""Clear the fish value marker from the graph"""
	is_fish_hovered = false
	fish_value = -1.0
	queue_redraw()

func _on_resized():
	# Recalculate positioning when the control is resized
	calculate_dynamic_positioning()
	queue_redraw()

func calculate_dynamic_positioning():
	var control_size = get_rect().size
	
	# Prevent issues with zero size
	if control_size.x <= 0 or control_size.y <= 0:
		return
	
	# Calculate margins
	var margin_x = control_size.x * margin_percent.x
	var margin_y = control_size.y * margin_percent.y
	
	# Calculate available space
	var available_width = control_size.x - 2 * margin_x
	var available_height = control_size.y - 2 * margin_y
	
	# Calculate center position within the control
	center_x = margin_x + available_width * 0.3  # Shift left since curve peaks early
	center_y = margin_y + available_height * 0.7  # Position curve in upper portion
	
	# Calculate dynamic scaling
	scale_x = available_width / (range_max - range_min)
	max_y_value = custom_skewed_distribution(peak_position)
	scale_y = (available_height * curve_height_percent) / max_y_value

# Custom skewed distribution that matches your create_right_skewed_array function
func custom_skewed_distribution(x: float) -> float:
	var weight: float
	
	if x <= peak_position:
		# Left side: steep drop-off (matches your Gaussian-like left side)
		var distance_left = peak_position - x
		weight = 100.0 * exp(-pow(distance_left, 2) / left_steepness)
	else:
		# Right side: gradual exponential decay (long tail)
		var distance_right = x - peak_position
		weight = 100.0 * exp(-decay_rate * distance_right)
	
	# Ensure minimum weight and normalize
	weight = max(weight, 1.0)
	return weight / 100.0  # Normalize to reasonable scale

# Helper function to convert x-value to screen x position
func x_to_screen_x(x_value: float) -> float:
	return (x_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)

# Helper function to convert y-value to screen y position
func y_to_screen_y(y_value: float) -> float:
	return center_y - y_value * scale_y

func draw_fish_marker():
	"""Draw the fish value marker on the graph"""
	if not is_fish_hovered or fish_value < range_min or fish_value > range_max:
		return
		
	# Calculate screen position for the fish value
	var screen_x = x_to_screen_x(fish_value)
	
	# Calculate y position on the curve
	var curve_y = custom_skewed_distribution(fish_value)
	var screen_y = y_to_screen_y(curve_y)
	
	# Draw vertical dashed line from x-axis to the curve point
	draw_fish_dashed_line(screen_x, center_y, screen_y)
	
	# Draw the fish marker dot with border for better visibility
	draw_circle(Vector2(screen_x, screen_y), fish_marker_radius + 1, Color.BLACK)
	draw_circle(Vector2(screen_x, screen_y), fish_marker_radius, fish_marker_color)

func draw_fish_dashed_line(x: float, start_y: float, end_y: float):
	"""Draw a vertical dashed line for the fish marker"""
	var current_y = max(start_y, end_y)  # Start from the higher point
	var target_y = min(start_y, end_y)   # Go to the lower point
	var is_dash = true
	
	while current_y > target_y:
		var segment_end = current_y - (dash_length if is_dash else dash_gap)
		segment_end = max(segment_end, target_y)
		
		if is_dash:
			draw_line(
				Vector2(x, current_y),
				Vector2(x, segment_end),
				fish_marker_color,
				fish_line_width
			)
		
		current_y = segment_end
		is_dash = not is_dash

func _draw():
	# Only draw if we have valid dimensions
	if scale_x <= 0 or scale_y <= 0:
		return
		
	draw_axes()
	draw_skewed_curve()     # Draw right-skewed curve
	
	# Draw the fish value marker
	if is_fish_hovered:
		draw_fish_marker()

func draw_skewed_curve():
	# Draw the right-skewed curve using draw_polyline
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = lerp(range_min, range_max, i / float(num_points - 1))
		var y = custom_skewed_distribution(x)
		# Map x and y to screen space
		var screen_x = x_to_screen_x(x)
		var screen_y = y_to_screen_y(y)
		points.append(Vector2(screen_x, screen_y))
	
	# Draw the curve as a polyline
	draw_polyline(points, curve_color, curve_width)

func draw_axes():
	# Draw X axis (only from y-axis intersection to the right)
	var y_axis_x = x_to_screen_x(0.0)  # X position of y-axis
	var x_end = center_x + (range_max - range_min) * scale_x * 0.7 + 20
	draw_line(Vector2(y_axis_x, center_y), Vector2(x_end, center_y), axis_color, axis_width)
	
	# Draw Y axis (only from x-axis intersection upward)
	var y_start = center_y - max_y_value * scale_y - 50
	draw_line(Vector2(y_axis_x, center_y), Vector2(y_axis_x, y_start), axis_color, axis_width)
	
	# Draw X axis ticks and labels (integers 0-10)
	for i in range(11):  # 0 to 10 inclusive
		var x_value = float(i)
		var screen_x = x_to_screen_x(x_value)
		
		# Draw tick mark
		draw_line(
			Vector2(screen_x, center_y - tick_length/2),
			Vector2(screen_x, center_y + tick_length/2),
			axis_color,
			axis_width
		)
		
		# Draw label (integer values)
		var label_text = str(i)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(screen_x - 5, center_y + 25),
			label_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			axis_color
		)
