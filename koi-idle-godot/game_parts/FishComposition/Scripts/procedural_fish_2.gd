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
#   %FishBody     — Line2D for the visible body (carries the noise texture)
#   %Skeleton     — Line2D for the skeleton / fin anchor
#
# Boundary: assign `swim_area` (a SwimArea resource) before or after adding the
# fish to the tree. Whoever spawns fish owns the SwimArea and can share one
# resource across every fish in a pond.
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

## Boundary the fish stays inside. Forwarded to FishSteering.
## Safe to set before the fish enters the tree (stored until _ready).
@export var swim_area: SwimArea:
	set(value):
		swim_area = value
		if is_node_ready():
			_steering.swim_area = value

# Speed values — read by state machine and procedural_skeleton
@export var slow_speed:      float = 0.1
@export var fast_speed:      float = 0.3
@export var very_slow_speed: float = 0.05

# --- Saved place ---
## Write where the fish is (fish_res.swim_position / swim_heading) every
## REMEMBER_INTERVAL seconds, so it reappears there next start. The toilet
## and pond turn this on (FishDisplay); shop-card fish leave it off.
@export var remember_position: bool = false
## Heading to start with instead of a random one (set before adding the fish).
var start_heading: Vector2 = Vector2.ZERO

## How bent a new fish's body is, in degrees from head to tail. Each fish
## picks a random bend around this (most a little less, a few up to 3x more),
## curving left or right, like a fish caught mid-swim. 0 = dead straight.
## Measured on swimming fish: median head-to-tail bend about 12 degrees.
@export_range(0.0, 45.0, 0.5) var spawn_bend: float = 18.0
const REMEMBER_INTERVAL := 0.5
var _remember_timer: float = 0.0

# --- Live size (pond growth) ---
## How much a bigger fish speeds up: speed × size ^ this. 0 = same speed at
## any size, 0.5 = a 4× fish swims 2× faster, 1 = in proportion to size.
@export_range(0.0, 1.0, 0.05) var speed_size_exponent: float = 0.5
## Current size relative to the fish's normal size (1 = as built). Change it
## with set_size_factor(); the pond sets it from how much the fish has grown.
var size_factor: float = 1.0
var _target_size: float = 1.0
var _size_speed: float = 1.0   # size units per second while easing to the target
var _base_seg: float = 0.0
var _base_body_width: float = 0.0
var _base_skeleton_width: float = 0.0


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

## How far from the swim_area edge the fish starts turning away.
var boundary_avoidance_distance: float:
	get: return _steering.boundary_avoidance_distance
	set(value): _steering.boundary_avoidance_distance = value


# ------------------------------------------------------------------ Ready

func _ready() -> void:
	var seg_length = int((300.0 / num_points) * fish_scale)

	# Scale spatial values before building the Line2Ds
	amplitude *= fish_scale
	fish_body.width *= fish_scale
	skeleton.width  *= fish_scale

	# Pick the starting heading first so the body can be laid out behind it.
	if _steering.lock_heading:
		current_direction = _steering.locked_direction.normalized()
	elif start_heading != Vector2.ZERO:
		current_direction = start_heading.normalized()
	else:
		current_direction = Vector2.RIGHT.rotated(randf() * TAU)

	# Seed the Line2Ds: head at start_position, the body trailing behind it
	# in a gentle random curve (see spawn_bend), the way a swimming fish looks,
	# so it doesn't start wiggly or spend its first seconds straightening.
	# start_position is a LOCAL offset from the node's position (default 0,0),
	# matching the old procedural_fish so spawners can just set node.position.
	for i in range(num_points):
		fish_body.add_point(start_position)
		skeleton.add_point(start_position)
	_lay_out_body(seg_length)

	# Sizes at factor 1, for set_size_factor().
	_base_seg = seg_length
	_base_body_width = fish_body.width
	_base_skeleton_width = skeleton.width

	# Init components
	_state_machine.init(self)
	_state_machine.apply_scale(fish_scale)

	_steering.init(current_direction, fish_scale)
	_steering.swim_area = swim_area
	_body_chain.init(fish_body, skeleton, num_points, seg_length)
	_eating.init(fish_body, skeleton, _state_machine, seg_length)
	# Sized before entering the tree (set_size_factor): apply it now.
	if size_factor != 1.0:
		_apply_size()
		_respace_body()

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
	if size_factor != _target_size:
		size_factor = move_toward(size_factor, _target_size, _size_speed * delta)
		_apply_size()
	if remember_position and fish_res:
		_remember_timer += delta
		if _remember_timer >= REMEMBER_INTERVAL:
			_remember_timer = 0.0
			_remember_place()

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
	var result      = _steering.update(delta, head_global, _step_length(), speed, time)
	current_direction = result["direction"]
	_body_chain.update(
		to_local(result["new_head_global"]),
		speed,
		wave_amplitude * _wave_scale(), wave_frequency, wave_start_point, wave_phase_step,
		time
	)


func _eat(delta: float) -> void:
	_eating.update(delta, time)
	wave_amplitude = _eating.wave_amplitude
	current_speed  = _eating.current_speed

	# Phase 1 — fish is still moving; steering and body_chain handle movement
	if not _eating.is_stopped and current_speed > _eating.eating_stop_threshold:
		var head_global = to_global(fish_body.get_point_position(0))
		var result      = _steering.update(delta, head_global, _step_length(), current_speed, time)
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


## Jump straight into a state and hold it (no ACCEL/DECEL ramp).
func force_state(state: int) -> void:
	_state_machine.force_state(state)


func begin_entry(direction: Vector2, duration: float) -> void:
	_steering.begin_entry(direction, duration)


func set_state_wave_params(state: int, amp: float, freq: float, start: float, phase: float) -> void:
	_state_machine.set_wave_params(state, amp, freq, start, phase)


func get_state_wave_params(state: int) -> Dictionary:
	return _state_machine.get_wave_params(state)


## Stores where the head is (in the parent's space) and the heading on the
## fish's data; the next save writes it to disk.
func _remember_place() -> void:
	if fish_body.get_point_count() == 0:
		return
	fish_res.swim_position = position + fish_body.get_point_position(0)
	fish_res.swim_heading = current_direction


## Grow or shrink the fish to `factor` × its normal size, easing there over
## `seconds` (0 = at once). Swim area and behaviour are unchanged.
func set_size_factor(factor: float, seconds: float = 1.0) -> void:
	_target_size = maxf(factor, 0.01)
	if seconds <= 0.0 or not is_node_ready():
		size_factor = _target_size
		if is_node_ready():
			_apply_size()
			_respace_body()
	else:
		_size_speed = maxf(absf(_target_size - size_factor) / seconds, 0.0001)


func _apply_size() -> void:
	_body_chain.seg_length = _base_seg * size_factor
	fish_body.width = _base_body_width * size_factor
	skeleton.width = _base_skeleton_width * size_factor


## After an instant resize, lay the body out again at the new segment
## length, so a big fish doesn't spend seconds unfolding.
func _respace_body() -> void:
	_lay_out_body(_body_chain.seg_length)


## Lays the body out behind the head as a smooth arc with a random bend
## (spawn_bend; straight for fixed-heading card fish).
func _lay_out_body(seg: float) -> void:
	var count := fish_body.get_point_count()
	var bend := 0.0
	if not _steering.lock_heading and spawn_bend > 0.0:
		# Half-normal spread: median about 0.67 x spawn_bend, capped at 3x.
		bend = minf(absf(randfn(0.0, spawn_bend)), spawn_bend * 3.0)
		bend = deg_to_rad(bend) * (1.0 if randf() < 0.5 else -1.0)
	var turn := bend / maxf(count - 2, 1)
	var p := fish_body.get_point_position(0)
	var dir := -current_direction
	for i in range(1, count):
		p += dir * seg
		fish_body.set_point_position(i, p)
		skeleton.set_point_position(i, p)
		dir = dir.rotated(turn)


## Tail wiggle grows like the swim speed, not the full size: a big fish that
## moves less than its body length per beat would otherwise curl up.
func _wave_scale() -> float:
	return pow(size_factor, speed_size_exponent)


## How far the head moves per unit of speed: the normal segment length, sped
## up a little for bigger fish (speed_size_exponent).
func _step_length() -> float:
	return _base_seg * pow(size_factor, speed_size_exponent)


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
