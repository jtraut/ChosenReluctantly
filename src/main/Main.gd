extends Node3D
class_name Main
## Wires the arena's player and camera rig together on scene load, and owns
## the death beat and restart for this arena.

## Emitted once, after the death beat (slow-mo) finishes. The Game Over screen
## listens for this (it is a child of Main and binds to its parent).
signal game_over_ready()
## Emitted once from _ready when the starting deck breaks a minimum; the run does not start.
signal run_start_blocked(message: String)

## True in scenes/main/RunMain.tscn (a normal launch): the player fights through a seeded run of rooms.
## Main.tscn leaves it false: the endless arena that tests, scenarios, wave_sim and the soak use.
@export var run_mode: bool = false

var _game_over_announced: bool = false
var _restarting: bool = false
## Real seconds left of the death beat before Game Over (< 0 = no beat running), and the wall-clock time of
## the last count. Counted from the wall clock, not from Godot's timers or the frame delta: both are
## rescaled by the time scale, and the frame the slow-mo starts in gets the wrong scale (C1-t).
var _beat_left: float = -1.0
var _beat_last_usec: int = 0
## A frame longer than this counts as this long (a debugger stop must not eat the beat).
const MAX_BEAT_STEP := 0.5

@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var hud: Hud = $Hud
@onready var debug_overlay: DebugOverlay = $DebugOverlay


## The RunController when this scene is playing a run, else null (the endless arena).
var run_controller: RunController = null

## True when the starting deck broke a unique-card minimum and the run was refused (see _check_starting_deck).
var run_blocked: bool = false


func _enter_tree() -> void:
	WorldRef.register(self)


func _exit_tree() -> void:
	WorldRef.unregister(self)
	if GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.disconnect(_on_pause_changed)


func _ready() -> void:
	set_process(false)
	camera_rig.target = player
	camera_rig.global_position = player.global_position
	player.camera = camera_rig.camera
	enemy_spawner.target = player
	player.player_died.connect(_on_player_died)
	hud.set_player(player)
	debug_overlay.player = player
	AimIndicator.attach(self, player)
	PlayerOcclusionCue.attach(player)
	PlayerCues.attach(player)
	_setup_run_mode()
	_check_starting_deck()
	var problems := SceneSelfCheck.find_problems(self)
	if not problems.is_empty():
		push_error("Main scene self-check FAILED (world may render empty): " + "; ".join(problems))
	_setup_debug_capture()


## A scenario capture keeps the endless arena even on a normal launch (their seeded baselines and scripted
## setups assume it). `args` are the user args after `--`. Pure, so a test can check every combination.
static func uses_run_mode(run_mode_flag: bool, args: PackedStringArray) -> bool:
	if not run_mode_flag:
		return false
	return String(CaptureArgs.parse(args)["scenario"]) == ""


## Run mode: hand this scene to its RunController. Otherwise (endless arena) the run nodes are removed so
## nothing of the run system is on screen or ticking.
func _setup_run_mode() -> void:
	var controller := get_node_or_null("RunController") as RunController
	if uses_run_mode(run_mode, OS.get_cmdline_user_args()) and controller != null:
		if RunConfig.is_valid():
			run_controller = controller
			controller.begin(self)
			return
		push_error("Run mode needs a valid data/run.json; falling back to the endless arena. " + "; ".join(RunConfig.load_problems()))
	for run_node_name: String in ["RunController", "RunHud", "RoomClearedScreen", "WinScreen"]:
		var run_node := get_node_or_null(run_node_name)
		if run_node != null:
			remove_child(run_node)
			run_node.queue_free()


## Run-start deck validation (GDD section 4 unique minimums). A deck that breaks a minimum cannot start a
## run: push_error with every shortfall, switch the spawner off (no waves, no run) and emit run_start_blocked.
## The shipped content passes (DeckRules.validate_shipped_content, tested), so this only fires on bad data.
func _check_starting_deck() -> void:
	var problems := DeckRules.validate_config(DeckRules.shipped_config(), SlotTypeDatabase.known_ids())
	if not problems.is_empty():
		push_error("deck_rules.json is invalid: " + "; ".join(problems))
	var message := DeckRules.run_start_block_message(player.card_slots.deck_check())
	if message == "":
		return
	push_error(message)
	run_blocked = true
	enemy_spawner.process_mode = Node.PROCESS_MODE_DISABLED
	run_start_blocked.emit(message)


func is_game_over() -> bool:
	return _game_over_announced


func _on_player_died() -> void:
	var beat := UiConfig.death_beat()
	var duration: float = beat["slow_mo_duration"]
	Juice.slow_mo(duration, beat["slow_mo_scale"])
	Juice.screen_shake(0.35, 0.3)
	# Real time, so slow-mo doesn't stretch it (see _process). _process stops while the tree is paused,
	# so a pause during the beat holds it (Juice remembers the slow-mo left) and Game Over never
	# appears over a pause screen; the count restarts from the resume (GamePause.paused_changed).
	_beat_left = duration
	_beat_last_usec = Time.get_ticks_usec()
	if not GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.connect(_on_pause_changed)
	set_process(true)


func _process(_delta: float) -> void:
	if _beat_left < 0.0:
		set_process(false)
		return
	var now: int = Time.get_ticks_usec()
	_beat_left -= minf(float(now - _beat_last_usec) / 1000000.0, MAX_BEAT_STEP)
	_beat_last_usec = now
	if _beat_left <= 0.0:
		_beat_left = -1.0
		set_process(false)
		_announce_game_over()


## Time spent paused does not count towards the beat.
func _on_pause_changed(_is_paused: bool) -> void:
	_beat_last_usec = Time.get_ticks_usec()


func _announce_game_over() -> void:
	if _game_over_announced or _restarting:
		return
	_game_over_announced = true
	game_over_ready.emit()


## Public restart entry point for the Game Over screen's "Try again" (and the win screen's "New run").
## In a run this starts a brand-new run with a new seed (nothing carries over); in the endless arena it
## restarts the arena. Either way the scene is replaced by a fresh one (see swap_to_fresh_scene).
func restart_arena() -> void:
	if _restarting:
		return
	if run_controller != null:
		RunSession.begin_new_run()
	swap_to_fresh_scene()


## Replaces this scene with a fresh copy of itself, in the same place in the tree. A fresh scene resets
## everything in one move (HP, decks, cooldowns, shuffle bags, enemies, waves, statuses, timers); the
## RunState (a static, see RunSession) is what carries over. Does not rely on `current_scene`, so it also works
## inside tools/VpCapture.tscn (qa N5). Deferred, because it is usually called from a button's signal.
func swap_to_fresh_scene() -> void:
	if _restarting:
		return
	_restarting = true
	_prepare_for_restart()
	_replace_self.call_deferred()


func _replace_self() -> void:
	var parent: Node = get_parent()
	var tree: SceneTree = get_tree()
	if parent == null or tree == null or scene_file_path == "":
		if tree != null:
			tree.reload_current_scene()
		return
	var packed := load(scene_file_path) as PackedScene
	var fresh: Node = packed.instantiate()
	var was_current: bool = tree.current_scene == self
	parent.remove_child(self)
	queue_free()
	parent.add_child(fresh)
	if was_current:
		tree.current_scene = fresh


## Engine.time_scale and Juice state are global and survive a reload.
func _prepare_for_restart() -> void:
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


## Screenshot/scenario tooling (see README). Costs one args lookup in normal play.
func _setup_debug_capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	var config := CaptureArgs.parse(args)
	var error: String = config["error"]
	if error != "":
		push_error("Capture args: " + error)
		get_tree().quit(1)
		return
	var scenario_id: String = config["scenario"]
	if scenario_id != "" and Scenario.setup(self, scenario_id) == null:
		get_tree().quit(1)
		return
	var times: Array[float] = config["times"]
	if not times.is_empty():
		var capture := ScreenshotCapture.new()
		capture.name = "ScreenshotCapture"
		capture.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps timing shots while the settings screen pauses the tree
		capture.times = times
		capture.out = config["out"]
		add_child(capture)
