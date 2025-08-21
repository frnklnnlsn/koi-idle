extends Camera2D
@onready var skeleton: Line2D = %skeleton

# Shake parameters
@export var shake_intensity: float = 10.0  # How strong the shake is
@export var shake_frequency: float = 8.0  # How fast it shakes (Hz)
@export var shake_damping: float = 0.95   # How quickly shake fades (for trauma-based)

# Swimming animation parameters
@export var swim_bob_amplitude: float = 1.5  # Vertical bobbing
@export var swim_bob_speed: float = 3.0      # Speed of bobbing
@export var swim_sway_amplitude: float = 0.8 # Horizontal swaying
@export var swim_sway_speed: float = 2.0     # Speed of swaying

# Internal variables
var time_passed: float = 0.0
var base_position: Vector2
var trauma: float = 0.0  # For trauma-based shake (0-1)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	time_passed += delta
	
	# Get the base position from skeleton
	var skeleton_pos = skeleton.get_point_position(0)
	base_position = Vector2(skeleton_pos.x, skeleton_pos.y + 100)
	
	# Calculate shake offset
	var shake_offset = calculate_shake_offset(delta)
	
	# Apply the final position
	self.position = base_position + shake_offset

# Method 1: Simple sine wave shake (gentle swimming motion)
func calculate_gentle_swim_shake() -> Vector2:
	var x_shake = sin(time_passed * swim_sway_speed) * swim_sway_amplitude
	var y_shake = sin(time_passed * swim_bob_speed) * swim_bob_amplitude
	
	# Add some randomness for more natural feel
	x_shake += sin(time_passed * shake_frequency + 1.5) * shake_intensity * 0.3
	y_shake += cos(time_passed * shake_frequency + 0.7) * shake_intensity * 0.3
	
	return Vector2(x_shake, y_shake)

# Method 2: Perlin noise-based shake (more organic)
func calculate_noise_shake() -> Vector2:
	var noise = FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = shake_frequency * 0.1
	
	var x_shake = noise.get_noise_2d(time_passed * 10, 0) * shake_intensity
	var y_shake = noise.get_noise_2d(0, time_passed * 10) * shake_intensity
	
	# Add swimming motion
	x_shake += sin(time_passed * swim_sway_speed) * swim_sway_amplitude
	y_shake += sin(time_passed * swim_bob_speed) * swim_bob_amplitude
	
	return Vector2(x_shake, y_shake)

# Method 3: Random shake with swimming motion
func calculate_random_swim_shake() -> Vector2:
	# Swimming motion (smooth)
	var swim_x = sin(time_passed * swim_sway_speed) * swim_sway_amplitude
	var swim_y = sin(time_passed * swim_bob_speed) * swim_bob_amplitude
	
	# Random jitter (choppy)
	var jitter_x = (randf() - 0.5) * shake_intensity
	var jitter_y = (randf() - 0.5) * shake_intensity
	
	return Vector2(swim_x + jitter_x, swim_y + jitter_y)

# Method 4: Trauma-based shake (for when fish gets excited/scared)
func calculate_trauma_shake(delta: float) -> Vector2:
	# Reduce trauma over time
	trauma = max(trauma - delta * shake_damping, 0.0)
	
	# Calculate shake based on trauma
	var shake_amount = trauma * trauma * shake_intensity
	
	var x_shake = (randf() - 0.5) * shake_amount
	var y_shake = (randf() - 0.5) * shake_amount
	
	# Add swimming motion
	x_shake += sin(time_passed * swim_sway_speed) * swim_sway_amplitude
	y_shake += sin(time_passed * swim_bob_speed) * swim_bob_amplitude
	
	return Vector2(x_shake, y_shake)

# Main shake calculation - choose your preferred method
func calculate_shake_offset(delta: float) -> Vector2:
	# Uncomment the method you want to use:
	
	return calculate_gentle_swim_shake()
	# return calculate_noise_shake()
	# return calculate_random_swim_shake()
	# return calculate_trauma_shake(delta)

# Call this to add sudden trauma (like fish getting startled)
func add_trauma(amount: float):
	trauma = min(trauma + amount, 1.0)

# Optional: Different shake patterns for different fish behaviors
func set_swimming_style(style: String):
	match style:
		"calm":
			shake_intensity = 1.0
			swim_bob_speed = 2.0
			swim_sway_speed = 1.5
		"active":
			shake_intensity = 3.0
			swim_bob_speed = 4.0
			swim_sway_speed = 3.0
		"excited":
			shake_intensity = 5.0
			swim_bob_speed = 6.0
			swim_sway_speed = 4.0
			add_trauma(0.5)

# Optional: Adjust shake based on fish movement speed
func update_shake_based_on_movement():
	# You could calculate fish velocity and adjust shake accordingly
	# This would make the camera more dynamic based on fish behavior
	pass
