class_name Pond extends SubViewport

# ── Pipe / grate configuration ─────────────────────────────────────────────
## World-space centre of the grate (set to wherever your pipe art sits)
@export var pipe_origin:        Vector2 = Vector2(0, -200)
## Gap between the 4 channel slots
@export var channel_spacing:    float   = 10.0
## Number of channels the grate creates
@export var channel_count:      int     = 4
## Direction fish swim when they exit the pipe  (DOWN = pipe flows into pond from top)
@export var channel_exit_dir:   Vector2 = Vector2.DOWN
## How long each fish swims "straight" before wandering freely (seconds)
@export var entry_swim_duration: float  = 2.5
## Seconds between each fish emerging — spread them out so it looks natural
@export var spawn_stagger_sec:   float  = 0.35

# ── Internal ────────────────────────────────────────────────────────────────
var _display:              FishDisplay
var _pending_display_list: Array = []

var _spawn_queue:  Array = []   # Array of fish data dicts waiting to be placed
var _spawn_timer:  float = 0.0
var _channel_idx:  int   = 0    # round-robins through channels

@onready var fish_container_pond: Node2D = %FishContainerPond


func _ready() -> void:
	DisplayManager.display_fish_pond.connect(Display)
	DisplayManager.fish_caught.connect(_on_fish_caught)
	DisplayManager.flush_completed.connect(_on_flush_completed)

	var factory = FishFactory.new()
	_display    = FishDisplay.new(factory)

	var save_data = SaveManager.load_saved_data()
	if save_data == null:
		push_warning("No save data found.")
		return
	_display.display_all(save_data.list_of_retired_fish, fish_container_pond)


func _process(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_pop_spawn_queue()
		_spawn_timer = spawn_stagger_sec


# ── Channel helpers ─────────────────────────────────────────────────────────

## Returns the 4 evenly-spaced world positions along the grate.
func _get_channel_positions() -> Array:
	var positions: Array = []
	var total_width = (channel_count - 1) * channel_spacing
	var start_x     = pipe_origin.x - total_width * 0.5
	for i in range(channel_count):
		positions.append(Vector2(start_x + i * channel_spacing, pipe_origin.y))
	return positions


## Pick the next channel in a round-robin, adding a tiny random nudge so fish
## don't stack perfectly on top of one another.
func _next_spawn_position() -> Vector2:
	var positions = _get_channel_positions()
	var base_pos  = positions[_channel_idx % channel_count]
	_channel_idx  = (_channel_idx + 1) % channel_count
	# Small perpendicular jitter so fish in the same channel don't overlap
	var perp      = channel_exit_dir.rotated(PI * 0.5)
	var jitter    = perp * randf_range(-channel_spacing * 0.15, channel_spacing * 0.15)
	return base_pos + jitter


# ── Spawn queue ─────────────────────────────────────────────────────────────

func _pop_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	var fish_data = _spawn_queue.pop_front()
	_spawn_one(fish_data)


func _spawn_one(fish_data) -> void:
	# Let FishDisplay create and add the node as usual
	_display.display_all([fish_data], fish_container_pond)

	# Grab the node that was just added (it will be the last child)
	var node = fish_container_pond.get_node_or_null(fish_data.ID)
	if node == null:
		return

	# Position it at the pipe channel (convert world → SubViewport local)
	var spawn_world = _next_spawn_position()
	node.position   = fish_container_pond.to_local(spawn_world)

	# Add a tiny direction wobble so each fish doesn't look identical
	var angle_wobble = randf_range(-0.25, 0.25)   # ± ~14° in radians
	var exit_dir     = channel_exit_dir.rotated(angle_wobble).normalized()

	# Tell the fish to swim straight out for a while before wandering
	if node.has_method("begin_entry"):
		node.begin_entry(exit_dir, entry_swim_duration)


# ── Signal handlers ─────────────────────────────────────────────────────────

func Display(list: Array) -> void:
	if _display == null:
		return
	_pending_display_list = list
	if not DisplayManager.is_flushing:
		_try_spawn_pending()


func _on_flush_completed() -> void:
	_try_spawn_pending()


func _try_spawn_pending() -> void:
	if _pending_display_list.is_empty():
		return
	var list              = _pending_display_list
	_pending_display_list = []
	_spawn_filtered(list)


func _spawn_filtered(list: Array) -> void:
	var existing_ids: Array = []
	for child in fish_container_pond.get_children():
		existing_ids.append(child.name)

	var new_fish = list.filter(func(f): return f.ID not in existing_ids)
	if new_fish.is_empty():
		return

	# Queue them — _process will drip them out one per stagger interval
	_spawn_queue.append_array(new_fish)
	_spawn_timer = 0.0   # fire the first one immediately


func _on_fish_caught(fish_list: Array) -> void:
	for fish in fish_list:
		var node = fish_container_pond.get_node_or_null(fish.ID)
		if node:
			node.queue_free()
