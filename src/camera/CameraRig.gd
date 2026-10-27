extends Node3D
class_name CameraRig
## Fixed-angle isometric camera rig. The rig's root smoothly follows a target's
## horizontal position; the Camera3D child keeps a constant local offset/angle.

@export var follow_speed: float = 8.0

var target: Node3D = null

@onready var camera: Camera3D = $Camera3D


func _process(delta: float) -> void:
	if target == null:
		return
	var target_pos := target.global_position
	var blend := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target_pos, blend)
