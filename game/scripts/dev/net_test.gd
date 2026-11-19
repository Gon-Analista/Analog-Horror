class_name NetTest
extends Node
## Dev: two windows on one PC check the online plumbing over LAN and print
## one "NETTEST" line each, then quit:
##   godot --path game -- --net-test host
##   godot --path game -- --net-test client
## The host walks to a spot (the client must see it there); the client
## asks for a tape (both must count it); both report where the entity is.


func run_test(main: Node) -> void:
	var run: Run = main.run
	var me: Player = main.player
	await _wait(1.0)
	if run.entity_peer != 0:
		await _versus(main, run, me)
		return
	if multiplayer.is_server():
		run._wake_entity.rpc()  # the tapes appear with it
	await _wait(1.0)
	var cameras_at_start := "%s" % me.has_camera
	if multiplayer.is_server():
		me.global_position = run.level.center(run.level.spots_of("P")[0])
		run._request_drop.rpc_id(1, 77.0)  # pass the camcorder
	else:
		run._request_pickup.rpc_id(1, "Tape0")
	await _wait(1.0)
	if not multiplayer.is_server():
		run._request_pickup.rpc_id(1, "Camcorder1")
	await _wait(2.0)
	if not multiplayer.is_server() and not run.level.hide_spots.is_empty():
		me.hide_in(run.level.hide_spots[0])  # the host must see where
	await _wait(1.0)
	# The best moments: the host marks one, picks it and starts it; both play it.
	if multiplayer.is_server():
		run._moment("flash", me)
		await _wait(0.5)
		run._set_clips.rpc(run.replay.pick())
		run._play_replay.rpc(0)
	await _wait(1.0 if multiplayer.is_server() else 1.5)
	var replay_state := "moments=%d clips=%d playing=%s" % [run.replay.moments.size(), run.replay.clips.size(), run.replay.playing]
	await _wait(1.0)  # (the guest looks before the host stops it)
	if multiplayer.is_server():
		run._stop_replay.rpc()
	await _wait(0.3)
	var other: Player = null
	for p: Player in run.players.values():
		if p != me:
			other = p
	print("NETTEST role=%s players=%d tapes=%d camera_start=%s camera_now=%s battery=%d voice_frames=%d other_at=%s entity_at=%s hidden=%s replay[%s]" % [
		Net.test_role, run.players.size(), run.tapes_got, cameras_at_start, me.has_camera, int(me.camcorder.battery),
		main.get_node("VoiceChat").frames_received,
		str(other.global_position.snapped(Vector3.ONE * 0.1)) if other else "none",
		str(main.entity.global_position.snapped(Vector3.ONE * 0.1)),
		other.net_hide if other else "none", replay_state])
	# The client leaves first: the host going away would send it to the menu.
	await _wait(1.0 if not multiplayer.is_server() else 2.5)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## "--net-versus": the guest plays the entity; it walks up to the host and
## grabs them (the host must die, on both machines).
func _versus(main: Node, run: Run, me: Player) -> void:
	if multiplayer.is_server():
		run._wake_entity.rpc()
		me.global_position = run.level.center(run.level.spots_of("P")[0])
	await _wait(2.0)
	var host: Player = run.players.get(1)
	if run.pilot:
		var c := run.level.cell_of(host.global_position)
		for d in Level.DIRS:
			var n := c + Vector3i(d.x, 0, d.y)
			if run.level.is_walkable(n):
				run.pilot.place(run.level.center(n))
				var to := host.global_position - run.level.center(n)
				run.pilot.yaw = atan2(-to.x, -to.z)
				break
		await _wait(0.6)
		run.pilot._attack()
	await _wait(2.5)
	print("NETTEST role=%s versus entity_peer=%d pilot_here=%s host_alive=%s entity_state=%d phase=%d" % [
		Net.test_role, run.entity_peer, run.pilot != null, host.alive if host else false, main.entity.state, run.phase])
	await _wait(1.0 if not multiplayer.is_server() else 2.5)
	get_tree().quit()
