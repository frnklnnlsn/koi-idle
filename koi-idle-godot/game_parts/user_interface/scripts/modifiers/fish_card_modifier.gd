extends Node

## Texture width the fish frequencies were designed for. The noise is sampled
## once per pixel, so a smaller texture sees a smaller patch of the pattern;
## frequency is scaled by REFERENCE_SIZE / width to keep the same look.
## Generating the texture is the slow part of making a fish (a 512 px one costs
## 64x a 64 px one), so fish scenes use small textures (FishBody > Texture >
## Width / Height on ProceduralFish2.tscn).
const REFERENCE_SIZE := 512.0
## Domain warp (the swirl) at REFERENCE_SIZE, FastNoiseLite's defaults. Also in
## pixels, so it's rescaled the same way.
const REFERENCE_WARP_AMPLITUDE := 30.0
const REFERENCE_WARP_FREQUENCY := 0.05

func modify_parent(fish_data):
	var parent = self.get_parent()
	
	# Apply fish data to the Line2D
	if parent.texture and parent.texture.color_ramp:
		parent.texture.color_ramp.colors = fish_data.colors
		parent.texture.color_ramp.offsets = fish_data.offsets
	
	if parent.texture and parent.texture.noise:
		parent.texture.noise.noise_type = fish_data.noise_type_index
		parent.texture.noise.seed = fish_data.seed
		var scale := REFERENCE_SIZE / maxf(parent.texture.width, 1.0)
		parent.texture.noise.frequency = fish_data.frequency * scale
		parent.texture.noise.domain_warp_amplitude = REFERENCE_WARP_AMPLITUDE / scale
		parent.texture.noise.domain_warp_frequency = REFERENCE_WARP_FREQUENCY * scale
	
	# Add any other fish card specific modifications
	# parent.width = fish_data.line_width
	# parent.modulate = fish_data.tint_color
	# etc.
