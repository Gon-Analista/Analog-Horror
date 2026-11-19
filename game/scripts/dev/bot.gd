class_name Bot
extends Node
## Dev (Alt+F1 monitor, "+ BOT"): a stand-in teammate for testing the
## entity alone: it walks the house on the host, sometimes sticking with
## you, sometimes wandering off by itself (so the entity can follow the
## one who goes alone, take them, play with the body...). It drives its
## body the way a remote player's is driven (net_pos / net_yaw). Host only;
## guests do not see it.

var body: Player
var level: Level
var leader: Player
var _path: Array[Vector3i] = []
var _goal := Vector3i(-1, -1, -1)
var _wait := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if body == null or not body.alive or get_tree().paused:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _path.is_empty():
		_pick_goal()
		return
	var door := level.door_at(_path[0])
	if door and door.blocks():
		if door.ready_to_move() and not door.is_open:
			door.set_open.rpc(true, false, door.swing_from(body.net_pos))  # a bot opens doors in its way like anyone
		return
	var next := level.center(_path[0])
	var to := next - body.net_pos
	var step := Tuning.WALK_SPEED * delta
	if to.length() <= step:
		body.net_pos = next
		_path.pop_front()
		if _path.is_empty():
			_wait = _rng.randf_range(0.5, 3.0)
	else:
		body.net_pos += to.normalized() * step
		var flat := Vector2(to.x, to.z)
		if flat.length() > 0.01:
			body.net_yaw = atan2(-to.x, -to.z)
	body.net_light = true


## Half the time somewhere near whoever it follows, half the time a room of
## its own choosing (alone).
func _pick_goal() -> void:
	var here := level.nearest_walkable(level.cell_of(body.net_pos))
	var dist := level.layout.distances(here)
	var options: Array[Vector3i] = []
	if leader and leader.alive and _rng.randf() < 0.5:
		var near := level.nearest_walkable(level.cell_of(leader.global_position))
		var around := level.layout.distances(near)
		for c: Vector3i in around.keys():
			if int(around[c]) <= 2 and dist.has(c):
				options.append(c)
	else:
		for c: Vector3i in dist.keys():
			if int(dist[c]) >= 6 and int(dist[c]) <= 16:
				options.append(c)
	if options.is_empty():
		_wait = 1.0
		return
	_goal = options[_rng.randi() % options.size()]
	_path = level.path(here, _goal)
