// water_wobble.gdshader
// Refraction wobble for fish seen through water. Pushes the fish's outline
// back and forth with a slow-moving wave pattern that is fixed in the pond
// (world space), not to the fish: fish swimming through it waver like things
// under a moving surface, and neighbouring fish waver together.
//
// Used on FishBody and Skeleton (fins) of pond and toilet fish, through
// water_wobble_material.tres (FishDisplay assigns it). Edit the numbers there.
shader_type canvas_item;

// How far an edge moves, in pond pixels. Keep it small: 0.5 - 1.5.
uniform float amplitude : hint_range(0.0, 4.0, 0.05) = 0.8;
// Size of the ripples, in pond pixels. Around the size of a fish looks best.
uniform float wavelength : hint_range(4.0, 200.0, 1.0) = 36.0;
// How fast the ripples drift.
uniform float speed : hint_range(0.0, 5.0, 0.05) = 0.9;
// Second, crossing ripple pattern, as a share of the first (0 = one pattern).
uniform float cross_ripple : hint_range(0.0, 1.0, 0.05) = 0.6;

void vertex() {
	// Where this vertex is in the pond (fish nodes aren't rotated or scaled).
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float k = 6.2831853 / wavelength;
	float t = TIME * speed;
	vec2 offset;
	offset.x = sin(world.y * k + t) + cross_ripple * sin((world.x + world.y) * k * 0.7 - t * 1.3);
	offset.y = cos(world.x * k * 0.9 + t * 1.1) + cross_ripple * cos((world.x - world.y) * k * 0.6 + t * 0.8);
	VERTEX += offset * amplitude / (1.0 + cross_ripple);
}
