// water_area.gdshaderinc
// The swim area's shape, for water shaders that should only act on the water
// (inside the area) or draw along its edge. The pond and toilet scripts fill
// these in from their SwimShape (SwimArea.apply_to_material), so don't edit
// them by hand.

// 0 = no area (everywhere counts as inside), 1 = circle / ellipse,
// 2 = capsule (vertical, then turned by area_rotation), 3 = rectangle,
// 4 = polygon (area_points, world pixels; e.g. the pond's organic outline).
uniform int area_shape = 0;
uniform vec2 area_points[64];
uniform int area_point_count = 0;
uniform vec2 area_center = vec2(0.0);
// Ellipse: half width / half height. Capsule: radius / half the total height.
// Rectangle: half width / half height.
uniform vec2 area_size = vec2(0.0);
uniform float area_rotation = 0.0;

// How far `p` (pond pixels) is inside the area's edge; negative = outside.
float area_distance(vec2 p) {
	if (area_shape == 0) {
		return 1e6;
	}
	if (area_shape == 4) {
		// Signed distance to a polygon (Inigo Quilez's sdPolygon), flipped so
		// inside is positive.
		int n = min(area_point_count, 64);
		if (n < 3) {
			return 1e6;
		}
		float d = dot(p - area_points[0], p - area_points[0]);
		float sgn = 1.0;
		for (int i = 0, j = n - 1; i < n; j = i, i++) {
			vec2 e = area_points[j] - area_points[i];
			vec2 w = p - area_points[i];
			vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
			d = min(d, dot(b, b));
			bvec3 c = bvec3(p.y >= area_points[i].y, p.y < area_points[j].y, e.x * w.y > e.y * w.x);
			if (all(c) || all(not(c))) {
				sgn = -sgn;
			}
		}
		return -sgn * sqrt(d);
	}
	vec2 l = p - area_center;
	float c = cos(-area_rotation);
	float s = sin(-area_rotation);
	l = vec2(l.x * c - l.y * s, l.x * s + l.y * c);
	vec2 r = max(area_size, vec2(0.001));
	if (area_shape == 1) {
		return (1.0 - length(l / r)) * min(r.x, r.y);
	} else if (area_shape == 2) {
		float half_line = max(r.y - r.x, 0.0);
		vec2 spine = vec2(0.0, clamp(l.y, -half_line, half_line));
		return r.x - length(l - spine);
	}
	return min(r.x - abs(l.x), r.y - abs(l.y));
}
