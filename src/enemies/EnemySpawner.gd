extends Node3D
class_name EnemySpawner
## Sends staged waves of enemies into the arena around `target`. What spawns, when,
## and the simultaneous-enemy cap all come from data/waves.json (WaveConfig/WavePlan);
## enemy ids resolve to scenes through data/enemies.json. New enemies appear on a
## ring outside the player's immediate area, inside the arena, and get a short
## attack grace so first contact is never instant (s1-f).

## Emitted after each enemy is added: (enemy, alive_count).
signal enemy_spawned(enemy: Enemy, alive: int)

var target: Node3D = null
## The wave table state (built from data/waves.json; tests and tools may replace it).
var plan: WavePlan = null

var _rng := RandomNumberGenerator.new()
var _alive: int = 0
var _scenes: Dictionary = {}


func _ready() -> void:
	if plan == null:
		plan = WavePlan.new(WaveConfig.get_config(), _rng)


## Seeds every random choice (spawn order within a stage and positions) for repeatable runs.
## Call before the first wave; it rebuilds the plan from the current config.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	plan = WavePlan.new(WaveConfig.get_config(), _rng)


## The spawner's random generator (so a tool that builds its own WavePlan stays on the same seed).
func rng() -> RandomNumberGenerator:
	return _rng


## Enemies spawned by this spawner that are still in the tree.
func alive_count() -> int:
	return _alive


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or plan == null:
		return
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return  # player is dead: no more waves
	for enemy_id: String in plan.step(delta, _alive):
		_spawn_one(enemy_id)


func _spawn_one(enemy_id: String) -> void:
	var scene: PackedScene = _scene_for(enemy_id)
	if scene == null:
		return
	var instance: Enemy = scene.instantiate()
	# The arena is the spawner's parent (Main); only a parentless spawner falls back to the scene root.
	var world: Node = get_parent() if get_parent() != null else get_tree().current_scene
	world.add_child(instance)
	instance.global_position = _random_spawn_position()
	instance.target = target
	instance.begin_spawn_grace(float(plan.config["spawn_attack_grace"]))
	_alive += 1
	instance.tree_exited.connect(_on_enemy_gone, CONNECT_ONE_SHOT)
	enemy_spawned.emit(instance, _alive)


func _on_enemy_gone() -> void:
	_alive = maxi(_alive - 1, 0)


func _scene_for(enemy_id: String) -> PackedScene:
	if not _scenes.has(enemy_id):
		var path := EnemyConfig.scene_path_for(enemy_id)
		_scenes[enemy_id] = load(path) as PackedScene if path != "" else null
	return _scenes[enemy_id]


## A point on a ring around the target, clamped inside the arena. Tries a few angles so
## a player standing at the wall still gets spawns at least spawn_distance_min away.
func _random_spawn_position() -> Vector3:
	var config: Dictionary = plan.config
	var limit: float = float(config["arena_half_extent"])
	var min_dist: float = float(config["spawn_distance_min"])
	var best: Vector3 = target.global_position
	var best_dist: float = -1.0
	for attempt in range(8):
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(min_dist, float(config["spawn_distance_max"]))
		var pos: Vector3 = target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
		pos.x = clampf(pos.x, -limit, limit)
		pos.z = clampf(pos.z, -limit, limit)
		var actual: float = Vector2(pos.x - target.global_position.x, pos.z - target.global_position.z).length()
		if actual > best_dist:
			best = pos
			best_dist = actual
		if actual >= min_dist:
			break
	return best
