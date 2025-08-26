extends Node

@onready var income: float
@onready var net_worth: float = 10 #set it to some big right now for testing change later


func _ready()->void:
	FishGenerator.new_fish.connect(for_new_fish)


func _process(delta)->void: #save the income and networth to the savedata
	var save_data = SaveManager.load_saved_data() 
	save_data.income = income
	save_data.net_worth = net_worth
	SaveManager.save_current_data(save_data) 



func for_new_fish(fish_res_array:Array)-> void:
	if fish_res_array:
		for fish in fish_res_array:
			add_fish(fish)
	
	print("income: " + str(income))
	print("net_worth: " + str(net_worth))



func add_fish(fish_res:fish_conf)->void:
	if fish_res:
		income += fish_res.income
		net_worth -= fish_res.cost


func for_sell_fish(fish_res_array)->void:
	if fish_res_array:
		for fish in fish_res_array:
			remove_fish(fish)
	
	print("income: " + str(income))
	print("net_worth: " + str(net_worth))


func remove_fish(fish_res:fish_conf)->void:
	if fish_res:
		income -= fish_res.income
		net_worth += fish_res.cost
