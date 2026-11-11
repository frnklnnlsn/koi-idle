# ui_slide.gd
# Little UI animations.
#   UiSlide.up_from_bottom(control)   the control rises into place from below
#                                     the screen (e.g. a panel's charts when
#                                     it opens).
# Inside a container, the container decides where the control belongs and
# may move it while the panel settles; the slide re-reads that spot every
# time the container lays out, and lets it lay out once more at the end, so
# the control always lands exactly where the layout puts it.
class_name UiSlide
extends RefCounted


static func up_from_bottom(node: Control, seconds := 0.4) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	# Let the panel settle first.
	await node.get_tree().process_frame
	if not is_instance_valid(node):
		return
	var state := {"k": 1.0, "base": node.position.y,
		"dist": maxf(node.get_viewport_rect().size.y - node.global_position.y, 0.0)}
	var parent := node.get_parent() as Container
	var on_sort := _after_sort.bind(node, state)
	if parent:
		parent.sort_children.connect(on_sort)
	_apply(1.0, node, state)
	node.modulate.a = 1.0
	var t := node.create_tween()
	t.tween_method(_apply.bind(node, state), 1.0, 0.0, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_finish.bind(node, parent, on_sort))


## The container just put the node where it belongs: remember that spot and
## put the slide offset back on.
static func _after_sort(node: Control, state: Dictionary) -> void:
	if is_instance_valid(node):
		state["base"] = node.position.y
		node.position.y = state["base"] + state["dist"] * state["k"]


static func _apply(k: float, node: Control, state: Dictionary) -> void:
	state["k"] = k
	if is_instance_valid(node):
		node.position.y = state["base"] + state["dist"] * k


static func _finish(node: Control, parent: Container, on_sort: Callable) -> void:
	if parent and is_instance_valid(parent):
		if parent.sort_children.is_connected(on_sort):
			parent.sort_children.disconnect(on_sort)
		parent.queue_sort()   # back exactly where the layout wants it
