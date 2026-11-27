class_name HouseGenerator
extends RefCounted
## Builds a house from a seed, sized for the number of tapes: rooms by
## binary space partition, a hallway along the front with the door to the
## van, doors placed so that most rooms have two ways out, except a dead end
## or two on purpose (each with a wardrobe or a bed: in there you hide, or
## you are cornered), a second floor joined by stairs when the house grows,
## room types and their furniture, lamps, windows, a boarded doorway or two,
## and the spots for tapes, batteries, the player and the entity.
## Rooms: the fixed ones (living room with the TV, kitchen, bathroom, the
## child's room, a bedroom) and themed ones drawn from a pool, each laid
## out to play differently: a study with aisles of bookcases to lose sight
## in and a desk to get under, a laundry, a playroom with the show's bear
## sitting in a corner, a sewing room full of dress forms (figures in the
## viewfinder), a pantry lined with shelves, a dining room, a storeroom.
## Every machine builds the same house from the same seed. A house that
## fails validation (something unreachable) is thrown away and redone.

const MIN_TAPES := 5
const MAX_TAPES := 12
const STAIR_RUN := 5
const TWO_FLOORS_FROM := 8  # tapes from which the house gets a second floor
## Themed rooms: [the shorter side, the area] each needs (interior cells).
const THEMES := {"dining": [3, 12], "study": [4, 16], "laundry": [3, 9], "playroom": [3, 12],
		"sewing": [3, 12], "storage": [3, 9], "pantry": [3, 9], "bedroom": [3, 12]}
const GROUND_THEMES: Array[String] = ["dining", "study", "laundry", "playroom", "pantry", "storage"]
const UPPER_THEMES: Array[String] = ["bedroom", "study", "sewing", "playroom", "storage"]
## Furniture built cell by cell (a box, a washer, a figure): side by side
## they stay separate things. The rest join into one piece, which has to
## stay a rectangle (an L-shaped group was built as its bounding box).
const SINGLE_CELL_FURNITURE := "cmn"


static func generate(p_seed: int, tapes: int) -> HouseLayout:
	tapes = clampi(tapes, MIN_TAPES, MAX_TAPES)
	var last: HouseLayout = null
	for attempt in 40:
		var layout := _try(p_seed * 31 + attempt * 7919, tapes)
		if layout == null:
			continue
		last = layout
		if layout.validate().is_empty():
			return layout
	push_error("HouseGenerator: no valid house for seed %d (%s)" % [p_seed, last.validate() if last else "none"])
	return last


static func _try(p_seed: int, tapes: int) -> HouseLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var floors := 1 if tapes < TWO_FLOORS_FROM else 2
	var area := 430.0 + (tapes - MIN_TAPES) * 58.0
	if floors == 2:
		area *= 0.62
	var w := clampi(roundi(sqrt(area * 1.6)), 20, 36)
	var d := clampi(roundi(area / w), 14, 24)
	var L := HouseLayout.new()
	L.setup(w, d, floors)

	var exit_x := rng.randi_range(w / 3, (w * 2) / 3)
	var stair_x := -1
	if floors == 2:
		stair_x = 2 if exit_x > w / 2 else w - 2 - STAIR_RUN
	for f in floors:
		var hall := Rect2i(1, d - 3, w - 2, 2)
		_carve(L, f, hall, _add_room(L, f, hall, "hall"))
		var leaves: Array[Rect2i] = []
		_split(Rect2i(1, 1, w - 2, d - 5), rng, leaves)
		for r in leaves:
			_carve(L, f, r, _add_room(L, f, r, ""))
		if stair_x >= 0:
			for i in STAIR_RUN:
				L.set_char(Vector3i(stair_x + i, f, d - 3), "S")
		if not _place_doors(L, f, rng, 1 + (1 if tapes >= 9 else 0)):
			return null
	if stair_x >= 0:
		var cells: Array[Vector2i] = []
		for i in STAIR_RUN:
			cells.append(Vector2i(stair_x + i, d - 3))
		L.stairs.append({"bottom": Vector3i(stair_x - 1, 0, d - 3), "top": Vector3i(stair_x + STAIR_RUN, 1, d - 3),
				"cells": cells, "dir": Vector2i(1, 0)})
	L.set_char(Vector3i(exit_x, 0, d - 1), "X")
	var spawn := Vector3i(exit_x, 0, d - 2)

	_assign_types(L, rng)
	for i in L.rooms.size():
		_furnish(L, i, rng)
	_hideouts_in_dead_ends(L, rng)
	_board_doors(L, rng, 1 + (1 if tapes >= 9 else 0))
	_add_lamps(L, rng)
	_add_windows(L, rng, exit_x)
	L.set_char(spawn, "P")
	if not _place_spots(L, rng, spawn, tapes):
		return null
	return L


# --- rooms -------------------------------------------------------------------------

static func _add_room(L: HouseLayout, f: int, r: Rect2i, type: String) -> int:
	L.rooms.append({"floor": f, "rect": r, "type": type})
	return L.rooms.size() - 1


static func _carve(L: HouseLayout, f: int, r: Rect2i, id: int) -> void:
	var ids: PackedInt32Array = L.room_of[f]
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			L.set_char(Vector3i(x, f, z), ".")
			ids[z * L.width + x] = id


## Binary space partition: rooms of 3 to ~9 cells a side, a one-cell wall
## between them; now and then a bigger one (room for aisles of shelves).
static func _split(r: Rect2i, rng: RandomNumberGenerator, out: Array[Rect2i]) -> void:
	var can_v := r.size.x >= 7
	var can_h := r.size.y >= 7
	var area := r.size.x * r.size.y
	var wants := area > 48 or r.size.x > 9 or r.size.y > 8
	if area <= 48 and area >= 16 and rng.randf() < 0.25:
		wants = false
	elif area <= 66 and r.size.x <= 11 and r.size.y <= 8 and rng.randf() < 0.12:
		wants = false
	if not wants or (not can_v and not can_h):
		out.append(r)
		return
	var vertical := can_v and (not can_h or r.size.x > r.size.y * 1.2 or (r.size.x * 1.2 >= r.size.y and rng.randf() < 0.5))
	if vertical:
		var s := rng.randi_range(r.position.x + 3, r.end.x - 4)
		_split(Rect2i(r.position.x, r.position.y, s - r.position.x, r.size.y), rng, out)
		_split(Rect2i(s + 1, r.position.y, r.end.x - s - 1, r.size.y), rng, out)
	else:
		var s := rng.randi_range(r.position.y + 3, r.end.y - 4)
		_split(Rect2i(r.position.x, r.position.y, r.size.x, s - r.position.y), rng, out)
		_split(Rect2i(r.position.x, s + 1, r.size.x, r.end.y - s - 1), rng, out)


## Doors: a spanning tree of the rooms of this floor (so all are reachable),
## extra doors for loops, and a second door for any room left with one,
## except `dead_ends` of them, kept with a single door on purpose.
static func _place_doors(L: HouseLayout, f: int, rng: RandomNumberGenerator, dead_ends: int) -> bool:
	var candidates := {}  # Vector2i(a, b) -> Array[Vector3i]
	for z in range(1, L.depth - 1):
		for x in range(1, L.width - 1):
			var c := Vector3i(x, f, z)
			if L.char_at(c) != "#":
				continue
			for axis: Array in [[Vector3i(1, 0, 0), Vector3i(0, 0, 1)], [Vector3i(0, 0, 1), Vector3i(1, 0, 0)]]:
				var across: Vector3i = axis[0]
				var along: Vector3i = axis[1]
				var a := L.room_at(c - across)
				var b := L.room_at(c + across)
				if a < 0 or b < 0 or a == b:
					continue
				if L.char_at(c + along) != "#" or L.char_at(c - along) != "#":
					continue
				if L.char_at(c - across) == "S" or L.char_at(c + across) == "S":
					continue  # never open into the stairs
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not candidates.has(key):
					candidates[key] = []
				candidates[key].append(c)
	var floor_rooms: Array[int] = []
	for i in L.rooms.size():
		if L.rooms[i].floor == f:
			floor_rooms.append(i)
	var parent := {}
	for i in floor_rooms:
		parent[i] = i
	var keys := candidates.keys()
	_shuffle(keys, rng)
	var degree := {}
	var used := {}
	for key: Vector2i in keys:
		var ra := _find(parent, key.x)
		var rb := _find(parent, key.y)
		if ra != rb:
			parent[ra] = rb
			_open_door(L, candidates[key], rng, used, degree, key)
	# A dead end or two, on purpose (never the hallway).
	var keep := {}
	var lone: Array[int] = []
	for i in floor_rooms:
		if int(degree.get(i, 0)) == 1 and L.rooms[i].type != "hall":
			lone.append(i)
	_shuffle(lone, rng)
	for i in lone.slice(0, dead_ends):
		keep[i] = true
	for key: Vector2i in keys:
		if not used.has(key) and not keep.has(key.x) and not keep.has(key.y) and rng.randf() < 0.35:
			_open_door(L, candidates[key], rng, used, degree, key)
	# No other dead ends where a second door is possible.
	for key: Vector2i in keys:
		if used.has(key) or keep.has(key.x) or keep.has(key.y):
			continue
		if int(degree.get(key.x, 0)) < 2 or int(degree.get(key.y, 0)) < 2:
			_open_door(L, candidates[key], rng, used, degree, key)
	var root := _find(parent, floor_rooms[0])
	for i in floor_rooms:
		if _find(parent, i) != root:
			return false
	return true


static func _open_door(L: HouseLayout, cells: Array, rng: RandomNumberGenerator, used: Dictionary, degree: Dictionary, key: Vector2i) -> void:
	var c: Vector3i = cells[rng.randi() % cells.size()]
	L.set_char(c, "D")
	used[key] = true
	degree[key.x] = int(degree.get(key.x, 0)) + 1
	degree[key.y] = int(degree.get(key.y, 0)) + 1


static func _find(parent: Dictionary, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func _area(r: Dictionary) -> int:
	var rect: Rect2i = r.rect
	return rect.size.x * rect.size.y


static func _assign_types(L: HouseLayout, rng: RandomNumberGenerator) -> void:
	for f in L.floors:
		var ids: Array[int] = []
		for i in L.rooms.size():
			if L.rooms[i].floor == f and L.rooms[i].type == "":
				ids.append(i)
		ids.sort_custom(func(a: int, b: int) -> bool: return _area(L.rooms[a]) > _area(L.rooms[b]))
		var order: Array[String] = []
		if f == 0:
			order = ["living", "kitchen"]
			if L.floors == 1:
				order.append_array(["kid", "bedroom"])
		else:
			order = ["bedroom", "kid"]
		# The rest from the pool, each theme once before any repeats.
		var pool: Array[String] = GROUND_THEMES.duplicate() if f == 0 else UPPER_THEMES.duplicate()
		if L.floors == 1:
			pool.append("sewing")
		var themes: Array[String] = []
		for i in ids.size():
			var type := ""
			if i < order.size():
				type = order[i]
			elif i == ids.size() - 1 and ids.size() >= 3:
				type = "bathroom"
			else:
				type = _pick_theme(L.rooms[ids[i]].rect, themes, pool, rng)
			L.rooms[ids[i]].type = type
		# The bathroom is the smallest room, whatever the order said.
		if ids.size() >= 3 and not ids.any(func(i: int) -> bool: return L.rooms[i].type == "bathroom"):
			L.rooms[ids[ids.size() - 1]].type = "bathroom"
	for i in L.rooms.size():
		var t: String = L.rooms[i].type
		if t == "kitchen" or t == "bathroom" or t == "laundry":
			var rect: Rect2i = L.rooms[i].rect
			for z in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector3i(x, L.rooms[i].floor, z)
					if L.char_at(c) == ".":
						L.set_char(c, ",")


## The first theme left that fits the room (the pool again once it runs out).
static func _pick_theme(rect: Rect2i, themes: Array[String], pool: Array[String], rng: RandomNumberGenerator) -> String:
	for attempt in 2:
		if themes.is_empty() or attempt == 1:
			var more := pool.duplicate()
			_shuffle(more, rng)
			themes.append_array(more)
		for i in themes.size():
			var need: Array = THEMES[themes[i]]
			if mini(rect.size.x, rect.size.y) >= int(need[0]) and rect.size.x * rect.size.y >= int(need[1]):
				var t := themes[i]
				themes.remove_at(i)
				return t
	return "storage"


# --- furniture ------------------------------------------------------------------------

static func _floor_char(ch: String) -> bool:
	return ch == "." or ch == "," or ch == "r"


## Interior cells right in front of a door: kept free.
static func _door_fronts(L: HouseLayout, room: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector3i(x, r.floor, z)
			for d in HouseLayout.DIRS:
				var ch := L.char_at(c + Vector3i(d.x, 0, d.y))
				if ch == "D" or ch == "U" or ch == "X" or ch == "S":
					out.append(c)
	return out


## Places `ch` on `cells` if they are free floor and the room stays crossable.
static func _try_place(L: HouseLayout, room: int, cells: Array[Vector3i], ch: String) -> bool:
	var fronts := _door_fronts(L, room)
	for c in cells:
		if not L.inside(c) or L.room_at(c) != room or not _floor_char(L.char_at(c)) or fronts.has(c):
			return false
	var old: Array[String] = []
	for c in cells:
		old.append(L.char_at(c))
		L.set_char(c, ch)
	if not _room_crossable(L, room, fronts) or not _pieces_whole(L, cells, ch):
		for i in cells.size():
			L.set_char(cells[i], old[i])
		return false
	return true


## The piece each of `cells` belongs to is a full rectangle of `ch` (for
## the furniture built as one piece).
static func _pieces_whole(L: HouseLayout, cells: Array[Vector3i], ch: String) -> bool:
	if SINGLE_CELL_FURNITURE.contains(ch):
		return true
	var seen := {}
	for c in cells:
		if seen.has(c):
			continue
		var lo := Vector2i(c.x, c.z)
		var hi := lo
		var count := 0
		var stack: Array[Vector3i] = [c]
		seen[c] = true
		while not stack.is_empty():
			var cur: Vector3i = stack.pop_back()
			count += 1
			lo = Vector2i(mini(lo.x, cur.x), mini(lo.y, cur.z))
			hi = Vector2i(maxi(hi.x, cur.x), maxi(hi.y, cur.z))
			for d in HouseLayout.DIRS:
				var n := cur + Vector3i(d.x, 0, d.y)
				if L.char_at(n) == ch and not seen.has(n):
					seen[n] = true
					stack.append(n)
		if count != (hi.x - lo.x + 1) * (hi.y - lo.y + 1):
			return false
	return true


## A run of `ch` along one wall: the side's cells less its corners (runs on
## two walls never meet), cut where a doorway is; `min_len` to `max_len`
## long, from the longest free stretch that takes it.
static func _wall_run(L: HouseLayout, room: int, side: int, ch: String, min_len: int, max_len: int, rng: RandomNumberGenerator) -> bool:
	var cells := _side(L.rooms[room], side)
	if cells.size() < min_len + 2:
		return false
	var fronts := _door_fronts(L, room)
	var stretches: Array = []
	var cur: Array[Vector3i] = []
	for c in cells.slice(1, cells.size() - 1):
		if _floor_char(L.char_at(c)) and not fronts.has(c):
			cur.append(c)
		else:
			if cur.size() >= min_len:
				stretches.append(cur)
			cur = []
	if cur.size() >= min_len:
		stretches.append(cur)
	stretches.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	for stretch: Array in stretches:
		for n in range(mini(stretch.size(), max_len), min_len - 1, -1):
			var start := rng.randi_range(0, stretch.size() - n)
			var run: Array[Vector3i] = []
			run.assign(stretch.slice(start, start + n))
			if _try_place(L, room, run, ch):
				return true
	return false


## Inner cells (off the walls), shuffled.
static func _inner_cells(r: Dictionary, rng: RandomNumberGenerator) -> Array[Vector3i]:
	var rect: Rect2i = r.rect
	var out: Array[Vector3i] = []
	for z in range(rect.position.y + 1, rect.end.y - 1):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			out.append(Vector3i(x, r.floor, z))
	_shuffle(out, rng)
	return out


static func _corners(r: Dictionary, rng: RandomNumberGenerator) -> Array[Vector3i]:
	var rect: Rect2i = r.rect
	var f: int = r.floor
	var out: Array[Vector3i] = [Vector3i(rect.position.x, f, rect.position.y), Vector3i(rect.end.x - 1, f, rect.position.y),
			Vector3i(rect.position.x, f, rect.end.y - 1), Vector3i(rect.end.x - 1, f, rect.end.y - 1)]
	_shuffle(out, rng)
	return out


## Up to `count` boxes along the walls.
static func _boxes(L: HouseLayout, room: int, rng: RandomNumberGenerator, count: int) -> void:
	for i in count:
		var cells := _side(L.rooms[room], rng.randi_range(0, 3))
		_try_place(L, room, [cells[rng.randi() % cells.size()]], "c")


## A rug of up to 3x2 in the middle of the room.
static func _rug(L: HouseLayout, room: int) -> void:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var w := mini(3, rect.size.x - 2)
	var h := mini(2, rect.size.y - 2)
	var x0 := rect.position.x + (rect.size.x - w) / 2
	var z0 := rect.position.y + (rect.size.y - h) / 2
	for z in range(z0, z0 + h):
		for x in range(x0, x0 + w):
			var c := Vector3i(x, r.floor, z)
			if L.char_at(c) == ".":
				L.set_char(c, "r")


## Every door of the room reachable from every other, and most of the floor.
static func _room_crossable(L: HouseLayout, room: int, fronts: Array[Vector3i]) -> bool:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var free: Array[Vector3i] = []
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector3i(x, r.floor, z)
			if L.is_walkable(c):
				free.append(c)
	if free.is_empty():
		return false
	var start := fronts[0] if not fronts.is_empty() else free[0]
	var seen := {start: true}
	var queue: Array[Vector3i] = [start]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		for d in HouseLayout.DIRS:
			var n := c + Vector3i(d.x, 0, d.y)
			if L.room_at(n) == room and L.is_walkable(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for c in fronts:
		if not seen.has(c):
			return false
	return seen.size() >= free.size() * 0.8


## Cells along one side of a room, against the wall: side 0 north, 1 south,
## 2 west, 3 east.
static func _side(r: Dictionary, side: int) -> Array[Vector3i]:
	var rect: Rect2i = r.rect
	var f: int = r.floor
	var out: Array[Vector3i] = []
	match side:
		0:
			for x in range(rect.position.x, rect.end.x):
				out.append(Vector3i(x, f, rect.position.y))
		1:
			for x in range(rect.position.x, rect.end.x):
				out.append(Vector3i(x, f, rect.end.y - 1))
		2:
			for z in range(rect.position.y, rect.end.y):
				out.append(Vector3i(rect.position.x, f, z))
		3:
			for z in range(rect.position.y, rect.end.y):
				out.append(Vector3i(rect.end.x - 1, f, z))
	return out


static func _inward(side: int) -> Vector3i:
	return [Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)][side]


static func _furnish(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var f: int = r.floor
	match r.type:
		"living":
			_furnish_living(L, room, rng)
		"kitchen":
			# The counter along a wall from a corner, the fridge at its end.
			_corner_row(L, room, "k", 3, 2, "m", rng)
			if rect.size.x >= 4 and rect.size.y >= 4:
				var c := Vector3i(rect.position.x + rect.size.x / 2 - 1, f, rect.position.y + rect.size.y / 2)
				_try_place(L, room, [c, c + Vector3i(1, 0, 0)], "t")
		"bathroom":
			_furnish_bathroom(L, room, rng)
		"bedroom", "kid":
			var big := false  # single beds only (a double one got in the way of wardrobes)
			for side in _sides_shuffled(rng):
				var cells := _side(r, side)
				if cells.size() < 3:
					continue
				var a: Vector3i = cells[1]
				var b: Vector3i = cells[2]
				var bed: Array[Vector3i] = [a, b]
				if big:
					bed.append_array([a + _inward(side), b + _inward(side)])
				if _try_place(L, room, bed, "b"):
					break
			var corners: Array[Vector3i] = [Vector3i(rect.position.x, f, rect.position.y), Vector3i(rect.end.x - 1, f, rect.position.y),
					Vector3i(rect.position.x, f, rect.end.y - 1), Vector3i(rect.end.x - 1, f, rect.end.y - 1)]
			_shuffle(corners, rng)
			for c in corners:
				if _next_to(L, c, "b"):
					continue  # never against the bed (it would block the doors)
				if _try_place(L, room, [c], "w" if r.type == "bedroom" else "c"):
					break
			if r.type == "kid":
				_add_drawings(L, room, rng)
		"dining":
			# The table in the middle (under it, you hide), a sideboard.
			if rect.size.x >= 4 and rect.size.y >= 3:
				var c := Vector3i(rect.position.x + rect.size.x / 2 - 1, f, rect.position.y + rect.size.y / 2)
				_try_place(L, room, [c, c + Vector3i(1, 0, 0)], "t")
			for side in _sides_shuffled(rng):
				if _wall_run(L, room, side, "k", 2, 2, rng):
					break
		"storage":
			_boxes(L, room, rng, rng.randi_range(2, 4))
			for side in _sides_shuffled(rng):
				if _wall_run(L, room, side, "h", 2, 3, rng):
					break
		"study":
			_furnish_study(L, room, rng)
		"laundry":
			_furnish_laundry(L, room, rng)
		"playroom":
			_furnish_playroom(L, room, rng)
		"sewing":
			_furnish_sewing(L, room, rng)
		"pantry":
			# Shelves on every wall they fit, a box or two: a dead end
			# with nowhere to hide but the cupboard.
			for side in _sides_shuffled(rng):
				_wall_run(L, room, side, "h", 1, 4, rng)
			_boxes(L, room, rng, rng.randi_range(1, 2))


## A desk against a wall (to get under), bookcases along two walls and, in
## a big one, free-standing rows of them: aisles to lose sight in.
static func _furnish_study(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var f: int = r.floor
	for side in _sides_shuffled(rng):
		var cells := _side(r, side)
		if cells.size() >= 4 and _try_place(L, room, [cells[1], cells[2]], "t"):
			break
	var walls := 0
	for side in _sides_shuffled(rng):
		if walls < 2 and _wall_run(L, room, side, "h", 2, 5, rng):
			walls += 1
	var long_x := rect.size.x >= rect.size.y
	var length := rect.size.x if long_x else rect.size.y
	var across := rect.size.y if long_x else rect.size.x
	if length < 6 or across < 5:
		return
	var k := 2
	while k <= across - 3:
		var row: Array[Vector3i] = []
		for i in range(2, length - 2):
			row.append(Vector3i(rect.position.x + i, f, rect.position.y + k) if long_x else Vector3i(rect.position.x + k, f, rect.position.y + i))
		if not _try_place(L, room, row, "h"):
			# A shorter row, leaving a gap in the middle.
			var half := row.size() / 2
			if half >= 2:
				_try_place(L, room, row.slice(0, half - 1), "h")
				_try_place(L, room, row.slice(half), "h")
		k += 3


## Washing machines along a wall with the sink at their end, baskets.
static func _furnish_laundry(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	_corner_row(L, room, "m", 2, 1, "k", rng)
	_boxes(L, room, rng, rng.randi_range(1, 2))


## A row of `ch` along a wall, from one of its corners (`most` long, or down
## to `least`), and one `then` at its open end: whichever wall and corner
## take it first.
static func _corner_row(L: HouseLayout, room: int, ch: String, most: int, least: int, then: String, rng: RandomNumberGenerator) -> bool:
	for n in range(most, least - 1, -1):
		for side in _sides_shuffled(rng):
			var cells := _side(L.rooms[room], side)
			if cells.size() < n + 1:
				continue
			var starts := [0, cells.size() - n]
			_shuffle(starts, rng)
			for start: int in starts:
				var row: Array[Vector3i] = []
				row.assign(cells.slice(start, start + n))
				if not _try_place(L, room, row, ch):
					continue
				var end := start + n if start == 0 else start - 1
				if then != "" and end >= 0 and end < cells.size():
					_try_place(L, room, [cells[end]], then)
				return true
	return false


## The show's bear, big as a child, slumped in a corner; a little table to
## crawl under; toy boxes, a rug, drawings of Vecinito.
static func _furnish_playroom(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	_rug(L, room)
	for c in _corners(r, rng):
		if _try_place(L, room, [c], "n"):
			break
	for side in _sides_shuffled(rng):
		var cells := _side(r, side)
		if cells.size() >= 4 and _try_place(L, room, [cells[cells.size() / 2]], "t"):
			break
	_boxes(L, room, rng, rng.randi_range(2, 3))
	_add_drawings(L, room, rng)


## Dress forms standing about the room (in the viewfinder, in the dark,
## they are people), the sewing table, a box of cloth.
static func _furnish_sewing(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	for side in _sides_shuffled(rng):
		var cells := _side(r, side)
		if cells.size() >= 4 and _try_place(L, room, [cells[1], cells[2]], "t"):
			break
	var forms := 0
	var want := rng.randi_range(2, 3)
	var spots := _inner_cells(r, rng)
	for side in _sides_shuffled(rng):
		var cells := _side(r, side)
		spots.append(cells[rng.randi() % cells.size()])
	for c in spots:
		if forms >= want:
			break
		if not _next_to(L, c, "n") and _try_place(L, room, [c], "n"):
			forms += 1
	_boxes(L, room, rng, 1)


## The bath along a wall into a corner, the basin on another wall.
static func _furnish_bathroom(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var tub_side := -1
	for side in _sides_shuffled(rng):
		var cells := _side(r, side)
		if cells.size() < 3:
			continue
		var tub: Array[Vector3i] = [cells[0], cells[1]]
		var other: Array[Vector3i] = [cells[cells.size() - 2], cells[cells.size() - 1]]
		if rng.randf() < 0.5:
			var swap := tub
			tub = other
			other = swap
		if _try_place(L, room, tub, "a") or _try_place(L, room, other, "a"):
			tub_side = side
			break
	for side in _sides_shuffled(rng):
		if side == tub_side:
			continue
		var cells := _side(r, side)
		if cells.size() >= 3 and _try_place(L, room, [cells[cells.size() / 2]], "k"):
			break


static func _sides_shuffled(rng: RandomNumberGenerator) -> Array:
	var s := [0, 1, 2, 3]
	_shuffle(s, rng)
	return s


## The TV against the middle of one wall, the sofa facing it 3-4 cells
## away, a rug between them.
static func _furnish_living(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var sides := _sides_shuffled(rng)
	# Prefer a side with room in front of it.
	sides.sort_custom(func(a: int, b: int) -> bool:
		var da: int = rect.size.y if a < 2 else rect.size.x
		var db: int = rect.size.y if b < 2 else rect.size.x
		return da > db)
	for side: int in sides:
		var cells := _side(r, side)
		var reach: int = rect.size.y if side < 2 else rect.size.x
		if cells.size() < 3 or reach < 4:
			continue
		var tv: Vector3i = cells[cells.size() / 2]
		if not _try_place(L, room, [tv], "V"):
			continue
		var into := _inward(side)
		var along := Vector3i(into.z, 0, into.x)
		# The sofa close in front of the set and centred on it (3 seats, or
		# 1 if there is no room): you sit right in front of the screen.
		var dist := mini(2, reach - 1)
		var sofa_c := tv + into * dist
		if not _try_place(L, room, [sofa_c - along, sofa_c, sofa_c + along], "s"):
			_try_place(L, room, [sofa_c], "s")
		for k in range(1, dist):
			for o in [-1, 0, 1]:
				var c: Vector3i = tv + into * k + along * o
				if L.room_at(c) == room and L.char_at(c) == ".":
					L.set_char(c, "r")
		return
	# Nowhere good: the TV goes anywhere along a wall.
	for side: int in sides:
		for c in _side(r, side):
			if _try_place(L, room, [c], "V"):
				return


static func _add_drawings(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var placed := 0
	for side in _sides_shuffled(rng):
		var cells := _side(r, side)
		var c: Vector3i = cells[rng.randi() % cells.size()]
		var out := -_inward(side)
		if L.char_at(c + out) == "#":
			L.decor.append({"cell": c, "dir": Vector2i(out.x, out.z), "tex": "drawing" if placed == 0 else "drawing_scribbled"})
			placed += 1
			if placed >= 2:
				return


## Every room with a single way out gets somewhere to hide that conceals
## you (a wardrobe, or a bed already there): cornered in there, you hide.
static func _hideouts_in_dead_ends(L: HouseLayout, rng: RandomNumberGenerator) -> void:
	for i in L.rooms.size():
		var r: Dictionary = L.rooms[i]
		if r.type == "hall" or _exits(L, i) > 1:
			continue
		var rect: Rect2i = r.rect
		var has_hide := false
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if L.char_at(Vector3i(x, r.floor, z)) in ["b", "w"]:
					has_hide = true
		if has_hide:
			continue
		var f: int = r.floor
		var cells: Array[Vector3i] = [Vector3i(rect.position.x, f, rect.position.y), Vector3i(rect.end.x - 1, f, rect.position.y),
				Vector3i(rect.position.x, f, rect.end.y - 1), Vector3i(rect.end.x - 1, f, rect.end.y - 1)]
		_shuffle(cells, rng)
		for side in _sides_shuffled(rng):
			cells.append_array(_side(r, side))
		for c in cells:
			if _next_to(L, c, "b"):
				continue
			if _try_place(L, i, [c], "w"):
				break


## Whether `c` touches a cell of furniture `ch` (side by side).
static func _next_to(L: HouseLayout, c: Vector3i, ch: String) -> bool:
	for d in HouseLayout.DIRS:
		if L.char_at(c + Vector3i(d.x, 0, d.y)) == ch:
			return true
	return false


## How many doorways (open or boarded) lead out of a room.
static func _exits(L: HouseLayout, room: int) -> int:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var doors := {}
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector3i(x, r.floor, z)
			for d in HouseLayout.DIRS:
				var n := c + Vector3i(d.x, 0, d.y)
				if L.char_at(n) in ["D", "U", "X"]:
					doors[n] = true
	return doors.size()


# --- details ----------------------------------------------------------------------------

## Boards across a doorway or two between rooms (crouch to pass), only
## where the rooms stay connected another way.
## `avoid`: "U" to count the boarded doorways already placed as walls too
## (the station: nobody gets through them, The Husk included).
static func _board_doors(L: HouseLayout, rng: RandomNumberGenerator, count: int, avoid := "") -> void:
	var doors := L.find_all("D")
	_shuffle(doors, rng)
	for c in doors:
		if count <= 0:
			return
		var rooms_touched := {}
		for d in HouseLayout.DIRS:
			var r := L.room_at(c + Vector3i(d.x, 0, d.y))
			if r >= 0:
				rooms_touched[L.rooms[r].type] = true
		if rooms_touched.has("hall"):
			continue
		# Still connected without walking through it?
		L.set_char(c, "#")
		var some := Vector3i(-1, -1, -1)
		for d in HouseLayout.DIRS:
			var n := c + Vector3i(d.x, 0, d.y)
			if L.is_walkable(n):
				if some.x < 0:
					some = n
				elif not L.distances(some, avoid).has(n):
					some = Vector3i(-2, -2, -2)
		L.set_char(c, "D" if some.x == -2 else "U")
		if some.x != -2:
			count -= 1


static func _add_lamps(L: HouseLayout, rng: RandomNumberGenerator) -> void:
	for i in L.rooms.size():
		var r: Dictionary = L.rooms[i]
		var rect: Rect2i = r.rect
		var spots: Array[Vector3i] = []
		if r.type == "hall":
			var x := rect.position.x + 2
			while x < rect.end.x - 1:
				spots.append(Vector3i(x, r.floor, rect.end.y - 1))
				x += 6
		else:
			# Near the middle of the room, on bare floor (not the rug, not
			# furniture), so no room is left without its light.
			var mid := Vector2(rect.position) + Vector2(rect.size) * 0.5 - Vector2(0.5, 0.5)
			var best := Vector3i(-1, -1, -1)
			for z in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector3i(x, r.floor, z)
					if L.char_at(c) in [".", ","] and (best.x < 0 or Vector2(x, z).distance_to(mid) < Vector2(best.x, best.z).distance_to(mid)):
						best = c
			if best.x >= 0:
				spots.append(best)
		for c in spots:
			var ch := L.char_at(c)
			if not _floor_char(ch):
				continue
			var dead: bool = r.type != "living" and rng.randf() < 0.3
			L.set_char(c, "l" if dead else "L")


static func _add_windows(L: HouseLayout, rng: RandomNumberGenerator, exit_x: int) -> void:
	for f in L.floors:
		for x in range(2, L.width - 2):
			for z: int in [0, L.depth - 1]:
				var c := Vector3i(x, f, z)
				if L.char_at(c) != "#" or (f == 0 and absi(x - exit_x) <= 1):
					continue
				var inner := c + Vector3i(0, 0, 1 if z == 0 else -1)
				if L.is_walkable(inner) or _floor_char(L.char_at(inner)):
					if rng.randf() < 0.14:
						L.set_char(c, "W")
		for z in range(2, L.depth - 2):
			for x: int in [0, L.width - 1]:
				var c := Vector3i(x, f, z)
				if L.char_at(c) != "#":
					continue
				var inner := c + Vector3i(1 if x == 0 else -1, 0, 0)
				if (L.is_walkable(inner) or _floor_char(L.char_at(inner))) and rng.randf() < 0.14:
					L.set_char(c, "W")


## Tapes spread over the rooms (one per room, round-robin), batteries, and
## the entity as far from the door as the house allows.
static func _place_spots(L: HouseLayout, rng: RandomNumberGenerator, spawn: Vector3i, tapes: int) -> bool:
	var dist := L.distances(spawn)
	var per_room := {}
	for c: Vector3i in dist.keys():
		var ch := L.char_at(c)
		if not _floor_char(ch) or int(dist[c]) < 6:
			continue
		var room := L.room_at(c)
		if room < 0 or _door_fronts(L, room).has(c):
			continue
		if not per_room.has(room):
			per_room[room] = []
		per_room[room].append(c)
	var rooms := per_room.keys()
	_shuffle(rooms, rng)
	# Rooms first, the hall last.
	rooms.sort_custom(func(a: int, b: int) -> bool: return L.rooms[a].type != "hall" and L.rooms[b].type == "hall")
	for room in rooms:
		_shuffle(per_room[room], rng)
		# Against a wall or furniture first: it looks put there.
		(per_room[room] as Array).sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return _snug(L, a) > _snug(L, b))
	var need := {"T": tapes + 1, "B": 2 + tapes / 4 + L.rooms.size() / Tuning.ROOMS_PER_BATTERY}
	for ch: String in ["T", "B"]:
		var left: int = need[ch]
		var guard := 0
		while left > 0 and guard < 400:
			guard += 1
			for room in rooms:
				var list: Array = per_room[room]
				if left <= 0:
					break
				if list.is_empty():
					continue
				L.set_char(list.pop_front(), ch)
				left -= 1
		if left > 0:
			return false
	# The entity: the farthest plain floor (upstairs if there is one).
	var best := Vector3i(-1, -1, -1)
	var best_d := -1
	for c: Vector3i in dist.keys():
		if not _floor_char(L.char_at(c)):
			continue
		var score := int(dist[c]) + (100 if c.y == L.floors - 1 and L.floors > 1 else 0)
		if score > best_d:
			best_d = score
			best = c
	if best.x < 0:
		return false
	L.set_char(best, "E")
	return true


static func _snug(L: HouseLayout, c: Vector3i) -> int:
	var n := 0
	for d in HouseLayout.DIRS:
		var ch := L.char_at(c + Vector3i(d.x, 0, d.y))
		if HouseLayout.is_solid_char(ch) or HouseLayout.FURNITURE_CHARS.contains(ch):
			n += 1
	return n
