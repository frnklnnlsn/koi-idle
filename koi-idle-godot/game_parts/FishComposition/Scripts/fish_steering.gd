# fish_steering.gd
# Child Node of procedural_fish (add as $FishSteering).
# Owns all direction-finding logic: wandering, boundary avoidance, entry override.
# Call update() each frame to get the new head global position and direction.
extends Node

# --- Boundary ---
## Assign before first frame. Can be swapped at runtime to move a fish to a new pond.
var swim_area: SwimArea = null

# --- Wander ---
@export var wander_strength: float = 0.4
@export var wander_rate:     float = 0.8
@export var max_turn_angle:  float = 0.1
@export var noise_intensity: float = 100.0

# --- Avoidance ---
@export var boundary_avoidance_distance: float = 800.0
@export var boundary_avoidance_strength: float = 1.5

# --- Live state (readable by coordinator) ---
var current_direction:  Vector2 = Vector2.RIGHT
var previous_direction: Vector2 = Vector2.RIGHT

# --- Internal ---
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0
var _noise := FastNoiseLite.new()

# --- Entry override ---
var _entry_active:    bool    = false
var _entry_timer:     float   = 0.0
var _entry_duration:  float   = 1.0
var _entry_direction: Vector2 = Vector2.DOWN


# ------------------------------------------------------------------ Init

func init(initial_direction: Vector2, fish_scale: float) -> void:
	noise_intensity    *= fish_scale
	_noise.seed         = randi()
	_noise.frequency    = 0.2
	current_direction   = initial_direction
	previous_direction  = initial_direction
	_wander_angle       = initial_direction.angle()


# ------------------------------------------------------------------ Entry override

## Lock the fish onto a straight exit path immediately after spawning from a pipe.
func begin_entry(direction: Vector2, duration: float) -> void:
	_entry_active    = true
	_entry_timer     = 0.0
	_entry_duration  = max(duration, 0.01)
	_entry_direction = direction.normalized()
	current_direction  = _entry_direction
	previous_direction = _entry_direction
	_wander_angle      = _entry_direction.angle()


# ------------------------------------------------------------------ Update

## Returns {"direction": Vector2, "new_head_global": Vector2}
## seg_length and speed are needed to compute how far the head moves this frame.
func update(delta: float, head_global: Vector2, seg_length: int,
			speed: float, time: float) -> Dictionary:
	_wander_timer += delta

	if _entry_active:
		return _update_entry(head_global, seg_length, speed)

	return _update_wander(head_global, seg_length, speed, time)


# ------------------------------------------------------------------ Wander path

func _update_wander(head_global: Vector2, seg_length: int,
					speed: float, time: float) -> Dictionary:
	# Update wander angle periodically
	if _wander_timer > 1.0:
		_wander_angle += (randf() - 0.5) * wander_rate
		_wander_timer  = 0.0

	var wander_force = Vector2(cos(_wander_angle), sin(_wander_angle)) * wander_strength

	# Boundary avoidance
	var boundary_force = Vector2.ZERO
	var dist_from_edge = 9999.0
	if swim_area:
		dist_from_edge = swim_area.distance_from_edge(head_global)
		if dist_from_edge < boundary_avoidance_distance:
			var to_safety  = swim_area.direction_to_safety(head_global)
			var intensity  = pow(1.0 - (dist_from_edge / boundary_avoidance_distance), 1.5)
			boundary_force = to_safety * boundary_avoidance_strength * intensity
			# Add a perpendicular nudge so fish curves away rather than reversing
			var perp = to_safety.rotated(PI / 2) * (1.0 if randf() > 0.5 else -1.0)
			boundary_force += perp * intensity * 0.2

	# Direction smoothing with clamped turn rate
	var total_force       = wander_force + boundary_force
	var desired           = (current_direction + total_force * 0.5).normalized()
	var turn_mult         = 1.5 if dist_from_edge < boundary_avoidance_distance * 0.3 else 1.0
	var smoothed          = previous_direction.lerp(desired, 0.1 * turn_mult)
	var angle_diff        = current_direction.angle_to(smoothed)
	var max_turn          = max_turn_angle * turn_mult
	if abs(angle_diff) > max_turn:
		smoothed = current_direction.rotated(sign(angle_diff) * max_turn)

	previous_direction = current_direction
	current_direction  = smoothed

	# Head movement + noise micro-jitter
	var new_pos = head_global + current_direction * seg_length * speed
	new_pos += Vector2(
		_noise.get_noise_2d(time * speed, 0.0) * noise_intensity * 0.005,
		_noise.get_noise_2d(0.0, time * speed) * noise_intensity * 0.005
	)

	# Soft boundary clamp — nudges head back inside without a hard snap
	if swim_area and not swim_area.is_inside(new_pos):
		new_pos           = swim_area.clamp_to_boundary(new_pos)
		var dir_to_center = swim_area.direction_to_safety(new_pos)
		current_direction = current_direction.lerp(dir_to_center, 0.06)

	return {"direction": current_direction, "new_head_global": new_pos}


# ------------------------------------------------------------------ Entry path

func _update_entry(head_global: Vector2, seg_length: int, speed: float) -> Dictionary:
	_entry_timer += get_process_delta_time()
	var t = clamp(_entry_timer / _entry_duration, 0.0, 1.0)
	if t >= 1.0:
		_entry_active = false

	var blend        = _ease_in_quad(t)
	var wander_vec   = Vector2(cos(_wander_angle), sin(_wander_angle))
	var target_dir   = _entry_direction.lerp(wander_vec * blend, blend)
	if target_dir.length_squared() > 0.0001:
		target_dir = target_dir.normalized()
	current_direction  = current_direction.lerp(target_dir, 0.08).normalized()
	previous_direction = current_direction

	return {
		"direction":       current_direction,
		"new_head_global": head_global + current_direction * seg_length * speed
	}


func _ease_in_quad(t: float) -> float:
	return t * t
