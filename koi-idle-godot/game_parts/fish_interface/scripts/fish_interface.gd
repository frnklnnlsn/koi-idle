extends Control

@onready var fish_card_hbox: HBoxContainer = %fish_card_hbox
@onready var distribution_graph = %bellcurve
var fish_card = preload("res://game_parts/fish_interface/scenes/fish_card.tscn")
var fish_for_card = preload("res://game_parts/fish_interface/scenes/fish_for_card.tscn")
var number_of_fish = 1
var rank = 0

func _ready() -> void:
	FishGenerator.new_fish.connect(populate_fish_cards)










###  fish card stuff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
func for_hovered_card(fish_res:fish_conf):
	# Get the fish resource from the card
   # Adjust based on how you store the fish data
	
	# Send the fish value to the graph
	if fish_res and distribution_graph:
		distribution_graph.set_fish_value(fish_res.value)  # Adjust property name as needed

# Also add a function for when hovering stops (if you have an unhovered signal)
#func for_unhovered_card():
	#if graph:
		#graph.clear_fish_value()
	#
	#pass



func populate_fish_cards(new_fish_array: Array):
	for fish in new_fish_array:
		var new_fish_card = fish_card.instantiate()
		
		# Connect the signal right after instantiation
		new_fish_card.fish_resource = fish
		new_fish_card.hovered.connect(for_hovered_card)
		
		# Use your architecture pattern
		setup_fish_in_card(new_fish_card, fish)
		
		fish_card_hbox.add_child(new_fish_card)
		await get_tree().create_timer(0.01).timeout




func setup_fish_in_card(card: Control, fish_data):
	# Instantiate the fish scene
	var fish_scene = fish_for_card.instantiate()
	
	# Get the viewport (using one of the methods we discussed)
	var viewport = card.get_node("%FishViewport") as SubViewport  # or however you access it
	# Apply your modification pattern
	var line_body = fish_scene.get_node("%body")  # or whatever the path is
	
	# Force duplicate resources if needed
	if line_body.texture:
		line_body.texture = line_body.texture.duplicate(true)
		if line_body.texture.color_ramp:
			line_body.texture.color_ramp = line_body.texture.color_ramp.duplicate(true)
		if line_body.texture.noise:
			line_body.texture.noise = line_body.texture.noise.duplicate(true)
	
	# Create and add your modifier script
	var modifier_script = preload("res://game_parts/fish_interface/scripts/modifiers/fish_card_modifier.gd")
	var modifier_instance = modifier_script.new()
	line_body.add_child(modifier_instance)
	modifier_instance.modify_parent(fish_data)
	
	# Add to viewport
	viewport.add_child(fish_scene)
















### signal connections~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

func _on_qnty_line_text_submitted(new_text: String) -> void:
	number_of_fish = int(new_text)
	print(number_of_fish)
	pass # Replace with function body.


func _on_class_button_item_selected(index: int) -> void:
	rank = index
	pass # Replace with function body.


func _on_button_pressed() -> void:
	FishGenerator.generate_fish(number_of_fish,rank)
	pass # Replace with function body.
