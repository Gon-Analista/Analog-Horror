class_name Level
extends Node3D
## The house, built from an ASCII map (HouseMap): walls, floors, ceilings,
## furniture, door frames, photos and papers all merged into one mesh with
## a surface per material (few draw calls) and one trimesh collider for
## the architecture; ceiling lamps and moonlight through the windows. Also
## owns the walkable grid the entity paths on and the named map spots.

const CELL := 1.0
const HEIGHT := 2.6
const LINTEL := 2.1
const WALL_TEX_WIDTH := 2.0  # metres covered by one repeat of a wall texture
const TV_STAND_HEIGHT := 0.5
const FURNITURE_CHARS := "kstbwVc"
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LAMP_COLOR := Color(1.0, 0.72, 0.42)
const LAMP_SHADOW_RANGE := 6.5
const MOON_COLOR := Color(0.45, 0.56, 0.9)
const DECOR_SEED := 14  # level design, not per run: the same house every time
const PHOTO_CHANCE := 0.1
const PAPER_CHANCE := 0.12

var rows: PackedStringArray
var width := 0
var depth := 0
## char -> Array of cells (every char that is not wall or plain floor).
var spots := {}
var lamps: Array[FlickerLight] = []
var _walkable := PackedByteArray()
var _surfaces := {}  # material key -> SurfaceTool
var _mats := {}      # material key -> StandardMaterial3D
var _decor := RandomNumberGenerator.new()
var _furniture_body: StaticBody3D


func build(p_rows: PackedStringArray) -> void:
	rows = p_rows
	depth = rows.size()
	width = rows[0].length()
	_walkable.resize(width * depth)
	_decor.seed = DECOR_SEED
	_furniture_body = StaticBody3D.new()
	_furniture_body.name = "Furniture"
	_furniture_body.collision_layer = Tuning.LAYER_WORLD
	_furniture_body.collision_mask = 0
	for z in depth:
		for x in width:
			_build_cell(Vector2i(x, z))
	_build_furniture()
	_build_decor()
	_commit()
	add_child(_furniture_body)


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


## Only the working lamp nearest the viewer casts shadows: an omni shadow re-renders
## the house six times, so far lamps would cost hundreds of draw calls for
## shadows nobody sees (dev_guidelines §9).
func update_shadows(viewer: Vector3) -> void:
	var nearest: FlickerLight = null
	var best := LAMP_SHADOW_RANGE
	for lamp in lamps:
		var d := lamp.global_position.distance_to(viewer)
		if not lamp.dead and d < best:
			best = d
			nearest = lamp
	for lamp in lamps:
		lamp.shadow_enabled = lamp == nearest


func spots_of(ch: String) -> Array:
	return spots.get(ch, [])


## Cells to walk from `from` to `to` (the first element is the next cell).
## Empty if already there or unreachable. BFS on a ~300-cell grid: cheap
## enough to run several times per second.
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


# --- cells ------------------------------------------------------------------

func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < depth


func _is_solid(ch: String) -> bool:
	return ch == "#" or ch == "X" or ch == "W"


func _floor_key(c: Vector2i) -> String:
	var ch := char_at(c)
	if ch == ",":
		return "floor_tile"
	if ch == "r":
		return "rug"
	if ch == ".":
		return "floor_wood"
	var tiles := 0
	var woods := 0
	for d in DIRS:
		var n := char_at(c + d)
		if n == ",":
			tiles += 1
		elif n == "." or n == "r":
			woods += 1
	return "floor_tile" if tiles > woods else "floor_wood"


func _wall_key(open_cell: Vector2i) -> String:
	if _floor_key(open_cell) == "floor_tile":
		return "wall_tile"
	for key: String in HouseMap.ZONES:
		if (HouseMap.ZONES[key] as Rect2i).has_point(open_cell):
			return key
	return "wallpaper"


func _build_cell(c: Vector2i) -> void:
	var ch := char_at(c)
	if _is_solid(ch):
		for d in DIRS:
			if not _inside(c + d) or _is_solid(char_at(c + d)):
				continue
			var key := "door_exit" if ch == "X" else ("window" if ch == "W" else _wall_key(c + d))
			_wall_face(c, d, 0.0, HEIGHT, key)
			if ch == "W":
				_add_moonlight(c, d)
			elif ch == "#" and key.begins_with("wallpaper") and _decor.randf() < PHOTO_CHANCE:
				_add_photo(c, d)
		if ch == "X":
			_add_spot(ch, c)
		return
	_walkable[c.y * width + c.x] = 0 if FURNITURE_CHARS.contains(ch) else 1
	if ch != "." and ch != ",":
		_add_spot(ch, c)
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	var x1 := x0 + CELL
	var z1 := z0 + CELL
	_quad(_floor_key(c), [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)],
			[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], Vector3.UP)
	var top := HEIGHT
	if ch == "D" or ch == "U":
		top = LINTEL
		_add_door_frame(c)
		if ch == "U":
			_add_boards(c)
	_quad("ceiling", [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)],
			[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], Vector3.DOWN)
	if ch == "L" or ch == "l":
		_add_lamp(c, ch == "l")
	if (ch == "." or ch == "r") and _decor.randf() < PAPER_CHANCE:
		_add_papers(c)


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
	if key == "door_exit" or key == "window":
		ua = 0.0
		ub = 1.0
	else:
		ua = (a.z if d.x != 0 else a.x) / WALL_TEX_WIDTH
		ub = (b.z if d.x != 0 else b.x) / WALL_TEX_WIDTH
	var va := 1.0 - y0 / HEIGHT
	var vb := 1.0 - y1 / HEIGHT
	_quad(key, [a + Vector3.UP * y0, b + Vector3.UP * y0, b + Vector3.UP * y1, a + Vector3.UP * y1],
			[Vector2(ua, va), Vector2(ub, va), Vector2(ub, vb), Vector2(ua, vb)], n)


# --- geometry helpers -----------------------------------------------------------

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


## Axis-aligned box with world-space UVs (1 texture repeat per metre); the
## bottom face is skipped (it always rests on something).
func _box(key: String, c: Vector3, s: Vector3) -> void:
	var x0 := c.x - s.x * 0.5
	var x1 := c.x + s.x * 0.5
	var y0 := c.y - s.y * 0.5
	var y1 := c.y + s.y * 0.5
	var z0 := c.z - s.z * 0.5
	var z1 := c.z + s.z * 0.5
	_quad(key, [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)],
			[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], Vector3.UP)
	var side_x := [Vector2(z0, -y0), Vector2(z1, -y0), Vector2(z1, -y1), Vector2(z0, -y1)]
	_quad(key, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], side_x, Vector3.RIGHT)
	_quad(key, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], side_x, Vector3.LEFT)
	var side_z := [Vector2(x0, -y0), Vector2(x1, -y0), Vector2(x1, -y1), Vector2(x0, -y1)]
	_quad(key, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], side_z, Vector3.BACK)
	_quad(key, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], side_z, Vector3.FORWARD)


## A flat rectangle on a wall (seen from direction n), for photos and
## drawings; uv_rect picks part of the texture.
func _wall_sheet(key: String, mid: Vector3, n: Vector3, w: float, h: float, uv_rect := Rect2(0, 0, 1, 1)) -> void:
	var along := Vector3(n.z, 0, -n.x)  # the viewer's right
	var a := mid - along * w * 0.5
	var b := mid + along * w * 0.5
	var u0 := uv_rect.position.x
	var u1 := uv_rect.end.x
	var v0 := uv_rect.position.y
	var v1 := uv_rect.end.y
	_quad(key, [a - Vector3.UP * h * 0.5, b - Vector3.UP * h * 0.5, b + Vector3.UP * h * 0.5, a + Vector3.UP * h * 0.5],
			[Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)], n)


func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var path := "res://assets/textures/%s.png" % key
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Level: missing %s (run tools/gen_textures.py and import)" % path)
		m.albedo_color = Color.MAGENTA
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.92
	_mats[key] = m
	return m


func _commit() -> void:
	var arch := ArrayMesh.new()
	for key: String in _surfaces:
		(_surfaces[key] as SurfaceTool).commit(arch)
		arch.surface_set_material(arch.get_surface_count() - 1, mat(key))
	_surfaces.clear()
	var mi := MeshInstance3D.new()
	mi.name = "House"
	mi.mesh = arch
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Shadows are drawn from a copy merged into a single surface: every
	# shadow pass (six per omni lamp) is then one draw call, not one per
	# material.
	var merged := SurfaceTool.new()
	for i in arch.get_surface_count():
		merged.append_from(arch, i, Transform3D.IDENTITY)
	var caster := MeshInstance3D.new()
	caster.name = "HouseShadow"
	caster.mesh = merged.commit()
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(caster)
	var body := StaticBody3D.new()
	body.name = "HouseCollision"
	body.collision_layer = Tuning.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = arch.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


# --- furniture --------------------------------------------------------------------

## Each connected group of the same furniture char becomes one piece,
## shaped by its type; collision is one box per piece.
func _build_furniture() -> void:
	var seen := {}
	for z in depth:
		for x in width:
			var c := Vector2i(x, z)
			var ch := char_at(c)
			if not FURNITURE_CHARS.contains(ch) or seen.has(c):
				continue
			var rect := Rect2i(c, Vector2i.ONE)
			var stack: Array[Vector2i] = [c]
			seen[c] = true
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				rect = rect.expand(cur).expand(cur + Vector2i.ONE)
				for d in DIRS:
					if char_at(cur + d) == ch and not seen.has(cur + d):
						seen[cur + d] = true
						stack.append(cur + d)
			_furniture_piece(ch, rect)


func _furniture_piece(ch: String, r: Rect2i) -> void:
	var m := 0.04
	var x0 := r.position.x * CELL + m
	var z0 := r.position.y * CELL + m
	var x1 := r.end.x * CELL - m
	var z1 := r.end.y * CELL - m
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var sx := x1 - x0
	var sz := z1 - z0
	var height := 0.9
	match ch:
		"s":
			var back := _away_from_tv(r)
			height = 0.9
			_box("sofa", Vector3(cx, 0.21, cz), Vector3(sx, 0.42, sz))
			_box("sofa", _edge(cx, cz, sx, sz, back, 0.22, 0.45), _edge_size(sx, sz, back, 0.22, 0.9))
			var side := Vector2i(-back.y, back.x)
			for k: int in [-1, 1]:
				_box("sofa", _edge(cx, cz, sx, sz, side * k, 0.14, 0.31), _edge_size(sx, sz, side * k, 0.14, 0.62))
		"b":
			var head := _against_wall(r)
			height = 0.55
			_box("wood_dark", Vector3(cx, 0.16, cz), Vector3(sx, 0.32, sz))
			_box("bed", Vector3(cx, 0.4, cz), Vector3(sx - 0.06, 0.16, sz - 0.06))
			_box("paper", _edge(cx, cz, sx, sz, head, 0.35, 0.52), _edge_size(sx * 0.7, sz * 0.7, head, 0.3, 0.1))
			_box("wood_dark", _edge(cx, cz, sx, sz, head, 0.08, 0.5), _edge_size(sx, sz, head, 0.08, 1.0))
		"t":
			height = 0.78
			_box("wood_dark", Vector3(cx, 0.75, cz), Vector3(sx, 0.06, sz))
			for lx: float in [x0 + 0.08, x1 - 0.08]:
				for lz: float in [z0 + 0.08, z1 - 0.08]:
					_box("wood_dark", Vector3(lx, 0.36, lz), Vector3(0.07, 0.72, 0.07))
		"k":
			height = 0.92
			_box("wood_dark", Vector3(cx, 0.43, cz), Vector3(sx - 0.04, 0.86, sz - 0.04))
			_box("counter", Vector3(cx, 0.89, cz), Vector3(sx + 0.03, 0.06, sz + 0.03))
		"w":
			height = 2.0
			_box("wood_dark", Vector3(cx, 1.0, cz), Vector3(sx, 2.0, sz))
			_box("wood_trim", Vector3(cx, 2.02, cz), Vector3(sx + 0.04, 0.05, sz + 0.04))
		"V":
			height = TV_STAND_HEIGHT
			_box("wood_dark", Vector3(cx, TV_STAND_HEIGHT * 0.5, cz), Vector3(sx, TV_STAND_HEIGHT, sz))
		"c":
			height = 0.5
			var ox := _decor.randf_range(-0.12, 0.12)
			var oz := _decor.randf_range(-0.12, 0.12)
			_box("cardboard", Vector3(cx + ox, 0.25, cz + oz), Vector3(0.62, 0.5, 0.5))
			if _decor.randf() < 0.6:
				_box("cardboard", Vector3(cx - ox, 0.68, cz - oz), Vector3(0.42, 0.36, 0.38))
				height = 0.86
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sx, height, sz)
	shape.shape = bs
	shape.position = Vector3(cx, height * 0.5, cz)
	_furniture_body.add_child(shape)


## Centre of a slab of `thick` metres along side `d` of a footprint.
func _edge(cx: float, cz: float, sx: float, sz: float, d: Vector2i, thick: float, y: float) -> Vector3:
	return Vector3(cx + d.x * (sx - thick) * 0.5, y, cz + d.y * (sz - thick) * 0.5)


func _edge_size(sx: float, sz: float, d: Vector2i, thick: float, h: float) -> Vector3:
	return Vector3(thick if d.x != 0 else sx, h, thick if d.y != 0 else sz)


## The side facing away from the TV (a sofa's back), north if there is none.
func _away_from_tv(r: Rect2i) -> Vector2i:
	var tvs := spots_of("V")
	if tvs.is_empty():
		return Vector2i(0, -1)
	var to := Vector2(tvs[0]) - Vector2(r.get_center())
	if absf(to.x) > absf(to.y):
		return Vector2i(-int(signf(to.x)), 0)
	return Vector2i(0, -int(signf(to.y)))


## A side whose cells all touch a wall (a bed's head).
func _against_wall(r: Rect2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var ok := true
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				var edge := (d.x < 0 and x == r.position.x) or (d.x > 0 and x == r.end.x - 1) \
						or (d.y < 0 and z == r.position.y) or (d.y > 0 and z == r.end.y - 1)
				if edge and not _is_solid(char_at(c + d)):
					ok = false
		if ok:
			return d
	return Vector2i(0, -1)


# --- details ----------------------------------------------------------------------

## Wooden frame around both openings of a doorway.
func _add_door_frame(c: Vector2i) -> void:
	for d in DIRS:
		if _is_solid(char_at(c + d)):
			continue
		var n := Vector3(d.x, 0, d.y)
		var face := center(c) + n * (CELL * 0.5 + 0.02)
		var along := Vector3(-d.y, 0, d.x)
		for k: float in [-1.0, 1.0]:
			var post := face + along * k * (CELL * 0.5 - 0.04) + Vector3.UP * LINTEL * 0.5
			_box("wood_trim", post, Vector3(0.08 if d.y != 0 else 0.06, LINTEL, 0.06 if d.y != 0 else 0.08))
		var beam := face + Vector3.UP * (LINTEL + 0.05)
		_box("wood_trim", beam, Vector3(CELL if d.y != 0 else 0.06, 0.1, 0.06 if d.y != 0 else CELL))


## Planks nailed across a doorway from 1 m up: only crouching gets you
## under them. The entity does not care (it is a drawing).
func _add_boards(c: Vector2i) -> void:
	var d := Vector2i(1, 0) if not _is_solid(char_at(c + Vector2i(1, 0))) else Vector2i(0, 1)
	var across := Vector3(CELL if d.y != 0 else 0.04, 0, 0.04 if d.y != 0 else CELL)
	var mid := center(c)
	for k in 3:
		var h := 1.08 + k * 0.33 + _decor.randf_range(-0.04, 0.04)
		var w := 1.0 - (0.18 if k == 1 else 0.0)
		var size := Vector3(across.x * w if d.y != 0 else 0.04, 0.12, across.z * w if d.x != 0 else 0.04)
		_box("wood_trim" if k % 2 == 0 else "wood_dark", mid + Vector3.UP * h, size)
	var top := 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL if d.y != 0 else 0.12, LINTEL - top, 0.12 if d.y != 0 else CELL)
	shape.shape = box
	shape.position = mid + Vector3.UP * (top + (LINTEL - top) * 0.5)
	_furniture_body.add_child(shape)
	var hint := CrouchHint.new()
	var hint_shape := CollisionShape3D.new()
	hint_shape.shape = box
	hint.add_child(hint_shape)
	hint.position = shape.position
	add_child(hint)


## A framed family photo on the face `d` of wall cell `c`.
func _add_photo(c: Vector2i, d: Vector2i) -> void:
	var n := Vector3(d.x, 0, d.y)
	var along := Vector3(-d.y, 0, d.x)
	var mid := center(c) + n * (CELL * 0.5) + along * _decor.randf_range(-0.2, 0.2) + Vector3.UP * _decor.randf_range(1.35, 1.65)
	var w := _decor.randf_range(0.34, 0.46)
	var h := w * 1.25
	_box("wood_trim", mid + n * 0.02, Vector3(w if d.y != 0 else 0.04, h, 0.04 if d.y != 0 else w))
	var q := _decor.randi() % 4
	var uv := Rect2((q % 2) * 0.5, (q / 2) * 0.5, 0.5, 0.5)
	_wall_sheet("photos", mid + n * 0.041, n, w - 0.06, h - 0.06, uv)


func _build_decor() -> void:
	for item: Dictionary in HouseMap.DECOR:
		var c: Vector2i = item.cell
		var d: Vector2i = item.dir
		var n := -Vector3(d.x, 0, d.y)  # faces back into the room
		var mid := center(c) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.004) + Vector3.UP * 1.15
		_wall_sheet(item.tex, mid, n, 0.32, 0.4)


## A couple of loose sheets of paper on the floor.
func _add_papers(c: Vector2i) -> void:
	for i in _decor.randi_range(1, 2):
		var p := center(c) + Vector3(_decor.randf_range(-0.3, 0.3), 0.003 + i * 0.001, _decor.randf_range(-0.3, 0.3))
		var rot := _decor.randf() * TAU
		var ax := Vector3(cos(rot), 0, sin(rot)) * 0.105
		var az := Vector3(-sin(rot), 0, cos(rot)) * 0.14
		_quad("paper", [p - ax - az, p + ax - az, p + ax + az, p - ax + az],
				[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector3.UP)


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
	light.shadow_enabled = false  # turned on near the viewer: update_shadows()
	light.distance_fade_enabled = true
	light.distance_fade_begin = 14.0
	light.dead = dead
	light.bulb = bulb
	add_child(light)
	lamps.append(light)


## Cold moonlight falling through the window of wall cell `c` into the
## room on side `d`: a shadowless spot with the window frame as projector,
## so it costs little and draws a shaft in the fog.
func _add_moonlight(c: Vector2i, d: Vector2i) -> void:
	var n := Vector3(d.x, 0, d.y)
	var window := center(c) + n * CELL * 0.5
	var spot := SpotLight3D.new()
	spot.light_color = MOON_COLOR
	spot.light_energy = 1.6
	spot.spot_range = 7.0
	spot.spot_angle = 24.0
	spot.light_projector = load("res://assets/textures/window_cookie.png")
	spot.light_volumetric_fog_energy = 2.0
	spot.shadow_enabled = false
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 16.0
	add_child(spot)
	spot.global_position = window - n * 0.8 + Vector3.UP * 2.4
	spot.look_at(window + n * 2.2 + Vector3.UP * 0.1, Vector3.UP)
