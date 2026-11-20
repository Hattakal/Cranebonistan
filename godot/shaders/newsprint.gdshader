// Laid over a newspaper (text and all) and multiplied into it: cheap paper with fibres,
// soft blotches and a few specks, slightly uneven under the ink. Only darkens; the lamp
// light on the sheet does the brightening. The fold and the pages underneath are drawn
// by the Newspaper itself (paper.gd).
shader_type canvas_item;
render_mode blend_mul;

uniform vec2 sheet = vec2(900.0, 1200.0);   // the sheet's size in pixels

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * sheet;
	float m = 1.0;
	m -= (noise(p * vec2(0.09, 0.55)) - 0.5) * 0.05;    // long fibres running across
	m -= (noise(p * 0.012) - 0.5) * 0.045;               // soft blotches
	m -= (hash(floor(p)) - 0.5) * 0.035;                // fine grain
	if (hash(floor(p / 2.0) + 7.0) > 0.99975) m *= 0.8; // the odd speck
	// the page bends towards the fold at the bottom, away from the light
	m *= 1.0 - 0.08 * smoothstep(sheet.y - 90.0, sheet.y, p.y);
	COLOR = vec4(vec3(m), 1.0);
}
