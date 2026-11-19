class_name Director
extends RefCounted
## The second mind (host only), the one that does know where everybody is.
## The entity hunts by what it sees and hears; left to itself it can lose
## the team for minutes and the night goes flat. The director watches the
## tension and, when the entity has been away from everyone too long,
## steps in, never by handing over a position:
##   AMBUSH  it guesses where someone is going (the tape they are heading
##           for, or simply the way they are walking) and sends the entity
##           there first, to wait behind a corner of that place.
##   HINT    a vague nudge: "someone, somewhere around there" (a cell a few
##           steps from a player), which the entity goes to investigate.
## Also, when a search comes up empty, it may guess where they went next.

var entity: Entity
var level: Level
var _calm := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_entity: Entity) -> void:
	entity = p_entity
	level = p_entity.level
	_rng.randomize()
	_calm = _patience() - 10.0  # the first nudge comes soon after it wakes


## Keep out of it for `seconds` (the house is quiet at first).
func hold(seconds: float) -> void:
	_calm = -seconds


func tick(delta: float, alive: Array[Player]) -> void:
	if entity.engaged(alive):
		_calm = 0.0
		return
	_calm += delta
	if _calm < _patience():
		return
	_calm = 0.0
	var p := pick(alive)
	if p == null:
		return
	if _rng.randf() < 0.55 and _ambush(p):
		return
	entity.hint(vague(p))


## A search found nobody (or nobody came to an ambush): most of the time it
## guesses where they went and sets another.
func search_failed(alive: Array[Player]) -> void:
	var p := pick(alive)
	if p and _rng.randf() < 0.35:
		_ambush(p)


func _patience() -> float:
	var t := lerpf(Tuning.DIRECTOR_PATIENCE, Tuning.DIRECTOR_PATIENCE_MIN, entity.aggression())
	return t + (6.0 if Net.is_solo() else 0.0)


## Whoever is alone first (more fun to stalk), else anyone not hiding.
func pick(alive: Array[Player]) -> Player:
	var open: Array[Player] = []
	for p in alive:
		if not p.is_hidden():
			open.append(p)
	if open.is_empty():
		return null
	for p in open:
		if entity.is_alone(p, alive):
			return p
	return open[_rng.randi() % open.size()]


func _ambush(p: Player) -> bool:
	var dest := predict(p)
	return dest.x >= 0 and entity.ambush(p, dest)


## Where `p` is going: the tape they seem to be heading for (close, and in
## the direction they walk), or else the place 6-10 steps ahead of them.
func predict(p: Player) -> Vector3i:
	var vel := entity.velocity_of(p)
	var heading := Vector3(vel.x, 0.0, vel.z)
	var moving := heading.length() > 0.5
	if moving:
		heading = heading.normalized()
	var from := level.nearest_walkable(level.cell_of(p.global_position))
	var dist := level.layout.distances(from)
	var best := Vector3i(-1, -1, -1)
	var best_score := INF
	for node in entity.get_tree().get_nodes_in_group("pickups"):
		var pk := node as Pickup
		if pk.kind != Pickup.Kind.TAPE:
			continue
		var c := level.nearest_walkable(level.cell_of(pk.global_position))
		if not dist.has(c):
			continue
		var steps := int(dist[c])
		if steps < 4 or steps > 20:
			continue
		var to := pk.global_position - p.global_position
		to.y = 0.0
		var align := heading.dot(to.normalized()) if moving else 0.0
		var score := steps * (1.6 - align)
		if score < best_score:
			best_score = score
			best = c
	if best.x >= 0 or not moving:
		return best
	for c: Vector3i in dist.keys():
		var steps := int(dist[c])
		if steps < 6 or steps > 10:
			continue
		var to := level.center(c) - p.global_position
		to.y = 0.0
		var score := -heading.dot(to.normalized())
		if score < best_score:
			best_score = score
			best = c
	return best


## Somewhere 2-4 steps from them: the right area, not the spot.
func vague(p: Player) -> Vector3:
	var from := level.nearest_walkable(level.cell_of(p.global_position))
	var dist := level.layout.distances(from)
	var options: Array[Vector3i] = []
	for c: Vector3i in dist.keys():
		if int(dist[c]) >= 2 and int(dist[c]) <= 4:
			options.append(c)
	if options.is_empty():
		return level.center(from)
	return level.center(options[_rng.randi() % options.size()])
