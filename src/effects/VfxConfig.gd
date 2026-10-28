class_name VfxConfig
extends RefCounted
## data/vfx.json: tuning for the pooled effect system. Missing or invalid values
## fall back to DEFAULTS (with a push_error for invalid ones, never a crash).

const PATH := "res://data/vfx.json"
const DEFAULTS: Dictionary = {
	"max_simultaneous": 48,
	"hurtbox_reach_radius": 0.45,
}

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Returns human-readable problems; empty means valid.
static func validate(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var cap: Variant = config.get("max_simultaneous")
	if typeof(cap) != TYPE_INT and typeof(cap) != TYPE_FLOAT:
		errors.append("'max_simultaneous' must be a number")
	elif float(cap) < 1.0 or float(cap) > 512.0 or float(cap) != floorf(float(cap)):
		errors.append("'max_simultaneous' must be a whole number from 1 to 512")
	var reach: Variant = config.get("hurtbox_reach_radius")
	if typeof(reach) != TYPE_INT and typeof(reach) != TYPE_FLOAT:
		errors.append("'hurtbox_reach_radius' must be a number")
	elif float(reach) < 0.0 or float(reach) > 5.0:
		errors.append("'hurtbox_reach_radius' must be between 0 and 5")
	return errors


static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = DEFAULTS.duplicate()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("VfxConfig: could not open " + PATH)
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("VfxConfig: %s is not a JSON object" % PATH)
		return _cache
	var errors := validate(parsed)
	if not errors.is_empty():
		push_error("VfxConfig: invalid %s: %s" % [PATH, "; ".join(errors)])
		return _cache
	_cache.merge(parsed, true)
	return _cache


## How far past a hit query's range a target's centre can still be hit: the
## target hurtbox radius (MeleeChaser capsule, 0.45). See VfxSizing.
static func hurtbox_reach_radius() -> float:
	return float(get_config()["hurtbox_reach_radius"])


static func max_simultaneous() -> int:
	return int(get_config()["max_simultaneous"])
