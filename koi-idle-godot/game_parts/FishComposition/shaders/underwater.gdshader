// underwater.gdshader
// For sprites under the water (the toilet bowl's bottom, rocks, plants...).
// The fish shader bends the fish's outline, but a sprite is a plain
// rectangle, so this one bends the picture inside it instead: each pixel
// reads the texture a little to the side, by the same pond-fixed ripple the
// fish use, so the bed and the fish waver together. It also adds the same
// light ripples and can tint the water.
//
// Put the material on an "Underwater" Node2D and tick Use Parent Material on
// each sprite under it. With the swim area filled in (the toilet / pond
// script does it), the effect stays inside the water: porcelain or banks
// outside the area stay crisp.
shader_type canvas_item;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"
#include "res://game_parts/FishComposition/shaders/water_area.gdshaderinc"

group_uniforms wobble;
// Same meaning as on the fish (water_wobble_material.tres); keep them equal.
uniform float amplitude : hint_range(0.0, 4.0, 0.05) = 0.8;
uniform float wavelength : hint_range(4.0, 200.0, 1.0) = 36.0;
uniform float speed : hint_range(0.0, 5.0, 0.05) = 0.9;
uniform float cross_ripple : hint_range(0.0, 1.0, 0.05) = 0.6;

group_uniforms light_ripples;
uniform float light_strength : hint_range(0.0, 2.0, 0.05) = 0.35;
uniform vec4 light_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float light_scale : hint_range(10.0, 400.0, 1.0) = 90.0;
uniform float light_speed : hint_range(0.0, 3.0, 0.05) = 0.5;
uniform float light_width : hint_range(0.01, 0.5, 0.01) = 0.14;
uniform float band_at : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float core_at : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform sampler2D noise : repeat_enable, filter_nearest;
uniform float noise_px : hint_range(32.0, 1024.0, 1.0) = 256.0;
uniform float rippling : hint_range(0.0, 20.0, 0.5) = 4.0;

group_uniforms water;
// Colour the underwater part is multiplied by (white = no tint).
uniform vec4 water_tint : source_color = vec4(0.88, 0.94, 1.0, 1.0);
// Only bend / light / tint inside the swim area (needs the area set).
uniform bool only_in_water = true;
group_uniforms;

varying vec2 world_pos;
varying float world_scale;   // pond pixels per sprite pixel

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	world_scale = max(length(MODEL_MATRIX[0].xy), 0.0001);
}

void fragment() {
	float wet = 1.0;
	if (only_in_water) {
		wet = step(0.0, area_distance(world_pos));
	}
	// Bend: read the texture shifted by the ripple (pond pixels -> UV).
	vec2 shift = water_wobble_offset(world_pos, wavelength, speed, cross_ripple, TIME) * amplitude;
	vec2 uv = UV + shift * TEXTURE_PIXEL_SIZE / world_scale * wet;
	vec4 col = texture(TEXTURE, uv) * COLOR;
	// Light ripples, the same net as on the fish and the pond floor.
	vec2 p = water_snap(world_pos, pixel_size);
	p += water_ripple(noise, p, noise_px, rippling, TIME);
	float band = water_band(water_light(p, light_scale, TIME * light_speed, light_width), band_at, core_at);
	float glow = step(1.0, band) * 0.6 + step(2.0, band) * 0.4;
	col.rgb += light_color.rgb * glow * light_strength * col.a * wet;
	col.rgb *= mix(vec3(1.0), water_tint.rgb, wet);
	COLOR = col;
}
