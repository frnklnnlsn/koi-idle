class_name FishFactory
extends Node

const FISH_SCENE = preload("res://game_parts/fish_gallery/scenes/procedural_fish.tscn")
const BODY_SCRIPT = preload("res://game_parts/fish_gallery/scripts/procedural_body.gd")

func build(fish_res) -> Node:
	var scene = FISH_SCENE.instantiate()
	var line_body = scene.get_node("body")
	_duplicate_texture(line_body)
	var instance = BODY_SCRIPT.new()
	line_body.add_child(instance)
	instance.modify_parent(fish_res)
	return scene

func _duplicate_texture(line_body):
	if not line_body.texture:
		return
	line_body.texture = line_body.texture.duplicate(true)
	if line_body.texture.color_ramp:
		line_body.texture.color_ramp = line_body.texture.color_ramp.duplicate(true)
	if line_body.texture.noise:
		line_body.texture.noise = line_body.texture.noise.duplicate(true)
