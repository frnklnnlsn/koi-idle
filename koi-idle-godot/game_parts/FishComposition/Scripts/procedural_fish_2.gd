# procedural_fish.gd
# Root Node2D of the fish scene. Thin coordinator — wires the four child
# components together and preserves the public API that procedural_skeleton
# and fish_test_ground depend on.
#
# Required child nodes (exact names):
#   $FishStateMachine  — fish_state_machine.gd
#   $FishSteering      — fish_steering.gd
#   $FishBodyChain     — fish_body_chain.gd
#   $FishEating        — fish_eating.gd
#
# Unique-name node refs (% prefix):
#   %"fish body"  — Line2D for the visible body
#   %skeleton     — Line2D for the skeleton / fin anchor
extends Node2D

# ------------------------------------------------------------------ Exports

@export var fish_scale:         float   = 0.05
@export var fish_res:           fish_conf
@export var num_points:         int     = 10
@export var start_position:     Vector2
@export var amplitude:          float   = 100.0
@export var wavelength:         float   = 0.5
@export var debug_mode:         bool    = false
@export var start_in_slow_swim: bool    = false

# Speed values — read by state machine and procedural_skeleton
@export var slow_speed:      float = 0.1
@export var fast_speed:      float = 0.3
@export var very_slow_speed: float = 0.05


# ------------------------------------------------------------------ State enum
# Kept here so procedural_skeleton can still do `koi.FishState.SLOW_SWIM` etc.

enum FishState {
	VERY_SLOW_SWIM,
	ACCELERATING,
	SLOW_SWIM,
	FAST_SWIM,
	DECELERATING,
	EATING
}


# ------------------------------------------------------------------ Node refs

@onready var fish_body: Line2D = %FishBody
@onready var skeleton:  Line2D = %Skeleton

@onready var _state_machine: Node = $FishStateMachine
@onready var _steering:      Node = $FishSteering
@onready var _body_chain:    Node = $FishBodyChain
@onready var _eating:        Node = $FishEating


# ------------------------------------------------------------------ Live coordinator state
# These are the single source of truth for values that cross component boundaries.

var current_speed:     float   = 0.0
var current_direction: Vector2 = Vector2.RIGHT
var time:              float   = 0.0

# Current wave params — updated via state_changed signal
var wave_amplitude:   float = 3.5
var wave_frequency:   float = 5.0
var wave_start_point: float = 0.5
var wave_phase_step:  float = 0.1


# ------------------------------------------------------------------ Pass-throughs for skeleton
# procedural_skeleton reads these via `koi.<property>`

var state_timer: float:
	get: return _state_machine.state_timer

var target_state: int:
	get: return _state_machine.target_state

var start_speed: float:
	get: return _state_machine.start_speed

var acceleration_duration: float:
	get: return _state_machine.acceleration_duration

var deceleration_duration: float:
	get: return _state_machine.deceleration_duration


# ------------------------------------------------------------------ Ready

func _ready() -> void:
	var seg_length = int((300.0 / num_points) * fish_scale)

	# Scale spatial values before building the Line2Ds
	amplitude *= fish_scale
	fish_body.width *= fish_scale
	skeleton.width  *= fish_scale

	# Seed the Line2Ds with initial positions
	if start_position == Vector2.ZERO:
		start_position = Vector2(400, 300)
	for i in range(num_points):
		var offset = i * seg_length
		var wave_y = sin(offset * wavelength) * amplitude
		fish_body.add_point(start_position + Vector2(offset, wave_y))
		skeleton.add_point(start_position + Vector2(offset, wave_y))

	# Init components
	_state_machine.init(self)
	_state_machine.apply_scale(fish_scale)

	current_direction = Vector2.RIGHT.rotated(randf() * TAU)
	_steering.init(current_direction, fish_scale)
	_body_chain.init(fish_body, skeleton, num_points, seg_length)
	_eating.init(fish_body, skeleton, _state_machine, seg_length)

	# Wire signals
	_state_machine.state_changed.connect(_on_state_changed)
	_state_machine.eating_entered.connect(_on_eating_entered)

	# Set starting state
	if start_in_slow_swim:
		_state_machine.current_state = FishState.ACCELERATING
		_state_machine.target_state  = FishState.SLOW_SWIM
		_state_machine.start_speed   = very_slow_speed
	else:
		current_speed = very_slow_speed

	# Seed wave params from the initial state
	_on_state_changed(
		_state_machine.current_state,
		_state_machine.get_wave_params(_state_machine.current_state)
	)
	_state_machine.schedule_next_state_change()


# ------------------------------------------------------------------ Process

func _process(delta: float) -> void:
	time += delta

	var FS = FishState
	match _state_machine.current_state:
		FS.VERY_SLOW_SWIM:
			_swim(delta, very_slow_speed)
		FS.ACCELERATING:
			var progress = _ease_out_quad(
				_state_machine.state_timer / _state_machine.acceleration_duration
			)
			var target = slow_speed if _state_machine.target_state == FS.SLOW_SWIM else fast_speed
			current_speed = lerp(_state_machine.start_speed, target, progress)
			_swim(delta, current_speed)
		FS.SLOW_SWIM:
			_swim(delta, slow_speed)
		FS.FAST_SWIM:
			_swim(delta, fast_speed)
		FS.DECELERATING:
			var progress = _ease_in_quad(
				_state_machine.state_timer / _state_machine.deceleration_duration
			)
			var target = slow_speed if _state_machine.target_state == FS.SLOW_SWIM else very_slow_speed
			current_speed = lerp(_state_machine.start_speed, target, progress)
			_swim(delta, current_speed)
		FS.EATING:
			_eat(delta)

	queue_redraw()


# ------------------------------------------------------------------ Internal swim / eat

func _swim(delta: float, speed: float) -> void:
	current_speed = speed
	var head_global = to_global(fish_body.get_point_position(0))
	var result      = _steering.update(delta, head_global, _body_chain.seg_length, speed, time)
	current_direction = result["direction"]
	_body_chain.update(
		to_local(result["new_head_global"]),
		speed,
		wave_amplitude, wave_frequency, wave_start_point, wave_phase_step,
		time
	)


func _eat(delta: float) -> void:
	_eating.update(delta, time)
	wave_amplitude = _eating.wave_amplitude
	current_speed  = _eating.current_speed

	# Phase 1 — fish is still moving; steering and body_chain handle movement
	if not _eating.is_stopped and current_speed > _eating.eating_stop_threshold:
		var head_global = to_global(fish_body.get_point_position(0))
		var result      = _steering.update(delta, head_global, _body_chain.seg_length, current_speed, time)
		current_direction = result["direction"]
		_body_chain.update(
			to_local(result["new_head_global"]),
			current_speed,
			wave_amplitude, wave_frequency, wave_start_point, wave_phase_step,
			time
		)
	# Phase 2 — is_stopped == true; fish_eating owns the body positions directly.


# ------------------------------------------------------------------ Signal handlers

func _on_state_changed(new_state: int, params: Dictionary) -> void:
	wave_amplitude   = params.get("amp",   wave_amplitude)
	wave_frequency   = params.get("freq",  wave_frequency)
	wave_start_point = params.get("start", wave_start_point)
	wave_phase_step  = params.get("phase", wave_phase_step)


func _on_eating_entered(spd: float) -> void:
	_eating.begin(spd)


# ------------------------------------------------------------------ Public API
# Preserves the interface expected by fish_test_ground and procedural_skeleton.

func get_current_state() -> int:
	return _state_machine.current_state


func get_fish_direction() -> float:
	if fish_body.get_point_count() >= 2:
		return (fish_body.get_point_position(0) - fish_body.get_point_position(1)).angle()
	return 0.0


func set_state(new_state: int) -> void:
	_state_machine.set_state(new_state)


func lock_to_state(state: int) -> void:
	_state_machine.lock_to_state(state)


func unlock_state() -> void:
	_state_machine.unlock_state()


func begin_entry(direction: Vector2, duration: float) -> void:
	_steering.begin_entry(direction, duration)


func set_state_wave_params(state: int, amp: float, freq: float, start: float, phase: float) -> void:
	_state_machine.set_wave_params(state, amp, freq, start, phase)


func get_state_wave_params(state: int) -> Dictionary:
	return _state_machine.get_wave_params(state)


# ------------------------------------------------------------------ Easing helpers

func _ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func _ease_in_quad(t: float) -> float:
	return t * t


# ------------------------------------------------------------------ Debug draw

func _draw() -> void:
	if not debug_mode:
		return

	# Draw boundary outline
	if _steering.swim_area:
		_draw_swim_area(_steering.swim_area)

	var font      = ThemeDB.fallback_font
	var font_size = 16
	var state_names = ["VERY_SLOW", "ACCEL", "SLOW", "FAST", "DECEL", "EATING"]
	var sm   = _state_machine
	var text = "State: " + state_names[sm.current_state]
	if sm.current_state in [FishState.ACCELERATING, FishState.DECELERATING]:
		text += " → " + state_names[sm.target_state]
	if sm.state_locked:
		text += " [LOCKED]"
	draw_string(font, Vector2(10, 30), text,     HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(10, 50), "Speed: %.3f" % current_speed,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
	draw_string(font, Vector2(10, 70),
		"Wave amp:%.1f freq:%.1f start:%.2f phase:%.2f" % [wave_amplitude, wave_frequency, wave_start_point, wave_phase_step],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)

	# Direction arrow from head
	var head = fish_body.get_point_position(0)
	draw_line(head, head + current_direction * 50.0, Color.CYAN, 2.0)


func _draw_swim_area(area: SwimArea) -> void:
	var local_center = to_local(area.center)
	match area.shape:
		SwimArea.Shape.CIRCLE:
			draw_arc(local_center, area.size.x, 0.0, TAU, 48, Color.ALICE_BLUE, 1.5)
			draw_arc(local_center, area.size.x - _steering.boundary_avoidance_distance,
				0.0, TAU, 48, Color.ORANGE, 1.0)
		SwimArea.Shape.ELLIPSE:
			_draw_ellipse(local_center, area.size, Color.ALICE_BLUE)
			_draw_ellipse(local_center,
				area.size - Vector2.ONE * _steering.boundary_avoidance_distance, Color.ORANGE)
		SwimArea.Shape.RECTANGLE:
			draw_rect(Rect2(local_center - area.size, area.size * 2.0), Color.ALICE_BLUE, false, 1.5)


func _draw_ellipse(center: Vector2, size: Vector2, color: Color, segments: int = 48) -> void:
	var pts = PackedVector2Array()
	for i in segments:
		var a = TAU * i / segments
		pts.append(center + Vector2(cos(a) * size.x, sin(a) * size.y))
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], color, 1.0)
