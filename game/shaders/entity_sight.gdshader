shader_type canvas_item;
render_mode unshaded;

// How the entity sees (the player who is the Visita): one pass over the
// low-res 3D image. Not a camera: an eye. The picture is mapped through a
// ramp of its own (black, old blood, raw red, pale like bone) so the house
// reads in reds; the living glow through it (their heat, added in 3D,
// comes out bone-white); the lens bulges a little, the air shimmers, the
// edges smear apart in colour; the dark at the rim of its sight beats with
// its pulse, harder when it hunts. Ordered dither and quantised levels keep
// it in the same pixel register as the rest of the game.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pulse = 0.0;    // 0..1, its heartbeat (one beat = a bump)
uniform float hunt = 0.0;     // 0..1, running after them
uniform float hurt = 0.0;     // 0..1, blinded by a flash
uniform float sense = 0.0;    // 0..1, feeling for them (Q)
uniform float sleep = 0.0;    // 0..1, still asleep
uniform float levels = 24.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 ramp(float l) {
	vec3 c = mix(vec3(0.01, 0.0, 0.004), vec3(0.2, 0.015, 0.025), smoothstep(0.02, 0.22, l));
	c = mix(c, vec3(0.6, 0.08, 0.06), smoothstep(0.22, 0.55, l));
	c = mix(c, vec3(1.0, 0.86, 0.74), smoothstep(0.6, 0.98, l));
	return c;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.6, 1.0));
	float t = TIME;
	// The lens of its eye: a slight bulge, more when it runs; the air
	// trembling; blinded, the picture swims.
	uv = 0.5 + c * (1.0 - (0.045 + 0.05 * hunt) * r * r);
	uv.x += sin(uv.y * 48.0 + t * 2.7) * (0.0009 + 0.0016 * hunt + 0.004 * hurt);
	uv.y += cos(uv.x * 37.0 + t * 1.9) * (0.0006 + 0.003 * hurt);
	// Colour smears apart towards the edges.
	vec2 ca = c * (0.004 + 0.01 * r + 0.012 * hurt + 0.004 * sense);
	vec3 col;
	col.r = texture(screen_tex, uv + ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - ca).b;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	// Its sight: lifted out of the dark (it sees there), through the ramp;
	// a trace of the true colours stays in the brightest things.
	float lifted = pow(clamp(l * 1.15, 0.0, 1.0), 0.9);
	vec3 seen = ramp(lifted);
	seen = mix(seen, col * vec3(1.3, 0.75, 0.6), 0.12 * smoothstep(0.4, 1.0, l));
	// The rim of its sight closes in and beats with its pulse.
	float edge = smoothstep(0.32 - pulse * 0.05 - hunt * 0.06, 0.95, r);
	seen *= 1.0 - edge * (0.82 + 0.1 * pulse);
	seen += vec3(0.16, 0.0, 0.0) * edge * pulse;
	// Feeling for them: the whole view darkens and breathes red.
	seen = mix(seen, seen * vec3(0.55, 0.25, 0.25) + vec3(0.08, 0.0, 0.0) * (0.6 + 0.4 * sin(t * 9.0)), sense * 0.6);
	// Grain, at the picture's own pixels.
	vec2 px = floor(FRAGCOORD.xy);
	seen += (hash(px + fract(t * 7.31) * 57.0) - 0.5) * 0.045;
	// Asleep: almost nothing, a slow red breath.
	seen = mix(seen, seen * 0.22 + vec3(0.05, 0.0, 0.0) * (0.5 + 0.5 * sin(t * 1.3)), sleep);
	// Blinded: white, burning out to red.
	seen = mix(seen, vec3(1.0, 0.93, 0.86), hurt * hurt * 0.85);
	seen = mix(seen, vec3(1.0, 0.3, 0.2), hurt * (1.0 - hurt) * 0.6);
	// Dither and quantise (the same pixel register as the rest).
	int bi = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float d = (BAYER[bi] / 16.0 - 0.5) / levels;
	seen = floor((seen + d) * levels + 0.5) / levels;
	COLOR = vec4(seen, 1.0);
}
