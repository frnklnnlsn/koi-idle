# Settings.gd
# Player settings (audio, display, gameplay): kept in user://settings.cfg,
# separate from the save game, so resetting progress keeps them.
#
# Each setting is one entry in SPEC. The settings menu (settings_menu.gd)
# builds its rows from SPEC, so adding a setting here adds it to the menu;
# then give it an effect in _apply().
#
#   get_value("audio/master")          read
#   set_value("audio/master", 0.5)     change, apply and save
#   changed(key, value)                emitted after a change
extends Node

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"

## Fish recycled at once before "Ask before big sells" asks.
const BIG_SELL := 5

## Choice lists (the value stored is the index into these).
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_CAPS := [30, 60, 120, 0]   # 0 = no cap
const AUTOSAVE_SECONDS := [5.0, 15.0, 30.0, 60.0]

## One entry per setting, in menu order. Tabs come from the key's first part.
##   type "slider" (0..1), "toggle" (bool), "choice" (index into "options")
const SPEC := [
	{"key": "audio/master", "label": "Master volume", "type": "slider", "default": 0.8},
	{"key": "audio/music", "label": "Music", "type": "slider", "default": 0.7},
	{"key": "audio/sfx", "label": "Sound effects", "type": "slider", "default": 0.8},
	{"key": "audio/mute", "label": "Mute all", "type": "toggle", "default": false},
	{"key": "audio/mute_in_background", "label": "Mute when the game is in the background", "type": "toggle", "default": false},

	{"key": "display/window_mode", "label": "Window", "type": "choice", "options": ["Windowed", "Fullscreen"], "default": 0},
	{"key": "display/window_size", "label": "Window size", "type": "choice", "options": ["1280 × 720", "1600 × 900", "1920 × 1080"], "default": 0},
	{"key": "display/vsync", "label": "VSync", "type": "toggle", "default": true},
	{"key": "display/fps_cap", "label": "Frame rate limit", "type": "choice", "options": ["30 fps (saves power)", "60 fps", "120 fps", "No limit"], "default": 1},
	{"key": "display/always_on_top", "label": "Keep window on top", "type": "toggle", "default": true},

	{"key": "gameplay/autosave", "label": "Autosave every", "type": "choice", "options": ["5 seconds", "15 seconds", "30 seconds", "60 seconds"], "default": 0},
	{"key": "gameplay/number_format", "label": "Big numbers", "type": "choice", "options": ["1,234,567", "1.23M", "1.23e6"], "default": 0},
	{"key": "gameplay/confirm_big_sells", "label": "Ask before big sells (:sellall, recycling %d+ fish)" % BIG_SELL, "type": "toggle", "default": true},
	{"key": "gameplay/key_hints", "label": "Show key hints in the terminal", "type": "toggle", "default": true},
]

const TAB_NAMES := {"audio": "Audio", "display": "Display", "gameplay": "Gameplay"}

var _values := {}
var _focused := true


func _ready() -> void:
	_ensure_audio_buses()
	for s in SPEC:
		_values[s["key"]] = s["default"]
	_load()
	for key in _values:
		_apply(key)


func get_value(key: String) -> Variant:
	return _values.get(key)


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	_save()
	changed.emit(key, value)


func spec_for(key: String) -> Dictionary:
	for s in SPEC:
		if s["key"] == key:
			return s
	return {}


## Everything back to its default.
func reset_to_defaults() -> void:
	for s in SPEC:
		set_value(s["key"], s["default"])


# --- Effects ----------------------------------------------------------------

func _apply(key: String) -> void:
	var v = _values[key]
	match key:
		"audio/master", "audio/mute", "audio/mute_in_background":
			_apply_master()
		"audio/music":
			_set_bus_volume("Music", v)
		"audio/sfx":
			_set_bus_volume("SFX", v)
		"display/window_mode", "display/window_size":
			_apply_window()
		"display/vsync":
			if _has_window():
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		"display/fps_cap":
			Engine.max_fps = FPS_CAPS[v]
		"display/always_on_top":
			if _has_window():
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, v)
		"gameplay/number_format":
			NumberFormat.mode = v


## Seconds between autosaves (PassiveSystems reads this).
func autosave_seconds() -> float:
	return AUTOSAVE_SECONDS[_values["gameplay/autosave"]]


func _apply_master() -> void:
	var muted: bool = _values["audio/mute"] or (_values["audio/mute_in_background"] and not _focused)
	var i := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(i, muted)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(_values["audio/master"], 0.0001)))


func _set_bus_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


## Music and SFX buses, so sounds can be sorted onto them: set a player's
## Bus to "Music" or "SFX" (AudioStreamPlayer > Bus in the Inspector).
func _ensure_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func _apply_window() -> void:
	if not _has_window():
		return
	if _values["display/window_mode"] == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = WINDOW_SIZES[_values["display/window_size"]]
	DisplayServer.window_set_size(size)
	# Centre it on its screen.
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)


## False when running headless (tests) or inside the editor's game view,
## where window changes would fight the editor.
func _has_window() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_apply_master()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_apply_master()


# --- File -------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for s in SPEC:
		var parts: PackedStringArray = s["key"].split("/")
		var v = cfg.get_value(parts[0], parts[1], s["default"])
		if typeof(v) == typeof(s["default"]) or (s["type"] == "slider" and typeof(v) in [TYPE_INT, TYPE_FLOAT]):
			if s["type"] == "choice":
				v = clampi(v, 0, s["options"].size() - 1)
			_values[s["key"]] = v


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _values:
		var parts: PackedStringArray = key.split("/")
		cfg.set_value(parts[0], parts[1], _values[key])
	cfg.save(PATH)
