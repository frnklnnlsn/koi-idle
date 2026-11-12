# iris_transition.gd
# A circle wipe for cut scenes: the screen goes black outside a circle that
# closes in on a point, then opens again from another point.
#   await iris.close_on(screen_pos, seconds)
#   await iris.open_on(screen_pos, seconds)
# While it's covering anything it blocks clicks. Colour and pixel size are on
# the material (iris_transition.tscn).
class_name IrisTransition
extends ColorRect

var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


## Closes to nothing around `at` (screen position).
func close_on(at: Vector2, seconds := 0.6) -> void:
	_start(at, _cover_radius(at), 0.0)
	_tween.tween_method(_set_radius, _cover_radius(at), 0.0, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _tween.finished


## Opens from nothing around `at` until the whole screen shows, then hides.
func open_on(at: Vector2, seconds := 0.8) -> void:
	_start(at, 0.0, _cover_radius(at))
	_tween.tween_method(_set_radius, 0.0, _cover_radius(at), seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _tween.finished
	visible = false


func _start(at: Vector2, from: float, _to: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = true
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("center", at - global_position)
	_set_radius(from)
	_tween = create_tween()


func _set_radius(r: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("radius", r)


## Big enough to uncover the whole screen from `at`.
func _cover_radius(at: Vector2) -> float:
	var p := at - global_position
	var far := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		far = maxf(far, p.distance_to(corner))
	return far + 8.0
