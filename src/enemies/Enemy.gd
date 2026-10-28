extends CharacterBody3D
class_name Enemy
## Shared enemy behavior: chase, melee or ranged attack (via EffectTemplates,
## same system cards use), a telegraph before the attack lands, hit-flash,
## and knockback. The 3 enemy types in this milestone (melee chaser, ranged
## shooter, elemental-resistant) are this same script with different exported
## values per scene - resistance itself lives as data on the Health node.

const TELEGRAPH_COLOR := Color(1.0, 0.65, 0.1)
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const HIT_FLASH_DURATION := 0.12
const KNOCKBACK_DECAY := 18.0
const ARRIVAL_MARGIN := 0.3
## Fallback stun tint (the real one is `visual.tint_color` / `tint_amount` in data/statuses.json).
const DEFAULT_STUN_TINT := Color(0.74, 0.74, 0.69)
const DEFAULT_STUN_TINT_AMOUNT := 0.55

## A stun began (seconds) / ended. For ux: the stunned cue hangs off these.
signal stunned(duration: float)
signal stun_ended()

## Key into data/enemies.json "enemies" (rank). Set per scene.
@export var enemy_id: String = ""

@export var move_speed: float = 3.5
@export var gravity: float = 20.0
@export var turn_speed: float = 10.0

@export var is_ranged: bool = false
@export var attack_range: float = 1.6
@export var preferred_range: float = 6.0
@export var attack_damage: float = 6.0
@export var attack_damage_type: String = "physical"
@export var attack_cooldown: float = 1.4
@export var telegraph_duration: float = 0.45

@export var projectile_speed: float = 10.0
@export var projectile_max_range: float = 20.0

var target: Node3D = null

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var status_manager: StatusEffectManager = $StatusEffectManager

var _base_color: Color = Color.WHITE
var _attack_cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _was_stunned: bool = false
var _stun_tint: Color = DEFAULT_STUN_TINT
var _stun_tint_amount: float = DEFAULT_STUN_TINT_AMOUNT
## Seconds until another "IMMUNE" popup may show on this enemy (keeps it quiet).
var _immune_popup_cooldown: float = 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if status_manager != null:
		status_manager.rank = EnemyConfig.rank_for(enemy_id)
		status_manager.status_applied.connect(_on_status_applied)
		status_manager.status_expired.connect(_on_status_expired)
		status_manager.status_resisted.connect(_on_status_resisted)
	var material := body_mesh.material_override
	if material is StandardMaterial3D:
		var unique_material: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
		body_mesh.material_override = unique_material
		_base_color = unique_material.albedo_color


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_immune_popup_cooldown = maxf(_immune_popup_cooldown - delta, 0.0)

	if is_stunned():
		# Stunned: no chasing, turning or attacking, and any wind-up is dropped. Only
		# knockback moves it.
		_cancel_telegraph()
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
	elif not _has_live_target() or health.is_dead():
		# No target, or the player is dead: stand down (and drop any wind-up).
		_cancel_telegraph()
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
	elif _telegraph_remaining > 0.0:
		_telegraph_remaining -= delta
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		if _telegraph_remaining <= 0.0:
			_execute_attack()
	else:
		_chase_and_attack(delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## True while a stun status is active (placeholder cue + gameplay hook for ux).
func is_stunned() -> bool:
	return status_manager != null and status_manager.is_stunned()


func _on_status_applied(status_id: String) -> void:
	if is_stunned() and not _was_stunned:
		_was_stunned = true
		var tint := StatusDatabase.body_tint(status_id)
		_stun_tint = tint.get("color", DEFAULT_STUN_TINT)
		_stun_tint_amount = float(tint.get("amount", DEFAULT_STUN_TINT_AMOUNT))
		_cancel_telegraph()
		_set_body_color(_rest_color())
		stunned.emit(status_manager.stun_time_remaining())


func _on_status_expired(_status_id: String) -> void:
	if _was_stunned and not is_stunned():
		_was_stunned = false
		_set_body_color(_rest_color())
		stun_ended.emit()


## A stun bounced off (boss, or diminishing returns): a small word above the head, at
## most once per `immune_cooldown` per enemy so a rapid-hit crowd stays quiet.
func _on_status_resisted(_status_id: String) -> void:
	if _immune_popup_cooldown > 0.0 or health.is_dead():
		return
	var cfg: Dictionary = UiConfig.popups()
	_immune_popup_cooldown = float(cfg["immune_cooldown"])
	Juice.spawn_popup(global_position, String(cfg["immune_text"]), Color.html(String(cfg["immune_color"])), float(cfg["immune_scale"]), float(cfg["immune_height"]))


func _cancel_telegraph() -> void:
	if _telegraph_remaining > 0.0:
		_telegraph_remaining = 0.0
		_set_body_color(_rest_color())


## The body color at rest: base, or tinted while stunned.
func _rest_color() -> Color:
	return _base_color.lerp(_stun_tint, _stun_tint_amount) if _was_stunned else _base_color


func _has_live_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return not (target.has_method("is_dead") and bool(target.call("is_dead")))


func _chase_and_attack(delta: float) -> void:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var desired_range := preferred_range if is_ranged else attack_range

	if distance > desired_range + ARRIVAL_MARGIN:
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed + _knockback_velocity.x
		velocity.z = dir.z * move_speed + _knockback_velocity.z
	else:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		if _attack_cooldown_remaining <= 0.0:
			_start_telegraph()

	if distance > 0.01:
		_face_direction(to_target.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	var blend := 1.0 - exp(-turn_speed * delta)
	global_transform.basis = Basis(current_quat.slerp(target_quat, blend)).orthonormalized()


func _start_telegraph() -> void:
	_telegraph_remaining = telegraph_duration
	_set_body_color(TELEGRAPH_COLOR)


func _execute_attack() -> void:
	_set_body_color(_rest_color())
	_attack_cooldown_remaining = attack_cooldown
	if not _has_live_target():
		return
	var context := EffectContext.new(self, get_tree().current_scene, hurtbox.team if hurtbox != null else "enemy")
	if is_ranged:
		EffectTemplates.execute("projectile", {
			"damage": attack_damage,
			"damage_type": attack_damage_type,
			"speed": projectile_speed,
			"max_range": projectile_max_range,
			"hit_radius": EnemyConfig.projectile_hit_radius(),
		}, context)
	else:
		EffectTemplates.execute("cone", {
			"damage": attack_damage,
			"damage_type": attack_damage_type,
			"range": attack_range,
			"half_angle_degrees": EnemyConfig.melee_half_angle_degrees(),
			"knockback_strength": 2.0,
		}, context)


func _on_damaged(amount: float, damage_type: String, knockback: Vector3) -> void:
	_knockback_velocity = knockback
	_flash_body(HIT_FLASH_COLOR)
	Juice.on_hit_landed(global_position, amount, damage_type)


func _on_died() -> void:
	queue_free()


func _flash_body(color: Color) -> void:
	_set_body_color(color)
	var tween := create_tween()
	tween.tween_property(body_mesh, "material_override:albedo_color", _rest_color(), HIT_FLASH_DURATION)
	# A stun that lands in the same hit must keep its tint once the flash has faded.
	tween.tween_callback(func() -> void: _set_body_color(_rest_color()))


func _set_body_color(color: Color) -> void:
	var material := body_mesh.material_override
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color = color
