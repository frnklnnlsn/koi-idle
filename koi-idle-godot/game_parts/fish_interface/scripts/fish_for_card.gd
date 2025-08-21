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
@export var squiggle_frequency: float = 0.55
@export var squiggle_chance: float = 1  # Chance per second to start squiggling

# Wave parameters for body undulation
@export var wave_length: float = 200.0  # Distance over which one complete wave occurs
@export var wave_speed: float = 5.0     # How fast the wave travels along the body

# Movement state - keeping original name for compatibility
enum FishState {
	STRAIGHT,
	SQUIGGLING
}

var current_state: FishState = FishState.STRAIGHT
var state_timer: float = 0.0
var squiggle_duration: float = 3.25
var straight_duration: float = 2.0

# Internal variables
var seg_length: int = 30
var time: float = 0.0
var squiggle_phase: float = 0.0
var movement_direction: Vector2 = Vector2.UP  # North direction
var base_spine_positions: Array[Vector2] = []  # Store the straight-line positions

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
	base_spine_positions.resize(num_points)
	for i in range(num_points):
		var point_pos = start_position + Vector2(0, i * seg_length)
		base_spine_positions[i] = point_pos
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
	# Move the base spine forward
	var base_movement = movement_direction * swim_speed * delta
	for i in range(num_points):
		base_spine_positions[i] += base_movement
	
	# Apply undulation to create the wavy fish body
	for i in range(num_points):
		var base_pos = base_spine_positions[i]
		var final_pos = base_pos
		
		if current_state == FishState.SQUIGGLING:
			# Calculate wave offset for this segment
			# Distance from head along the spine
			var spine_distance = i * seg_length
			
			# Calculate wave phase based on position along spine and time
			var wave_phase = (spine_distance / wave_length * TAU) - (time * wave_speed) + squiggle_phase
			
			# Calculate wave intensity (fade in/out for smooth transitions)
			var fade_factor = 1.0
			if state_timer < 0.3:
				fade_factor = state_timer / 0.3
			elif state_timer > squiggle_duration - 0.3:
				fade_factor = (squiggle_duration - state_timer) / 0.3
			
			# Apply sine wave offset perpendicular to movement direction
			var wave_offset = sin(wave_phase * squiggle_frequency) * squiggle_amplitude * fade_factor
			var perpendicular_direction = movement_direction.rotated(PI/2)
			final_pos += perpendicular_direction * wave_offset
		
		# Update the actual line points
		fish_body.set_point_position(i, final_pos)
		skeleton.set_point_position(i, final_pos)
	
	# Optional: Ensure segments maintain proper distance (for more rigid body feel)
	# Uncomment the following section if you want the segments to maintain consistent spacing
	"""
	for i in range(1, fish_body.get_point_count()):
		var current_pos = fish_body.get_point_position(i)
		var ahead_pos = fish_body.get_point_position(i - 1)
		
		var direction_to_ahead = (ahead_pos - current_pos)
		var distance_to_ahead = direction_to_ahead.length()
		
		if distance_to_ahead > seg_length * 1.2:  # Allow some flexibility
			var move_direction = direction_to_ahead.normalized()
			var new_pos = ahead_pos - move_direction * seg_length
			fish_body.set_point_position(i, new_pos)
			skeleton.set_point_position(i, new_pos)
			# Update base position too
			base_spine_positions[i] = new_pos
	"""

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

func set_wave_parameters(length: float, speed: float) -> void:
	wave_length = length
	wave_speed = speed

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
		var wave_text = "Wave Length: " + str(wave_length) + " Speed: " + str(wave_speed)
		
		var font = ThemeDB.fallback_font
		var font_size = 16
		draw_string(font, Vector2(10, 30), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_string(font, Vector2(10, 50), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		draw_string(font, Vector2(10, 70), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)
		draw_string(font, Vector2(10, 90), wave_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.MAGENTA)
		
		# Draw movement direction
		if fish_body.get_point_count() > 0:
			var head_pos = fish_body.get_point_position(0)
			var direction_end = head_pos + movement_direction * 50
			draw_line(head_pos, direction_end, Color.GREEN, 2.0)
			
			# Draw squiggle indicator
			if current_state == FishState.SQUIGGLING:
				draw_circle(head_pos, 20, Color.RED)
		
		# Draw base spine positions (for debugging)
		for i in range(base_spine_positions.size() - 1):
			draw_line(base_spine_positions[i], base_spine_positions[i + 1], Color.BLUE, 1.0)
