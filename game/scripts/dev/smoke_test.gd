class_name SmokeTest
extends Node
## Dev: checks the core rules without playing and prints one line per
## check ("SMOKE ok ..." / "SMOKE FAIL ..."), then quits:
##   godot --headless --path game -- --smoke
## 0. Input reaches the 3D world.  1. Filming the entity freezes it.  2. Unfilmed, it reaches the player.
## 3. Picking up the quota opens the exit.  4. Generated houses are sound
## (many seeds and tape counts).  5. Pickups lie on the floor, never inside
## walls or furniture.  6. A body thrown by the entity lands on the floor.
## 7. It does not know where you are, hears noises, never catches through a
## wall, does not find you hidden unless you talk, and the Director sets
## ambushes where you are going.

var _fails := 0


func run_smoke(main: Node) -> void:
	var player: Player = main.player
	var entity: Entity = main.entity
	var run: Run = main.run
	await get_tree().physics_frame
	_check_generation()

	# 0. Input reaches the player inside the 3D SubViewport.
	var light_on := player.light_on
	var ev := InputEventAction.new()
	ev.action = "flashlight"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 4:
		await get_tree().process_frame
	_check("input reaches the 3D world", player.flashlight.visible != light_on, "flashlight did not toggle (light_on %s vis %s hands %s/%s)" % [player.light_on, player.flashlight.visible, player.inventory.left, player.inventory.right])
	player.light_on = light_on

	# The hands: what is in them works; what is in the bag does not.
	var inv := player.inventory
	inv.swap("left", "right")
	player.camcorder.force_held = true
	await _wait(Tuning.CAMCORDER_RAISE_TIME + 0.2)
	var films_left := player.camcorder.filming and inv.left == "camcorder"
	inv.swap("left", "bag0")
	await get_tree().process_frame
	var bag_stops := not player.camcorder.filming
	inv.swap("right", "bag1")
	await get_tree().process_frame
	var light_off := not player.flashlight.visible
	player.camcorder.force_held = false
	inv.swap("bag0", "right")
	inv.swap("bag1", "left")
	await get_tree().process_frame
	_check("inventory: the camcorder films from either hand, nothing works from the bag",
			films_left and bag_stops and light_off and inv.left == "flashlight" and inv.right == "camcorder" and player.flashlight.visible == light_on,
			"left=%s bag=%s light_off=%s hands=%s/%s" % [films_left, bag_stops, light_off, inv.left, inv.right])

	# Reading the broadcast wakes it; E again closes the broadcast.
	var screen: ReadableScreen = null
	for child in run.tv.get_children():
		if child is ReadableScreen:
			screen = child
	_check("entity sleeps until the broadcast is read", entity.state == Entity.State.DORMANT, Entity.State.keys()[entity.state])
	player.global_position = run.tv.global_position + run.tv.global_transform.basis.z * -1.2
	run._on_interact(screen)
	_check("the TV starts on the show", run.tv.state == TvBroadcast.State.SHOW and entity.state == Entity.State.DORMANT, "")
	var sat := player.seated and player.global_position.distance_to(run.tv.global_position) > 1.5
	run._on_interact(null)  # trying to get up before the end: you cannot
	_check("watching the TV you sit on the sofa and stay there", sat and player.seated and run.reading,
			"sat=%s seated=%s reading=%s" % [sat, player.seated, run.reading])
	await _wait(Tuning.TV_DISTURB_AT + 1.0)
	_check("the show starts going wrong", run.tv.disturbance() > 0.0 and run.tv.state == TvBroadcast.State.SHOW, "disturbance %.2f" % run.tv.disturbance())
	await _wait(Tuning.TV_DISTURB_TIME + TvBroadcast.INTERRUPT_TIME)
	_check("then the alert cuts in, and it waits while you read",
			run.tv.is_showing_text() and entity.state == Entity.State.DORMANT,
			"tv=%s entity=%s" % [TvBroadcast.State.keys()[run.tv.state], Entity.State.keys()[entity.state]])
	run._on_interact(null)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("closing the alert wakes it, and you get up", not run.reading and not player.seated and entity.state != Entity.State.DORMANT, "")
	# Just woken: far from everyone (nobody dies the moment the broadcast
	# ends), then silent for a while.
	var woke_d := entity.global_position.distance_to(player.global_position)
	await _wait(3.0)
	_check("its cry comes once the TV is left", not entity.cry_pending and entity.sounds.any(func(s: String) -> bool: return s.ends_with("wake_cry")), str(entity.sounds))
	_check("just woken it comes in far away, and silent", entity.quiet and player.alive and woke_d > 8.0,
			"quiet=%s mode=%s d=%.1f" % [entity.quiet, Entity.Mode.keys()[entity.mode], woke_d])
	entity._grace = 0.0  # (the rest of the checks need it awake)
	entity.quiet = false
	for i in run.blackout_at():
		run._request_pickup("Tape%d" % i)
	await get_tree().process_frame
	var lit := 0
	for lamp in run.level.lamps:
		if not lamp.dead:
			lit += 1
	_check("half the tapes cut the power (lamps and TV)", run.tapes_got == run.blackout_at() and lit == 0 and not run.tv.powered,
			"tapes=%d lit=%d tv=%s" % [run.tapes_got, lit, run.tv.powered])

	await get_tree().physics_frame
	_check_pickups(run)
	await _check_batteries(run, player)

	# 1. The camera no longer stops it: filmed, it comes on; the flash
	# burns it and it runs off; enraged, the flash only stuns it.
	var line := run.level.find_line(6)
	var start: Vector3i = line[0]
	var dir: Vector2i = line[1]
	player.global_position = run.level.center(start)
	player.set_view(atan2(-dir.x, -dir.y))
	entity.global_position = run.level.center(start + Vector3i(dir.x * 5, 0, dir.y * 5))
	entity.wake()
	player.net_god = true
	player.camcorder.force_held = true
	entity._learn(player, true, true)
	entity._start_chase("test")
	await _wait(0.6)
	var before := entity.global_position
	await _wait(0.4)
	_check("filmed, it keeps coming (the camera does not stop it)", entity.global_position.distance_to(before) > 0.2,
			"moved %.2f m" % entity.global_position.distance_to(before))
	entity.global_position = run.level.center(start + Vector3i(dir.x * 4, 0, dir.y * 4))
	await get_tree().physics_frame
	var hit := entity.flash_hits(player)
	if hit:
		entity.flashed(player)
	var apart := entity.vanishing
	await _wait(Entity.VANISH_TIME + 0.3)
	var away := entity.global_position.distance_to(player.global_position)
	var space := entity.get_world_3d().direct_space_state
	var unseen := not entity._clear(space, player.camera.global_position, entity.global_position + Vector3.UP * 1.2) or away > 15.0
	_check("the flash burns it: it comes apart, and is gone, somewhere out of sight and away", hit and apart and entity.gone
			and not entity._sprite.visible and away > 6.0 and unseen and not entity.flash_hits(player),
			"hit=%s apart=%s gone=%s %.1f m away unseen=%s" % [hit, apart, entity.gone, away, unseen])
	await _wait(Tuning.RECOVER_MAX + 0.5)
	_check("then it comes back (from where it chose)", not entity.gone and not entity.vanishing,
			"gone=%s mode=%s" % [entity.gone, Entity.Mode.keys()[entity.mode]])
	entity.enraged = true
	entity._recover = 0.0
	entity._flash_immune = 0.0
	entity.global_position = run.level.center(start + Vector3i(dir.x * 4, 0, dir.y * 4))
	entity._learn(player, true, true)
	entity._start_chase("test")
	await get_tree().physics_frame
	if entity.flash_hits(player):
		entity.flashed(player)
	await _wait(0.3)
	_check("enraged, the flash only stuns it", entity.state == Entity.State.FROZEN and entity.mode == Entity.Mode.CHASE,
			"state=%s mode=%s" % [Entity.State.keys()[entity.state], Entity.Mode.keys()[entity.mode]])
	entity.enraged = false
	entity._stagger = 0.0
	entity.resume()
	player.camcorder.force_held = false
	player.net_god = false
	_check("(still alive for the next checks)", player.alive, "caught by the enraged entity")
	await _check_senses(run, player, entity, main)

	# The dev bot (Alt+F1): it joins, walks, and the entity counts it.
	var note := run.spawn_bot()
	var bot: Player = run.players.values().filter(func(q: Player) -> bool: return q.has_node("Bot"))[0] if run.players.size() > 1 else null
	var bot_from := bot.global_position if bot else Vector3.ZERO
	await _wait(6.0)  # it may stop a moment before setting off
	_check("a bot can be added and walks about (%s)" % note, bot != null and entity.players.has(bot) and (bot.global_position.distance_to(bot_from) > 0.5 or not bot.alive),
			"bot=%s moved=%.1f" % [bot != null, bot.global_position.distance_to(bot_from) if bot else 0.0])
	if bot:
		run.players.erase(bot.peer_id)
		entity.players.erase(bot)
		bot.queue_free()

	# Two floors: you walk up the stairs (no step stops you).
	if not run.level.layout.stairs.is_empty():
		var st: Dictionary = run.level.layout.stairs[0]
		var sd: Vector2i = st.dir
		entity.set_physics_process(false)
		player.net_god = true
		player.global_position = run.level.center(st.bottom)
		player.set_view(atan2(-sd.x, -sd.y))
		Input.action_press("move_forward")
		var climb := 0.0
		while climb < 5.0 and player.global_position.y < Level.FLOOR_H - 0.1:
			await get_tree().physics_frame
			climb += get_physics_process_delta_time()
		Input.action_release("move_forward")
		_check("you can walk up the stairs (%.1f s)" % climb, player.global_position.y > Level.FLOOR_H - 0.2, "stuck at y=%.2f" % player.global_position.y)
		player.net_god = false
		entity.set_physics_process(true)

	# 2. Chase: camcorder down; from its bedroom it must path through the
	# house and catch the player at the front door.
	player.camcorder.force_held = false
	entity.hunt_only = true
	entity.resume()
	entity.global_position = run.level.center(run.level.spots_of("E")[0])
	player.global_position = run.level.center(run.level.spots_of("P")[0])
	var t := 0.0
	while run.phase == Run.Phase.PLAYING and t < 40.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check("unfilmed entity catches the player", run.phase == Run.Phase.CAUGHT, "phase %s after %.1f s" % [Run.Phase.keys()[run.phase], t])

	# 3. Quota opens the exit (counted directly on the run state).
	run.tapes_got = run.tapes_needed
	_check("exit opens with the quota", run.exit_door != null and run.exit_door.is_open(), "")

	# 6. The body stays, and the entity can drag and throw it.
	await _wait(3.0)
	var mine := run.corpses.filter(func(b: Corpse) -> bool: return b.peer_id == player.peer_id)
	_check("the taken leave a body", mine.size() == 1 and entity.corpses.size() == run.corpses.size(), "%d bodies" % run.corpses.size())
	if not mine.is_empty():
		var body: Corpse = mine[0]
		# After a catch (with someone left) it carries the body off.
		var fake := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
		fake.setup(55, "Otro", Net.COLORS[1], false)
		main.world.add_child(fake)
		fake.global_position = run.level.center(run.level.spots_of("P")[0])
		entity.players.append(fake)
		entity.state = Entity.State.FEEDING
		entity.global_position = body.global_position
		entity.resume()
		_check("after a catch it takes the body away (others get a chance)", entity.mode == Entity.Mode.CORPSE and entity._taking_away,
				"mode=%s taking=%s" % [Entity.Mode.keys()[entity.mode], entity._taking_away])
		entity._set_mode(Entity.Mode.WANDER, 0.0, "test")
		entity._corpse = null
		entity.players.erase(fake)
		fake.queue_free()
		body.grab(entity)
		entity.global_position = run.level.center(start)
		await _wait(0.6)
		var dragged := body.global_position.distance_to(entity.global_position) < 1.5
		body.throw_to(run.level.center(start + Vector3i(dir.x * 4, 0, dir.y * 4)))
		await _wait(Corpse.THROW_TIME + 0.3)
		_check("a dragged body is thrown and lands on the floor",
				dragged and body.cstate == Corpse.CState.LYING and absf(body.global_position.y - 0.14) < 0.05,
				"dragged=%s state=%s y=%.2f" % [dragged, Corpse.CState.keys()[body.cstate], body.global_position.y])
	await _check_replay(main, run, player, entity)
	await _check_voice(main, player)
	await _check_doors(main, run, player, entity)
	await _check_windows(run, player)
	# Translations: English loaded and complete for what the menu shows;
	# Spanish (the source) shows the text itself.
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var en := tr("JUGAR SOLO") == "PLAY ALONE" and tr_n("Falta %d cinta", "Faltan %d cintas", 3) == "%d tapes missing"
	TranslationServer.set_locale("es")
	var es := tr("JUGAR SOLO") == "JUGAR SOLO"
	TranslationServer.set_locale(was)
	_check("translations: English loaded, Spanish is the source", en and es and Settings.languages().has("en"), "en=%s es=%s" % [en, es])
	await _check_pilot(main, run, player, entity)
	print("SMOKE done, %d failed" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check_senses(run: Run, player: Player, entity: Entity, main: Node) -> void:
	var level := run.level
	# Unaware: crouched in the dark at the front door, it in its far room.
	player.light_on = false
	player._set_crouch(true)
	player.global_position = level.center(level.spots_of("P")[0])
	entity.global_position = level.center(level.spots_of("E")[0])
	entity.resume()
	await _wait(1.5)
	_check("it does not know where you are", entity.clue_age() > Tuning.MEMORY and entity.mode == Entity.Mode.WANDER,
			"mode %s clue %.1f s" % [Entity.Mode.keys()[entity.mode], entity.clue_age()])
	entity.hear(player.global_position, 999.0)
	await _wait(0.3)
	_check("a noise brings it to investigate", entity.mode == Entity.Mode.INVESTIGATE and entity.clue_age() < 1.0,
			Entity.Mode.keys()[entity.mode])

	# Never through a wall: a hand's width away but behind one.
	entity.set_physics_process(false)
	var wall := _wall_between(level)
	var caught := [0]
	var count := func(_p: Player) -> void: caught[0] += 1
	entity.caught.connect(count)
	if wall.is_empty():
		_check("it never catches through a wall", false, "no wall found")
	else:
		var a: Vector3i = wall[0]
		var d: Vector3 = wall[1]
		player.global_position = level.center(a) + d * 0.3
		entity.global_position = level.center(a) + d * 1.0  # inside the wall, 0.7 m away
		entity.state = Entity.State.STALKING
		entity._try_catch(entity._alive())
		_check("it never catches through a wall", caught[0] == 0, "caught")
		# Immortal (Alt+F1 monitor): right on top of you, nothing.
		player.global_position = level.center(a)
		entity.global_position = level.center(a) + Vector3(0.2, 0, 0)
		player.net_god = true
		entity._try_catch(entity._alive())
		player.net_god = false
		_check("immortal with the monitor open", caught[0] == 0, "caught")

	# Hidden under a bed: it searches right there and does not find you...
	var bed: HideSpot = null
	for s in level.hide_spots:
		if s.kind == HideSpot.Kind.BED:
			bed = s
	if bed == null:
		_check("hidden under a bed it does not find you", false, "no bed in this house")
	else:
		player._set_crouch(false)
		player.global_position = level.center(bed.access)
		player.hide_in(bed)
		entity.global_position = level.center(bed.access) + Vector3(0.3, 0, 0)
		entity._clue_spot = null
		entity._clue_pos = entity.global_position
		entity._start_search()
		entity.set_physics_process(true)
		await _wait(3.0)
		_check("hidden under a bed, it looks and does not find you", caught[0] == 0 and player.alive and player.is_hidden(),
				"caught=%d hidden=%s" % [caught[0], player.is_hidden()])
		# ...unless you talk.
		main.get_node("VoiceChat").heard[player.peer_id] = main.get_node("VoiceChat")._clock
		_check("talking in the hiding place gives you away", entity.finds_in(bed, player), "")
		# Found: it leans in and shows its face first; a flash then saves you.
		var only: Array[Player] = [player]
		entity._check_spot(bed, only)
		await get_tree().physics_frame
		var peeking: bool = entity.mode == Entity.Mode.PEEK and caught[0] == 0
		var flashable := entity.flash_hits(player)
		_check("found hiding, it first shows its face, in frame for the flash", peeking and flashable,
				"mode=%s caught=%d flashable=%s" % [Entity.Mode.keys()[entity.mode], caught[0], flashable])
		if flashable:
			entity.flashed(player)
		await _wait(Tuning.PEEK_TIME + 0.3)
		_check("flashed while it peeks, it comes apart (and is gone far away, not on you) and you live", caught[0] == 0 and player.alive
				and entity.gone and entity.global_position.distance_to(player.global_position) > 6.0,
				"caught=%d gone=%s %.1f m away" % [caught[0], entity.gone, entity.global_position.distance_to(player.global_position)])
		main.get_node("VoiceChat").heard.erase(player.peer_id)
		player.leave_hide()
		entity.vanishing = false  # (back for the next checks)
		entity.gone = false
	entity.caught.disconnect(count)

	# The Director: where you are going, it gets there first.
	if entity.director == null:
		entity.director = Director.new()
		entity.director.setup(entity)
	player.global_position = level.center(level.spots_of("P")[0])
	entity.global_position = level.center(level.spots_of("E")[0])
	entity.resume()
	var dest := entity.director.predict(player)
	var ok := dest.x >= 0 and entity.ambush(player, dest)
	var space := level.get_world_3d().direct_space_state
	var unseen := ok and space.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,
			level.center(entity._hide) + Vector3.UP * 1.4, Tuning.LAYER_WORLD)).size() > 0
	_check("the Director sends it to wait where you are going, out of sight", ok and unseen and entity.mode == Entity.Mode.AMBUSH,
			"dest=%s ok=%s unseen=%s" % [dest, ok, unseen])
	# Caught lying in wait: it stares, shouts after 2 s, then comes in fury.
	var wline := level.find_line(7)
	var wc: Vector3i = wline[0]
	var wd: Vector2i = wline[1]
	player.global_position = level.center(wc)
	player.set_view(atan2(-wd.x, -wd.y))
	entity.global_position = level.center(wc + Vector3i(wd.x * 5, 0, wd.y * 5))
	entity._hide = level.nearest_walkable(level.cell_of(entity.global_position))
	entity.vanishing = false  # (not gone from an earlier flash)
	entity.gone = false
	entity._flash_immune = 0.0
	entity._set_mode(Entity.Mode.LURK, 30.0, "test")
	entity.target = player
	player.net_god = true
	player.camcorder.force_held = true
	await _wait(0.3)
	var staring_at := entity.global_position
	await _wait(1.4)
	var still := entity.global_position.distance_to(staring_at) < 0.05
	await _wait(0.9)
	var shrieked: bool = entity._shrieked
	player.camcorder.force_held = false
	await _wait(0.3)
	_check("found lying in wait: stares, shouts, then comes furious", shrieked and still and entity.mode == Entity.Mode.CHASE and entity._fury > 0.0,
			"shrieked=%s frozen=%s mode=%s fury=%.1f" % [shrieked, still, Entity.Mode.keys()[entity.mode], entity._fury])
	# Seen while it walks about (filmed, then let go): it does not learn where you are.
	entity._fury = 0.0  # (the fury of the last check is over)
	entity._burst = 0.0
	entity._found_out = false
	if entity.director:
		entity.director.hold(10.0)  # (the Director must not send it to lie in wait right now)
	entity.resume()
	entity.global_position = level.center(wc + Vector3i(wd.x * 5, 0, wd.y * 5))
	entity._wander_pause = 5.0  # standing about, its back to you
	entity._facing = Vector3(wd.x, 0, wd.y)
	player.light_on = false
	player._set_crouch(true)
	entity._motion.clear()  # (the teleports of the checks are not footsteps it can hear)
	entity._heard_new = false
	player.velocity = Vector3.ZERO
	main.get_node("VoiceChat").heard.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity._motion.clear()
	entity._clue_age = INF
	player.camcorder.force_held = true
	await _wait(0.5)
	player.camcorder.force_held = false
	await _wait(0.1)
	# (Whatever it goes on doing, it does not come for you: not after you,
	# not looking where you are.)
	# (If it heard you meanwhile, that is not the camera's doing.)
	var heard := entity.events.slice(0, 4).any(func(e: String) -> bool: return e.contains("oye"))
	_check("filming it while it roams does not give you away", entity._clue_age > 0.9 or entity._clue_player != player or not entity._clue_seen or heard, "%s %s" % [Entity.Mode.keys()[entity.mode], entity.events.slice(0, 5)])
	player._set_crouch(false)
	player.net_god = false

	# Stealth: your back to it, it comes up behind you silent; turn round and
	# it has you.
	var sline := level.find_line(7)
	var sc: Vector3i = sline[0]
	var sd: Vector2i = sline[1]
	player.global_position = level.center(sc)
	player.set_view(atan2(-sd.x, -sd.y))  # looking down the line, away from it
	entity.resume()
	var behind_cell := level.nearest_walkable(level.cell_of(player.global_position - Vector3(sd.x, 0, sd.y) * 5.0))
	entity.global_position = level.center(behind_cell)
	entity.target = player
	entity._learn(player, true, true)
	entity._behind_t = -1.0
	entity._set_mode(Entity.Mode.STALK, 20.0, "test")
	var caught2 := [0]
	var count2 := func(_p: Player) -> void: caught2[0] += 1
	entity.caught.connect(count2)
	player.net_god = true
	await _wait(2.5)
	var behind: bool = entity._behind_t >= 0.0 and caught2[0] == 0
	player.set_view(atan2(sd.x, sd.y))  # turns round
	player.net_yaw = player.rotation.y
	await _wait(0.8)
	_check("stealth: up behind you silently, and when you turn round it has you", behind and caught2[0] == 1,
			"behind=%s caught=%d" % [behind, caught2[0]])
	entity.caught.disconnect(count2)
	player.net_god = false
	entity.resume()

	# From the ceiling: it waits up there and drops on whoever walks under.
	var under := level.find_line(7)
	var cell: Vector3i = under[0]
	var ud: Vector2i = under[1]
	player.light_on = false
	player.global_position = level.center(cell + Vector3i(ud.x * 6, 0, ud.y * 6))
	entity.global_position = level.center(cell)
	entity._hide = cell
	entity._set_mode(Entity.Mode.AMBUSH, 30.0, "test")
	entity._ceiling = true
	entity.target = player
	player.net_god = true
	await _wait(0.4)
	var was_up := entity.on_ceiling
	player.global_position = level.center(cell)
	await _wait(0.3)
	_check("it waits on the ceiling and drops when you walk under", was_up and not entity.on_ceiling and entity.mode == Entity.Mode.CHASE,
			"up=%s now_up=%s mode=%s" % [was_up, entity.on_ceiling, Entity.Mode.keys()[entity.mode]])
	player.global_position = level.center(level.spots_of("P")[0])
	entity.global_position = level.center(level.spots_of("E")[0])
	entity.resume()
	await _wait(0.2)
	player.net_god = false
	player.light_on = true

	# Left alone, it does not lose the night: before long it is onto you
	# (heard, nudged by the Director or lying in wait where you are).
	entity.resume()
	var t := 0.0
	var engaged := false
	while t < 50.0 and not engaged:
		await _wait(0.5)
		t += 0.5
		engaged = entity.mode in [Entity.Mode.CHASE, Entity.Mode.FOLLOW, Entity.Mode.LURK, Entity.Mode.AMBUSH, Entity.Mode.INVESTIGATE]
	_check("the Director never lets it lose you for long (%.0f s)" % t, engaged and player.alive, Entity.Mode.keys()[entity.mode])


## A wall cell with free floor on both sides: [cell on one side, direction].
func _wall_between(level: Level) -> Array:
	for z in level.depth:
		for x in level.width:
			var c := Vector3i(x, 0, z)
			if not level.is_walkable(c):
				continue
			for d in Level.DIRS:
				var w := c + Vector3i(d.x, 0, d.y)
				if level.char_at(w) == "#" and level.is_walkable(w + Vector3i(d.x, 0, d.y)):
					return [c, Vector3(d.x, 0, d.y)]
	return []


## Many houses, every size: valid, enough tapes and batteries, every pickup
## spot on a free floor cell, the spawn and both floors connected, never
## more than two floors.
func _check_generation() -> void:
	var bad := PackedStringArray()
	var sizes := PackedStringArray()
	var dead_ends := 0
	var types := {}
	var rooms := 0
	var bare := PackedStringArray()
	var unmarked := PackedStringArray()
	for tapes in [5, 6, 8, 10, 12]:
		var cells := 0
		for seed in range(1, 21):
			var L := HouseGenerator.generate(seed, tapes)
			var problems := L.validate()
			if L.find_all("T").size() < tapes + 1:
				problems.append("%d tape spots" % L.find_all("T").size())
			if L.find_all("B").size() < 2:
				problems.append("%d battery spots" % L.find_all("B").size())
			if L.floors > 2 or (tapes >= HouseGenerator.TWO_FLOORS_FROM) != (L.floors == 2):
				problems.append("%d floors" % L.floors)
			var reach := L.distances(L.find_all("P")[0])
			for ch in ["T", "B", "U"]:
				for c in L.find_all(ch):
					if not L.is_walkable(c) or not reach.has(c):
						problems.append("%s at %s not on a free floor" % [ch, c])
			if L.floors == 2:
				var up := 0
				for c: Vector3i in reach.keys():
					if c.y == 1:
						up += 1
				if up < 20:
					problems.append("upstairs unreachable")
			cells += reach.size()
			# Furniture built as one piece is always a full rectangle (an L of
			# it was built as its bounding box, over the floor).
			for f in L.floors:
				for z in L.depth:
					for x in L.width:
						var c := Vector3i(x, f, z)
						var ch := L.char_at(c)
						if HouseLayout.FURNITURE_CHARS.contains(ch) and not HouseGenerator._pieces_whole(L, [c], ch):
							problems.append("%s not a rectangle at %s" % [ch, c])
			# Every room furnished as its kind.
			for i in L.rooms.size():
				var r: Dictionary = L.rooms[i]
				types[r.type] = int(types.get(r.type, 0)) + 1
				if r.type == "hall":
					continue
				rooms += 1
				var rect: Rect2i = r.rect
				var furnished := false
				for z in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						if HouseLayout.FURNITURE_CHARS.contains(L.char_at(Vector3i(x, r.floor, z))):
							furnished = true
				if not furnished:
					bare.append(r.type)
				# ...and with what makes it that room.
				var mark: String = {"living": "V", "kitchen": "k", "study": "h", "laundry": "m", "playroom": "n", "sewing": "n", "pantry": "h", "bathroom": "a"}.get(r.type, "")
				if mark != "":
					var has := false
					for z in range(rect.position.y, rect.end.y):
						for x in range(rect.position.x, rect.end.x):
							has = has or L.char_at(Vector3i(x, r.floor, z)) == mark
					if not has:
						unmarked.append("%s without %s" % [r.type, mark])
			# Dead ends on purpose, each with a wardrobe or a bed to hide in.
			for i in L.rooms.size():
				if L.rooms[i].type == "hall" or HouseGenerator._exits(L, i) > 1:
					continue
				dead_ends += 1
				var rect: Rect2i = L.rooms[i].rect
				var hide := false
				for z in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						if L.char_at(Vector3i(x, L.rooms[i].floor, z)) in ["b", "w"]:
							hide = true
				if not hide:
					problems.append("dead end %s with nowhere to hide" % L.rooms[i].type)
			if not problems.is_empty():
				bad.append("seed %d tapes %d: %s" % [seed, tapes, ", ".join(problems)])
		sizes.append("%d:%d" % [tapes, cells / 20])
	_check("generated houses are sound (100 houses; tapes:walkable cells %s; %d dead ends)" % [" ".join(sizes), dead_ends], bad.is_empty() and dead_ends >= 60, "; ".join(bad.slice(0, 4)))
	_check("rooms of every kind, furnished (%d rooms: %s; bare %d)" % [rooms, str(types), bare.size()],
			types.size() >= 13 and bare.size() <= rooms / 20, " ".join(bare.slice(0, 12)))
	_check("each room has what makes it that room (%d missing of %d)" % [unmarked.size(), rooms], unmarked.size() <= rooms / 25, ", ".join(unmarked.slice(0, 12)))


## Every tape and battery of this run rests on the floor, inside a free
## cell, touching no wall or furniture.
func _check_pickups(run: Run) -> void:
	var space := run.level.get_world_3d().direct_space_state
	var bad := PackedStringArray()
	var count := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		var pk := p as Pickup
		count += 1
		var at := pk.global_position
		var c := run.level.cell_of(at)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 0.5, Tuning.LAYER_WORLD)
		var hit := space.intersect_ray(ray)
		var shape := SphereShape3D.new()
		shape.radius = 0.12
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), at + Vector3.UP * 0.2)
		q.collision_mask = Tuning.LAYER_WORLD
		if not run.level.is_walkable(c):
			bad.append("%s in %s cell %s" % [pk.name, run.level.char_at(c), c])
		elif hit.is_empty() or absf(hit.position.y - at.y) > 0.05:
			bad.append("%s not on the floor" % pk.name)
		elif not space.intersect_shape(q, 1).is_empty():
			bad.append("%s inside geometry" % pk.name)
	_check("%d pickups lie free on the floor" % count, bad.is_empty() and count >= run.tapes_needed - 1, "; ".join(bad))


## Batteries wait in the bag; R puts one in; the hint comes once.
func _check_batteries(run: Run, player: Player) -> void:
	var seen := Settings.reload_hint_seen
	Settings.reload_hint_seen = false
	var cam := player.camcorder
	var charge := cam.battery
	cam.battery = 0.0
	var quiet := not run.reload_hint()
	var carried := player.inventory.count("battery")
	run._request_pickup("Battery0")
	await get_tree().process_frame
	_check("a battery goes to the bag, not into the camera", player.inventory.bag.has("battery") and player.inventory.count("battery") == carried + 1 and cam.battery == 0.0,
			"count %d battery %.0f" % [player.inventory.count("battery"), cam.battery])
	var slot := "bag%d" % player.inventory.bag.find("battery")
	_check("a spare battery cannot go in a hand", not player.inventory.can_swap(slot, "left") and player.inventory.can_swap(slot, "bag%d" % player.inventory.bag.find("")), "")
	_check("empty with a spare: the hint shows", quiet and run.reload_hint() and Settings.reload_hint_seen, "quiet=%s" % quiet)
	run._reloaded_at = -Run.RELOAD_LOCK_MS
	run._on_reload()
	_check("R puts the battery in", cam.battery == Tuning.BATTERY_PICKUP and player.inventory.count("battery") == carried and not run.reload_hint(),
			"battery %.0f count %d" % [cam.battery, player.inventory.count("battery")])
	player.inventory.add_to_bag("battery")
	cam.battery = 0.0
	_check("the hint never comes back", not run.reload_hint(), "")
	player.inventory.remove("battery")
	cam.battery = charge
	Settings.reload_hint_seen = seen
	Settings.save()


## "La Visita es un jugador" (last: this machine becomes the entity): it
## walks where you push it, climbs to the ceiling and back, a grab at
## nobody misses (and slows it), a flash blinds it, and a grab at someone
## right in front takes them.
func _check_pilot(main: Node, run: Run, player: Player, entity: Entity) -> void:
	run.phase = Run.Phase.PLAYING
	var line := run.level.find_line(7)
	if line.is_empty():
		_check("pilot: a straight corridor to test in", false, "")
		return
	var start: Vector3i = line[0]
	var dir: Vector2i = line[1]
	run.spawn_bot()
	var bot: Player = null
	for p: Player in run.players.values():
		if p.has_node("Bot"):
			bot = p
	bot.get_node("Bot").queue_free()
	bot.net_god = false
	bot.alive = true
	for c in run.corpses:
		if is_instance_valid(c):
			c.queue_free()
	run.corpses.clear()
	entity.state = Entity.State.STALKING
	entity._set_mode(Entity.Mode.WANDER, 0.0, "test")
	entity._flash_immune = 0.0
	run.entity_peer = player.peer_id
	entity.pilot_id = player.peer_id
	entity.players.erase(player)
	player.alive = false
	run.become_pilot()
	run.screens.visible = false  # (the end screens of the earlier checks)
	for c in run.screens.get_parent().get_children():
		if c is ReplayUI:
			c.visible = false
	var pilot := run.pilot
	pilot.place(run.level.center(start))
	pilot.yaw = atan2(-float(dir.x), -float(dir.y))
	bot.global_position = run.level.center(start + Vector3i(dir.x * 6, 0, dir.y * 6))
	bot.net_pos = bot.global_position
	var from := pilot.body.global_position
	Input.action_press("move_forward")
	await _wait(0.6)
	Input.action_release("move_forward")
	await _wait(0.2)
	var walked := pilot.body.global_position.distance_to(from)
	var shot := OS.get_cmdline_user_args().find("--pilot-shot")  # dev: what the entity's player sees
	if shot >= 0:
		var dir_out: String = OS.get_cmdline_user_args()[shot + 1]
		Sfx.play_3d(run.level, bot.global_position, "pickup", 0.0)
		var was_at := bot.global_position
		bot.global_position = pilot.body.global_position + Vector3(dir.x, 0, dir.y) * 2.2
		bot.net_pos = bot.global_position
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir_out.path_join("pilot_heat.png"))
		bot.global_position = was_at
		bot.net_pos = was_at
		pilot.sense_left = 3.0
		await _wait(0.3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir_out.path_join("pilot_walk.png"))
		print("PILOTHUD size=", pilot.hud.size, " vis=", pilot.hud.visible, " pings=", pilot.pings.size(), " sensed=", pilot.sensed().size(), " veil=", pilot.hud.get_child(0).size)
	_check("pilot: it walks where you push it, and the entity is there", walked > 0.8 and entity.global_position.distance_to(pilot.body.global_position) < 0.05,
			"walked %.2f m" % walked)
	# The mouse turns its view.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var yaw0 := pilot.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 0)
	motion.screen_relative = Vector2(80, 0)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("pilot: the mouse turns its view", absf(pilot.yaw - yaw0) > 0.05, "yaw %.2f -> %.2f (mouse %s)" % [yaw0, pilot.yaw, Input.mouse_mode])
	pilot.yaw = yaw0
	var floor_y := pilot.body.global_position.y
	pilot._toggle_ceiling()
	await _wait(Tuning.PILOT_CLIMB_TIME + 0.15)
	var up := pilot.ceiling and entity.on_ceiling and absf(pilot.body.global_position.y - floor_y) < 0.05 and pilot.camera.global_position.y > floor_y + 2.0
	if shot >= 0:
		pilot.pitch = -0.6
		await _wait(0.2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[shot + 1].path_join("pilot_ceiling.png"))
		pilot.pitch = 0.0
	await _wait(Tuning.PILOT_CEILING_COOLDOWN + 0.1)
	pilot._toggle_ceiling()
	await _wait(Tuning.PILOT_CLIMB_TIME + 0.15)
	_check("pilot: up to the ceiling and back down", up and not pilot.ceiling and not entity.on_ceiling, "up=%s now=%s" % [up, pilot.ceiling])
	pilot.place(run.level.center(start))
	pilot.yaw = atan2(float(dir.x), float(dir.y))  # (charging away from the bot: at nobody)
	await _wait(0.1)
	pilot._attack()
	await _wait(Tuning.PILOT_CHARGE_TIME + 0.3)
	_check("pilot: a grab at nobody misses and slows it", pilot.miss > 0.0 and bot.alive, "miss=%.2f bot alive=%s" % [pilot.miss, bot.alive])
	run._pilot_burned(bot)
	await _wait(0.1)
	_check("pilot: a flash blinds it", pilot.stun > 0.0, "stun=%.2f" % pilot.stun)
	# E at an empty hiding place: it gets in itself (unseen); E again, out.
	if not run.level.hide_spots.is_empty():
		var spot: HideSpot = run.level.hide_spots[0]
		await _wait(Tuning.PILOT_STUN + 0.2)
		pilot.place(run.level.center(spot.access))
		await _wait(0.1)
		pilot._asked_spot = spot
		run._pilot_search(String(spot.name))
		await _wait(0.2)
		var inside := pilot.hidden == spot and entity.gone and not entity.flash_hits(bot)
		pilot._leave_hiding()
		await _wait(0.2)
		_check("pilot: it hides in an empty hiding place like the crew, and gets out", inside and pilot.hidden == null and not entity.gone,
				"inside=%s now hidden=%s gone=%s" % [inside, pilot.hidden, entity.gone])
	await _wait(Tuning.PILOT_STUN + 0.2)
	pilot.attack_cd = 0.0
	pilot.place(run.level.center(start))
	pilot.yaw = atan2(-float(dir.x), -float(dir.y))  # (it was facing out of the hiding place)
	bot.global_position = run.level.center(start + Vector3i(dir.x * 2, 0, dir.y * 2))
	bot.net_pos = bot.global_position
	await _wait(0.15)
	pilot._attack()
	await _wait(Tuning.PILOT_CHARGE_TIME + 0.4)
	_check("pilot: a grab at someone right in front takes them", not bot.alive, "bot alive=%s at %.2f m phase=%d state=%d miss=%.2f t=%.1f at=%.1f" % [bot.alive, bot.global_position.distance_to(entity.global_position), run.phase, entity.state, pilot.miss, run.time, run._pilot_attack_at])


func _check(what: String, ok: bool, detail: String) -> void:
	if ok:
		print("SMOKE ok   ", what)
	else:
		_fails += 1
		print("SMOKE FAIL ", what, " (", detail, ")")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The voice chat's pipeline: the microphone resampled to 16 kHz without
## the highs folding back; the codec; the jitter buffer playing frames in
## order, hiding a lost one, and skipping ahead when far behind.
func _check_voice(main: Node, player: Player) -> void:
	var vc: VoiceChat = main.get_node("VoiceChat")
	vc._src_rate = 48000.0
	for f: VoiceChat.Biquad in vc._lp:
		f.setup("low", 7200.0, 48000.0)
	vc._hp.setup("high", 110.0, VoiceChat.RATE)
	vc._out.clear()
	var buf := PackedVector2Array()
	for i in 48000:
		var x := sin(TAU * 440.0 * i / 48000.0) * 0.5 + sin(TAU * 12000.0 * i / 48000.0) * 0.3
		buf.append(Vector2(x, x))
	vc._resample(buf)
	var out := vc._out.duplicate()
	vc._out.clear()
	var crossings := 0
	var sum := 0.0
	for i in range(8000, out.size()):
		if (out[i - 1] < 0.0) != (out[i] < 0.0):
			crossings += 1
		sum += out[i] * out[i]
	var hz := crossings / 2.0 / ((out.size() - 8000) / 16000.0)
	var rms := sqrt(sum / (out.size() - 8000))
	_check("voice: the mic is resampled to 16 kHz, the highs filtered out",
			absi(out.size() - 16000) < 3 and absf(hz - 440.0) < 6.0 and absf(rms - 0.354) < 0.04,
			"n=%d hz=%.1f rms=%.3f" % [out.size(), hz, rms])
	var dec := VoiceChat._decode(VoiceChat._encode(PackedFloat32Array([0.0, 0.25, -0.5, 0.9])))
	_check("voice: mu-law round trip", absf(dec[1].x - 0.25) < 0.01 and absf(dec[2].x + 0.5) < 0.02 and absf(dec[3].x - 0.9) < 0.03, str(dec))
	var v := vc._voice_for(player.peer_id)
	var frames: Dictionary = v.frames
	var mk := func(level: float) -> PackedVector2Array:
		var a := PackedVector2Array()
		a.resize(VoiceChat.FRAME)
		a.fill(Vector2(level, level))
		return a
	# 65534, 65535, (0 lost), 1, 2: out of order, across the wrap.
	for seq: int in [65535, 65534, 2, 1]:
		frames[seq] = mk.call(0.1)
	v.last_heard = vc._clock
	var pb: AudioStreamGeneratorPlayback = v.playback
	var before := pb.get_frames_available()
	vc._feed(player.peer_id)
	var pushed := before - pb.get_frames_available()
	# 4 frames and the lost one filled in: 5 frames, in order, up to 2.
	_check("voice: the jitter buffer plays in order from the oldest, filling in a lost frame",
			pushed == 5 * VoiceChat.FRAME and int(v.next) == 3 and frames.is_empty(),
			"pushed=%d next=%d lost=%d left=%d" % [pushed, v.next, v.lost, frames.size()])
	for seq in 40:
		frames[(int(v.next) + 100 + seq) % 65536] = mk.call(0.1)
	pb.clear_buffer()
	vc._feed(player.peer_id)
	_check("voice: far behind, it skips ahead", frames.size() <= VoiceChat.JITTER_START, "left=%d" % frames.size())
	frames.clear()
	v.next = -1
	pb.clear_buffer()


## The best moments: the catch was kept, the host's pick arrives, a clip
## plays back from the tape (its own camera, the entity drawn), and stopping
## puts the house back as it was.
func _check_replay(main: Node, run: Run, player: Player, entity: Entity) -> void:
	var rp := run.replay
	# Your own voice goes on the tape (a test tone through the real microphone path).
	var waited0 := 0.0
	while rp.clips.is_empty() and waited0 < 6.0:
		await _wait(0.2)
		waited0 += 0.2
	rp.stop()  # (the first clip starts on its own: nothing is taped while one plays)
	var vc: VoiceChat = main.get_node("VoiceChat")
	var before := rp._events.filter(func(e: Array) -> bool: return e[1] == "voice").size()
	vc.test_tone = true
	await _wait(0.5)
	vc.test_tone = false
	var taped := rp._events.filter(func(e: Array) -> bool: return e[1] == "voice").size() - before
	_check("best moments: what you say is recorded", taped > 5, "%d voice frames taped" % taped)
	var waited := 0.0
	while rp.clips.is_empty() and waited < 6.0:
		await _wait(0.2)
		waited += 0.2
	var has_catch := rp.moments.values().any(func(m: Dictionary) -> bool: return m.kind == "caught")
	# A voice on the tape (as if the player had talked): it must be heard.
	if not rp.clips.is_empty():
		var c: Dictionary = rp.clips[0]
		var t0: float = rp.moments[int(c.id)].at + float(c.from)
		var tone := PackedFloat32Array()
		tone.resize(VoiceChat.FRAME)
		for k in 120:
			for i in VoiceChat.FRAME:
				tone[i] = sin((k * VoiceChat.FRAME + i) * TAU * 300.0 / VoiceChat.RATE) * 0.5
			rp._events.append([t0 + 0.05 + k * 0.02, "voice", [player.peer_id, VoiceChat._encode(tone)]])
		rp._events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	rp.play(0)
	await _wait(0.6)
	var voice_bus := AudioServer.get_bus_index(VoiceChat.VOICE_BUS)
	var heard_db := AudioServer.get_bus_peak_volume_left_db(voice_bus, 0) if voice_bus >= 0 else -200.0
	var shot := OS.get_cmdline_user_args().find("--replay-shot")  # dev: what a clip looks like
	if shot >= 0:
		var dir: String = OS.get_cmdline_user_args()[shot + 1]
		for k in 3:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("replay_%d.png" % k))
			await _wait(1.2)
		rp.stop()
		await _wait(0.3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("replay_list.png"))
		rp.play(0)
		await _wait(0.2)
	var cam_ok: bool = rp.playing and main.world.get_camera_3d() == rp._camera and not entity.visible and (rp._ent.visible or (rp._ent_model != null and rp._ent_model.visible))
	rp.stop()
	await get_tree().process_frame
	_check("best moments: the catch is kept and plays back from the tape, then all is put back",
			has_catch and cam_ok and entity.visible and player.visible and not rp.playing and main.world.get_camera_3d() != rp._camera,
			"clips=%d catch=%s cam=%s frames=%d" % [rp.clips.size(), has_catch, cam_ok, rp._frames.size()])
	_check("best moments: your own voice is heard in your clip", heard_db > -40.0, "voice bus peak %.1f dB" % heard_db)


## Windows: real openings you see out of; E opens and closes the sash (not
## twice in a row), it slides up, the entity hears it, and open or shut
## nobody gets out through it.
func _check_windows(run: Run, player: Player) -> void:
	var level := run.level
	_check("windows: the house has sash windows in its outside walls", not level.windows.is_empty(),
			"%d windows" % level.windows.size())
	if level.windows.is_empty():
		return
	var was_phase := run.phase
	var was_alive := player.alive
	run.phase = Run.Phase.PLAYING
	player.alive = true
	var w: HouseWindow = level.windows[0]
	var room := w.cell + Vector3i(w.inward.x, 0, w.inward.y)
	player.global_position = level.center(room)
	run._request_window(String(w.name))
	var opened := w.is_open
	run._request_window(String(w.name))
	var spam_ignored := w.is_open
	await _wait(HouseWindow.SLIDE_TIME + HouseWindow.COOLDOWN + 0.1)
	var lifted: bool = w.amount >= 1.0 and (w.get_node("Sash") as Node3D).position.y > HouseWindow.LIFT * 0.9
	# Out through the gap under the lifted sash: something solid stops you.
	var from := level.center(room) + Vector3.UP * (HouseWindow.SILL_Y + 0.2)
	var out := Vector3(-w.inward.x, 0, -w.inward.y)
	var q := PhysicsRayQueryParameters3D.create(from, from + out * 2.5, Tuning.LAYER_WORLD)
	var blocked := not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	run._request_window(String(w.name))
	var closed := not w.is_open
	await _wait(HouseWindow.SLIDE_TIME + HouseWindow.COOLDOWN + 0.1)
	_check("windows: E opens and closes a window, but not twice in a row; open, nobody climbs out",
			opened and spam_ignored and lifted and blocked and closed and w.amount <= 0.0,
			"opened=%s spam_ignored=%s lifted=%s blocked=%s closed=%s" % [opened, spam_ignored, lifted, blocked, closed])
	run.phase = was_phase
	player.alive = was_alive


## Doors: E opens and closes them (not spammable, not on anyone, not with
## the entity at it); the entity opens a closed door in its way and goes
## over a stable one; a closed door blocks its sight; a friend's flash
## dazzles you.
func _check_doors(main: Node, run: Run, player: Player, entity: Entity) -> void:
	var level := run.level
	var full: Door = null
	var windowed: Door = null
	for d in level.doors:
		if d.transom and windowed == null:
			windowed = d
		elif not d.transom and full == null:
			full = d
	_check("doors: the house has doors, some with a broken window over them", full != null and windowed != null and level.doors.size() >= 3,
			"%d doors" % level.doors.size())
	if full == null:
		return
	# (The night may be over by now: back to playing, alive, for these.)
	var was_phase := run.phase
	var was_alive := player.alive
	run.phase = Run.Phase.PLAYING
	player.alive = true
	player.net_god = true
	entity.set_physics_process(false)
	var a: Vector3i = full.cell - Vector3i(full.axis.x, 0, full.axis.y)
	var b: Vector3i = full.cell + Vector3i(full.axis.x, 0, full.axis.y)
	# A player opens and closes it; twice in a row does nothing (cooldown).
	full.set_open.rpc(false)
	full._cool = 0.0
	full.amount = 0.0
	player.global_position = level.center(a)
	entity.global_position = level.center(a) + Vector3(0, 0, 0) + Vector3(40, 0, 40)
	run._request_door(String(full.name))
	var opened := full.is_open
	run._request_door(String(full.name))
	var spam_ignored := full.is_open
	await _wait(Door.SWING_TIME + Door.COOLDOWN + 0.1)
	run._request_door(String(full.name))
	var closed := not full.is_open
	await _wait(Door.SWING_TIME + Door.COOLDOWN + 0.1)
	_check("doors: E opens and closes a door, but not twice in a row", opened and spam_ignored and closed, "opened=%s spam_ignored=%s closed=%s phase=%d alive=%s" % [opened, spam_ignored, closed, run.phase, player.alive])
	# It can be shut in its face, but not with it in the doorway.
	full.set_open.rpc(true)
	full._cool = 0.0
	full.amount = 1.0
	var old_state := entity.state
	entity.state = Entity.State.STALKING
	entity.global_position = level.center(full.cell)
	run._request_door(String(full.name))
	var held := full.is_open
	full._cool = 0.0
	full.amount = 1.0
	entity.global_position = level.center(b)
	run._request_door(String(full.name))
	_check("doors: shut in its face, but not with it in the doorway", held and not full.is_open, "held=%s open=%s" % [held, full.is_open])
	# Closed, it blocks the entity's sight; it opens it to come through.
	full.set_open.rpc(false)
	full._cool = 0.0
	full.amount = 0.0
	full._apply()
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.global_position = level.center(a)
	entity.global_position = level.center(b)
	var space := level.get_world_3d().direct_space_state
	var blind := not entity._can_see(space, player)
	entity._path.clear()
	entity._repath = 0.0
	var through := false
	for i in 240:
		entity._walk_to(level.center(a), Tuning.ENTITY_SPEED * 0.05, 0.05)
		await get_tree().process_frame
		if level.cell_of(entity.global_position) == a:
			through = true
			break
	_check("doors: closed, it hides you; the entity opens it and comes through", blind and full.is_open and through,
			"blind=%s open=%s through=%s" % [blind, full.is_open, through])
	# A broken window over the door: through it, the door stays shut.
	if windowed:
		var da: Vector3i = windowed.cell - Vector3i(windowed.axis.x, 0, windowed.axis.y)
		var db: Vector3i = windowed.cell + Vector3i(windowed.axis.x, 0, windowed.axis.y)
		windowed.set_open.rpc(false)
		windowed.amount = 0.0
		windowed._apply()
		entity.global_position = level.center(db)
		entity._path.clear()
		entity._repath = 0.0
		entity.on_ceiling = false
		entity._over_door = false
		var over := false
		var crossed := false
		var up_at := -1.0  # how far from the door it went up
		for i in 240:
			entity._walk_to(level.center(da), Tuning.ENTITY_SPEED * 0.05, 0.05)
			entity._door_guard()
			if entity.on_ceiling and up_at < 0.0:
				up_at = entity.global_position.distance_to(windowed.global_position)
			over = over or entity.on_ceiling
			await get_tree().process_frame
			if level.cell_of(entity.global_position) == da:
				crossed = true
				break
		# Past it, it stays up there a while, then comes down.
		var still_up := entity.on_ceiling
		var down := false
		for i in 180:
			entity._door_guard()
			await get_tree().physics_frame
			if not entity.on_ceiling:
				down = true
				break
		_check("doors: with a broken window over it, it goes up well before it, through the window, stays up a while, the door stays shut",
				crossed and over and up_at > 0.9 and still_up and down and not windowed.is_open,
				"crossed=%s up %.2f m before still_up=%s down=%s open=%s" % [crossed, up_at, still_up, down, windowed.is_open])
	entity.state = old_state
	entity.set_physics_process(true)
	# A friend's flash in your eyes.
	var friend := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	friend.setup(77, "Amigo", Net.COLORS[1], false)
	main.world.add_child(friend)
	var line := level.find_line(4)  # a straight free run of cells
	var spot: Vector3i = line[0]
	var ld: Vector2i = line[1]
	player.global_position = level.center(spot)
	player.set_view(atan2(-ld.x, -ld.y))
	await get_tree().physics_frame
	var ahead := player.global_position - player.global_transform.basis.z * 2.0
	friend.global_position = ahead
	friend.net_pos = ahead
	friend.net_yaw = player.rotation.y + PI  # looking back at us
	friend.rotation.y = friend.net_yaw
	await get_tree().physics_frame
	var power := run._dazzle(player, friend)
	friend.net_yaw = player.rotation.y  # its back to us
	friend.rotation.y = friend.net_yaw
	await get_tree().physics_frame
	var back := run._dazzle(player, friend)
	_check("flash: a friend looking at it is dazzled, one with their back to it is not", power > 0.3 and back == 0.0,
			"power=%.2f back=%.2f" % [power, back])
	friend.queue_free()
	run.phase = was_phase
	player.alive = was_alive
	player.net_god = false
