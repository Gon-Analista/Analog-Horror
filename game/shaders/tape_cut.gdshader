shader_type canvas_item;
render_mode unshaded;

// Scene change: the tape is cut. Black with a faint snow and bands of static
// tearing through, clearing to the new picture. Drawn over everything
// (TapeCut), apart from the world's own post shader.

uniform float amount = 0.0;  // 0 clear .. 1 covered
uniform float calm = 1.0;    // fewer flashes (Settings): fainter bands

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy / 3.0);
	float t = TIME;
	float snow = hash(px + fract(t * 13.7) * 91.3);
	float row = hash(vec2(floor(FRAGCOORD.y / 12.0), floor(t * 24.0)));
	float band = step(1.0 - amount * 1.25, row) * (1.0 - smoothstep(0.8, 1.0, amount)) * calm;
	float black = smoothstep(0.3, 0.95, amount);
	vec3 col = mix(vec3(snow * 0.8 * calm), vec3(snow * 0.04), black);
	// A thin bright tracking line rolling through while it tears.
	float roll = fract(t * 0.9);
	col += vec3(smoothstep(0.012, 0.0, abs(UV.y - roll)) * band * 0.5);
	COLOR = vec4(col, clamp(max(band * 0.9, black), 0.0, 1.0));
}
