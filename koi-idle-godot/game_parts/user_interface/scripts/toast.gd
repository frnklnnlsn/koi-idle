# toast.gd
# A short message that fades in at the bottom of the screen and fades away
# after a few seconds ("Kept 3 fish", "Skill point earned..."). A new message
# replaces the one showing. Look and position: toast.tscn.
class_name Toast
extends PanelContainer

## Seconds a message stays (plus a little per letter, up to max_seconds).
@export var seconds := 2.5
@export var max_seconds := 6.0
@export var fade_seconds := 0.35

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


func say(text: String) -> void:
	if text.strip_edges() == "":
		return
	%Text.text = text
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var stay := minf(seconds + text.length() * 0.03, max_seconds)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_seconds * (1.0 - modulate.a))
	_tween.tween_interval(stay)
	_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(func(): visible = false)
