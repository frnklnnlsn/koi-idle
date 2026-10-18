# fish_pattern_cache.gd
# One body-pattern texture per fish, shared by every place that draws it.
#
# A fish's pattern (its noise texture) depends only on its data: colours,
# offsets, noise type, seed and frequency. Generating it is the slow part of
# making a fish, so instead of each shop card, toilet fish and pond fish
# building its own copy, they all ask this cache:
#
#   body.texture = FishPatternCache.texture_for(fish, body.texture)
#
# The first call for a fish makes the texture (from the scene's texture as a
# template, so its size and look settings still come from the scene); later
# calls, e.g. when the fish moves from the shop to the toilet to the pond,
# return the same one at no cost.
class_name FishPatternCache
extends RefCounted

## Texture width the fish frequencies were designed for. The noise is sampled
## once per pixel, so a smaller texture sees a smaller patch of the pattern;
## frequency and domain warp are scaled by REFERENCE_SIZE / width to keep the
## same look at any size.
const REFERENCE_SIZE := 512.0
## Domain warp (the swirl) at REFERENCE_SIZE, FastNoiseLite's defaults.
const REFERENCE_WARP_AMPLITUDE := 30.0
const REFERENCE_WARP_FREQUENCY := 0.05
## Most patterns kept. When full, the oldest is dropped (a fish that comes
## back later just gets its pattern made again).
const MAX_ENTRIES := 400

static var _cache := {}   # key -> Texture2D, oldest first


## The pattern texture for `fish`, made from `template` the first time.
## Returns the template unchanged if it isn't a noise texture.
static func texture_for(fish: fish_conf, template: Texture2D) -> Texture2D:
	var noise_tex := template as NoiseTexture2D
	if fish == null or noise_tex == null:
		return template
	var key := "%s|%dx%d" % [fish.ID, noise_tex.width, noise_tex.height]
	if _cache.has(key):
		return _cache[key]
	var tex: NoiseTexture2D = noise_tex.duplicate()
	if tex.color_ramp:
		tex.color_ramp = tex.color_ramp.duplicate()
	if tex.noise:
		tex.noise = tex.noise.duplicate()
	apply_pattern(tex, fish)
	if fish.ID == "":
		return tex   # no ID to share it by
	_cache[key] = tex
	if _cache.size() > MAX_ENTRIES:
		_cache.erase(_cache.keys()[0])
	return tex


## Writes a fish's pattern settings into a noise texture (one it owns).
static func apply_pattern(tex: NoiseTexture2D, fish) -> void:
	if tex.color_ramp:
		tex.color_ramp.colors = fish.colors
		tex.color_ramp.offsets = fish.offsets
	if tex.noise:
		var scale := REFERENCE_SIZE / maxf(tex.width, 1.0)
		tex.noise.noise_type = fish.noise_type_index
		tex.noise.seed = fish.seed
		tex.noise.frequency = fish.frequency * scale
		tex.noise.domain_warp_amplitude = REFERENCE_WARP_AMPLITUDE / scale
		tex.noise.domain_warp_frequency = REFERENCE_WARP_FREQUENCY * scale


## How many patterns are cached (for the dev tools / tests).
static func size() -> int:
	return _cache.size()


static func clear() -> void:
	_cache.clear()
