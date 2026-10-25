shader_type canvas_item;

// Over the TV picture (inside the TV's own viewport): the show going
// wrong. Torn lines, a rolling picture, colour draining, snow.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float disturb = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float line = floor(uv.y * 60.0);
	float tear = step(1.0 - disturb * 0.35, hash(vec2(line, floor(TIME * 12.0))));
	uv.x += tear * (hash(vec2(line, TIME)) - 0.5) * 0.12 * disturb;
	uv.y = fract(uv.y + sin(TIME * 2.3) * 0.015 * disturb * disturb);
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l) * vec3(1.1, 0.72, 0.68), disturb * 0.6);
	c += (hash(SCREEN_UV * 173.0 + fract(TIME)) - 0.5) * 0.35 * disturb;
	COLOR = vec4(c, 1.0);
}
