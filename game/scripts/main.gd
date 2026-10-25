extends Node
## The house for one night: builds it, puts every player of the session in
## it (Net.players: one in solo), wires the systems and starts the run.
## The 3D world lives in a 480x270 SubViewport scaled up with nearest
## filtering (the pixel art); the UI is drawn on top at the window's real
## resolution so text stays sharp.
## Dev flags (after "--"), when this scene is started directly:
##   --seed N        fixed run (tape placement)
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
	Net.ensure_solo_players()
	level.build(PackedStringArray(HouseMap.ROWS))
	var tv := TvBroadcast.new()
	tv.name = "TV"  # same path on every machine: its state is replicated
	level.add_child(tv)
	tv.place(level)
	var players := _spawn_players()
	run.setup(level, players, player, entity, tv, screens)
	$WorldView/World/PostLayer/PostFX.setup(player, entity, run)
	$UILayer/Viewfinder.setup(player, run)
	$UILayer/Hud.setup(player, run)
	$UILayer/Debug.setup(player, entity)
	var ambience := AudioStreamPlayer.new()
	ambience.stream = Sfx.get_stream("house_ambience", true)
	ambience.volume_db = -10.0
	add_child(ambience)
	ambience.play()

	var args := OS.get_cmdline_user_args()
	var run_seed := Net.run_seed
	var i := args.find("--seed")
	if i >= 0 and i + 1 < args.size():
		run_seed = int(args[i + 1])
	var shots := args.find("--shots")
	if args.has("--smoke"):
		run.start(run_seed if i >= 0 else 1, true)
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.run_smoke(self)
	elif shots >= 0 and shots + 1 < args.size():
		run.start(run_seed if i >= 0 else 1, true)
		var tour := ShotTour.new()
		add_child(tour)
		tour.run_tour(self, args[shots + 1])
	else:
		run.start(run_seed, Net.test_role != "")
		if Net.test_role != "":
			var test := NetTest.new()
			add_child(test)
			test.run_test(self)


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
	return out
