# fish_state_machine.gd
# Child Node of procedural_fish (add as $FishStateMachine).
# Owns all state transitions, per-state wave param storage, and state locking.
# Emits signals so the coordinator and eating component can react without polling.
extends Node

# --- Signals ---
## Fired on every state transition. wave_params is the new state's params dict.
signal state_changed(new_state: int, wave_params: Dictionary)
## Fired specifically when EATING is entered so fish_eating can initialise itself.
signal eating_entered(start_speed: float)

# --- Exports (tweak in Inspector) ---
@export var acceleration_duration:        float = 0.5
@export var deceleration_duration:        float = 0.5
@export var eating_chance_from_very_slow: float = 0.2
@export var eating_chance_from_slow:      float = 0.15
@export var eating_rest_duration_min:     float = 2.0
@export var eating_rest_duration_max:     float = 4.0
@export var eating_decel_duration:        float = 1.2

# --- State (readable by coordinator / skeleton) ---
var current_state: int   = 0   # FishState.VERY_SLOW_SWIM
var state_timer:   float = 0.0
var next_state_change: float = 5.0
var target_state:  int   = 2   # FishState.SLOW_SWIM
var state_locked:  bool  = false
## Speed value at the moment a transition into ACCEL/DECEL was triggered.
## Read by coordinator for lerp and by procedural_skeleton for ellipse sizing.
var start_speed:   float = 0.0

var state_wave_params: Dictionary = {}

# Internal ref to coordinator (set via init)
var _fish: Node


# ------------------------------------------------------------------ Init

func init(fish_node: Node) -> void:
	_fish = fish_node
	_init_state_wave_params()


## Call from coordinator _ready AFTER setting the initial state values.
func schedule_next_state_change() -> void:
	state_timer = 0.0
	var FS = _fish.FishState
	match current_state:
		FS.VERY_SLOW_SWIM: next_state_change = randf_range(4.0, 10.0)
		FS.ACCELERATING:   next_state_change = acceleration_duration
		FS.SLOW_SWIM:      next_state_change = randf_range(4.0, 10.0)
		FS.FAST_SWIM:      next_state_change = randf_range(0.5, 2.0)
		FS.DECELERATING:   next_state_change = deceleration_duration
		FS.EATING:
			next_state_change = eating_decel_duration \
				+ randf_range(eating_rest_duration_min, eating_rest_duration_max)
			eating_entered.emit(_fish.current_speed)


# ------------------------------------------------------------------ Process

func _process(delta: float) -> void:
	if not _fish or state_locked:
		return
	state_timer += delta
	if state_timer >= next_state_change:
		_transition_to_next_state()


# ------------------------------------------------------------------ Wave params

func _init_state_wave_params() -> void:
	# Keyed by int so there's no enum dependency in this script.
	# 0=VERY_SLOW, 1=ACCEL, 2=SLOW, 3=FAST, 4=DECEL, 5=EATING
	state_wave_params = {
		0: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		1: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		2: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		3: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		4: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.10},
		5: {"amp": 3.50, "freq": 5.00, "start": 0.50, "phase": 0.00},
	}


## Scale the amp values once at startup after fish_scale is applied.
func apply_scale(fish_scale: float) -> void:
	for s in state_wave_params:
		state_wave_params[s]["amp"] *= fish_scale


func get_wave_params(state: int) -> Dictionary:
	return state_wave_params.get(state,
		{"amp": 3.5, "freq": 5.0, "start": 0.5, "phase": 0.1})


## Update stored params and immediately push them if we're in that state.
func set_wave_params(state: int, amp: float, freq: float, start: float, phase: float) -> void:
	state_wave_params[state] = {"amp": amp, "freq": freq, "start": start, "phase": phase}
	if current_state == state:
		state_changed.emit(current_state, state_wave_params[state])


# ------------------------------------------------------------------ Locking

func lock_to_state(state: int) -> void:
	state_locked = true
	set_state(state)


func unlock_state() -> void:
	state_locked = false
	state_timer  = 0.0
	schedule_next_state_change()


# ------------------------------------------------------------------ Public set_state

## Handles natural transition logic (adds ACCEL/DECEL bridging states).
func set_state(new_state: int) -> void:
	if new_state == current_state:
		return
	var FS   = _fish.FishState
	var prev = current_state
	current_state = new_state
	state_timer   = 0.0

	if prev == FS.VERY_SLOW_SWIM and new_state in [FS.SLOW_SWIM, FS.FAST_SWIM]:
		current_state = FS.ACCELERATING
		target_state  = new_state
		start_speed   = _fish.very_slow_speed
	elif prev in [FS.SLOW_SWIM, FS.FAST_SWIM] and new_state == FS.VERY_SLOW_SWIM:
		current_state = FS.DECELERATING
		target_state  = new_state
		start_speed   = _fish.current_speed
	elif prev == FS.SLOW_SWIM and new_state == FS.FAST_SWIM:
		current_state = FS.ACCELERATING
		target_state  = new_state
		start_speed   = _fish.current_speed
	elif prev == FS.FAST_SWIM and new_state == FS.SLOW_SWIM:
		current_state = FS.DECELERATING
		target_state  = new_state
		start_speed   = _fish.current_speed
	elif new_state == FS.EATING:
		current_state = FS.EATING

	state_changed.emit(current_state, get_wave_params(current_state))
	schedule_next_state_change()


# ------------------------------------------------------------------ Internal transitions

func _transition_to_next_state() -> void:
	var FS = _fish.FishState
	match current_state:
		FS.VERY_SLOW_SWIM:
			if randf() < eating_chance_from_very_slow:
				current_state = FS.EATING
			else:
				current_state = FS.ACCELERATING
				target_state  = FS.SLOW_SWIM if randf() < 0.7 else FS.FAST_SWIM
		FS.ACCELERATING:
			current_state = target_state
		FS.SLOW_SWIM:
			if randf() < eating_chance_from_slow:
				current_state = FS.EATING
			elif randf() < 0.3:
				current_state = FS.DECELERATING
				target_state  = FS.VERY_SLOW_SWIM
			elif randf() < 0.5:
				current_state = FS.ACCELERATING
				target_state  = FS.FAST_SWIM
		FS.FAST_SWIM:
			if randf() < 0.4:
				current_state = FS.DECELERATING
				target_state  = FS.VERY_SLOW_SWIM
			elif randf() < 0.6:
				current_state = FS.DECELERATING
				target_state  = FS.SLOW_SWIM
		FS.DECELERATING:
			current_state = target_state
		FS.EATING:
			current_state = FS.ACCELERATING
			target_state  = FS.VERY_SLOW_SWIM if randf() < 0.6 else FS.SLOW_SWIM
			start_speed   = 0.0

	if current_state in [FS.ACCELERATING, FS.DECELERATING]:
		start_speed = _fish.current_speed

	state_changed.emit(current_state, get_wave_params(current_state))
	schedule_next_state_change()
