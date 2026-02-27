extends Control

signal keep(fish_resource_array: Array)
signal sell(fish_resource_array: Array)

@onready var fish_card_hbox: HBoxContainer = %fish_card_hbox
@onready var distribution_graph = %bellcurve
@onready var growth_curve = %Growth_curve
@onready var histogram_graph = %Histogram
@onready var display_fish_card = %display_fish_card
@onready var fish_viewport = %FishViewport

@onready var fish_name = %fish_name
@onready var fish_rank = %fish_rank
@onready var fish_cost = %fish_cost
@onready var fish_income = %fish_income
@onready var sell_value = %"sell value"

var fish_card = preload("res://game_parts/user_interface/scenes/fish_card.tscn")
var fish_for_card = preload("res://game_parts/user_interface/scenes/fish_for_card.tscn")
var number_of_fish = 10
var rank = 0

var temp_fish_array = []
@onready var selected_fish: fish_conf

var fish_collection: Array = []
var card_placement_index = 0

func _ready() -> void:
	FishGenerator.new_fish.connect(populate_fish_cards)
	histogram_graph.bar_clicked.connect(for_bar_clicked)
	keep.connect(for_keep_fish)
	sell.connect(for_sell_fish)
	
	populate_fish_cards(FishHandler.list_of_shop_fish)

### Fish Card Management
func populate_fish_cards(new_fish_array: Array):
	fish_collection.append_array(new_fish_array)
	
	for fish in new_fish_array:
		var new_fish_card = fish_card.instantiate()
		temp_fish_array.append(fish)
		new_fish_card.fish_resource = fish
		
		# Connect signals
		new_fish_card.hovered.connect(for_hovered_card)
		new_fish_card.unhovered.connect(for_unhovered_card)
		new_fish_card.selected_deselected.connect(for_selected_deselected_fish)
		
		setup_fish_in_card(new_fish_card, fish)
		add_card_with_center_positioning(new_fish_card)
		await get_tree().create_timer(0.1).timeout
	
	await get_tree().process_frame
	if histogram_graph:
		histogram_graph.set_fish_collection(temp_fish_array)

func add_card_with_center_positioning(new_card: Control):
	var total_cards = fish_card_hbox.get_child_count()
	
	if total_cards == 0:
		fish_card_hbox.add_child(new_card)
	else:
		var center_pos = total_cards / 2
		var place_right = (card_placement_index % 2 == 0)
		var insert_position: int
		
		if place_right:
			insert_position = center_pos + 1 + (card_placement_index / 2)
		else:
			insert_position = max(0, center_pos - ((card_placement_index + 1) / 2))
		
		insert_position = min(insert_position, total_cards)
		fish_card_hbox.add_child(new_card)
		fish_card_hbox.move_child(new_card, insert_position)
	
	card_placement_index += 1

func setup_fish_in_card(card: Control, fish_data):
	var fish_scene = fish_for_card.instantiate()
	var viewport = card.get_node("%FishViewport") as SubViewport
	var line_body = fish_scene.get_node("%body")
	
	# Force duplicate resources
	if line_body.texture:
		line_body.texture = line_body.texture.duplicate(true)
		if line_body.texture.color_ramp:
			line_body.texture.color_ramp = line_body.texture.color_ramp.duplicate(true)
		if line_body.texture.noise:
			line_body.texture.noise = line_body.texture.noise.duplicate(true)
	
	var modifier_script = load("res://game_parts/user_interface/scripts/modifiers/fish_card_modifier.gd")
	var modifier_instance = modifier_script.new()
	line_body.add_child(modifier_instance)
	modifier_instance.modify_parent(fish_data)
	viewport.add_child(fish_scene)

### Signal Handlers
func for_hovered_card(fish_res: fish_conf):
	clear_viewport()
	update_graphs(fish_res)
	set_fish_label_data(fish_res)
	setup_fish_in_card(display_fish_card, fish_res)

func for_unhovered_card(fish_res: fish_conf):
	clear_viewport()
	if selected_fish != null:
		setup_fish_in_card(display_fish_card, selected_fish)

func for_bar_clicked(fish_res: fish_conf, bar_index: int):
	clear_viewport()
	selected_fish = fish_res
	for_hovered_card(fish_res)

func for_selected_deselected_fish(fish_res: fish_conf):
	if selected_fish == fish_res:
		selected_fish = null
		clear_viewport()
	else:
		selected_fish = fish_res

func for_keep_fish(list_of_fish_to_keep) -> void:
	remove_fish_cards(list_of_fish_to_keep)
	clear_viewport()
	selected_fish = null
	histogram_graph.set_fish_collection(temp_fish_array)
	histogram_graph.clear_fish_card_hover()
	FishHandler.save_work_fish(list_of_fish_to_keep)
	FishHandler.remove_shop_fish(list_of_fish_to_keep)

func for_sell_fish(list_of_fish_to_sell) -> void:
	remove_fish_cards(list_of_fish_to_sell)
	clear_viewport()
	selected_fish = null
	histogram_graph.set_fish_collection(temp_fish_array)
	histogram_graph.clear_fish_card_hover()
	Economy.for_sell_fish(list_of_fish_to_sell)
	FishHandler.remove_shop_fish(list_of_fish_to_sell)

### Helper Functions
func clear_viewport():
	for child in fish_viewport.get_children():
		child.queue_free()

func update_graphs(fish_res: fish_conf):
	if distribution_graph:
		distribution_graph.set_fish_value(fish_res.value)
	if growth_curve:
		growth_curve.set_fish_growth(fish_res)
	if histogram_graph:
		histogram_graph.set_fish_card_hover(fish_res)

func remove_fish_cards(fish_list: Array):
	var children = fish_card_hbox.get_children()
	for fish in fish_list:
		temp_fish_array.erase(fish)
		for child in children:
			if child.fish_resource == fish:
				child.queue_free()

func set_fish_label_data(fish_res: fish_conf) -> void:
	#print("=== DEBUG FISH DATA ===")
	#print("Fish resource: ", fish_res)
	#print("Fish ID: ", fish_res.ID)
	#print("Fish rank: ", fish_res.rank)
	#print("All properties: ")
	#for prop in fish_res.get_property_list():
		#if prop.name in ["ID", "rank", "cost", "income", "value"]:
			#print("  ", prop.name, ": ", fish_res.get(prop.name))
	#print("=======================")
	
	fish_name.text = str(fish_res.ID)
	fish_rank.text = str(fish_res.rank)
	fish_cost.text = str(fish_res.cost)
	fish_income.text = str(fish_res.income)
	sell_value.text = str(fish_res.value)

func clear_all_fish():
	fish_collection.clear()
	temp_fish_array.clear()
	card_placement_index = 0
	
	for child in fish_card_hbox.get_children():
		child.queue_free()
	
	if distribution_graph:
		distribution_graph.clear_fish_value()
	if growth_curve:
		growth_curve.clear_fish_growth()
	if histogram_graph:
		histogram_graph.clear_histogram()

### Button Handlers
func _on_qnty_line_text_submitted(new_text: String) -> void:
	number_of_fish = int(new_text)

func _on_class_button_item_selected(index: int) -> void:
	rank = index

func _on_button_pressed() -> void:
	FishGenerator.generate_fish(number_of_fish, rank)

func _on_keep_pressed():
	keep.emit([selected_fish])

func _on_keep_all_pressed():
	keep.emit(temp_fish_array.duplicate())

func _on_sell_pressed():
	sell.emit([selected_fish])

func _on_sell_all_pressed():
	sell.emit(temp_fish_array.duplicate())

func _on_buy_max_pressed():
	var capacity = FishHandler.capacity
	FishHandler.calculate_total_fish()
	var total_fish = FishHandler.total_fish
	var remainder = capacity - total_fish
	var fish_cost = FishGenerator.fish_cost_array[rank]
	var available_money = Economy.net_worth
	
	var max_affordable = int(available_money / fish_cost)
	var fish_to_buy = min(remainder, max_affordable)
	
	if fish_to_buy > 0:
		var total_cost = fish_to_buy * fish_cost
		FishGenerator.generate_fish(fish_to_buy, rank)
