extends Node3D
class_name Main
## Wires the arena's player and camera rig together on scene load, and owns
## the death beat and restart for this arena.

## Emitted once, after the death beat (slow-mo) finishes. The Game Over screen
## listens for this (find Main via the scene root: `get_tree().current_scene`).
signal game_over_ready()

var _game_over_announced: bool = false
var _restarting: bool = false

@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var hud: Hud = $Hud
@onready var debug_overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	camera_rig.target = player
	camera_rig.global_position = player.global_position
	player.camera = camera_rig.camera
	enemy_spawner.target = player
	player.player_died.connect(_on_player_died)
	hud.set_player(player)
	debug_overlay.player = player
	AimIndicator.attach(self, player)
	var problems := SceneSelfCheck.find_problems(self)
	if not problems.is_empty():
		push_error("Main scene self-check FAILED (world may render empty): " + "; ".join(problems))
	_setup_debug_capture()


func is_game_over() -> bool:
	return _game_over_announced


func _on_player_died() -> void:
	var beat := UiConfig.death_beat()
	var duration: float = beat["slow_mo_duration"]
	Juice.slow_mo(duration, beat["slow_mo_scale"])
	Juice.screen_shake(0.35, 0.3)
	# Real-time timer (ignore_time_scale = true) so slow-mo doesn't stretch it. Not process_always:
	# a pause during the beat holds it (Juice remembers the slow-mo left), so Game Over never
	# appears over a pause screen.
	get_tree().create_timer(duration, false, false, true).timeout.connect(_announce_game_over)


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
		capture.times = times
		capture.out = config["out"]
		add_child(capture)
