class_name StationGenerator
extends RefCounted
## The second night: Canal 9's studios, where ¡Te estoy viendo! was made,
## generated from a seed and sized for the master tapes to recover, on the
## same grid as the house (HouseLayout, kind "station"), so the Level, the
## paths, the doors, the hiding places and the pickups work the same way.
## One floor, laid out the way such buildings are: a corridor across the
## front from the loading dock (the way in and out) and a long corridor up
## the middle (long, lit sight lines: you can keep your eyes on something
## at the far end), rooms off both sides of it by binary partition.
## Rooms, each laid out to play differently against The Husk:
##   studio       the biggest: the show's set (the living room, its sofa, its
##                rug) between flats, studio cameras pointed at it, dark
##   archive      aisles of tape shelves: line of sight lost every two steps
##   wardrobe     the costumes standing in a row (one of them is The Husk:
##                it starts among them), lockers to hide in
##   control      the mixing desk under the monitors
##   transmitter  racks of humming equipment
##   dressing     the make-up counter, lockers
##   office       desks to get under, shelves
##   breakroom    a counter, the fridge, a table
##   restroom     tiles, the basins
##   storage      boxes, shelves
## Boarded doorways (crouch under the boards) are where it cannot follow.

const MIN_TAPES := HouseGenerator.MIN_TAPES
const MAX_TAPES := HouseGenerator.MAX_TAPES
const FIXED: Array[String] = ["studio", "archive", "wardrobe", "control", "transmitter", "dressing", "breakroom", "office", "restroom"]
const POOL: Array[String] = ["office", "storage", "archive", "dressing", "office", "storage"]
## Costumes standing in the wardrobe (The Husk is one more among them).
const DECOYS_MIN := 3
const DECOYS_MAX := 5


static func generate(p_seed: int, tapes: int) -> HouseLayout:
	tapes = clampi(tapes, MIN_TAPES, MAX_TAPES)
	var last: HouseLayout = null
	for attempt in 60:
		var layout := _try(p_seed * 37 + attempt * 6151 + 11, tapes)
		if layout == null:
			continue
		last = layout
		if layout.validate().is_empty() and _complete(layout):
			return layout
	push_error("StationGenerator: no valid station for seed %d (%s)" % [p_seed, last.validate() if last else "none"])
	return last


## Every station has its studio, its wardrobe with costumes and somewhere
## the master tapes can be; checked with the rest of validation.
static func _complete(L: HouseLayout) -> bool:
	var types := {}
	for r in L.rooms:
		types[r.type] = true
	return types.has("studio") and types.has("wardrobe") and L.find_all("n").size() >= DECOYS_MIN and not L.find_all("U").is_empty()


static func _try(p_seed: int, tapes: int) -> HouseLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var area := 480.0 + (tapes - MIN_TAPES) * 62.0
	var w := clampi(roundi(sqrt(area * 1.45)), 24, 40)
	var d := clampi(roundi(area / w), 17, 27)
	var L := HouseLayout.new()
	L.kind = "station"
	L.setup(w, d, 1)
	# The corridors: across the front (the dock) and up the middle, one
	# room (they are one space).
	var spine_x := clampi(w / 2 + rng.randi_range(-3, 3), 7, w - 9)
	var front := Rect2i(1, d - 3, w - 2, 2)
	var hall := HouseGenerator._add_room(L, 0, front, "hall")
	HouseGenerator._carve(L, 0, front, hall)
	HouseGenerator._carve(L, 0, Rect2i(spine_x, 1, 2, d - 4), hall)
	var leaves: Array[Rect2i] = []
	HouseGenerator._split(Rect2i(1, 1, spine_x - 2, d - 5), rng, leaves)
	HouseGenerator._split(Rect2i(spine_x + 3, 1, w - spine_x - 4, d - 5), rng, leaves)
	for r in leaves:
		HouseGenerator._carve(L, 0, r, HouseGenerator._add_room(L, 0, r, ""))
	if not HouseGenerator._place_doors(L, 0, rng, 1 + (1 if tapes >= 9 else 0)):
		return null
	# The loading dock, away from the foot of the spine.
	var exit_x := rng.randi_range(2, w - 3)
	for i in 12:
		if absi(exit_x - spine_x) > 3:
			break
		exit_x = rng.randi_range(2, w - 3)
	L.set_char(Vector3i(exit_x, 0, d - 1), "X")
	var spawn := Vector3i(exit_x, 0, d - 2)
	_assign_types(L, rng)
	for i in L.rooms.size():
		_furnish(L, i, rng)
	HouseGenerator._hideouts_in_dead_ends(L, rng)
	HouseGenerator._board_doors(L, rng, 2 + (1 if tapes >= 9 else 0), "U")
	_add_lamps(L, rng, spine_x)
	L.set_char(spawn, "P")
	if not HouseGenerator._place_spots(L, rng, spawn, tapes):
		return null
	# It starts in the wardrobe, standing in the row of costumes.
	if not _husk_among_costumes(L, rng):
		return null
	return L


static func _assign_types(L: HouseLayout, rng: RandomNumberGenerator) -> void:
	var ids: Array[int] = []
	for i in L.rooms.size():
		if L.rooms[i].type == "":
			ids.append(i)
	ids.sort_custom(func(a: int, b: int) -> bool: return HouseGenerator._area(L.rooms[a]) > HouseGenerator._area(L.rooms[b]))
	var pool := POOL.duplicate()
	HouseGenerator._shuffle(pool, rng)
	for k in ids.size():
		var type := ""
		if k < FIXED.size() - 1:
			type = FIXED[k]
		elif k == ids.size() - 1:
			type = "restroom"  # the smallest
		else:
			type = pool[(k - FIXED.size() + 1) % pool.size()]
		L.rooms[ids[k]].type = type
	# The wardrobe needs room for its row of costumes: swap with a bigger
	# room if it came out too small.
	for i in ids:
		if L.rooms[i].type != "wardrobe":
			continue
		var rect: Rect2i = L.rooms[i].rect
		if mini(rect.size.x, rect.size.y) >= 3 and rect.size.x * rect.size.y >= 12:
			break
		for j in ids:
			var rj: Rect2i = L.rooms[j].rect
			if L.rooms[j].type in ["office", "storage", "dressing", "breakroom"] and mini(rj.size.x, rj.size.y) >= 3 and rj.size.x * rj.size.y >= 12:
				L.rooms[j].type = "wardrobe"
				L.rooms[i].type = "office"
				break
		break
	for i in L.rooms.size():
		var t: String = L.rooms[i].type
		if t == "restroom" or t == "breakroom":
			var rect: Rect2i = L.rooms[i].rect
			for z in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector3i(x, 0, z)
					if L.char_at(c) == ".":
						L.set_char(c, ",")


static func _furnish(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	match r.type:
		"studio":
			_furnish_studio(L, room, rng)
		"archive":
			_furnish_archive(L, room, rng)
		"wardrobe":
			_furnish_wardrobe(L, room, rng)
		"control":
			# The mixing desk along a wall under the monitors, a second run
			# of it if it fits, a box of cables.
			var runs := 0
			for side in HouseGenerator._sides_shuffled(rng):
				if runs < 2 and HouseGenerator._wall_run(L, room, side, "k", 2, 4, rng):
					runs += 1
			HouseGenerator._boxes(L, room, rng, 1)
		"transmitter":
			HouseGenerator._corner_row(L, room, "m", 4, 2, "", rng)
			for side in HouseGenerator._sides_shuffled(rng):
				if HouseGenerator._wall_run(L, room, side, "m", 2, 3, rng):
					break
		"dressing":
			for side in HouseGenerator._sides_shuffled(rng):
				if HouseGenerator._wall_run(L, room, side, "k", 2, 3, rng):
					break
			for c in HouseGenerator._corners(r, rng):
				if HouseGenerator._try_place(L, room, [c], "w"):
					break
		"office":
			var rect: Rect2i = r.rect
			var desks := 0
			for side in HouseGenerator._sides_shuffled(rng):
				var cells := HouseGenerator._side(r, side)
				if desks < (2 if rect.size.x * rect.size.y >= 20 else 1) and cells.size() >= 4 and HouseGenerator._try_place(L, room, [cells[1], cells[2]], "t"):
					desks += 1
			for side in HouseGenerator._sides_shuffled(rng):
				if HouseGenerator._wall_run(L, room, side, "h", 2, 3, rng):
					break
			HouseGenerator._boxes(L, room, rng, rng.randi_range(0, 2))
		"breakroom":
			HouseGenerator._corner_row(L, room, "k", 3, 2, "m", rng)
			var rect: Rect2i = r.rect
			if rect.size.x >= 4 and rect.size.y >= 4:
				var c := Vector3i(rect.position.x + rect.size.x / 2 - 1, 0, rect.position.y + rect.size.y / 2)
				HouseGenerator._try_place(L, room, [c, c + Vector3i(1, 0, 0)], "t")
		"restroom":
			for side in HouseGenerator._sides_shuffled(rng):
				if HouseGenerator._wall_run(L, room, side, "k", 1, 2, rng):
					break
		"storage":
			HouseGenerator._boxes(L, room, rng, rng.randi_range(2, 4))
			for side in HouseGenerator._sides_shuffled(rng):
				if HouseGenerator._wall_run(L, room, side, "h", 2, 3, rng):
					break


## The set of the show in the middle of the studio (the same living room
## as on the tape: its sofa, its rug; the Level puts up the flats behind
## it), and the studio cameras on their pedestals pointed at it.
static func _furnish_studio(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var long_x := rect.size.x >= rect.size.y
	var mid := Vector3i(rect.position.x + rect.size.x / 2, 0, rect.position.y + rect.size.y / 2)
	var back := Vector3i(0, 0, -1) if long_x else Vector3i(-1, 0, 0)  # the set's back wall side
	if rng.randf() < 0.5:
		back = -back
	var along := Vector3i(absi(back.z), 0, absi(back.x))
	var sofa := mid + back
	if not HouseGenerator._try_place(L, room, [sofa - along, sofa, sofa + along], "s"):
		HouseGenerator._try_place(L, room, [sofa], "s")
	for k in [0, 1]:
		for o in [-1, 0, 1]:
			var c: Vector3i = mid - back * k + along * o
			if L.room_at(c) == room and L.char_at(c) == ".":
				L.set_char(c, "r")
	# The cameras: in front of the set, 3 or 4 cells off, spread across.
	var placed := 0
	for o in [-2, 0, 2, -3, 3]:
		if placed >= 3:
			break
		for dist in [3, 4, 2]:
			var c: Vector3i = mid - back * dist + along * o
			if L.room_at(c) == room and HouseGenerator._try_place(L, room, [c], "q"):
				placed += 1
				break
	HouseGenerator._boxes(L, room, rng, rng.randi_range(2, 3))


## Rows of shelves full of tapes, aisles two cells wide between them, and
## shelves along the walls.
static func _furnish_archive(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var rect: Rect2i = r.rect
	var walls := 0
	for side in HouseGenerator._sides_shuffled(rng):
		if walls < 2 and HouseGenerator._wall_run(L, room, side, "h", 2, 6, rng):
			walls += 1
	var long_x := rect.size.x >= rect.size.y
	var length := rect.size.x if long_x else rect.size.y
	var across := rect.size.y if long_x else rect.size.x
	if length < 5 or across < 5:
		return
	var k := 2
	while k <= across - 3:
		var row: Array[Vector3i] = []
		for i in range(1, length - 1):
			row.append(Vector3i(rect.position.x + i, 0, rect.position.y + k) if long_x else Vector3i(rect.position.x + k, 0, rect.position.y + i))
		if not HouseGenerator._try_place(L, room, row.slice(1, row.size() - 1), "h"):
			var half := row.size() / 2
			if half >= 2:
				HouseGenerator._try_place(L, room, row.slice(1, half - 1), "h")
				HouseGenerator._try_place(L, room, row.slice(half + 1, row.size() - 1), "h")
		k += 3


## The costumes in a row along one wall, a cell apart (each one a figure
## on its own), and lockers.
static func _furnish_wardrobe(L: HouseLayout, room: int, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = L.rooms[room]
	var want := rng.randi_range(DECOYS_MIN, DECOYS_MAX)
	var sides := HouseGenerator._sides_shuffled(rng)
	sides.sort_custom(func(a: int, b: int) -> bool: return HouseGenerator._side(r, a).size() > HouseGenerator._side(r, b).size())
	var placed := 0
	for side: int in sides:
		var cells := HouseGenerator._side(r, side)
		for i in range(1, cells.size() - 1, 2):
			if placed >= want:
				break
			if HouseGenerator._try_place(L, room, [cells[i]], "n"):
				placed += 1
		if placed >= want:
			break
	for c in HouseGenerator._corners(r, rng):
		if not HouseGenerator._next_to(L, c, "n") and HouseGenerator._try_place(L, room, [c], "w"):
			break


## A lamp in the middle of every room (the studio's are the work lights,
## two), tubes every five cells along the corridors; some dead.
static func _add_lamps(L: HouseLayout, rng: RandomNumberGenerator, spine_x: int) -> void:
	for i in L.rooms.size():
		var r: Dictionary = L.rooms[i]
		var rect: Rect2i = r.rect
		var spots: Array[Vector3i] = []
		if r.type == "hall":
			var x := rect.position.x + 2
			while x < rect.end.x - 1:
				spots.append(Vector3i(x, 0, rect.end.y - 1))
				x += 5
			var z := 2
			while z < rect.position.y - 1:
				spots.append(Vector3i(spine_x + (z / 5) % 2, 0, z))
				z += 5
		else:
			var mid := Vector2(rect.position) + Vector2(rect.size) * 0.5 - Vector2(0.5, 0.5)
			var best := Vector3i(-1, -1, -1)
			for z in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector3i(x, 0, z)
					if L.char_at(c) in [".", ","] and (best.x < 0 or Vector2(x, z).distance_to(mid) < Vector2(best.x, best.z).distance_to(mid)):
						best = c
			if best.x >= 0:
				spots.append(best)
		for c in spots:
			if not HouseGenerator._floor_char(L.char_at(c)):
				continue
			var dead := rng.randf() < (0.15 if r.type == "hall" else 0.3)
			L.set_char(c, "l" if dead else "L")


## The entity spot moves into the wardrobe, in the row of costumes: free
## floor next to one, not in front of a door.
static func _husk_among_costumes(L: HouseLayout, rng: RandomNumberGenerator) -> bool:
	var costumes := L.find_all("n")
	if costumes.is_empty():
		return false
	var room := L.room_at(costumes[0])
	var fronts := HouseGenerator._door_fronts(L, room)
	var options: Array[Vector3i] = []
	for c in costumes:
		for d in HouseLayout.DIRS:
			var n := c + Vector3i(d.x, 0, d.y)
			if L.room_at(n) == room and L.char_at(n) in [".", ","] and not fronts.has(n):
				options.append(n)
	if options.is_empty():
		return false
	for c in L.find_all("E"):
		L.set_char(c, ".")
	L.set_char(options[rng.randi() % options.size()], "E")
	return true
