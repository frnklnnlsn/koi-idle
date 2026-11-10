# pond_pixel_layers.gd
# Keeps pond fish looking like pixel art at every size: bigger fish are drawn
# with bigger pixels, the way a pixel-art sprite scaled up would look.
#
# The pond itself is drawn at low resolution and blown up (the container's
# stretch_shrink), which pixelates everything by the same amount. A fish that
# has grown 4× would look 4× smoother than a new one. So each fish is put in
# a size group (Pond.pixel_step / max_pixel_scale) and every group gets its own view of the
# same water at a lower resolution:
#
#   group 1 (normal size)   pond resolution        (pixels 1×)
#   group 2                 half the resolution    (pixels 2×)
#   group 3                 a third                (pixels 3×)
#   group 4                 a quarter              (pixels 4×)
#
# The views share the pond's world (like the fish close-up window) and only
# draw their own group, using Godot's visibility layers:
#
#   layer 1       the pond's own view: floor and everything under the fish
#   layers 2–5    fish of group 1–4 (Pond sets each fish's layer)
#   layer 6       things above the fish (WaterSurface sparkles, anything with
#                 z_index above the fish); drawn last, at pond resolution
#
# Bigger groups are drawn on top of smaller ones (bigger fish look closer).
class_name PondPixelLayers
extends Control

## Layer bit for things drawn above the fish.
const ABOVE_FISH_BIT := 1 << 5

## The pond's view (PondViewportContainer).
@export var source: SubViewportContainer

var _views: Array[SubViewport] = []


## Layer bit for fish of size group `group` (0 = normal size).
static func fish_bit(group: int) -> int:
	return 1 << (1 + group)


## Every fish layer together, for the nodes holding fish.
static func all_fish_bits(groups: int) -> int:
	var bits := 0
	for g in groups:
		bits |= fish_bit(g)
	return bits


## Puts `node` and everything drawn under it on `bits`. A canvas item only
## shows in a view if it and all its parents share a layer with the view.
static func set_layers(node: Node, bits: int) -> void:
	if node is CanvasItem:
		node.visibility_layer = bits
	for c in node.get_children():
		set_layers(c, bits)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if source == null:
		push_warning("PondPixelLayers: no source set")
		return
	var pond: SubViewport = source.get_child(0)
	var groups: int = pond.max_pixel_scale if "max_pixel_scale" in pond else 1
	# The pond's own view keeps everything except the fish and what's above.
	pond.canvas_cull_mask = 1
	# Things above the fish (surface sparkles...) go to their own layer.
	for c in pond.get_children():
		if c is CanvasItem and c.z_index > Layers.FISH:
			set_layers(c, ABOVE_FISH_BIT)
	# Fish containers must share every fish layer (parents filter children).
	var holder: Node = pond.get_node_or_null("%FishContainerPond")
	if holder is CanvasItem:
		holder.visibility_layer = 1 | all_fish_bits(groups)
	for g in groups:
		_add_view(pond, fish_bit(g), g + 1)
	_add_view(pond, ABOVE_FISH_BIT, 1)
	source.visibility_changed.connect(_follow_source)
	_follow_source()


## One stretched view of the pond's world showing only `mask`, with pixels
## `pixel` × the pond's.
func _add_view(pond: SubViewport, mask: int, pixel: int) -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = source.stretch_shrink * pixel
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.handle_input_locally = false
	vp.world_2d = pond.world_2d
	vp.canvas_cull_mask = mask
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	box.add_child(vp)
	# Same part of the pond as the pond's camera, at 1/pixel the resolution.
	var cam := Camera2D.new()
	var pond_cam := pond.get_camera_2d()
	if pond_cam:
		cam.position = pond_cam.global_position
	cam.zoom = Vector2.ONE / pixel
	vp.add_child(cam)
	_views.append(vp)


func _follow_source() -> void:
	visible = source.visible
