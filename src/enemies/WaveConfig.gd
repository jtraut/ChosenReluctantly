class_name WaveConfig
extends RefCounted
## data/waves.json: the wave table and the simultaneous-enemy cap (Slice 5a).
## Pure data loader and validator. A missing or invalid file is a push_error and
## falls back to DEFAULTS (one small wave loop), never a crash.
##
## Shape: global numbers (max_alive, first_wave_delay, spawn_attack_grace,
## spawn_gap, spawn_distance_min/max, arena_half_extent, loop_from_stage) and
## "stages": ordered objects {delay, until_alive_at_most (optional), spawns:
## [{enemy, count}]}. Enemy ids are keys of data/enemies.json "enemies".

const PATH := "res://data/waves.json"
## GDD density principle / ROADMAP Slice 5 criterion 1: about 6 to 15 at once.
const MAX_ALIVE_MIN := 6
const MAX_ALIVE_MAX := 15
## Inner face of the arena walls in scenes/main/Main.tscn (the ArenaWalls boxes). A test keeps this
## equal to the scene. `arena_half_extent` may not exceed it minus a clearance for an enemy's body (S5-3).
const WALL_INNER_HALF_EXTENT := 20.0
const WALL_CLEARANCE := 0.5

const DEFAULTS: Dictionary = {
	"max_alive": 8,
	"first_wave_delay": 3.0,
	"spawn_attack_grace": 1.5,
	"spawn_gap": 0.5,
	"spawn_distance_min": 9.0,
	"spawn_distance_max": 13.0,
	"arena_half_extent": 19.0,
	"loop_from_stage": 0,
	"stages": [
		{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 2}]},
	],
}

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Returns human-readable problems; empty means valid. `known_enemies` is the set of
## valid enemy ids (data/enemies.json); an empty array skips the id check.
static func validate(config: Dictionary, known_enemies: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var max_alive_value: Variant = config.get("max_alive")
	if typeof(max_alive_value) != TYPE_INT and typeof(max_alive_value) != TYPE_FLOAT:
		errors.append("'max_alive' must be a number")
	elif float(max_alive_value) != floorf(float(max_alive_value)) or int(max_alive_value) < MAX_ALIVE_MIN or int(max_alive_value) > MAX_ALIVE_MAX:
		errors.append("'max_alive' must be a whole number in [%d, %d]" % [MAX_ALIVE_MIN, MAX_ALIVE_MAX])
	_check_number(config, "first_wave_delay", 0.0, 120.0, errors)
	_check_number(config, "spawn_attack_grace", 0.0, 10.0, errors)
	_check_number(config, "spawn_gap", 0.0, 10.0, errors)
	_check_number(config, "spawn_distance_min", 1.0, 60.0, errors)
	_check_number(config, "spawn_distance_max", 1.0, 60.0, errors)
	_check_number(config, "arena_half_extent", 5.0, WALL_INNER_HALF_EXTENT - WALL_CLEARANCE, errors)
	if errors.is_empty() and float(config["spawn_distance_max"]) < float(config["spawn_distance_min"]):
		errors.append("'spawn_distance_max' must be >= 'spawn_distance_min'")
	var stages_value: Variant = config.get("stages")
	if typeof(stages_value) != TYPE_ARRAY or (stages_value as Array).is_empty():
		errors.append("'stages' must be a non-empty array")
		return errors
	var stage_list: Array = stages_value
	var loop_from: Variant = config.get("loop_from_stage")
	if typeof(loop_from) != TYPE_INT and typeof(loop_from) != TYPE_FLOAT:
		errors.append("'loop_from_stage' must be a number")
	elif float(loop_from) < 0.0 or float(loop_from) >= float(stage_list.size()) or float(loop_from) != floorf(float(loop_from)):
		errors.append("'loop_from_stage' must be a stage index in [0, %d]" % (stage_list.size() - 1))
	var cap: int = MAX_ALIVE_MAX
	if typeof(max_alive_value) == TYPE_INT or typeof(max_alive_value) == TYPE_FLOAT:
		cap = int(max_alive_value)
	for i in range(stage_list.size()):
		errors.append_array(_validate_stage(i, stage_list[i], known_enemies, cap))
	return errors


static func _validate_stage(index: int, stage: Variant, known_enemies: Array[String], cap: int) -> Array[String]:
	var errors: Array[String] = []
	var label := "stages[%d]" % index
	if typeof(stage) != TYPE_DICTIONARY:
		errors.append("%s must be an object" % label)
		return errors
	var dict: Dictionary = stage
	var delay: Variant = dict.get("delay")
	if (typeof(delay) != TYPE_INT and typeof(delay) != TYPE_FLOAT) or is_nan(float(delay)) or float(delay) < 0.0 or float(delay) > 600.0:
		errors.append("%s: 'delay' must be a number in [0, 600]" % label)
	if dict.has("until_alive_at_most"):
		var gate: Variant = dict["until_alive_at_most"]
		if (typeof(gate) != TYPE_INT and typeof(gate) != TYPE_FLOAT) or float(gate) < 0.0 or float(gate) > float(MAX_ALIVE_MAX):
			errors.append("%s: 'until_alive_at_most' must be a number in [0, %d]" % [label, MAX_ALIVE_MAX])
	var spawns: Variant = dict.get("spawns")
	if typeof(spawns) != TYPE_ARRAY or (spawns as Array).is_empty():
		errors.append("%s: 'spawns' must be a non-empty array" % label)
		return errors
	var total: int = 0
	for entry: Variant in (spawns as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s: each spawn must be an object {enemy, count}" % label)
			continue
		var spawn: Dictionary = entry
		if typeof(spawn.get("enemy")) != TYPE_STRING or (not known_enemies.is_empty() and not known_enemies.has(String(spawn["enemy"]))):
			errors.append("%s: 'enemy' must be an id from data/enemies.json (got %s)" % [label, str(spawn.get("enemy"))])
		var count: Variant = spawn.get("count")
		if (typeof(count) != TYPE_INT and typeof(count) != TYPE_FLOAT) or float(count) < 1.0 or float(count) > 30.0 or float(count) != floorf(float(count)):
			errors.append("%s: 'count' must be a whole number in [1, 30]" % label)
		else:
			total += int(count)
	if total > cap:
		errors.append("%s: spawns %d enemies, more than max_alive %d (it could never finish)" % [label, total, cap])
	return errors


static func _check_number(dict: Dictionary, key: String, low: float, high: float, errors: Array[String]) -> void:
	var value: Variant = dict.get(key)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		errors.append("'%s' must be a number" % key)
		return
	var number: float = float(value)
	if is_nan(number) or number > high or number < low:
		errors.append("'%s' must be in [%s, %s]" % [key, low, high])


static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = DEFAULTS.duplicate(true)
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("WaveConfig: could not open " + PATH)
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("WaveConfig: %s is not a JSON object" % PATH)
		return _cache
	var errors := validate(parsed, EnemyConfig.enemy_ids())
	if not errors.is_empty():
		push_error("WaveConfig: invalid %s: %s" % [PATH, "; ".join(errors)])
		return _cache
	_cache = (parsed as Dictionary).duplicate(true)
	return _cache


static func max_alive() -> int:
	return int(get_config()["max_alive"])
