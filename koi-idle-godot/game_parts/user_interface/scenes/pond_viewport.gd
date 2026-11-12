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

# ── Visible fish ────────────────────────────────────────────────────────────
# Only max_visible fish swim at once; the rest wait "down in the deep" (kept
# in the save, not drawn, so a big pond stays cheap). Every rotate_every
# seconds the fish that has been up longest sinks out of sight (fades and
# darkens) and the one that has waited longest rises in its place.
# Fish arriving through the pipe swim in the top arrival_levels levels for
# arrival_settle_seconds before they join the rotation. Visible fish drift
# up or down a level now and then (drift_every), blending smoothly.
# Clicking a fish in the list brings it to the surface (Pond.surface()).
@export_group("Visible fish")
## Most fish swimming at once.
@export_range(1, 200) var max_visible: int = 20
## Seconds between one fish sinking and another rising.
@export_range(1.0, 120.0, 0.5) var rotate_every: float = 8.0
## Seconds a fish takes to fade out (sinking) or in (rising).
@export_range(0.2, 10.0, 0.1) var fade_seconds: float = 2.5
## New arrivals swim in this many top levels (3 = levels 0, 1, 2).
@export_range(1, 10) var arrival_levels: int = 3
## Seconds new arrivals stay near the surface, out of the rotation.
@export_range(0.0, 600.0, 1.0) var arrival_settle_seconds: float = 45.0
## Seconds between a fish's depth changes (random in this range).
@export var drift_every: Vector2 = Vector2(15.0, 40.0)
## Seconds a depth change takes to blend.
@export_range(0.1, 10.0, 0.1) var depth_change_seconds: float = 3.0

## Fish that must not sink (main_ui: the one the close-up is following).
var keep_visible: Callable

var _hidden: Array = []       # fish_conf down in the deep, longest-waiting first
var _settling := {}           # ID -> seconds left near the surface
var _drift_timers := {}       # ID -> seconds until its next depth change
var _shown_since := {}        # ID -> _clock when it came up
var _leaving := {}            # ID -> true while sinking out
var _fading := {}             # ID -> true while fading in or out
var _rotate_timer := 0.0
var _clock := 0.0

# ── Pixel size ──────────────────────────────────────────────────────────────
# Bigger fish get bigger pixels so they keep the pixel-art look (see
# pond_pixel_layers.gd). Every time a fish gets pixel_step bigger than it was
# when it entered the pond, its pixels go up by one, up to max_pixel_scale:
#
#   pixel_step 1.0:  size 1 → 1×,  size 2 → 2×,  size 3 → 3×,  size 4 → 4×
#   pixel_step 0.5:  size 1 → 1×,  1.5 → 2×,  2 → 3×,  2.5 → 4× (chunky sooner)
#
# "Size" is how big the fish is drawn: 1 on entering the pond, up to
# max_size_factor when fully grown (smaller for deeper fish).
@export_group("Pixel size")
## How much bigger a fish must get for each next pixel size.
@export_range(0.1, 4.0, 0.05) var pixel_step: float = 1.0
## Biggest pixels a fish can get (× normal). Also how many pixel layers the
## pond draws, so keep it small.
@export_range(1, 8) var max_pixel_scale: int = 4
## Blend the body pattern on big-pixel fish into average colours (calmer but
## muddier). Off = crisp palette colours, busy patterns may look speckled.
@export var smooth_big_patterns: bool = false

# ── Internal ────────────────────────────────────────────────────────────────
var _display:              FishDisplay
var _pending_display_list: Array = []

var _spawn_queue:  Array = []   # Array of fish data dicts waiting to be placed
var _spawn_timer:  float = 0.0
var _channel_idx:  int   = 0    # round-robins through channels
## The pond's boundary, built from PondArea/PondShape (drag its outline points
## in pond_area.tscn), shared by every pond fish.
var _swim_area: SwimArea

@onready var fish_container_pond: Node2D = %FishContainerPond


func _ready() -> void:
	current = self
	# The pond's outline: the organic PondShape if there is one (it draws the
	# banks too), else the plain SwimShape.
	var pond_shape := get_node_or_null("PondArea/PondShape") as PondShape
	var swim_shape := get_node_or_null("PondArea/SwimShape") as SwimShape
	if pond_shape or swim_shape:
		_swim_area = pond_shape.make_swim_area() if pond_shape else swim_shape.make_swim_area()
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
	# Up to max_visible fish come up; the rest start down in the deep.
	var all: Array = save_data.list_of_retired_fish.duplicate()
	all.shuffle()
	_hidden = all.slice(max_visible)
	for f in all.slice(0, max_visible):
		_show(f, false)
	_update_sizes(0.0)
	_rotate_timer = rotate_every


func _process(delta: float) -> void:
	_update_visible(delta)
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
	# New arrivals swim near the surface for a while, out of the rotation.
	fish_data.depth = randi() % mini(arrival_levels, depth_levels)
	_settling[fish_data.ID] = arrival_settle_seconds
	_came_up(node)
	_size_fish(node, 0.0)
	# Make room: someone who's been up a while sinks.
	if _visible_count() > max_visible:
		var out := _pick_sinker()
		if out:
			_sink(out, fade_seconds * 0.6)

	# Position it at the pipe channel (convert world → SubViewport local)
	var spawn_world = _next_spawn_position()
	node.position   = fish_container_pond.to_local(spawn_world)

	# Add a tiny direction wobble so each fish doesn't look identical
	var angle_wobble = randf_range(-0.25, 0.25)   # ± ~14° in radians
	var exit_dir     = channel_exit_dir.rotated(angle_wobble).normalized()

	# Tell the fish to swim straight out for a while before wandering,
	# shot out fast by the water (it eases back to its normal pace).
	if node.has_method("begin_entry"):
		node.begin_entry(exit_dir, entry_swim_duration)
	if node.has_method("force_state"):
		node.force_state(node.FishState.FAST_SWIM)


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
	# Known fish: swimming, queued, or down in the deep. Only new ones come
	# through the pipe.
	var known := {}
	for child in fish_container_pond.get_children():
		known[str(child.name)] = true
	for f in _hidden:
		known[f.ID] = true
	for f in _spawn_queue:
		known[f.ID] = true
	var ids := {}
	for f in list:
		ids[f.ID] = true
	_hidden = _hidden.filter(func(f): return ids.has(f.ID))   # gone from the pond

	var new_fish = list.filter(func(f): return not known.has(f.ID))
	if new_fish.is_empty():
		return
	# More arrivals than can be seen at once: the extra go straight down,
	# first in line to rise.
	if new_fish.size() > max_visible:
		_hidden = new_fish.slice(max_visible) + _hidden
		new_fish = new_fish.slice(0, max_visible)

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


## How many times bigger than normal `fish`'s pixels are in the pond
## (1 = normal; one more each pixel_step it grows, see pixel_group).
static func pixel_scale_of(fish: fish_conf) -> int:
	var s := size_of(fish)
	if current and is_instance_valid(current):
		return current.pixel_group(s) + 1
	return clampi(floori(s - 1.0 + 0.01) + 1, 1, 4)


## Picture pixels per pond pixel for `fish` (FishIconRenderer): its size
## spread over its pixel scale, so a picture blown up by pixel_scale_of()
## has the same chunky pixels as the fish in the pond.
static func icon_density(fish: fish_conf) -> float:
	return size_of(fish) / float(pixel_scale_of(fish))


## The biggest size a fish can reach in the pond.
static func max_size() -> float:
	return current.max_size_factor if current and is_instance_valid(current) else 4.0


func _update_sizes(seconds: float) -> void:
	for node in fish_container_pond.get_children():
		if not _leaving.has(str(node.name)):
			_size_fish(node, seconds)


func _size_fish(node: Node, seconds: float) -> void:
	if not (node.has_method("set_size_factor") and "fish_res" in node) or node.fish_res == null:
		return
	var level := depth_of(node.fish_res)
	var drawn := size_for(node.fish_res) * maxf(1.0 - depth_size_loss * level, 0.05)
	node.set_size_factor(drawn, seconds)
	PondPixelLayers.set_layers(node, PondPixelLayers.fish_bit(pixel_group(drawn)))
	# Bigger pixels sample the body pattern more sparsely: with mipmaps they
	# take the pattern's average colour per pixel instead of a speckle.
	var body: CanvasItem = node.get_node_or_null("%FishBody")
	if body and smooth_big_patterns:
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	node.z_index = -level   # deeper fish drawn behind
	# Fading fish (rising / sinking) have their own tween on modulate.
	if _fading.has(str(node.name)):
		return
	var look := Color.WHITE.lerp(depth_tint, clampf(depth_darken * level, 0.0, 1.0))
	if seconds > 0.0:
		node.create_tween().tween_property(node, "modulate", look, seconds)
	else:
		node.modulate = look


## Pixel size group for a fish drawn `drawn` × normal size: 0 = normal
## pixels, 1 = 2×, ... (one more for every pixel_step it has grown).
func pixel_group(drawn: float) -> int:
	# A little slack: growth ^ 0.333 lands just under whole sizes (8^0.333 = 1.9986).
	var g := floori((drawn - 1.0 + 0.01) / maxf(pixel_step, 0.01))
	return clampi(g, 0, max_pixel_scale - 1)


## The fish's depth level, picking one at random the first time.
func depth_of(fish: fish_conf) -> int:
	if fish.depth < 0 or fish.depth >= depth_levels:
		fish.depth = randi() % depth_levels
	return fish.depth


func _on_fish_caught(fish_list: Array) -> void:
	var ids := {}
	for fish in fish_list:
		ids[fish.ID] = true
		var node = fish_container_pond.get_node_or_null(fish.ID)
		if node:
			node.queue_free()
		_forget(fish.ID)
	_hidden = _hidden.filter(func(f): return not ids.has(f.ID))


# ── Visible fish ────────────────────────────────────────────────────────────

## Where the pipe is on screen, kept a little inside the pond view (the
## pipe sits just off its top edge). For the flush cut scene.
func pipe_screen_position() -> Vector2:
	var c := get_parent() as SubViewportContainer
	var shrink := float(c.stretch_shrink) if c else 1.0
	var local := (canvas_transform * pipe_origin) * shrink
	if c == null:
		return local
	local = local.clamp(Vector2(40, 40), c.size - Vector2(40, 40))
	return c.get_global_transform() * local


## Brings `fish` to the surface (from the deep if it's hidden) and keeps it
## near the top for arrival_settle_seconds. For the fish list.
static func surface(fish: fish_conf) -> void:
	if current and is_instance_valid(current) and fish:
		current._surface(fish)


## Is `fish` swimming in view (not down in the deep)?
static func is_visible_fish(fish: fish_conf) -> bool:
	if not (current and is_instance_valid(current) and fish):
		return false
	return current.fish_container_pond.has_node(fish.ID) and not current._leaving.has(fish.ID)


func _surface(fish: fish_conf) -> void:
	var node := fish_container_pond.get_node_or_null(fish.ID)
	if node == null or _leaving.has(fish.ID):
		if node:   # sinking right now: let it go and bring it straight back
			_leaving.erase(fish.ID)
			_fading.erase(fish.ID)
			node.queue_free()
			await get_tree().process_frame
		_hidden.erase(fish)
		fish.depth = 0
		node = _show(fish, true)
		if _visible_count() > max_visible:
			var out := _pick_sinker()
			if out:
				_sink(out, fade_seconds * 0.6)
	else:
		fish.depth = 0
		_size_fish(node, depth_change_seconds)
	_settling[fish.ID] = arrival_settle_seconds
	_shown_since[fish.ID] = _clock


func _update_visible(delta: float) -> void:
	_clock += delta
	for id in _settling.keys():
		_settling[id] -= delta
		if _settling[id] <= 0.0:
			_settling.erase(id)
	# Depth drift.
	for node in fish_container_pond.get_children():
		var id := str(node.name)
		if _leaving.has(id) or _settling.has(id) or not ("fish_res" in node) or node.fish_res == null:
			continue
		_drift_timers[id] = _drift_timers.get(id, randf_range(drift_every.x, drift_every.y)) - delta
		if _drift_timers[id] <= 0.0:
			_drift_timers[id] = randf_range(drift_every.x, drift_every.y)
			_change_depth(node)
	# Rotation.
	_rotate_timer -= delta
	if _rotate_timer <= 0.0:
		_rotate_timer = rotate_every
		_rotate_once()


func _rotate_once() -> void:
	if _hidden.is_empty():
		return
	if _visible_count() >= max_visible:
		var out := _pick_sinker()
		if out == null:
			return
		_sink(out, fade_seconds)
	_show(_hidden.pop_front(), true)


## One level up or down (whichever is possible; random when both are).
func _change_depth(node: Node) -> void:
	if depth_levels < 2:
		return
	var f: fish_conf = node.fish_res
	var step := -1 if randf() < 0.5 else 1
	if f.depth + step < 0 or f.depth + step >= depth_levels:
		step = -step
	f.depth = clampi(f.depth + step, 0, depth_levels - 1)
	_size_fish(node, depth_change_seconds)


## Visible fish that aren't on their way out.
func _visible_count() -> int:
	var n := 0
	for node in fish_container_pond.get_children():
		if not _leaving.has(str(node.name)):
			n += 1
	return n


## The fish that has been up longest and may sink (not settling, entering,
## or followed by the close-up), or null.
func _pick_sinker() -> Node:
	var best: Node = null
	var best_since := INF
	for node in fish_container_pond.get_children():
		var id := str(node.name)
		if _leaving.has(id) or _settling.has(id):
			continue
		var steering := node.get_node_or_null("FishSteering")
		if steering and steering.is_entering():
			continue
		if keep_visible.is_valid() and keep_visible.call(node):
			continue
		var since: float = _shown_since.get(id, 0.0)
		if since < best_since:
			best_since = since
			best = node
	return best


## Puts `fish` in the water. `rise`: fade in from the deep (else appear as is).
func _show(fish: fish_conf, rise: bool) -> Node:
	_display.display_all([fish], fish_container_pond)
	var node := fish_container_pond.get_node_or_null(fish.ID)
	if node == null:
		return null
	if fish.swim_heading == Vector2.ZERO and _swim_area:
		node.position = fish_container_pond.to_local(_swim_area.get_random_interior_point())
	_came_up(node)
	_size_fish(node, 0.0)
	if rise:
		var id := fish.ID
		_fading[id] = true
		var look: Color = node.modulate
		node.modulate = Color(depth_tint, 0.0)
		var t := node.create_tween()
		t.tween_property(node, "modulate", look, fade_seconds)
		t.finished.connect(func(): _fading.erase(id))
	return node


func _came_up(node: Node) -> void:
	var id := str(node.name)
	_shown_since[id] = _clock
	_drift_timers[id] = randf_range(drift_every.x, drift_every.y)


## Fades `node` out into the deep, then frees it and puts its fish at the
## back of the line.
func _sink(node: Node, seconds: float) -> void:
	var id := str(node.name)
	_leaving[id] = true
	_fading[id] = true
	node.z_index = -depth_levels   # behind everyone while it goes
	if node.has_method("set_size_factor") and "size_factor" in node:
		node.set_size_factor(node.size_factor * 0.7, seconds)
	var t := node.create_tween()
	t.tween_property(node, "modulate", Color(depth_tint, 0.0), seconds)
	t.finished.connect(func():
		if not _leaving.has(id):
			return   # surfaced again meanwhile
		var fish: fish_conf = node.fish_res
		_forget(id)
		node.queue_free()
		if fish and fish in SaveManager.load_saved_data().list_of_retired_fish:
			_hidden.append(fish))


func _forget(id: String) -> void:
	_leaving.erase(id)
	_fading.erase(id)
	_settling.erase(id)
	_drift_timers.erase(id)
	_shown_since.erase(id)
