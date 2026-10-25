extends Node3D
## Prototype entry: builds the house, wires the systems and starts a run.
## Dev flags (after "--"):
##   --seed N        fixed run (tape placement)
##   --shots <dir>   fixed camera tour that saves screenshots and quits
##   --smoke         checks the core rules headless and quits

@onready var level: Level = $Level
@onready var player: Player = $Player
@onready var entity: Entity = $Entity
@onready var run: Run = $Run
@onready var screens: Screens = $UILayer/Screens


func _ready() -> void:
	Controls.setup()
	level.build(PackedStringArray(HouseMap.ROWS))
	var tv := TvBroadcast.new()
	level.add_child(tv)
	tv.place(level)
	run.setup(level, player, entity, tv, screens)
	$PostLayer/PostFX.setup(player, entity, run)
	$UILayer/Viewfinder.setup(player, run)
	$UILayer/Hud.setup(player, run)
	$UILayer/Debug.setup(player, entity)

	var args := OS.get_cmdline_user_args()
	var run_seed := randi()
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
		run.start(run_seed)
