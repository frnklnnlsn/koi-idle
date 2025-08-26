extends Control

@onready var net_worth_label = %net_worth
@onready var capacity_label = %capacity


func _process(delta)->void:
	# for now put the capacity calc in process
	
	
	
	var total_fish = FishHandler.total_fish
	capacity_label.text ="capacity: " + str(total_fish) + "/100"
	
	
	var net_worth = Economy.net_worth
	net_worth_label.text ="$: " + str(net_worth)
	
	
