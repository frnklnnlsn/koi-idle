extends Node

func modify_parent(fish_data):
	var parent = self.get_parent()
	
	# Apply fish data to the Line2D
	if parent.texture and parent.texture.color_ramp:
		parent.texture.color_ramp.colors = fish_data.colors
		parent.texture.color_ramp.offsets = fish_data.offsets
	
	if parent.texture and parent.texture.noise:
		parent.texture.noise.noise_type = fish_data.noise_type_index
		parent.texture.noise.seed = fish_data.seed
		parent.texture.noise.frequency = fish_data.frequency
	
	# Add any other fish card specific modifications
	# parent.width = fish_data.line_width
	# parent.modulate = fish_data.tint_color
	# etc.
