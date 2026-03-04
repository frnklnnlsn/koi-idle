class_name FishViewportRenderer
extends Node

var fish_scene = preload("res://game_parts/user_interface/scenes/fish_for_card.tscn")
var modifier_script = preload("res://game_parts/user_interface/scripts/modifiers/fish_card_modifier.gd")

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
	var line_body = scene.get_node("%body")
	_duplicate_texture(line_body)
	var modifier = modifier_script.new()
	line_body.add_child(modifier)
	modifier.modify_parent(fish)
	viewport.add_child(scene)

func _duplicate_texture(line_body):
	if not line_body.texture:
		return
	line_body.texture = line_body.texture.duplicate(true)
	if line_body.texture.color_ramp:
		line_body.texture.color_ramp = line_body.texture.color_ramp.duplicate(true)
	if line_body.texture.noise:
		line_body.texture.noise = line_body.texture.noise.duplicate(true)
