extends Control

# Default S-curve parameters (will be overridden by fish data)
@export var growth_rate: float = 3.0
@export var carrying_capacity: float = 100.0
@export var midpoint: float = 5.0  # Move midpoint to middle of positive range
@export var x_range: float = 10.0  # Shorter range for cleaner display
@export var x_start: float = 0.0   # Start at 0 (positive values only)
@export var y_start: float = 0.0
@export var num_points: int = 200

# Dynamic scaling based on control size - CONSISTENT LIKE DISTRIBUTION GRAPH
@export var margin_percent: Vector2 = Vector2(0.1, 0.2)  # 10% horizontal, 20% vertical margins
@export var curve_height_percent: float = 0.6  # Use 60% of available height for curve

# Axis properties
@export var axis_color: Color = Color.WHITE
@export var axis_width: float = 2.0
@export var tick_length: float = 10.0
@export var num_x_ticks: int = 6  # Reduced from 11 to 6 for less clutter
@export var num_y_ticks: int = 6

# S-curve line properties
@export var curve_color: Color = Color.WHITE
@export var curve_width: float = 3.0

# Fish marker properties
@export var fish_marker_color: Color = Color.YELLOW
@export var fish_marker_radius: float = 8.0
@export var fish_line_width: float = 2.0
@export var dash_length: float = 10.0
@export var dash_gap: float = 5.0

# FIXED POSITIONING VARIABLES - Similar to distribution graph
var center_x: float
var center_y: float
var scale_x: float
var scale_y: float

# Dynamic range variables - these change with fish data
var display_x_min: float
var display_x_max: float
var display_y_min: float
var display_y_max: float

# Fish growth variables
var current_fish_res = null
var is_fish_displayed: bool = false

func _ready():
	await get_tree().process_frame
	calculate_dynamic_positioning()
	
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	queue_redraw()

# Public functions to control the fish growth curve
func set_fish_growth(fish_res):
	"""Set the fish growth data and redraw the entire curve with fish parameters"""
	current_fish_res = fish_res
	is_fish_displayed = true
	
	# Update curve parameters from fish resource
	if fish_res:
		growth_rate = fish_res.growth_rate
		carrying_capacity = fish_res.carrying_capacity
		midpoint = fish_res.mid_point
		#print("midpoint" + str(midpoint))
		x_range = fish_res.x_range
		#print("x range" + str(x_range))
		x_start = fish_res.x_start
		y_start = fish_res.y_start
	
	# Update display ranges but keep same visual size
	update_display_ranges()
	queue_redraw()

func clear_fish_growth():
	"""Clear the fish growth curve and return to default parameters"""
	current_fish_res = null
	is_fish_displayed = false
	
	# Reset to positive-only default parameters
	growth_rate = 3.0
	carrying_capacity = 100.0
	midpoint = 5.0     # Middle of 0-10 range
	x_range = 10.0     # 0 to 10
	x_start = 0.0      # Start at 0
	y_start = 0.0
	
	# Update display ranges but keep same visual size
	update_display_ranges()
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
	
	# Calculate margins - SAME AS DISTRIBUTION GRAPH
	var margin_x = control_size.x * margin_percent.x
	var margin_y = control_size.y * margin_percent.y
	
	# Calculate available space
	var available_width = control_size.x - 2 * margin_x
	var available_height = control_size.y - 2 * margin_y
	
	# FIXED POSITIONING - Similar to distribution graph approach
	# Position graph area consistently regardless of data
	center_x = margin_x + available_width * 0.5  # Center horizontally
	center_y = margin_y + available_height * 0.7  # Position in upper portion
	
	# FIXED SCALING - Graph visual size stays the same
	# Make it match the distribution graph size more closely
	scale_x = available_width * 0.9  # Increased from 0.8 to 0.9 for larger visual size
	scale_y = available_height * curve_height_percent  # Use percentage of height
	
	# Update display ranges
	update_display_ranges()

func update_display_ranges():
	"""Update the ranges that will be displayed on the axes - centered around midpoint"""
	# Center the view around the midpoint for better visualization
	var half_range = x_range * 0.5
	var centered_min = midpoint - half_range
	var centered_max = midpoint + half_range
	
	# Ensure we never go below 0 (keep x-axis positive)
	display_x_min = max(centered_min, 0.0)
	display_x_max = display_x_min + x_range
	
	# If centering around midpoint would cut off too much of the curve,
	# adjust to keep the important part visible while staying positive
	if midpoint < display_x_min + x_range * 0.2:
		# Midpoint is too close to the left edge, shift right but stay positive
		display_x_min = max(midpoint - x_range * 0.3, 0.0)
		display_x_max = display_x_min + x_range
	elif midpoint > display_x_max - x_range * 0.2:
		# Midpoint is too close to the right edge, shift left but don't go negative
		display_x_max = midpoint + x_range * 0.3
		display_x_min = max(display_x_max - x_range, 0.0)
	
	display_y_min = y_start
	display_y_max = y_start + carrying_capacity

# Logistic growth function (S-curve)
func logistic_function(x: float) -> float:
	var exponent = -growth_rate * (x - midpoint)
	return carrying_capacity / (1.0 + exp(exponent))

# Helper functions to convert values to screen positions
# These now map the data ranges to the FIXED visual space
func x_to_screen_x(x_value: float) -> float:
	# Map x_value from [display_x_min, display_x_max] to the fixed graph width
	var normalized_x = (x_value - display_x_min) / (display_x_max - display_x_min)
	return center_x - scale_x * 0.45 + normalized_x * scale_x * 0.9  # Use more of the available width

func y_to_screen_y(y_value: float) -> float:
	# Map y_value from [display_y_min, display_y_max] to the fixed graph height
	var normalized_y = (y_value - display_y_min) / (display_y_max - display_y_min)
	return center_y - normalized_y * scale_y

func _draw():
	if scale_x <= 0 or scale_y <= 0:
		return
	
	draw_axes()
	draw_s_curve()

func draw_s_curve():
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = lerpf(display_x_min, display_x_max, i / float(num_points - 1))
		var y = logistic_function(x) + y_start  # Add y_start offset
		var screen_x = x_to_screen_x(x)
		var screen_y = y_to_screen_y(y)
		points.append(Vector2(screen_x, screen_y))
	
	draw_polyline(points, curve_color, curve_width)

func draw_axes():
	# Calculate fixed axis positions
	var y_axis_x = x_to_screen_x(display_x_min)  # Y-axis at left edge
	var x_axis_y = y_to_screen_y(display_y_min)  # X-axis at bottom edge
	var graph_right = x_to_screen_x(display_x_max)
	var graph_top = y_to_screen_y(display_y_max)
	
	# Draw X axis (horizontal line)
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(graph_right + 20, x_axis_y), axis_color, axis_width)
	
	# Draw Y axis (vertical line) 
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(y_axis_x, graph_top - 20), axis_color, axis_width)
	
	# Draw X axis ticks and labels
	var x_tick_spacing = x_range / float(num_x_ticks - 1) if num_x_ticks > 1 else x_range
	for i in range(num_x_ticks):
		var x_value = display_x_min + i * x_tick_spacing
		if x_value <= display_x_max:
			var screen_x = x_to_screen_x(x_value)
			
			# Draw tick mark
			draw_line(
				Vector2(screen_x, x_axis_y - tick_length/2),
				Vector2(screen_x, x_axis_y + tick_length/2),
				axis_color,
				axis_width
			)
			
			# Draw label - format based on whether it's a clean integer
			var label_text: String
			if abs(x_value - round(x_value)) < 0.01:  # Close to integer
				label_text = str(int(round(x_value)))
			else:
				label_text = "%.1f" % x_value
			
			draw_string(
				ThemeDB.fallback_font,
				Vector2(screen_x - 5, x_axis_y + 25),
				label_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				16,
				axis_color
			)
	
	# Draw Y axis ticks and labels
	var y_tick_spacing = (display_y_max - display_y_min) / float(num_y_ticks - 1) if num_y_ticks > 1 else (display_y_max - display_y_min)
	for i in range(num_y_ticks):
		var y_value = display_y_min + i * y_tick_spacing
		if y_value <= display_y_max:
			var screen_y = y_to_screen_y(y_value)
			
			# Draw tick mark
			draw_line(
				Vector2(y_axis_x - tick_length/2, screen_y),
				Vector2(y_axis_x + tick_length/2, screen_y),
				axis_color,
				axis_width
			)
			
			# Draw label - always round to nearest integer for cleaner display
			var label_text = str(int(round(y_value)))
			
			draw_string(
				ThemeDB.fallback_font,
				Vector2(y_axis_x - 40, screen_y + 5),
				label_text,
				HORIZONTAL_ALIGNMENT_RIGHT,
				-1,
				14,
				axis_color
			)
