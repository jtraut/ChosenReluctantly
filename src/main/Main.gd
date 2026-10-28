extends Node3D
class_name Main
## Wires the arena's player and camera rig together on scene load.

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
	hud.set_player(player)
	debug_overlay.player = player
	var problems := SceneSelfCheck.find_problems(self)
	if not problems.is_empty():
		push_error("Main scene self-check FAILED (world may render empty): " + "; ".join(problems))
	_setup_debug_capture()


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
