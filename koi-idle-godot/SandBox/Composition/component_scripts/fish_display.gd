class_name FishDisplay
extends Node

var factory: FishFactory

## The factory is optional so the scene can also hold this script as a plain
## node (main_UI does); code creates working ones with FishDisplay.new(factory).
func _init(fish_factory: FishFactory = null):
	factory = fish_factory

## Adds a swimming fish for each entry. Fish with a saved place (see
## fish_conf.swim_position) start there, facing the way they were going;
## the rest start at the container's origin. Every fish keeps its place
## up to date so it can come back to it next time.
func display_all(fish_list: Array, container: Node):
	for fish in fish_list:
		var fish_node = factory.build(fish)
		fish_node.name = fish.ID
		if "remember_position" in fish_node:
			fish_node.remember_position = true
			if fish is fish_conf and fish.swim_heading != Vector2.ZERO:
				fish_node.position = fish.swim_position
				fish_node.start_heading = fish.swim_heading
		container.add_child(fish_node)
