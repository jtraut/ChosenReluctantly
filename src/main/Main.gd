extends Node3D
class_name Main
## Wires the arena's player and camera rig together on scene load.

@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	camera_rig.target = player
	camera_rig.global_position = player.global_position
	player.camera = camera_rig.camera
