# vim_keys.gd
# Turns keystrokes into commands, vim style (a small, culled set). Pure logic:
# feed it key names, it returns a command when one is complete. The command
# line (command_line.gd) owns one of these and shows pending input.
#
# Normal keys ([n] = optional count, typed first, e.g. 5l):
#   [n]h / [n]l   move the cursor left / right (arrow keys too)
#   0 / $         first / last fish
#   [n]yy         keep n fish, starting at the cursor
#   [n]dd         recycle n fish, starting at the cursor
#   y$ / d$       keep / recycle from the cursor to the end
#   [n]b          buy n fish of the current rank
#   B             fill the pool (buy as many as fit and you can afford)
#   [ / ]         previous / next rank
#   .             repeat the last keep / recycle / buy
#   :             command line (see parse_ex)
#   Esc           cancel what you've typed (with nothing typed: close the
#                 open panel, see CommandLine.global_keys)
#   s             open / close the shop (handled by the command line, works
#                 everywhere; see CommandLine.global_keys)
#   v             switch between the toilet and the pond view (same)
class_name VimKeys
extends RefCounted

var _count := ""
var _op := ""


## What's been typed towards an unfinished command, e.g. "3d".
func pending() -> String:
	return _count + _op


func reset() -> void:
	_count = ""
	_op = ""


## Feed one key. Returns a command dictionary when a command is complete,
## or {} while waiting for more keys. Every command has "cmd".
func feed(key: String) -> Dictionary:
	if key == "escape":
		reset()
		return {"cmd": "cancel"}
	# Digits build a count ("0" alone means "first fish").
	if key.length() == 1 and key >= "0" and key <= "9" and not (key == "0" and _count == ""):
		_count += key
		return {}
	var n := int(_count) if _count != "" else 1

	if _op != "":
		var verb := "keep" if _op == "y" else "recycle"
		var op := _op
		reset()
		if key == op:
			return {"cmd": verb, "count": n}
		if key == "$":
			return {"cmd": verb, "to_end": true}
		return {"cmd": "unknown", "keys": op + key}

	match key:
		"h", "left":
			reset()
			return {"cmd": "move", "by": -n}
		"l", "right":
			reset()
			return {"cmd": "move", "by": n}
		"0", "^", "home":
			reset()
			return {"cmd": "first"}
		"$", "end":
			reset()
			return {"cmd": "last"}
		"y", "d":
			_op = key
			return {}
		"b":
			reset()
			return {"cmd": "buy", "count": n}
		"B":
			reset()
			return {"cmd": "fill"}
		"[":
			reset()
			return {"cmd": "rank", "by": -1}
		"]":
			reset()
			return {"cmd": "rank", "by": 1}
		".":
			reset()
			return {"cmd": "repeat"}
		":":
			reset()
			return {"cmd": "ex"}
	var typed := _count + key
	reset()
	return {"cmd": "unknown", "keys": typed}


## Command-line commands (typed after ":"). Fish numbers are the ones shown on
## the cards, starting at 1.
##   3,7d  / 3,7y      recycle / keep fish 3 to 7
##   4d    / 4y        recycle / keep fish 4
##   %d    / %y        recycle / keep every fish
##   b 5   / buy 5     buy 5 fish
##   B     / fill      fill the pool
##   rank 2            switch to rank 2
static func parse_ex(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {"cmd": "cancel"}
	var re := RegEx.new()
	re.compile("^(\\d+)\\s*(?:,\\s*(\\d+))?\\s*([dy])$")
	var m := re.search(t)
	if m:
		var a := int(m.get_string(1))
		var b := int(m.get_string(2)) if m.get_string(2) != "" else a
		return {"cmd": "keep" if m.get_string(3) == "y" else "recycle", "from": mini(a, b), "to": maxi(a, b)}
	if t == "%d" or t == "%y":
		return {"cmd": "keep" if t == "%y" else "recycle", "all": true}
	re.compile("^(?:b|buy)\\s*(\\d*)$")
	m = re.search(t)
	if m:
		return {"cmd": "buy", "count": int(m.get_string(1)) if m.get_string(1) != "" else 1}
	if t == "B" or t == "fill":
		return {"cmd": "fill"}
	re.compile("^rank\\s+(\\d+)$")
	m = re.search(t)
	if m:
		return {"cmd": "rank", "to": int(m.get_string(1))}
	return {"cmd": "error", "text": "Not a command: " + t}


## The key name for an event: the typed character for printable keys
## ("h", "$", ":", "B"), otherwise a lowercase name ("escape", "left").
static func key_name(event: InputEventKey) -> String:
	if event.unicode > 31:
		return char(event.unicode)
	match event.keycode:
		KEY_ESCAPE: return "escape"
		KEY_LEFT: return "left"
		KEY_RIGHT: return "right"
		KEY_HOME: return "home"
		KEY_END: return "end"
		KEY_ENTER, KEY_KP_ENTER: return "enter"
	return ""
