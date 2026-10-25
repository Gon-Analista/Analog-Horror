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
	if multiplayer.is_server():
		run._wake_entity.rpc()  # the tapes appear with it
	await _wait(1.0)
	if multiplayer.is_server():
		me.global_position = Vector3(8.5, 0, 11.5)
	else:
		run._request_pickup.rpc_id(1, "Tape0")
	await _wait(3.0)
	var other: Player = null
	for p: Player in run.players.values():
		if p != me:
			other = p
	print("NETTEST role=%s players=%d tapes=%d other_at=%s entity_at=%s" % [
		Net.test_role, run.players.size(), run.tapes_got,
		str(other.global_position.snapped(Vector3.ONE * 0.1)) if other else "none",
		str(main.entity.global_position.snapped(Vector3.ONE * 0.1))])
	await _wait(1.5)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
