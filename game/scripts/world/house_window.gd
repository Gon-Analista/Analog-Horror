class_name HouseWindow
extends Area3D
## A sash window in an outside wall (a "W" cell of the house): a real
## opening through the wall, two over two panes, the night outside behind
## the glass. Level builds what does not move (the reveal, the box frame,
## the upper sash and its glass, the casing, the sill, the curtain rod);
## this node is the lower sash, which slides up, and the curtains, which
## the draught moves while it is open.
## E opens or closes it (Run asks the host, like a door): it scrapes and
## rattles (the entity hears it), and open, the wind comes in: a cold draught
## you hear from the room and the curtains lifting. Nobody climbs out (the
## opening is blocked: the way out is the front door).
## The area itself is what the player's ray finds (prompt()).

const SLIDE_TIME := 0.7
const COOLDOWN := 0.6
## The opening, from the floor of its storey; across, from its middle.
const SILL_Y := 0.82
const HEAD_Y := 2.06
const HALF_W := 0.42
## How deep the wall shows in the opening (the rest of the cell is outside).
const REVEAL := 0.3
## Each sash: from the frame's sill to the meeting rail (they overlap there).
const SASH_BOTTOM := SILL_Y + 0.04
const SASH_TOP := HEAD_Y - 0.05
const SASH_H := 0.6
const SASH_HALF_W := 0.37
## Depth into the wall of each sash's middle (the lower one runs in front).
const LOWER_DEPTH := 0.14
const UPPER_DEPTH := 0.2
const SASH_THICK := 0.04
## How far the lower sash goes up, open.
const LIFT := 0.48
## The curtains: from the rod down to the hem, beside the opening.
const ROD_Y := 2.24
const HEM_Y := 0.72
const CURTAIN_OUT := 0.1

var cell := Vector3i.ZERO
## From the wall into the room.
var inward := Vector2i(0, 1)
var is_open := false
## 0 closed .. 1 open (animated on every machine).
var amount := 0.0
var _cool := 0.0
var _sash: MeshInstance3D
var _curtains: MeshInstance3D
var _audio: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
## Which of the two curtain cuts (one is torn short).
var torn := false

static var _meshes := {}
static var _glass: StandardMaterial3D
static var _curtain_mat: ShaderMaterial


func setup(p_cell: Vector3i, p_inward: Vector2i, p_torn: bool) -> void:
	cell = p_cell
	inward = p_inward
	torn = p_torn


func _ready() -> void:
	add_to_group("windows")
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	var level := get_parent() as Level
	var n := Vector3(inward.x, 0, inward.y)
	# Local frame: +Z into the room, +X along the wall, the origin on the
	# room face of the wall at floor level.
	position = level.center(cell) + n * Level.CELL * 0.5
	basis = Basis.looking_at(-n, Vector3.UP)
	# The interact box: the opening, in front of the glass.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_W * 2.0, HEAD_Y - SILL_Y, 0.12)
	shape.shape = box
	shape.position = Vector3(0, (SILL_Y + HEAD_Y) * 0.5, -0.06)
	add_child(shape)
	_sash = MeshInstance3D.new()
	_sash.name = "Sash"
	_sash.mesh = sash_mesh(level)
	_sash.position = Vector3(0, 0, -LOWER_DEPTH)
	# No shadows from what moves: an omni shadow redraws every caster near
	# the lamp six times (the window frame's shadow is the moon's projector).
	_sash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sash)
	_curtains = MeshInstance3D.new()
	_curtains.name = "Curtains"
	_curtains.mesh = _curtain_mesh(torn)
	_curtains.material_override = _curtain_material()
	_curtains.position = Vector3(0, 0, CURTAIN_OUT)
	_curtains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_curtains)
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "Effects"
	_audio.unit_size = 3.0
	_audio.position = Vector3(0, 1.3, 0)
	add_child(_audio)
	_wind = AudioStreamPlayer3D.new()
	_wind.bus = "Effects"
	_wind.unit_size = 2.0
	_wind.position = Vector3(0, 1.4, 0)
	_wind.stream = Sfx.get_stream("wind_draft", true)
	add_child(_wind)
	_apply()


func prompt() -> String:
	if is_open:
		return tr("[E] Cerrar la ventana")
	return tr("[E] Abrir la ventana")


## Can it be opened or closed right now (not sliding, not just used)?
func ready_to_move() -> bool:
	return _cool <= 0.0 and (amount <= 0.0 or amount >= 1.0)


## Host -> everyone: open or close it.
@rpc("authority", "call_local", "reliable")
func set_open(on: bool) -> void:
	if on == is_open:
		return
	is_open = on
	_cool = COOLDOWN + SLIDE_TIME
	_audio.stream = Sfx.get_stream("window_slide" if on else "window_shut")
	_audio.volume_db = -3.0
	_audio.play()
	Sfx.heard("window_slide" if on else "window_shut", global_position + Vector3.UP * 1.3, -3.0, 3.0)


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	var target := 1.0 if is_open else 0.0
	if amount != target:
		amount = move_toward(amount, target, delta / SLIDE_TIME)
		_apply()


func _apply() -> void:
	# A sash sticks and then gives: slow at the start, quicker after.
	var k := amount * amount * (3.0 - 2.0 * amount)
	if _sash:
		_sash.position.y = LIFT * k
	if _curtains:
		_curtains.set_instance_shader_parameter("wind", k)
	if _wind:
		if amount > 0.0 and not _wind.playing:
			_wind.play(randf() * 2.0)
		elif amount <= 0.0 and _wind.playing:
			_wind.stop()
		_wind.volume_db = linear_to_db(maxf(k, 0.001)) - 6.0


# --- the pieces ------------------------------------------------------------------

## Glass: almost clear, grimy at the edges (glass.png), a glint of the
## flashlight. Both faces (you see it from the room and through the gap).
static func glass_material() -> StandardMaterial3D:
	if _glass:
		return _glass
	_glass = StandardMaterial3D.new()
	_glass.albedo_texture = load("res://assets/textures/glass.png")
	_glass.albedo_color = Color(0.85, 0.9, 1.0, 1.0)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_glass.roughness = 0.08
	_glass.metallic_specular = 0.9
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass


static func _curtain_material() -> ShaderMaterial:
	if _curtain_mat:
		return _curtain_mat
	_curtain_mat = ShaderMaterial.new()
	_curtain_mat.shader = load("res://shaders/curtain.gdshader")
	_curtain_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/curtain.png"))
	_curtain_mat.set_shader_parameter("rod_y", ROD_Y)
	_curtain_mat.set_shader_parameter("drop", ROD_Y - HEM_Y)
	return _curtain_mat


## A sash (stiles, rails, a glazing bar, two panes) in a window's local
## frame, its middle at z 0, from y0 up SASH_H. `lower`: a deeper bottom
## rail (the one you lift by). Into `frame_key`'s and the glass's tools.
static func add_sash(frame: Callable, pane: Callable, y0: float, lower: bool) -> void:
	var w := SASH_HALF_W
	var t := SASH_THICK
	var stile := 0.045
	var bottom := 0.07 if lower else 0.04
	var top := 0.04 if lower else 0.045
	var y1 := y0 + SASH_H
	for s: float in [-1.0, 1.0]:
		frame.call(Vector3(s * (w - stile * 0.5), (y0 + y1) * 0.5, 0), Vector3(stile, SASH_H, t))
	frame.call(Vector3(0, y0 + bottom * 0.5, 0), Vector3(w * 2.0 - stile * 2.0, bottom, t))
	frame.call(Vector3(0, y1 - top * 0.5, 0), Vector3(w * 2.0 - stile * 2.0, top, t))
	var gy0 := y0 + bottom
	var gy1 := y1 - top
	frame.call(Vector3(0, (gy0 + gy1) * 0.5, 0), Vector3(0.022, gy1 - gy0, t * 0.8))
	pane.call(-w + stile, -0.011, gy0, gy1)
	pane.call(0.011, w - stile, gy0, gy1)


## The lower sash, shared by every window (local frame, z 0 its middle).
static func sash_mesh(level: Level) -> ArrayMesh:
	if _meshes.has("sash"):
		return _meshes["sash"]
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame := func(c: Vector3, s: Vector3) -> void:
		_box_into(wood, c, s)
	var pane := func(x0: float, x1: float, y0: float, y1: float) -> void:
		_pane_into(glass, x0, x1, y0, y1, 0.0)
	add_sash(frame, pane, SASH_BOTTOM, true)
	var mesh := ArrayMesh.new()
	wood.generate_tangents()
	wood.commit(mesh)
	mesh.surface_set_material(0, level.mat("window_frame"))
	glass.commit(mesh)
	mesh.surface_set_material(1, glass_material())
	_meshes["sash"] = mesh
	return mesh


## Two curtain panels hanging from the rod in folds, either side of the
## opening; in the torn cut the right one is ripped short and ragged.
static func _curtain_mesh(p_torn: bool) -> ArrayMesh:
	var key := "curtains %s" % p_torn
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var folds := 8
	for side: float in [-1.0, 1.0]:
		var inner := HALF_W - 0.1
		var outer := HALF_W + 0.22
		for k in folds:
			var xa := lerpf(inner, outer, float(k) / folds) * side
			var xb := lerpf(inner, outer, float(k + 1) / folds) * side
			var za := 0.03 * (1.0 if k % 2 == 0 else -1.0)
			var zb := -za
			var ha := HEM_Y
			var hb := HEM_Y
			if p_torn and side > 0.0:
				ha = HEM_Y + 0.35 + 0.12 * absf(sin(k * 2.7))
				hb = HEM_Y + 0.35 + 0.12 * absf(sin((k + 1) * 2.7))
			var a0 := Vector3(xa, ha, za)
			var b0 := Vector3(xb, hb, zb)
			var a1 := Vector3(xa, ROD_Y, za)
			var b1 := Vector3(xb, ROD_Y, zb)
			var ua := float(k) / folds * (outer - inner)
			var ub := float(k + 1) / folds * (outer - inner)
			for v: Array in [[a0, Vector2(ua, ROD_Y - ha)], [b0, Vector2(ub, ROD_Y - hb)], [b1, Vector2(ub, 0)],
					[a0, Vector2(ua, ROD_Y - ha)], [b1, Vector2(ub, 0)], [a1, Vector2(ua, 0)]]:
				st.set_normal(Vector3.BACK)  # (two-sided: the shader lights both faces)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _box_into(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]
	for f: Array in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var mid := c + nrm * h
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var p := [mid - u * hu - v * hv, mid + u * hu - v * hv, mid + u * hu + v * hv, mid - u * hu + v * hv]
		var uv := [Vector2(0, hv * 2.0), Vector2(hu * 2.0, hv * 2.0), Vector2(hu * 2.0, 0), Vector2(0, 0)]
		var order := [0, 1, 2, 0, 2, 3]
		if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot(nrm) > 0.0:
			order = [0, 2, 1, 0, 3, 2]  # clockwise seen from outside (Godot's front)
		for i: int in order:
			st.set_normal(nrm)
			st.set_uv(uv[i] + Vector2(c.x + c.z, -c.y))
			st.add_vertex(p[i])


static func _pane_into(st: SurfaceTool, x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	var p := [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.BACK)
		st.set_uv(uv[i])
		st.add_vertex(p[i])
