extends Node
## Autoload. Central hook for combat feel: hit-stop, screen shake, and
## damage numbers, so every place that reacts to a hit (Player, Enemy,
## TrainingDummy) calls one thing instead of re-implementing feel per script.

const DAMAGE_NUMBER_SCENE_PATH := "res://scenes/effects/DamageNumber.tscn"
const HEAVY_HIT_THRESHOLD := 10.0

var _hitstop_resume_msec: int = -1
var _camera_rig: CameraRig = null


func _process(_delta: float) -> void:
	if _hitstop_resume_msec >= 0 and Time.get_ticks_msec() >= _hitstop_resume_msec:
		Engine.time_scale = 1.0
		_hitstop_resume_msec = -1


## Autoloads outlive scene reloads: clear timing state and the (soon freed)
## camera rig and put time back to normal. Call before changing scenes.
func reset() -> void:
	_hitstop_resume_msec = -1
	_camera_rig = null
	Engine.time_scale = 1.0


## Slow-motion beat. Same wall-clock mechanism as hit_stop, so it ends on time
## despite the reduced time scale.
func slow_mo(duration_sec: float, time_scale: float) -> void:
	hit_stop(duration_sec, time_scale)


func register_camera_rig(rig: CameraRig) -> void:
	_camera_rig = rig


## A longer hit-stop always wins over a shorter one already running; it
## never "resets" a longer one that's still counting down.
func hit_stop(duration_sec: float, time_scale: float = 0.05) -> void:
	var resume_at := Time.get_ticks_msec() + int(duration_sec * 1000.0)
	if resume_at > _hitstop_resume_msec:
		_hitstop_resume_msec = resume_at
		Engine.time_scale = time_scale


func screen_shake(strength: float, duration: float) -> void:
	if is_instance_valid(_camera_rig):
		_camera_rig.shake(strength, duration)


## The one call combat code makes on a hit: shows the number, and adds
## hit-stop/shake if the hit was "heavy" (per HEAVY_HIT_THRESHOLD).
func on_hit_landed(world_pos: Vector3, amount: float, damage_type: String) -> void:
	spawn_damage_number(world_pos, amount, damage_type)
	if amount >= HEAVY_HIT_THRESHOLD:
		hit_stop(0.06, 0.04)
		screen_shake(0.25, 0.18)
	else:
		hit_stop(0.03, 0.2)


func spawn_damage_number(world_pos: Vector3, amount: float, damage_type: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var scene: PackedScene = load(DAMAGE_NUMBER_SCENE_PATH)
	var instance: DamageNumber = scene.instantiate()
	tree.current_scene.add_child(instance)
	instance.global_position = world_pos + Vector3(0.0, 1.6, 0.0)
	instance.show_amount(amount, damage_type)
