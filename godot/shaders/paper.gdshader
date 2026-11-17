// A sheet of paper under a desk lamp: warm and bright near the lamp (above the top left
// corner), cooler and a little darker away from it, with a faint tooth to the paper.
// Put on the panel that draws the sheet; its shadow stays black because light only multiplies.
shader_type canvas_item;

uniform vec2 sheet = vec2(820.0, 900.0);   // the sheet's size in pixels
uniform float strength = 1.0;

varying vec2 lp;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 lamp = vec2(sheet.x * 0.18, -140.0);
	float d = clamp(distance(lp, lamp) / (sheet.x * 1.5), 0.0, 1.0);
	vec3 warm = vec3(1.035, 1.012, 0.965);
	vec3 cool = vec3(0.91, 0.925, 0.95);
	vec3 light = mix(warm, cool, smoothstep(0.05, 1.0, d));
	float tooth = (hash(floor(lp)) - 0.5) * 0.022;
	COLOR.rgb *= mix(vec3(1.0), light + tooth, strength);
}
