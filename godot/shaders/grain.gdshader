// The last layer over the whole screen: a little film grain and darker corners, so flat
// colours and gradients look photographed instead of drawn.
shader_type canvas_item;

uniform float grain = 0.024;      // how strong the grain is
uniform float vignette = 0.3;    // how dark the corners get

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	float n = hash(px + floor(TIME * 12.0) * 17.0) - 0.5;
	vec2 d = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(d * vec2(1.0, 0.82)) * 1.25) * vignette;
	// darken by the vignette, then a speck of white or black on top
	float a = abs(n) * 2.0 * grain * (1.0 - v);
	float alpha = v + a;
	float white = n > 0.0 ? a : 0.0;
	COLOR = vec4(vec3(white / max(alpha, 0.0001)), alpha);
}
