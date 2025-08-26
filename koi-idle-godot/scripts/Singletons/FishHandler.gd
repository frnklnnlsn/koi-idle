extends Node
#var list_of_work_fish:Array 
#var lsit_of_retired_fish:Array
#var list_of_shop_fish:Array
var capacity = 100
var total_fish:int



func _ready()->void:
	FishGenerator.new_fish.connect(save_shop_fish)


func _process(delta)->void:
	calculate_total_fish()

func calculate_total_fish():
	var save_data = SaveManager.load_saved_data()
	var list_shop_size = save_data.list_of_shop_fish.size()
	var list_work_size = save_data.list_of_work_fish.size()
	total_fish = list_shop_size + list_work_size

### takes an array of fish_res, (can search through for same res)
func save_shop_fish(list_of_shop_fish:Array)-> void:
	if list_of_shop_fish:
		var save_data = SaveManager.load_saved_data() 
		save_data.list_of_shop_fish.append_array(list_of_shop_fish)
		print("list of shop fish: " + str(save_data.list_of_shop_fish))
		SaveManager.save_current_data(save_data) 

### takes an array of fish to remove from the list of shop fish, will be passed when sell, sell all
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

func save_work_fish(list_of_work_fish:Array)-> void:
	if list_of_work_fish:
		var save_data = SaveManager.load_saved_data() #should return the save data resource
		save_data.list_of_work_fish.append_array(list_of_work_fish)
		print("list of work fish: " + str(save_data.list_of_work_fish))
		SaveManager.save_current_data(save_data) 

func remove_work_fish(remove_work_fish:Array)->void:
	if remove_work_fish:
		var save_data = SaveManager.load_saved_data() 
		
		for fish in remove_work_fish:
			var index = save_data.list_of_work_fish.find(fish)
			if index != -1:
				save_data.list_of_work_fish.remove_at(index)
		
		SaveManager.save_current_data(save_data)
