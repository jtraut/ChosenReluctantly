extends Node3D
class_name TrainingDummy
## Manual-test target for the basic attack: prints what it takes and shows
## the same juice (damage numbers, hit-stop/shake) a real enemy would.

@onready var health: Health = $Health


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _on_damaged(amount: float, damage_type: String, _knockback: Vector3) -> void:
	print("TrainingDummy took %.1f %s damage (%.1f/%.1f hp)" % [amount, damage_type, health.current_health, health.max_health])
	Juice.on_hit_landed(global_position, amount, damage_type, health.last_kind, health.last_channel, health.last_reduction)


func _on_died() -> void:
	print("TrainingDummy died")
