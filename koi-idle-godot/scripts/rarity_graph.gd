class_name RarityGraph
extends Control

# Graph configuration
@export var peak_position: float = 2.0
@export var decay_rate: float = 0.3
@export var left_steepness: float = 10.0
@export var num_points: int = 200
@export var range_min: float = 0.0
@export var range_max: float = 10.0

# Dynamic scaling
@export var margin_percent: Vector2 = Vector2(0.1, 0.2)
@export var curve_height_percent: float = 0.6

# Theme resource
@export var graph_theme: RarityGraphTheme : set = set_graph_theme

# Region configuration
@export var region_percentages: Array[String] = ["60%", "25%", "10%", "4%", "1%"]
@export var region_labels: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# Internal variables
var center_x: float
var center_y: float
var max_y_value: float
var scale_x: float
var scale_y: float
var current_marker_value: float = -1.0

# Signals
signal marker_value_changed(value: float)

func _ready():
	await get_tree().process_frame
	calculate_dynamic_positioning()
	
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	# Apply default theme if none set
	if not graph_theme:
		graph_theme = load("res://themes/DefaultRarityGraph.tres")
	
	queue_redraw()

func _on_resized():
	calculate_dynamic_positioning()
	queue_redraw()

func set_graph_theme(new_theme: RarityGraphTheme):
	if graph_theme != new_theme:
		graph_theme = new_theme
		queue_redraw()

# Public method to set marker position via signal/code
func set_marker_value(value: float):
	if value != current_marker_value:
		current_marker_value = value
		marker_value_changed.emit(value)
		queue_redraw()

# Public method to clear marker
func clear_marker():
	current_marker_value = -1.0
	queue_redraw()

func calculate_dynamic_positioning():
	var control_size = get_rect().size
	
	if control_size.x <= 0 or control_size.y <= 0:
		return
	
	var margin_x = control_size.x * margin_percent.x
	var margin_y = control_size.y * margin_percent.y
	
	var available_width = control_size.x - 2 * margin_x
	var available_height = control_size.y - 2 * margin_y
	
	center_x = margin_x + available_width * 0.3
	center_y = margin_y + available_height * 0.7
	
	scale_x = available_width / (range_max - range_min)
	max_y_value = custom_skewed_distribution(peak_position)
	scale_y = (available_height * curve_height_percent) / max_y_value

func custom_skewed_distribution(x: float) -> float:
	var weight: float
	
	if x <= peak_position:
		var distance_left = peak_position - x
		weight = 100.0 * exp(-pow(distance_left, 2) / left_steepness)
	else:
		var distance_right = x - peak_position
		weight = 100.0 * exp(-decay_rate * distance_right)
	
	weight = max(weight, 1.0)
	return weight / 100.0

func _draw():
	if not graph_theme or scale_x <= 0 or scale_y <= 0:
		return
		
	draw_colored_regions()
	draw_axes()
	draw_skewed_curve()
	
	if current_marker_value >= range_min and current_marker_value <= range_max:
		draw_marker()

func draw_colored_regions():
	if not graph_theme.show_regions:
		return
		
	var total_range = range_max - range_min
	var boundaries = [
		range_min + total_range * 0.6,
		range_min + total_range * 0.85,
		range_min + total_range * 0.95,
		range_min + total_range * 0.99
	]
	
	var region_ranges = [
		[range_min, boundaries[0]],
		[boundaries[0], boundaries[1]],
		[boundaries[1], boundaries[2]],
		[boundaries[2], boundaries[3]],
		[boundaries[3], range_max]
	]
	
	for i in range(region_ranges.size()):
		if i >= graph_theme.region_colors.size():
			break
			
		var start_x = region_ranges[i][0]
		var end_x = region_ranges[i][1]
		
		draw_region_fill(start_x, end_x, graph_theme.region_colors[i])

func draw_region_fill(start_x: float, end_x: float, color: Color):
	var points = PackedVector2Array()
	var resolution = 50
	
	var screen_start_x = (start_x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	var screen_end_x = (end_x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	
	points.append(Vector2(screen_start_x, center_y))
	
	for i in range(resolution + 1):
		var x = lerp(start_x, end_x, i / float(resolution))
		var y = custom_skewed_distribution(x)
		var screen_x = (x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		var screen_y = center_y - y * scale_y
		points.append(Vector2(screen_x, screen_y))
	
	points.append(Vector2(screen_end_x, center_y))
	
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func draw_skewed_curve():
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = lerp(range_min, range_max, i / float(num_points - 1))
		var y = custom_skewed_distribution(x)
		var screen_x = (x - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		var screen_y = center_y - y * scale_y
		points.append(Vector2(screen_x, screen_y))
	
	draw_polyline(points, graph_theme.curve_color, graph_theme.curve_width)

func draw_axes():
	if not graph_theme.show_axes:
		return
		
	# X axis
	var x_start = center_x - (range_max - range_min) * scale_x * 0.3 - 20
	var x_end = center_x + (range_max - range_min) * scale_x * 0.7 + 20
	draw_line(Vector2(x_start, center_y), Vector2(x_end, center_y), graph_theme.axis_color, graph_theme.axis_width)
	
	if graph_theme.show_ticks:
		draw_x_ticks()
	
	if graph_theme.show_labels:
		draw_labels()

func draw_x_ticks():
	for i in range(graph_theme.num_x_ticks):
		var x_value = lerp(range_min, range_max, i / float(graph_theme.num_x_ticks - 1))
		var screen_x = (x_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		
		draw_line(
			Vector2(screen_x, center_y - graph_theme.tick_length/2),
			Vector2(screen_x, center_y + graph_theme.tick_length/2),
			graph_theme.axis_color,
			graph_theme.axis_width
		)
		
		var label_text = "%.1f" % x_value if abs(x_value) >= 0.1 else ""
		var font_to_use = graph_theme.tick_font if graph_theme.tick_font else ThemeDB.fallback_font
		draw_string(
			font_to_use,
			Vector2(screen_x - 10, center_y + 25),
			label_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			graph_theme.tick_font_size,
			graph_theme.tick_text_color
		)

func draw_labels():
	# Region labels
	var total_range = range_max - range_min
	var region_centers = [
		range_min + total_range * 0.3,
		range_min + total_range * 0.725,
		range_min + total_range * 0.9,
		range_min + total_range * 0.97,
		range_min + total_range * 0.995
	]
	
	var label_y_position = center_y + 100
	var font_to_use = graph_theme.label_font if graph_theme.label_font else ThemeDB.fallback_font
	
	for i in range(region_centers.size()):
		if i >= region_percentages.size():
			break
			
		var center_x_pos = (region_centers[i] - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
		
		# Percentage
		draw_string(
			font_to_use,
			Vector2(center_x_pos, label_y_position),
			region_percentages[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			graph_theme.label_font_size,
			graph_theme.label_text_color
		)
		
		# Rarity label
		if i < region_labels.size():
			draw_string(
				font_to_use,
				Vector2(center_x_pos, label_y_position - 25),
				region_labels[i],
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				graph_theme.label_font_size - 4,
				graph_theme.label_text_color
			)

func draw_marker():
	var screen_x = (current_marker_value - range_min) * scale_x + (center_x - (range_max - range_min) * scale_x * 0.3)
	var curve_y = custom_skewed_distribution(current_marker_value)
	var screen_y = center_y - curve_y * scale_y
	
	# Draw vertical line if enabled
	if graph_theme.show_marker_line:
		draw_dashed_line_vertical(screen_x)
	
	# Draw marker dot
	draw_circle(Vector2(screen_x, screen_y), graph_theme.marker_dot_radius, graph_theme.marker_color)
	
	# Draw marker outline if specified
	if graph_theme.marker_outline_width > 0:
		draw_arc(Vector2(screen_x, screen_y), graph_theme.marker_dot_radius, 0, TAU, 32, graph_theme.marker_outline_color, graph_theme.marker_outline_width)

func draw_dashed_line_vertical(x: float):
	var graph_top = center_y - max_y_value * scale_y - 50
	var graph_bottom = center_y + 50
	
	var current_y = graph_top
	var is_dash = true
	
	while current_y < graph_bottom:
		var segment_end = current_y + (graph_theme.dash_length if is_dash else graph_theme.dash_gap)
		segment_end = min(segment_end, graph_bottom)
		
		if is_dash:
			draw_line(
				Vector2(x, current_y),
				Vector2(x, segment_end),
				graph_theme.marker_line_color,
				graph_theme.marker_line_width
			)
		
		current_y = segment_end
		is_dash = not is_dash
