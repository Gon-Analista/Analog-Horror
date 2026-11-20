shader_type spatial;
// The curtains by a window (HouseWindow): heavy, two-sided, the moonlight
// glowing through them; with the window open (`wind` 0..1) the draught
// lifts them into the room, more at the hem than at the rod.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float rod_y = 2.24;
uniform float drop = 1.5;
instance uniform float wind = 0.0;

void vertex() {
	float hang = clamp((rod_y - VERTEX.y) / drop, 0.0, 1.0);
	if (wind > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float gust = 0.6 + 0.4 * sin(TIME * 0.9 + wp.x * 0.7 + wp.z * 0.7);
		float flutter = sin(TIME * 2.6 + VERTEX.x * 7.0 + VERTEX.y * 2.0) * 0.5 + sin(TIME * 4.1 + VERTEX.x * 13.0) * 0.25;
		VERTEX.z += wind * hang * hang * (0.16 * gust + 0.07 * flutter);
		VERTEX.x += wind * hang * (0.05 * sin(TIME * 1.7 + VERTEX.y * 3.0) - 0.06 * sign(VERTEX.x) * gust);
	}
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
	BACKLIGHT = ALBEDO * 0.45;
}
