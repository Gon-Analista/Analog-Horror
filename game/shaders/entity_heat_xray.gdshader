shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled;

// The same heat, through the walls: while the entity feels for them (Q).
// Their whole shape glows red through anything between, pulsing.

uniform vec4 tint : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform float strength = 0.7;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.2);
	float beat = 0.75 + 0.25 * sin(TIME * 9.0);
	ALBEDO = tint.rgb * (0.4 + rim * 0.8) * strength * beat;
}
