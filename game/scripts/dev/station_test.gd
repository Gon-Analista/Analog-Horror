class_name StationTest
extends Node
## Dev: the second night (Canal 9, The Husk). Checks its rules headless, or
## takes a tour of screenshots:
##   godot --headless --path game -- --station --smoke
##   godot --path game -- --station --shots <absolute dir>
## Lines as SmokeTest's ("SMOKE ok ..." / "SMOKE FAIL ...").

var _fails := 0


func run_test(main: Node, shots_dir: String) -> void:
	var player: Player = main.player
	var husk := main.entity as Husk
	var run: Run = main.run
	var level: Level = run.level
	await get_tree().physics_frame
	if shots_dir != "":
		await _tour(main, shots_dir)
		get_tree().quit()
		return
	_check_generation()
	_check_build(level)
	player.net_god = false

	# Asleep among the costumes until the first master is taken.
	var tapes := run.get_tree().get_nodes_in_group("pickups").filter(func(p: Node) -> bool: return (p as Pickup).kind == Pickup.Kind.TAPE)
	_check("the masters are on the shelves from the start (%d)" % tapes.size(), tapes.size() >= run.tapes_needed and (tapes[0] as Pickup).master, "")
	_check("it sleeps among the costumes", husk.state == Entity.State.DORMANT and _next_to_costume(level, husk.global_position), "")
	await _wait(1.0)
	_check("asleep, it does not move", husk.global_position.distance_to(husk.net_pos) < 0.01 and not husk.moving, "")
	run._request_pickup(String((tapes[0] as Pickup).name))
	await get_tree().physics_frame
	_check("the first master wakes it", husk.state == Entity.State.STALKING, Entity.State.keys()[husk.state])

	# Seen: it holds still. Looked away from: it comes.
	var line := level.find_line(7)
	var start: Vector3i = line[0]
	var dir: Vector2i = line[1]
	var ahead := func(n: int) -> Vector3: return level.center(start + Vector3i(dir.x * n, 0, dir.y * n))
	var face := atan2(-dir.x, -dir.y)
	player.global_position = level.center(start)
	player.set_view(face)
	player.light_on = true
	husk.global_position = ahead.call(3)
	husk.net_pos = husk.global_position
	husk._learn(player, true, true)
	await _wait(0.2)
	var before := husk.global_position
	await _wait(1.2)
	_check("seen, it does not move (3 m, lit)", husk.watched and husk.global_position.distance_to(before) < 0.01,
			"watched=%s moved %.2f" % [husk.watched, husk.global_position.distance_to(before)])
	var pose_seen := husk.look
	player.set_view(face + PI)
	await _wait(0.5)
	_check("looked away from, it comes (and changes pose)", not husk.watched and husk.global_position.distance_to(before) > 0.6 and husk.look != pose_seen,
			"moved %.2f look %d -> %d" % [husk.global_position.distance_to(before), pose_seen, husk.look])

	# Filming is not seeing.
	husk.global_position = ahead.call(4)
	player.set_view(face)
	player.camcorder.force_held = true
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.3)
	var filming := player.camcorder.filming
	var cam_mask := player.camera.cull_mask
	before = husk.global_position
	await _wait(0.4)
	_check("through the camcorder it is not on the picture (shadow only), and it moves", filming and (cam_mask & HuskModel.NAKED_LAYER) == 0
			and husk.global_position.distance_to(before) > 0.3, "filming=%s mask=%d moved=%.2f" % [filming, cam_mask, husk.global_position.distance_to(before)])
	player.camcorder.force_held = false
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.2)
	_check("the naked eye sees it again", (player.camera.cull_mask & HuskModel.NAKED_LAYER) != 0, "")

	# In the dark, you only make it out close up, or in your beam.
	for lamp in level.lamps:
		lamp.dead = true
	husk.global_position = ahead.call(6)
	await get_tree().physics_frame
	player.light_on = false
	await _wait(0.1)
	var dark_far := husk.sees_me(player, player.camera.global_transform)
	player.light_on = true
	await _wait(0.1)
	var beam := husk.sees_me(player, player.camera.global_transform)
	player.set_view(face + 1.2)
	await get_tree().physics_frame
	var beam_off := husk.sees_me(player, player.camera.global_transform)
	_check("dark: not seen at 6 m without light; in the beam yes; out of the beam no", not dark_far and beam and not beam_off,
			"dark=%s beam=%s off-beam=%s" % [dark_far, beam, beam_off])
	player.set_view(face)

	# Staring makes you blink, and it moves in the blink.
	husk.global_position = ahead.call(5)
	husk.net_pos = husk.global_position
	var blinks := [0]
	husk.blinked.connect(func() -> void: blinks[0] += 1)
	var start_pos := husk.global_position
	await _wait(Husk.BLINK_MAX + 0.6)
	_check("staring, you blink within %.1f s, and it moves in the blink" % Husk.BLINK_MAX, blinks[0] >= 1 and husk.global_position.distance_to(start_pos) > 0.2,
			"blinks=%d moved=%.2f" % [blinks[0], husk.global_position.distance_to(start_pos)])

	# The boards stop it: no path through a boarded doorway.
	var through := 0
	var blocked := 0
	for u in level.layout.find_all("U"):
		var sides: Array[Vector3i] = []
		for d in Level.DIRS:
			var n := u + Vector3i(d.x, 0, d.y)
			if level.is_walkable(n):
				sides.append(n)
		if sides.size() == 2:
			var p := level.path(sides[0], sides[1], "U")
			if p.has(u):
				through += 1
			if p.is_empty():
				blocked += 1
	_check("boarded doorways: never through them (%d sealed off a room)" % blocked, through == 0 and not level.layout.find_all("U").is_empty(), "%d paths through" % through)

	# Shut doors: it opens them, slowly, only when nobody looks.
	var door_ok := true
	for door in level.doors:
		if door.transom:
			door_ok = false
	_check("no broken windows over the doors here (it cannot climb)", door_ok, "")

	# Not watched and close: it takes you.
	player.set_view(face + PI)
	husk.global_position = ahead.call(2)
	husk.net_pos = husk.global_position
	husk._learn(player, true, true)
	await _wait(2.0)
	_check("unwatched, it reaches you and takes you", not player.alive or run.phase == Run.Phase.CAUGHT, "alive=%s d=%.2f mode=%s" % [player.alive, husk.global_position.distance_to(player.global_position), Entity.Mode.keys()[husk.mode]])
	print("SMOKE done: %d failed" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _next_to_costume(level: Level, at: Vector3) -> bool:
	var c := level.cell_of(at)
	for d in Level.DIRS:
		if level.char_at(c + Vector3i(d.x, 0, d.y)) == "n":
			return true
	return false


func _check_generation() -> void:
	var bad := PackedStringArray()
	var count := 0
	for tapes in [5, 7, 9, 12]:
		for seed in range(1, 16):
			count += 1
			var L := StationGenerator.generate(seed, tapes)
			var problems := L.validate()
			var p: Vector3i = L.find_all("P")[0]
			var reach := L.distances(p, "U")
			if L.find_all("T").size() < tapes + 1:
				problems.append("%d tape spots" % L.find_all("T").size())
			var reachable := 0
			for t in L.find_all("T"):
				if reach.has(t):
					reachable += 1
			if reachable < tapes + 1:
				problems.append("%d tapes reachable" % reachable)
			if not reach.has(L.find_all("E")[0]) and not reach.has(L.nearest_walkable(L.find_all("E")[0])):
				problems.append("husk cannot reach the crew")
			var exit_ok := false
			for x in L.find_all("X"):
				for d in Level.DIRS:
					if reach.has(x + Vector3i(d.x, 0, d.y)):
						exit_ok = true
			if not exit_ok:
				problems.append("exit unreachable")
			if L.find_all("n").size() < 3:
				problems.append("%d costumes" % L.find_all("n").size())
			if not problems.is_empty():
				bad.append("seed %d tapes %d: %s" % [seed, tapes, ", ".join(problems)])
	_check("generated stations are sound (%d)" % count, bad.is_empty(), "; ".join(bad.slice(0, 4)))


func _check_build(level: Level) -> void:
	var costumes := 0
	for child in level.get_children():
		if child is HuskModel:
			costumes += 1
	var lit := level.lamps.filter(func(l: FlickerLight) -> bool: return not l.dead).size()
	_check("built: %d costumes, %d lamps (%d lit), %d hiding places, %d doors" % [costumes, level.lamps.size(), lit, level.hide_spots.size(), level.doors.size()],
			costumes >= 3 and lit >= 3 and level.hide_spots.size() >= 2, "")
	# Furniture has a body: a ray down the middle of each piece hits it.
	var space := level.get_world_3d().direct_space_state
	var missing := PackedStringArray()
	for z in level.depth:
		for x in level.width:
			var c := Vector3i(x, 0, z)
			var ch := level.char_at(c)
			if not HouseLayout.FURNITURE_CHARS.contains(ch) or ch == "r":
				continue
			var p := level.center(c)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.5, 0), p + Vector3(0, 0.05, 0), Tuning.LAYER_WORLD)
			if space.intersect_ray(q).is_empty():
				missing.append("%s@%d,%d" % [ch, x, z])
	_check("furniture has collision (%d without)" % missing.size(), missing.size() <= 2, " ".join(missing.slice(0, 8)))


# --- the tour ----------------------------------------------------------------------

func _tour(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var player: Player = main.player
	var husk := main.entity as Husk
	var run: Run = main.run
	var level: Level = run.level
	husk.set_physics_process(false)
	for f in level.layout.floors:
		for z in level.layout.depth:
			var row := ""
			for x in level.layout.width:
				row += level.layout.char_at(Vector3i(x, f, z))
			print("MAP ", row)
	await _wait(1.5)
	for t: String in ["hall", "studio", "wardrobe", "control", "archive", "transmitter", "office", "dressing", "breakroom", "restroom", "storage"]:
		await _room_shot(player, level, t, dir, "s_" + t)
	# The wardrobe: the costumes, and which one is it (eye, then camcorder).
	var e: Vector3i = level.layout.find_all("E")[0]
	var to := level.center(e)
	var from := _cell_facing(level, e, 3)
	await _look_shot(player, level, from, to + Vector3.UP * 1.3, dir, "s_costumes_eye")
	player.camcorder.force_held = true
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.6)
	await _shot(dir, "s_costumes_camera")
	player.camcorder.force_held = false
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.3)
	# Awake, in the corridor, in each pose, a few metres ahead.
	var line := level.find_line(7)
	var start: Vector3i = line[0]
	var ld: Vector2i = line[1]
	husk.state = Entity.State.STALKING
	for k in [HuskModel.Pose.STAND, HuskModel.Pose.TILT, HuskModel.Pose.CROUCH, HuskModel.Pose.CLOSE]:
		var at := level.center(start + Vector3i(ld.x * (2 if k == HuskModel.Pose.CLOSE else 4), 0, ld.y * (2 if k == HuskModel.Pose.CLOSE else 4)))
		husk.global_position = at
		husk.look = k
		husk.yaw = atan2(float(ld.x), float(ld.y))
		husk._shown_look = k  # (seen, it would keep the pose it had: the tour moves it by hand)
		husk._shown_yaw = husk.yaw
		await _look_shot(player, level, start, at + Vector3.UP * 1.3, dir, "s_husk_%s" % HuskModel.Pose.keys()[k].to_lower())
	# The same, through the camcorder: only its shadow.
	player.camcorder.force_held = true
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.6)
	await _shot(dir, "s_husk_on_camera")
	player.camcorder.force_held = false
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.3)
	# The blink.
	husk.set_process(false)  # (held half shut for the picture)
	husk.blink = Husk.BLINK_TIME * 0.5
	await _wait(0.2)
	await _shot(dir, "s_blink")
	husk.set_process(true)
	# The PA.
	var night: StationNight = main.get_node("UILayer/StationNight")
	night._sub.text = night._text_for("lie_look")
	night._sub_left = 3.0
	night._sub.modulate.a = 1.0
	await _wait(0.3)
	await _shot(dir, "s_pa")
	# Blackout.
	run._blackout()
	await _look_shot(player, level, start, level.center(start + Vector3i(ld.x * 4, 0, ld.y * 4)) + Vector3.UP * 1.3, dir, "s_blackout")


func _cell_facing(level: Level, target: Vector3i, n: int) -> Vector3i:
	var room := level.layout.room_at(target)
	var best := target
	var best_d := -1.0
	for z in range(target.z - n, target.z + n + 1):
		for x in range(target.x - n, target.x + n + 1):
			var c := Vector3i(x, 0, z)
			if level.is_walkable(c) and level.layout.room_at(c) == room:
				var d := Vector2(x - target.x, z - target.z).length()
				if d > best_d and d <= n + 0.5:
					best_d = d
					best = c
	return best


func _room_shot(player: Player, level: Level, type: String, dir: String, shot_name: String) -> void:
	for r: Dictionary in level.layout.rooms:
		if r.type != type:
			continue
		var rect: Rect2i = r.rect
		var mid := Vector3(rect.position.x + rect.size.x * 0.5, 0, rect.position.y + rect.size.y * 0.5)
		var best := Vector3i(-1, -1, -1)
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector3i(x, 0, z)
				if level.is_walkable(c) and (best.x < 0 or level.center(c).distance_to(mid) > level.center(best).distance_to(mid)):
					best = c
		if best.x >= 0:
			await _look_shot(player, level, best, mid + Vector3.UP * 0.9, dir, shot_name)
		return


func _look_shot(player: Player, level: Level, from: Vector3i, at: Vector3, dir: String, shot_name: String) -> void:
	var eye := level.center(from) + Vector3.UP * 1.6
	var to := at - eye
	player.global_position = level.center(from)
	player.set_view(atan2(-to.x, -to.z), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.8, 0.8))
	await _wait(0.7)
	await _shot(dir, shot_name)


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))


func _check(what: String, ok: bool, detail: String) -> void:
	if ok:
		print("SMOKE ok   ", what)
	else:
		_fails += 1
		print("SMOKE FAIL ", what, " (", detail, ")")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
