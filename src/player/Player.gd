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

## Milestone 2 has one character: a Fire Rogue with no class/element pick
## yet, so this is a fixed export rather than real character creation.
@export var owned_pools: Array[String] = ["rogue", "fire", "neutral"]

const HIT_FLASH_COLOR := Color(1.0, 0.3, 0.3)
const HIT_FLASH_DURATION := 0.15
const KNOCKBACK_DECAY := 18.0

var camera: Camera3D = null
var stat_modifiers := StatModifiers.new()
var card_slots: CardSlotController

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var body_mesh: MeshInstance3D = $BodyMesh

var _attack_cooldown_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _base_body_color: Color = Color.WHITE
var _knockback_velocity: Vector3 = Vector3.ZERO

# Generic forced-motion override (dodge roll, and later any Movement-slot
# "dash" card): while active, this drives velocity instead of normal input.
var _forced_move_direction: Vector3 = Vector3.FORWARD
var _forced_move_speed: float = 0.0
var _forced_move_time_remaining: float = 0.0
var _forced_move_invulnerable: bool = false


func _ready() -> void:
	var team := hurtbox.team if hurtbox != null else "player"
	card_slots = CardSlotController.new(self, get_tree().current_scene, team, stat_modifiers, owned_pools)
	health.damaged.connect(_on_damaged)
	var material := body_mesh.material_override
	if material is StandardMaterial3D:
		var unique_material: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
		body_mesh.material_override = unique_material
		_base_body_color = unique_material.albedo_color


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	card_slots.advance(delta)
	_handle_dodge_input()
	if _forced_move_time_remaining > 0.0:
		_apply_forced_move(delta)
	else:
		_apply_movement(delta)
	_apply_aim(delta)
	_handle_attack()
	_handle_card_slot_input()
	move_and_slide()


func _on_damaged(amount: float, damage_type: String, knockback: Vector3) -> void:
	_knockback_velocity = knockback
	_flash_body(HIT_FLASH_COLOR)
	Juice.on_hit_landed(global_position, amount, damage_type)


func _flash_body(color: Color) -> void:
	var material := body_mesh.material_override
	if not (material is StandardMaterial3D):
		return
	(material as StandardMaterial3D).albedo_color = color
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", _base_body_color, HIT_FLASH_DURATION)


func _tick_cooldowns(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)


func _handle_dodge_input() -> void:
	if _forced_move_time_remaining > 0.0 or _dodge_cooldown_remaining > 0.0:
		return
	if not Input.is_action_just_pressed("dodge"):
		return
	var input_dir := _movement_input_direction()
	var dodge_direction := input_dir if input_dir.length_squared() > 0.0001 else -global_transform.basis.z
	_dodge_cooldown_remaining = dodge_cooldown
	start_forced_move(dodge_direction, dodge_speed, dodge_duration, true)


## Overrides normal movement input for `duration` seconds, driving velocity
## directly along `direction` at `speed`. Used by the dodge roll, and by the
## "dash" card effect template so Movement-slot cards can reuse the same
## motion/invulnerability machinery instead of duplicating it.
func start_forced_move(direction: Vector3, speed: float, duration: float, invulnerable: bool = false) -> void:
	var flat_direction := direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() < 0.0001:
		flat_direction = -global_transform.basis.z
	_forced_move_direction = flat_direction.normalized()
	_forced_move_speed = speed
	_forced_move_time_remaining = duration
	_forced_move_invulnerable = invulnerable
	if invulnerable and hurtbox != null:
		hurtbox.set_invulnerable(true)


func _apply_forced_move(delta: float) -> void:
	velocity.x = _forced_move_direction.x * _forced_move_speed
	velocity.z = _forced_move_direction.z * _forced_move_speed
	velocity.y = 0.0
	_forced_move_time_remaining -= delta
	if _forced_move_time_remaining <= 0.0:
		_forced_move_time_remaining = 0.0
		if _forced_move_invulnerable and hurtbox != null:
			hurtbox.set_invulnerable(false)
		_forced_move_invulnerable = false


func _handle_attack() -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	if not Input.is_action_just_pressed("attack_basic"):
		return
	_attack_cooldown_remaining = attack_cooldown
	_perform_melee_attack()


func _perform_melee_attack() -> void:
	# The basic attack is just a "cone" effect with no card behind it, so it
	# goes through the same EffectTemplates path a Rogue card would.
	var context := EffectContext.new(self, get_tree().current_scene, hurtbox.team if hurtbox != null else "neutral")
	EffectTemplates.execute("cone", {
		"damage": attack_damage,
		"damage_type": "physical",
		"range": attack_range,
		"half_angle_degrees": attack_half_angle_degrees,
		"knockback_strength": 3.0,
	}, context)


## exact_match=true matters here: without it, Ctrl+1 would also register as
## a plain "1" press and fire slot_1 and dead_card_swap_1 in the same frame.
func _handle_card_slot_input() -> void:
	for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		var slot_type := CardSlotController.slot_type_at_index(i)
		if Input.is_action_just_pressed("dead_card_swap_%d" % (i + 1), true):
			card_slots.try_swap(slot_type)
		elif Input.is_action_just_pressed("slot_%d" % (i + 1), true):
			card_slots.try_use(slot_type)


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

	velocity.x = horizontal_velocity.x + _knockback_velocity.x
	velocity.z = horizontal_velocity.z + _knockback_velocity.z

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
