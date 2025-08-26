
extends Control

# Add these signals at the top of your script
signal bar_clicked(fish_resource: fish_conf, bar_index: int)
signal bar_pressed(fish_resource: fish_conf, bar_index: int)
signal bar_released(fish_resource: fish_conf, bar_index: int)

# Histogram properties
@export var max_fish_count: int = 100
@export var bar_color: Color = Color.WHITE
@export var bar_outline_color: Color = Color.BLACK
@export var bar_outline_width: float = 1.0
@export var bar_spacing_percent: float = 0.1

# Dynamic scaling based on control size
@export var margin_percent: Vector2 = Vector2(0.1, 0.2)
@export var histogram_height_percent: float = 0.6

# Axis properties
@export var axis_color: Color = Color.WHITE
@export var axis_width: float = 2.0
@export var tick_length: float = 10.0
@export var num_y_ticks: int = 6

# Hover properties
@export var hover_color: Color = Color.YELLOW
@export var hover_outline_width: float = 3.0
@export var card_hover_color: Color = Color.BLACK
@export var card_hover_outline_color: Color = Color.WHITE
@export var card_hover_outline_width: float = 2.0

# New: Click/Press visual feedback
@export var pressed_color: Color = Color.GRAY
@export var pressed_outline_color: Color = Color.WHITE
@export var pressed_outline_width: float = 2.0

# Layout variables
var center_x: float
var center_y: float
var scale_y: float
var histogram_width: float
var histogram_height: float

# Data variables
var fish_collection: Array[fish_conf] = []
var sorted_fish_collection: Array[fish_conf] = []
var max_fish_value: float = 10.0
var hovered_fish_index: int = -1

# Bar positioning
var bar_width: float
var bar_positions: Array[Vector2] = []
var hovered_card_fish: fish_conf = null

# New: Mouse interaction state
var pressed_fish_index: int = -1
var mouse_pressed: bool = false

func _ready():
	await get_tree().process_frame
	calculate_dynamic_positioning()
	
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	queue_redraw()

# Your existing functions remain the same...
func set_fish_collection(fish_array: Array):
	fish_collection.clear()
	for fish in fish_array:
		if fish is fish_conf:
			fish_collection.append(fish)
	
	await get_tree().process_frame
	calculate_dynamic_positioning()
	update_histogram_data()
	queue_redraw()

func add_fish_to_histogram(fish_res: fish_conf):
	if fish_res:
		fish_collection.append(fish_res)
		await get_tree().process_frame
		calculate_dynamic_positioning()
		update_histogram_data()
		queue_redraw()

func clear_histogram():
	fish_collection.clear()
	sorted_fish_collection.clear()
	bar_positions.clear()
	hovered_fish_index = -1
	hovered_card_fish = null
	pressed_fish_index = -1
	queue_redraw()

func set_fish_card_hover(fish_res: fish_conf):
	hovered_card_fish = fish_res
	queue_redraw()

func clear_fish_card_hover():
	hovered_card_fish = null
	queue_redraw()

# Enhanced mouse input handling
func _gui_input(event):
	if event is InputEventMouseMotion:
		check_hover(event.position)
	elif event is InputEventMouseButton:
		handle_mouse_button(event)

func handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_bar_index = get_bar_at_position(event.position)
		
		if event.pressed:
			# Mouse pressed down
			mouse_pressed = true
			pressed_fish_index = clicked_bar_index
			
			if clicked_bar_index >= 0:
				var fish_resource = sorted_fish_collection[clicked_bar_index]
				bar_pressed.emit(fish_resource, clicked_bar_index)
			
			queue_redraw()
		else:
			# Mouse released
			mouse_pressed = false
			var old_pressed = pressed_fish_index
			pressed_fish_index = -1
			
			# Check if this was a complete click (pressed and released on same bar)
			if old_pressed >= 0 and old_pressed == clicked_bar_index:
				var fish_resource = sorted_fish_collection[old_pressed]
				bar_clicked.emit(fish_resource, old_pressed)
			
			# Always emit release if something was pressed
			if old_pressed >= 0:
				var fish_resource = sorted_fish_collection[old_pressed]
				bar_released.emit(fish_resource, old_pressed)
			
			queue_redraw()

func get_bar_at_position(mouse_pos: Vector2) -> int:
	"""Get the index of the bar at the given position, or -1 if none"""
	for i in range(bar_positions.size()):
		var bar_pos = bar_positions[i]
		var fish_value = sorted_fish_collection[i].value
		var bar_height = fish_value * scale_y
		
		var bar_rect = Rect2(
			bar_pos.x - bar_width * 0.5,
			bar_pos.y,
			bar_width,
			bar_height
		)
		
		if bar_rect.has_point(mouse_pos):
			return i
	
	return -1

func check_hover(mouse_pos: Vector2):
	var old_hovered = hovered_fish_index
	hovered_fish_index = get_bar_at_position(mouse_pos)
	
	if old_hovered != hovered_fish_index:
		queue_redraw()

# Your existing positioning and data functions remain the same...
func _on_resized():
	calculate_dynamic_positioning()
	update_histogram_data()
	queue_redraw()

func calculate_dynamic_positioning():
	var control_size = get_rect().size
	
	if control_size.x <= 0 or control_size.y <= 0:
		return
	
	var margin_x = control_size.x * margin_percent.x
	var margin_y = control_size.y * margin_percent.y
	
	var available_width = control_size.x - 2 * margin_x
	var available_height = control_size.y - 2 * margin_y
	
	center_x = control_size.x * 0.5
	center_y = margin_y + available_height * 0.7
	
	histogram_width = available_width * 0.8
	histogram_height = available_height * histogram_height_percent
	
	scale_y = histogram_height / max_fish_value

func update_histogram_data():
	bar_positions.clear()
	sorted_fish_collection.clear()
	
	if fish_collection.is_empty():
		return
	
	if scale_y <= 0 or histogram_height <= 0 or histogram_width <= 0:
		calculate_dynamic_positioning()
		if scale_y <= 0:
			return
	
	sorted_fish_collection = fish_collection.duplicate()
	sorted_fish_collection.sort_custom(func(a, b): return a.value < b.value)
	
	max_fish_value = 1.0
	for fish in sorted_fish_collection:
		if fish.value > max_fish_value:
			max_fish_value = fish.value
	
	max_fish_value *= 1.1
	scale_y = histogram_height / max_fish_value
	
	var fish_count = sorted_fish_collection.size()
	var start_x = center_x - histogram_width * 0.5
	var spacing = histogram_width / float(fish_count)
	
	for i in range(fish_count):
		var x_pos = start_x + (i + 0.5) * spacing
		var fish_value = sorted_fish_collection[i].value
		var bar_height = fish_value * scale_y
		var y_pos = center_y - bar_height
		
		bar_positions.append(Vector2(x_pos, y_pos))
	
	bar_width = spacing * 0.8

func value_to_screen_y(value: float) -> float:
	return center_y - value * scale_y

func _draw():
	if fish_collection.is_empty() or scale_y <= 0:
		draw_empty_axes()
		return
	
	draw_axes()
	draw_bars()

func draw_empty_axes():
	var y_axis_x = center_x - histogram_width * 0.5
	var x_axis_y = center_y
	var x_axis_end = center_x + histogram_width * 0.5
	var y_axis_end = center_y - histogram_height
	
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(x_axis_end, x_axis_y), axis_color, axis_width)
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(y_axis_x, y_axis_end), axis_color, axis_width)

func draw_axes():
	var y_axis_x = center_x - histogram_width * 0.5
	var x_axis_y = center_y
	var x_axis_end = center_x + histogram_width * 0.5 + 20
	var y_axis_end = center_y - histogram_height - 20
	
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(x_axis_end, x_axis_y), axis_color, axis_width)
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(y_axis_x, y_axis_end), axis_color, axis_width)
	
	for i in range(num_y_ticks):
		var y_value = (max_fish_value * i) / float(num_y_ticks - 1)
		var screen_y = value_to_screen_y(y_value)
		
		draw_line(
			Vector2(y_axis_x - tick_length/2, screen_y),
			Vector2(y_axis_x + tick_length/2, screen_y),
			axis_color,
			axis_width
		)
		
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

func draw_bars():
	for i in range(bar_positions.size()):
		var bar_pos = bar_positions[i]
		var current_fish = sorted_fish_collection[i]
		var fish_value = current_fish.value
		var bar_height = fish_value * scale_y
		
		# Determine bar appearance based on interaction state
		var current_bar_color = bar_color
		var current_outline_width = bar_outline_width
		var current_outline_color = bar_outline_color
		
		# Priority: pressed > card hover > direct hover > normal
		var is_pressed = (i == pressed_fish_index and mouse_pressed)
		var is_card_hovered = (hovered_card_fish != null and current_fish == hovered_card_fish)
		var is_directly_hovered = (i == hovered_fish_index)
		
		if is_pressed:
			# Pressed state: gray with white outline
			current_bar_color = pressed_color
			current_outline_color = pressed_outline_color
			current_outline_width = pressed_outline_width
		elif is_card_hovered:
			# Fish card hover: black bar with white outline
			current_bar_color = card_hover_color
			current_outline_color = card_hover_outline_color
			current_outline_width = card_hover_outline_width
		elif is_directly_hovered:
			# Direct bar hover: yellow highlight
			current_bar_color = hover_color
			current_outline_width = hover_outline_width
		
		var bar_rect = Rect2(
			bar_pos.x - bar_width * 0.5,
			bar_pos.y,
			bar_width,
			bar_height
		)
		
		draw_rect(bar_rect, current_bar_color)
		
		if current_outline_width > 0:
			draw_rect(bar_rect, current_outline_color, false, current_outline_width)
		
		if bar_width > 15:
			var value_text = "%.1f" % fish_value
			draw_string(
				ThemeDB.fallback_font,
				Vector2(bar_pos.x - 8, center_y + 20),
				value_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				10,
				axis_color
			)

func get_hovered_fish() -> fish_conf:
	if hovered_fish_index >= 0 and hovered_fish_index < sorted_fish_collection.size():
		return sorted_fish_collection[hovered_fish_index]
	return null
