// water_light_layer.gdshader
// The pond's WaterLight layer: the light-ripple pattern on the water behind
// the fish (same pattern as on the fish, water_light.gdshaderinc). Put on a
// ColorRect covering the water; its position in the pond sets where the light
// falls, so the pattern lines up with the light on the fish.
shader_type canvas_item;
render_mode blend_add;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"

uniform float light_strength : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform vec4 light_color : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float light_scale : hint_range(10.0, 400.0, 1.0) = 90.0;
uniform float light_speed : hint_range(0.0, 3.0, 0.05) = 0.5;
uniform float light_width : hint_range(0.01, 0.5, 0.01) = 0.12;
uniform float light_hardness : hint_range(0.0, 1.0, 0.05) = 0.5;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float light = water_light_shaped(world_pos, light_scale, TIME * light_speed, light_width, light_hardness);
	COLOR = vec4(light_color.rgb * light * light_strength, 1.0);
}
