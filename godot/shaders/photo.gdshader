// One treatment for every photograph, so pictures from a hundred sources look like one
// newspaper: the "night print".
//  - colour is thrown away and the tones are pushed apart (deep shadows, clean highlights)
//  - what is left is printed in two inks: a blue-black for the shadows and the paper
//    (or a cold white, on a screen) for the highlights
//  - anything that was strongly red in the original stays red: a flag, a tie, a fire
//  - a fine halftone screen on paper, scan lines on a television
//  - the edges fall away a little, as from a cheap lens
// "round" cuts the picture to a circle, for portraits.
shader_type canvas_item;

uniform vec4 shadow : source_color = vec4(0.055, 0.075, 0.115, 1.0);
uniform vec4 light : source_color = vec4(0.937, 0.922, 0.886, 1.0);
uniform vec4 red : source_color = vec4(0.824, 0.224, 0.184, 1.0);
uniform float contrast = 1.35;       // 1 = as shot
uniform float keep_red = 1.0;        // 0 = red is printed like any other colour
uniform float dots = 0.55;           // strength of the halftone screen (paper)
uniform float cell = 4.0;            // size of a halftone dot, in pixels
uniform float lines = 0.0;           // strength of the scan lines (screen)
uniform float vignette = 0.35;
uniform bool round = false;
uniform vec2 px = vec2(800.0, 450.0);    // the size the picture is drawn at, in pixels
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);   // the part of the picture shown (x, y, w, h in UV)

float tone(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = (l - 0.5) * contrast + 0.5;
	return smoothstep(0.02, 0.98, clamp(l, 0.0, 1.0));
}

void fragment() {
	vec2 uv = crop.xy + UV * crop.zw;
	vec3 c = texture(TEXTURE, uv).rgb;
	float l = tone(c);
	// how red the original was here (red well above both green and blue)
	float redness = smoothstep(0.14, 0.34, c.r - max(c.g, c.b)) * keep_red;
	vec2 p = UV * px;
	// the halftone screen, turned 45 degrees: dots grow as the tone darkens
	float out_l = l;
	if (dots > 0.0) {
		vec2 r = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p / cell;
		float d = length(fract(r) - 0.5) * 1.4142;
		float printed = smoothstep(-0.12, 0.12, d - (1.0 - l) * 1.05);
		out_l = mix(l, printed, dots);
	}
	if (lines > 0.0) out_l *= 1.0 - lines * step(1.5, mod(p.y, 3.0));
	vec3 col = mix(shadow.rgb, light.rgb, out_l);
	col = mix(col, red.rgb * (0.35 + 0.75 * out_l), redness);
	vec2 e = UV - 0.5;
	col = mix(col, shadow.rgb, smoothstep(0.35, 0.8, length(e)) * vignette);
	float a = 1.0;
	if (round) a = 1.0 - smoothstep(0.485, 0.5, length(e));
	COLOR = vec4(col, a * COLOR.a);
}
