# SaveManager.gd
# Owns the one SaveData for the running game.
#
# The save lives in memory: load_saved_data() hands everyone the same object,
# so reading it is free (FishHandler checks it every frame) and every system
# sees the same fish. save_current_data() writes it to disk. Writes go to a
# temporary file first and are then swapped in, so a crash or power cut mid
# write can't leave a half-written save behind.
extends Node

## Emitted after the save is wiped and every system has reloaded from it.
signal save_reset

const SAVE_PATH := "user://savegame.tres"
const TEMP_PATH := "user://savegame.tmp.tres"
const TIMESTAMP_PATH := "user://timestamp.cfg"
const STARTING_COINS := 500.0

var _data: SaveData


func _ready() -> void:
	if DevSettings.RESET_SAVE_ON_LAUNCH:
		reset_save_data(STARTING_COINS, false)
	else:
		_data = _read_from_disk()
		if _data == null:
			_data = _fresh(STARTING_COINS)
			save_current_data(_data)
			save_timestamp()


## The live save. Change it, then call save_current_data() to keep the change.
func load_saved_data() -> SaveData:
	if _data == null:
		_data = _read_from_disk()
		if _data == null:
			_data = _fresh(STARTING_COINS)
	return _data


## Write the save to disk. Passing a different SaveData replaces the live one.
func save_current_data(save_data: SaveData = null) -> void:
	if save_data != null:
		_data = save_data
	if _data == null:
		return
	var err := ResourceSaver.save(_data, TEMP_PATH)
	if err != OK:
		push_error("SaveManager: could not write save (%s)" % error_string(err))
		return
	var dir := DirAccess.open("user://")
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())


func save_timestamp() -> void:
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.WRITE)
	if file:
		file.store_double(Time.get_unix_time_from_system())
		file.close()


## Pretend the game was last saved `seconds_ago` seconds ago (dev tools).
func backdate_timestamp(seconds_ago: float) -> void:
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.WRITE)
	if file:
		file.store_double(Time.get_unix_time_from_system() - seconds_ago)
		file.close()


func load_timestamp() -> float:
	if not FileAccess.file_exists(TIMESTAMP_PATH):
		return 0.0
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.READ)
	if file:
		var ts := file.get_double()
		file.close()
		return ts
	return 0.0


## Wipe the save and reload every system from the fresh one. When the game is
## running, the current scene is reloaded so all views start clean.
func reset_save_data(starting_net_worth: float = STARTING_COINS, reload_scene: bool = true) -> void:
	_data = _fresh(starting_net_worth)
	save_current_data(_data)
	save_timestamp()
	PassiveSystems.reload()
	FishHandler.list_of_shop_fish = _data.list_of_shop_fish
	DisplayManager.is_flushing = false
	save_reset.emit()
	if reload_scene and get_tree().current_scene != null:
		reload_scene_once()


var _reload_queued := false

## Reload the current scene at the end of the frame, once, however many
## systems ask for it in the same frame (two reloads at once crash Godot).
func reload_scene_once() -> void:
	if _reload_queued:
		return
	_reload_queued = true
	_do_reload.call_deferred()


func _do_reload() -> void:
	_reload_queued = false
	get_tree().reload_current_scene()


func _fresh(starting_net_worth: float) -> SaveData:
	var save_data := SaveData.new()
	save_data.net_worth = starting_net_worth
	save_data.income = 0.0
	save_data.list_of_work_fish = []
	save_data.list_of_shop_fish = []
	save_data.list_of_retired_fish = []
	return save_data


func _read_from_disk() -> SaveData:
	# Fall back to the temp file if a write was interrupted between steps.
	for path in [SAVE_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			var save_data := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
			if save_data != null:
				return _upgrade(save_data)
	return null


## Bring older saves up to the current layout.
func _upgrade(save_data: SaveData) -> SaveData:
	# Version 1 is the first versioned layout; saves from before it load as-is.
	save_data.save_version = SaveData.CURRENT_VERSION
	return save_data
