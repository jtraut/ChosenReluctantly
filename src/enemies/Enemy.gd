extends CharacterBody3D
class_name Enemy
## Shared enemy behavior: chase, melee or ranged attack (via EffectTemplates,
## same system cards use), a telegraph before the attack lands, hit-flash,
## and knockback. The 3 enemy types in this milestone (melee chaser, ranged
## shooter, elemental-resistant) are this same script; their stats (health, speed,
## damage, ranges, resistances) come from data/enemies.json, not per-scene exports.

const TELEGRAPH_COLOR := Color(1.0, 0.65, 0.1)
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const HIT_FLASH_DURATION := 0.12
const KNOCKBACK_DECAY := 18.0
const ARRIVAL_MARGIN := 0.3
## Sideways bias (fraction of the push length) so a queue of chasers fans out around the target.
const SWIRL := 0.6
## Fallback stun tint (the real one is `visual.tint_color` / `tint_amount` in data/statuses.json).
const DEFAULT_STUN_TINT := Color(0.74, 0.74, 0.69)
const DEFAULT_STUN_TINT_AMOUNT := 0.55

## A stun began (seconds) / ended. For ux: the stunned cue hangs off these.
signal stunned(duration: float)
signal stun_ended()
## A stun landed while already stunned (seconds left now). `stunned` is only for the start,
## so the stars and tint are not restarted; this is for a flash or sound on a re-stun.
signal stun_refreshed(remaining: float)

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
## Order this enemy came into the world (the spawner assigns it before add_child; a test may set it). Drives
## the swirl side and the on-top push direction so behaviour repeats from a seed. -1 = not assigned: _ready
## then uses how many enemies are already alive (still deterministic for a given scene, never the instance id).
var spawn_index: int = -1

## Every live enemy in the tree, for separation steering (5d). A plain static array walked in place:
## no per-frame allocation, and the order (spawn order) is deterministic.
static var _roster: Array[Enemy] = []
## True while the player has a pass-through buff: no enemy body collides with the player's body.
## Static so an enemy spawned during the buff joins it; the Player clears it on end, death and exit.
static var _player_body_suppressed: bool = false
var _default_collision_mask: int = 0
var _separation_radius: float = 0.0
var _separation_strength: float = 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var status_manager: StatusEffectManager = $StatusEffectManager

var _base_color: Color = Color.WHITE
var _attack_cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _was_stunned: bool = false
## Ground wedge showing a melee wind-up (built on the first telegraph; ranged enemies have none).
var _wedge: AttackArcVisual = null
## The ranged wind-up lane (pooled), ended early when the wind-up is cancelled or the enemy dies.
var _shot_lane: PooledEffect = null
var _shot_lane_generation: int = 0
var _shot_lane_pool: EffectPool = null
var _stun_tint: Color = DEFAULT_STUN_TINT
var _stun_tint_amount: float = DEFAULT_STUN_TINT_AMOUNT
## Seconds until another "IMMUNE" popup may show on this enemy (keeps it quiet).
var _immune_popup_cooldown: float = 0.0


func _ready() -> void:
	if spawn_index < 0:
		spawn_index = _roster.size()
	_roster.append(self)
	_default_collision_mask = collision_mask
	if PlayerConfig.collide_with_enemies():
		_default_collision_mask |= CollisionLayers.PLAYER_BODY  # solid enemies (data/player.json body.collide_with_enemies)
		collision_mask = _default_collision_mask
	if _player_body_suppressed:
		collision_mask = _default_collision_mask & ~CollisionLayers.PLAYER_BODY
	_apply_stats(EnemyConfig.stats_for(enemy_id))
	_separation_radius = EnemyConfig.separation_radius()
	_separation_strength = EnemyConfig.separation_strength()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if status_manager != null:
		status_manager.rank = EnemyConfig.rank_for(enemy_id)
		status_manager.status_applied.connect(_on_status_applied)
		status_manager.status_expired.connect(_on_status_expired)
		status_manager.status_resisted.connect(_on_status_resisted)
		status_manager.status_refreshed.connect(_on_status_refreshed)
	var material := body_mesh.material_override
	if material is StandardMaterial3D:
		var unique_material: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
		body_mesh.material_override = unique_material
		_base_color = unique_material.albedo_color


## Per-type combat stats come from data/enemies.json "enemies.<id>.stats" (validated by EnemyConfig); the
## exports above are only the fallback for an enemy with no data entry.
func _apply_stats(stats: Dictionary) -> void:
	if stats.is_empty():
		return
	move_speed = float(stats["move_speed"])
	is_ranged = bool(stats["is_ranged"])
	attack_range = float(stats["attack_range"])
	preferred_range = float(stats["preferred_range"])
	attack_damage = float(stats["attack_damage"])
	attack_damage_type = String(stats["attack_damage_type"])
	attack_cooldown = float(stats["attack_cooldown"])
	telegraph_duration = float(stats["telegraph_duration"])
	projectile_speed = float(stats["projectile_speed"])
	projectile_max_range = float(stats["projectile_max_range"])


func _exit_tree() -> void:
	_roster.erase(self)


## Pass-through buff (Player): every live enemy stops colliding with the player's body (and stays
## that way for enemies spawned meanwhile), or goes back to the mask its scene gave it.
static func set_player_body_suppressed(suppressed: bool) -> void:
	_player_body_suppressed = suppressed
	for enemy: Enemy in _roster:
		enemy.collision_mask = (enemy._default_collision_mask & ~CollisionLayers.PLAYER_BODY) if suppressed else enemy._default_collision_mask


static func is_player_body_suppressed() -> bool:
	return _player_body_suppressed


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
		if _wedge != null and _telegraph_remaining > 0.0:
			_update_wedge()
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


## Spawn grace (s1-f): the enemy may not start an attack for `seconds`, so a fresh
## spawn is never an instant hit. Only ever lengthens the attack cooldown.
func begin_spawn_grace(seconds: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining, seconds)


## True while a stun status is active (placeholder cue + gameplay hook for ux).
func is_stunned() -> bool:
	return status_manager != null and status_manager.is_stunned()


func _on_status_applied(status_id: String) -> void:
	if is_stunned() and not _was_stunned:
		_was_stunned = true
		var tint := StatusDatabase.body_tint(status_id)
		_stun_tint = tint.get("color", DEFAULT_STUN_TINT)
		_stun_tint_amount = float(tint.get("amount", DEFAULT_STUN_TINT_AMOUNT))
		if _telegraph_remaining > 0.0 and telegraph_duration > 0.0:
			TemplateVfx.windup_cancelled(EffectPool.for_world(get_parent()), global_position, ElementVisuals.visual_for_team(attack_damage_type, "enemy")["color"])
		_cancel_telegraph()
		_set_body_color(_rest_color())
		stunned.emit(status_manager.stun_time_remaining())


func _on_status_refreshed(_status_id: String) -> void:
	if _was_stunned and is_stunned():
		stun_refreshed.emit(status_manager.stun_time_remaining())


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
		_stop_shot_lane()
		if _wedge != null:
			_wedge.hide_now()
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

	var push := _separation_push()
	if distance > desired_range + ARRIVAL_MARGIN:
		var dir := to_target.normalized()
		# Only the sideways part of the push applies while closing in (the along-the-path part just cancels the
		# chase and parks an enemy in a queue behind its neighbour). A fixed per-enemy swirl, scaled by how
		# crowded it is, makes a queue fan out around the target instead of waiting in line.
		var lateral := push - dir * push.dot(dir)
		var side := 1.0 if spawn_index % 2 == 0 else -1.0
		lateral += Vector3(-dir.z, 0.0, dir.x) * (push.length() * SWIRL * side)
		var move := dir * move_speed + lateral * (move_speed * _separation_strength)
		var speed := Vector2(move.x, move.z).length()
		if speed > move_speed:
			move *= move_speed / speed  # steering never makes an enemy faster than its own speed
		velocity.x = move.x + _knockback_velocity.x
		velocity.z = move.z + _knockback_velocity.z
	else:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		if _attack_cooldown_remaining <= 0.0:
			_start_telegraph()
		elif distance > 0.01:
			# In range and waiting out the cooldown: slide sideways (never in or out) to make room.
			var radial := to_target / distance
			var slide := push - radial * push.dot(radial)
			var slide_move := Vector3(slide.x, 0.0, slide.z) * (move_speed * _separation_strength)
			var slide_speed := Vector2(slide_move.x, slide_move.z).length()
			if slide_speed > move_speed:
				slide_move *= move_speed / slide_speed  # same cap as the chase branch (S5d-1)
			velocity.x += slide_move.x
			velocity.z += slide_move.z

	if distance > 0.01:
		_face_direction(to_target.normalized(), delta)


## Sum of pushes away from every other live enemy closer than the separation radius, each weighted
## by how deep inside the radius it is (0 at the edge, 1 on top). Flat (y = 0); length may exceed 1.
func _separation_push() -> Vector3:
	var push := Vector3.ZERO
	if _separation_radius <= 0.0 or _separation_strength <= 0.0:
		return push
	var mine := global_position
	for other in _roster:
		if other == self or other.health.is_dead():
			continue
		var dx := mine.x - other.global_position.x
		var dz := mine.z - other.global_position.z
		var d2 := dx * dx + dz * dz
		if d2 >= _separation_radius * _separation_radius:
			continue
		if d2 < 0.0001:
			# Exactly on top: a stable, per-enemy direction (golden angle steps of the spawn index), not random.
			var angle := float(spawn_index) * 2.399963
			push += Vector3(cos(angle), 0.0, sin(angle))
			continue
		var d := sqrt(d2)
		push += Vector3(dx, 0.0, dz) * ((1.0 - d / _separation_radius) / d)
	return push


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	var blend := 1.0 - exp(-turn_speed * delta)
	global_transform.basis = Basis(current_quat.slerp(target_quat, blend)).orthonormalized()


func _start_telegraph() -> void:
	_telegraph_remaining = telegraph_duration
	_set_body_color(TELEGRAPH_COLOR)
	if telegraph_duration <= 0.0:
		return
	if is_ranged:
		_show_shot_lane()
	else:
		_update_wedge()


## Ranged wind-up: a strip along the line the shot will take (the enemy does not turn while winding up).
func _show_shot_lane() -> void:
	if not is_inside_tree():
		return
	var pool := EffectPool.for_world(get_parent())
	if pool == null:
		return
	var forward: Vector3 = -global_transform.basis.z
	var color: Color = ElementVisuals.visual_for_team(attack_damage_type, "enemy")["color"]
	_shot_lane = TemplateVfx.enemy_shot_lane(pool, global_position + forward * 0.6, forward, projectile_max_range, EnemyConfig.projectile_hit_radius(), color, telegraph_duration)
	_shot_lane_pool = pool
	_shot_lane_generation = _shot_lane.generation if _shot_lane != null else 0


## Ends the lane now (a cancelled wind-up must not promise a shot that never comes).
func _stop_shot_lane() -> void:
	if _shot_lane != null and is_instance_valid(_shot_lane_pool):
		_shot_lane_pool.stop(_shot_lane, _shot_lane_generation)
	_shot_lane = null


## Wind-up wedge on the ground, the same language as the player's heavy (pale outline, fill growing in),
## sized to where the melee cone really lands on the player (VfxSizing) and tinted for the enemy team.
func _update_wedge() -> void:
	if _wedge == null:
		_wedge = AttackArcVisual.new()
		_wedge.name = "TelegraphWedge"
		add_child(_wedge)
		var color: Color = ElementVisuals.visual_for_team(attack_damage_type, "enemy")["color"]
		_wedge.setup(VfxSizing.lateral_reach_vs_player(attack_range), EnemyConfig.melee_half_angle_degrees(), color)
	_wedge.show_windup(1.0 - _telegraph_remaining / telegraph_duration)


func _execute_attack() -> void:
	_set_body_color(_rest_color())
	_stop_shot_lane()
	if _wedge != null:
		_wedge.hide_now()  # the cone template draws the impact itself
	_attack_cooldown_remaining = attack_cooldown
	if not _has_live_target():
		return
	var context := EffectContext.new(self, WorldRef.get_world(get_tree()), hurtbox.team if hurtbox != null else "enemy")
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
	Juice.on_hit_landed(global_position, amount, damage_type, health.last_kind)


func _on_died() -> void:
	_stop_shot_lane()
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
