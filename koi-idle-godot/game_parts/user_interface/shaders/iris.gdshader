// iris.gdshader
// Black everywhere except inside a circle (the flush cut scene's wipe).
// Positions are in the rect's own pixels; the edge is snapped to chunky
// pixel steps to match the game.
shader_type canvas_item;

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 2000.0;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 p = floor(UV * rect_size / pixel_size) * pixel_size + pixel_size * 0.5;
	COLOR = distance(p, center) < radius ? vec4(0.0) : color;
}
