// pond_water.gdshader
// Pixel-art water for the pond, a cross of our light-ripple shader and
// "2D Pixel Art Water" (godotshaders.com, CC0). Used on two ColorRects in the
// pond, with a material each (pond_water_floor.tres / pond_water_surface.tres):
//
//   Floor layer (behind the fish): the drifting net of light, rippled by a
//   noise texture, snapped to a pixel grid and drawn in two tones (light
//   band + bright core) over an optional water colour.
//
//   Surface layer (above the fish): random sparkles, plus foam pulsing along
//   the edge of the swim shape (off by default; the scripts set the shape).
//
// Positions are pond pixels, so the floor's light lines up with the light on
// the fish (water_wobble.gdshader); keep light_scale / light_speed / pixel
// settings the same in both.
shader_type canvas_item;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"
#include "res://game_parts/FishComposition/shaders/water_area.gdshaderinc"

// false = floor layer, true = surface layer.
uniform bool surface_layer = false;
// Size of one "pixel" of the effect, in pond pixels (1 = native, 2 = chunky).
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
// Draw only inside the swim area (set by the toilet / pond script).
uniform bool clip_to_area = false;

group_uniforms water;
// Fill under the light (alpha 0 = keep whatever is behind).
uniform vec4 water_color : source_color = vec4(0.05, 0.07, 0.18, 0.0);
// Seamless noise for rippling and sparkles (a NoiseTexture2D, seamless on).
uniform sampler2D noise : repeat_enable, filter_nearest;
// How many pond pixels one noise tile covers.
uniform float noise_px : hint_range(32.0, 1024.0, 1.0) = 256.0;
// How far the ripple pushes the pattern, in pond pixels.
uniform float rippling : hint_range(0.0, 20.0, 0.5) = 4.0;

group_uniforms light;
uniform vec4 light_color : source_color = vec4(0.45, 0.6, 0.95, 0.16);
uniform vec4 highlight_color : source_color = vec4(0.8, 0.9, 1.0, 0.3);
uniform float light_scale : hint_range(10.0, 400.0, 1.0) = 90.0;
uniform float light_speed : hint_range(0.0, 3.0, 0.05) = 0.5;
uniform float light_width : hint_range(0.01, 0.5, 0.01) = 0.14;
// Where the light band and the bright core start (0..1 of the light).
uniform float band_at : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float core_at : hint_range(0.0, 1.0, 0.01) = 0.7;

group_uniforms sparkles;
uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
// Higher = fewer sparkles.
uniform float sparkle_threshold : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float sparkle_scale : hint_range(1.0, 60.0, 0.5) = 20.0;
// Sparkles only where the light falls (otherwise anywhere on the water).
uniform bool sparkles_only_on_light = true;

group_uniforms foam;
uniform vec4 foam_color : source_color = vec4(0.85, 0.92, 1.0, 0.5);
// Width of the foam band along the swim area's edge, in pond pixels
// (0 = no foam, the default).
uniform float foam_width : hint_range(0.0, 40.0, 0.5) = 0.0;
group_uniforms;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Draws `src` over `dst`, both with their own alpha (see-through colours).
vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 rgb = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

void fragment() {
	vec2 p = water_snap(world_pos, pixel_size);
	float t = TIME * light_speed;
	vec2 rp = p + water_ripple(noise, p, noise_px, rippling, TIME);
	float light = water_light(rp, light_scale, t, light_width);
	float band = water_band(light, band_at, core_at);
	vec4 col = vec4(0.0);

	if (!surface_layer) {
		col = water_color;
		if (band >= 1.0) {
			col = over(col, light_color);
		}
		if (band >= 2.0) {
			col = over(col, highlight_color);
		}
	} else {
		float glint = water_sparkle(noise, p, noise_px, sparkle_scale, TIME, sparkle_threshold);
		if (sparkles_only_on_light) {
			glint *= step(1.0, band);
		}
		if (glint > 0.5) {
			col = over(col, sparkle_color);
		}
		if (foam_width > 0.0 && area_shape != 0) {
			float d = area_distance(p);
			// Foam band that breathes in and out, as in the pixel-art shader.
			float breathe = 0.55 + 0.45 * abs(sin(TIME + 1.5707963));
			float foam = step(0.0, d) * step(d, foam_width * breathe);
			if (foam > 0.5) {
				col = over(col, foam_color);
			}
		}
	}
	if (clip_to_area && area_distance(world_pos) < 0.0) {
		col.a = 0.0;
	}
	COLOR = col;
}
