class_name BotTest
extends Node
## Dev: a night with crew bots and nobody else (you as the entity with
## --versus-me), fast-forwarded a little: prints what the bots did, quits.
##   godot --path game res://scenes/main.tscn -- --bots 3 [--versus-me] --bot-test


func run_test(main: Node) -> void:
	var run: Run = main.run
	await get_tree().create_timer(0.5).timeout
	run._wake_entity.rpc()
	var start := {}
	for p: Player in run.players.values():
		if p.is_bot:
			start[p] = p.net_pos
	var t := 0.0
	var hid := false
	while t < 45.0 and run.phase == Run.Phase.PLAYING:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		for p: Player in start:
			hid = hid or p.is_hidden()
	var moved := 0.0
	var alive := 0
	for p: Player in start:
		moved += p.net_pos.distance_to(start[p])
		alive += 1 if p.alive else 0
	print("BOTTEST bots=%d alive=%d moved=%.1f tapes=%d/%d hid=%s phase=%s pilot=%s t=%.0f" % [start.size(), alive, moved, run.tapes_got, run.tapes_needed,
			hid, Run.Phase.keys()[run.phase], run.pilot != null, t])
	get_tree().quit()
