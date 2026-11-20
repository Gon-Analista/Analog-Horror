shader_type spatial;
// La Visita's aura (EntitySoot): soot smoke boiling off its body and limbs,
// for GPUParticles3D quads. Billboards that keep the particle's size and
// spin; the smoke is two scrolling layers of tileable noise eroded as the
// particle ages (it thins into wisps, it does not just fade); soft where
// it meets walls and floor (depth fade), so no hard edges cut the puff.
// Lit like the house: in the dark it is a darker dark; caught in a
// flashlight, grey wisps over a black core.
// Its alpha is stepped a little, like the rest of the picture (pixel, tape).
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;  // data, not colour
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 soot_color : source_color = vec4(0.02, 0.017, 0.016, 1.0);
// Its thin edges: grey-brown, where the light catches the wisps.
uniform vec4 edge_color : source_color = vec4(0.3, 0.26, 0.24, 1.0);
uniform float density = 1.6;
// The tape sees soot in the dark the way it sees everything (gain): its thin
// edges glow a faint grey, so the black core reads against a dark room.
uniform float glow = 0.38;
uniform float soft_distance = 0.3;
// Steps of opacity (0: smooth).
uniform float steps = 0.0;
// 1 while it is filmed: the smoke hangs, still, as if time stopped around it.
uniform float hold = 0.0;

varying float v_seed;
varying float v_life;

void vertex() {
	// Billboard (particles): face the camera, keep spin (CUSTOM.x) and size.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	world = world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_seed = fract(sin(float(INSTANCE_ID) * 12.9898 + a * 3.17) * 43758.5453);
	v_life = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float t = TIME * mix(0.12, 0.02, hold);
	vec3 n1 = texture(noise_tex, UV * 0.55 + vec2(v_seed * 7.0, -t)).rgb;
	vec3 n2 = texture(noise_tex, UV * 1.25 + vec2(-t * 1.6, v_seed * 3.0 + t * 0.4)).rgb;
	// A ragged round puff (the noise bites into its rim)...
	float r = length(c + (n2.xy - 0.5) * 0.55);
	float puff = smoothstep(1.0, 0.0, r + (n1.r - 0.5) * 0.8);
	// ...that erodes into wisps as it ages.
	float wisp = n1.g * 0.65 + n2.b * 0.55;
	float erode = mix(0.05, 0.75, v_life);
	float body = smoothstep(erode, erode + 0.35, wisp);
	float a = puff * body * COLOR.a * density;
	// Soft against the house (no hard line where a puff meets a wall).
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	a *= clamp((VERTEX.z - view.z) / soft_distance, 0.0, 1.0);
	if (steps > 0.0) {
		a = floor(a * steps + 0.5) / steps;
	}
	float core = smoothstep(0.1, 0.7, a);
	ALBEDO = mix(edge_color.rgb, soot_color.rgb, core) * COLOR.rgb;
	// (Glow over the whole wisp, strongest where it is thin: no bright rims.)
	EMISSION = edge_color.rgb * glow * mix(1.0, 0.25, core) * COLOR.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	// (A billboard: its normal faces you, so a light behind it rims nothing;
	// a little back light lets the beam through the thin parts.)
	BACKLIGHT = edge_color.rgb * 0.6;
}
