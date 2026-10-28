class_name Scenario
extends Node
## Scripted test scene driven through real systems (Health, StatusEffectManager,
## enemy scenes). Definitions live in data/scenarios.json. Added by Main only
## when --scenario=<id> is passed.

const DATA_PATH := "res://data/scenarios.json"

var _main: Node3D
var _def: Dictionary = {}
var _enemies: Array[Enemy] = []
var _elapsed: float = 0.0
var _late_hit_done: bool = false
var _kill_done: bool = false


static func has_scenario(scenario_id: String) -> bool:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has(scenario_id)


static func load_def(scenario_id: String) -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Scenario: could not open " + DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has(scenario_id):
		push_error("Scenario: unknown scenario '%s'" % scenario_id)
		return {}
	return (parsed as Dictionary)[scenario_id]


## Builds the scenario inside `main` (which must have a Player) and returns the
## Scenario node (already a child of main) so callers can inspect enemies.
static func setup(main: Node3D, scenario_id: String) -> Scenario:
	var def := load_def(scenario_id)
	if def.is_empty():
		return null
	var scenario := Scenario.new()
	scenario.name = "Scenario"
	scenario._main = main
	scenario._def = def
	main.add_child(scenario)
	scenario._build()
	return scenario


func enemies() -> Array[Enemy]:
	return _enemies


func _build() -> void:
	var player: Player = _main.get_node("Player")
	if bool(_def.get("disable_spawner", true)):
		var spawner: Node = _main.get_node_or_null("EnemySpawner")
		if spawner != null:
			spawner.process_mode = Node.PROCESS_MODE_DISABLED
	# Keep the player alive for the whole capture.
	player.health.set_max_health(float(_def.get("player_max_health", 9999.0)))
	player.health.heal(player.health.get_max_health())

	var offset_values: Array = _def.get("origin_offset", [3.0, 0.0, -2.0])
	var origin := Vector3(float(offset_values[0]), float(offset_values[1]), float(offset_values[2]))
	var spacing_values: Array = _def.get("spacing", [1.3, 1.2])
	var spacing := Vector2(float(spacing_values[0]), float(spacing_values[1]))
	var columns: int = maxi(int(_def.get("columns", 3)), 1)
	var index := 0
	for group: Dictionary in _def.get("groups", []):
		var packed: PackedScene = load(String(group["scene"]))
		for i in range(int(group.get("count", 1))):
			var enemy: Enemy = packed.instantiate()
			_main.add_child(enemy)
			enemy.global_position = player.global_position + origin + Vector3(
				float(index % columns) * spacing.x, 0.0, float(index / columns) * spacing.y)
			enemy.target = player
			_enemies.append(enemy)
			index += 1

	var fractions: Array = _def.get("hp_fractions", [])
	for i in range(mini(fractions.size(), _enemies.size())):
		var health: Health = _enemies[i].health
		var lost: float = health.get_max_health() * (1.0 - float(fractions[i]))
		if lost > 0.0:
			health.take_damage(lost, "physical")

	for burn_index: int in _def.get("burn_indices", []):
		if burn_index < _enemies.size():
			var manager: StatusEffectManager = _enemies[burn_index].get_node("StatusEffectManager")
			manager.apply_status("burn", StatusDatabase.get_status("burn"), float(_def.get("burn_duration", 8.0)))


func _process(delta: float) -> void:
	_elapsed += delta
	# Scenario-only death trigger (capture tooling; there is no debug key for it).
	if not _kill_done and _def.has("kill_player_at") and _elapsed >= float(_def["kill_player_at"]):
		_kill_done = true
		var player: Player = _main.get_node("Player")
		player.health.take_damage(player.health.get_max_health() * 2.0, "physical")
	var late: Dictionary = _def.get("late_hit", {})
	if late.is_empty() or _late_hit_done or _elapsed < float(late.get("at", 2.4)):
		return
	_late_hit_done = true
	for hit_index: int in late.get("indices", []):
		if hit_index < _enemies.size() and is_instance_valid(_enemies[hit_index]):
			_enemies[hit_index].health.take_damage(float(late.get("amount", 5.0)), "physical")
