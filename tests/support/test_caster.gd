class_name TestCaster
extends Node3D
## Test double for a damage dealer: a Node3D (facing -Z) with Health and a StatusEffectManager
## that forwards its own damage_dealt events to lifesteal, exactly like Player does. Unlike
## the Player it never attacks by itself, so a test controls every hit.

signal damage_dealt(target: Node, amount: float, damage_type: String, kind: StringName)

var health: Health
var status_manager: StatusEffectManager
## Every damage_dealt event, as [amount, kind].
var dealt: Array[Array] = []


func _init() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_health = 30.0
	health.current_health = 30.0
	add_child(health)
	status_manager = StatusEffectManager.new()
	status_manager.name = "StatusEffectManager"
	status_manager.health = health
	add_child(status_manager)
	damage_dealt.connect(_on_damage_dealt)


func _on_damage_dealt(_target: Node, amount: float, _damage_type: String, kind: StringName) -> void:
	dealt.append([amount, kind])
	status_manager.on_damage_dealt(amount)
