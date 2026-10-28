class_name EnemyConfig
extends RefCounted
## data/enemies.json: attack shape numbers shared by every enemy type (the per-type
## stats are still exported scene values; there is no per-enemy data table yet).
## A missing or invalid file is a push_error and falls back to DEFAULTS.

const PATH := "res://data/enemies.json"
const DEFAULTS: Dictionary = {
	"projectile_hit_radius": 0.3,
	"melee_half_angle_degrees": 60.0,
}

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Returns human-readable problems; empty means valid.
static func validate(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var shapes: Variant = config.get("attack_shapes")
	if typeof(shapes) != TYPE_DICTIONARY:
		errors.append("'attack_shapes' must be an object")
		return errors
	var dict: Dictionary = shapes
	_check_number(dict, "projectile_hit_radius", 0.0, 5.0, true, errors)
	_check_number(dict, "melee_half_angle_degrees", 0.0, 180.0, true, errors)
	return errors


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
	return _cache


static func projectile_hit_radius() -> float:
	return float(get_config()["projectile_hit_radius"])


static func melee_half_angle_degrees() -> float:
	return float(get_config()["melee_half_angle_degrees"])
