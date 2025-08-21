extends Node2D

# Node references
@onready var fish_body = %body
@onready var skeleton = %skeleton

# Fish movement parameters
@export var num_points: int = 10
@export var start_position: Vector2
@export var amplitude: float = 100.0
@export var wavelength: float = 0.5
@export var noise_intensity: float = 100.0

# Circular boundary parameters
@export var circle_center: Vector2 = Vector2(0,0)
@export var circle_radius: float = 700.0
@export var max_turn_angle: float = 0.1  # Reduced from 0.2 for smoother turns

# Wandering behavior parameters - IMPROVED VALUES
@export var wander_strength: float = 0.4      # Reduced for smoother movement
@export var wander_rate: float = 0.8          # Reduced for less erratic direction changes
@export var boundary_avoidance_distance: float = 800.0  # Much larger for smoother avoidance
@export var boundary_avoidance_strength: float = 1.5    # Slightly reduced for gentler steering

# State-specific parameters
@export var very_slow_speed: float = 0.1      # New very slow speed
@export var slow_speed: float = 0.3
@export var fast_speed: float = 0.8
@export var acceleration_duration: float = 1.5
@export var deceleration_duration: float = 2.0

# Startup parameters
@export var start_in_slow_swim: bool = false

# Ellipse and eye parameters
@export var ellipse_size: Vector2 = Vector2(20, 10)
@export var ellipse_spacing: int = 5
@export var ellipse_offset1: float = 20
@export var ellipse_offset2: float = 35

# Debugging
@export var debug_mode: bool = false

# State machine
enum FishState {
	VERY_SLOW_SWIM,
	ACCELERATING,
	SLOW_SWIM,
	FAST_SWIM,
	DECELERATING,
	EATING
}

var current_state: FishState = FishState.VERY_SLOW_SWIM
var state_timer: float = 0.0
var next_state_change: float = 5.0
var target_state: FishState = FishState.SLOW_SWIM

# Internal variables
var seg_length: int = 300 / num_points
var noise = FastNoiseLite.new()
var time: float = 0.0
var rotation_offset: float = PI / 4
var current_speed: float = 0.0
var start_speed: float = 0.0

# Wandering variables
var wander_angle: float = 0.0
var current_direction: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
var previous_direction: Vector2 = Vector2.RIGHT  # Track previous direction for smoother turns

func _ready() -> void:
	print("koi ready with state machine")
	
	noise.seed = randi()
	noise.frequency = 0.2
	
	# Initialize fish body and skeleton points
	for i in range(num_points):
		var offset = i * seg_length
		var wave_y = sin(offset * wavelength) * amplitude
		fish_body.add_point(start_position + Vector2(offset, wave_y))
		skeleton.add_point(start_position + Vector2(offset, wave_y))
	
	# Set initial position
	if start_position == Vector2.ZERO:
		start_position = Vector2(400, 300)
	
	# Initialize wandering direction
	current_direction = Vector2.RIGHT.rotated(randf() * TAU)
	previous_direction = current_direction
	wander_angle = randf() * TAU
	
	# Handle startup state
	if start_in_slow_swim:
		current_state = FishState.ACCELERATING
		target_state = FishState.SLOW_SWIM
		start_speed = very_slow_speed
	else:
		current_speed = very_slow_speed
	
	schedule_next_state_change()

func _process(delta: float) -> void:
	time += delta
	state_timer += delta
	wander_timer += delta
	
	# Check for state transitions
	if state_timer >= next_state_change:
		transition_to_next_state()
	
	# Update fish based on current state
	match current_state:
		FishState.VERY_SLOW_SWIM:
			update_swim_state(delta, very_slow_speed)
		FishState.ACCELERATING:
			update_accelerating_state(delta)
		FishState.SLOW_SWIM:
			update_swim_state(delta, slow_speed)
		FishState.FAST_SWIM:
			update_swim_state(delta, fast_speed)
		FishState.DECELERATING:
			update_decelerating_state(delta)
		FishState.EATING:
			update_swim_state(delta, very_slow_speed)
	
	queue_redraw()

func transition_to_next_state() -> void:
	var previous_state = current_state
	
	match current_state:
		FishState.VERY_SLOW_SWIM:
			current_state = FishState.ACCELERATING
			target_state = FishState.SLOW_SWIM if randf() < 0.7 else FishState.FAST_SWIM
		FishState.ACCELERATING:
			current_state = target_state
		FishState.SLOW_SWIM:
			if randf() < 0.3:
				current_state = FishState.DECELERATING
				target_state = FishState.VERY_SLOW_SWIM
			elif randf() < 0.5:
				current_state = FishState.ACCELERATING
				target_state = FishState.FAST_SWIM
			# else stay in SLOW_SWIM
		FishState.FAST_SWIM:
			if randf() < 0.4:
				current_state = FishState.DECELERATING
				target_state = FishState.VERY_SLOW_SWIM
			elif randf() < 0.6:
				current_state = FishState.DECELERATING
				target_state = FishState.SLOW_SWIM
			# else stay in FAST_SWIM
		FishState.DECELERATING:
			current_state = target_state
		FishState.EATING:
			current_state = FishState.DECELERATING
			target_state = FishState.VERY_SLOW_SWIM
	
	if current_state == FishState.ACCELERATING:
		start_speed = current_speed
	elif current_state == FishState.DECELERATING:
		start_speed = current_speed
	
	#print("State changed from ", FishState.keys()[previous_state], " to ", FishState.keys()[current_state])
	if current_state in [FishState.ACCELERATING, FishState.DECELERATING]:
		pass
		#print("  -> Target state: ", FishState.keys()[target_state])
	
	schedule_next_state_change()

func schedule_next_state_change() -> void:
	state_timer = 0.0
	match current_state:
		FishState.VERY_SLOW_SWIM:
			next_state_change = randf_range(4.0, 10.0)
		FishState.ACCELERATING:
			next_state_change = acceleration_duration
		FishState.SLOW_SWIM:
			next_state_change = randf_range(4.0, 10.0)
		FishState.FAST_SWIM:
			next_state_change = randf_range(2.0, 6.0)
		FishState.DECELERATING:
			next_state_change = deceleration_duration
		FishState.EATING:
			next_state_change = randf_range(3.0, 5.0)

func update_swim_state(delta: float, speed: float) -> void:
	var head_pos = to_global(fish_body.get_point_position(0))
	
	# Enhanced wandering behavior with time-based changes
	if wander_timer > 1.0:  # Increased to 1.0 second for smoother changes
		wander_angle += (randf() - 0.5) * wander_rate
		wander_timer = 0.0
	
	var wander_force = Vector2(cos(wander_angle), sin(wander_angle)) * wander_strength
	
	# Calculate distance from boundary
	var distance_from_center = head_pos.distance_to(circle_center)
	var distance_from_edge = circle_radius - distance_from_center
	
	# Improved boundary avoidance with much gentler steering
	var boundary_force = Vector2.ZERO
	if distance_from_edge < boundary_avoidance_distance:
		# Calculate direction toward center
		var to_center = (circle_center - head_pos).normalized()
		# Much more gradual avoidance that gets stronger as fish approaches edge
		var avoidance_intensity = 1.0 - (distance_from_edge / boundary_avoidance_distance)
		avoidance_intensity = pow(avoidance_intensity, 1.5)  # Less aggressive curve
		boundary_force = to_center * boundary_avoidance_strength * avoidance_intensity
		
		# Reduce perpendicular force for smoother movement
		var perpendicular = to_center.rotated(PI / 2)
		if randf() > 0.5:
			perpendicular = -perpendicular
		boundary_force += perpendicular * avoidance_intensity * 0.2  # Reduced from 0.5
	
	# Combine forces with smoothing
	var total_force = wander_force + boundary_force
	var desired_direction = (current_direction + total_force * 0.5).normalized()  # Reduce force influence
	
	# Much smoother turning with direction smoothing
	var turn_multiplier = 1.0
	if distance_from_edge < boundary_avoidance_distance * 0.3:
		# Only allow slightly sharper turns when very close to boundary
		turn_multiplier = 1.5  # Reduced from 2.0
	
	# Apply smoothing to direction changes
	var smoothed_direction = previous_direction.lerp(desired_direction, 0.1 * turn_multiplier)
	
	# Apply turn angle limiting to the smoothed direction
	var angle_diff = current_direction.angle_to(smoothed_direction)
	var max_turn = max_turn_angle * turn_multiplier
	if abs(angle_diff) > max_turn:
		smoothed_direction = current_direction.rotated(sign(angle_diff) * max_turn)
	
	# Update directions
	previous_direction = current_direction
	current_direction = smoothed_direction
	
	# Calculate movement
	var move_distance = seg_length * speed
	var new_position = head_pos + current_direction * move_distance
	
	# Add noise for organic movement (reduced intensity)
	var noise_offset = Vector2(
		noise.get_noise_2d(time * speed, 0) * noise_intensity * 0.005,  # Reduced from 0.01
		noise.get_noise_2d(0, time * speed) * noise_intensity * 0.005
	)
	new_position += noise_offset
	
	# Gentle boundary handling - no sharp corrections
	var final_distance = new_position.distance_to(circle_center)
	if final_distance > circle_radius:
		# Gentle pushback without sharp direction changes
		var overshoot = final_distance - circle_radius
		var direction_to_center = (circle_center - new_position).normalized()
		new_position += direction_to_center * overshoot * 0.8  # Gentle correction
		
		# Very gentle direction adjustment
		var reflection_strength = min(overshoot / 100.0, 0.3)  # Much more gradual
		current_direction = current_direction.lerp(direction_to_center, reflection_strength * 0.2)
	
	# Update positions
	fish_body.set_point_position(0, to_local(new_position))
	skeleton.set_point_position(0, to_local(new_position))

	# Update body segments
	for i in range(1, fish_body.get_point_count()):
		var current_pos = fish_body.get_point_position(i)
		var ahead_pos = fish_body.get_point_position(i - 1)
		var dir_to_ahead = (ahead_pos - current_pos).normalized()
		var new_pos = ahead_pos - dir_to_ahead * seg_length
		fish_body.set_point_position(i, new_pos)
		skeleton.set_point_position(i, new_pos)

	# Clean up excess points
	if fish_body.get_point_count() > num_points:
		fish_body.remove_point(0)
	if skeleton.get_point_count() > num_points:
		skeleton.remove_point(0)

func update_accelerating_state(delta: float) -> void:
	var progress = state_timer / acceleration_duration
	progress = ease_out_quad(progress)
	
	var target_speed = very_slow_speed
	if target_state == FishState.SLOW_SWIM:
		target_speed = slow_speed
	elif target_state == FishState.FAST_SWIM:
		target_speed = fast_speed
	
	current_speed = lerp(start_speed, target_speed, progress)
	
	update_swim_state(delta, current_speed)

func update_decelerating_state(delta: float) -> void:
	var progress = state_timer / deceleration_duration
	progress = ease_in_quad(progress)
	
	var target_speed = very_slow_speed
	if target_state == FishState.SLOW_SWIM:
		target_speed = slow_speed
	
	current_speed = lerp(start_speed, target_speed, progress)
	
	update_swim_state(delta, current_speed)

func get_fish_direction() -> float:
	if fish_body.get_point_count() >= 2:
		var head_pos = fish_body.get_point_position(0)
		var neck_pos = fish_body.get_point_position(1)
		return (head_pos - neck_pos).angle()
	return 0.0

func set_state(new_state: FishState) -> void:
	if new_state != current_state:
		var previous_state = current_state
		current_state = new_state
		state_timer = 0.0
		
		if previous_state == FishState.VERY_SLOW_SWIM and new_state in [FishState.SLOW_SWIM, FishState.FAST_SWIM]:
			current_state = FishState.ACCELERATING
			target_state = new_state
			start_speed = very_slow_speed
		elif previous_state in [FishState.SLOW_SWIM, FishState.FAST_SWIM] and new_state == FishState.VERY_SLOW_SWIM:
			current_state = FishState.DECELERATING
			target_state = new_state
			start_speed = current_speed
		elif previous_state == FishState.SLOW_SWIM and new_state == FishState.FAST_SWIM:
			current_state = FishState.ACCELERATING
			target_state = new_state
			start_speed = current_speed
		elif previous_state == FishState.FAST_SWIM and new_state == FishState.SLOW_SWIM:
			current_state = FishState.DECELERATING
			target_state = new_state
			start_speed = current_speed
		
		schedule_next_state_change()

func get_current_state() -> FishState:
	return current_state

func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t

func _draw():
	if debug_mode:
		draw_arc(circle_center, circle_radius, 0, TAU, 32, Color.ALICE_BLUE, 2.0)
		
		var state_text = "State: " + FishState.keys()[current_state]
		if current_state in [FishState.ACCELERATING, FishState.DECELERATING]:
			state_text += " -> " + FishState.keys()[target_state]
		var speed_text = "Speed: " + str(snapped(current_speed, 0.01))
		
		var font = ThemeDB.fallback_font
		var font_size = 16
		draw_string(font, Vector2(10, 30), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_string(font, Vector2(10, 50), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		
		draw_arc(circle_center, circle_radius - boundary_avoidance_distance, 0, TAU, 32, Color.ORANGE, 1.0)
		
		# Draw multiple boundary zones for better visualization
		draw_arc(circle_center, circle_radius - boundary_avoidance_distance * 0.5, 0, TAU, 32, Color.RED, 1.0)
		
		var head_pos = to_global(fish_body.get_point_position(0))
		var direction_end = head_pos + current_direction * 50
		draw_line(to_local(head_pos), to_local(direction_end), Color.CYAN, 2.0)
		
		# Draw previous direction for debugging
		var prev_direction_end = head_pos + previous_direction * 40
		draw_line(to_local(head_pos), to_local(prev_direction_end), Color.MAGENTA, 1.0)
