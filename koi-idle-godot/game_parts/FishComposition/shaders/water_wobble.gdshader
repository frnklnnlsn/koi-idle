// water_wobble.gdshader
// Refraction wobble for fish seen through water. Pushes the fish's outline
// back and forth with a slow-moving wave pattern that is fixed in the pond
// (world space), not to the fish: fish swimming through it waver like things
// under a moving surface, and neighbouring fish waver together.
//
// Also draws light ripples (caustics) on the fish, from the same pond-fixed
// pattern as the pond's WaterLight layer, so fish swim through patches of
// light. Deeper fish are tinted darker by the pond, which dims it too.
//
// Used on FishBody and Skeleton (fins) of pond and toilet fish, through
// water_wobble_material.tres (FishDisplay assigns it). Edit the numbers there.
shader_type canvas_item;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"

// How far an edge moves, in pond pixels. Keep it small: 0.5 - 1.5.
uniform float amplitude : hint_range(0.0, 4.0, 0.05) = 0.8;
// Size of the ripples, in pond pixels. Around the size of a fish looks best.
uniform float wavelength : hint_range(4.0, 200.0, 1.0) = 36.0;
// How fast the ripples drift.
uniform float speed : hint_range(0.0, 5.0, 0.05) = 0.9;
// Second, crossing ripple pattern, as a share of the first (0 = one pattern).
uniform float cross_ripple : hint_range(0.0, 1.0, 0.05) = 0.6;

group_uniforms light_ripples;
// How bright the light on the fish is (0 = off).
uniform float light_strength : hint_range(0.0, 2.0, 0.05) = 0.45;
uniform vec4 light_color : source_color = vec4(1.0, 0.97, 0.85, 1.0);
// Size of the light cells, in pond pixels.
uniform float light_scale : hint_range(10.0, 400.0, 1.0) = 90.0;
uniform float light_speed : hint_range(0.0, 3.0, 0.05) = 0.5;
// Thickness of the light lines, as a share of a cell.
uniform float light_width : hint_range(0.01, 0.5, 0.01) = 0.12;
// 0 = soft glow, 1 = crisp pixel bands.
uniform float light_hardness : hint_range(0.0, 1.0, 0.05) = 0.5;
group_uniforms;

varying vec2 world_pos;

void vertex() {
	// Where this vertex is in the pond (fish nodes aren't rotated or scaled).
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	world_pos = world;
	float k = 6.2831853 / wavelength;
	float t = TIME * speed;
	vec2 offset;
	offset.x = sin(world.y * k + t) + cross_ripple * sin((world.x + world.y) * k * 0.7 - t * 1.3);
	offset.y = cos(world.x * k * 0.9 + t * 1.1) + cross_ripple * cos((world.x - world.y) * k * 0.6 + t * 0.8);
	VERTEX += offset * amplitude / (1.0 + cross_ripple);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float light = water_light_shaped(world_pos, light_scale, TIME * light_speed, light_width, light_hardness);
	base.rgb += light_color.rgb * light * light_strength * base.a;
	COLOR = base;
}
