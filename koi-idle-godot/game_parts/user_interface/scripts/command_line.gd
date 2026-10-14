# command_line.gd
# The keyboard terminal along the bottom of the screen, vim style.
# Layout and style live in command_line.tscn; resize or restyle it there (or
# on the CommandLine node in main_UI). The main layout stops above it.
#
#   Info     details of the fish under the cursor (several lines)
#   Prompt   what you've typed so far ("3d"), or ":" for the command line
#   Message  the result of the last command ("Kept 3 fish")
#   Status   the active screen's status (rank, pool, toilet)
#
# Keys go to whichever screen `target_provider` returns (the shop while it's
# open). That screen implements:
#   run_command(cmd: Dictionary) -> String   do it, return a message
#   command_status() -> String               short status for the right side
#   command_info() -> String                 text for the Info area
# See VimKeys for the key list.
class_name CommandLine
extends PanelContainer

## Commands "." can repeat.
const REPEATABLE := ["keep", "recycle", "buy", "fill"]

## Returns the node keys should go to, or null when nothing takes keys.
var target_provider: Callable

var _keys := VimKeys.new()
var _last: Dictionary = {}
@onready var _info: Label = %Info
@onready var _prompt: Label = %Prompt
@onready var _ex: LineEdit = %Ex
@onready var _message: Label = %Message
@onready var _status: Label = %Status


func _ready() -> void:
	_ex.text_submitted.connect(_on_ex_submitted)
	_ex.gui_input.connect(_on_ex_input)


func _process(_delta: float) -> void:
	var target = _target()
	_status.text = target.command_status() if target else "open the shop to use keys"
	_info.text = target.command_info() if target and target.has_method("command_info") else ""


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
