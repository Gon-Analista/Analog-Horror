extends Node
## The house for one night: builds it, puts every player of the session in
## it (Net.players: one in solo), wires the systems and starts the run.
## The 3D world lives in a SubViewport of 960x540 (480x270 with the "low"
## graphics option) scaled up to the window (the pixel art); the UI is
## drawn on top at the window's real resolution so text stays sharp.
## Dev flags (after "--"), when this scene is started directly:
##   --seed N        fixed run (house and tape placement)
##   --tapes N       tapes to recover (5-12, the house grows with it)
##   --shots <dir>   fixed camera tour that saves screenshots and quits
##   --smoke         checks the core rules headless and quits

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var world: SubViewport = $WorldView/World
@onready var level: Level = $WorldView/World/Level
@onready var entity: Entity = $WorldView/World/Entity
@onready var run: Run = $Run
@onready var screens: Screens = $UILayer/Screens
## The local player.
var player: Player


func _ready() -> void:
	Controls.setup()
	_set_render_scale(Settings.render_scale())
	Net.ensure_solo_players()
	var args := OS.get_cmdline_user_args()
	var style := args.find("--entity-style")  # dev: 0 the new drawing, 1 the classic one, 2 the 3D one (the game's)
	if style >= 0 and style + 1 < args.size():
		Net.entity_style = int(args[style + 1])
	var bots := args.find("--bots")  # dev: crew bots in this run (and --versus-me: you are the entity)
	if bots >= 0 and bots + 1 < args.size():
		Net.bot_count = int(args[bots + 1])
		if args.has("--versus-me"):
			Net.game_mode = Net.GameMode.VERSUS
			Net.entity_peer = 1
	var run_seed := Net.run_seed
	var i := args.find("--seed")
	if i >= 0 and i + 1 < args.size():
		run_seed = int(args[i + 1])
	var t := args.find("--tapes")
	if t >= 0 and t + 1 < args.size():
		Net.tape_count = int(args[t + 1])
	Net.tape_count = clampi(Net.tape_count, HouseGenerator.MIN_TAPES, HouseGenerator.MAX_TAPES)
	if i < 0 and (args.has("--smoke") or args.has("--shots")):
		run_seed = 1
	# The house: generated from the run's seed, sized for the tapes.
	level.build(HouseGenerator.generate(run_seed, Net.tape_count), run_seed)
	var tv := TvBroadcast.new()
	tv.name = "TV"  # same path on every machine: its state is replicated
	level.add_child(tv)
	tv.place(level)
	var players := _spawn_players()
	if player == null:
		# (Should not happen: Net waits for our place in the roster.)
		Net.log_line("no body for my id %d in %s" % [multiplayer.get_unique_id(), Net.players.keys()])
		Net.end_session.call_deferred(tr("No se pudo entrar en la partida"))
		return
	tv.viewer = player
	run.setup(level, players, player, entity, tv, screens)
	if multiplayer.is_server():
		for p: Player in players.values():
			if p.is_bot:
				var brain := CrewBot.new()
				brain.name = "CrewBot"
				brain.body = p
				brain.run = run
				brain.level = level
				p.add_child(brain)
	$WorldView/World/PostLayer/PostFX.setup(player, entity, run)
	$UILayer/Viewfinder.setup(player, run)
	$UILayer/Hud.setup(player, run)
	var inventory := InventoryUI.new()
	$UILayer.add_child(inventory)
	inventory.setup(player, run)
	$UILayer/Debug.setup(player, entity)
	var pause := PauseMenu.new()
	$UILayer.add_child(pause)
	pause.setup(run)
	if OS.is_debug_build() or args.has("--dev"):  # (Alt+F1: not in the released game unless asked for)
		var monitor := EntityMonitor.new()
		$UILayer.add_child(monitor)
		monitor.setup(player, entity)
	var voice := VoiceChat.new()
	voice.name = "VoiceChat"  # same path on every machine (it receives RPCs)
	voice.process_mode = Node.PROCESS_MODE_ALWAYS  # you can talk while paused
	add_child(voice)
	voice.test_tone = Net.test_role == "client"
	voice.setup(run)
	entity.voices = voice
	$UILayer/Hud.voice = voice
	var ambience := AudioStreamPlayer.new()
	ambience.stream = Sfx.get_stream("house_ambience", true)
	ambience.volume_db = -20.0  # the air of the house: there, but under everything
	ambience.bus = "Effects"
	add_child(ambience)
	ambience.play()
	# Watching the TV, only the TV: the air of the house goes quiet.
	run.read.connect(func(open: bool) -> void:
		create_tween().tween_property(ambience, "volume_db", -60.0 if open else -20.0, 0.6))

	run.tapes_needed = Net.tape_count
	var shots := args.find("--shots")
	if args.has("--smoke"):
		run.start(run_seed, true)
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.run_smoke(self)
	elif args.has("--bot-test"):
		run.start(run_seed, true)
		var bt := BotTest.new()
		add_child(bt)
		bt.run_test(self)
	elif args.has("--model-shots"):
		run.start(run_seed, true)
		var ms := ModelShots.new()
		add_child(ms)
		ms.run_shots(self, args[args.find("--model-shots") + 1])
	elif shots >= 0 and shots + 1 < args.size():
		run.start(run_seed, true)
		var tour := ShotTour.new()
		add_child(tour)
		tour.run_tour(self, args[shots + 1])
	else:
		var intro_shot := args.find("--intro-shot")  # dev: a screenshot of the intro
		if intro_shot >= 0 and intro_shot + 1 < args.size():
			var path: String = args[intro_shot + 1]
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path)
				get_tree().quit())
		run.start(run_seed, Net.test_role != "")
		if Net.test_role != "":
			var test := NetTest.new()
			add_child(test)
			test.run_test(self)
	# The best moments at the end (Run made the recorder when it started).
	var replay_ui := ReplayUI.new()
	$UILayer.add_child(replay_ui)
	replay_ui.setup(run, [$UILayer/Hud, $UILayer/Viewfinder])


## The world's resolution: 480x270 times `q`. The UI is laid out at
## 480x270, so the view is that many times bigger and drawn at 1/q.
func _set_render_scale(q: int) -> void:
	var view := $WorldView as SubViewportContainer
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(480, 270) * q
	view.scale = Vector2.ONE / q
	# (The container stretches the world to its own size: 480x270 times q.)
	# High: smoothed edges and soft shadow edges as well (cheap at this size).
	world.msaa_3d = Viewport.MSAA_2X if q > 1 else Viewport.MSAA_DISABLED
	var soft := RenderingServer.SHADOW_QUALITY_SOFT_LOW if q > 1 else RenderingServer.SHADOW_QUALITY_HARD
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	_update_filter()
	get_viewport().size_changed.connect(_update_filter)


## Sharp pixels when the window is a whole multiple of the world's
## resolution; smooth when it is not (uneven pixels shimmer as you turn).
func _update_filter() -> void:
	var ratio := float(get_viewport().get_visible_rect().size.y) * get_viewport().get_final_transform().get_scale().y / float(world.size.y)
	var whole := absf(ratio - roundf(ratio)) < 0.05
	$WorldView.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if whole else CanvasItem.TEXTURE_FILTER_LINEAR


## One body per player of the session, with the same names on every
## machine (P<peer id>) so their synchronizers find each other. Each one is
## the authority of its own body.
func _spawn_players() -> Dictionary:
	var out := {}
	var ids := Net.players.keys()
	ids.sort()
	for id: int in ids:
		var p := PLAYER_SCENE.instantiate() as Player
		var local := id == multiplayer.get_unique_id()
		p.setup(id, Net.name_of(id), Net.color_of(id), local)
		world.add_child(p)
		p.set_multiplayer_authority(id)
		out[id] = p
		if local:
			player = p
	# Crew members played by the house (the lobby's BOTS): the same bodies
	# on every machine (P900...), the host drives them.
	var slots := ids.size()
	for i in Net.bot_count:
		var id := 900 + i
		var b := PLAYER_SCENE.instantiate() as Player
		b.setup(id, tr("Bot %d") % (i + 1), Net.COLORS[(slots + i) % Net.COLORS.size()], false)
		b.is_bot = true
		world.add_child(b)
		b.set_multiplayer_authority(1)
		out[id] = b
	return out
