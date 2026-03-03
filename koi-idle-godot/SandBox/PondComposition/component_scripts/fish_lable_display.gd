class_name FishLabelDisplay
extends Node

var fish_name_label
var fish_rank_label
var fish_cost_label
var fish_income_label
var sell_value_label

func _init(name_l, rank_l, cost_l, income_l, sell_l):
	fish_name_label   = name_l
	fish_rank_label   = rank_l
	fish_cost_label   = cost_l
	fish_income_label = income_l
	sell_value_label  = sell_l

func show(fish: fish_conf):
	fish_name_label.text   = str(fish.ID)
	fish_rank_label.text   = str(fish.rank)
	fish_cost_label.text   = str(fish.cost)
	fish_income_label.text = str(fish.income)
	sell_value_label.text  = str(fish.value)
