extends Control

# S-curve parameters
@export var growth_rate: float = 3  # Controls steepness of the curve
@export var carrying_capacity: float = 100.0  # Maximum value (K in logistic equation)
@export var midpoint: float = 0.0  # Inflection point (where growth is fastest)
@export var num_points: int = 200
@export var x_range: float = 20.0  # Total range to display
@export var x_start: float = -2  # Starting X value (left side of graph)
@export var y_start: float = 0.0  # Starting Y value (bottom of graph)

# Dynamic scaling based on control size
@export var margin_percent: Vector2 = Vector2(0.1, 0.2)  # 10% horizontal, 20% vertical margins
@export var curve_height_percent: float = 0.7  # Use 70% of available height for curve

# Axis properties
@export var axis_color: Color = Color.BLACK
@export var axis_width: float = 2.0
@export var tick_length: float = 10.0
@export var num_x_ticks: int = 9  # Number of ticks on X axis
@export var num_y_ticks: int = 6  # Number of ticks on Y axis

# S-curve line properties
@export var curve_color: Color = Color.WHITE
@export var curve_width: float = 3.0

# Growth phase colors
@export var phase_colors: Array[Color] = [
	Color(1.0, 0.4, 0.4, 0.6),  # Red - Slow start phase
	Color(0.2, 0.8, 0.5, 0.6),  # Green - Exponential growth phase
	Color(0.4, 0.6, 1.0, 0.6)   # Blue - Saturation phase
]

# Phase labels
@export var phase_labels: Array[String] = ["Slow Start", "Exponential Growth", "Saturation"]

# Label properties
@export var label_font_size: int = 20
@export var label_text_color: Color = Color.WHITE

# Slider indicator properties
@export var indicator_color: Color = Color.RED
@export var indicator_dot_radius: float = 6.0
@export var indicator_line_width: float = 2.0
@export var dash_length: float = 10.0
@export var dash_gap: float = 5.0

@onready var slider = $HSlider

var center_x: float
var bottom_y: float
var top_y: float
var scale_x: float
var scale_y: float
var x_min: float
var x_max: float

func _ready():
	# Wait for the control to be properly sized
	await get_tree().process_frame
	calculate_dynamic_positioning()
	setup_slider()
	
	# Connect the resized signal to recalculate positioning
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	queue_redraw()

func _on_resized():
	# Recalculate positioning when the control is resized
	calculate_dynamic_positioning()
	setup_slider()
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
	
	# Calculate center and bounds
	center_x = control_size.x / 2
	bottom_y = control_size.y - margin_y - 60  # Leave space for slider
	top_y = margin_y + 20
	
	# Set x range
	x_min = x_start
	x_max = x_start + x_range
	
	# Calculate dynamic scaling
	scale_x = available_width / x_range
	scale_y = (available_height * curve_height_percent) / carrying_capacity
	
	# Adjust font sizes based on control size
	label_font_size = int(clamp(control_size.x / 50, 14, 28))

func setup_slider():
	if slider:
		# Position slider at the bottom of the control
		var control_size = get_rect().size
		if control_size.x <= 0 or control_size.y <= 0:
			return
			
		var slider_margin = 20
		slider.position.x = slider_margin
		slider.position.y = control_size.y - 40
		slider.size.x = control_size.x - 2 * slider_margin
		
		# Set slider range to match the graph range
		slider.min_value = x_min
		slider.max_value = x_max
		slider.value = midpoint  # Start at the midpoint
		slider.step = 0.1
		
		# Connect slider signal
		if not slider.value_changed.is_connected(_on_slider_value_changed):
			slider.value_changed.connect(_on_slider_value_changed)

func _on_slider_value_changed(value: float):
	queue_redraw()

# Logistic growth function (S-curve)
func logistic_function(x: float) -> float:
	var exponent = -growth_rate * (x - midpoint)
	return carrying_capacity / (1.0 + exp(exponent))

# Derivative of logistic function (growth rate at point x)
func growth_rate_at_point(x: float) -> float:
	var y = logistic_function(x)
	return growth_rate * y * (1.0 - y / carrying_capacity)

func _draw():
	# Only draw if we have valid dimensions
	if scale_x <= 0 or scale_y <= 0:
		return
		
	draw_colored_phases()
	draw_axes()
	draw_s_curve()
	draw_slider_line()
	draw_slider_dot()

func draw_s_curve():
	# Draw the S-curve using draw_polyline
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = lerpf(x_min, x_max, i / float(num_points - 1))
		var y = logistic_function(x)
		# Map x and y to screen space
		var screen_x = (x - x_min) * scale_x + (center_x - x_range * scale_x / 2)
		var screen_y = bottom_y - y * scale_y
		points.append(Vector2(screen_x, screen_y))
	
	# Draw the curve as a polyline
	draw_polyline(points, curve_color, curve_width)

func draw_slider_line():
	if not slider:
		return
		
	var slider_value = slider.value
	var screen_x = (slider_value - x_min) * scale_x + (center_x - x_range * scale_x / 2)
	
	# Draw vertical dashed line
	draw_dashed_line_vertical(screen_x)

func draw_slider_dot():
	if not slider:
		return
		
	var slider_value = slider.value
	
	# Calculate screen position
	var screen_x = (slider_value - x_min) * scale_x + (center_x - x_range * scale_x / 2)
	
	# Calculate y position on the curve
	var curve_y = logistic_function(slider_value)
	var screen_y = bottom_y - curve_y * scale_y
	
	# Draw red dot on the curve
	draw_circle(Vector2(screen_x, screen_y), indicator_dot_radius, indicator_color)

func draw_dashed_line_vertical(x: float):
	var graph_top = top_y
	var graph_bottom = bottom_y
	
	var current_y = graph_top
	var is_dash = true
	
	while current_y < graph_bottom:
		var segment_end = current_y + (dash_length if is_dash else dash_gap)
		segment_end = min(segment_end, graph_bottom)
		
		if is_dash:
			draw_line(
				Vector2(x, current_y),
				Vector2(x, segment_end),
				indicator_color,
				indicator_line_width
			)
		
		current_y = segment_end
		is_dash = not is_dash

func draw_colored_phases():
	# Define phase boundaries based on growth characteristics
	# Phase 1: Slow start (0% to ~25% of carrying capacity)
	# Phase 2: Exponential growth (~25% to ~75% of carrying capacity) 
	# Phase 3: Saturation (~75% to 100% of carrying capacity)
	
	var phase_y_boundaries = [
		0.0,
		carrying_capacity * 0.25,
		carrying_capacity * 0.75,
		carrying_capacity
	]
	
	# Find x positions for these y boundaries
	var phase_x_boundaries = []
	for y_boundary in phase_y_boundaries:
		if y_boundary <= 0:
			phase_x_boundaries.append(x_min)
		elif y_boundary >= carrying_capacity:
			phase_x_boundaries.append(x_max)
		else:
			# Solve for x when y = y_boundary using inverse logistic function
			var ratio = y_boundary / carrying_capacity
			var ln_term = log((1.0 / ratio) - 1.0)
			var x_boundary = midpoint - ln_term / growth_rate
			phase_x_boundaries.append(clamp(x_boundary, x_min, x_max))
	
	# Draw each phase
	for i in range(3):  # Three phases
		if i >= phase_colors.size():
			break
			
		var start_x = phase_x_boundaries[i]
		var end_x = phase_x_boundaries[i + 1]
		
		draw_phase_fill(start_x, end_x, phase_colors[i])

func draw_phase_fill(start_x: float, end_x: float, color: Color):
	var points = PackedVector2Array()
	var resolution = 50  # Number of points for smooth curve
	
	# Calculate screen positions
	var screen_start_x = (start_x - x_min) * scale_x + (center_x - x_range * scale_x / 2)
	var screen_end_x = (end_x - x_min) * scale_x + (center_x - x_range * scale_x / 2)
	
	# Add bottom points (along x-axis)
	points.append(Vector2(screen_start_x, bottom_y))
	
	# Add curve points from left to right
	for i in range(resolution + 1):
		var x = lerpf(start_x, end_x, i / float(resolution))
		var y = logistic_function(x)
		var screen_x = (x - x_min) * scale_x + (center_x - x_range * scale_x / 2)
		var screen_y = bottom_y - y * scale_y
		points.append(Vector2(screen_x, screen_y))
	
	# Close the polygon
	points.append(Vector2(screen_end_x, bottom_y))
	
	# Draw filled polygon
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func draw_axes():
	var graph_left = center_x - x_range * scale_x / 2
	var graph_right = center_x + x_range * scale_x / 2
	
	# Draw X axis
	draw_line(Vector2(graph_left - 20, bottom_y), Vector2(graph_right + 20, bottom_y), axis_color, axis_width)
	
	# Draw Y axis
	draw_line(Vector2(graph_left, bottom_y + 10), Vector2(graph_left, top_y), axis_color, axis_width)
	
	# Draw X axis ticks and labels
	for i in range(num_x_ticks):
		var actual_x_value = lerpf(x_min, x_max, i / float(num_x_ticks - 1))
		var display_x_value = lerpf(0.0, x_range, i / float(num_x_ticks - 1))  # Always start labels from 0
		var screen_x = (actual_x_value - x_min) * scale_x + graph_left
		
		# Draw tick mark
		draw_line(
			Vector2(screen_x, bottom_y - tick_length/2),
			Vector2(screen_x, bottom_y + tick_length/2),
			axis_color,
			axis_width
		)
		
		# Draw label
		var label_text = "%.1f" % display_x_value
		draw_string(
			ThemeDB.fallback_font,
			Vector2(screen_x - 15, bottom_y + 25),
			label_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			14,
			axis_color
		)
	
	# Draw Y axis ticks and labels
	for i in range(num_y_ticks):
		var actual_y_value = lerpf(0.0, carrying_capacity, i / float(num_y_ticks - 1))
		var display_y_value = actual_y_value + y_start  # Add offset for display only
		var screen_y = bottom_y - actual_y_value * scale_y
		
		# Draw tick mark
		draw_line(
			Vector2(graph_left - tick_length/2, screen_y),
			Vector2(graph_left + tick_length/2, screen_y),
			axis_color,
			axis_width
		)
		
		# Draw label
		var label_text = "%.0f" % display_y_value
		draw_string(
			ThemeDB.fallback_font,
			Vector2(graph_left - 40, screen_y + 5),
			label_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			-1,
			14,
			axis_color
		)

func draw_phase_labels():
	# Draw phase labels in the center of each colored region
	var phase_positions = [
		Vector2(center_x - x_range * scale_x / 3, bottom_y - carrying_capacity * 0.15 * scale_y),  # Slow start
		Vector2(center_x, bottom_y - carrying_capacity * 0.5 * scale_y),   # Exponential growth  
		Vector2(center_x + x_range * scale_x / 3, bottom_y - carrying_capacity * 0.85 * scale_y)   # Saturation
	]
	
	for i in range(min(phase_labels.size(), phase_positions.size())):
		draw_string(
			ThemeDB.fallback_font,
			phase_positions[i],
			phase_labels[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			label_font_size,
			label_text_color
		)
