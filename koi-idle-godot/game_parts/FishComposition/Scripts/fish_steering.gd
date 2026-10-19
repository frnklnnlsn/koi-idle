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

# --- Portrait mode ---
## When true the fish ignores wander/avoidance and always swims in
## locked_direction. Used by card portraits so every fish faces the same way.
@export var lock_heading:     bool    = false
@export var locked_direction: Vector2 = Vector2.UP

# --- Avoidance ---
@export var boundary_avoidance_distance: float = 800.0
@export var boundary_avoidance_strength: float = 1.5
## How strongly avoiding a wall also turns the fish's wandering direction
## inward. Without it the wander keeps pulling toward the wall while the
## avoidance pushes away, and the fish slides along the edge.
## 0 = old behaviour (edge-hugging), 0.5 = spreads over the whole area,
## 1 = turns back sharply and favours the middle.
@export_range(0.0, 3.0, 0.05) var wall_turn_memory: float = 0.5
## How sharply a fish that touches the edge turns back inside (per frame).
## Was 0.06; higher = less sliding along the edge.
@export_range(0.0, 1.0, 0.01) var edge_bounce: float = 0.3

# --- Schooling ---
## Set every frame by the school while following (zero = wander on its own).
var follow_dir: Vector2 = Vector2.ZERO
## How strongly a follower steers toward follow_dir (wander uses wander_strength).
@export var follow_strength: float = 1.2
## Tightest turn allowed, as a radius in pond pixels (0 = no limit). Set while
## schooling: the slower the fish, the less it can turn per frame, so it
## swings round in an arc instead of folding its body in place.
var turn_radius: float = 0.0
var _radius_fade_from := 0.0
var _radius_fade_left := 0.0
var _radius_fade_time := 1.0


## Let the turn limit go gradually (after leaving a school), so a fish
## doesn't snap into a tight turn the moment it's on its own.
func fade_out_turn_radius(seconds: float) -> void:
	_radius_fade_from = turn_radius
	_radius_fade_time = maxf(seconds, 0.01)
	_radius_fade_left = _radius_fade_time

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
## Still swimming out of the pipe (begin_entry).
func is_entering() -> bool:
	return _entry_active


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
func update(delta: float, head_global: Vector2, seg_length: float,
			speed: float, time: float) -> Dictionary:
	_wander_timer += delta

	if lock_heading:
		current_direction  = locked_direction.normalized()
		previous_direction = current_direction
		return {
			"direction":       current_direction,
			"new_head_global": head_global + current_direction * seg_length * speed
		}

	if _entry_active:
		return _update_entry(head_global, seg_length, speed)

	return _update_wander(head_global, seg_length, speed, time)


# ------------------------------------------------------------------ Wander path

func _update_wander(head_global: Vector2, seg_length: float,
					speed: float, time: float) -> Dictionary:
	# Update wander angle periodically
	if _wander_timer > 1.0:
		_wander_angle += (randf() - 0.5) * wander_rate
		_wander_timer  = 0.0

	var wander_force = Vector2(cos(_wander_angle), sin(_wander_angle)) * wander_strength
	# In a school: head where the school says instead of wandering. Keep the
	# wander angle in step so leaving the school doesn't jerk the fish round.
	if follow_dir != Vector2.ZERO:
		wander_force = follow_dir * follow_strength
		_wander_angle = follow_dir.angle()

	# Boundary avoidance
	var boundary_force = Vector2.ZERO
	var dist_from_edge = 9999.0
	if swim_area:
		dist_from_edge = swim_area.distance_from_edge(head_global)
		if dist_from_edge < boundary_avoidance_distance:
			var to_safety  = swim_area.direction_to_safety(head_global)
			var intensity  = pow(1.0 - (dist_from_edge / boundary_avoidance_distance), 1.5)
			boundary_force = to_safety * boundary_avoidance_strength * intensity
			# Add a perpendicular nudge so fish curves away rather than reversing,
			# on the side it's already turning (a random side every frame cancels out).
			var side := 1.0 if current_direction.cross(to_safety) >= 0.0 else -1.0
			var perp = to_safety.rotated(PI / 2) * side
			boundary_force += perp * intensity * 0.2
			# Swing the wander direction inward too, so it stops pulling the fish
			# back toward the wall once the avoidance has turned it.
			if wall_turn_memory > 0.0:
				var k := clampf(wall_turn_memory * intensity * get_process_delta_time() * 3.0, 0.0, 1.0)
				_wander_angle = lerp_angle(_wander_angle, to_safety.angle(), k)

	# Direction smoothing with clamped turn rate
	var total_force       = wander_force + boundary_force
	var desired           = (current_direction + total_force * 0.5).normalized()
	var turn_mult         = 1.5 if dist_from_edge < boundary_avoidance_distance * 0.3 else 1.0
	var smoothed          = previous_direction.lerp(desired, 0.1 * turn_mult)
	var angle_diff        = current_direction.angle_to(smoothed)
	var max_turn          = max_turn_angle * turn_mult
	if _radius_fade_left > 0.0:
		_radius_fade_left = maxf(_radius_fade_left - get_process_delta_time(), 0.0)
		turn_radius = _radius_fade_from * _radius_fade_left / _radius_fade_time
	if turn_radius > 0.0:
		max_turn = minf(max_turn, maxf(seg_length * speed / turn_radius, 0.002))
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
		current_direction = current_direction.lerp(dir_to_center, edge_bounce).normalized()
		if wall_turn_memory > 0.0:
			_wander_angle = dir_to_center.angle()

	return {"direction": current_direction, "new_head_global": new_pos}


# ------------------------------------------------------------------ Entry path

func _update_entry(head_global: Vector2, seg_length: float, speed: float) -> Dictionary:
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
