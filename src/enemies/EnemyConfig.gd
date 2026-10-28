class_name EnemyConfig
extends RefCounted
## data/enemies.json: attack shape numbers shared by every enemy type, plus each enemy
## type's rank and scene (the per-type combat stats are still exported scene values).
## A missing or invalid file is a push_error and falls back to DEFAULTS.

const PATH := "res://data/enemies.json"
## Enemy ranks: normal enemies take full status effects, elites reduced, bosses
## are immune to some (a stun's rank_multipliers in data/statuses.json decide).
const RANKS: Array[String] = ["normal", "elite", "boss"]
const DEFAULT_RANK := "normal"
const DEFAULTS: Dictionary = {
	"projectile_hit_radius": 0.3,
	"melee_half_angle_degrees": 60.0,
}

static var _cache: Dictionary = {}
static var _loaded: bool = false
## enemy id -> rank, from data/enemies.json "enemies".
static var _ranks: Dictionary = {}
## enemy id -> scene path, from data/enemies.json "enemies" (the wave table spawns by id).
static var _scenes: Dictionary = {}


## Returns human-readable problems; empty means valid.
static func validate(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_enemies(config.get("enemies")))
	var shapes: Variant = config.get("attack_shapes")
	if typeof(shapes) != TYPE_DICTIONARY:
		errors.append("'attack_shapes' must be an object")
		return errors
	var dict: Dictionary = shapes
	_check_number(dict, "projectile_hit_radius", 0.0, 5.0, true, errors)
	_check_number(dict, "melee_half_angle_degrees", 0.0, 180.0, true, errors)
	return errors


## Per-enemy data: each id maps to an object with a known "rank".
static func validate_enemies(enemies: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(enemies) != TYPE_DICTIONARY:
		errors.append("'enemies' must be an object (enemy id -> {rank})")
		return errors
	for enemy_id: String in (enemies as Dictionary).keys():
		var entry: Variant = (enemies as Dictionary)[enemy_id]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("enemies.%s must be an object" % enemy_id)
			continue
		var entry_dict: Dictionary = entry
		if typeof(entry_dict.get("rank")) != TYPE_STRING or not RANKS.has(String(entry_dict["rank"])):
			errors.append("enemies.%s: 'rank' must be one of %s" % [enemy_id, str(RANKS)])
		var scene_path: Variant = entry_dict.get("scene")
		if typeof(scene_path) != TYPE_STRING or not String(scene_path).begins_with("res://") or not ResourceLoader.exists(String(scene_path)):
			errors.append("enemies.%s: 'scene' must be an existing res:// scene path" % enemy_id)
		elif not _scene_root_is_enemy(String(scene_path)):
			errors.append("enemies.%s: scene '%s' must have an Enemy (src/enemies/Enemy.gd) as its root" % [enemy_id, String(scene_path)])
	return errors


## True if the scene's root node carries a script that is, or extends, the global class Enemy. Reads
## the packed scene state only (no instancing, and no reference to the Enemy class: it would pull in the
## Juice autoload and break `-s` tools, see S5-1).
static func _scene_root_is_enemy(path: String) -> bool:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	var state: SceneState = packed.get_state()
	if state.get_node_count() == 0:
		return false
	var script: Script = null
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == "script":
			script = state.get_node_property_value(0, i) as Script
	while script != null:
		if script.get_global_name() == &"Enemy":
			return true
		script = script.get_base_script()
	return false


static func _check_number(dict: Dictionary, key: String, low: float, high: float, exclusive_low: bool, errors: Array[String]) -> void:
	var value: Variant = dict.get(key)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		errors.append("'%s' must be a number" % key)
		return
	var number: float = float(value)
	if is_nan(number) or number > high or number < low or (exclusive_low and number == low):
		errors.append("'%s' must be > %s and <= %s" % [key, low, high])


static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = DEFAULTS.duplicate()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("EnemyConfig: could not open " + PATH)
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EnemyConfig: %s is not a JSON object" % PATH)
		return _cache
	var errors := validate(parsed)
	if not errors.is_empty():
		push_error("EnemyConfig: invalid %s: %s" % [PATH, "; ".join(errors)])
		return _cache
	_cache.merge(parsed["attack_shapes"], true)
	for enemy_id: String in (parsed["enemies"] as Dictionary).keys():
		_ranks[enemy_id] = String(parsed["enemies"][enemy_id]["rank"])
		_scenes[enemy_id] = String(parsed["enemies"][enemy_id]["scene"])
	return _cache


## Rank of an enemy type (data/enemies.json). An unknown id is an error and counts as normal.
static func rank_for(enemy_id: String) -> String:
	get_config()
	if not _ranks.has(enemy_id):
		push_error("EnemyConfig: enemy id '%s' has no entry in data/enemies.json 'enemies'" % enemy_id)
		return DEFAULT_RANK
	return String(_ranks[enemy_id])


## Scene path of an enemy type, or "" (with an error) if the id is unknown.
static func scene_path_for(enemy_id: String) -> String:
	get_config()
	if not _scenes.has(enemy_id):
		push_error("EnemyConfig: enemy id '%s' has no scene in data/enemies.json 'enemies'" % enemy_id)
		return ""
	return String(_scenes[enemy_id])


## Every enemy id in data/enemies.json (empty if the file was invalid).
static func enemy_ids() -> Array[String]:
	get_config()
	var ids: Array[String] = []
	for key: Variant in _scenes.keys():
		ids.append(String(key))
	return ids


static func projectile_hit_radius() -> float:
	return float(get_config()["projectile_hit_radius"])


static func melee_half_angle_degrees() -> float:
	return float(get_config()["melee_half_angle_degrees"])
