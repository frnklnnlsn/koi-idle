extends Node

@onready var income: float
@onready var net_worth: float = 1000000

func update_income(fish_array:Array):
	for fish in fish_array:
		var fish_instance:fish_conf = fish
		income += fish_instance.income
		net_worth -= fish_instance.cost
		pass
	print("income: " + str(income))
	print("net_worth: " + str(net_worth))
	pass
