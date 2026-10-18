class_name FishViewportRenderer
extends Node

var fish_scene = preload("res://game_parts/FishComposition/scenes/ProceduralFishCard.tscn")

func setup_fish_in_card(card: Control, fish: fish_conf):
	var viewport = card.get_node("%FishViewport") as SubViewport
	_place_fish(viewport, fish)

func place_fish_in_viewport(viewport: SubViewport, fish: fish_conf):
	clear_viewport(viewport)
	_place_fish(viewport, fish)

func clear_viewport(viewport: SubViewport):
	for child in viewport.get_children():
		child.queue_free()

func _place_fish(viewport: SubViewport, fish: fish_conf):
	var scene = fish_scene.instantiate()
	scene.fish_res = fish   # lets the skeleton pick up fin_color
	var line_body = scene.get_node("FishBody")
	# Same shared pattern texture the toilet and pond use for this fish.
	line_body.texture = FishPatternCache.texture_for(fish, line_body.texture)
	viewport.add_child(scene)
