shader_type canvas_item;
render_mode unshaded;

// Single full-screen pass over the low-res 3D image (one screen read):
// always: vignette + ordered dither + colour quantisation (the pixel-art
// register); through the camcorder: VHS (gain, chroma bleed, tracking,
// scanlines, grain) and interference when the entity is near.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float levels = 28.0;
uniform float dither = 1.0;
uniform float vignette = 0.35;

uniform float vhs = 0.0;            // 0 naked eye .. 1 at the viewfinder
uniform float gain = 2.4;           // camcorder low-light gain
uniform float static_amount = 0.0;  // entity proximity
uniform float hit = 0.0;            // capture: full interference
uniform float dead = 0.0;           // battery empty: no picture

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = floor(FRAGCOORD.xy);
	float t = TIME;
	float noise_amt = clamp(static_amount + hit, 0.0, 1.0);

	if (vhs > 0.0) {
		float roll = fract(t * 0.06);
		float band = smoothstep(0.035, 0.0, abs(uv.y - roll));
		float line_jitter = hash(vec2(floor(uv.y * 135.0), floor(t * 24.0))) - 0.5;
		uv.x += (sin(uv.y * 90.0 + t * 7.0) * 0.0008 + band * 0.006 + line_jitter * 0.03 * noise_amt) * vhs;
	}

	float ca = 0.0025 * vhs + 0.006 * noise_amt;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;

	if (vhs > 0.0) {
		vec3 lifted = col * gain + vec3(0.015);
		float luma = dot(lifted, vec3(0.299, 0.587, 0.114));
		lifted = mix(lifted, vec3(luma), 0.35) * vec3(0.95, 1.02, 0.93);
		col = mix(col, lifted, vhs);
		float g = hash(px + fract(t * 7.13) * 91.7) - 0.5;
		col += g * (0.07 * vhs + 0.6 * noise_amt);
		col *= 1.0 - 0.16 * vhs * mod(px.y, 2.0);
		float bars = step(0.62, hash(vec2(floor(px.y / 3.0), floor(t * 30.0)))) * noise_amt;
		col = mix(col, vec3(hash(px * 1.31 + t)), bars * 0.7);
		col = mix(col, vec3(hash(px + t) * 0.08), dead * vhs);
	}

	// A faint film grain even to the naked eye: the whole game is "footage".
	col += (hash(px * 0.73 + fract(t * 3.7) * 57.1) - 0.5) * 0.025 * (1.0 - vhs);

	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * (vignette + 0.7 * vhs) * 2.0;

	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float b = (BAYER[i] + 0.5) / 16.0 - 0.5;
	col = floor(clamp(col, 0.0, 1.0) * levels + 0.5 + b * dither) / levels;
	COLOR = vec4(col, 1.0);
}
