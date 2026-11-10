// boss_water.gdshader
// Background of the boss cut scene: deep water, lighter towards the surface,
// with the pond's light net drifting over it (stronger near the top).
// `depth` (0..1) fades the whole thing darker; the cut scene animates it.
shader_type canvas_item;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"

uniform vec4 surface_color : source_color = vec4(0.10, 0.26, 0.36, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.03, 0.08, 1.0);
uniform vec4 light_color : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float light_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float light_scale : hint_range(10.0, 600.0, 1.0) = 220.0;
uniform float light_speed : hint_range(0.0, 3.0, 0.05) = 0.35;
uniform float light_width : hint_range(0.01, 0.5, 0.01) = 0.12;
// 0 = bright surface water, 1 = all deep (the scene starts deep).
uniform float depth : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	float y = UV.y;
	vec3 col = mix(surface_color.rgb, deep_color.rgb, clamp(y * 1.1 + depth * 0.6, 0.0, 1.0));
	vec2 p = FRAGCOORD.xy;
	float l = water_light(p, light_scale, TIME * light_speed, light_width);
	float fade = (1.0 - y) * (1.0 - y) * (1.0 - depth);
	col += light_color.rgb * smoothstep(0.4, 1.0, l) * light_strength * fade;
	COLOR = vec4(col, 1.0);
}
