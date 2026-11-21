// A television in a dark room: faint scan lines, and a glass that is a little brighter in the middle.
shader_type canvas_item;

uniform vec2 sheet = vec2(860.0, 600.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float line = 0.94 + 0.06 * step(1.5, mod(lp.y, 3.0));
	vec2 c = lp / sheet - 0.5;
	float glow = 1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.75, length(c)));
	COLOR.rgb *= line * glow;
}
