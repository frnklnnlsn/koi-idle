# save_manager.gd
extends Node

const SAVE_PATH := "user://savegame.tres"

func _ready() -> void:
	# Ensure a save file exists on first launch
	make_player_save()

func load_saved_data() -> SaveData:
	var save_data := ResourceLoader.load(SAVE_PATH) as SaveData
	if save_data != null:
		return save_data
	push_warning("SaveManager: No save file found, returning empty SaveData.")
	return SaveData.new()  # never returns null

func make_player_save() -> void:
	# Only creates a new save if one doesn't already exist
	if not FileAccess.file_exists(SAVE_PATH):
		var save_data := SaveData.new()
		ResourceSaver.save(save_data, SAVE_PATH)

func save_current_data(save_data: SaveData) -> void:
	ResourceSaver.save(save_data, SAVE_PATH)

func reset_save_data() -> void:
	var save_data := SaveData.new()
	ResourceSaver.save(save_data, SAVE_PATH)
