extends Node
# Applies a fish's body pattern to the parent Line2D's (own, duplicated) noise
# texture. The game itself now uses FishPatternCache, which shares one texture
# per fish; this stays for scenes that still build their own copy.

func modify_parent(fish_data):
	var parent = self.get_parent()
	if parent.texture is NoiseTexture2D:
		FishPatternCache.apply_pattern(parent.texture, fish_data)
