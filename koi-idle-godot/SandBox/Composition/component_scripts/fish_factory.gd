class_name FishFactory
extends Node

const FISH_SCENE = preload("res://game_parts/FishComposition/scenes/ProceduralFish2.tscn")

func build(fish_res) -> Node:
	var scene = FISH_SCENE.instantiate()
	scene.fish_res = fish_res
	var line_body = scene.get_node("%FishBody")
	# One shared pattern texture per fish (made once, reused everywhere).
	line_body.texture = FishPatternCache.texture_for(fish_res, line_body.texture)
	scene.add_to_group("fish")  # tag it
	return scene
