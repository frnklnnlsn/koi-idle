# SaveManager.gd
extends Node

const SAVE_PATH := "user://savegame.tres"
const TIMESTAMP_PATH := "user://timestamp.cfg"

func _ready() -> void:
	reset_save_data() 
	make_player_save()

func make_player_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		var save_data := SaveData.new()
		save_data.net_worth = 10.0  # starting coins
		ResourceSaver.save(save_data, SAVE_PATH)
		save_timestamp()
		print("CREATED FRESH SAVE")

func load_saved_data() -> SaveData:
	var save_data := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if save_data != null:
		return save_data
	return SaveData.new()

func save_current_data(save_data: SaveData) -> void:
	ResourceSaver.save(save_data, SAVE_PATH)

func save_timestamp() -> void:
	var ts := Time.get_unix_time_from_system()
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.WRITE)
	if file:
		file.store_double(ts)  # double instead of float
		file.close()
		print("TIMESTAMP SAVED: ", ts)


func load_timestamp() -> float:
	if not FileAccess.file_exists(TIMESTAMP_PATH):
		print("NO TIMESTAMP FILE FOUND")
		return 0.0
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.READ)
	if file:
		var ts := file.get_double()  # double instead of float
		file.close()
		print("TIMESTAMP LOADED: ", ts)
		return ts
	return 0.0

func reset_save_data(starting_net_worth: float = 10.0) -> void:
	var save_data := SaveData.new()
	save_data.net_worth = starting_net_worth
	save_data.income = 0.0
	save_data.list_of_work_fish = []
	save_data.list_of_shop_fish = []
	save_data.list_of_retired_fish = []
	ResourceSaver.save(save_data, SAVE_PATH)
	save_timestamp()
	PassiveSystems.reload()
