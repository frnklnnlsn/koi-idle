# ui_slide.gd
# Little UI animations.
#   UiSlide.up_from_bottom(control)   the control rises into place from below
#                                     the screen (e.g. a panel's charts when
#                                     it opens). Works inside containers: the
#                                     offset is re-applied every frame, so a
#                                     re-layout mid-way can't snap it.
class_name UiSlide
extends RefCounted


static func up_from_bottom(node: Control, seconds := 0.4) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	# Let the container place it first, so we know where it ends up.
	await node.get_tree().process_frame
	if not is_instance_valid(node):
		return
	var base := node.position.y
	var dist := maxf(node.get_viewport_rect().size.y - node.global_position.y, 0.0)
	node.position.y = base + dist
	node.modulate.a = 1.0
	var t := node.create_tween()
	t.tween_method(_set_y.bind(node, base, dist), 1.0, 0.0, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _set_y(k: float, node: Control, base: float, dist: float) -> void:
	if is_instance_valid(node):
		node.position.y = base + dist * k
