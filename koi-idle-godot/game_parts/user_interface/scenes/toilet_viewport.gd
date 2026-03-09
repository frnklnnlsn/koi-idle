#class_name Toilet 
extends SubViewport

var _display: FishDisplay
@onready var fish_container_toilet: Node2D = %FishContainerToilet

func _ready() -> void:
	DisplayManager.display_fish_toilet.connect(Display)
	DisplayManager.flush_fish.connect(Clear)

	var factory = FishFactory.new()
	_display = FishDisplay.new(factory)

	var save_data = SaveManager.load_saved_data()
	if save_data == null:
		push_warning("No save data found.")
		return

	_display.display_all(save_data.list_of_work_fish, fish_container_toilet)

func Display(list):
	if _display == null:
		return
	_display.display_all(list, fish_container_toilet)  # pass container not self

func Clear():
	for child in fish_container_toilet.get_children():
		if child.is_in_group("fish"):  # only remove fish, not other children
			child.queue_free()
