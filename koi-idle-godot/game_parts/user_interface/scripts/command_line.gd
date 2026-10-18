# command_line.gd
# The keyboard terminal along the bottom of the screen, vim style.
# Layout and style live in command_line.tscn; resize or restyle it there (or
# on the CommandLine node in main_UI). The main layout stops above it.
#
#   Info     details of the fish under the cursor, laid out in `Info.columns`
#            columns (set it on the Info node; 2 = two lines per column)
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

## Keys that work everywhere, even with no screen taking keys: key name ->
## Callable (e.g. "s" opens / closes the shop, "escape" closes the open
## panel). Checked first, but only when nothing is half typed, so Esc still
## cancels a pending "3d" before it closes anything.
var global_keys := {}

## Size of the fish info lines (colour: the palette's text).
@export var info_font_size := 14

var _keys := VimKeys.new()
var _last: Dictionary = {}
## A y / n question is waiting (e.g. :sellall): called with true on y.
var _confirm: Callable
@onready var _info: GridContainer = %Info
@onready var _prompt: Label = %Prompt
@onready var _ex: LineEdit = %Ex
@onready var _message: Label = %Message
@onready var _status: Label = %Status


func _ready() -> void:
	_ex.text_submitted.connect(_on_ex_submitted)
	_ex.gui_input.connect(_on_ex_input)


func _process(_delta: float) -> void:
	var target = _target()
	_status.text = target.command_status() if target \
		else "toilet %d/%d · S opens the shop" % [FishHandler.work_count(), FishHandler.capacity]
	_set_info(target.command_info() if target and target.has_method("command_info") else "")


## One label per line of info, flowing across the Info grid's columns.
func _set_info(text: String) -> void:
	var lines := text.split("\n", false)
	while _info.get_child_count() < lines.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", info_font_size)
		l.add_theme_color_override("font_color", UIPalette.get_palette().text)
		_info.add_child(l)
	for i in _info.get_child_count():
		var l: Label = _info.get_child(i)
		l.visible = i < lines.size()
		if l.visible:
			l.text = lines[i]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	# Holding a key only repeats movement.
	if k.echo and k.keycode not in [KEY_H, KEY_L, KEY_LEFT, KEY_RIGHT]:
		return
	var key := VimKeys.key_name(k)
	# A y / n question takes the next key, whatever it is.
	if _confirm.is_valid() and key != "":
		get_viewport().set_input_as_handled()
		var answer := _confirm
		_confirm = Callable()
		_prompt.text = ""
		answer.call(key == "y")
		return
	# Only when nothing is half typed, so "3s" style input can't misfire.
	if key in global_keys and _keys.pending() == "" and not k.echo:
		get_viewport().set_input_as_handled()
		global_keys[key].call()
		return
	var target = _target()
	# ":" opens the command line on any screen (some commands, like
	# :sellall, don't need the shop); other keys only drive the shop.
	if target == null and not (key == ":" and _keys.pending() == ""):
		return
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
		"sellall":
			_sell_all(cmd.get("confirmed", false))
			return
	if target == null:
		_say("Open the shop first (s)")
		return
	if cmd["cmd"] in REPEATABLE:
		_last = cmd
	_say(target.run_command(cmd))


## :sellall: sells every toilet fish, after a y / n unless confirmed.
func _sell_all(confirmed: bool) -> void:
	var count := FishHandler.work_count()
	if count == 0:
		_say("No fish in the toilet to sell")
		return
	var value := FishHandler.toilet_sale_value()
	if not confirmed:
		_say("Sell %d toilet fish for $%s?  y / n" % [count, FishLabelDisplay.num(value)])
		_prompt.text = "y/n"
		_confirm = func(yes: bool):
			if yes:
				_sell_all(true)
			else:
				_say("Kept your toilet fish")
		return
	var sold := FishHandler.sell_all_work_fish()
	_say("Sold %d toilet fish for $%s" % [sold["count"], FishLabelDisplay.num(sold["paid"])])


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


## Show a message from outside the keys (mouse buttons, card drags).
func say(text: String) -> void:
	if text != "":
		_say(text)


func _target():
	if not target_provider.is_valid():
		return null
	var t = target_provider.call()
	return t if t and t.is_visible_in_tree() else null
