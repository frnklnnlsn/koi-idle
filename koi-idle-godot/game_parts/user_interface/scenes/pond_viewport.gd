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
## Keep the water effects inside the swim area (off: the pond's water fills
## the whole view).
@export var clip_water_to_swim_area: bool = false

# ── Growth → size ───────────────────────────────────────────────────────────
# Every fish enters the pond at the same size, whatever its mass. As it grows
# it gets bigger: growth = current mass ÷ mass when it entered the pond, and
# size = growth ^ size_exponent, capped at max_size_factor. The swim area
# stays the same for every size.
@export_group("Growth size")
## 0.333 = like real fish (mass grows with length³): 8× the mass = 2× as long.
## 0.5 = stronger (4× the mass = 2× as long), 0 = no size change.
@export_range(0.0, 1.0, 0.001) var size_exponent: float = 0.333
## Biggest a fish can get, relative to its starting size.
@export_range(1.0, 10.0, 0.1) var max_size_factor: float = 4.0
## Seconds a fish takes to swell to its new size after each growth update.
@export_range(0.0, 10.0, 0.1) var size_change_seconds: float = 2.0

# ── Depth ───────────────────────────────────────────────────────────────────
# Each fish swims at a depth picked at random when it first enters the pond
# (saved with the fish). Level 0 is the surface; each level down the fish is
# drawn behind the ones above, a bit smaller and a bit darker, so the pond
# looks deep. The swim area is the same at every depth.
@export_group("Depth")
## How many depth levels (1 = everyone at the surface).
@export_range(1, 10) var depth_levels: int = 4
## Size lost per level down: 0.12 = each level is 12% smaller than the surface
## (level 3 = 64% of the size).
@export_range(0.0, 0.3, 0.01) var depth_size_loss: float = 0.12
## Colour deep fish fade toward (multiplied over the fish, so it also darkens).
@export var depth_tint: Color = Color(0.14, 0.17, 0.32)
## How far toward depth_tint each level goes: 0.28 = level 3 is 84% of the way.
@export_range(0.0, 0.5, 0.01) var depth_darken: float = 0.28

# ── Internal ────────────────────────────────────────────────────────────────
var _display:              FishDisplay
var _pending_display_list: Array = []

var _spawn_queue:  Array = []   # Array of fish data dicts waiting to be placed
var _spawn_timer:  float = 0.0
var _channel_idx:  int   = 0    # round-robins through channels
## The pond's boundary, built from the PondArea/SwimShape node (drag / resize
## it in pond_area.tscn), shared by every pond fish.
var _swim_area: SwimArea

@onready var fish_container_pond: Node2D = %FishContainerPond


func _ready() -> void:
	current = self
	var swim_shape := get_node_or_null("PondArea/SwimShape") as SwimShape
	if swim_shape:
		_swim_area = swim_shape.make_swim_area()
		# Water layers get the pond's shape (for foam / clipping, see
		# pond_water.gdshader). Not clipped: the pond's water fills the view.
		_swim_area.setup_water_layers([get_node_or_null("WaterFloor"), get_node_or_null("WaterSurface"), get_node_or_null("Underwater")], clip_water_to_swim_area)
		fish_container_pond.child_entered_tree.connect(func(n):
			if "swim_area" in n:
				n.swim_area = _swim_area)
	DisplayManager.display_fish_pond.connect(Display)
	DisplayManager.fish_caught.connect(_on_fish_caught)
	DisplayManager.flush_completed.connect(_on_flush_completed)
	FishGrowthManager.growth_updated.connect(_update_sizes.bind(size_change_seconds))

	var factory = FishFactory.new()
	_display    = FishDisplay.new(factory)

	var save_data = SaveManager.load_saved_data()
	if save_data == null:
		push_warning("No save data found.")
		return
	_display.display_all(save_data.list_of_retired_fish, fish_container_pond)
	_update_sizes(0.0)


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
	_size_fish(node, 0.0)

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


# ── Growth → size ───────────────────────────────────────────────────────────

## How big a fish should look: 1 on entering the pond, more as it grows.
func size_for(fish: fish_conf) -> float:
	return growth_size(fish, size_exponent, max_size_factor)


## The pond's size rule as a plain function: 1 on entering the pond (or not
## in it yet), growth ^ exponent after, capped. Other screens (the fish list)
## use it with the running pond's settings through Pond.size_of().
static func growth_size(fish: fish_conf, exponent: float, cap: float) -> float:
	if fish == null or fish.y_start <= 0.0:
		return 1.0
	var growth := maxf(fish.mass / fish.y_start, 1.0)
	return clampf(pow(growth, exponent), 1.0, cap)


## The running pond (for size_of / max_size), or null.
static var current: Pond = null


## How big `fish` is drawn in the pond (growth only, not depth).
static func size_of(fish: fish_conf) -> float:
	if current and is_instance_valid(current):
		return current.size_for(fish)
	return growth_size(fish, 0.333, 4.0)


## The biggest size a fish can reach in the pond.
static func max_size() -> float:
	return current.max_size_factor if current and is_instance_valid(current) else 4.0


func _update_sizes(seconds: float) -> void:
	for node in fish_container_pond.get_children():
		_size_fish(node, seconds)


func _size_fish(node: Node, seconds: float) -> void:
	if not (node.has_method("set_size_factor") and "fish_res" in node) or node.fish_res == null:
		return
	var level := depth_of(node.fish_res)
	node.set_size_factor(size_for(node.fish_res) * maxf(1.0 - depth_size_loss * level, 0.05), seconds)
	node.z_index = -level   # deeper fish drawn behind
	node.modulate = Color.WHITE.lerp(depth_tint, clampf(depth_darken * level, 0.0, 1.0))


## The fish's depth level, picking one at random the first time.
func depth_of(fish: fish_conf) -> int:
	if fish.depth < 0 or fish.depth >= depth_levels:
		fish.depth = randi() % depth_levels
	return fish.depth


func _on_fish_caught(fish_list: Array) -> void:
	for fish in fish_list:
		var node = fish_container_pond.get_node_or_null(fish.ID)
		if node:
			node.queue_free()
