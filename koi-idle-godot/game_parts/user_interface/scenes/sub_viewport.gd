class_name Pond extends SubViewport


func _ready():
	var factory = FishFactory.new()
	var display = FishDisplay.new(factory)
	var save_data = SaveManager.load_saved_data()
	display.display_all(save_data.list_of_work_fish, self)
