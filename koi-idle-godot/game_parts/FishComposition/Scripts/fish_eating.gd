# fish_eating.gd
# Child Node of procedural_fish (add as $FishEating).
# Owns the full two-phase eating behaviour:
#   Phase 1 — decelerate to a stop, draining wave amplitude with speed.
#   Phase 2 — hold still, straighten spine, fade a rocking wave back in.
#
# The coordinator calls begin() when EATING is entered,
# then calls update() every frame until the state machine transitions away.
extends Node

# --- Tweakables ---
@export var eating_decel_duration:      float = 1.2
@export var eating_stop_threshold:      float = 0.002
@export var eating_wave_fade_in_time:   float = 0.8
@export var eating_straighten_duration: float = 2.0

# --- Outputs read by coordinator each frame ---
var current_speed:  float = 0.0
var wave_amplitude: float = 0.0
## True once the fish has fully stopped (coordinator skips body_chain while true)
var is_stopped:     bool  = false

# --- Internal refs (set via init) ---
var _fish_body:      Line2D
var _skeleton:       Line2D
var _state_machine:  Node   # fish_state_machine

# --- Internal state ---
var _seg_length:          int     = 15
var _decel_start_speed:   float   = 0.0
var _eating_timer:        float   = 0.0
var _stopped_timer:       float   = 0.0
var _target_amplitude:    float   = 0.0
var _wave_frequency:      float   = 5.0
var _wave_start_point:    float   = 0.5
var _wave_phase_step:     float   = 0.0   # 0.0 = standing wave while resting
var _stopped_angles:      Array   = []
var _rest_direction:      Vector2 = Vector2.RIGHT


func init(fish_body: Line2D, skeleton: Line2D,
		  state_machine: Node, seg_length: int) -> void:
	_fish_body     = fish_body
	_skeleton      = skeleton
	_state_machine = state_machine
	_seg_length    = seg_length


# ------------------------------------------------------------------ Begin

## Call once when the EATING state is entered.
## start_speed is the fish's current_speed at that moment.
func begin(start_spd: float) -> void:
	is_stopped          = false
	current_speed       = start_spd
	_decel_start_speed  = start_spd
	_eating_timer       = 0.0
	_stopped_timer      = 0.0
	wave_amplitude      = 0.0

	var p               = _state_machine.get_wave_params(5)  # 5 = EATING
	_target_amplitude   = p["amp"]
	_wave_frequency     = p["freq"]
	_wave_start_point   = p["start"]
	_wave_phase_step    = p["phase"]


# ------------------------------------------------------------------ Update

## Call every frame while in EATING state.
## time is the coordinator's master clock (shared with body_chain).
func update(delta: float, time: float) -> void:
	_eating_timer += delta

	if not is_stopped:
		_update_decel_phase(delta)
	else:
		_update_rest_phase(delta, time)


# ------------------------------------------------------------------ Phase 1: deceleration

func _update_decel_phase(delta: float) -> void:
	var progress  = min(_eating_timer / eating_decel_duration, 1.0)
	current_speed = lerp(_decel_start_speed, 0.0, _ease_in_quad(progress))

	# Drain wave amplitude proportionally to remaining speed — body naturally relaxes
	var speed_ratio = current_speed / max(_decel_start_speed, 0.0001)
	wave_amplitude  = _target_amplitude * speed_ratio

	if current_speed <= eating_stop_threshold:
		# Fully stopped — snapshot body geometry for the rest phase
		current_speed  = 0.0
		wave_amplitude = 0.0
		is_stopped     = true
		_stopped_timer = 0.0
		_snapshot_stopped_geometry()


func _snapshot_stopped_geometry() -> void:
	# Derive rest direction from actual head→neck vector for accuracy
	if _fish_body.get_point_count() >= 2:
		_rest_direction = (
			_fish_body.get_point_position(0) - _fish_body.get_point_position(1)
		).normalized()

	# Snapshot each segment's angle so we can lerp toward straight during Phase 2
	_stopped_angles.clear()
	for i in range(_fish_body.get_point_count() - 1):
		var seg_dir = (
			_fish_body.get_point_position(i) - _fish_body.get_point_position(i + 1)
		).normalized()
		_stopped_angles.append(seg_dir.angle())


# ------------------------------------------------------------------ Phase 2: resting rock

func _update_rest_phase(delta: float, time: float) -> void:
	_stopped_timer += delta

	# Refresh wave params in case the debug panel changed them
	var p = _state_machine.get_wave_params(5)
	_target_amplitude = p["amp"]
	_wave_frequency   = p["freq"]
	_wave_start_point = p["start"]
	_wave_phase_step  = p["phase"]

	# Fade wave amplitude back in gently
	var fade_t     = min(_stopped_timer / eating_wave_fade_in_time, 1.0)
	wave_amplitude = _target_amplitude * _ease_in_quad(fade_t)

	# Straighten the spine toward rest_direction over time
	var straighten_t        = min(_stopped_timer / eating_straighten_duration, 1.0)
	var straighten_progress = _ease_in_out_quad(straighten_t)
	var rest_angle          = _rest_direction.angle()
	var head_pos            = _fish_body.get_point_position(0)
	var perp                = _rest_direction.rotated(PI / 2)

	# Reconstruct spine by walking from head using lerped angles.
	# Stepping exactly seg_length keeps the chain length constant (no stretching).
	var reconstructed: Array = [head_pos]
	for i in range(_fish_body.get_point_count() - 1):
		var snap_angle   = _stopped_angles[i] if i < _stopped_angles.size() else rest_angle
		var lerped_angle = lerp_angle(snap_angle, rest_angle, straighten_progress)
		var seg_dir      = Vector2.from_angle(lerped_angle)
		reconstructed.append(reconstructed[i] - seg_dir * _seg_length)

	# Apply standing wave on top of the reconstructed spine
	for i in range(_fish_body.get_point_count()):
		var base_pos = reconstructed[i]
		var t        = float(i) / float(_fish_body.get_point_count() - 1)
		var envelope = max(0.0, (t - _wave_start_point) / max(1.0 - _wave_start_point, 0.001))
		var wave     = sin(time * _wave_frequency + i * _wave_phase_step) * wave_amplitude * envelope
		_fish_body.set_point_position(i, base_pos + perp * wave)
		_skeleton.set_point_position(i, _fish_body.get_point_position(i))


# ------------------------------------------------------------------ Easing

func _ease_in_quad(t: float) -> float:
	return t * t

func _ease_in_out_quad(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
