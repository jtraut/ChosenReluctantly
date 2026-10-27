extends Node
class_name Health
## Generic health/damage component. Attach to any Node3D that can take damage.
## Resistance is per-element, data on this node (set it for enemies via their
## spawner/data); physical damage always ignores resistance.

signal damaged(amount: float, damage_type: String)
signal healed(amount: float)
signal health_changed(current: float, max: float)
signal died()

@export var max_health: float = 20.0
## element name ("fire", "water", ...) -> resistance fraction [0, resistance_cap]
@export var resistances: Dictionary = {}
@export var resistance_cap: float = 0.5

var current_health: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float, damage_type: String = "physical") -> void:
	if _is_dead or amount <= 0.0:
		return
	var resistance_fraction: float = resistances.get(damage_type, 0.0)
	var final_amount := CombatMath.apply_resistance(amount, damage_type, resistance_fraction, resistance_cap)
	if final_amount <= 0.0:
		return
	current_health = maxf(current_health - final_amount, 0.0)
	damaged.emit(final_amount, damage_type)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0 and not _is_dead:
		_is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _is_dead
