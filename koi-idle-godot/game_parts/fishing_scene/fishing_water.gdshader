// fishing_water.gdshader
// Background of the fishing scene: the pond's surface seen from above, with
// the light net drifting over it, a little darker towards the bottom edge.
shader_type canvas_item;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.07, 0.20, 0.30, 1.0);
uniform vec4 far_color : source_color = vec4(0.03, 0.09, 0.17, 1.0);
uniform vec4 light_color : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float light_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float light_scale : hint_range(10.0, 600.0, 1.0) = 140.0;
uniform float light_speed : hint_range(0.0, 3.0, 0.05) = 0.3;
uniform float light_width : hint_range(0.01, 0.5, 0.01) = 0.1;

void fragment() {
	vec3 col = mix(water_color.rgb, far_color.rgb, clamp(UV.y * 0.8, 0.0, 1.0));
	float l = water_light(FRAGCOORD.xy, light_scale, TIME * light_speed, light_width);
	col += light_color.rgb * smoothstep(0.4, 1.0, l) * light_strength;
	COLOR = vec4(col, 1.0);
}
