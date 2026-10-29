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
## Elite/boss stats by tier id (data/run.json `tiers`); set by the run controller. Empty = tiers are ignored.
var tier_configs: Dictionary = {}

var _rng := RandomNumberGenerator.new()
## The seed last given to set_seed / configure_room (a boss seeds its own attack picks from it, so it never draws from `_rng`).
var _seed_value: int = 0
var _alive: int = 0
var _scenes: Dictionary = {}

## Evenly spaced fallback angles tried when random ring points keep landing too close (player in a corner).
const SWEEP_ANGLES := 32


## Enemies this spawner has spawned so far; each gets its running number as `spawn_index`.
var _spawn_count: int = 0


func _ready() -> void:
	if plan == null:
		plan = WavePlan.new(WaveConfig.get_config(), _rng)


## Seeds every random choice (spawn order within a stage and positions) for repeatable runs.
## Call before the first wave; it rebuilds the plan from the current config.
func set_seed(seed_value: int) -> void:
	_seed_value = seed_value
	_rng.seed = seed_value
	_spawn_count = 0
	plan = WavePlan.new(WaveConfig.get_config(), _rng)


## Replaces the wave table with one room's finite table (RunConfig.room_wave_config) and seeds it.
func configure_room(room_config: Dictionary, seed_value: int) -> void:
	_seed_value = seed_value
	_rng.seed = seed_value
	_spawn_count = 0
	plan = WavePlan.new(room_config, _rng)


## True when the room's finite table has spawned everything and nothing is left alive.
func room_cleared() -> bool:
	return plan != null and plan.is_finished() and _alive == 0


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
	var enemy_id: String = plan.step_one(delta, _alive)
	if enemy_id != "":
		_spawn_one(enemy_id)


func _spawn_one(queued: String) -> void:
	var decoded: Dictionary = WavePlan.decode(queued)
	var enemy_id: String = decoded["enemy"]
	var tier_id: String = decoded["tier"]
	var scene: PackedScene = _scene_for(enemy_id)
	if scene == null:
		return
	var instance: Enemy = scene.instantiate()
	instance.spawn_index = _spawn_count
	_spawn_count += 1
	if instance is Boss:
		(instance as Boss).set_seed((_seed_value * 2654435761 + instance.spawn_index * 40503 + 12345) & 0x7fffffff)
	# The arena is the spawner's parent (Main); only a parentless spawner falls back to the scene root.
	var world: Node = get_parent() if get_parent() != null else WorldRef.get_world(get_tree())
	var spawn_position := _random_spawn_position()
	if PlayerConfig.collide_with_enemies() and world is Node3D:
		# Solid bodies: in place before it enters the tree. An enemy that first appears at the origin overlaps a
		# player standing there and pops it up onto its head for a few frames. (With the flag off the old order
		# is kept so that setting restores the earlier behaviour exactly, even seed for seed.)
		instance.position = (world as Node3D).to_local(spawn_position)
	world.add_child(instance)
	instance.global_position = spawn_position
	instance.target = target
	instance.begin_spawn_grace(float(plan.config["spawn_attack_grace"]))
	if tier_id != "" and tier_configs.has(tier_id):
		instance.apply_tier(tier_id, tier_configs[tier_id])
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


## A point on a ring around the target, clamped inside the arena and at least spawn_distance_min
## from the target. Random angles first; if the clamp keeps squeezing them under the minimum (a
## player in a corner), sweep evenly spaced angles and take the first that fits, else the farthest (S5-4).
func _random_spawn_position() -> Vector3:
	var config: Dictionary = plan.config
	var min_dist: float = float(config["spawn_distance_min"])
	var max_dist: float = float(config["spawn_distance_max"])
	var best: Vector3 = target.global_position
	var best_dist: float = -1.0
	for attempt in range(8):
		var pos: Vector3 = _ring_point(_rng.randf_range(0.0, TAU), _rng.randf_range(min_dist, max_dist))
		var actual: float = _flat_distance(pos)
		if actual > best_dist:
			best = pos
			best_dist = actual
		if actual >= min_dist:
			return pos
	var sweep_start: float = _rng.randf_range(0.0, TAU)
	for step in range(SWEEP_ANGLES):
		var pos: Vector3 = _ring_point(sweep_start + TAU * float(step) / float(SWEEP_ANGLES), max_dist)
		var actual: float = _flat_distance(pos)
		if actual > best_dist:
			best = pos
			best_dist = actual
		if actual >= min_dist:
			return pos
	return best


func _ring_point(angle: float, dist: float) -> Vector3:
	var limit: float = float(plan.config["arena_half_extent"])
	var pos: Vector3 = target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
	pos.x = clampf(pos.x, -limit, limit)
	pos.z = clampf(pos.z, -limit, limit)
	return pos


func _flat_distance(pos: Vector3) -> float:
	return Vector2(pos.x - target.global_position.x, pos.z - target.global_position.z).length()
