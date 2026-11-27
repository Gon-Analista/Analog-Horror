class_name HouseLayout
extends RefCounted
## A generated house as data: one character grid per floor (same legend as
## before), the rooms (rect, floor, type), the stairs and the hand-placed
## decor. It also answers the grid questions (what is at a cell, can you
## walk it, how to get from one cell to another, stairs included), so the
## generator can validate a house before anything is built and the entity
## can path on it.
##   # wall · W window · X front door · D doorway · U boarded doorway
##   . wood · , tile · r rug · S stairs (floor 0: the flight; floor 1: the
##   opening above it) · k counter · t table · s sofa · b bed · w wardrobe
##   V television · c boxes · h bookcase / shelves · a bath · m fridge or
##   washer · n figure (a dress form; the show's bear in the playroom)
##   q studio camera on its pedestal (the station)
##   L lamp · l dead lamp · T tape · B battery · P player · E entity
## Cells are Vector3i(x, floor, z).

const FURNITURE_CHARS := "kstbwVchamnq"
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## What was generated: "house" (HouseGenerator, the first night) or
## "station" (StationGenerator, Canal 9's studios, the second night). The
## Level dresses the same grid differently for each.
var kind := "house"
var width := 0
var depth := 0
var floors := 1
## One PackedStringArray of rows per floor.
var grids: Array = []
## {floor: int, rect: Rect2i (interior cells), type: String}
var rooms: Array[Dictionary] = []
## Room index per cell (-1: none), one PackedInt32Array per floor.
var room_of: Array = []
## {bottom: Vector3i, top: Vector3i, cells: Array[Vector2i], dir: Vector2i}
## bottom: the floor-0 cell before the first step; top: the floor-1 landing.
var stairs: Array[Dictionary] = []
## {cell: Vector3i (the open cell it is seen from), dir: Vector2i (to the wall), tex: String}
var decor: Array[Dictionary] = []


func setup(w: int, d: int, f: int) -> void:
	width = w
	depth = d
	floors = f
	grids.clear()
	room_of.clear()
	for i in f:
		var rows := PackedStringArray()
		for z in d:
			rows.append("#".repeat(w))
		grids.append(rows)
		var ids := PackedInt32Array()
		ids.resize(w * d)
		ids.fill(-1)
		room_of.append(ids)


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.z >= 0 and c.x < width and c.z < depth and c.y >= 0 and c.y < floors


func char_at(c: Vector3i) -> String:
	if not inside(c):
		return "#"
	return (grids[c.y] as PackedStringArray)[c.z][c.x]


func set_char(c: Vector3i, ch: String) -> void:
	var rows: PackedStringArray = grids[c.y]
	var row := rows[c.z]
	rows[c.z] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


func room_at(c: Vector3i) -> int:
	if not inside(c):
		return -1
	return (room_of[c.y] as PackedInt32Array)[c.z * width + c.x]


func room_type_at(c: Vector3i) -> String:
	var r := room_at(c)
	return "" if r < 0 else str(rooms[r].type)


static func is_solid_char(ch: String) -> bool:
	return ch == "#" or ch == "X" or ch == "W"


## Somewhere you can stand (not wall, not furniture, not the stairs: those
## are crossed through the stair links).
func is_walkable(c: Vector3i) -> bool:
	var ch := char_at(c)
	return not is_solid_char(ch) and not FURNITURE_CHARS.contains(ch) and ch != "S"


## `avoid`: chars it may not step on (The Husk: "U", the boarded doorways).
func neighbours(c: Vector3i, avoid := "") -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for d in DIRS:
		var n := c + Vector3i(d.x, 0, d.y)
		if is_walkable(n) and (avoid == "" or not avoid.contains(char_at(n))):
			out.append(n)
	for s in stairs:
		if s.bottom == c:
			out.append(s.top)
		elif s.top == c:
			out.append(s.bottom)
	return out


func nearest_walkable(c: Vector3i) -> Vector3i:
	if is_walkable(c):
		return c
	for d in DIRS:
		var n := c + Vector3i(d.x, 0, d.y)
		if is_walkable(n):
			return n
	# On the stairs: the nearer end of the flight.
	for s in stairs:
		for cell: Vector2i in s.cells:
			if cell.x == c.x and cell.y == c.z:
				return s.top if c.y >= 1 or (s.cells as Array).find(cell) > 2 else s.bottom
	return c


## Cells to walk from `from` to `to` (the first element is the next cell).
## Empty if already there or unreachable. BFS: cheap on houses this size.
func path(from: Vector3i, to: Vector3i, avoid := "") -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if from == to or not is_walkable(from) or not is_walkable(to):
		return result
	var prev := {from: from}
	var queue: Array[Vector3i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == to:
			break
		for n in neighbours(c, avoid):
			if not prev.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return result
	var back := to
	while back != from:
		result.push_front(back)
		back = prev[back]
	return result


## Steps from `start` to every reachable cell.
func distances(start: Vector3i, avoid := "") -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector3i] = [start]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for n in neighbours(c, avoid):
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				queue.append(n)
	return dist


## Every cell holding `ch`, on every floor.
func find_all(ch: String) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for f in floors:
		for z in depth:
			for x in width:
				if char_at(Vector3i(x, f, z)) == ch:
					out.append(Vector3i(x, f, z))
	return out


## Problems that would break a run (empty: fine). Used by the generator
## and by the smoke test on many seeds.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var p := find_all("P")
	if p.size() != 1:
		return PackedStringArray(["%d player spawns" % p.size()])
	var reach := distances(p[0])
	for ch in ["T", "B", "E", "V", "X"]:
		for c in find_all(ch):
			if ch == "V" or ch == "X":
				continue
			if not reach.has(c):
				problems.append("%s at %s unreachable" % [ch, c])
	if find_all("X").size() != 1:
		problems.append("no single exit")
	if kind == "house" and find_all("V").size() != 1:
		problems.append("no single TV")
	if kind == "station" and find_all("E").size() != 1:
		problems.append("no single entity spot")
	return problems
