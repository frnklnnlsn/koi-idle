class_name FishDisplay
extends Node

var factory: FishFactory

func _init(fish_factory: FishFactory):
	factory = fish_factory

func display_all(fish_list: Array, container: Node):
	for fish in fish_list:
		var fish_node = factory.build(fish)
		fish_node.name = fish.ID
		container.add_child(fish_node)
