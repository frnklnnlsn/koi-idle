// water_light.gdshaderinc
// Shared light-ripple (caustics) pattern: the net of bright lines that
// sunlight makes through a moving water surface, like the bottom of a pool.
// Included by the fish shader and the pond's water-light layer, so both show
// the same light at the same place.
//
// How it works: the pond is cut into cells, each with a point drifting
// around inside it; light lines are drawn where two cells meet (the edges of
// a Voronoi pattern). A gentle warp bends the lines so they look liquid.

vec2 water_light_hash(vec2 cell) {
	vec2 h = vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)));
	return fract(sin(h) * 43758.5453);
}

// 0..1 light at a pond position (pixels). scale = cell size in pixels,
// t = time, width = line thickness as a share of a cell.
float water_light(vec2 pos, float scale, float t, float width) {
	vec2 p = pos / scale;
	p += 0.15 * vec2(sin(p.y * 2.0 + t), sin(p.x * 2.0 - t * 0.8));
	vec2 ip = floor(p);
	vec2 fp = p - ip;
	float d1 = 9.0;
	float d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = water_light_hash(ip + o);
			vec2 pt = 0.5 + 0.4 * sin(vec2(t * 0.7, t * 0.6) + 6.2831853 * h);
			float d = length(o + pt - fp);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = d2 - d1;
	float l = clamp(1.0 - edge / max(width, 0.001), 0.0, 1.0);
	return l * l;
}


// Refraction wobble: how far (in pond pixels, before x amplitude) water bends
// what's under it at a pond position. Fish move their outline by this,
// underwater sprites shift their picture by it, so both waver together.
vec2 water_wobble_offset(vec2 world, float wavelength, float speed, float cross_ripple, float t) {
	float k = 6.2831853 / wavelength;
	float tt = t * speed;
	vec2 offset;
	offset.x = sin(world.y * k + tt) + cross_ripple * sin((world.x + world.y) * k * 0.7 - tt * 1.3);
	offset.y = cos(world.x * k * 0.9 + tt * 1.1) + cross_ripple * cos((world.x - world.y) * k * 0.6 + tt * 0.8);
	return offset / (1.0 + cross_ripple);
}

// --- Pixel-art helpers (ideas from "2D Pixel Art Water", godotshaders.com,
// CC0) --------------------------------------------------------------------

// Snaps a pond position to a grid of `pixel`-sized squares (centre of the
// square), so light and sparkles come out as solid pixel blocks.
vec2 water_snap(vec2 pos, float pixel) {
	float s = max(pixel, 0.001);
	return (floor(pos / s) + 0.5) * s;
}

// Sideways shift (pixels) that wobbles a pattern, from a scrolling seamless
// noise texture: the "rippling" of the pixel-art water shader.
// noise_px = how many pond pixels one noise tile covers.
vec2 water_ripple(sampler2D noise_tex, vec2 pos, float noise_px, float amount, float t) {
	vec2 n = texture(noise_tex, pos / noise_px + vec2(t * 0.03, t * 0.02)).rg;
	return (n - 0.5) * 2.0 * amount;
}

// Two-tone banding of a 0..1 light value: 0 = none, 1 = light band,
// 2 = bright core.
float water_band(float l, float band_at, float core_at) {
	return step(band_at, l) + step(core_at, l);
}

// Random surface sparkles at a pond position: two noise samples scrolling
// opposite ways, overlay-blended and taken away from a still sample; where
// the difference is high, a glint. threshold: higher = fewer sparkles.
float water_sparkle(sampler2D noise_tex, vec2 pos, float noise_px, float scale, float t, float threshold) {
	vec2 uv = pos / noise_px;
	vec4 a = texture(noise_tex, uv * scale + t * 0.2);
	vec4 b = texture(noise_tex, uv * scale - t * 0.2);
	vec4 overlay = mix(1.0 - 2.0 * (1.0 - a) * (1.0 - b), 2.0 * a * b, step(a, vec4(0.5)));
	vec4 still = texture(noise_tex, uv);
	return step(threshold, (still - overlay).r);
}
