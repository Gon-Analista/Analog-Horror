class_name ShotTour
extends Node
## Dev: a camera tour of the generated house that saves screenshots (window
## resolution, UI included) and quits, to review the look without playing:
##   godot --path game -- --shots <absolute dir> [--seed N] [--tapes N]
## It finds its own viewpoints (rooms by type, the stairs, a straight run,
## the boarded doorways), so it works on any house; the map is printed too.


func run_tour(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var player: Player = main.player
	var entity: Entity = main.entity
	var run: Run = main.run
	var level: Level = run.level
	entity.set_physics_process(false)
	_print_map(level.layout)
	await _wait(1.5)

	await _room_shot(player, level, "hall", dir, "01_hallway")
	# The pause menu with its options (and the controls and accessibility).
	for child in main.get_node("UILayer").get_children():
		if child is PauseMenu:
			var pause := child as PauseMenu
			pause.open()
			pause._options.visible = true
			pause._centre()
			await _wait(0.5)
			await _shot(dir, "01b_pause")
			pause.close()
	if OS.get_cmdline_user_args().has("--pause-only"):  # dev: just that one
		get_tree().quit()
	if OS.get_cmdline_user_args().has("--house-only"):  # dev: windows, rooms, materials
		await house_shots(main, dir)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--soot-only"):  # dev: just the soot
		await soot_shots(main, dir)
		get_tree().quit()
		return
	await _room_shot(player, level, "living", dir, "02_living")
	# Watching the show, then the alert cutting in.
	var tv := run.tv
	var front := tv.global_position - tv.global_transform.basis.z * 1.3
	player.global_position = Vector3(front.x, level.center(level.cell_of(front)).y, front.z)
	player.set_view(tv.global_rotation.y + PI, -0.2)
	for child in tv.get_children():
		if child is ReadableScreen:
			run._on_interact(child)
	# The programme, then each step of it going wrong (by how long it has
	# been watched), then the alert; then the broadcast turned, and a hijack.
	var at := func(w: float) -> void:
		while tv.watched < w:
			await get_tree().process_frame
	await _wait(1.0)
	await _shot(dir, "03_tv_show")
	await at.call(Tuning.TV_DISTURB_AT + Tuning.TV_DISTURB_TIME * 0.35)
	await _shot(dir, "03b_tv_stare")
	await at.call(Tuning.TV_DISTURB_AT + Tuning.TV_DISTURB_TIME * 0.5)
	await _shot(dir, "03c_tv_live")
	await at.call(Tuning.TV_DISTURB_AT + Tuning.TV_DISTURB_TIME * 0.62)
	await _shot(dir, "03d_tv_dark")
	await at.call(Tuning.TV_DISTURB_AT + Tuning.TV_DISTURB_TIME * 0.84)
	await _shot(dir, "03e_tv_live_close")
	tv._feed_vp.get_texture().get_image().save_png(dir.path_join("03e2_feed_raw.png"))
	await at.call(Tuning.TV_DISTURB_AT + Tuning.TV_DISTURB_TIME * 0.95)
	await _shot(dir, "03f_tv_live_runs")
	await _wait(TvBroadcast.INTERRUPT_TIME + 1.5)
	await _shot(dir, "04_tv_alert")
	run._on_interact(null)
	await _wait(0.5)
	await _shot(dir, "04b_tv_alert_room")
	tv.set_corrupted()
	await _wait(1.0)
	await _shot(dir, "04c_tv_corrupt")
	tv._hijack_in = 0.0
	await _wait(0.35)
	await _shot(dir, "04d_tv_hijack")
	entity.state = Entity.State.STALKING  # woken by the alert; keep it still for the tour
	# The monitor (Alt+F1), as the entity wanders.
	entity.set_physics_process(true)
	var monitor: EntityMonitor = main.get_node("UILayer").get_children().filter(func(n: Node) -> bool: return n is EntityMonitor)[0]
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.alt_pressed = true
	key.pressed = true
	monitor._input(key)
	await _wait(3.0)
	await _shot(dir, "40_monitor")
	monitor._input(key)
	entity.set_physics_process(false)
	await _room_shot(player, level, "kitchen", dir, "05_kitchen")
	await _room_shot(player, level, "kid", dir, "06_kid_room")
	await _room_shot(player, level, "bedroom", dir, "07_bedroom", 0)
	await _room_shot(player, level, "bathroom", dir, "07b_bathroom")
	await _room_shot(player, level, "storage", dir, "07c_storage")
	for t: String in ["study", "laundry", "playroom", "sewing", "pantry", "dining"]:  # (whichever this house has)
		await _room_shot(player, level, t, dir, "07t_" + t)

	# The stairs, from below and from the landing above.
	if not level.layout.stairs.is_empty():
		var s: Dictionary = level.layout.stairs[0]
		var bottom: Vector3i = s.bottom
		var top: Vector3i = s.top
		var d: Vector2i = s.dir
		await _look_shot(player, level, bottom + Vector3i(0, 0, 1), level.center(top) + Vector3.UP * 1.2, dir, "07d_stairs_up")
		var above := top + Vector3i(d.x, 0, d.y)
		if not level.is_walkable(above):
			above = top
		await _look_shot(player, level, above, level.center(bottom), dir, "07e_stairs_down")
		await _room_shot(player, level, "bedroom", dir, "07f_upstairs", 1)

	# The entity 4 m ahead along a straight run: naked eye, then filmed.
	var line := level.find_line(7)
	var start: Vector3i = line[0]
	var ld: Vector2i = line[1]
	var ahead := func(n: int) -> Vector3: return level.center(start + Vector3i(ld.x * n, 0, ld.y * n))
	entity.global_position = ahead.call(5)
	await _look_shot(player, level, start, ahead.call(6) + Vector3.UP * 1.3, dir, "08_naked_eye")
	player.camcorder.force_held = true
	await _wait(0.8)
	await _shot(dir, "09_camcorder")
	# Out of battery with two spares: the hint, through the viewfinder and not.
	var seen := Settings.reload_hint_seen
	Settings.reload_hint_seen = false
	player.inventory.add_to_bag("battery")
	player.inventory.add_to_bag("battery")
	player.camcorder.battery = 0.0
	await _wait(0.4)
	await _shot(dir, "09b_reload_hint")
	player.camcorder.force_held = false
	await _wait(0.8)
	await _shot(dir, "09c_reload_hint_naked")
	player.camcorder.force_held = true
	player.inventory.remove("battery")
	player.inventory.remove("battery")
	player.camcorder.battery = 100.0
	Settings.reload_hint_seen = seen
	Settings.save()
	await _wait(0.5)
	entity.global_position = ahead.call(2)
	await _wait(0.4)
	await _shot(dir, "10_camcorder_close")
	player.camcorder.force_held = false

	# First-person hands, the camcorder going up, and a teammate.
	entity.global_position = level.center(level.spots_of("E")[0])
	await _look_shot(player, level, start, ahead.call(6) + Vector3.UP * 1.3, dir, "11_hands")
	player.camcorder.force_held = true
	for i in 3:
		await get_tree().process_frame
	await _shot(dir, "12_raising")
	player.camcorder.force_held = false
	await _wait(0.5)
	var mate := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	mate.setup(2, "Lucía", Net.COLORS[1], false)
	main.world.add_child(mate)
	mate.global_position = ahead.call(2) + Vector3(0.1, 0, 0.1)
	mate.net_pos = mate.global_position
	mate.net_yaw = atan2(-ld.x, -ld.y) + PI + 0.3
	mate.rotation.y = mate.net_yaw
	mate.net_pitch = -0.1
	await _wait(0.6)
	await _shot(dir, "13_teammate")
	mate.net_raise = 1.0
	mate.net_filming = true
	mate.net_pitch = 0.0
	await _wait(0.7)
	await _shot(dir, "14_teammate_filming")
	mate.queue_free()
	var exit: Vector3i = level.spots_of("X")[0]
	await _look_shot(player, level, level.spots_of("P")[0] + Vector3i(-2, 0, -1), level.center(exit) + Vector3.UP * 1.1, dir, "15_exit")

	# A boarded doorway, crouched; then the entity squeezing under it.
	var boards := level.spots_of("U")
	if not boards.is_empty():
		var b: Vector3i = boards[0]
		var side := Vector2i.ZERO
		for d in Level.DIRS:
			if level.is_walkable(b + Vector3i(d.x, 0, d.y)) and level.is_walkable(b + Vector3i(d.x * 2, 0, d.y * 2)):
				side = d
				break
		var stand := b + Vector3i(side.x * 2, 0, side.y * 2)
		player._set_crouch(true)
		player.crouching = true
		await _look_shot(player, level, stand, level.center(b) + Vector3.UP * 0.5, dir, "16_boards_crouched")
		player._set_crouch(false)
		player.crouching = false
		entity.global_position = level.center(b) + Vector3(side.x, 0, side.y) * 0.1
		await _look_shot(player, level, stand, level.center(b) + Vector3.UP * 0.4, dir, "17_crawl_naked")
		player.camcorder.force_held = true
		await _wait(0.6)
		await _shot(dir, "18_crawl_camcorder")
		player.camcorder.force_held = false

	# Lurking: behind a corner near you, only the head leaning into the frame.
	player.global_position = level.center(start)
	entity.target = player
	var tc := level.nearest_walkable(level.cell_of(player.global_position))
	if entity._pick_corner(tc, [player.camera.global_position], player.camera.global_position, 3, 8):
		entity.pose = Entity.Pose.TILT
		entity.global_position = level.center(entity._hide) + entity._hide_dir * 0.38
		await _look_shot(player, level, start, entity.global_position + Vector3.UP * 1.6, dir, "24_lurk_naked")
		player.camcorder.force_held = true
		await _wait(0.6)
		await _shot(dir, "25_lurk_camcorder")
		entity.pose = Entity.Pose.STRETCH  # found out: the neck grows at you
		await _wait(0.3)
		await _shot(dir, "25c_found_stretch")
		player.camcorder.force_held = false
		entity.pose = Entity.Pose.STAND
	else:
		print("TOUR no corner to lurk behind near ", start)

	# On the ceiling, over the way you will walk.
	entity.on_ceiling = true
	entity.global_position = ahead.call(3)
	await _look_shot(player, level, start, ahead.call(3) + Vector3.UP * 2.4, dir, "32_ceiling_naked")
	player.camcorder.force_held = true
	await _wait(0.6)
	await _shot(dir, "33_ceiling_camcorder")
	player.camcorder.force_held = false
	entity.on_ceiling = false

	# On all fours, coming at you down the corridor; walking; the flash.
	entity.mode = Entity.Mode.CHASE
	player.camcorder.force_held = true
	await _look_shot(player, level, start, ahead.call(5) + Vector3.UP * 0.8, dir, "34_pre_gallop")
	var from5: Vector3 = ahead.call(6)
	var to5: Vector3 = ahead.call(2)
	for i in 40:
		entity.global_position = from5.lerp(to5, i / 40.0)
		await get_tree().process_frame
	await _shot(dir, "35_gallop_camcorder")
	entity.mode = Entity.Mode.WANDER
	for i in 40:
		entity.global_position = to5.lerp(from5, i / 80.0)
		await get_tree().process_frame
	await _shot(dir, "36_walk_camcorder")
	run._on_flash()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(dir, "37_flash")
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "37b_vanish")
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "37c_vanish")
	entity.vanishing = false  # (back for the rest of the tour)
	entity.gone = false
	player.camcorder.force_held = false
	await _wait(0.5)

	entity.enraged = true
	entity.global_position = ahead.call(4)
	await _look_shot(player, level, start, ahead.call(6) + Vector3.UP * 1.3, dir, "19_enraged_naked")
	player.camcorder.force_held = true
	await _wait(0.6)
	await _shot(dir, "20_enraged_camcorder")
	player.camcorder.force_held = false
	entity.enraged = false

	# Found hiding: it leans in and shows its face (under a bed, in a wardrobe).
	for kind: int in [HideSpot.Kind.BED, HideSpot.Kind.WARDROBE]:
		var spot: HideSpot = null
		for sp in level.hide_spots:
			if sp.kind == kind:
				spot = sp
		if spot == null:
			continue
		var tag := "bed" if kind == HideSpot.Kind.BED else "wardrobe"
		player.global_position = level.center(spot.access)
		player.hide_in(spot)
		await _wait(0.4)
		await _shot(dir, "25b_hidden_%s" % tag)
		entity._peek_into(spot, player)
		await _wait(0.5)
		await _shot(dir, "26_peek_%s_naked" % tag)
		player.camcorder.force_held = true
		await _wait(0.8)
		await _shot(dir, "27_peek_%s_camcorder" % tag)
		player.camcorder.force_held = false
		player.leave_hide()
		entity.mode = Entity.Mode.WANDER
		entity.pose = Entity.Pose.STAND
		await _wait(0.4)

	# A teammate taken (the entity invisible: lifted by nothing), and the
	# hands of someone without a camcorder.
	entity.global_position = ahead.call(5)
	var victim := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	victim.setup(3, "Marco", Net.COLORS[2], false)
	main.world.add_child(victim)
	victim.global_position = ahead.call(4)
	victim.net_pos = victim.global_position
	victim.net_yaw = atan2(-ld.x, -ld.y)
	await _look_shot(player, level, start, ahead.call(5) + Vector3.UP * 1.2, dir, "22a_teammate_before")
	victim.alive = false
	victim.avatar.play_death(entity.global_position)
	await _wait(1.0)
	await _shot(dir, "22b_teammate_taken")
	player.has_camera = false
	await _wait(0.5)
	await _shot(dir, "23_no_camera_hands")
	player.has_camera = true
	victim.queue_free()

	# What is left of them: the body, dragged off and thrown (alone it slides
	# and flies by itself; through the camcorder, it is in its hands).
	var body := Corpse.new()
	body.setup(3, Net.COLORS[2])
	level.add_child(body)
	body.global_position = ahead.call(3) + Vector3.UP * 0.14
	entity.global_position = ahead.call(3) + Vector3(ld.x, 0, ld.y) * 0.7
	entity.pose = Entity.Pose.CROUCH
	await _look_shot(player, level, start, ahead.call(3), dir, "26_body")
	player.camcorder.force_held = true
	await _wait(0.6)
	await _shot(dir, "27_body_camcorder")
	player.camcorder.force_held = false
	body.throw_to(ahead.call(1))
	await _wait(Corpse.THROW_TIME * 0.45)
	await _shot(dir, "28_body_thrown")
	await _wait(1.0)
	await _shot(dir, "29_body_landed")
	entity.pose = Entity.Pose.STAND

	# Hiding: under a bed, under a table, in a wardrobe; and it looking in.
	body.queue_free()
	for kind: HideSpot.Kind in [HideSpot.Kind.BED, HideSpot.Kind.TABLE, HideSpot.Kind.WARDROBE]:
		for s: HideSpot in level.hide_spots:
			if s.kind != kind:
				continue
			player.global_position = level.center(s.access)
			player.hide_in(s)
			entity.pose = Entity.Pose.STAND
			entity.global_position = level.center(s.access) + s.facing * 1.2
			await _wait(0.8)
			var tag: String = ["bed", "table", "wardrobe"][kind]
			await _shot(dir, "30_hide_%s" % tag)
			if kind == HideSpot.Kind.BED:
				# It bends down to look under the bed: on camera...
				entity.pose = Entity.Pose.CROUCH
				entity.global_position = level.center(s.access) + s.facing * 0.2
				player.camcorder.force_held = true
				await _wait(0.8)
				await _shot(dir, "31_hide_bed_it_looks")
				player.camcorder.force_held = false
				await _wait(0.4)
			player.leave_hide()
			break
	entity.pose = Entity.Pose.STAND

	# The crew: the four of them, side by side, facing the camera.
	var crew: Array[Player] = []
	for i in 4:
		var m := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
		m.setup(10 + i, ["Operador", "Sonido", "Reportero", "Becario"][i], Net.COLORS[i], false)
		main.world.add_child(m)
		var at2: Vector3 = ahead.call(2) + Vector3(ld.y, 0, -ld.x) * (i - 1.5) * 0.55
		m.global_position = at2
		m.net_pos = at2
		var cam_at: Vector3 = level.center(start)
		m.look_at(Vector3(cam_at.x, at2.y, cam_at.z), Vector3.UP)
		m.net_yaw = m.rotation.y
		crew.append(m)
	crew[1].voice_level = 1.0
	crew[3].disturbance = 0.9
	await _look_shot(player, level, start, ahead.call(2) + Vector3.UP * 1.25, dir, "41_crew")
	player.global_position = level.center(start) + Vector3(ld.x, 0, ld.y) * 1.0
	await _wait(0.4)
	await _shot(dir, "41b_crew_close")
	player.camcorder.force_held = true
	await _wait(0.5)
	await _shot(dir, "42_crew_camcorder")
	player.camcorder.force_held = false
	for m in crew:
		m.queue_free()

	# The toolbar, the inventory, the hands swapped, reaching for a battery
	# and putting it in, and a battery and a tape on the floor.
	var inv_ui: InventoryUI = null
	for child in main.get_node("UILayer").get_children():
		if child is InventoryUI:
			inv_ui = child
	inv_ui._poke()
	await _room_shot(player, level, "living", dir, "50_toolbar")
	inv_ui._toggle(true)
	await _wait(0.4)
	await _shot(dir, "51_inventory")
	inv_ui._toggle(false)
	player.inventory.swap("left", "right")
	await _wait(0.4)
	await _shot(dir, "52_hands_swapped")
	player.inventory.swap("left", "right")
	await get_tree().process_frame
	player.viewmodel.play_grab("battery")
	await _wait(ViewModel.GRAB_TIME * 0.55)
	await _shot(dir, "53_grab")
	await _wait(ViewModel.GRAB_TIME * 0.45 + ViewModel.INSERT_TIME * 0.35)
	await _shot(dir, "54_battery_insert")
	await _wait(0.6)
	var floor_at: Vector3 = ahead.call(1)
	for k in 2:
		var item := Pickup.create(Pickup.Kind.BATTERY if k == 0 else Pickup.Kind.TAPE)
		level.add_child(item)
		item.global_position = floor_at + Vector3(ld.y, 0, -ld.x) * (k * 0.35 - 0.17)
	player.light_on = true
	await _look_shot(player, level, start, floor_at, dir, "55_pickups")

	# Furniture from the front: the sofa (from the TV), a wardrobe, a counter.
	for ch: String in ["s", "w", "k", "b"]:
		var cells := level.layout.find_all(ch)
		if cells.is_empty():
			continue
		var c: Vector3i = cells[0]
		var facing: Vector2i = -level._against_wall(Rect2i(c.x, c.z, 1, 1), c.y) if ch != "s" else -level._away_from_tv(Rect2i(c.x, c.z, 1, 1))
		var stand := level.nearest_walkable(c + Vector3i(facing.x * 3, 0, facing.y * 3))
		await _look_shot(player, level, stand, level.center(c) + Vector3.UP * 0.6, dir, "56_furniture_" + ch)

	# Doors: a plain one and one with a broken window over it, shut, then open.
	var shown := {}
	for door: Door in level.doors:
		var kind := "transom" if door.transom else "full"
		if shown.has(kind):
			continue
		shown[kind] = true
		door.set_open(false)
		door.amount = 0.0
		door._apply()
		var stand := level.nearest_walkable(door.cell + Vector3i(door.axis.x, 0, door.axis.y) * door.face * 2)
		player.light_on = true
		await _look_shot(player, level, stand, level.center(door.cell) + Vector3.UP * (1.9 if door.transom else 1.1), dir, "57_door_%s" % kind)
		door.set_open(true)
		await _wait(0.8)
		await _shot(dir, "58_door_%s_open" % kind)

	# Your own body, looking down (standing, then walking).
	await _room_shot(player, level, "living", dir, "59a_tmp")
	player.set_view(player.rotation.y, -1.35)
	await _wait(0.5)
	await _shot(dir, "59_own_body")
	player.set_view(player.rotation.y, -0.75)
	await _wait(0.3)
	await _shot(dir, "59b_own_body_ahead")

	# A teamhider hidden under the bed and under a table: you see them there.
	for kind2: int in [HideSpot.Kind.BED, HideSpot.Kind.TABLE]:
		var sp2: HideSpot = null
		for sp in level.hide_spots:
			if sp.kind == kind2:
				sp2 = sp
		if sp2 == null:
			continue
		var hider := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
		hider.setup(20 + kind2, "Escondido", Net.COLORS[1], false)
		main.world.add_child(hider)
		hider.global_position = sp2.inside
		hider.net_pos = sp2.inside
		hider.net_yaw = atan2(-sp2.facing.x, -sp2.facing.z)
		hider.rotation.y = hider.net_yaw
		hider.net_hide = String(sp2.name)
		var from_c := level.nearest_walkable(sp2.access + Vector3i(roundi(sp2.facing.x) * 2, 0, roundi(sp2.facing.z) * 2))
		player.light_on = true
		await _look_shot(player, level, from_c, sp2.inside + Vector3.UP * 0.2, dir, "60_hidden_%s" % ("bed" if kind2 == HideSpot.Kind.BED else "table"))
		hider.queue_free()

	# The last tape: what to do now, then the line that stays.
	run.objective.emit(tr("¡TIENES TODAS LAS CINTAS!"), tr("Sal por la puerta por la que entraste"), tr("▶ Vuelve a la puerta de entrada"))
	await _room_shot(player, level, "hall", dir, "62_objective")
	await _wait(6.2)  # (Hud.OBJECTIVE_TIME)
	await _shot(dir, "62b_objective_reminder")
	main.screens.show_escaped(5, 5, 372.0, 2, "Lucía", PackedStringArray(["Lucía"]), true)
	await _wait(10.0)
	await _shot(dir, "21_win")
	print("PERF fps=%d draw_calls=%d objects=%d vram=%.0fMB" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("SHOTS saved to ", dir)
	get_tree().quit()


## From the walkable cell of the room farthest from its middle, looking at
## the middle: the whole room in frame.
func _room_shot(player: Player, level: Level, type: String, dir: String, shot_name: String, on_floor := -1) -> void:
	for r: Dictionary in level.layout.rooms:
		if r.type != type or (on_floor >= 0 and r.floor != on_floor):
			continue
		var rect: Rect2i = r.rect
		var f: int = r.floor
		var mid := Vector3(rect.position.x + rect.size.x * 0.5, f * Level.FLOOR_H, rect.position.y + rect.size.y * 0.5)
		var best := Vector3i(-1, -1, -1)
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector3i(x, f, z)
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


func _print_map(L: HouseLayout) -> void:
	for f in L.floors:
		print("MAP floor %d (%dx%d)" % [f, L.width, L.depth])
		for z in L.depth:
			var row := ""
			for x in L.width:
				row += L.char_at(Vector3i(x, f, z))
			print("MAP ", row)


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(shot_name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout



## The house itself, to judge its geometry and materials: two windows (from
## across the room and close), a few rooms, and the first window opened.
##   godot --path game -- --shots <dir> --house-only
func house_shots(main: Node, dir: String) -> void:
	var player: Player = main.player
	var level: Level = main.run.level
	var shown := 0
	var windows: Array[Vector3i] = []
	for z in level.depth:
		for x in level.width:
			if level.char_at(Vector3i(x, 0, z)) == "W":
				windows.append(Vector3i(x, 0, z))
	for c: Vector3i in windows:
		if c.y != 0 or shown >= 2:
			continue
		var inward := Vector3i.ZERO
		for d in Level.DIRS:
			if level.is_walkable(c + Vector3i(d.x, 0, d.y)):
				inward = Vector3i(d.x, 0, d.y)
		if inward == Vector3i.ZERO:
			continue
		var far := c + inward
		for k in range(2, 4):
			if level.is_walkable(c + inward * k):
				far = c + inward * k
		var at := level.center(c) - Vector3(inward) * 0.5 + Vector3.UP * 1.35
		await _look_shot(player, level, far, at, dir, "h%d_window_far" % shown)
		await _look_shot(player, level, c + inward, at + Vector3.UP * 0.1, dir, "h%d_window_close" % shown)
		if shown == 0 and level.has_method("window_at") and level.call("window_at", c) != null:
			var w: Node = level.call("window_at", c)
			w.call("set_open", true)
			await _wait(1.6)
			await _shot(dir, "h%d_window_open" % shown)
			await _look_shot(player, level, far, at, dir, "h%d_window_open_far" % shown)
			w.call("set_open", false)
		shown += 1
	for t: String in ["hall", "living", "kitchen", "bedroom", "bathroom"]:
		await _room_shot(player, level, t, dir, "r_" + t)
	print("HOUSE shots done")


## The Visita's soot (EntitySoot): its trail seen with the naked eye, the
## aura through the camcorder (walking, held still while filmed, close),
## the handprints on all fours, the scorch the flash leaves, the ceiling.
##   godot --path game -- --shots <dir> --soot-only
func soot_shots(main: Node, dir: String) -> void:
	var player: Player = main.player
	var entity: Entity = main.entity
	var run: Run = main.run
	var level: Level = run.level
	entity.state = Entity.State.STALKING
	var line := level.find_line(8)
	var start: Vector3i = line[0]
	var ld: Vector2i = line[1]
	var ahead := func(n: float) -> Vector3: return level.center(start) + Vector3(ld.x, 0, ld.y) * n
	player.global_position = level.center(start)
	# It walks away from you down the corridor, then waits at the end.
	entity.mode = Entity.Mode.WANDER
	entity.pose = Entity.Pose.STAND
	for i in 150:
		entity.global_position = ahead.call(1.2).lerp(ahead.call(6.5), i / 150.0)
		await get_tree().process_frame
	await _wait(Tuning.SOOT_SETTLE + 1.0)
	await _look_shot(player, level, start, ahead.call(2.6), dir, "soot_01_trail_naked")
	player.camcorder.force_held = true
	await _wait(1.2)
	await _shot(dir, "soot_02_trail_camcorder")
	await _clean_shot(main, dir, "soot_02_trail_camcorder_clean")
	# Close, filmed: frozen, its smoke hanging round it.
	entity.global_position = ahead.call(3.6)
	await _look_shot(player, level, start, ahead.call(3.6) + Vector3.UP * 1.1, dir, "soot_03_aura_close")
	await _clean_shot(main, dir, "soot_03_aura_close_clean")
	entity.state = Entity.State.FROZEN
	await _wait(1.5)
	await _shot(dir, "soot_04_aura_frozen")
	# What the aura costs (filmed, close): draw calls with it and without.
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	entity._soot._smoke.visible = false
	entity._soot._flakes.visible = false
	await _wait(0.3)
	print("SOOT draws with=%d without=%d fps=%d" % [draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second()])
	entity._soot._smoke.visible = true
	entity._soot._flakes.visible = true
	await _clean_shot(main, dir, "soot_04_aura_frozen_clean")
	entity.state = Entity.State.STALKING
	entity.enraged = true
	await _wait(1.5)
	await _shot(dir, "soot_05_aura_enraged")
	await _clean_shot(main, dir, "soot_05_aura_enraged_clean")
	entity.enraged = false
	# On all fours, running from you: handprints.
	entity.mode = Entity.Mode.FLEE
	for i in 90:
		entity.global_position = ahead.call(3.6).lerp(ahead.call(7.5), i / 90.0)
		await get_tree().process_frame
	entity.mode = Entity.Mode.WANDER
	player.camcorder.force_held = false
	await _wait(Tuning.SOOT_SETTLE + 0.8)
	await _look_shot(player, level, start, ahead.call(3.6), dir, "soot_06_hands_naked")
	# The flash: it comes apart and leaves a burnt splash.
	entity.global_position = ahead.call(3.0)
	player.camcorder.force_held = true
	await _wait(0.8)
	run._on_flash()
	await _wait(1.6)
	await _shot(dir, "soot_07_scorch_camcorder")
	await _clean_shot(main, dir, "soot_07_scorch_camcorder_clean")
	player.camcorder.force_held = false
	await _wait(0.6)
	await _shot(dir, "soot_08_scorch_naked")
	entity.vanishing = false
	entity.gone = false
	# On the ceiling: its shadow spread up there round it.
	entity.on_ceiling = true
	entity.global_position = ahead.call(3.0)
	player.camcorder.force_held = true
	await _look_shot(player, level, start, ahead.call(3.0) + Vector3.UP * 2.3, dir, "soot_09_ceiling")
	await _clean_shot(main, dir, "soot_09_ceiling_clean")
	entity.on_ceiling = false
	player.camcorder.force_held = false
	print("SOOT shots done")


## The same picture without the tape (no post-process): to judge the effect itself.
func _clean_shot(main: Node, dir: String, shot_name: String) -> void:
	var post := main.get_node("WorldView/World/PostLayer/PostFX") as CanvasItem
	post.visible = false
	await get_tree().process_frame
	await _shot(dir, shot_name)
	post.visible = true
