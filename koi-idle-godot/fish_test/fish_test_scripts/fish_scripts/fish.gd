extends Node2D

# Node references
#@onready var head: Area2D = %head
#@onready var head_detection: CollisionShape2D = %"head detection"
@onready var fish_body = %body
@onready var skeleton = %skeleton

# Fish movement parameters
@export var num_points: int = 10
@export var start_position: Vector2 #= Vector2(500, 500)
@export var speed: float = 0.5
@export var amplitude: float = 100.0
@export var wavelength: float = 0.5
@export var noise_intensity: float = 100.0

# Circular boundary parameters
@export var circle_center: Vector2 = Vector2(0,0)
@export var circle_radius: float = 700.0
@export var max_turn_angle: float = 0.2

# Ellipse and eye parameters
@export var ellipse_size: Vector2 = Vector2(20, 10)  # Width, height of ellipses
@export var ellipse_spacing: int = 5  # Every 5 points on the line
@export var ellipse_offset1: float = 20  # Distance from the line
@export var ellipse_offset2: float = 35  # Distance from the line
#@export var ellipse_color: Color = Color(1, 0.498039, 0.313726, 1)

#@export var eye_radius: float = 5  # Radius of the eyes
#@export var eye_offset: float = 15  # Distance from the center of point 0
#@export var eye_color: Color = Color(0, 0, 0)  # Black color for the eyes

# Debugging
@export var debug_mode: bool = false

# Internal variables
var seg_length: int = 300 / num_points
var noise = FastNoiseLite.new()
var time: float = 0.0
var rotation_offset: float = PI / 4  # Fine-tune this value to adjust the tilt
#var smelling: bool = false
#var food: Vector2
#var food_area: Area2D
#var fish_resource:fish

func _ready() -> void:
	print("koi ready")
	#print(fish_resource.tint)
	#print(fish_resource.name)
	#fish_body.fish_resource = fish_resource
	
	noise.seed = randi()
	noise.frequency = 0.2
	
	# Initialize fish body and skeleton points
	for i in range(num_points):
		var offset = i * seg_length
		var wave_y = sin(offset * wavelength) * amplitude
		fish_body.add_point(start_position + Vector2(offset, wave_y))
		skeleton.add_point(start_position + Vector2(offset, wave_y))

func _process(delta: float) -> void:
	time += delta * speed
	update_fish_movement(delta)
	queue_redraw()

func update_fish_movement(delta: float) -> void:
	var head_pos = to_global(fish_body.get_point_position(0))  # Convert to global coordinates
	var new_x = head_pos.x + cos(time) * seg_length * speed
	var new_y = head_pos.y + sin(time * wavelength) * amplitude + noise.get_noise_1d(time) * noise_intensity
	var new_position = Vector2(new_x, new_y)

	# Ensure the fish stays within the circular boundary
	if new_position.distance_to(circle_center) > circle_radius:
		var direction = (circle_center - new_position).normalized()
		new_position = circle_center + direction * circle_radius
	
	# Handle food detection and movement
	#if smelling and is_instance_valid(food_area):
		#var direction = (food - head_pos).normalized()
		#new_position = head_pos + direction * seg_length * speed
	#elif smelling:
		#print("Food is gone or invalid")
		#smelling = false

	# Smooth turning logic: Limit the angle change to prevent sharp turns
	var prev_direction = (head_pos - to_global(fish_body.get_point_position(1))).normalized()
	var desired_direction = (new_position - head_pos).normalized()
	
	var angle_diff = prev_direction.angle_to(desired_direction)
	if abs(angle_diff) > max_turn_angle:
		desired_direction = prev_direction.rotated(sign(angle_diff) * max_turn_angle)

	new_position = head_pos + desired_direction * seg_length * speed
	
	# Update fish body and skeleton positions
	fish_body.set_point_position(0, to_local(new_position))  # Convert back to local coordinates
	skeleton.set_point_position(0, to_local(new_position))
	#head.position = to_local(new_position)

	for i in range(1, fish_body.get_point_count()):
		var current_pos = fish_body.get_point_position(i)
		var ahead_pos = fish_body.get_point_position(i - 1)
		var dir_to_ahead = (ahead_pos - current_pos).normalized()
		var new_pos = ahead_pos - dir_to_ahead * seg_length
		fish_body.set_point_position(i, new_pos)
		skeleton.set_point_position(i, new_pos)

	# Remove excess points if necessary
	if fish_body.get_point_count() > num_points:
		fish_body.remove_point(0)
	if skeleton.get_point_count() > num_points:
		skeleton.remove_point(0)

#func _on_head_area_entered(area: Area2D) -> void:
	#if area.is_in_group("smell"):
		#if not smelling:
			#print("Food detected at global position: ", area.global_position)
			#set_food_target(area.global_position)
			#food_area = area
		#smelling = true
#
#func set_food_target(target: Vector2) -> void:
	#food = target
	#print("Food position set to: ", food)

func _draw():
	if debug_mode:
		draw_arc(circle_center, circle_radius, 0, TAU, 32, Color.ALICE_BLUE, 2.0)
		#if smelling:
			#var fish_head_global = to_global(fish_body.get_point_position(0))  # Convert fish head to global space
			#draw_line(fish_head_global, food, Color.RED, 2.0)
			#draw_circle(food, 5, Color.GREEN)  # Draw a green circle at the food position
	## Draw ellipses and eyes
	#for i in range(0, fish_body.get_point_count(), ellipse_spacing):
		#var point = fish_body.get_point_position(i)
		#var normal = (fish_body.get_point_position(i + 1) - fish_body.get_point_position(i - 1)).normalized().orthogonal()
		#var ellipse_pos1 = point + normal * ellipse_offset1
		#var ellipse_pos2 = point - normal * ellipse_offset2
		#draw_ellipse(ellipse_pos1, ellipse_size, ellipse_color)
		#draw_ellipse(ellipse_pos2, ellipse_size, ellipse_color)
	#
	## Draw eyes
	#var head_pos = fish_body.get_point_position(0)
	#var eye_pos1 = head_pos + Vector2(eye_offset, 0).rotated(rotation_offset)
	#var eye_pos2 = head_pos + Vector2(-eye_offset, 0).rotated(rotation_offset)
	#draw_circle(eye_pos1, eye_radius, eye_color)
	#draw_circle(eye_pos2, eye_radius, eye_color)

#func draw_ellipse(center: Vector2, size: Vector2, color: Color):
	#var points = PackedVector2Array()
	#var num_points = 32
	#for i in range(num_points):
		#var angle = TAU * i / num_points
		#var x = size.x * cos(angle)
		#var y = size.y * sin(angle)
		#points.append(center + Vector2(x, y))
	#draw_colored_polygon(points, color)

#func draw_circle(center: Vector2, radius: float, color: Color):
	#var points = PackedVector2Array()
	#var num_points = 32
	#for i in range(num_points):
		#var angle = TAU * i / num_points
		#var x = radius * cos(angle)
		#var y = radius * sin(angle)
		#points.append(center + Vector2(x, y))
	#draw_colored_polygon(points, color)
