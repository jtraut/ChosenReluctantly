extends Node3D
class_name EnemySpawner
## Sends waves of enemies into the arena around a fixed target point. Picks
## uniformly at random from `enemy_scenes` and spawns in a ring around
## `target` so new enemies don't appear on top of the player.

@export var enemy_scenes: Array[PackedScene] = []
@export var wave_interval: float = 10.0
@export var enemies_per_wave: int = 2
@export var spawn_radius: float = 10.0
@export var min_spawn_distance: float = 5.0

var target: Node3D = null

var _wave_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	if target == null or enemy_scenes.is_empty():
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_spawn_wave()
		_wave_timer = wave_interval


func _spawn_wave() -> void:
	for i in range(enemies_per_wave):
		_spawn_one()


func _spawn_one() -> void:
	var scene: PackedScene = enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
	var instance: Enemy = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = _random_spawn_position()
	instance.target = target


func _random_spawn_position() -> Vector3:
	var angle := _rng.randf_range(0.0, TAU)
	var dist := _rng.randf_range(min_spawn_distance, spawn_radius)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * dist
	return target.global_position + offset
