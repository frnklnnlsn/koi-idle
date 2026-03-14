# fish_test_ground.gd
# Attach to root Node2D of FishTestGround scene
extends Control

# --- Scene references ---
@onready var fish_container:   Node2D       = %FishContainer
@onready var shadow_container: Node2D       = %ShadowContainer
@onready var boundary_shape:   CollisionShape2D = %BoundaryShape
@onready var camera:           Camera2D     = %Camera2D
@onready var debug_panel                    = %DebugPanel

# --- Factory / builder ---
const FISH_FACTORY = preload("res://SandBox/Composition/component_scripts/fish_factory.gd")
var factory: FishFactory

# --- Spawn settings ---
@export var default_spawn_count: int  = 10
@export var spawn_stagger_frames: int = 1   # frames to wait between each fish spawn

# --- Tracking ---
var _fish_nodes:   Array = []   # all live fish Node2Ds
var _shadow_nodes: Array = []   # parallel array, one shadow per fish
var _spawn_queue:  Array = []   # fish_conf resources waiting to be spawned
var _frames_since_last_spawn: int = 0

# --- Shadow settings (tweakable from debug panel) ---
var shadow_enabled:   bool  = true
var shadow_scale:     float = 0.75
var shadow_modulate:  Color = Color(0.0, 0.0, 0.15, 0.45)
var shadow_offset:    Vector2 = Vector2(12, 14)
var shadow_update_interval: int = 3
var _shadow_frame_counter: int  = 0

# --- State editing ---
## -1 = auto (no lock), 0-5 = hard-locked to that FishState index
var _editing_state: int = -1

## Master copy of per-state wave params so newly-spawned fish inherit edits.
## Keyed by state index (int). Populated lazily on first edit.
var _master_wave_params: Dictionary = {}


func _ready() -> void:
	factory = FishFactory.new()
	add_child(factory)
	if debug_panel:
		debug_panel.init(self)


func _process(delta: float) -> void:
	_process_spawn_queue()
	_process_shadows()


# ------------------------------------------------------------------ Spawning

func spawn_fish(fish_res_array: Array) -> void:
	_spawn_queue.append_array(fish_res_array)


func spawn_fish_immediate(fish_res: fish_conf) -> void:
	var fish_node = factory.build(fish_res)
	fish_node.position = _random_spawn_position()
	_apply_boundary_to_fish(fish_node)

	# Push any wave params that have already been edited this session
	for state_index in _master_wave_params:
		var p = _master_wave_params[state_index]
		if fish_node.has_method("set_state_wave_params"):
			fish_node.set_state_wave_params(state_index, p["amp"], p["freq"], p["start"], p["phase"])

	# If a state lock is active, lock the new fish immediately
	if _editing_state >= 0 and fish_node.has_method("lock_to_state"):
		fish_node.lock_to_state(_editing_state)

	fish_container.add_child(fish_node)
	_fish_nodes.append(fish_node)

	if shadow_enabled:
		var shadow = _create_shadow(fish_node)
		shadow_container.add_child(shadow)
		_shadow_nodes.append(shadow)
	else:
		_shadow_nodes.append(null)


func _process_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	_frames_since_last_spawn += 1
	if _frames_since_last_spawn >= spawn_stagger_frames:
		_frames_since_last_spawn = 0
		var fish_res = _spawn_queue.pop_front()
		spawn_fish_immediate(fish_res)


func clear_all_fish() -> void:
	for node in _fish_nodes:
		if is_instance_valid(node):
			node.queue_free()
	for node in _shadow_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_fish_nodes.clear()
	_shadow_nodes.clear()
	_spawn_queue.clear()


func _random_spawn_position() -> Vector2:
	var radius = _get_boundary_radius() * 0.7
	var angle  = randf() * TAU
	return Vector2(cos(angle), sin(angle)) * radius * randf()


# ------------------------------------------------------------------ Boundary

func _get_boundary_radius() -> float:
	if boundary_shape and boundary_shape.shape is CircleShape2D:
		return boundary_shape.shape.radius
	return 700.0


func _apply_boundary_to_fish(fish_node: Node2D) -> void:
	if fish_node.has_method("set"):
		fish_node.circle_radius = _get_boundary_radius()
		fish_node.circle_center = boundary_shape.global_position if boundary_shape else Vector2.ZERO


func set_boundary_radius(new_radius: float) -> void:
	if boundary_shape and boundary_shape.shape is CircleShape2D:
		boundary_shape.shape.radius = new_radius
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.circle_radius = new_radius


# ------------------------------------------------------------------ State locking

## Hard-lock all fish to a state. -1 releases to auto-transitioning.
func set_fish_state_lock(state_index: int) -> void:
	_editing_state = state_index
	if state_index < 0:
		# Release lock — fish resume normal transitions
		for fish_node in _fish_nodes:
			if is_instance_valid(fish_node) and fish_node.has_method("unlock_state"):
				fish_node.unlock_state()
	else:
		for fish_node in _fish_nodes:
			if is_instance_valid(fish_node) and fish_node.has_method("lock_to_state"):
				fish_node.lock_to_state(state_index)


# ------------------------------------------------------------------ Per-state wave params

## Update the wave params for one state across all live fish + the master dict.
## Also immediately applies them when the fish are locked to that state.
func set_state_wave_params_for_all(state_index: int, amp: float, freq: float, start: float, phase: float) -> void:
	_master_wave_params[state_index] = {"amp": amp, "freq": freq, "start": start, "phase": phase}
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node) and fish_node.has_method("set_state_wave_params"):
			fish_node.set_state_wave_params(state_index, amp, freq, start, phase)


## Get the stored wave params for a state (reads from master dict or first live fish).
func get_state_wave_params(state_index: int) -> Dictionary:
	if _master_wave_params.has(state_index):
		return _master_wave_params[state_index]
	# Fall back to reading directly from a live fish
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node) and fish_node.has_method("get_state_wave_params"):
			var p = fish_node.get_state_wave_params(state_index)
			# Cache it so subsequent calls are consistent
			_master_wave_params[state_index] = p
			return p
	return {"amp": 8.0, "freq": 3.0, "start": 0.4, "phase": 0.8}


## Prints all per-state wave params to the Godot output panel.
## Copy the output straight into koi_movement._init_state_wave_params() as your new defaults.
func print_all_state_params() -> void:
	var state_names = ["VERY_SLOW_SWIM", "ACCELERATING", "SLOW_SWIM", "FAST_SWIM", "DECELERATING", "EATING"]
	print("\n# ===== Copy into koi_movement._init_state_wave_params() =====")
	print("state_wave_params = {")
	for i in state_names.size():
		var p = get_state_wave_params(i)
		print("\tFishState.%s: {\"amp\": %.2f, \"freq\": %.2f, \"start\": %.2f, \"phase\": %.2f}%s" % [
			state_names[i],
			p.get("amp",   8.0),
			p.get("freq",  3.0),
			p.get("start", 0.4),
			p.get("phase", 0.8),
			"," if i < state_names.size() - 1 else "",
		])
	print("}\n# =============================================================\n")


# ------------------------------------------------------------------ Shadows

func _create_shadow(fish_node: Node2D) -> Node2D:
	var shadow = fish_node.duplicate()
	shadow.scale    = Vector2(shadow_scale, shadow_scale)
	shadow.modulate = shadow_modulate
	shadow.position = fish_node.position + shadow_offset
	shadow.set_process(false)
	shadow.set_physics_process(false)
	return shadow


func _process_shadows() -> void:
	if not shadow_enabled:
		return
	_shadow_frame_counter += 1
	if _shadow_frame_counter < shadow_update_interval:
		return
	_shadow_frame_counter = 0

	for i in _fish_nodes.size():
		var fish   = _fish_nodes[i]
		var shadow = _shadow_nodes[i]
		if is_instance_valid(fish) and is_instance_valid(shadow):
			shadow.position = fish.position + shadow_offset
			shadow.modulate = shadow_modulate


func set_shadow_enabled(enabled: bool) -> void:
	shadow_enabled = enabled
	for shadow in _shadow_nodes:
		if is_instance_valid(shadow):
			shadow.visible = enabled


func set_shadow_scale(new_scale: float) -> void:
	shadow_scale = new_scale
	for shadow in _shadow_nodes:
		if is_instance_valid(shadow):
			shadow.scale = Vector2(new_scale, new_scale)


func set_shadow_opacity(opacity: float) -> void:
	shadow_modulate.a = opacity
	for shadow in _shadow_nodes:
		if is_instance_valid(shadow):
			shadow.modulate.a = opacity


# ------------------------------------------------------------------ Fish state control

## Force all live fish into a given FishState (pass the enum int).
## NOTE: prefer set_fish_state_lock() from the debug panel — this does not lock.
func set_all_fish_state(state_index: int) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node) and fish_node.has_method("set_state"):
			fish_node.set_state(state_index)


func set_all_fish_speed_multiplier(multiplier: float) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.slow_speed      = 0.3  * multiplier
			fish_node.fast_speed      = 0.8  * multiplier
			fish_node.very_slow_speed = 0.1  * multiplier

func set_all_fish_wave_amplitude(value: float) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.wave_amplitude = value

func set_all_fish_wave_frequency(value: float) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.wave_frequency = value

func set_all_fish_wave_start(value: float) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.wave_start_point = value

func set_all_fish_wave_phase(value: float) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.wave_phase_step = value


# ------------------------------------------------------------------ Camera

func set_camera_zoom(zoom_value: float) -> void:
	if camera:
		camera.zoom = Vector2(zoom_value, zoom_value)
