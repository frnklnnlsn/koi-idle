class_name FishCardManager
extends Node

signal cards_changed

var hbox: HBoxContainer
var card_scene = preload("res://game_parts/user_interface/scenes/fish_card.tscn")
var card_placement_index := 0
var temp_fish_array: Array = []

func _init(card_hbox: HBoxContainer):
	hbox = card_hbox

func add_card(fish: fish_conf, renderer: FishViewportRenderer) -> Control:
	var card = card_scene.instantiate()
	card.fish_resource = fish
	temp_fish_array.append(fish)
	renderer.setup_fish_in_card(card, fish)
	_add_with_center_positioning(card)
	return card

func remove_cards(fish_list: Array):
	for fish in fish_list:
		temp_fish_array.erase(fish)
		for child in hbox.get_children():
			if child.fish_resource == fish:
				child.queue_free()
	cards_changed.emit()

func clear_all():
	temp_fish_array.clear()
	card_placement_index = 0
	for child in hbox.get_children():
		child.queue_free()
	cards_changed.emit()

func _add_with_center_positioning(card: Control):
	var total = hbox.get_child_count()
	if total == 0:
		hbox.add_child(card)
	else:
		var center = total / 2
		var place_right = (card_placement_index % 2 == 0)
		var pos = center + 1 + (card_placement_index / 2) if place_right \
				  else max(0, center - ((card_placement_index + 1) / 2))
		hbox.add_child(card)
		hbox.move_child(card, min(pos, total))
	card_placement_index += 1
