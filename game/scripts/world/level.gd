class_name Level
extends Node3D
## The house, built from a generated HouseLayout: walls, floors, ceilings,
## stairs, furniture, door frames, photos and papers all merged into one
## mesh with a surface per material (few draw calls), one trimesh collider
## for the architecture, a single-surface copy for shadows; ceiling lamps
## and moonlight through the windows. Grid questions (walkable, paths,
## stairs) are answered by the layout. Cells are Vector3i(x, floor, z).

const CELL := 1.0
const HEIGHT := 2.6                 # floor to ceiling
const FLOOR_H := 3.0                # floor to the next floor (0.4 m slab)
const LINTEL := 2.1
const TRANSOM_LINTEL := 1.9          # a door with a broken window over it is lower: a big gap above
const WALL_TEX_WIDTH := 2.0         # metres covered by one repeat of a wall texture
const TV_STAND_HEIGHT := 0.5
const FURNITURE_CHARS := HouseLayout.FURNITURE_CHARS
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LAMP_COLOR := Color(1.0, 0.72, 0.42)
const LAMP_SHADOW_RANGE := 6.5
const MOON_COLOR := Color(0.45, 0.56, 0.9)
const PHOTO_CHANCE := 0.1
const PAPER_CHANCE := 0.12

var layout: HouseLayout
var width := 0
var depth := 0
var floors := 1
## char -> Array of cells (every char that is not wall or plain floor).
var spots := {}
var lamps: Array[FlickerLight] = []
## Beds, tables and wardrobes you can hide in (Hide<n>, in build order).
var hide_spots: Array[HideSpot] = []
## Doors in the doorways (Door<n>, in build order); cell -> Door.
var doors: Array[Door] = []
var _door_at := {}
## cell -> {axis, face, hinge, transom, open}: decided before the walls.
var _door_plan := {}
var _surfaces := {}  # material key -> SurfaceTool
var _mats := {}      # material key -> StandardMaterial3D
var _decor := RandomNumberGenerator.new()
var _furniture_body: StaticBody3D
var _boards_body: StaticBody3D


func build(p_layout: HouseLayout, decor_seed := 14) -> void:
	layout = p_layout
	width = layout.width
	depth = layout.depth
	floors = layout.floors
	_decor.seed = decor_seed
	_plan_doors(decor_seed)
	_furniture_body = StaticBody3D.new()
	_furniture_body.name = "Furniture"
	_furniture_body.collision_layer = Tuning.LAYER_WORLD
	_furniture_body.collision_mask = 0
	for f in floors:
		for z in depth:
			for x in width:
				_build_cell(Vector3i(x, f, z))
	for s in layout.stairs:
		_build_stairs(s)
	_build_furniture()
	_build_decor()
	_commit()
	add_child(_furniture_body)
	_build_doors(decor_seed)


## Most doorways get a door, some left open; over some there is a transom
## window with its glass broken (the entity's way through). Decided before
## the walls are built; the same on every machine (from the seed).
func _plan_doors(seed_value: int) -> void:
	_door_plan.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 31
	for f in floors:
		for z in depth:
			for x in width:
				var c := Vector3i(x, f, z)
				if char_at(c) != "D":
					continue
				var axis := Vector2i(1, 0) if not _is_solid(char_at(_n(c, Vector2i(1, 0)))) else Vector2i(0, 1)
				if rng.randf() > Tuning.DOOR_CHANCE:
					continue
				_door_plan[c] = {"axis": axis, "face": 1 if rng.randf() < 0.5 else -1, "hinge": 1 if rng.randf() < 0.5 else -1,
						"transom": rng.randf() < Tuning.TRANSOM_CHANCE, "open": rng.randf() < Tuning.DOOR_OPEN_CHANCE}
	# Most have the window, but at least one is a whole door (to shut
	# yourself in behind).
	var solid := _door_plan.keys().filter(func(c: Vector3i) -> bool: return not _door_plan[c].transom)
	if solid.is_empty() and _door_plan.size() > 1:
		var keys := _door_plan.keys()
		_door_plan[keys[rng.randi() % keys.size()]].transom = false


func _build_doors(_seed_value: int) -> void:
	for c: Vector3i in _door_plan:
		var plan: Dictionary = _door_plan[c]
		var door := Door.new()
		door.name = "Door%d" % doors.size()
		door.setup(c, plan.axis, plan.face, plan.hinge, plan.transom, plan.open)
		add_child(door)
		doors.append(door)
		_door_at[c] = door


## The top of the doorway at `c` (lower with a transom over it).
func door_lintel(c: Vector3i) -> float:
	return TRANSOM_LINTEL if _door_plan.get(c, {}).get("transom", false) else LINTEL


## Over the door, the wall is open: a transom window, its frame and the
## last teeth of glass in it; the sill on top of the lintel.
func _add_transom(c: Vector3i, plan: Dictionary) -> void:
	var base := c.y * FLOOR_H
	var axis: Vector2i = plan.axis
	var n := Vector3(axis.x, 0, axis.y) * int(plan.face)
	var across := Vector3(-axis.y, 0, axis.x)
	var face := center(c) + n * (CELL * 0.5 + 0.02)
	var y0 := TRANSOM_LINTEL + 0.1
	var y1 := HEIGHT - 0.06
	var h := y1 - y0
	var thin := func(l: float, d: float, hh: float) -> Vector3:
		return Vector3(l, hh, d) if absf(across.x) > 0.5 else Vector3(d, hh, l)
	# The sill (seen from the room it is the top of the lintel), the top rail
	# and the stiles of the window.
	_box("wood_trim", center(c) + Vector3.UP * (base + TRANSOM_LINTEL + 0.05) - Vector3.UP * base * 0.0, thin.call(CELL, CELL, 0.1))
	_box("wood_trim", face + Vector3.UP * (base + y1 + 0.03), thin.call(CELL, 0.07, 0.06))
	for k: float in [-1.0, 1.0]:
		_box("wood_trim", face + across * k * (CELL * 0.5 - 0.04) + Vector3.UP * (base + y0 + h * 0.5), thin.call(0.08, 0.07, h))
	# Teeth of glass left in the corners.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.8, 0.85, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.3
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[-1.0, 0.0], [1.0, 0.0], [-1.0, 1.0], [1.0, 1.0]]
	for corner: Array in corners:
		if _decor.randf() < 0.6:
			continue  # most of the glass is gone
		var sx: float = corner[0]
		var sy: float = corner[1]
		var cx := face + across * sx * (CELL * 0.5 - 0.08) + Vector3.UP * (base + (y0 if sy == 0.0 else y1))
		var a := cx + across * -sx * _decor.randf_range(0.15, 0.35)
		var b := cx + Vector3.UP * (1.0 if sy == 0.0 else -1.0) * _decor.randf_range(0.12, h * 0.8)
		var m := cx + across * -sx * _decor.randf_range(0.05, 0.15) + Vector3.UP * (1.0 if sy == 0.0 else -1.0) * _decor.randf_range(0.05, 0.12)
		for p in [cx, a, m, cx, m, b]:
			st.set_normal(n)
			st.add_vertex(p)
	var shards := MeshInstance3D.new()
	shards.mesh = st.commit()
	shards.material_override = glass
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shards)


func door_at(c: Vector3i) -> Door:
	return _door_at.get(c)


# --- grid queries (the layout answers) ------------------------------------------

func char_at(c: Vector3i) -> String:
	return layout.char_at(c)


func is_walkable(c: Vector3i) -> bool:
	return layout.is_walkable(c)


func cell_of(p: Vector3) -> Vector3i:
	var f := clampi(floori((p.y + 0.8) / FLOOR_H), 0, floors - 1)
	return Vector3i(floori(p.x / CELL), f, floori(p.z / CELL))


func center(c: Vector3i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, c.y * FLOOR_H, (c.z + 0.5) * CELL)


func nearest_walkable(c: Vector3i) -> Vector3i:
	return layout.nearest_walkable(c)


func path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	return layout.path(from, to)


func spots_of(ch: String) -> Array:
	return spots.get(ch, [])


## Dev: a straight run of `length` walkable cells on the ground floor
## (start, direction), for tests that need room in front of them.
func find_line(length: int) -> Array:
	for z in range(depth - 1, -1, -1):  # from the front: the hallway first
		for x in width:
			for d in DIRS:
				var ok := true
				for i in length:
					if not is_walkable(Vector3i(x + d.x * i, 0, z + d.y * i)):
						ok = false
						break
				if ok:
					return [Vector3i(x, 0, z), d]
	return []


## Only the working lamp nearest the viewer casts shadows: an omni shadow
## re-renders the house six times, so far lamps would cost hundreds of draw
## calls for shadows nobody sees (dev_guidelines §9).
## On a flight of stairs: the end (bottom or top cell) nearer in height;
## NO_CELL-like (-1) when not on stairs.
func stair_end_near(p: Vector3) -> Vector3i:
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	for s in layout.stairs:
		for c: Vector2i in s.cells:
			if c.x == x and c.y == z and p.y > 0.15 and p.y < FLOOR_H - 0.15:
				return s.top if p.y > FLOOR_H * 0.5 else s.bottom
	return Vector3i(-1, -1, -1)


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


# --- cells ------------------------------------------------------------------

func _is_solid(ch: String) -> bool:
	return HouseLayout.is_solid_char(ch)


func _n(c: Vector3i, d: Vector2i) -> Vector3i:
	return c + Vector3i(d.x, 0, d.y)


func _floor_key(c: Vector3i) -> String:
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
		var n := char_at(_n(c, d))
		if n == ",":
			tiles += 1
		elif n == "." or n == "r":
			woods += 1
	return "floor_tile" if tiles > woods else "floor_wood"


func _wall_key(open_cell: Vector3i) -> String:
	if _floor_key(open_cell) == "floor_tile":
		return "wall_tile"
	match layout.room_type_at(open_cell):
		"kid", "playroom":
			return "wallpaper_kid"
		"bedroom", "sewing":
			return "wallpaper_bed"
		"study":
			return "wallpaper_study"
	return "wallpaper"


func _build_cell(c: Vector3i) -> void:
	var ch := char_at(c)
	var base := c.y * FLOOR_H
	if _is_solid(ch):
		for d in DIRS:
			var n := _n(c, d)
			if not layout.inside(n) or _is_solid(char_at(n)):
				continue
			var key := "door_exit" if ch == "X" else ("window" if ch == "W" else _wall_key(n))
			# Into the stairwell the wall goes up through the slab.
			var top := base + (FLOOR_H if char_at(n) == "S" and c.y == 0 else HEIGHT)
			_wall_face(c, d, base, top, key, base)
			if ch == "W":
				_add_moonlight(c, d)
			elif ch == "#" and key.begins_with("wallpaper") and _decor.randf() < PHOTO_CHANCE:
				_add_photo(c, d)
		if ch == "X":
			_add_spot(ch, c)
		return
	if ch != "." and ch != "," and ch != "r":
		_add_spot(ch, c)
	var x0 := c.x * CELL
	var z0 := c.z * CELL
	var x1 := x0 + CELL
	var z1 := z0 + CELL
	var uv := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
	if ch == "S":
		if c.y > 0:
			_stairwell_edges(c)
			# Open from the floor below up to this floor's ceiling.
			_quad("ceiling", [Vector3(x0, base + HEIGHT, z0), Vector3(x1, base + HEIGHT, z0), Vector3(x1, base + HEIGHT, z1), Vector3(x0, base + HEIGHT, z1)], uv, Vector3.DOWN)
		return
	_quad(_floor_key(c), [Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(x0, base, z1)], uv, Vector3.UP)
	var top := HEIGHT
	if ch == "D" or ch == "U":
		top = door_lintel(c)
		_add_door_frame(c)
		var plan: Dictionary = _door_plan.get(c, {})
		if plan.get("transom", false):
			# Open over the door (a broken transom window): up to the ceiling.
			top = HEIGHT
			_add_transom(c, plan)
		else:
			# The wall above the doorway, on both sides (without it you look
			# up through the gap into the floor above).
			for d in DIRS:
				var n := _n(c, d)
				if not _is_solid(char_at(n)) and char_at(n) != "S":
					_wall_face(c, d, base + LINTEL, base + HEIGHT, _wall_key(n), base)
		if ch == "U":
			_add_boards(c)
	_quad("ceiling", [Vector3(x0, base + top, z0), Vector3(x1, base + top, z0), Vector3(x1, base + top, z1), Vector3(x0, base + top, z1)], uv, Vector3.DOWN)
	if ch == "L" or ch == "l":
		_add_lamp(c, ch == "l")
	if (ch == "." or ch == "r") and _decor.randf() < PAPER_CHANCE:
		_add_papers(c)


func _add_spot(ch: String, c: Vector3i) -> void:
	if not spots.has(ch):
		spots[ch] = []
	spots[ch].append(c)


## Vertical face on the side `d` of cell `c`, seen from the neighbour, from
## height y0 to y1 (world); `base` is the floor the texture starts at.
func _wall_face(c: Vector3i, d: Vector2i, y0: float, y1: float, key: String, base: float) -> void:
	var n := Vector3(d.x, 0, d.y)
	var mid := Vector3((c.x + 0.5) * CELL, 0.0, (c.z + 0.5) * CELL) + n * CELL * 0.5
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
	var va := 1.0 - (y0 - base) / HEIGHT
	var vb := 1.0 - (y1 - base) / HEIGHT
	_quad(key, [a + Vector3.UP * y0, b + Vector3.UP * y0, b + Vector3.UP * y1, a + Vector3.UP * y1],
			[Vector2(ua, va), Vector2(ub, va), Vector2(ub, vb), Vector2(ua, vb)], n)


# --- stairs ------------------------------------------------------------------------

## A wooden flight on the ground floor (three steps per cell) with a smooth
## ramp as its collision, so walking up feels right.
func _build_stairs(s: Dictionary) -> void:
	var cells: Array = s.cells
	var d: Vector2i = s.dir
	var run := cells.size() * CELL
	var steps := cells.size() * 3
	var rise := FLOOR_H / steps
	var tread := run / steps
	var first: Vector2i = cells[0]
	var start := Vector3(first.x * CELL, 0.0, first.y * CELL)
	var dv := Vector3(d.x, 0, d.y)
	var across := Vector3(absi(d.y), 0, absi(d.x))
	for k in steps:
		var h := (k + 1) * rise
		var along_mid := (k + 0.5) * tread
		var c := start + across * 0.5 * CELL + dv * along_mid
		if d.x < 0 or d.y < 0:
			c = start + Vector3(CELL, 0, CELL) - across * 0.5 * CELL + dv * along_mid
		c.y = h * 0.5
		var size := across * (CELL - 0.04) + Vector3(absf(dv.x), 0, absf(dv.z)) * tread + Vector3.UP * h
		_box("wood_dark", c, size)
		_box("floor_wood", Vector3(c.x, h - 0.015, c.z), Vector3(size.x, 0.03, size.z) + Vector3(absf(dv.x), 0, absf(dv.z)) * 0.02)
	# Collision: one slab along the slope, through the front edge of every
	# tread (one tread earlier, so it meets the floor), so the body glides
	# up instead of catching on each riser.
	var angle := atan2(FLOOR_H, run)
	var length := sqrt(run * run + FLOOR_H * FLOOR_H)
	start -= dv * tread
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.12, CELL - 0.04) if d.x != 0 else Vector3(CELL - 0.04, 0.12, length)
	shape.shape = box
	var mid := start + across * 0.5 * CELL + dv * run * 0.5 + Vector3.UP * FLOOR_H * 0.5
	if d.x != 0:
		shape.rotation.z = angle * d.x
	else:
		shape.rotation.x = -angle * d.y
	shape.position = mid - shape.basis.y * 0.06
	_furniture_body.add_child(shape)


## Around the opening upstairs: the edge of the slab seen from below and a
## railing so nobody walks into the hole (except down the stairs).
func _stairwell_edges(c: Vector3i) -> void:
	var base := c.y * FLOOR_H
	for d in DIRS:
		var n := _n(c, d)
		var ch := char_at(n)
		if _is_solid(ch) or ch == "S":
			continue
		# The slab edge, from the ceiling below up to this floor.
		_wall_face(n, -d, base - (FLOOR_H - HEIGHT), base, "ceiling", base - (FLOOR_H - HEIGHT))
		var landing := false
		for s in layout.stairs:
			if s.top == n:
				landing = true
		if landing:
			continue
		var nv := Vector3(d.x, 0, d.y)
		var along := Vector3(absi(d.y), 0, absi(d.x))
		var edge := center(c) + nv * CELL * 0.5
		_box("wood_trim", edge + Vector3.UP * 0.92, along * CELL + Vector3(0.06, 0.06, 0.06) - along * 0.06)
		for k in 4:
			var post := edge + along * ((k + 0.5) / 4.0 - 0.5) * CELL + Vector3.UP * 0.45
			_box("wood_trim", post, Vector3(0.04, 0.9, 0.04))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = along * CELL + Vector3(0.1, 1.0, 0.1) - along * 0.1
		shape.shape = box
		shape.position = edge + Vector3.UP * 0.5
		_furniture_body.add_child(shape)


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
## bottom face is skipped (it rests on something) unless `bottom` (a bed
## frame, a table top: you can look at them from underneath).
func _box(key: String, c: Vector3, s: Vector3, bottom := false) -> void:
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
	if bottom:
		_quad(key, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)],
				[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], Vector3.DOWN)


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
	for f in floors:
		for z in depth:
			for x in width:
				var c := Vector3i(x, f, z)
				var ch := char_at(c)
				if not FURNITURE_CHARS.contains(ch) or seen.has(c):
					continue
				var rect := Rect2i(Vector2i(x, z), Vector2i.ONE)
				var stack: Array[Vector3i] = [c]
				seen[c] = true
				while not stack.is_empty():
					var cur: Vector3i = stack.pop_back()
					rect = rect.expand(Vector2i(cur.x, cur.z)).expand(Vector2i(cur.x, cur.z) + Vector2i.ONE)
					for d in DIRS:
						var n := _n(cur, d)
						if char_at(n) == ch and not seen.has(n):
							seen[n] = true
							stack.append(n)
				_furniture_piece(ch, rect, f)


func _furniture_piece(ch: String, r: Rect2i, f: int) -> void:
	var m := 0.04
	var base := f * FLOOR_H
	var x0 := r.position.x * CELL + m
	var z0 := r.position.y * CELL + m
	var x1 := r.end.x * CELL - m
	var z1 := r.end.y * CELL - m
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var sx := x1 - x0
	var sz := z1 - z0
	var height := 0.9
	var up := Vector3.UP * base
	match ch:
		"s":
			_sofa(r, cx, cz, sx, sz, x0, z0, x1, z1, up)
		"b":
			var head := _bed_head(r, f)
			height = 0.55
			# On legs, with a dark gap underneath: room to crawl in.
			_box("wood_dark", Vector3(cx, 0.3, cz) + up, Vector3(sx, 0.12, sz), true)
			for lx: float in [x0 + 0.05, x1 - 0.05]:
				for lz: float in [z0 + 0.05, z1 - 0.05]:
					_box("wood_dark", Vector3(lx, 0.12, lz) + up, Vector3(0.07, 0.24, 0.07))
			_box("linen", Vector3(cx, 0.4, cz) + up, Vector3(sx - 0.06, 0.08, sz - 0.06))  # the mattress
			# The blanket, hanging over the sides, folded back at the head.
			# (It stops short of the footboard, and every piece differs a little
			# in size from its neighbours: faces that coincide flicker.)
			var length := sz if head.y != 0 else sx
			var to_head := Vector3(head.x, 0, head.y)
			var cover := length * 0.8 - 0.1
			var blanket_c := _edge(cx, cz, sx, sz, -head, cover, 0.46) + to_head * 0.1
			_box("bed", blanket_c + up, _edge_size(sx + 0.03, sz + 0.03, -head, cover, 0.07))
			_box("bed", blanket_c + Vector3(0, -0.1, 0) + up, _edge_size(sx + 0.05, sz + 0.05, -head, cover - 0.01, 0.13), true)
			# Pillows (two on a double bed), the headboard and a low footboard.
			var across := Vector2i(absi(head.y), absi(head.x))
			var wide := sx if head.y != 0 else sz
			var pillows := 2 if wide > 1.4 else 1
			for k in pillows:
				var off := (k - (pillows - 1) * 0.5) * wide / pillows
				var pc := _edge(cx, cz, sx, sz, head, 0.36, 0.5) + Vector3(across.x, 0, across.y) * off
				_box("linen", pc + up, _edge_size(wide / pillows - 0.12 if across.x != 0 else 0.3, wide / pillows - 0.12 if across.y != 0 else 0.3, head, 0.3, 0.11))
			# Head and foot boards a touch proud of the frame (not flush with it).
			_box("wood_dark", _edge(cx, cz, sx + 0.02, sz + 0.02, head, 0.08, 0.5) + up, _edge_size(sx + 0.02, sz + 0.02, head, 0.08, 1.0))
			_box("wood_trim", _edge(cx, cz, sx + 0.04, sz + 0.04, head, 0.1, 1.02) + up, _edge_size(sx + 0.04, sz + 0.04, head, 0.1, 0.05))
			_box("wood_dark", _edge(cx, cz, sx + 0.02, sz + 0.02, -head, 0.06, 0.32) + up, _edge_size(sx + 0.02, sz + 0.02, -head, 0.06, 0.64))
		"t":
			height = 0.78
			_box("wood_dark", Vector3(cx, 0.75, cz) + up, Vector3(sx, 0.06, sz), true)
			_box("wood_trim", Vector3(cx, 0.785, cz) + up, Vector3(sx - 0.02, 0.01, sz - 0.02))  # the worn top
			for lx: float in [x0 + 0.08, x1 - 0.08]:
				for lz: float in [z0 + 0.08, z1 - 0.08]:
					_box("wood_dark", Vector3(lx, 0.36, lz) + up, Vector3(0.07, 0.72, 0.07))
			# The apron under the top, between the legs.
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_box("wood_dark", _edge(cx, cz, sx - 0.16, sz - 0.16, d, 0.03, 0.66) + up, _edge_size(sx - 0.16, sz - 0.16, d, 0.03, 0.1))
		"k":
			height = 0.92
			var front := -_against_wall(r, f)
			_box("wood_dark", Vector3(cx, 0.47, cz) + up, Vector3(sx - 0.04, 0.78, sz - 0.04))
			_box("plastic", Vector3(cx, 0.04, cz) + up - Vector3(front.x, 0, front.y) * 0.05, Vector3(sx - 0.14, 0.08, sz - 0.14))  # toe kick
			_box("counter", Vector3(cx, 0.89, cz) + up, Vector3(sx + 0.03, 0.06, sz + 0.03))
			_cabinet_doors(r, front, cx, cz, sx, sz, 0.12, 0.8, up, true)
		"w":
			height = 2.0
			var front := -_against_wall(r, f)
			_box("wood_dark", Vector3(cx, 1.03, cz) + up, Vector3(sx, 1.94, sz))
			_box("plastic", Vector3(cx, 0.04, cz) + up, Vector3(sx - 0.06, 0.08, sz - 0.06))  # plinth
			_box("wood_trim", Vector3(cx, 2.02, cz) + up, Vector3(sx + 0.04, 0.05, sz + 0.04))
			_box("wood_trim", Vector3(cx, 2.06, cz) + up, Vector3(sx + 0.07, 0.03, sz + 0.07))  # the crown
			_cabinet_doors(r, front, cx, cz, sx, sz, 0.12, 1.96, up, false)
		"V":
			height = TV_STAND_HEIGHT
			var front := -_against_wall(r, f)
			_box("wood_dark", Vector3(cx, TV_STAND_HEIGHT - 0.03, cz) + up, Vector3(sx, 0.06, sz))
			_box("wood_dark", Vector3(cx, 0.03, cz) + up, Vector3(sx, 0.06, sz))
			for k: int in [-1, 1]:  # the sides
				var side := Vector2i(-front.y, front.x) * k
				_box("wood_dark", _edge(cx, cz, sx, sz, side, 0.05, TV_STAND_HEIGHT * 0.5) + up, _edge_size(sx, sz, side, 0.05, TV_STAND_HEIGHT))
			_box("wood_dark", _edge(cx, cz, sx, sz, -front, 0.03, TV_STAND_HEIGHT * 0.5) + up, _edge_size(sx, sz, -front, 0.03, TV_STAND_HEIGHT))
			# A VCR on the shelf, its clock blinking 12:00 in the dark.
			var vcr := Vector3(cx, 0.1, cz) + Vector3(front.x, 0, front.y) * 0.03
			_box("plastic", vcr + up, Vector3(0.36 if front.y != 0 else 0.26, 0.08, 0.26 if front.y != 0 else 0.36))
			var led := OmniLight3D.new()
			led.light_color = Color(0.3, 1.0, 0.5)
			led.light_energy = 0.08
			led.omni_range = 0.35
			led.position = vcr + up + Vector3(front.x, 0, front.y) * 0.16
			add_child(led)
		"c":
			# One stack of boxes per cell (side by side they stay apart).
			height = 0.5
			for c in _cells_of(r, f):
				var bx := center(c).x
				var bz := center(c).z
				var ox := _decor.randf_range(-0.12, 0.12)
				var oz := _decor.randf_range(-0.12, 0.12)
				_box("cardboard", Vector3(bx + ox, 0.25, bz + oz) + up, Vector3(0.62, 0.5, 0.5))
				_box("paper", Vector3(bx + ox, 0.503, bz + oz) + up, Vector3(0.62, 0.006, 0.08))  # tape across the flaps
				if _decor.randf() < 0.6:
					_box("cardboard", Vector3(bx - ox, 0.68, bz - oz) + up, Vector3(0.42, 0.36, 0.38))
					_box("paper", Vector3(bx - ox, 0.863, bz - oz) + up, Vector3(0.06, 0.006, 0.38))
					height = 0.86
		"h":
			height = 2.0
			_bookcase(r, f, cx, cz, sx, sz, up)
		"a":
			height = 0.62
			_bath(r, f, cx, cz, sx, sz, x0, z0, x1, z1, up)
		"m":
			# A fridge in the kitchen, a washing machine anywhere else.
			var fridge := layout.room_type_at(Vector3i(r.position.x, f, r.position.y)) == "kitchen"
			height = 1.75 if fridge else 0.88
			var front := -_against_wall(r, f)
			for c in _cells_of(r, f):
				_appliance(center(c), Vector3(front.x, 0, front.y), fridge)  # (center() is at its floor)
		"n":
			# The show's bear in the playroom; dress forms anywhere else.
			var bear := layout.room_type_at(Vector3i(r.position.x, f, r.position.y)) == "playroom"
			height = 0.98 if bear else 1.62
			for c in _cells_of(r, f):
				if bear:
					_bear(center(c), _toward_middle(c))
				else:
					_dress_form(center(c))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sx, height, sz)
	shape.shape = bs
	shape.position = Vector3(cx, base + height * 0.5, cz)
	_furniture_body.add_child(shape)
	if ch in ["b", "t", "w"]:
		_add_hide_spot(ch, r, f, Vector3(cx, base + height * 0.5, cz), bs.size)


func _cells_of(r: Rect2i, f: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector3i(x, f, z))
	return out


## From cell `c` towards the middle of its room, along x or z.
func _toward_middle(c: Vector3i) -> Vector3:
	var room := layout.room_at(c)
	if room < 0:
		return Vector3.FORWARD
	var rr: Rect2i = layout.rooms[room].rect
	var to := Vector2(rr.position) + Vector2(rr.size) * 0.5 - Vector2(c.x + 0.5, c.z + 0.5)
	if absf(to.x) > absf(to.y):
		return Vector3(signf(to.x), 0, 0)
	return Vector3(0, 0, signf(to.y) if to.y != 0.0 else 1.0)


## A bookcase: end panels, a back against the wall (books on both faces if
## it stands free, a spine down the middle), shelves a third of a metre
## apart (the rows of the books texture) and the books.
func _bookcase(r: Rect2i, f: int, cx: float, cz: float, sx: float, sz: float, up: Vector3) -> void:
	var wall := _wall_side(r, f)
	var faces: Array[Vector2i] = []
	if wall != Vector2i.ZERO:
		faces = [-wall]
	elif sx >= sz:
		faces = [Vector2i(0, 1), Vector2i(0, -1)]
	else:
		faces = [Vector2i(1, 0), Vector2i(-1, 0)]
	var along_x := faces[0].y != 0
	var ends: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0)]
	if not along_x:
		ends = [Vector2i(0, 1), Vector2i(0, -1)]
	for e in ends:
		_box("wood_dark", _edge(cx, cz, sx, sz, e, 0.04, 1.0) + up, _edge_size(sx, sz, e, 0.04, 2.0))
	_box("wood_trim", Vector3(cx, 2.01, cz) + up, Vector3(sx + 0.03, 0.03, sz + 0.03))
	if wall != Vector2i.ZERO:
		_box("wood_dark", _edge(cx, cz, sx, sz, wall, 0.03, 1.0) + up, _edge_size(sx, sz, wall, 0.03, 2.0))
	else:
		_box("wood_dark", Vector3(cx, 1.0, cz) + up, Vector3(0.03, 2.0, sz - 0.08) if not along_x else Vector3(sx - 0.08, 2.0, 0.03))
	var inner_x := sx - 0.09 if along_x else sx
	var inner_z := sz if along_x else sz - 0.09
	for k in 7:  # the bottom, five shelves, under the top
		var y := 0.04 if k == 0 else k / 3.0
		if k == 6:
			y = 1.97
		_box("wood_dark", Vector3(cx, y, cz) + up, Vector3(inner_x, 0.025, inner_z))
	var depth := (sz if along_x else sx) * (0.4 if faces.size() == 2 else 0.75)
	for face in faces:
		# Set back a little from the front edge of the shelves.
		var book := _edge(cx, cz, inner_x, inner_z - 0.04 if along_x else inner_z, face, depth, 1.0) if along_x \
				else _edge(cx, cz, inner_x - 0.04, inner_z, face, depth, 1.0)
		_box("books", book + up, _edge_size(inner_x, inner_z, face, depth, 1.9))


## A clawfoot bath: an enamel shell on brass feet, a skin of grey water
## left standing in it, the taps at the end against the wall.
func _bath(r: Rect2i, f: int, cx: float, cz: float, sx: float, sz: float, x0: float, z0: float, x1: float, z1: float, up: Vector3) -> void:
	var head := _bed_head(r, f)
	_box("enamel", Vector3(cx, 0.15, cz) + up, Vector3(sx - 0.06, 0.06, sz - 0.06), true)
	for d in DIRS:
		# (Each side a touch different in height and the ends a touch short:
		# coinciding faces flicker.)
		var h := 0.48 if d.x != 0 else 0.49
		var ex := sx - (0.004 if d.y != 0 else 0.0)
		var ez := sz - (0.004 if d.x != 0 else 0.0)
		_box("enamel", _edge(cx, cz, ex, ez, d, 0.07, 0.12 + h * 0.5) + up, _edge_size(ex, ez, d, 0.07, h))
	_box("plastic", Vector3(cx, 0.3, cz) + up, Vector3(sx - 0.14, 0.02, sz - 0.14))  # the water
	for lx: float in [x0 + 0.14, x1 - 0.14]:
		for lz: float in [z0 + 0.14, z1 - 0.14]:
			_box("brass", Vector3(lx, 0.06, lz) + up, Vector3(0.07, 0.12, 0.07))
	var taps := _edge(cx, cz, sx, sz, head, 0.12, 0.7)
	_box("brass", taps + up, Vector3(0.05, 0.14, 0.05))
	_box("brass", taps + Vector3(-head.x, 0, -head.y) * 0.05 + Vector3(0, 0.06, 0) + up, Vector3(0.04, 0.03, 0.04) + Vector3(absf(head.x), 0, absf(head.y)) * 0.08)


## A 1980s fridge (two doors, a long handle) or a front-loading washer (the
## round window, the dial), white enamel gone yellow, facing `front`.
func _appliance(c: Vector3, front: Vector3, fridge: bool) -> void:
	var s := 0.7
	var h := 1.75 if fridge else 0.86
	var along := Vector3(absf(front.z), 0, absf(front.x))
	_box("enamel", c + Vector3(0, h * 0.5, 0), Vector3(s, h, s))
	var face := c + front * (s * 0.5 + 0.006)
	if fridge:
		_box("plastic", face + Vector3.UP * 1.22, _sized(along, s - 0.04, 0.012, 0.02))  # between the doors
		_box("plastic", face + front * 0.02 + along * (s * 0.5 - 0.09) + Vector3.UP * 1.48, _sized(along, 0.035, 0.03, 0.34))
		_box("plastic", face + front * 0.02 + along * (s * 0.5 - 0.09) + Vector3.UP * 0.86, _sized(along, 0.035, 0.03, 0.5))
	else:
		_box("plastic", face + Vector3.UP * 0.42, _sized(along, 0.38, 0.012, 0.38))  # the window, dark
		_box("enamel", face + front * 0.008 + Vector3.UP * 0.42, _sized(along, 0.2, 0.01, 0.2))  # its ring of light glass
		_box("plastic", face + Vector3.UP * 0.78, _sized(along, s - 0.06, 0.012, 0.1))  # the control strip
		_box("brass", face + front * 0.015 + along * 0.2 + Vector3.UP * 0.78, _sized(along, 0.06, 0.02, 0.06))  # the dial


## Vecinito as a big plush toy, the show's bear, slumped where a child left
## it: mustard fur, a pale snout, one button eye. The other is gone; a few
## threads hang where it was.
func _bear(c: Vector3, face: Vector3) -> void:
	var side := Vector3(absf(face.z), 0, absf(face.x))
	var lean := side * _decor.randf_range(-0.06, 0.06)
	_box("plush", c + Vector3.UP * 0.25 - face * 0.05, _sized(side, 0.48, 0.42, 0.46))  # the body
	_box("linen", c + Vector3.UP * 0.27 - face * 0.05 + face * 0.212, _sized(side, 0.3, 0.01, 0.3))  # the tummy
	for k: int in [-1, 1]:
		_box("plush", c + Vector3.UP * 0.09 + face * 0.2 + side * 0.13 * k, _sized(side, 0.16, 0.34, 0.16))  # the legs
		_box("linen", c + Vector3.UP * 0.09 + face * 0.372 + side * 0.13 * k, _sized(side, 0.12, 0.01, 0.12))  # the pads
		_box("plush", c + Vector3.UP * 0.3 + face * 0.02 + side * 0.3 * k, _sized(side, 0.12, 0.16, 0.34))  # the arms, limp
	var head := c + Vector3.UP * 0.66 + lean
	_box("plush", head, _sized(side, 0.42, 0.36, 0.36))
	for k: int in [-1, 1]:
		_box("plush", head + Vector3.UP * 0.22 + side * 0.16 * k, _sized(side, 0.12, 0.08, 0.12))  # the ears
	_box("linen", head + face * 0.2 + Vector3.DOWN * 0.07, _sized(side, 0.18, 0.06, 0.12))  # the snout
	_box("plastic", head + face * 0.235 + Vector3.DOWN * 0.04, _sized(side, 0.06, 0.012, 0.04))  # the nose
	_box("plastic", head + face * 0.185 + side * 0.1 + Vector3.UP * 0.05, _sized(side, 0.06, 0.02, 0.06))  # the eye left
	for k in 3:  # where the other eye was
		_box("linen", head + face * 0.183 - side * (0.09 + k * 0.015) + Vector3.UP * (0.03 - k * 0.025), _sized(side, 0.008, 0.008, 0.05))


## A tailor's dress form on a tripod: hips, waist, bust and shoulders in
## stained linen, a wooden knob for a neck. In the dark, in the viewfinder,
## somebody standing there.
func _dress_form(c: Vector3) -> void:
	var turn := _decor.randf() < 0.5
	var side := Vector3(1, 0, 0) if turn else Vector3(0, 0, 1)
	var other := Vector3(side.z, 0, side.x)
	_box("wood_dark", c + Vector3.UP * 0.02, _sized(side, 0.52, 0.05, 0.03))
	_box("wood_dark", c + Vector3.UP * 0.021, _sized(other, 0.52, 0.05, 0.031))
	_box("wood_dark", c + Vector3.UP * 0.5, Vector3(0.035, 0.96, 0.035))
	_box("dressform", c + Vector3.UP * 1.04, _sized(side, 0.34, 0.24, 0.2))   # the hips
	_box("dressform", c + Vector3.UP * 1.2, _sized(side, 0.26, 0.18, 0.13))   # the waist
	_box("dressform", c + Vector3.UP * 1.38, _sized(side, 0.36, 0.25, 0.23))  # the bust
	_box("dressform", c + Vector3.UP * 1.53, _sized(side, 0.42, 0.18, 0.07))  # the shoulders
	_box("wood_trim", c + Vector3.UP * 1.61, Vector3(0.08, 0.09, 0.08))   # the neck


## A sofa: wooden feet, the frame, seat cushions side by side, back
## cushions against the back, the armrests.
func _sofa(r: Rect2i, cx: float, cz: float, sx: float, sz: float, x0: float, z0: float, x1: float, z1: float, up: Vector3) -> void:
	var back := _away_from_tv(r)
	var side := Vector2i(-back.y, back.x)
	for lx: float in [x0 + 0.07, x1 - 0.07]:
		for lz: float in [z0 + 0.07, z1 - 0.07]:
			_box("wood_dark", Vector3(lx, 0.04, lz) + up, Vector3(0.06, 0.08, 0.06))
	_box("sofa", Vector3(cx, 0.17, cz) + up, Vector3(sx, 0.18, sz))
	_box("sofa", _edge(cx, cz, sx, sz, back, 0.2, 0.47) + up, _edge_size(sx, sz, back, 0.2, 0.78))
	for k: int in [-1, 1]:
		_box("sofa", _edge(cx, cz, sx, sz, side * k, 0.14, 0.33) + up, _edge_size(sx, sz, side * k, 0.14, 0.5))
	var length := sx if side.x != 0 else sz
	var depth := sz if back.y != 0 else sx
	var inner := length - 0.28
	var n := clampi(roundi(inner / 0.6), 1, 3)
	var along := Vector3(absf(side.x), 0, absf(side.y))
	var to_back := Vector3(back.x, 0, back.y)
	for k in n:
		var off := -inner * 0.5 + (k + 0.5) * inner / n
		var l := inner / n - 0.025
		var seat := Vector3(cx, 0.32, cz) + along * off - to_back * 0.1
		_box("sofa", seat + up, _sized(along, l, depth - 0.24, 0.12))
		var rest := Vector3(cx, 0.55, cz) + along * off + to_back * (depth * 0.5 - 0.27)
		_box("sofa", rest + up, _sized(along, l, 0.14, 0.34))


## Cabinet doors on the front of a counter or a wardrobe: panels standing
## a little proud, with a gap between them and a brass handle each.
func _cabinet_doors(r: Rect2i, front: Vector2i, cx: float, cz: float, sx: float, sz: float, y0: float, y1: float, up: Vector3, knobs: bool) -> void:
	var width := sx if front.y != 0 else sz
	var n := maxi(1, roundi(width / 0.5))
	var along := Vector3(absf(front.y), 0, absf(front.x))
	var out := Vector3(front.x, 0, front.y)
	var face := Vector3(cx, (y0 + y1) * 0.5, cz) + out * ((sz if front.y != 0 else sx) * 0.5 + 0.006)
	var door_w := width / n
	for k in n:
		var off := -width * 0.5 + (k + 0.5) * door_w
		var c := face + along * off
		var s := _sized(along, door_w - 0.03, 0.012, y1 - y0 - 0.03)
		_box("wood_trim", c + up, s)
		var hinge_left := k % 2 == 0
		var handle_off := (door_w * 0.5 - 0.06) * (1.0 if hinge_left else -1.0)
		var handle := c + along * handle_off + out * 0.012
		if knobs:
			handle.y = y1 - 0.12
			_box("brass", handle + up, _sized(along, 0.03, 0.02, 0.03))
		else:
			handle.y = (y0 + y1) * 0.5 + 0.1
			_box("brass", handle + up, _sized(along, 0.015, 0.02, 0.18))


## A box size given its length along `along` (an x or z unit vector).
func _sized(along: Vector3, l: float, d: float, h: float) -> Vector3:
	return Vector3(l, h, d) if along.x > 0.5 else Vector3(d, h, l)


## You crawl in from the free cell next to it nearest the middle of the
## room (not the bed's head, not a doorway).
func _add_hide_spot(ch: String, r: Rect2i, f: int, centre: Vector3, size: Vector3) -> void:
	var best := Vector3i(-1, -1, -1)
	var best_dir := Vector2i.ZERO
	var best_score := INF
	var room := layout.room_at(Vector3i(r.position.x, f, r.position.y))
	var mid := Vector2(r.get_center())
	if room >= 0:
		var rr: Rect2i = layout.rooms[room].rect
		mid = Vector2(rr.position) + Vector2(rr.size) * 0.5
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			for d in DIRS:
				var n := Vector3i(x + d.x, f, z + d.y)
				if r.has_point(Vector2i(n.x, n.z)) or not is_walkable(n) or char_at(n) == "D":
					continue
				var score := Vector2(n.x + 0.5, n.z + 0.5).distance_to(mid)
				if score < best_score:
					best_score = score
					best = n
					best_dir = d
	if best.x < 0:
		return
	var spot := HideSpot.new()
	spot.name = "Hide%d" % hide_spots.size()
	var kind := HideSpot.Kind.BED if ch == "b" else (HideSpot.Kind.TABLE if ch == "t" else HideSpot.Kind.WARDROBE)
	spot.setup(kind, centre, size, best, Vector3(best_dir.x, 0, best_dir.y))
	add_child(spot)
	hide_spots.append(spot)


## The hiding place whose access cell is `c` (the entity looks in from there).
func hide_spots_at(c: Vector3i) -> Array[HideSpot]:
	var out: Array[HideSpot] = []
	for s in hide_spots:
		if s.access == c:
			out.append(s)
	return out


## Centre of a slab of `thick` metres along side `d` of a footprint.
func _edge(cx: float, cz: float, sx: float, sz: float, d: Vector2i, thick: float, y: float) -> Vector3:
	return Vector3(cx + d.x * (sx - thick) * 0.5, y, cz + d.y * (sz - thick) * 0.5)


func _edge_size(sx: float, sz: float, d: Vector2i, thick: float, h: float) -> Vector3:
	return Vector3(thick if d.x != 0 else sx, h, thick if d.y != 0 else sz)


## The side facing away from the TV (a sofa's back), north if there is none.
func _away_from_tv(r: Rect2i) -> Vector2i:
	var tvs := layout.find_all("V")
	if tvs.is_empty():
		return Vector2i(0, -1)
	var to := Vector2(tvs[0].x, tvs[0].z) - Vector2(r.get_center())
	if absf(to.x) > absf(to.y):
		return Vector2i(-int(signf(to.x)), 0)
	return Vector2i(0, -int(signf(to.y)))


## A side whose cells all touch a wall (a bed's head).
## A bed's head: one of its short ends, the one against a wall if any.
func _bed_head(r: Rect2i, f: int) -> Vector2i:
	if r.size.x == r.size.y:
		return _against_wall(r, f)
	var ends: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1)]
	if r.size.x > r.size.y:
		ends = [Vector2i(-1, 0), Vector2i(1, 0)]
	for d in ends:
		var ok := true
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var edge := (d.x < 0 and x == r.position.x) or (d.x > 0 and x == r.end.x - 1) 						or (d.y < 0 and z == r.position.y) or (d.y > 0 and z == r.end.y - 1)
				if edge and not _is_solid(char_at(Vector3i(x + d.x, f, z + d.y))):
					ok = false
		if ok:
			return d
	return ends[0]


## The side against a wall, or ZERO if it stands free.
func _wall_side(r: Rect2i, f: int) -> Vector2i:
	var d := _against_wall(r, f)
	if d != Vector2i(0, -1):
		return d
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if z == r.position.y and not _is_solid(char_at(Vector3i(x, f, z - 1))):
				return Vector2i.ZERO
	return d


func _against_wall(r: Rect2i, f: int) -> Vector2i:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var ok := true
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var edge := (d.x < 0 and x == r.position.x) or (d.x > 0 and x == r.end.x - 1) \
						or (d.y < 0 and z == r.position.y) or (d.y > 0 and z == r.end.y - 1)
				if edge and not _is_solid(char_at(Vector3i(x + d.x, f, z + d.y))):
					ok = false
		if ok:
			return d
	return Vector2i(0, -1)


# --- details ----------------------------------------------------------------------

## Wooden frame round the doorway, on one side only (the door's, or the
## first open one): two frames a metre apart looked like a double door.
func _add_door_frame(c: Vector3i) -> void:
	var lintel := door_lintel(c)
	var side := Vector2i.ZERO
	if _door_plan.has(c):
		side = _door_plan[c].axis * int(_door_plan[c].face)
	for d in DIRS:
		if _is_solid(char_at(_n(c, d))):
			continue
		if side == Vector2i.ZERO:
			side = d
		if d != side:
			continue
		var n := Vector3(d.x, 0, d.y)
		var face := center(c) + n * (CELL * 0.5 + 0.02)
		var along := Vector3(-d.y, 0, d.x)
		for k: float in [-1.0, 1.0]:
			var post := face + along * k * (CELL * 0.5 - 0.04) + Vector3.UP * lintel * 0.5
			_box("wood_trim", post, Vector3(0.08 if d.y != 0 else 0.06, lintel, 0.06 if d.y != 0 else 0.08))
		var beam := face + Vector3.UP * (lintel + 0.05)
		_box("wood_trim", beam, Vector3(CELL if d.y != 0 else 0.06, 0.1, 0.06 if d.y != 0 else CELL))


## Planks nailed across a doorway from 1 m up: only crouching gets you
## under them. The entity does not care (it is a drawing).
func _add_boards(c: Vector3i) -> void:
	var d := Vector2i(1, 0) if not _is_solid(char_at(_n(c, Vector2i(1, 0)))) else Vector2i(0, 1)
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
	# (Its own layer: a body bumps into it, a look goes between the boards.)
	if _boards_body == null:
		_boards_body = StaticBody3D.new()
		_boards_body.name = "Boards"
		_boards_body.collision_layer = Tuning.LAYER_BOARDS
		_boards_body.collision_mask = 0
		add_child(_boards_body)
	_boards_body.add_child(shape)
	var hint := CrouchHint.new()
	var hint_shape := CollisionShape3D.new()
	hint_shape.shape = box
	hint.add_child(hint_shape)
	hint.position = shape.position
	add_child(hint)


## A framed family photo on the face `d` of wall cell `c`.
func _add_photo(c: Vector3i, d: Vector2i) -> void:
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
	for item: Dictionary in layout.decor:
		var c: Vector3i = item.cell
		var d: Vector2i = item.dir
		var n := -Vector3(d.x, 0, d.y)  # faces back into the room
		var mid := center(c) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.004) + Vector3.UP * 1.15
		_wall_sheet(item.tex, mid, n, 0.32, 0.4)


## A couple of loose sheets of paper on the floor.
func _add_papers(c: Vector3i) -> void:
	for i in _decor.randi_range(1, 2):
		var p := center(c) + Vector3(_decor.randf_range(-0.3, 0.3), 0.003 + i * 0.001, _decor.randf_range(-0.3, 0.3))
		var rot := _decor.randf() * TAU
		var ax := Vector3(cos(rot), 0, sin(rot)) * 0.105
		var az := Vector3(-sin(rot), 0, cos(rot)) * 0.14
		_quad("paper", [p - ax - az, p + ax - az, p + ax + az, p - ax + az],
				[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector3.UP)


func _add_lamp(c: Vector3i, dead: bool) -> void:
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
	# Each kind of room has its own light: warm amber where the family sat,
	# cold green-white tubes in the kitchen and bathroom, a dim reddish
	# glow in the bedrooms, a sickly yellow in the hall, a bare bulb in the
	# storeroom.
	var kind := layout.room_type_at(c)
	var tone := LAMP_COLOR
	var power := 1.0
	var tube := false
	match kind:
		"living":
			tone = Color(1.0, 0.64, 0.36)
			power = 1.1
		"kitchen", "bathroom":
			tone = Color(0.78, 0.95, 0.86)
			power = 0.95
			tube = true
		"bedroom", "kid", "playroom", "sewing":
			tone = Color(1.0, 0.5, 0.32)
			power = 0.7
		"laundry":
			tone = Color(0.78, 0.95, 0.86)
			power = 0.85
			tube = true
		"study", "dining":
			tone = Color(1.0, 0.66, 0.4)
			power = 0.75
		"hall":
			tone = Color(0.96, 0.82, 0.5)
			power = 0.8
		_:
			tone = Color(1.0, 0.76, 0.5)
			power = 0.6
	power *= _decor.randf_range(0.8, 1.15)
	bulb.emission = tone
	var light := FlickerLight.new()
	light.position = p + Vector3.UP * (HEIGHT - 0.32)
	light.light_color = tone
	light.omni_range = 4.2
	light.omni_attenuation = 1.6
	light.light_volumetric_fog_energy = 0.5
	light.base_energy = power
	light.fluorescent = tube
	# The cone of light down onto the floor: dark corners round it, and a
	# shaft through the dust in the air.
	var cone := SpotLight3D.new()
	cone.light_color = tone
	cone.spot_range = HEIGHT + 0.6
	cone.spot_angle = 52.0
	cone.spot_attenuation = 0.9
	cone.spot_angle_attenuation = 1.6
	cone.light_volumetric_fog_energy = 2.2
	cone.shadow_enabled = false
	cone.distance_fade_enabled = true
	cone.distance_fade_begin = 14.0
	cone.rotation.x = -PI / 2
	light.add_child(cone)
	light.spot = cone
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
func _add_moonlight(c: Vector3i, d: Vector2i) -> void:
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
