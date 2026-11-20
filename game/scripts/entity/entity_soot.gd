class_name EntitySoot
extends Node3D
## La Visita's soot: what is left of the burnt tape it came from.
##   aura   soot smoke boiling off its body and every joint of its limbs,
##          a few black flakes falling, and a stain of shadow spreading on
##          the floor (or the ceiling) under it. Visual layer 2, like the
##          Visita: only a filming camcorder sees it. While it is filmed
##          (FROZEN) the smoke hangs almost still around it.
##   marks  long-toed footprints (huge handprints on all fours) and a burnt
##          splash where the flash tore it apart. They settle a moment after
##          it passed (where it was, never where it is) and fade out after
##          Tuning.SOOT_LIFE. Seen with the naked eye (Tuning.SOOT_NAKED_EYE):
##          the one trace it leaves in the real world.
## Presentation only, on every machine: derived from what Entity already
## replicates (position, state, pose, mode); nothing of its own goes over the
## network. A pool of decals (no draw calls: clustered) and two particle
## systems (two draw calls, only through the camcorder).

const TEX_FOOT := "res://assets/textures/soot_foot.png"
const TEX_HAND := "res://assets/textures/soot_hand.png"
const TEX_SCORCH := "res://assets/textures/soot_scorch.png"
const TEX_POOL := "res://assets/textures/soot_pool.png"
const TEX_NOISE := "res://assets/textures/soot_noise.png"
const SHADER := "res://shaders/entity_soot.gdshader"
const FOOT_SIZE := Vector3(0.4, 1.0, 0.6)
const HAND_SIZE := Vector3(0.6, 1.0, 0.75)
const SCORCH_SIZE := Vector3(1.5, 1.0, 1.5)
const POOL_SIZE := 1.9
const MARK_ALPHA := 1.0
const UPDATE_EVERY := 0.1  # marks fade in steps (cheap), the aura is the GPU's
## Decal albedo goes in linear: the textures' soot colour, darkened to
## read as soot and not as a grey shadow (alpha set as it settles).
const INK := Color(0.22, 0.22, 0.22, 0.0)

## Of Tuning.SOOT_MARKS, how many of each.
const POOLS := {TEX_FOOT: 0.7, TEX_HAND: 0.25, TEX_SCORCH: 0.05}

## [decal, born (clock), life]
var _marks: Array = []
var _rings := {}  # texture -> [entries]
var _next := {}   # texture -> next entry to reuse
var _clock := 0.0
var _update_in := 0.0
var _travel := 0.0
var _side := 1.0
var _last := Vector3.INF
var _smoke: GPUParticles3D
var _flakes: GPUParticles3D
var _smoke_mat: ShaderMaterial
var _points := PackedVector3Array()
var _point_img: Image
var _point_tex: ImageTexture
var _pool: Decal
var _pool_t := 0.0
var _rng := RandomNumberGenerator.new()
var _tex := {}


func _ready() -> void:
	top_level = true  # the marks stay where they fell
	global_transform = Transform3D.IDENTITY
	_rng.seed = 7071
	# Crisp prints, pixels like the rest of the house: the default (linear,
	# mipmapped) blurs a print a few metres away into nothing. Set here and
	# not in project.godot (a patch cannot change it); only its decals use it.
	RenderingServer.decals_set_filter(RenderingServer.DECAL_FILTER_NEAREST)
	for key: String in [TEX_FOOT, TEX_HAND, TEX_SCORCH, TEX_POOL]:
		_tex[key] = load(key)
	var marks_layer := 1 | Entity.LAYER_MASK if Tuning.SOOT_NAKED_EYE else Entity.LAYER_MASK
	var matte := _matte()
	# One pool per print, each decal keeping its texture (swapping a decal's
	# texture at run time is not reliable on every driver).
	for key: String in POOLS:
		var ring: Array = []
		for i in int(POOLS[key] * Tuning.SOOT_MARKS):
			var d := Decal.new()
			d.texture_albedo = _tex[key]
			d.layers = marks_layer
			d.cull_mask = Tuning.LAYER_WORLD  # the house, never the Visita or the hands in view
			d.texture_orm = matte
			d.normal_fade = 0.35  # not up the walls
			d.upper_fade = 0.3
			d.lower_fade = 0.3
			d.visible = false
			add_child(d)
			var entry := [d, -INF, 0.0]
			ring.append(entry)
			_marks.append(entry)
		_rings[key] = ring
		_next[key] = 0
	_build_aura()


## Soot is matte: where it lies, a polished floor stops shining.
static func _matte() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(1.0, 1.0, 0.0))  # occlusion 1, roughness 1, metal 0
	return ImageTexture.create_from_image(img)


func _build_aura() -> void:
	_point_img = Image.create(EntityModel.SOOT_POINTS, 1, false, Image.FORMAT_RGBF)
	_point_tex = ImageTexture.create_from_image(_point_img)
	_points.resize(EntityModel.SOOT_POINTS)
	# Smoke: puffs born on its joints, drifting up and curling (turbulence),
	# growing and thinning into wisps; they stay behind as it moves.
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = _point_tex
	pm.emission_point_count = EntityModel.SOOT_POINTS
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, 0.22, 0)
	pm.damping_min = 0.4
	pm.damping_max = 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	pm.scale_min = 0.6
	pm.scale_max = 1.25
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 0.85))
	grow.add_point(Vector2(1.0, 1.4))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 0.9))
	ramp.add_point(0.6, Color(0.9, 0.85, 0.85, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.8, 0.8, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.2
	pm.turbulence_noise_speed = Vector3(0, 0.15, 0)
	pm.turbulence_influence_min = 0.08
	pm.turbulence_influence_max = 0.2
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = load(SHADER)
	_smoke_mat.set_shader_parameter("noise_tex", load(TEX_NOISE))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 0.75)
	quad.material = _smoke_mat
	_smoke = _particles(Tuning.SOOT_AURA, 3.4, pm, quad)
	# Flakes: a few black specks falling off it, turning over.
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	fm.emission_point_texture = _point_tex
	fm.emission_point_count = EntityModel.SOOT_POINTS
	fm.direction = Vector3.DOWN
	fm.spread = 40.0
	fm.initial_velocity_min = 0.05
	fm.initial_velocity_max = 0.2
	fm.gravity = Vector3(0, -0.45, 0)
	fm.damping_min = 0.3
	fm.damping_max = 0.6
	fm.scale_min = 0.5
	fm.scale_max = 1.3
	fm.turbulence_enabled = true
	fm.turbulence_noise_strength = 2.0
	fm.turbulence_noise_scale = 1.4
	fm.turbulence_influence_min = 0.1
	fm.turbulence_influence_max = 0.25
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.1, Color(1, 1, 1, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	fm.color_ramp = fade_tex
	var speck := QuadMesh.new()
	speck.size = Vector2(0.03, 0.03)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.03, 0.025, 0.025)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sm.alpha_scissor_threshold = 0.5
	# (Never a black square drifting across the lens: gone when close.)
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	sm.distance_fade_min_distance = 0.6
	sm.distance_fade_max_distance = 1.4
	speck.material = sm
	_flakes = _particles(20, 3.2, fm, speck)
	# The stain of shadow under it (only through the camcorder).
	_pool = Decal.new()
	_pool.texture_albedo = _tex[TEX_POOL]
	_pool.texture_orm = _matte()
	_pool.modulate = INK
	_pool.size = Vector3(POOL_SIZE, 1.0, POOL_SIZE)
	_pool.layers = Entity.LAYER_MASK
	_pool.cull_mask = Tuning.LAYER_WORLD
	_pool.normal_fade = 0.3
	_pool.visible = false
	add_child(_pool)


func _particles(amount: int, life: float, process: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.process_material = process
	p.draw_pass_1 = mesh
	p.local_coords = false  # the smoke stays behind as it moves
	p.layers = Entity.LAYER_MASK
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.emitting = false
	add_child(p)
	return p


## Every frame, from Entity._present: where it is and what it is doing.
## `body`: its 3D puppet (null with the drawing: the smoke rises from a box).
## `aura`: the smoke (always on while it is here: the camcorder's layer
## decides who sees it, and it is already boiling when you raise it).
## `marks`: it leaves prints (not while it is gone or coming apart).
func drive(delta: float, at: Vector3, aura: bool, marks: bool, frozen: bool, crawling: bool, ceiling: bool, enraged: bool,
		sneaking: bool, body: EntityModel) -> void:
	_clock += delta
	# --- the aura ---
	var on := aura
	if on != _smoke.emitting:
		_smoke.emitting = on
		_flakes.emitting = on
	_pool.visible = on
	if on:
		_update_points(at, body)
		# Filmed: everything around it stops too (the smoke hangs and curls,
		# barely moving); enraged, it pours off it.
		_smoke.speed_scale = move_toward(_smoke.speed_scale, 0.12 if frozen else 1.0, delta * 3.0)
		_flakes.speed_scale = _smoke.speed_scale
		_smoke.amount_ratio = 1.0 if enraged else (0.55 if sneaking else 0.8)
		_smoke_mat.set_shader_parameter("hold", 1.0 - _smoke.speed_scale)
		_pool_t += delta * _smoke.speed_scale
		var breathe := 1.0 + sin(_pool_t * 1.7) * 0.06 + sin(_pool_t * 0.63) * 0.05
		var s := POOL_SIZE * breathe * (1.25 if enraged else 1.0)
		_pool.size = Vector3(s, 1.0, s)
		if ceiling:
			# Spread on the ceiling round it, projected up.
			_pool.global_transform = Transform3D(Basis(Vector3.RIGHT, PI).rotated(Vector3.UP, _pool_t * 0.05),
					at + Vector3.UP * Level.HEIGHT)
		else:
			_pool.global_transform = Transform3D(Basis(Vector3.UP, _pool_t * 0.05), at)
		_pool.modulate.a = 0.85 if frozen else 0.7
	# --- the marks ---
	var moved := at - _last if _last != Vector3.INF else Vector3.ZERO
	moved.y = 0.0
	_last = at
	# (Not a jump: back from somewhere else, or a guest catching up with it
	# after it came back elsewhere, would draw a line of prints through walls.)
	if moved.length() > Tuning.SOOT_STEP * 1.5 or moved.length() / maxf(delta, 0.001) > 9.0 or not marks:
		_travel = 0.0
	elif not ceiling and moved.length() > 0.0005:
		_travel += moved.length()
		var step := Tuning.SOOT_HAND_STEP if crawling else Tuning.SOOT_STEP
		if _travel >= step:
			_travel = 0.0
			_side = -_side
			var fwd := moved.normalized()
			var right := fwd.cross(Vector3.UP)
			var spot := at + right * _side * (0.24 if crawling else 0.1) + fwd * _rng.randf_range(-0.04, 0.04)
			var turn := _rng.randf_range(-0.18, 0.18) + _side * (0.2 if crawling else 0.06)
			if crawling:
				_mark(TEX_HAND, HAND_SIZE, spot, fwd, turn, 0.85, Tuning.SOOT_SETTLE)
			else:
				_mark(TEX_FOOT, FOOT_SIZE, spot, fwd, turn, MARK_ALPHA * (0.7 if sneaking else 1.0), Tuning.SOOT_SETTLE)
	_update_in -= delta
	if _update_in <= 0.0:
		_update_in = UPDATE_EVERY
		_fade_marks()


## Where the flash tore it apart: a burnt splash on the floor (at once).
func scorch(at: Vector3) -> void:
	var fwd := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
	_mark(TEX_SCORCH, SCORCH_SIZE * _rng.randf_range(0.85, 1.1), at, fwd, 0.0, 1.0, 0.0)


func _mark(tex: String, size: Vector3, at: Vector3, fwd: Vector3, turn: float, alpha: float, settle: float) -> void:
	var ring: Array = _rings[tex]
	var entry: Array = ring[_next[tex]]
	_next[tex] = (int(_next[tex]) + 1) % ring.size()
	var d: Decal = entry[0]
	d.size = size
	# The texture's top (the toes, the fingers) forward: the decal's -Z.
	var basis := Basis.looking_at(fwd, Vector3.UP).rotated(Vector3.UP, turn)
	d.global_transform = Transform3D(basis, at)
	d.modulate = INK
	d.visible = true
	d.set_meta("alpha", alpha)
	entry[1] = _clock + settle
	entry[2] = Tuning.SOOT_LIFE


func _fade_marks() -> void:
	for entry: Array in _marks:
		var d: Decal = entry[0]
		if not d.visible:
			continue
		var age: float = _clock - float(entry[1])
		if age < 0.0:
			d.modulate.a = 0.0  # still settling
			continue
		var life: float = entry[2]
		if age >= life:
			d.visible = false
			continue
		# Settles in quickly, darkest while fresh, then thins out to nothing.
		var a := clampf(age / 0.8, 0.0, 1.0) * (1.0 - smoothstep(life * 0.35, life, age))
		d.modulate.a = a * float(d.get_meta("alpha", 1.0))


func _update_points(at: Vector3, body: EntityModel) -> void:
	if body and body.visible:
		body.soot_points(_points)
	else:
		# The drawing: from a tall box where its body would be.
		for i in _points.size():
			_points[i] = at + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.2, 2.2), _rng.randf_range(-0.25, 0.25))
	# The emitters go with it (their bounds too, or the camera would cull
	# them away from the origin); their points are relative to them.
	_smoke.global_position = at
	_flakes.global_position = at
	for i in _points.size():
		var p := _points[i] - at
		_point_img.set_pixel(i, 0, Color(p.x, p.y, p.z))
	_point_tex.update(_point_img)
