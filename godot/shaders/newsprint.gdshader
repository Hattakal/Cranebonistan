// Laid over a newspaper (text and all) and multiplied into it: cheap paper that has been
// rolled up and folded. Only darkens; the lamp light on the sheet does the brightening.
//  - fibres and blotches in the paper, a few specks
//  - soft bands across the page where it remembers being rolled
//  - the ends curl away from the light, so the top and bottom edges are darker
//  - a crease across the middle where it was folded
//  - edges a little browner, as old newsprint goes
shader_type canvas_item;
render_mode blend_mul;

uniform vec2 sheet = vec2(900.0, 1200.0);   // the sheet's size in pixels
uniform float roll = 420.0;                  // how far apart the roll bands are, in pixels
uniform float fold = 0.5;                    // where the fold is, as a share of the height (<0 for none)

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
	// the paper itself: long fibres running across, soft blotches, fine grain
	m -= (noise(p * vec2(0.09, 0.55)) - 0.5) * 0.05;
	m -= (noise(p * 0.012) - 0.5) * 0.07;
	m -= (hash(floor(p)) - 0.5) * 0.035;
	if (hash(floor(p / 2.0) + 7.0) > 0.99975) m *= 0.8;
	// it was rolled: soft bands across the page, darkest where it bent most
	float band = 0.5 + 0.5 * cos(6.2832 * (p.y / roll + 0.15 * noise(vec2(p.x * 0.004, 3.0))));
	m *= 1.0 - 0.05 * band * band;
	// the ends curl up, away from the lamp
	float top = 1.0 - smoothstep(0.0, 70.0, p.y);
	float bottom = 1.0 - smoothstep(0.0, 70.0, sheet.y - p.y);
	m *= 1.0 - 0.13 * top * top - 0.13 * bottom * bottom;
	// the fold across the middle: a soft valley with a sharp crease
	if (fold > 0.0) {
		float d = p.y - fold * sheet.y + (noise(vec2(p.x * 0.01, 1.0)) - 0.5) * 3.0;
		m *= 1.0 - 0.07 * exp(-d * d / 180.0);
		m *= 1.0 - 0.18 * exp(-d * d / 0.9);
		m *= 1.0 - 0.04 * smoothstep(0.0, 3.0, d) * exp(-d / 14.0);
	}
	// old newsprint browns at the edges
	float edge = min(min(p.x, sheet.x - p.x), min(p.y, sheet.y - p.y));
	float age = 1.0 - smoothstep(0.0, 26.0, edge);
	vec3 c = vec3(m) * mix(vec3(1.0), vec3(0.9, 0.86, 0.76), age);
	COLOR = vec4(c, 1.0);
}
