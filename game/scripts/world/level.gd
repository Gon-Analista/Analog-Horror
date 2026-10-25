class_name Level
extends Node3D
## The house, built from an ASCII map (HouseMap): walls, floors and ceilings
## merged into one mesh with a surface per material (few draw calls) and
## one trimesh collider; furniture boxes; ceiling lamps. Also owns the
## walkable grid the entity paths on and the named spots of the map.

const CELL := 1.0
const HEIGHT := 2.6
const LINTEL := 2.1
const WALL_TEX_WIDTH := 2.0  # metres covered by one repeat of a wall texture
const FURNITURE := {
	"k": {"h": 0.92, "mat": "counter"},
	"t": {"h": 0.75, "mat": "wood_dark"},
	"s": {"h": 0.8, "mat": "sofa"},
	"b": {"h": 0.55, "mat": "bed"},
	"w": {"h": 2.0, "mat": "wood_dark"},
	"V": {"h": 0.5, "mat": "wood_dark"},
}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LAMP_COLOR := Color(1.0, 0.72, 0.42)

var rows: PackedStringArray
var width := 0
var depth := 0
## char -> Array of cells (every char that is not wall or plain floor).
var spots := {}
var lamps: Array[FlickerLight] = []
var _walkable := PackedByteArray()
var _surfaces := {}  # material key -> SurfaceTool
var _mats := {}      # material key (+ "@tri") -> StandardMaterial3D


func build(p_rows: PackedStringArray) -> void:
	rows = p_rows
	depth = rows.size()
	width = rows[0].length()
	_walkable.resize(width * depth)
	for z in depth:
		for x in width:
			_build_cell(Vector2i(x, z))
	_commit_static()
	_build_furniture()


# --- grid queries ---------------------------------------------------------

func char_at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= depth:
		return "#"
	return rows[c.y][c.x]


func is_walkable(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= depth:
		return false
	return _walkable[c.y * width + c.x] == 1


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func nearest_walkable(c: Vector2i) -> Vector2i:
	if is_walkable(c):
		return c
	for d in DIRS:
		if is_walkable(c + d):
			return c + d
	return c


func spots_of(ch: String) -> Array:
	return spots.get(ch, [])


## Cells to walk from `from` to `to` (both excluded / included: the first
## element is the next cell). Empty if already there or unreachable. BFS on
## a ~300-cell grid: cheap enough to run several times per second.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or not is_walkable(from) or not is_walkable(to):
		return result
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == to:
			break
		for d in DIRS:
			var n := c + d
			if is_walkable(n) and not prev.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return result
	var back := to
	while back != from:
		result.push_front(back)
		back = prev[back]
	return result


# --- building -------------------------------------------------------------

func _is_solid(ch: String) -> bool:
	return ch == "#" or ch == "X"


func _floor_key(c: Vector2i) -> String:
	var ch := char_at(c)
	if ch == ",":
		return "floor_tile"
	if ch == ".":
		return "floor_wood"
	var tiles := 0
	var woods := 0
	for d in DIRS:
		var n := char_at(c + d)
		if n == ",":
			tiles += 1
		elif n == ".":
			woods += 1
	return "floor_tile" if tiles > woods else "floor_wood"


func _build_cell(c: Vector2i) -> void:
	var ch := char_at(c)
	if _is_solid(ch):
		for d in DIRS:
			if _is_solid(char_at(c + d)) or not _inside(c + d):
				continue
			var key := "door_exit" if ch == "X" else ("wall_tile" if _floor_key(c + d) == "floor_tile" else "wallpaper")
			_wall_face(c, d, 0.0, HEIGHT, key)
		if ch == "X":
			_add_spot(ch, c)
		return
	_walkable[c.y * width + c.x] = 0 if FURNITURE.has(ch) else 1
	if ch != "." and ch != ",":
		_add_spot(ch, c)
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	var x1 := x0 + CELL
	var z1 := z0 + CELL
	_quad(_floor_key(c), [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)],
			[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], Vector3.UP)
	var top := HEIGHT
	if ch == "D":
		top = LINTEL
		for d in DIRS:
			if not _is_solid(char_at(c + d)):
				_wall_face(c, d, LINTEL, HEIGHT, "wallpaper")
	_quad("ceiling", [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)],
			[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], Vector3.DOWN)
	if ch == "L" or ch == "l":
		_add_lamp(c, ch == "l")


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < depth


func _add_spot(ch: String, c: Vector2i) -> void:
	if not spots.has(ch):
		spots[ch] = []
	spots[ch].append(c)


## Vertical face on the side `d` of cell `c`, seen from the neighbour.
func _wall_face(c: Vector2i, d: Vector2i, y0: float, y1: float, key: String) -> void:
	var n := Vector3(d.x, 0, d.y)
	var mid := center(c) + n * CELL * 0.5
	var along := Vector3(-d.y, 0, d.x)
	var a := mid - along * CELL * 0.5
	var b := mid + along * CELL * 0.5
	var ua: float
	var ub: float
	if key == "door_exit":
		ua = 0.0
		ub = 1.0
	else:
		ua = (a.z if d.x != 0 else a.x) / WALL_TEX_WIDTH
		ub = (b.z if d.x != 0 else b.x) / WALL_TEX_WIDTH
	var va := 1.0 - y0 / HEIGHT
	var vb := 1.0 - y1 / HEIGHT
	_quad(key, [a + Vector3.UP * y0, b + Vector3.UP * y0, b + Vector3.UP * y1, a + Vector3.UP * y1],
			[Vector2(ua, va), Vector2(ub, va), Vector2(ub, vb), Vector2(ua, vb)], n)


func _st(key: String) -> SurfaceTool:
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = st
	return _surfaces[key]


## A quad given in order around its edge; wound clockwise seen from the
## side `n` points to (Godot's front face).
func _quad(key: String, p: Array, uv: Array, n: Vector3) -> void:
	var st := _st(key)
	var order := [0, 1, 2, 0, 2, 3]
	if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i: int in order:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func mat(key: String, triplanar := false) -> StandardMaterial3D:
	var cache_key := key + ("@tri" if triplanar else "")
	if _mats.has(cache_key):
		return _mats[cache_key]
	var m := StandardMaterial3D.new()
	var path := "res://assets/textures/%s.png" % key
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Level: missing %s (run tools/gen_textures.py and import)" % path)
		m.albedo_color = Color.MAGENTA
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.92
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE
	_mats[cache_key] = m
	return m


func _commit_static() -> void:
	var mesh := ArrayMesh.new()
	for key: String in _surfaces:
		(_surfaces[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat(key))
	_surfaces.clear()
	var mi := MeshInstance3D.new()
	mi.name = "House"
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "HouseCollision"
	body.collision_layer = Tuning.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


## Contiguous runs of the same furniture char along a row become one box.
func _build_furniture() -> void:
	var body := StaticBody3D.new()
	body.name = "Furniture"
	body.collision_layer = Tuning.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for z in depth:
		var x := 0
		while x < width:
			var ch := char_at(Vector2i(x, z))
			if not FURNITURE.has(ch):
				x += 1
				continue
			var x2 := x
			while char_at(Vector2i(x2 + 1, z)) == ch:
				x2 += 1
			var h: float = FURNITURE[ch].h
			var size := Vector3((x2 - x + 1) * CELL - 0.08, h, CELL - 0.08)
			var pos := Vector3((x + x2 + 1) * 0.5 * CELL, h * 0.5, (z + 0.5) * CELL)
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = size
			mi.mesh = box
			mi.material_override = mat(FURNITURE[ch].mat, true)
			mi.position = pos
			body.add_child(mi)
			var shape := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = size
			shape.shape = bs
			shape.position = pos
			body.add_child(shape)
			x = x2 + 1


func _add_lamp(c: Vector2i, dead: bool) -> void:
	var p := center(c)
	var fixture := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.13
	cyl.height = 0.1
	cyl.radial_segments = 8
	cyl.rings = 1
	fixture.mesh = cyl
	fixture.position = p + Vector3.UP * (HEIGHT - 0.05)
	fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(0.85, 0.8, 0.7)
	bulb.emission_enabled = true
	bulb.emission = LAMP_COLOR
	fixture.material_override = bulb
	add_child(fixture)
	var light := FlickerLight.new()
	light.position = p + Vector3.UP * (HEIGHT - 0.32)
	light.light_color = LAMP_COLOR
	light.omni_range = 5.0
	light.omni_attenuation = 1.4
	light.light_volumetric_fog_energy = 0.7
	light.shadow_enabled = not dead
	light.distance_fade_enabled = true
	light.distance_fade_begin = 14.0
	light.distance_fade_shadow = 9.0
	light.dead = dead
	light.bulb = bulb
	add_child(light)
	lamps.append(light)
