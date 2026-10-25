class_name ShotTour
extends Node
## Dev: a fixed camera tour that saves screenshots (window resolution, UI
## included) and quits, to review the look without playing:
##   godot --path game -- --shots <absolute dir>


func run_tour(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var player: Player = main.player
	var entity: Entity = main.entity
	var run: Run = main.run
	entity.set_physics_process(false)
	await _wait(1.5)

	await _pose_shot(player, Vector2(15.5, 11.5), PI / 2, 0.0, dir, "01_hallway")
	await _pose_shot(player, Vector2(12.6, 2.6), PI * 0.88, -0.22, dir, "02_living")
	# Watching the show, then the alert cutting in.
	var tv := run.tv
	var front := tv.global_position - tv.global_transform.basis.z * 1.3
	player.global_position = Vector3(front.x, 0, front.z)
	player.set_view(tv.global_rotation.y + PI, -0.2)
	for child in tv.get_children():
		if child is ReadableScreen:
			run._on_interact(child)
	await _wait(1.0)
	await _shot(dir, "03_tv_show")
	await _wait(Tuning.TV_DISTURB_AT + Tuning.TV_DISTURB_TIME * 0.65 - 1.0)
	await _shot(dir, "03b_tv_going_wrong")
	await _wait(Tuning.TV_DISTURB_TIME * 0.35 + TvBroadcast.INTERRUPT_TIME + 0.5)
	await _shot(dir, "04_tv_alert")
	run._on_interact(null)
	entity.state = Entity.State.STALKING  # woken by the alert; keep it still for the tour
	await _pose_shot(player, Vector2(3.5, 2.2), PI * 0.85, -0.2, dir, "05_kitchen")
	await _pose_shot(player, Vector2(5.0, 8.4), PI * 0.62, 0.0, dir, "06_kid_room")
	await _pose_shot(player, Vector2(19.2, 3.2), PI * 0.4, -0.1, dir, "07_bedroom")

	# The entity 4 m ahead in the hallway: naked eye, then through the camcorder.
	entity.global_position = Vector3(10.5, 0, 11.5)
	await _pose_shot(player, Vector2(6.5, 11.5), -PI / 2, 0.05, dir, "08_naked_eye")
	player.camcorder.force_held = true
	await _wait(0.8)
	await _shot(dir, "09_camcorder")
	entity.global_position = Vector3(8.0, 0, 11.5)
	await _wait(0.4)
	await _shot(dir, "10_camcorder_close")
	player.camcorder.force_held = false

	# First-person hands, the camcorder going up, and a teammate.
	entity.global_position = Vector3(20.5, 0, 2.5)
	await _pose_shot(player, Vector2(4.5, 11.5), -PI / 2, -0.05, dir, "11_hands")
	player.camcorder.force_held = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(dir, "12_raising")
	player.camcorder.force_held = false
	await _wait(0.5)
	var mate := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	mate.setup(2, "Lucía", Net.COLORS[1], false)
	main.world.add_child(mate)
	mate.global_position = Vector3(7.0, 0, 11.6)
	mate.net_pos = mate.global_position
	mate.net_yaw = PI / 2 + 0.3
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
	await _pose_shot(player, Vector2(9.5, 11.6), PI, 0.05, dir, "15_exit")
	player._set_crouch(true)
	player.crouching = true
	await _pose_shot(player, Vector2(3.5, 11.4), 0.0, 0.15, dir, "16_boards_crouched")
	print("PERF fps=%d draw_calls=%d objects=%d vram=%.0fMB" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("SHOTS saved to ", dir)
	get_tree().quit()


func _pose_shot(player: Player, at: Vector2, yaw: float, pitch: float, dir: String, shot_name: String) -> void:
	player.global_position = Vector3(at.x, 0.0, at.y)
	player.set_view(yaw, pitch)
	await _wait(0.7)
	await _shot(dir, shot_name)


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(shot_name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
