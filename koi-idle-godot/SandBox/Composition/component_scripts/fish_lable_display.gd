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
	if fish_name_label:   fish_name_label.text   = str(fish.ID)
	if fish_rank_label:   fish_rank_label.text   = str(fish.rank)
	if fish_cost_label:   fish_cost_label.text   = str(fish.cost)
	if fish_income_label: fish_income_label.text = str(fish.income)
	if sell_value_label:  sell_value_label.text  = str(fish.value)
