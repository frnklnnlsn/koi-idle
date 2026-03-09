# koi_movement.gd
# Attach to KoiFish Node2D (root of fish scene)
extends Node2D

# --- Node references ---
@onready var fish_body = %body
@onready var skeleton  = %skeleton

# --- Fish movement parameters ---
@export var num_points:      int     = 10
@export var start_position:  Vector2
@export var amplitude:       float   = 100.0
@export var wavelength:      float   = 0.5
@export var noise_intensity: float   = 100.0

# --- Circular boundary parameters ---
@export var circle_center:   Vector2 = Vector2(0, 0)
@export var circle_radius:   float   = 700.0
@export var max_turn_angle:  float   = 0.1

# --- Wandering behavior ---
@export var wander_strength:              float = 0.4
@export var wander_rate:                  float = 0.8
@export var boundary_avoidance_distance:  float = 800.0
@export var boundary_avoidance_strength:  float = 1.5

# --- State-specific speeds ---
@export var very_slow_speed:       float = 0.1
@export var slow_speed:            float = 0.3
@export var fast_speed:            float = 0.8
@export var acceleration_duration: float = 1.5
@export var deceleration_duration: float = 2.0
@export var start_in_slow_swim:    bool  = false

# --- Travelling wave parameters ---
## How fast the wave cycles (higher = faster wiggle)
@export var wave_frequency:   float = 3.0
## Peak side-to-side displacement at the tail in pixels
@export var wave_amplitude:   float = 8.0
## Normalised 0-1: where along the body oscillation starts ramping up
## 0.0 = whole body wiggles, 0.5 = back half, 0.8 = just the tail
@export var wave_start_point: float = 0.4
## How tightly each segment is offset in phase (creates the travelling look)
@export var wave_phase_step:  float = 0.8

# --- Debug ---
@export var debug_mode: bool = false

# --- State machine ---
enum FishState {
	VERY_SLOW_SWIM,
	ACCELERATING,
	SLOW_SWIM,
	FAST_SWIM,
	DECELERATING,
	EATING
}

var current_state: FishState = FishState.VERY_SLOW_SWIM
var state_timer:        float = 0.0
var next_state_change:  float = 5.0
var target_state:       FishState = FishState.SLOW_SWIM

# --- Internal ---
var seg_length:         int     = 300 / num_points
var noise               = FastNoiseLite.new()
var time:               float   = 0.0
var rotation_offset:    float   = PI / 4
var current_speed:      float   = 0.0
var start_speed:        float   = 0.0

var wander_angle:       float   = 0.0
var current_direction:  Vector2 = Vector2.RIGHT
var wander_timer:       float   = 0.0
var previous_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	noise.seed   = randi()
	noise.frequency = 0.2

	for i in range(num_points):
		var offset = i * seg_length
		var wave_y = sin(offset * wavelength) * amplitude
		fish_body.add_point(start_position + Vector2(offset, wave_y))
		skeleton.add_point(start_position + Vector2(offset, wave_y))

	if start_position == Vector2.ZERO:
		start_position = Vector2(400, 300)

	current_direction  = Vector2.RIGHT.rotated(randf() * TAU)
	previous_direction = current_direction
	wander_angle       = randf() * TAU

	if start_in_slow_swim:
		current_state = FishState.ACCELERATING
		target_state  = FishState.SLOW_SWIM
		start_speed   = very_slow_speed
	else:
		current_speed = very_slow_speed

	schedule_next_state_change()


func _process(delta: float) -> void:
	time         += delta
	state_timer  += delta
	wander_timer += delta

	if state_timer >= next_state_change:
		transition_to_next_state()

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


# ------------------------------------------------------------------ State machine

func transition_to_next_state() -> void:
	var previous_state = current_state

	match current_state:
		FishState.VERY_SLOW_SWIM:
			current_state = FishState.ACCELERATING
			target_state  = FishState.SLOW_SWIM if randf() < 0.7 else FishState.FAST_SWIM
		FishState.ACCELERATING:
			current_state = target_state
		FishState.SLOW_SWIM:
			if randf() < 0.3:
				current_state = FishState.DECELERATING
				target_state  = FishState.VERY_SLOW_SWIM
			elif randf() < 0.5:
				current_state = FishState.ACCELERATING
				target_state  = FishState.FAST_SWIM
		FishState.FAST_SWIM:
			if randf() < 0.4:
				current_state = FishState.DECELERATING
				target_state  = FishState.VERY_SLOW_SWIM
			elif randf() < 0.6:
				current_state = FishState.DECELERATING
				target_state  = FishState.SLOW_SWIM
		FishState.DECELERATING:
			current_state = target_state
		FishState.EATING:
			current_state = FishState.DECELERATING
			target_state  = FishState.VERY_SLOW_SWIM

	if current_state == FishState.ACCELERATING or current_state == FishState.DECELERATING:
		start_speed = current_speed

	schedule_next_state_change()


func schedule_next_state_change() -> void:
	state_timer = 0.0
	match current_state:
		FishState.VERY_SLOW_SWIM: next_state_change = randf_range(4.0, 10.0)
		FishState.ACCELERATING:   next_state_change = acceleration_duration
		FishState.SLOW_SWIM:      next_state_change = randf_range(4.0, 10.0)
		FishState.FAST_SWIM:      next_state_change = randf_range(2.0, 6.0)
		FishState.DECELERATING:   next_state_change = deceleration_duration
		FishState.EATING:         next_state_change = randf_range(3.0, 5.0)


# ------------------------------------------------------------------ Swimming

func update_swim_state(delta: float, speed: float) -> void:
	var head_pos = to_global(fish_body.get_point_position(0))

	# Wandering
	if wander_timer > 1.0:
		wander_angle += (randf() - 0.5) * wander_rate
		wander_timer  = 0.0

	var wander_force = Vector2(cos(wander_angle), sin(wander_angle)) * wander_strength

	# Boundary avoidance
	var distance_from_center = head_pos.distance_to(circle_center)
	var distance_from_edge   = circle_radius - distance_from_center
	var boundary_force       = Vector2.ZERO

	if distance_from_edge < boundary_avoidance_distance:
		var to_center          = (circle_center - head_pos).normalized()
		var avoidance_intensity = pow(
			1.0 - (distance_from_edge / boundary_avoidance_distance), 1.5
		)
		boundary_force = to_center * boundary_avoidance_strength * avoidance_intensity
		var perpendicular = to_center.rotated(PI / 2)
		if randf() > 0.5:
			perpendicular = -perpendicular
		boundary_force += perpendicular * avoidance_intensity * 0.2

	# Direction smoothing
	var total_force       = wander_force + boundary_force
	var desired_direction = (current_direction + total_force * 0.5).normalized()
	var turn_multiplier   = 1.5 if distance_from_edge < boundary_avoidance_distance * 0.3 else 1.0
	var smoothed_direction = previous_direction.lerp(desired_direction, 0.1 * turn_multiplier)
	var angle_diff = current_direction.angle_to(smoothed_direction)
	var max_turn   = max_turn_angle * turn_multiplier
	if abs(angle_diff) > max_turn:
		smoothed_direction = current_direction.rotated(sign(angle_diff) * max_turn)

	previous_direction = current_direction
	current_direction  = smoothed_direction

	# Head movement
	var move_distance = seg_length * speed
	var new_position  = head_pos + current_direction * move_distance
	var noise_offset  = Vector2(
		noise.get_noise_2d(time * speed, 0) * noise_intensity * 0.005,
		noise.get_noise_2d(0, time * speed) * noise_intensity * 0.005
	)
	new_position += noise_offset

	# Soft boundary clamp
	var final_distance = new_position.distance_to(circle_center)
	if final_distance > circle_radius:
		var overshoot          = final_distance - circle_radius
		var direction_to_center = (circle_center - new_position).normalized()
		new_position           += direction_to_center * overshoot * 0.8
		var reflection_strength = min(overshoot / 100.0, 0.3)
		current_direction = current_direction.lerp(direction_to_center, reflection_strength * 0.2)

	fish_body.set_point_position(0, to_local(new_position))
	skeleton.set_point_position(0, to_local(new_position))

	# Body segments — follow chain + travelling wave
	for i in range(1, fish_body.get_point_count()):
		var current_pos = fish_body.get_point_position(i)
		var ahead_pos   = fish_body.get_point_position(i - 1)
		var dir_to_ahead = (ahead_pos - current_pos).normalized()

		# Base follow position (keeps segment length fixed)
		var new_pos = ahead_pos - dir_to_ahead * seg_length

		# --- Travelling wave ---
		# t: how far along the body this point is (0=head, 1=tail)
		var t        = float(i) / float(num_points - 1)
		# Envelope ramps from 0 at wave_start_point to 1 at the tail
		var envelope = max(0.0, (t - wave_start_point) / max(1.0 - wave_start_point, 0.001))
		# Perpendicular to the direction of travel at this segment
		var perp     = dir_to_ahead.rotated(PI / 2)
		# Phase offset per segment creates the travelling wave look
		var wave     = sin(time * wave_frequency + i * wave_phase_step) * wave_amplitude * envelope
		new_pos     += perp * wave
		# Scale wave amplitude with speed so slow fish barely wiggle
		new_pos = fish_body.get_point_position(i).lerp(new_pos, clamp(speed * 3.0, 0.1, 1.0))

		fish_body.set_point_position(i, new_pos)
		skeleton.set_point_position(i, new_pos)

	if fish_body.get_point_count() > num_points:
		fish_body.remove_point(0)
	if skeleton.get_point_count() > num_points:
		skeleton.remove_point(0)


func update_accelerating_state(delta: float) -> void:
	var progress     = ease_out_quad(state_timer / acceleration_duration)
	var target_speed = slow_speed if target_state == FishState.SLOW_SWIM else fast_speed
	current_speed    = lerp(start_speed, target_speed, progress)
	update_swim_state(delta, current_speed)


func update_decelerating_state(delta: float) -> void:
	var progress     = ease_in_quad(state_timer / deceleration_duration)
	var target_speed = slow_speed if target_state == FishState.SLOW_SWIM else very_slow_speed
	current_speed    = lerp(start_speed, target_speed, progress)
	update_swim_state(delta, current_speed)


# ------------------------------------------------------------------ Public API

func get_current_state() -> FishState:
	return current_state


func get_fish_direction() -> float:
	if fish_body.get_point_count() >= 2:
		return (fish_body.get_point_position(0) - fish_body.get_point_position(1)).angle()
	return 0.0


func set_state(new_state: FishState) -> void:
	if new_state == current_state:
		return
	var prev = current_state
	current_state = new_state
	state_timer   = 0.0

	if prev == FishState.VERY_SLOW_SWIM and new_state in [FishState.SLOW_SWIM, FishState.FAST_SWIM]:
		current_state = FishState.ACCELERATING
		target_state  = new_state
		start_speed   = very_slow_speed
	elif prev in [FishState.SLOW_SWIM, FishState.FAST_SWIM] and new_state == FishState.VERY_SLOW_SWIM:
		current_state = FishState.DECELERATING
		target_state  = new_state
		start_speed   = current_speed
	elif prev == FishState.SLOW_SWIM and new_state == FishState.FAST_SWIM:
		current_state = FishState.ACCELERATING
		target_state  = new_state
		start_speed   = current_speed
	elif prev == FishState.FAST_SWIM and new_state == FishState.SLOW_SWIM:
		current_state = FishState.DECELERATING
		target_state  = new_state
		start_speed   = current_speed

	schedule_next_state_change()


# ------------------------------------------------------------------ Easing

func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t


# ------------------------------------------------------------------ Debug draw

func _draw() -> void:
	if not debug_mode:
		return
	draw_arc(circle_center, circle_radius, 0, TAU, 32, Color.ALICE_BLUE, 2.0)
	draw_arc(circle_center, circle_radius - boundary_avoidance_distance, 0, TAU, 32, Color.ORANGE, 1.0)

	var font      = ThemeDB.fallback_font
	var font_size = 16
	var state_text = FishState.keys()[current_state]
	if current_state in [FishState.ACCELERATING, FishState.DECELERATING]:
		state_text += " -> " + FishState.keys()[target_state]
	draw_string(font, Vector2(10, 30), "State: " + state_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(10, 50), "Speed: %.2f" % current_speed,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
	draw_string(font, Vector2(10, 70), "Wave amp: %.1f  freq: %.1f  start: %.2f" % [wave_amplitude, wave_frequency, wave_start_point],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)

	var head_pos      = to_global(fish_body.get_point_position(0))
	var direction_end = head_pos + current_direction * 50
	draw_line(to_local(head_pos), to_local(direction_end), Color.CYAN, 2.0)
