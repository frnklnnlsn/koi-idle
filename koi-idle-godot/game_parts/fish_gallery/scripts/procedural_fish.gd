# procedural_fish.gd
# Attach to KoiFish Node2D (root of fish scene)
extends Node2D

@export var fish_scale: float = 0.05
@export var fish_res: fish_conf
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
@export var circle_radius:   float   = 1700.0
@export var max_turn_angle:  float   = 0.1

# --- Wandering behavior ---
@export var wander_strength:              float = 0.4
@export var wander_rate:                  float = 0.8
@export var boundary_avoidance_distance:  float = 800.0
@export var boundary_avoidance_strength:  float = 1.5

# --- State-specific speeds ---
@export var slow_speed:            float = 0.1
@export var fast_speed:            float = 0.3
@export var very_slow_speed:       float = 0.05
@export var acceleration_duration: float = 0.5
@export var deceleration_duration: float = 0.5
@export var start_in_slow_swim:    bool  = false

# --- Travelling wave parameters (live values, driven by state params below) ---
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

# --- State locking (used by debug panel) ---
## When true the state machine timer is frozen — no auto-transitions occur
var state_locked: bool = false

# --- Per-state wave parameters ---
## Each state stores its own amp/freq/start/phase.
## On every state transition these are applied to the live wave vars above.
## Edit via the debug panel; copy printed output into _init_state_wave_params() defaults.
var state_wave_params: Dictionary = {}

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

# --- Eating state ---
## Probability of entering EATING from VERY_SLOW_SWIM on each state transition
@export var eating_chance_from_very_slow: float = 0.2
## Probability of entering EATING from SLOW_SWIM on each state transition
@export var eating_chance_from_slow:      float = 0.15
## How long the fish rests and rocks after fully stopping (seconds)
@export var eating_rest_duration_min:     float = 2.0
@export var eating_rest_duration_max:     float = 4.0
## How long the deceleration-to-stop phase lasts
@export var eating_decel_duration:    float = 1.2
## Speed threshold below which the fish is considered fully stopped
@export var eating_stop_threshold:    float = 0.002
## How long the rocking wave fades back in once stopped (seconds)
@export var eating_wave_fade_in_time:  float = 0.8
## How long the body takes to straighten out after the fish stops (seconds)
## Should be >= eating_wave_fade_in_time for the smoothest look
@export var eating_straighten_duration: float = 2.0
var _eating_decel_start_speed: float = 0.0
var _eating_stopped:           bool  = false
var _eating_timer:             float = 0.0
## Tracks elapsed time since the fish fully stopped, used to fade the wave back in
var _eating_stopped_timer:     float = 0.0
## The base amplitude stored for this state, so we can scale back toward it
var _eating_target_amplitude:  float = 0.0
## Snapshot of each segment's angle at the moment the fish stops
## We lerp angles (not positions) to keep chain length constant during straightening
var _eating_stopped_angles:    Array = []
## Direction derived from the actual body geometry at stop time — more accurate than current_direction
var _eating_rest_direction:    Vector2 = Vector2.RIGHT

# --- Entry / pipe-spawn behaviour ---
var _entry_active:    bool    = false
var _entry_timer:     float   = 0.0
var _entry_duration:  float   = 0.0
var _entry_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	_init_state_wave_params()

	# Scale all spatial values by fish_scale
	seg_length      = int((300.0 / num_points) * fish_scale)
	amplitude       *= fish_scale
	noise_intensity *= fish_scale
	for state in state_wave_params:
		state_wave_params[state]["amp"] *= fish_scale

	# Scale the line widths to match
	fish_body.width *= fish_scale
	skeleton.width  *= fish_scale

	noise.seed      = randi()
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

	_apply_state_wave_params(current_state)
	schedule_next_state_change()


func _process(delta: float) -> void:
	time         += delta
	wander_timer += delta

	# Only advance the state timer and trigger transitions when not locked
	if not state_locked:
		state_timer += delta
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
			update_eating_state(delta)

	queue_redraw()


# ------------------------------------------------------------------ Per-state wave params

## Default values used on first run; override via debug panel and copy the printed output back here.
func _init_state_wave_params() -> void:
	state_wave_params = {
		FishState.VERY_SLOW_SWIM: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		FishState.ACCELERATING:   {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		FishState.SLOW_SWIM:      {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		FishState.FAST_SWIM:      {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		FishState.DECELERATING:   {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		# phase is intentionally 0.0 — standing wave, not travelling
		FishState.EATING:         {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.00},
	}


func _apply_state_wave_params(state: FishState) -> void:
	if not state_wave_params.has(state):
		return
	var p            = state_wave_params[state]
	wave_amplitude   = p["amp"]
	wave_frequency   = p["freq"]
	wave_start_point = p["start"]
	wave_phase_step  = p["phase"]


## Store new params for a state and immediately apply them if we're in that state.
func set_state_wave_params(state: int, amp: float, freq: float, start: float, phase: float) -> void:
	state_wave_params[state] = {"amp": amp, "freq": freq, "start": start, "phase": phase}
	if current_state == state:
		wave_amplitude   = amp
		wave_frequency   = freq
		wave_start_point = start
		wave_phase_step  = phase


## Return the stored params for a state (falls back to current live values).
func get_state_wave_params(state: int) -> Dictionary:
	return state_wave_params.get(state, {
		"amp":   wave_amplitude,
		"freq":  wave_frequency,
		"start": wave_start_point,
		"phase": wave_phase_step,
	})

## Call immediately after spawning to lock the fish onto a straight exit path.
##   direction : normalised vector pointing away from the pipe mouth
##   duration  : seconds before full wander / state-machine behaviour resumes
func begin_entry(direction: Vector2, duration: float) -> void:
	_entry_active     = true
	_entry_timer      = 0.0
	_entry_duration   = max(duration, 0.01)
	_entry_direction  = direction.normalized()
	# Seed the steering so the fish never starts fighting itself
	current_direction  = _entry_direction
	previous_direction = _entry_direction
	wander_angle       = _entry_direction.angle()

# ------------------------------------------------------------------ State locking (debug)

## Hard-lock to a specific state; the state machine timer stops.
func lock_to_state(state: int) -> void:
	state_locked = true
	# Use the public API so transition helpers fire correctly
	set_state(state as FishState)
	# Force-apply this state's wave params immediately
	_apply_state_wave_params(state as FishState)


## Release the lock; the state machine resumes from the current state.
func unlock_state() -> void:
	state_locked = false
	state_timer  = 0.0
	schedule_next_state_change()


# ------------------------------------------------------------------ State machine

func transition_to_next_state() -> void:
	match current_state:
		FishState.VERY_SLOW_SWIM:
			if randf() < eating_chance_from_very_slow:
				current_state = FishState.EATING
			else:
				current_state = FishState.ACCELERATING
				target_state  = FishState.SLOW_SWIM if randf() < 0.7 else FishState.FAST_SWIM
		FishState.ACCELERATING:
			current_state = target_state
		FishState.SLOW_SWIM:
			if randf() < eating_chance_from_slow:
				current_state = FishState.EATING
			elif randf() < 0.3:
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
			# After eating, ease back into gentle movement
			current_state = FishState.ACCELERATING
			target_state  = FishState.VERY_SLOW_SWIM if randf() < 0.6 else FishState.SLOW_SWIM
			start_speed   = 0.0

	if current_state == FishState.ACCELERATING or current_state == FishState.DECELERATING:
		start_speed = current_speed

	# Apply the wave personality for the new state
	_apply_state_wave_params(current_state)
	schedule_next_state_change()


func schedule_next_state_change() -> void:
	state_timer = 0.0
	match current_state:
		FishState.VERY_SLOW_SWIM: next_state_change = randf_range(4.0, 10.0)
		FishState.ACCELERATING:   next_state_change = acceleration_duration
		FishState.SLOW_SWIM:      next_state_change = randf_range(4.0, 10.0)
		FishState.FAST_SWIM:      next_state_change = randf_range(0.5, 2.0)
		FishState.DECELERATING:   next_state_change = deceleration_duration
		FishState.EATING:
			_eating_stopped           = false
			_eating_decel_start_speed = current_speed
			_eating_timer             = 0.0
			_eating_stopped_timer     = 0.0
			# Cache the target amplitude for this state so we can fade back to it
			_eating_target_amplitude  = state_wave_params[FishState.EATING]["amp"]
			# Start with wave amplitude at zero — it will fade in once stopped
			wave_amplitude            = 0.0
			# Total duration = decel phase + guaranteed rest time after stopping.
			# This ensures the state machine never fires mid-deceleration.
			next_state_change = eating_decel_duration + randf_range(eating_rest_duration_min, eating_rest_duration_max)


# ------------------------------------------------------------------ Swimming

func update_swim_state(delta: float, speed: float) -> void:
	var head_pos = to_global(fish_body.get_point_position(0))
# ---- Entry override: suppress wander and hold exit direction ----
	if _entry_active:
		_entry_timer += delta
		var t = clamp(_entry_timer / _entry_duration, 0.0, 1.0)
		if t >= 1.0:
			_entry_active = false          # hand back to normal steering
		else:
			# Ease-in: barely wiggles at first, gradually gives wander control back
			var blend         = ease_in_quad(t)
			var wander_vec    = Vector2(cos(wander_angle), sin(wander_angle))
			var target_dir    = _entry_direction.lerp(wander_vec * blend, blend).normalized()
			current_direction = current_direction.lerp(target_dir, 0.08).normalized()
			previous_direction = current_direction
			# Skip normal wander / boundary steering this frame
			# (still runs the body-chain / wave code below)
			var move_distance = seg_length * speed
			var new_head      = head_pos + current_direction * move_distance
			fish_body.set_point_position(0, to_local(new_head))
			skeleton.set_point_position(0, to_local(new_head))
			# Body chain + wave (identical to the normal path below)
			for i in range(1, fish_body.get_point_count()):
				var cur  = fish_body.get_point_position(i)
				var ahd  = fish_body.get_point_position(i - 1)
				var dta  = (ahd - cur).normalized()
				var np   = ahd - dta * seg_length
				var tv   = float(i) / float(num_points - 1)
				var env  = max(0.0, (tv - wave_start_point) / max(1.0 - wave_start_point, 0.001))
				var perp = dta.rotated(PI / 2)
				var wav  = sin(time * wave_frequency + i * wave_phase_step) * wave_amplitude * env
				np      += perp * wav
				np       = cur.lerp(np, clamp(speed * 3.0, 0.1, 1.0))
				fish_body.set_point_position(i, np)
				skeleton.set_point_position(i, np)
			return   # ← skip the rest of update_swim_state this frame
	# ---- end entry override ----
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
		var current_pos  = fish_body.get_point_position(i)
		var ahead_pos    = fish_body.get_point_position(i - 1)
		var dir_to_ahead = (ahead_pos - current_pos).normalized()

		var new_pos = ahead_pos - dir_to_ahead * seg_length

		# --- Travelling wave ---
		var t        = float(i) / float(num_points - 1)
		var envelope = max(0.0, (t - wave_start_point) / max(1.0 - wave_start_point, 0.001))
		var perp     = dir_to_ahead.rotated(PI / 2)
		var wave     = sin(time * wave_frequency + i * wave_phase_step) * wave_amplitude * envelope
		new_pos     += perp * wave
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


func update_eating_state(delta: float) -> void:
	_eating_timer += delta

	# --- Phase 1: decelerate to a full stop, fading wave amplitude with speed ---
	if not _eating_stopped:
		var progress  = min(_eating_timer / eating_decel_duration, 1.0)
		current_speed = lerp(_eating_decel_start_speed, 0.0, ease_in_quad(progress))

		# Scale wave amplitude proportionally to how much speed remains.
		# As the fish slows, the body flex naturally drains away — no snap at the end.
		var speed_ratio = current_speed / max(_eating_decel_start_speed, 0.0001)
		wave_amplitude  = _eating_target_amplitude * speed_ratio

		if current_speed > eating_stop_threshold:
			# Still moving — swim normally with the scaled-down wave
			update_swim_state(delta, current_speed)
		else:
			# Fully stopped — snapshot the actual (still-wavy) body positions
			current_speed         = 0.0
			wave_amplitude        = 0.0
			_eating_stopped       = true
			_eating_stopped_timer = 0.0
			# Derive rest direction from the actual head→neck vector, not current_direction
			# This ensures the spine target aligns with where the body is visually pointing
			if fish_body.get_point_count() >= 2:
				_eating_rest_direction = (fish_body.get_point_position(0) - fish_body.get_point_position(1)).normalized()
			else:
				_eating_rest_direction = current_direction
			# Snapshot each segment's angle — lerping angles (not positions) keeps
			# chain length fixed throughout the straightening transition
			_eating_stopped_angles.clear()
			for i in range(fish_body.get_point_count() - 1):
				var seg_dir = (fish_body.get_point_position(i) - fish_body.get_point_position(i + 1)).normalized()
				_eating_stopped_angles.append(seg_dir.angle())

		return

	# --- Phase 2: hold still, fade the rocking wave back in gently ---
	_eating_stopped_timer += delta
	var fade_progress = min(_eating_stopped_timer / eating_wave_fade_in_time, 1.0)
	# Ease in so the rock starts subtle rather than snapping to full amplitude
	wave_amplitude = _eating_target_amplitude * ease_in_quad(fade_progress)

	# Apply phase params for EATING (standing wave, phase_step == 0.0)
	var p = state_wave_params[FishState.EATING]
	wave_frequency   = p["freq"]
	wave_start_point = p["start"]
	wave_phase_step  = p["phase"]

	# Standing wave: head is the anchor, segments rock in place
	var head_pos   = fish_body.get_point_position(0)
	var perp       = _eating_rest_direction.rotated(PI / 2)
	var rest_angle = _eating_rest_direction.angle()

	var straighten_t        = min(_eating_stopped_timer / eating_straighten_duration, 1.0)
	var straighten_progress = ease_in_out_quad(straighten_t)

	# Reconstruct spine by walking each segment from the head using lerped angles.
	# Because we always step exactly seg_length, the chain length never changes.
	var reconstructed: Array = []
	reconstructed.append(head_pos)
	for i in range(fish_body.get_point_count() - 1):
		var snap_angle    = _eating_stopped_angles[i] if i < _eating_stopped_angles.size() else rest_angle
		var lerped_angle  = lerp_angle(snap_angle, rest_angle, straighten_progress)
		var seg_dir       = Vector2.from_angle(lerped_angle)
		reconstructed.append(reconstructed[i] - seg_dir * seg_length)

	for i in range(fish_body.get_point_count()):
		var base_pos = reconstructed[i]
		var t        = float(i) / float(fish_body.get_point_count() - 1)
		var envelope = max(0.0, (t - wave_start_point) / max(1.0 - wave_start_point, 0.001))
		var wave     = sin(time * wave_frequency + i * wave_phase_step) * wave_amplitude * envelope
		fish_body.set_point_position(i, base_pos + perp * wave)
		skeleton.set_point_position(i, fish_body.get_point_position(i))


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
	# Any swimming state can jump directly to EATING — schedule_next_state_change handles setup
	elif new_state == FishState.EATING:
		current_state = FishState.EATING

	schedule_next_state_change()


# ------------------------------------------------------------------ Easing

func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t

func ease_in_out_quad(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0


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
	var lock_text = " [LOCKED]" if state_locked else ""
	draw_string(font, Vector2(10, 30), "State: " + state_text + lock_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(10, 50), "Speed: %.2f" % current_speed,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
	draw_string(font, Vector2(10, 70), "Wave amp: %.1f  freq: %.1f  start: %.2f  phase: %.2f" % [wave_amplitude, wave_frequency, wave_start_point, wave_phase_step],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)

	var head_pos      = to_global(fish_body.get_point_position(0))
	var direction_end = head_pos + current_direction * 50
	draw_line(to_local(head_pos), to_local(direction_end), Color.CYAN, 2.0)
