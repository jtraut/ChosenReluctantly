extends CharacterBody3D
class_name Player
## WASD movement relative to the fixed camera, and continuous mouse-ground aim.

## Emitted once when Health reaches 0. Main, the run system, and UI listen here.
signal player_died()

## Attack timing signals for UI (ids are &"light" / &"heavy"). Forwarded from
## the AttackController. started: swing or wind-up begins; fired: damage
## moment; ready: cooldown finished; cancelled: wind-up aborted (death).
signal attack_started(attack_id: StringName)
signal attack_fired(attack_id: StringName)
signal attack_ready(attack_id: StringName)
signal attack_cancelled(attack_id: StringName)

@export var move_speed: float = 6.0
@export var acceleration: float = 24.0
@export var friction: float = 28.0
@export var turn_speed: float = 14.0
@export var gravity: float = 20.0

@export var dodge_speed: float = 14.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.8

## Milestone 2 has one character: a Fire Rogue with no class/element pick
## yet, so this is a fixed export rather than real character creation.
@export var owned_pools: Array[String] = ["rogue", "fire", "neutral"]

const HIT_FLASH_COLOR := Color(1.0, 0.3, 0.3)
const HIT_FLASH_DURATION := 0.15
const KNOCKBACK_DECAY := 18.0
const DEATH_FLASH_WHITE := Color(1.0, 1.0, 1.0)
const DEATH_FLASH_RED := Color(1.0, 0.1, 0.1)
const DEATH_FLASH_HOLD := 0.08
const DEATH_SHAKE_STRENGTH := 0.45
const DEATH_SHAKE_DURATION := 0.3

var camera: Camera3D = null
var stat_modifiers := StatModifiers.new()
var card_slots: CardSlotController
var attacks: AttackController

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var body_mesh: MeshInstance3D = $BodyMesh

var _attack_visuals: Dictionary = {}
var _dodge_cooldown_remaining: float = 0.0
var _base_body_color: Color = Color.WHITE
var _knockback_velocity: Vector3 = Vector3.ZERO
var _dead: bool = false

# Generic forced-motion override (dodge roll, and later any Movement-slot
# "dash" card): while active, this drives velocity instead of normal input.
var _forced_move_direction: Vector3 = Vector3.FORWARD
var _forced_move_speed: float = 0.0
var _forced_move_time_remaining: float = 0.0
var _forced_move_invulnerable: bool = false
## Element look for the dash card's trail and end puff; empty (dodge roll) means no trail.
var _forced_move_look: Dictionary = {}
var _forced_move_trail_timer: float = 0.0

const DASH_TRAIL_INTERVAL := 0.04


func _ready() -> void:
	var team := hurtbox.team if hurtbox != null else "player"
	card_slots = CardSlotController.new(self, get_tree().current_scene, team, stat_modifiers, owned_pools)
	_setup_attacks()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	# The body material lives in the scene as a surface override, so material_override
	# is empty until we take a unique copy here. Every flash (hit, death) tweens this
	# copy; before, nothing was found and none of them ever showed.
	var material: Material = body_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		var unique_material: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
		body_mesh.material_override = unique_material
		_base_body_color = unique_material.albedo_color


func _physics_process(delta: float) -> void:
	if _dead:
		_tick_dead(delta)
		return
	_tick_cooldowns(delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	card_slots.advance(delta)
	_handle_dodge_input()
	if _forced_move_time_remaining > 0.0:
		_apply_forced_move(delta)
	else:
		_apply_movement(delta)
	_apply_aim(delta)
	_handle_attack(delta)
	_handle_card_slot_input()
	move_and_slide()


func is_dead() -> bool:
	return _dead


## False once dead: gates input, movement, cards, dodge, and light/heavy attacks.
func can_act() -> bool:
	return not _dead


## 0..1 fraction of the attack's cooldown elapsed (1.0 = ready). `attack_id`
## is &"light" or &"heavy". Unknown ids return 0.0.
func get_attack_progress(attack_id: StringName) -> float:
	return attacks.get_progress(attack_id)


func is_attack_ready(attack_id: StringName) -> bool:
	return attacks.is_ready(attack_id)


## Effective cooldown in seconds after StatModifiers.
func get_attack_interval(attack_id: StringName) -> float:
	return attacks.get_interval(attack_id)


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_forced_move_time_remaining = 0.0
	_forced_move_invulnerable = false
	_forced_move_look = {}
	attacks.cancel_all()
	if hurtbox != null:
		hurtbox.set_invulnerable(true)
	_play_death_animation()
	player_died.emit()


## Dead bodies only settle: friction on any leftover slide, gravity, no input.
func _tick_dead(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## Placeholder death beat (s1-a): the body flashes white then red (so the moment
## of death reads in a still), a red ring and burst pop out of it, the camera
## shakes, and then the body greys out and topples. Primitives only. The beat
## runs in slow-mo, so the flash holds are short in game time.
func _play_death_animation() -> void:
	var config := UiConfig.death_beat()
	var duration: float = config["collapse_duration"]
	var material := body_mesh.material_override
	TemplateVfx.death_cue(EffectPool.for_world(get_parent()), global_position)
	Juice.screen_shake(DEATH_SHAKE_STRENGTH, DEATH_SHAKE_DURATION)
	var topple := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	topple.tween_property(body_mesh, "rotation_degrees:x", -90.0, duration).set_delay(DEATH_FLASH_HOLD)
	topple.tween_property(body_mesh, "position:y", body_mesh.position.y * 0.5, duration).set_delay(DEATH_FLASH_HOLD)
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		standard.albedo_color = DEATH_FLASH_WHITE
		var colors := create_tween()
		colors.tween_interval(DEATH_FLASH_HOLD * 0.5)
		colors.tween_property(standard, "albedo_color", DEATH_FLASH_RED, DEATH_FLASH_HOLD * 0.5)
		colors.tween_interval(DEATH_FLASH_HOLD)
		colors.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		colors.tween_property(standard, "albedo_color", Color(0.25, 0.25, 0.25), duration)


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
func start_forced_move(direction: Vector3, speed: float, duration: float, invulnerable: bool = false, vfx_look: Dictionary = {}) -> void:
	if _dead:
		return
	_forced_move_look = vfx_look
	_forced_move_trail_timer = 0.0
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
	if not _forced_move_look.is_empty():
		_forced_move_trail_timer -= delta
		if _forced_move_trail_timer <= 0.0:
			_forced_move_trail_timer = DASH_TRAIL_INTERVAL
			TemplateVfx.dash_trail(EffectPool.for_world(get_parent()), global_position, _forced_move_look)
	if _forced_move_time_remaining <= 0.0:
		_forced_move_time_remaining = 0.0
		if not _forced_move_look.is_empty():
			# Where the motion actually stopped (it may have been blocked short of the distance).
			TemplateVfx.dash_end(EffectPool.for_world(get_parent()), global_position, _forced_move_look)
			_forced_move_look = {}
		if _forced_move_invulnerable and hurtbox != null:
			hurtbox.set_invulnerable(false)
		_forced_move_invulnerable = false


func _setup_attacks() -> void:
	var defs := AttackDatabase.load_valid()
	attacks = AttackController.new(defs, stat_modifiers)
	attacks.attack_started.connect(_on_attack_started)
	attacks.attack_fired.connect(_on_attack_fired)
	attacks.attack_ready.connect(func(attack_id: StringName) -> void: attack_ready.emit(attack_id))
	attacks.attack_cancelled.connect(_on_attack_cancelled)
	for attack_id: StringName in attacks.ids():
		var def := attacks.get_def(attack_id)
		var visual := AttackArcVisual.new()
		visual.name = "AttackVisual_%s" % attack_id
		add_child(visual)
		visual.setup(VfxSizing.cone_reach(float(def["range"])), float(def["half_angle_degrees"]), Color.html(String(def["color"])))
		_attack_visuals[attack_id] = visual


func _handle_attack(delta: float) -> void:
	var manual: Dictionary = {
		&"light": Input.is_action_just_pressed("attack_light"),
		&"heavy": Input.is_action_just_pressed("attack_heavy"),
	}
	attacks.tick(delta, can_act(), manual, _attack_has_target)
	for attack_id: StringName in attacks.ids():
		if attacks.is_winding_up(attack_id):
			(_attack_visuals[attack_id] as AttackArcVisual).show_windup(attacks.get_windup_progress(attack_id))


## True when at least one enemy is inside the attack's range and arc, facing
## the current aim direction. Gate for automatic attacks (never whiff).
func _attack_has_target(attack_id: StringName) -> bool:
	if not is_inside_tree():
		return false
	var def := attacks.get_def(attack_id)
	var hits := MeleeQuery.find_hurtboxes_in_cone(
		get_world_3d().direct_space_state,
		global_position,
		-global_transform.basis.z,
		float(def["range"]),
		float(def["half_angle_degrees"]),
		hurtbox.team if hurtbox != null else "player",
		CollisionLayers.HURTBOX
	)
	return not hits.is_empty()


func _on_attack_started(attack_id: StringName) -> void:
	if attacks.is_winding_up(attack_id):
		(_attack_visuals[attack_id] as AttackArcVisual).show_windup(0.0)
	attack_started.emit(attack_id)


func _on_attack_cancelled(attack_id: StringName) -> void:
	(_attack_visuals[attack_id] as AttackArcVisual).hide_now()
	attack_cancelled.emit(attack_id)


func _on_attack_fired(attack_id: StringName) -> void:
	var def := attacks.get_def(attack_id)
	# Light and heavy are just "cone" effects with no card behind them, so
	# they go through the same EffectTemplates path a Rogue card would.
	var context := EffectContext.new(self, get_tree().current_scene, hurtbox.team if hurtbox != null else "neutral")
	EffectTemplates.execute("cone", {
		"damage": def["damage"],
		"damage_type": def["damage_type"],
		"range": def["range"],
		"half_angle_degrees": def["half_angle_degrees"],
		"knockback_strength": def["knockback"],
		"vfx": false,
	}, context)
	(_attack_visuals[attack_id] as AttackArcVisual).flash(float(def["flash_duration"]))
	if not context.last_hits.is_empty():
		Juice.hit_stop(float(def["hit_stop_duration"]), float(def["hit_stop_scale"]))
		Juice.screen_shake(float(def["shake_strength"]), float(def["shake_duration"]))
	attack_fired.emit(attack_id)


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
