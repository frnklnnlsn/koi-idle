extends SubViewport


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func display_fish(what_fish, where_fish):
	var save_data = SaveManager.load_saved_data()
	for fish in save_data.list_of_work_fish:
		
		new_generate_fish(fish)
		pass
	pass




func new_generate_fish(fish_res):
	var scene = preload("res://game_parts/fish_gallery/scenes/procedural_fish.tscn").instantiate()
	var line_body = scene.get_node("body")
	
	# Force duplicate the texture and its sub-resources BEFORE modifying
	if line_body.texture:
		line_body.texture = line_body.texture.duplicate(true)
		if line_body.texture.color_ramp:
			line_body.texture.color_ramp = line_body.texture.color_ramp.duplicate(true)
		if line_body.texture.noise:
			line_body.texture.noise = line_body.texture.noise.duplicate(true)
	
	var script = preload("res://game_parts/fish_gallery/scripts/procedural_body.gd")
	var instance = script.new()
	line_body.add_child(instance)
	instance.modify_parent(fish_res)
	self.add_child(scene)
	
func remove_shop_fish(remove_shop_fish:Array) -> void:
	if remove_shop_fish:
		print("this is the list of fish to remove from the shop list:" + str(remove_shop_fish))
		var save_data = SaveManager.load_saved_data() 
		
		for fish_to_remove in remove_shop_fish:
			print("this is the save data before remove: " + str(save_data.list_of_shop_fish))
			print("looking for fish with ID: " + fish_to_remove.ID)
			
			# Find the index by comparing fish IDs
			var found_index = -1
			for i in range(save_data.list_of_shop_fish.size()):
				var shop_fish = save_data.list_of_shop_fish[i]
				if shop_fish.ID == fish_to_remove.ID:
					found_index = i
					break
			
			if found_index != -1:
				save_data.list_of_shop_fish.remove_at(found_index)
				print("removed fish with ID: " + fish_to_remove.ID + " at index: " + str(found_index))
			else:
				print("fish with ID: " + fish_to_remove.ID + " not found in shop list")
				
			print("this is the save data after remove: " + str(save_data.list_of_shop_fish))
		
		print("final list of shop fish: " + str(save_data.list_of_shop_fish))
		SaveManager.save_current_data(save_data)
