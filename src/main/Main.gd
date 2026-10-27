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
