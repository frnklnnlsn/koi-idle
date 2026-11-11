// flush_water.gdshader
// The toilet's water while it flushes: spiral streaks of foam swirling in to
// the drain, a dark vortex at the drain and a churned tint over the bowl.
// Drawn on its own layer over the toilet water (FlushWater in main_UI), at
// nothing (strength 0) until toilet_viewport.gd turns it up during a flush.
// Positions are toilet pixels, snapped to the same chunky grid as the water.
shader_type canvas_item;

#include "res://game_parts/FishComposition/shaders/water_light.gdshaderinc"
#include "res://game_parts/FishComposition/shaders/water_area.gdshaderinc"

// 0 = still water (invisible), 1 = full flush. Set by toilet_viewport.gd.
uniform float strength : hint_range(0.0, 1.0, 0.01) = 0.0;
// The drain, in toilet pixels. Set by toilet_viewport.gd (flush_drain_point).
uniform vec2 drain = vec2(0.0, -60.0);
// 1 or -1: which way the water turns (matches the fish's spiral).
uniform float spin = 1.0;
// How far the water has turned so far. toilet_viewport.gd adds to it each
// frame (slow at first, faster as the flush builds), so the spin speeds up
// smoothly instead of jumping when the strength changes.
uniform float swirl_phase = 0.0;
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
// Draw only inside the bowl (set by the toilet script).
uniform bool clip_to_area = false;

group_uniforms swirl;
// Number of spiral arms, how tightly they wind, and how fast they turn at
// full flush (toilet_viewport.gd reads spin_speed).
uniform float arms : hint_range(1.0, 8.0, 1.0) = 3.0;
uniform float twist : hint_range(0.0, 12.0, 0.1) = 4.0;
uniform float spin_speed : hint_range(0.0, 20.0, 0.1) = 6.0;
// Share of the swirl that's streak (higher = thinner streaks).
uniform float streak_cut : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform vec4 streak_color : source_color = vec4(0.85, 0.95, 1.0, 0.55);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
// Churned-water tint over the whole bowl.
uniform vec4 churn_color : source_color = vec4(0.35, 0.55, 0.75, 0.06);

group_uniforms vortex;
uniform vec4 vortex_color : source_color = vec4(0.02, 0.03, 0.08, 0.85);
// Radius of the dark hole at the drain, in toilet pixels.
uniform float vortex_radius : hint_range(0.0, 60.0, 0.5) = 14.0;

group_uniforms noise;
// How much the noise wobbles the streaks (0 = clean spiral arms).
uniform float noise_wobble : hint_range(0.0, 4.0, 0.05) = 0.8;
// Seamless noise that breaks the streaks up (a NoiseTexture2D).
uniform sampler2D noise : repeat_enable, filter_nearest;
uniform float noise_px : hint_range(16.0, 512.0, 1.0) = 96.0;
group_uniforms;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = water_snap(world_pos, pixel_size);
	if (strength <= 0.001 || (clip_to_area && area_distance(p) < 0.0)) {
		discard;
	}
	vec2 d = p - drain;
	float r = length(d) + 0.001;
	float a = atan(d.y, d.x);
	float t = swirl_phase;
	// Spiral arms: constant along a * arms + twist * log(r); turning in time.
	float phase = a * arms * spin + twist * log(r) - t * spin;
	// Turn the noise with the water so the streaks break up as they swirl.
	float rot = -t * 0.15 * spin;
	vec2 q = vec2(cos(rot) * d.x - sin(rot) * d.y, sin(rot) * d.x + cos(rot) * d.y);
	float n = texture(noise, q / noise_px).r;
	float wave = sin(phase + n * noise_wobble) * 0.5 + 0.5;
	// Strongest near the drain, fading out to the rim.
	float near = clamp(1.0 - r / 180.0, 0.0, 1.0);

	vec4 col = churn_color;
	if (wave > streak_cut) {
		col = mix(col, streak_color, 1.0);
	}
	if (wave > mix(streak_cut, 1.0, 0.7) && n > 0.55) {
		col = foam_color;
	}
	col.a *= mix(0.35, 1.0, near);
	// The dark hole.
	float hole = 1.0 - smoothstep(vortex_radius * 0.5, vortex_radius, r);
	col = mix(col, vortex_color, hole * step(0.01, vortex_radius));
	col.a *= strength;
	COLOR = col;
}
