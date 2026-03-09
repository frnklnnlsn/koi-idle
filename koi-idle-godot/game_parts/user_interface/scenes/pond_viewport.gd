class_name Pond extends SubViewport

var _display: FishDisplay
@onready var fish_container_pond: Node2D = %FishContainerPond

func _ready() -> void:
	DisplayManager.display_fish_pond.connect(Display)
	DisplayManager.fish_caught.connect(_on_fish_caught)  # add this
	var factory = FishFactory.new()
	_display = FishDisplay.new(factory)
	var save_data = SaveManager.load_saved_data()
	if save_data == null:
		push_warning("No save data found.")
		return
	_display.display_all(save_data.list_of_retired_fish, fish_container_pond)

func Display(list):
	if _display == null:
		return
	var existing_ids = []
	for child in fish_container_pond.get_children():
		existing_ids.append(child.name)

	print("Existing pond IDs: ", existing_ids)  # Are these actually fish IDs or default names?

	var new_fish = list.filter(func(f): return f.ID not in existing_ids)
	print("New fish to spawn: ", new_fish.size())
	if new_fish.is_empty():
		return
	_display.display_all(new_fish, fish_container_pond)

func _on_fish_caught(fish_list: Array) -> void:
	for fish in fish_list:
		var node = fish_container_pond.get_node_or_null(fish.ID)
		if node:
			node.queue_free()
