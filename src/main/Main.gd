extends Node3D
class_name Main
## Wires the arena's player and camera rig together on scene load, and owns
## the death beat and restart for this arena.

## Emitted once, after the death beat (slow-mo) finishes. The Game Over screen
## listens for this (find Main via the scene root: `get_tree().current_scene`).
signal game_over_ready()

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


static var _deck_warned: bool = false


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
	_check_starting_deck()
	var problems := SceneSelfCheck.find_problems(self)
	if not problems.is_empty():
		push_error("Main scene self-check FAILED (world may render empty): " + "; ".join(problems))
	_setup_debug_capture()


## Run-start deck validation (GDD section 4 unique minimums). Warns, not blocks, until the
## C1-c cards exist: the preset deck is short on some slots today. See DECISIONS.
func _check_starting_deck() -> void:
	var problems := DeckRules.validate_config(DeckRules.shipped_config(), SlotTypeDatabase.known_ids())
	if not problems.is_empty():
		push_error("deck_rules.json is invalid: " + "; ".join(problems))
	if _deck_warned:
		return
	_deck_warned = true  # once per process; scene reloads would repeat the same lines
	for problem: String in player.card_slots.deck_check().problems:
		push_warning("Starting deck breaks a unique-card minimum: " + problem)


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


## Public restart entry point for the Game Over screen's "Try again".
## A scene reload resets everything (HP, decks, cooldowns, enemies, waves,
## statuses, timers) in one move; see DECISIONS.md.
func restart_arena() -> void:
	if _restarting:
		return
	_restarting = true
	_prepare_for_restart()
	get_tree().reload_current_scene()


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
