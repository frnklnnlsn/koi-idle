class_name Pond extends SubViewport


var _display: FishDisplay  # class-level variable

func _ready() -> void:
	DisplayManager.display_new_fish.connect(Display)
	
	var factory = FishFactory.new()
	_display = FishDisplay.new(factory)  # assign to class variable
	
	var save_data = SaveManager.load_saved_data()
	if save_data == null:
		push_warning("No save data found.")
		return
	
	_display.display_all(save_data.list_of_work_fish, self)

func Display(list):
	if _display == null:
		push_warning("Display called before FishDisplay was initialized.")
		return
	_display.display_all(list, self)
