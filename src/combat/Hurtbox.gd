extends Area3D
class_name Hurtbox
## Detectable-by-query damage receiver. "team" prevents friendly fire; attacks
## filter out hurtboxes on their own team. Set invulnerable (dodge i-frames)
## by zeroing the collision layer so attack queries simply don't find it.

@export var team: String = "neutral"
@export var health_path: NodePath

var health: Health = null
var _default_collision_layer: int = 0


func _ready() -> void:
	_default_collision_layer = collision_layer
	if health_path != NodePath():
		health = get_node(health_path) as Health


func receive_damage(amount: float, damage_type: String = "physical") -> void:
	if health != null:
		health.take_damage(amount, damage_type)


func set_invulnerable(invulnerable: bool) -> void:
	collision_layer = 0 if invulnerable else _default_collision_layer
