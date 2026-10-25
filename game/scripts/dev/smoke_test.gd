class_name SmokeTest
extends Node
## Dev: checks the core rules without playing and prints one line per
## check ("SMOKE ok ..." / "SMOKE FAIL ..."), then quits:
##   godot --headless --path game -- --smoke
## 1. Filming the entity freezes it.  2. Unfilmed, it reaches the player.
## 3. Picking up the quota opens the exit.

var _fails := 0


func run_smoke(main: Node) -> void:
	var player: Player = main.player
	var entity: Entity = main.entity
	var run: Run = main.run
	await get_tree().physics_frame

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
