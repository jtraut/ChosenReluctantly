extends CharacterBody3D
class_name Player
## WASD movement relative to the fixed camera, and continuous mouse-ground aim.

@export var move_speed: float = 6.0
@export var acceleration: float = 24.0
@export var friction: float = 28.0
@export var turn_speed: float = 14.0
@export var gravity: float = 20.0

@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 0.45
@export var attack_range: float = 1.8
@export var attack_half_angle_degrees: float = 50.0

@export var dodge_speed: float = 14.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.8

var camera: Camera3D = null

@onready var hurtbox: Hurtbox = $Hurtbox

var _attack_cooldown_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_time_remaining: float = 0.0
var _is_dodging: bool = false
var _dodge_direction: Vector3 = Vector3.FORWARD


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_handle_dodge(delta)
	if _is_dodging:
		_apply_dodge_motion(delta)
	else:
		_apply_movement(delta)
	_apply_aim(delta)
	_handle_attack()
	move_and_slide()


func _tick_cooldowns(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)


func _handle_dodge(delta: float) -> void:
	if _is_dodging:
		_dodge_time_remaining -= delta
		if _dodge_time_remaining <= 0.0:
			_end_dodge()
		return
	if _dodge_cooldown_remaining > 0.0:
		return
	if not Input.is_action_just_pressed("dodge"):
		return
	var input_dir := _movement_input_direction()
	_dodge_direction = input_dir if input_dir.length_squared() > 0.0001 else -global_transform.basis.z
	_is_dodging = true
	_dodge_time_remaining = dodge_duration
	_dodge_cooldown_remaining = dodge_cooldown
	if hurtbox != null:
		hurtbox.set_invulnerable(true)


func _end_dodge() -> void:
	_is_dodging = false
	if hurtbox != null:
		hurtbox.set_invulnerable(false)


func _apply_dodge_motion(_delta: float) -> void:
	velocity.x = _dodge_direction.x * dodge_speed
	velocity.z = _dodge_direction.z * dodge_speed
	velocity.y = 0.0


func _handle_attack() -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	if not Input.is_action_just_pressed("attack_basic"):
		return
	_attack_cooldown_remaining = attack_cooldown
	_perform_melee_attack()


func _perform_melee_attack() -> void:
	var world := get_world_3d()
	if world == null:
		return
	var forward := -global_transform.basis.z
	var hits := MeleeQuery.find_hurtboxes_in_cone(
		world.direct_space_state,
		global_position,
		forward,
		attack_range,
		attack_half_angle_degrees,
		"player",
		CollisionLayers.HURTBOX
	)
	for target_hurtbox: Hurtbox in hits:
		target_hurtbox.receive_damage(attack_damage, "physical")


func _movement_input_direction() -> Vector3:
	var forward_input := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var right_input := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var basis_forward := Vector3.FORWARD
	var basis_right := Vector3.RIGHT
	if camera != null:
		basis_forward = _flattened(-camera.global_transform.basis.z)
		basis_right = _flattened(camera.global_transform.basis.x)
	var dir := basis_forward * forward_input + basis_right * right_input
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir


func _apply_movement(delta: float) -> void:
	var move_dir := _movement_input_direction()
	var target_velocity := move_dir * move_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else friction
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta


func _apply_aim(delta: float) -> void:
	if camera == null:
		return
	var aim_point: Variant = _ground_point_under_mouse()
	if aim_point == null:
		return
	var to_aim := (aim_point as Vector3) - global_position
	to_aim.y = 0.0
	if to_aim.length_squared() < 0.0001:
		return
	var target_basis := Basis.looking_at(to_aim, Vector3.UP)
	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	var blend := 1.0 - exp(-turn_speed * delta)
	var blended := Basis(current_quat.slerp(target_quat, blend))
	global_transform.basis = blended.orthonormalized()


func _ground_point_under_mouse() -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_origin, ray_dir)


func _flattened(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()
