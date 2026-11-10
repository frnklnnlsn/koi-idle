# fish_icon_renderer.gd
# Still pictures of fish for lists: each fish is drawn once, sideways
# (facing right), in a small hidden viewport, and the picture is kept (one
# per fish ID) so lists can show hundreds of fish without each row running a
# live fish. Ask with request(fish, texture_rect); the picture arrives a few
# frames later. Up to BATCH fish are drawn at once, in a column of cells,
# and cut apart afterwards.
class_name FishIconRenderer
extends Node

## Size the fish is drawn at (pictures are scaled down in the list, so a
## bigger render stays crisp for big fish).
const RENDER_SCALE := 4.0
## Picture size in pixels (fits a fish at RENDER_SCALE with its fins).
const PICTURE_SIZE := Vector2i(128, 56)
## Fish drawn per frame.
const BATCH := 8

static var _cache := {}   # fish ID -> Texture2D

var _queue: Array = []    # [fish, TextureRect]
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


## The picture for `fish` into `target` (now if it's drawn already).
func request(fish: fish_conf, target: TextureRect) -> void:
	if fish == null or target == null:
		return
	if _cache.has(fish.ID):
		target.texture = _cache[fish.ID]
		return
	_queue.append([fish, target])
	if not _busy:
		_run()


## A drawn picture, or null if this fish hasn't been drawn yet.
static func cached(fish: fish_conf) -> Texture2D:
	return _cache.get(fish.ID) if fish else null


func _run() -> void:
	_busy = true
	while not _queue.is_empty() and is_inside_tree():
		# Next batch: fish not drawn yet (one each, however many rows want it).
		var batch: Array = []
		for job in _queue:
			var f: fish_conf = job[0]
			if not _cache.has(f.ID) and f not in batch:
				batch.append(f)
				if batch.size() == BATCH:
					break
		if not batch.is_empty():
			await _draw(batch)
		# Hand out every picture that's ready.
		var waiting: Array = []
		for job in _queue:
			if _cache.has(job[0].ID):
				if is_instance_valid(job[1]):
					job[1].texture = _cache[job[0].ID]
			else:
				waiting.append(job)
		_queue = waiting
	_busy = false


## Draws up to BATCH fish in one frame, one per cell down the viewport.
func _draw(batch: Array) -> void:
	var nodes: Array = []
	for i in batch.size():
		var node = _factory.build(batch[i])
		node.get_node("FishSteering").lock_heading = true
		node.get_node("FishSteering").locked_direction = Vector2.RIGHT
		node.set_size_factor(RENDER_SCALE, 0.0)
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
		_cache[batch[i].ID] = ImageTexture.create_from_image(cell)
	for node in nodes:
		node.queue_free()
