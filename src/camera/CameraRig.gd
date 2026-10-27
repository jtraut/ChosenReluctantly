extends Node3D
class_name CameraRig
## Fixed-angle isometric camera rig. The rig's root smoothly follows a
## target's horizontal position; the Camera3D child keeps a constant local
## offset/angle, with a decaying random jitter added on top for screen shake.

@export var follow_speed: float = 8.0

var target: Node3D = null

@onready var camera: Camera3D = $Camera3D

var _camera_base_position: Vector3
var _shake_strength: float = 0.0
var _shake_time_remaining: float = 0.0
var _shake_duration_total: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_camera_base_position = camera.position
	Juice.register_camera_rig(self)


func _process(delta: float) -> void:
	if target != null:
		var target_pos := target.global_position
		var blend := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(target_pos, blend)
	_update_shake(delta)


## A stronger/longer shake always wins over a weaker one already running.
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time_remaining = maxf(_shake_time_remaining, duration)
	_shake_duration_total = maxf(_shake_duration_total, duration)


func _update_shake(delta: float) -> void:
	if _shake_time_remaining <= 0.0:
		camera.position = _camera_base_position
		return
	_shake_time_remaining = maxf(_shake_time_remaining - delta, 0.0)
	var falloff := _shake_time_remaining / maxf(_shake_duration_total, 0.0001)
	var jitter := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake_strength * falloff
	camera.position = _camera_base_position + jitter
