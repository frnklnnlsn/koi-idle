# command_line.gd
# The keyboard command bar along the bottom of the screen, vim style.
#
#   left    what you've typed so far ("3d"), or the ":" command line
#   middle  the result of the last command ("Kept 3 fish")
#   right   the active screen's status (rank, pool, toilet)
#
# Keys go to whichever screen `target_provider` returns (the shop while it's
# open). That screen implements:
#   run_command(cmd: Dictionary) -> String   do it, return a message
#   command_status() -> String               short status for the right side
# See VimKeys for the key list.
class_name CommandLine
extends PanelContainer

## Commands "." can repeat.
const REPEATABLE := ["keep", "recycle", "buy", "fill"]

## Returns the node keys should go to, or null when nothing takes keys.
var target_provider: Callable

var _keys := VimKeys.new()
var _last: Dictionary = {}
var _prompt: Label
var _ex: LineEdit
var _message: Label
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_prompt = _label(Color(1.0, 0.85, 0.3))
	_prompt.custom_minimum_size.x = 40
	row.add_child(_prompt)
	_ex = LineEdit.new()
	_ex.visible = false
	_ex.custom_minimum_size.x = 180
	_ex.flat = true
	_ex.placeholder_text = "3,7d   %y   b 5   rank 2"
	_ex.text_submitted.connect(_on_ex_submitted)
	_ex.gui_input.connect(_on_ex_input)
	row.add_child(_ex)
	_message = _label(Color(0.85, 0.88, 0.95))
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.clip_text = true
	row.add_child(_message)
	_status = _label(Color(0.6, 0.65, 0.75))
	row.add_child(_status)


func _process(_delta: float) -> void:
	var target = _target()
	_status.text = target.command_status() if target else "open the shop to use keys"


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	# Holding a key only repeats movement.
	if k.echo and k.keycode not in [KEY_H, KEY_L, KEY_LEFT, KEY_RIGHT]:
		return
	var target = _target()
	if target == null:
		return
	var key := VimKeys.key_name(k)
	if key == "" or key == "enter":
		return
	get_viewport().set_input_as_handled()
	var cmd := _keys.feed(key)
	_prompt.text = _keys.pending()
	if cmd.is_empty():
		return
	_run(cmd)


func _run(cmd: Dictionary) -> void:
	var target = _target()
	match cmd["cmd"]:
		"cancel":
			_prompt.text = ""
			return
		"ex":
			_open_ex()
			return
		"unknown":
			_say("Unknown keys: " + cmd.get("keys", ""))
			return
		"error":
			_say(cmd["text"])
			return
		"repeat":
			if _last.is_empty():
				_say("Nothing to repeat yet")
				return
			cmd = _last
	if target == null:
		return
	if cmd["cmd"] in REPEATABLE:
		_last = cmd
	_say(target.run_command(cmd))


func _open_ex() -> void:
	_prompt.text = ":"
	_ex.text = ""
	_ex.visible = true
	_ex.grab_focus()


func _close_ex() -> void:
	_ex.visible = false
	_ex.release_focus()
	_prompt.text = ""


func _on_ex_submitted(text: String) -> void:
	_close_ex()
	_run(VimKeys.parse_ex(text))


func _on_ex_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_ex()
		_ex.accept_event()


func _say(text: String) -> void:
	_message.text = text


func _target():
	if not target_provider.is_valid():
		return null
	var t = target_provider.call()
	return t if t and t.is_visible_in_tree() else null


func _label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 14)
	return l
