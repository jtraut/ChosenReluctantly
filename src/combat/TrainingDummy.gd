extends Node3D
class_name TrainingDummy
## Manual-test target for the basic attack. Prints what it takes until the
## HUD/damage-number juice pass gives it something better to show.

@onready var health: Health = $Health


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _on_damaged(amount: float, damage_type: String) -> void:
	print("TrainingDummy took %.1f %s damage (%.1f/%.1f hp)" % [amount, damage_type, health.current_health, health.max_health])


func _on_died() -> void:
	print("TrainingDummy died")
