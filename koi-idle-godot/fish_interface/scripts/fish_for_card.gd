extends Node2D

# Node references
@onready var fish_body = %body
@onready var skeleton = %skeleton

# Fish parameters
@export var num_points: int = 10
@export var start_position: Vector2
@export var swim_speed: float = 50.0

# Squiggle parameters
@export var squiggle_amplitude: float = 30.0
@export var squiggle_frequency: float = 2.0
@export var squiggle_chance: float = 0.3  # Chance per second to start squiggling

# Movement state - keeping original name for compatibility
enum FishState {
	STRAIGHT,
	SQUIGGLING
}

var current_state: FishState = FishState.STRAIGHT
var state_timer: float = 0.0
var squiggle_duration: float = 1.5
var straight_duration: float = 2.0

# Internal variables
var seg_length: int = 30
var time: float = 0.0
var squiggle_phase: float = 0.0
var movement_direction: Vector2 = Vector2.UP  # North direction

# Debugging
@export var debug_mode: bool = false

func _ready() -> void:
	#print("North-swimming fish ready")
	
	# Initialize fish body and skeleton points
	seg_length = 300 / num_points
	
	# Set initial position
	if start_position == Vector2.ZERO:
		start_position = Vector2(400, 300)
	
	# Create initial straight line of points going south (so fish faces north)
	for i in range(num_points):
		var point_pos = start_position + Vector2(0, i * seg_length)
		fish_body.add_point(point_pos)
		skeleton.add_point(point_pos)

func _process(delta: float) -> void:
	time += delta
	state_timer += delta
	
	# Handle state transitions
	match current_state:
		FishState.STRAIGHT:
			if state_timer >= straight_duration and randf() < squiggle_chance * delta:
				transition_to_squiggle()
		FishState.SQUIGGLING:
			if state_timer >= squiggle_duration:
				transition_to_straight()
	
	# Update fish movement
	update_fish_movement(delta)
	
	queue_redraw()

func transition_to_squiggle() -> void:
	current_state = FishState.SQUIGGLING
	state_timer = 0.0
	squiggle_phase = randf() * TAU  # Random starting phase
	#print("Starting squiggle")

func transition_to_straight() -> void:
	current_state = FishState.STRAIGHT
	state_timer = 0.0
	#print("Swimming straight")

func update_fish_movement(delta: float) -> void:
	var head_pos = fish_body.get_point_position(0)
	
	# Calculate base movement (always north)
	var base_movement = movement_direction * swim_speed * delta
	
	# Add squiggle if in squiggling state
	var lateral_offset = Vector2.ZERO
	if current_state == FishState.SQUIGGLING:
		# Create side-to-side motion perpendicular to movement direction
		var squiggle_intensity = sin(time * squiggle_frequency * TAU + squiggle_phase)
		# Fade in and out of squiggle for smoother transitions
		var fade_factor = 1.0
		if state_timer < 0.3:
			fade_factor = state_timer / 0.3
		elif state_timer > squiggle_duration - 0.3:
			fade_factor = (squiggle_duration - state_timer) / 0.3
		
		lateral_offset = movement_direction.rotated(PI/2) * squiggle_intensity * squiggle_amplitude * fade_factor * delta
	
	# Apply movement to head
	var new_head_pos = head_pos + base_movement + lateral_offset
	fish_body.set_point_position(0, new_head_pos)
	skeleton.set_point_position(0, new_head_pos)
	
	# Update body segments to follow the head
	for i in range(1, fish_body.get_point_count()):
		var current_pos = fish_body.get_point_position(i)
		var ahead_pos = fish_body.get_point_position(i - 1)
		
		# Calculate direction to the point ahead
		var direction_to_ahead = (ahead_pos - current_pos)
		var distance_to_ahead = direction_to_ahead.length()
		
		# If too far, move closer; if too close, move away slightly
		if distance_to_ahead > seg_length:
			var move_direction = direction_to_ahead.normalized()
			var new_pos = current_pos + move_direction * (distance_to_ahead - seg_length)
			fish_body.set_point_position(i, new_pos)
			skeleton.set_point_position(i, new_pos)
		elif distance_to_ahead < seg_length * 0.8:
			# Add slight follow delay for more natural movement
			var move_direction = direction_to_ahead.normalized()
			var new_pos = current_pos + move_direction * (distance_to_ahead - seg_length * 0.9)
			fish_body.set_point_position(i, new_pos)
			skeleton.set_point_position(i, new_pos)

func get_fish_direction() -> float:
	if fish_body.get_point_count() >= 2:
		var head_pos = fish_body.get_point_position(0)
		var neck_pos = fish_body.get_point_position(1)
		return (head_pos - neck_pos).angle()
	return movement_direction.angle()

func set_swim_speed(new_speed: float) -> void:
	swim_speed = new_speed

func set_squiggle_parameters(amplitude: float, frequency: float, chance: float) -> void:
	squiggle_amplitude = amplitude
	squiggle_frequency = frequency
	squiggle_chance = chance

func force_squiggle() -> void:
	if current_state == FishState.STRAIGHT:
		transition_to_squiggle()

func get_current_state() -> FishState:
	return current_state

func set_state(new_state: FishState) -> void:
	if new_state != current_state:
		current_state = new_state
		state_timer = 0.0
		print("State manually set to: ", FishState.keys()[current_state])

func _draw():
	if debug_mode:
		var state_text = "State: " + FishState.keys()[current_state]
		var speed_text = "Speed: " + str(swim_speed)
		var timer_text = "Timer: " + str(snapped(state_timer, 0.1))
		
		var font = ThemeDB.fallback_font
		var font_size = 16
		draw_string(font, Vector2(10, 30), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_string(font, Vector2(10, 50), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		draw_string(font, Vector2(10, 70), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)
		
		# Draw movement direction
		if fish_body.get_point_count() > 0:
			var head_pos = fish_body.get_point_position(0)
			var direction_end = head_pos + movement_direction * 50
			draw_line(head_pos, direction_end, Color.GREEN, 2.0)
			
			# Draw squiggle indicator
			if current_state == FishState.SQUIGGLING:
				draw_circle(head_pos, 20, Color.RED)
