shader_type canvas_item;

// The TV showing the room it stands in ("EN DIRECTO"): the picture of a
// cheap studio camera with the gain all the way up. Grey, crushed, grainy,
// rolling a little.

uniform float gain = 1.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float line = floor(uv.y * 120.0);
	uv.x += (hash(vec2(line, floor(TIME * 15.0))) - 0.5) * 0.006;
	vec3 c = texture(TEXTURE, uv).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11)) * gain;
	l = pow(clamp(l, 0.0, 1.0), 0.8);
	l = smoothstep(0.04, 0.95, l);
	l += (hash(UV * 211.0 + fract(TIME * 7.0)) - 0.5) * 0.16;
	l *= 0.92 + 0.08 * sin(UV.y * 240.0);
	float vig = 1.0 - 0.5 * dot(UV - 0.5, UV - 0.5) * 2.0;
	COLOR = vec4(vec3(l * vig) * vec3(0.92, 0.97, 1.0), 1.0);
}
