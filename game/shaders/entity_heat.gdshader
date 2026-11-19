shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

// The living, as the entity sees them (only on its player's machine): the
// warmth of a body glowing at its edges, breathing, fading out with the
// distance its sight reaches. Laid over the crew's own materials.

uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.36, 1.0);
uniform float strength = 0.8;
uniform float reach = 10.0;   // metres: past this, no heat to see

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float breathe = 0.85 + 0.15 * sin(TIME * 5.0 + VERTEX.y * 3.0);
	float fade = 1.0 - smoothstep(reach * 0.45, reach, length(VERTEX));
	ALBEDO = tint.rgb * (0.55 + rim * 1.1) * strength * breathe * fade;
}
