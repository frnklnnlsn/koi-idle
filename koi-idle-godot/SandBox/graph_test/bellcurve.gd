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
@export var num_x_ticks: int = 9  # Number of ticks on X axis
@export var num_y_ticks: int = 6  # Number of ticks on Y axis

# Bell curve line properties
@export var curve_color: Color = Color.WHITE
@export var curve_width: float = 3.0

# Color regions (adjusted for right-skewed distribution)
@export var region_colors: Array[Color] = [
	Color(0.2, 0.8, 0.5, 0.8),  # Green - Common items (left side)
	Color(0.3, 0.7, 1.0, 0.8),  # Light blue - Uncommon
	Color(0.4, 0.6, 1.0, 0.8),  # Blue - Rare
	Color(1.0, 0.6, 0.2, 0.8),  # Orange - Epic
	Color(1.0, 0.4, 0.4, 0.8)   # Red - Legendary (right tail)
]

# Region percentages (for item rarity labels)
@export var region_percentages: Array[String] = ["60%", "25%", "10%", "4%", "1%"]
@export var region_labels: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

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


# Add this to your graph script
var fish_value: float = -1.0  # -1 indicates no fish is being hovered
var is_fish_hovered: bool = false

# Add this function to update the fish value marker
func set_fish_value(value: float):
	fish_value = value
	is_fish_hovered = true
	queue_redraw()  # Redraw to show the new marker

# Add this function to clear the fish value marker
func clear_fish_value():
	is_fish_hovered = false
	queue_redraw()  # Redraw to hide the marker



func draw_fish_marker():
	if not is_fish_hovered or fish_value < range_min or fish_value > range_max:
		return
		
	# Calculate screen position for the fish value
	var screen_x = (fish_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	
	# Calculate y position on the curve
	var curve_y = custom_skewed_distribution(fish_value)
	var screen_y = center_y - curve_y * scale_y
	
	# Draw a different colored marker for the fish (maybe yellow or green)
	var fish_marker_color = Color.YELLOW
	var fish_marker_radius = 8.0  # Slightly larger than the slider dot
	
	# Draw the fish marker
	draw_circle(Vector2(screen_x, screen_y), fish_marker_radius, fish_marker_color)
	
	# Optional: Draw a vertical line to show the exact position
	draw_line(
		Vector2(screen_x, center_y),
		Vector2(screen_x, screen_y),
		fish_marker_color,
		2.0
	)



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
	center_x = margin_x + available_width * 0.3  # Shift left since curve peaks early
	center_y = margin_y + available_height * 0.7  # Position curve in upper portion
	
	# Calculate dynamic scaling
	scale_x = available_width / (range_max - range_min)
	max_y_value = custom_skewed_distribution(peak_position)
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
		slider.min_value = range_min
		slider.max_value = range_max
		slider.value = peak_position  # Start at the peak
		slider.step = 0.1
		
		# Connect slider signal
		if not slider.value_changed.is_connected(_on_slider_value_changed):
			slider.value_changed.connect(_on_slider_value_changed)

func _on_slider_value_changed(value: float):
	queue_redraw()

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

# Approximation of gamma function for small positive values (kept for compatibility)
func gamma_function(z: float) -> float:
	if z < 1.0:
		return gamma_function(z + 1.0) / z
	elif z == 1.0:
		return 1.0
	elif z == 2.0:
		return 1.0
	else:
		# Stirling's approximation for larger values
		return sqrt(2.0 * PI / z) * pow(z / exp(1.0), z)

func _draw():
	# Only draw if we have valid dimensions
	if scale_x <= 0 or scale_y <= 0:
		return
		
	draw_colored_regions()
	draw_axes()
	draw_skewed_curve()     # Draw right-skewed curve
	draw_slider_line()      # Draw dashed line
	draw_slider_dot()       # Draw dot on top
	
	# Add this line to draw the fish value marker
	if is_fish_hovered:
		draw_fish_marker()

func draw_skewed_curve():
	# Draw the right-skewed curve using draw_polyline
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = lerp(range_min, range_max, i / float(num_points - 1))
		var y = custom_skewed_distribution(x)
		# Map x and y to screen space
		var screen_x = (x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		var screen_y = center_y - y * scale_y  # invert y for screen
		points.append(Vector2(screen_x, screen_y))
	
	# Draw the curve as a polyline
	draw_polyline(points, curve_color, curve_width)

func draw_slider_line():
	if not slider:
		return
		
	var slider_value = slider.value
	var screen_x = (slider_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	
	# Draw vertical dashed line
	draw_dashed_line_vertical(screen_x)

func draw_slider_dot():
	if not slider:
		return
		
	var slider_value = slider.value
	
	# Calculate screen position
	var screen_x = (slider_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	
	# Calculate y position on the curve
	var curve_y = custom_skewed_distribution(slider_value)
	var screen_y = center_y - curve_y * scale_y
	
	# Draw red dot on the curve
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
	# Define boundaries for item rarity regions (adjusted for right-skewed distribution)
	var total_range = range_max - range_min
	var boundaries = [
		range_min + total_range * 0.6,   # 60% - Common/Uncommon boundary
		range_min + total_range * 0.85,  # 85% - Uncommon/Rare boundary  
		range_min + total_range * 0.95,  # 95% - Rare/Epic boundary
		range_min + total_range * 0.99   # 99% - Epic/Legendary boundary
	]
	
	# Draw each region
	var region_ranges = [
		[range_min, boundaries[0]],              # Common (60%)
		[boundaries[0], boundaries[1]],          # Uncommon (25%)
		[boundaries[1], boundaries[2]],          # Rare (10%)
		[boundaries[2], boundaries[3]],          # Epic (4%)
		[boundaries[3], range_max]               # Legendary (1%)
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
	
	# Calculate screen positions
	var screen_start_x = (start_x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	var screen_end_x = (end_x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	
	# Add bottom points (along x-axis) from left to right
	points.append(Vector2(screen_start_x, center_y))
	
	# Add curve points from left to right
	for i in range(resolution + 1):
		var x = lerp(start_x, end_x, i / float(resolution))
		var y = custom_skewed_distribution(x)
		var screen_x = (x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		var screen_y = center_y - y * scale_y
		points.append(Vector2(screen_x, screen_y))
	
	# Close the polygon
	points.append(Vector2(screen_end_x, center_y))
	
	# Draw filled polygon
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func draw_axes():
	# Draw X axis only
	var x_start = center_x - (range_max - range_min) * scale_x * 0.3 - 20
	var x_end = center_x + (range_max - range_min) * scale_x * 0.7 + 20
	draw_line(Vector2(x_start, center_y), Vector2(x_end, center_y), axis_color, axis_width)
	
	# Draw X axis ticks and labels
	for i in range(num_x_ticks):
		var x_value = lerp(range_min, range_max, i / float(num_x_ticks - 1))
		var screen_x = (x_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		
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
		"Item Rarity Scale",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		20,
		axis_color
	)
	
	# Y axis label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x - 80, center_y - max_y_value * scale_y / 2),
		"Drop Rate Probability",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		20,
		axis_color
	)

func draw_percentage_labels():
	# Define the center positions for each rarity region
	var total_range = range_max - range_min
	var region_centers = [
		range_min + total_range * 0.3,   # Center of Common region
		range_min + total_range * 0.725, # Center of Uncommon region
		range_min + total_range * 0.9,   # Center of Rare region
		range_min + total_range * 0.97,  # Center of Epic region
		range_min + total_range * 0.995  # Center of Legendary region
	]
	
	# Position labels below the curve, outside the graph area
	var label_y_position = center_y + 100  # Position below the x-axis
	
	for i in range(region_centers.size()):
		if i >= region_percentages.size():
			break
			
		var center_x_pos = (region_centers[i] - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		
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
		
		# Draw rarity label above percentage
		if i < region_labels.size():
			draw_string(
				ThemeDB.fallback_font,
				Vector2(center_x_pos, label_y_position - 25),
				region_labels[i],
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				percentage_font_size - 4,
				percentage_text_color
			)
