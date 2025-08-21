extends Node

var save_path := "user://savegame.tres"

func _ready() -> void:
	#var save_data := ResourceLoader.load(save_path)
	#save_data = SaveData.new()
	#save_current_data(save_data)
	make_player_save()

func load_saved_data() -> SaveData:
	var save_data := ResourceLoader.load(save_path)
	if save_data != null:
		print("Loaded save from:", ProjectSettings.globalize_path(save_path))
		return save_data
	else:
		print("❌ Failed to load save file.")
		return null

func make_player_save():
	var save_data := ResourceLoader.load(save_path)
	if save_data == null:
		save_data = SaveData.new()



	# Save to disk
	var error = ResourceSaver.save(save_data,save_path)
	print("Saving to:", ProjectSettings.globalize_path(save_path))
	print("Save result code:", error)  # 0 = OK

func save_current_data(save_data: SaveData):
	var error = ResourceSaver.save(save_data, save_path)
	print("Save result code:", error)
