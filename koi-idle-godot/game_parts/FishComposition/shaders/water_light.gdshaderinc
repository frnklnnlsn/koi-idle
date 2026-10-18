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

// The same with soft or hard edges: hardness 0 = soft glow, 1 = crisp
// pixel-art lines.
float water_light_shaped(vec2 pos, float scale, float t, float width, float hardness) {
	float l = water_light(pos, scale, t, width);
	return mix(l, step(0.35, l), hardness);
}
