class_name RelayTarget
extends Node3D
## Test double for an enemy: a Node3D with the same child names the game's enemies use (Hurtbox, Health,
## StatusEffectManager). Like Enemy, it frees itself when its Health dies, connected after the status manager so the
## order matches the real scene. `died_handler_ran` lets a test prove a relay event fired before that.

var hurtbox: Hurtbox
var health: Health
var status_manager: StatusEffectManager
var died_handler_ran: bool = false


func _init(team: String = "enemy", hp: float = 20.0) -> void:
	name = "RelayTarget"
	health = Health.new()
	health.name = "Health"
	health.max_health = hp
	health.current_health = hp
	add_child(health)
	status_manager = StatusEffectManager.new()
	status_manager.name = "StatusEffectManager"
	status_manager.health = health
	add_child(status_manager)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.team = team
	hurtbox.health = health
	hurtbox.status_manager = status_manager
	add_child(hurtbox)
	health.died.connect(_on_died)


func _on_died() -> void:
	died_handler_ran = true
	queue_free()
