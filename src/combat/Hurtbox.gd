extends Area3D
class_name Hurtbox
## Detectable-by-query damage receiver. "team" prevents friendly fire; attacks
## filter out hurtboxes on their own team. Set invulnerable (dodge i-frames)
## by zeroing the collision layer so attack queries simply don't find it.

@export var team: String = "neutral"
@export var health_path: NodePath
@export var status_manager_path: NodePath

var health: Health = null
var status_manager: StatusEffectManager = null
var _default_collision_layer: int = 0


func _ready() -> void:
	_default_collision_layer = collision_layer
	if health_path != NodePath():
		health = get_node(health_path) as Health
	if status_manager_path != NodePath():
		status_manager = get_node(status_manager_path) as StatusEffectManager


func receive_damage(amount: float, damage_type: String = "physical", knockback: Vector3 = Vector3.ZERO, source: Node = null, kind: StringName = Health.KIND_HIT) -> void:
	if health != null:
		health.take_damage(amount, damage_type, knockback, source, kind)


func set_invulnerable(invulnerable: bool) -> void:
	collision_layer = 0 if invulnerable else _default_collision_layer
