#FishHandler.gd
extends Node
#var list_of_work_fish:Array 
#var lsit_of_retired_fish:Array
var list_of_shop_fish:Array
## Toilet capacity before Tuning (levels / skills change it).
var base_capacity: int = 20
## Toilet capacity: most fish you can keep earning at once.
var capacity: int:
	get: return Tuning.apply_int(Tuning.TOILET_CAPACITY, base_capacity, 1)
var total_fish:int

signal keep_fish(list)

func _ready() -> void:
	var save_data :SaveData= SaveManager.load_saved_data()
	if save_data == null:
		push_error("Could not load save data in " + name)
		return
	list_of_shop_fish = save_data.list_of_shop_fish
	FishGenerator.new_fish.connect(save_shop_fish)

func _process(delta)->void:
	calculate_total_fish()

func calculate_total_fish():
	var save_data = SaveManager.load_saved_data()
	var list_shop_size = save_data.list_of_shop_fish.size()
	var list_work_size = save_data.list_of_work_fish.size()
	total_fish = list_shop_size + list_work_size

## Fish kept in the toilet right now.
func work_count() -> int:
	return SaveManager.load_saved_data().list_of_work_fish.size()


## Free toilet slots (how many more fish can be kept).
func toilet_space() -> int:
	return maxi(capacity - work_count(), 0)


## Free slots in the shop's buy pool (rank table: shop_pool_size).
func pool_space() -> int:
	return maxi(Ranks.pool_size() - SaveManager.load_saved_data().list_of_shop_fish.size(), 0)


### takes an array of fish_res, (can search through for same res)
func save_shop_fish(list_of_shop_fish:Array)-> void:
	if list_of_shop_fish:
		var save_data = SaveManager.load_saved_data() 
		save_data.list_of_shop_fish.append_array(list_of_shop_fish)
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
		SaveManager.save_current_data(save_data) 

func remove_work_fish(remove_work_fish:Array)->void:
	if remove_work_fish:
		var save_data = SaveManager.load_saved_data() 
		
		for fish in remove_work_fish:
			var index = save_data.list_of_work_fish.find(fish)
			if index != -1:
				save_data.list_of_work_fish.remove_at(index)
		
		SaveManager.save_current_data(save_data)

## What selling every toilet fish would pay: each fish's price minus the
## rank table's recycle fee (the same as recycling it in the shop).
func toilet_sale_value() -> float:
	var total := 0.0
	for fish in SaveManager.load_saved_data().list_of_work_fish:
		if fish is fish_conf:
			total += PassiveSystems.recycle_refund(fish)
	return total


## Sells every fish in the toilet (:sellall). Returns how many and the money.
func sell_all_work_fish() -> Dictionary:
	var save_data: SaveData = SaveManager.load_saved_data()
	var count := save_data.list_of_work_fish.size()
	if count == 0:
		return {"count": 0, "paid": 0.0}
	var paid := toilet_sale_value()
	save_data.list_of_work_fish.clear()
	PassiveSystems.net_worth += paid
	PassiveSystems.reset_income()   # no fish left earning; also saves
	DisplayManager.toilet_cleared.emit()
	return {"count": count, "paid": paid}


func flush_to_retired(fish_list: Array) -> void:
	var save_data: SaveData = SaveManager.load_saved_data()  # <-- missing this
	if not save_data:
		push_error("Could not load save data in flush_to_retired")
		return
	for fish in fish_list:
		FishGrowthManager.enter_pond(fish)
		save_data.list_of_retired_fish.append(fish)
	SaveManager.save_current_data(save_data)
