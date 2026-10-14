class_name FishDisplay
extends Node

var factory: FishFactory

## The factory is optional so the scene can also hold this script as a plain
## node (main_UI does); code creates working ones with FishDisplay.new(factory).
func _init(fish_factory: FishFactory = null):
	factory = fish_factory

func display_all(fish_list: Array, container: Node):
	for fish in fish_list:
		var fish_node = factory.build(fish)
		fish_node.name = fish.ID
		container.add_child(fish_node)
