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
var shadow_update_interval: int = 3   # update shadow position every N frames
var _shadow_frame_counter: int  = 0


func _ready() -> void:
	factory = FishFactory.new()
	add_child(factory)
	# Let debug panel wire itself to us after both are ready
	if debug_panel:
		debug_panel.init(self)


func _process(delta: float) -> void:
	_process_spawn_queue()
	_process_shadows()


# ------------------------------------------------------------------ Spawning

## Queue a list of fish_conf resources for staggered spawning
func spawn_fish(fish_res_array: Array) -> void:
	_spawn_queue.append_array(fish_res_array)


## Spawn a single fish immediately, bypassing the queue
func spawn_fish_immediate(fish_res: fish_conf) -> void:
	var fish_node = factory.build(fish_res)
	fish_node.position = _random_spawn_position()
	_apply_boundary_to_fish(fish_node)
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

## Read the actual radius from the CollisionShape so fish always match
func _get_boundary_radius() -> float:
	if boundary_shape and boundary_shape.shape is CircleShape2D:
		return boundary_shape.shape.radius
	return 700.0


## Push the boundary radius into every live fish's circle_radius export
func _apply_boundary_to_fish(fish_node: Node2D) -> void:
	if fish_node.has_method("set"):
		fish_node.circle_radius = _get_boundary_radius()
		fish_node.circle_center = boundary_shape.global_position if boundary_shape else Vector2.ZERO


## Called by debug panel when boundary slider changes
func set_boundary_radius(new_radius: float) -> void:
	if boundary_shape and boundary_shape.shape is CircleShape2D:
		boundary_shape.shape.radius = new_radius
	# Update all live fish
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.circle_radius = new_radius


# ------------------------------------------------------------------ Shadows

func _create_shadow(fish_node: Node2D) -> Node2D:
	# Duplicate the entire fish subtree for the shadow
	var shadow = fish_node.duplicate()
	shadow.scale    = Vector2(shadow_scale, shadow_scale)
	shadow.modulate = shadow_modulate
	shadow.position = fish_node.position + shadow_offset
	# Disable shadow fish state machine processing to save perf
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
			# Just mirror position — shadow body points update via duplicate
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

## Force all live fish into a given FishState (pass the enum int)
func set_all_fish_state(state_index: int) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node) and fish_node.has_method("set_state"):
			fish_node.set_state(state_index)


## Override speed on all live fish
func set_all_fish_speed_multiplier(multiplier: float) -> void:
	for fish_node in _fish_nodes:
		if is_instance_valid(fish_node):
			fish_node.slow_speed  = 0.3  * multiplier
			fish_node.fast_speed  = 0.8  * multiplier
			fish_node.very_slow_speed = 0.1 * multiplier

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
