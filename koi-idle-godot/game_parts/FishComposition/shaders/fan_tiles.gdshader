// fan_tiles.gdshader
// A floor of fan (fish scale) tiles: round tops, pointed bottoms where the
// next row overlaps them, thin grout lines, an even flat band just inside the
// grout all the way round each tile, and a slight colour difference from tile
// to tile. Drawn on a ColorRect (Floor in
// the toilet view); positions are world pixels, so the tiles stay put however
// big the rect is.
shader_type canvas_item;

// Tile radius (half a tile's width), in pixels.
uniform float radius : hint_range(4.0, 120.0, 1.0) = 26.0;
uniform vec4 tile_color : source_color = vec4(0.79, 0.82, 0.86, 1.0);
// The flat band just inside the grout, all round each tile.
uniform vec4 edge_color : source_color = vec4(0.73, 0.76, 0.81, 1.0);
uniform vec4 grout_color : source_color = vec4(0.56, 0.60, 0.66, 1.0);
// Grout line width, and the band inside it, in pixels.
uniform float grout : hint_range(0.0, 8.0, 0.5) = 2.0;
uniform float edge_width : hint_range(0.0, 12.0, 0.5) = 3.0;
// How much each tile's colour varies (0 = all the same).
uniform float variation : hint_range(0.0, 0.2, 0.005) = 0.03;
group_uniforms colour;
// Recolour the tiles: the hue to use (0..1 round the colour wheel: 0 red,
// 0.17 yellow, 0.33 green, 0.5 cyan, 0.67 blue, 0.83 pink), how colourful,
// and how much of it to apply (0 = the colours above as they are).
uniform float hue : hint_range(0.0, 1.0, 0.005) = 0.58;
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float tint_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
// Recolour the grout too.
uniform bool tint_grout = false;
group_uniforms;

// Snap to a chunky grid, in pixels (1 = none).
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// The colour with the chosen hue and saturation, same brightness.
vec3 tint(vec3 c) {
	vec3 hsv = rgb2hsv(c);
	return mix(c, hsv2rgb(vec3(hue, saturation, hsv.z)), tint_amount);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (floor(world_pos / pixel_size) + 0.5) * pixel_size;
	float r = radius;
	// Rows are r apart, tiles 2r apart, every other row shifted by r. Each
	// row covers the one above it, so the lowest row whose circle holds the
	// point owns it.
	float row0 = floor(p.y / r);
	vec2 centre = vec2(0.0);
	float found = 0.0;
	for (int i = 0; i < 3; i++) {
		float k = row0 + 1.0 - float(i);
		float shift = mod(k, 2.0) * r;
		float cx = floor((p.x - shift) / (2.0 * r) + 0.5) * 2.0 * r + shift;
		vec2 c = vec2(cx, k * r);
		if (found < 0.5 && distance(p, c) < r) {
			centre = c;
			found = 1.0;
		}
	}
	// Pixels to the tile's visible edge: its own rim, or the rims of the two
	// tiles below that overlap its bottom.
	float edge = r - length(p - centre);
	edge = min(edge, length(p - (centre + vec2(-r, r))) - r);
	edge = min(edge, length(p - (centre + vec2(r, r))) - r);

	vec3 col = edge < grout + edge_width ? edge_color.rgb : tile_color.rgb;
	col *= 1.0 + (hash(centre) - 0.5) * 2.0 * variation;
	col = tint(col);
	if (found < 0.5 || edge < grout) {
		col = tint_grout ? tint(grout_color.rgb) : grout_color.rgb;
	}
	COLOR = vec4(col, 1.0);
}
