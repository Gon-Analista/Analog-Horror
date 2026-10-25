class_name SmokeTest
extends Node
## Dev: checks the core rules without playing and prints one line per
## check ("SMOKE ok ..." / "SMOKE FAIL ..."), then quits:
##   godot --headless --path game -- --smoke
## 0. Input reaches the 3D world.  1. Filming the entity freezes it.  2. Unfilmed, it reaches the player.
## 3. Picking up the quota opens the exit.

var _fails := 0


func run_smoke(main: Node) -> void:
	var player: Player = main.player
	var entity: Entity = main.entity
	var run: Run = main.run
	await get_tree().physics_frame

	# 0. Input reaches the player inside the 3D SubViewport.
	var lit := player.flashlight.visible
	var ev := InputEventAction.new()
	ev.action = "flashlight"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("input reaches the 3D world", player.flashlight.visible != lit, "flashlight did not toggle")
	player.flashlight.visible = lit

	# Reading the broadcast wakes it; E again closes the broadcast.
	var screen: ReadableScreen = null
	for child in run.tv.get_children():
		if child is ReadableScreen:
			screen = child
	_check("entity sleeps until the broadcast is read", entity.state == Entity.State.DORMANT, Entity.State.keys()[entity.state])
	player.global_position = run.tv.global_position + run.tv.global_transform.basis.z * -1.2
	run._on_interact(screen)
	_check("the TV starts on the show", run.tv.state == TvBroadcast.State.SHOW and entity.state == Entity.State.DORMANT, "")
	await _wait(Tuning.TV_DISTURB_AT + 1.0)
	_check("the show starts going wrong", run.tv.disturbance() > 0.0 and run.tv.state == TvBroadcast.State.SHOW, "disturbance %.2f" % run.tv.disturbance())
	await _wait(Tuning.TV_DISTURB_TIME + TvBroadcast.INTERRUPT_TIME)
	_check("then the alert cuts in, and it waits while you read",
			run.tv.is_showing_text() and entity.state == Entity.State.DORMANT,
			"tv=%s entity=%s" % [TvBroadcast.State.keys()[run.tv.state], Entity.State.keys()[entity.state]])
	run._on_interact(null)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("closing the alert wakes it", not run.reading and entity.state != Entity.State.DORMANT, "")

	# 1. Freeze: entity 4 m ahead in the hallway, camcorder up.
	player.global_position = Vector3(6.5, 0, 11.5)
	player.set_view(-PI / 2)
	entity.global_position = Vector3(10.5, 0, 11.5)
	entity.wake()
	player.camcorder.force_held = true
	await _wait(0.5)
	var before := entity.global_position
	await _wait(2.0)
	_check("filmed entity stays still", entity.global_position.distance_to(before) < 0.01, "moved %.2f m" % entity.global_position.distance_to(before))

	# 2. Chase: camcorder down; from its bedroom it must path through the
	# house and catch the player at the front door.
	player.camcorder.force_held = false
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
	print("SMOKE done, %d failed" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool, detail: String) -> void:
	if ok:
		print("SMOKE ok   ", what)
	else:
		_fails += 1
		print("SMOKE FAIL ", what, " (", detail, ")")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
