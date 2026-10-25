shader_type canvas_item;

// Over a TV picture drawn in the UI: scanlines, a curved-glass vignette and
// a faint reflection. Draws on top (it does not read the picture).

void fragment() {
	vec2 d = UV - 0.5;
	float scan = 0.16 * step(0.5, fract(FRAGCOORD.y * 0.5));
	float vignette = smoothstep(0.28, 0.78, length(d * vec2(1.0, 1.15))) * 0.85;
	float glare = smoothstep(0.32, 0.0, length(UV - vec2(0.28, 0.2))) * 0.1;
	float dark = clamp(scan + vignette, 0.0, 1.0);
	// Black darkening, with a little white where the glass catches light.
	COLOR = vec4(vec3(glare / max(glare + dark, 0.001)), clamp(dark + glare, 0.0, 1.0));
}
