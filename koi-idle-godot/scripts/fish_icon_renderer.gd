# fish_icon_renderer.gd
# Still pictures of fish for lists: each fish is drawn once, sideways
# (facing right), in a small hidden viewport, and the picture is kept (one
# per fish and pixel density) so lists can show hundreds of fish without each
# row running a live fish. Ask with request(fish, density, callback); the
# picture arrives a few frames later. Up to BATCH fish are drawn at once, in
# a column of cells, and cut apart afterwards.
#
# Pictures match the pond's pixel art: `density` is how many picture pixels
# a fish gets per pond pixel (1 = a fresh fish; bigger fish in the pond get
# up to ~2 before they switch to chunkier pixels, see Pond.icon_density()).
# Show the picture scaled up by a whole number with nearest filtering and it
# looks like the fish in the pond. Pictures are cropped to the fish.
class_name FishIconRenderer
extends Node

## Drawing cell per fish, in picture pixels: room for a fish drawn at
## density up to MAX_DENSITY with its fins and nose (cropped afterwards).
const PICTURE_SIZE := Vector2i(120, 56)
const MAX_DENSITY := 3.0
## Fish drawn per frame.
const BATCH := 8

static var _cache := {}   # "ID@density" -> Texture2D

var _queue: Array = []    # [fish, density, callback(Texture2D)]
var _busy := false
var _viewport: SubViewport
var _camera: Camera2D
var _factory := FishFactory.new()


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PICTURE_SIZE.x, PICTURE_SIZE.y * BATCH)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera2D.new()
	_viewport.add_child(_camera)


## The picture of `fish` at `density`, handed to `done(texture)` (now if
## it's drawn already, else a few frames later).
func request(fish: fish_conf, density: float, done: Callable) -> void:
	if fish == null:
		return
	density = snappedf(clampf(density, 0.5, MAX_DENSITY), 0.05)
	var key := _key(fish, density)
	if _cache.has(key):
		done.call(_cache[key])
		return
	_queue.append([fish, density, done])
	if not _busy:
		_run()


static func _key(fish: fish_conf, density: float) -> String:
	return "%s@%.2f" % [fish.ID, density]


func _run() -> void:
	_busy = true
	while not _queue.is_empty() and is_inside_tree():
		# Next batch: pictures not drawn yet (one each, however many ask).
		var batch: Array = []   # [fish, density]
		var keys: Array = []
		for job in _queue:
			var k := _key(job[0], job[1])
			if not _cache.has(k) and k not in keys:
				batch.append([job[0], job[1]])
				keys.append(k)
				if batch.size() == BATCH:
					break
		if not batch.is_empty():
			await _draw(batch)
		# Hand out every picture that's ready.
		var waiting: Array = []
		for job in _queue:
			var k := _key(job[0], job[1])
			if _cache.has(k):
				if job[2].is_valid():
					job[2].call(_cache[k])
			else:
				waiting.append(job)
		_queue = waiting
	_busy = false


## Draws up to BATCH fish in one frame, one per cell down the viewport.
func _draw(batch: Array) -> void:
	var nodes: Array = []
	for i in batch.size():
		var node = _factory.build(batch[i][0])
		node.get_node("FishSteering").lock_heading = true
		node.get_node("FishSteering").locked_direction = Vector2.RIGHT
		node.set_size_factor(batch[i][1], 0.0)
		_viewport.add_child(node)
		# Centre the body in its cell.
		var cell_center := Vector2(PICTURE_SIZE.x * 0.5, PICTURE_SIZE.y * (i + 0.5))
		node.position += cell_center - node.body_center_global()
		nodes.append(node)
	# Body patterns are generated in the background: wait for them.
	for i in 60:
		var ready := true
		for node in nodes:
			var tex = node.get_node("%FishBody").texture
			if tex is NoiseTexture2D and tex.get_image() == null:
				ready = false
		if ready:
			break
		await get_tree().process_frame
	for node in nodes:
		node.set_process(false)   # hold the pose
	_camera.position = Vector2(_viewport.size) * 0.5
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	for i in batch.size():
		var cell := img.get_region(Rect2i(0, PICTURE_SIZE.y * i, PICTURE_SIZE.x, PICTURE_SIZE.y))
		# Crop to the fish, one clear pixel around it.
		var used := cell.get_used_rect()
		if used.size.x > 0:
			cell = cell.get_region(used.grow(1).intersection(Rect2i(Vector2i.ZERO, cell.get_size())))
		_cache[_key(batch[i][0], batch[i][1])] = ImageTexture.create_from_image(cell)
	for node in nodes:
		node.queue_free()
