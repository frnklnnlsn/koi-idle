extends Control

@export var mean: float = 0.0
@export var std_dev: float = 1.0
@export var num_points: int = 200
@export var range: float = 4.0  # How far left/right from mean to go (in std dev units)

# Dynamic scaling based on control size
@export var margin_percent: Vector2 = Vector2(0.1, 0.2)  # 10% horizontal, 20% vertical margins
@export var curve_height_percent: float = 0.6  # Use 60% of available height for curve

# Axis properties
@export var axis_color: Color = Color.BLACK
@export var axis_width: float = 2.0
@export var tick_length: float = 10.0
@export var num_x_ticks: int = 9  # Number of ticks on X axis
@export var num_y_ticks: int = 6  # Number of ticks on Y axis

# Bell curve line properties
@export var curve_color: Color = Color.WHITE
@export var curve_width: float = 3.0

# Color regions (matching the PowerPoint template)
@export var region_colors: Array[Color] = [
	Color(1.0, 0.6, 0.2, 0.8),  # Orange - outer left (beyond -2σ)
	Color(0.3, 0.7, 1.0, 0.8),  # Light blue - left (-2σ to -1σ)
	Color(0.2, 0.8, 0.5, 0.8),  # Green - center (-1σ to +1σ)
	Color(0.4, 0.6, 1.0, 0.8),  # Blue - right (+1σ to +2σ)
	Color(1.0, 0.4, 0.4, 0.8)   # Red - outer right (beyond +2σ)
]

# Region percentages (for labels)
@export var region_percentages: Array[String] = ["5%", "12%", "66%", "12%", "5%"]

# Percentage label properties
@export var percentage_font_size: int = 24
@export var percentage_text_color: Color = Color.WHITE

# Slider indicator properties
@export var indicator_color: Color = Color.RED
@export var indicator_dot_radius: float = 6.0
@export var indicator_line_width: float = 2.0
@export var dash_length: float = 10.0
@export var dash_gap: float = 5.0

@onready var line = $Line2D
@onready var slider = $HSlider

var center_x: float
var center_y: float
var max_y_value: float
var scale_x: float
var scale_y: float

func _ready():
	# Wait for the control to be properly sized
	await get_tree().process_frame
	calculate_dynamic_positioning()
	setup_slider()
	
	# Hide the Line2D node since we'll draw the curve manually
	if line:
		line.visible = false
	
	# Connect the resized signal to recalculate positioning
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	queue_redraw()

func _on_resized():
	# Recalculate positioning when the control is resized
	calculate_dynamic_positioning()
	setup_slider()  # Reposition slider as well
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
	center_x = control_size.x / 2
	center_y = margin_y + available_height * 0.7  # Position curve in upper portion
	
	# Calculate dynamic scaling
	scale_x = available_width / (2 * range * std_dev)
	max_y_value = normal_distribution(mean, mean, std_dev)
	scale_y = (available_height * curve_height_percent) / max_y_value
	
	# Adjust font sizes based on control size
	percentage_font_size = int(clamp(control_size.x / 40, 12, 32))

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
		slider.min_value = mean - range * std_dev
		slider.max_value = mean + range * std_dev
		slider.value = mean  # Start at the mean
		slider.step = 0.1
		
		# Connect slider signal
		if not slider.value_changed.is_connected(_on_slider_value_changed):
			slider.value_changed.connect(_on_slider_value_changed)

func _on_slider_value_changed(value: float):
	queue_redraw()

func normal_distribution(x: float, mean: float, std_dev: float) -> float:
	var exponent = -pow(x - mean, 2) / (2.0 * pow(std_dev, 2))
	return (1.0 / (std_dev * sqrt(2.0 * PI))) * exp(exponent)

func _draw():
	# Only draw if we have valid dimensions
	if scale_x <= 0 or scale_y <= 0:
		return
		
	draw_colored_regions()
	draw_axes()
	draw_bell_curve_manual()  # Draw curve manually
	draw_slider_line()        # Draw dashed line
	draw_slider_dot()         # Draw dot on top

func draw_bell_curve_manual():
	# Draw the bell curve using draw_polyline instead of Line2D
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = lerp(mean - range * std_dev, mean + range * std_dev, i / float(num_points - 1))
		var y = normal_distribution(x, mean, std_dev)
		# Map x and y to screen space
		var screen_x = (x - mean) * scale_x + center_x
		var screen_y = center_y - y * scale_y  # invert y for screen
		points.append(Vector2(screen_x, screen_y))
	
	# Draw the curve as a polyline
	draw_polyline(points, curve_color, curve_width)

func draw_slider_line():
	if not slider:
		return
		
	var slider_value = slider.value
	var screen_x = (slider_value - mean) * scale_x + center_x
	
	# Draw vertical dashed line
	draw_dashed_line_vertical(screen_x)

func draw_slider_dot():
	if not slider:
		return
		
	var slider_value = slider.value
	
	# Calculate screen position
	var screen_x = (slider_value - mean) * scale_x + center_x
	
	# Calculate y position on the curve
	var curve_y = normal_distribution(slider_value, mean, std_dev)
	var screen_y = center_y - curve_y * scale_y
	
	# Draw red dot on the curve (this will be called after Line2D is drawn)
	draw_circle(Vector2(screen_x, screen_y), indicator_dot_radius, indicator_color)

func draw_dashed_line_vertical(x: float):
	var graph_top = center_y - max_y_value * scale_y - 50
	var graph_bottom = center_y + 50
	
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

func draw_colored_regions():
	# Define the standard deviation boundaries
	var boundaries = [
		mean - 2 * std_dev,  # -2σ
		mean - 1 * std_dev,  # -1σ
		mean + 1 * std_dev,  # +1σ
		mean + 2 * std_dev   # +2σ
	]
	
	# Draw each region
	var region_ranges = [
		[mean - range * std_dev, boundaries[0]],  # Beyond -2σ
		[boundaries[0], boundaries[1]],           # -2σ to -1σ
		[boundaries[1], boundaries[2]],           # -1σ to +1σ
		[boundaries[2], boundaries[3]],           # +1σ to +2σ
		[boundaries[3], mean + range * std_dev]   # Beyond +2σ
	]
	
	for i in range(region_ranges.size()):
		if i >= region_colors.size():
			break
			
		var start_x = region_ranges[i][0]
		var end_x = region_ranges[i][1]
		
		draw_region_fill(start_x, end_x, region_colors[i])

func draw_region_fill(start_x: float, end_x: float, color: Color):
	var points = PackedVector2Array()
	var resolution = 50  # Number of points for smooth curve
	
	# Add bottom points (along x-axis) from left to right
	var screen_start_x = (start_x - mean) * scale_x + center_x
	var screen_end_x = (end_x - mean) * scale_x + center_x
	points.append(Vector2(screen_start_x, center_y))
	
	# Add curve points from left to right
	for i in range(resolution + 1):
		var x = lerp(start_x, end_x, i / float(resolution))
		var y = normal_distribution(x, mean, std_dev)
		var screen_x = (x - mean) * scale_x + center_x
		var screen_y = center_y - y * scale_y
		points.append(Vector2(screen_x, screen_y))
	
	# Close the polygon
	points.append(Vector2(screen_end_x, center_y))
	
	# Draw filled polygon
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func draw_axes():
	# Draw X axis only
	var x_start = center_x - range * std_dev * scale_x - 20
	var x_end = center_x + range * std_dev * scale_x + 20
	draw_line(Vector2(x_start, center_y), Vector2(x_end, center_y), axis_color, axis_width)
	
	# Draw X axis ticks and labels
	for i in range(num_x_ticks):
		var x_value = lerp(mean - range * std_dev, mean + range * std_dev, i / float(num_x_ticks - 1))
		var screen_x = (x_value - mean) * scale_x + center_x
		
		# Draw tick mark
		draw_line(
			Vector2(screen_x, center_y - tick_length/2),
			Vector2(screen_x, center_y + tick_length/2),
			axis_color,
			axis_width
		)
		
		# Draw label
		var label_text = "%.1f" % x_value if abs(x_value) >= 0.1 else ""
		draw_string(
			ThemeDB.fallback_font,
			Vector2(screen_x - 10, center_y + 25),
			label_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			axis_color
		)

func draw_axis_labels():
	# X axis label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x, center_y + 60),
		"Standard Deviations",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		20,
		axis_color
	)
	
	# Y axis label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x - 80, center_y - max_y_value * scale_y / 2),
		"Probability Density",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		20,
		axis_color
	)

func draw_percentage_labels():
	# Define the center positions for each region
	var region_centers = [
		mean - 2.5 * std_dev,  # Center of beyond -2σ region
		mean - 1.5 * std_dev,  # Center of -2σ to -1σ region
		mean,                  # Center of -1σ to +1σ region
		mean + 1.5 * std_dev,  # Center of +1σ to +2σ region
		mean + 2.5 * std_dev   # Center of beyond +2σ region
	]
	
	# Position labels below the curve, outside the graph area
	var label_y_position = center_y + 100  # Position below the x-axis
	
	for i in range(region_centers.size()):
		if i >= region_percentages.size():
			break
			
		var center_x_pos = (region_centers[i] - mean) * scale_x + center_x
		
		# Draw percentage text below the graph
		draw_string(
			ThemeDB.fallback_font,
			Vector2(center_x_pos, label_y_position),
			region_percentages[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			percentage_font_size,
			percentage_text_color
		)
