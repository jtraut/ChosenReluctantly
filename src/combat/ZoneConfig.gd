class_name ZoneConfig
extends RefCounted
## data/zones.json: limits for the zone template. `max_live` is the most zones alive at once in a
## world; placing one more ends the oldest (like the effect pool's cap). A missing or invalid file
## push_errors and falls back to DEFAULTS (never a crash).

const PATH := "res://data/zones.json"
const DEFAULTS: Dictionary = {"max_live": 6}
const MAX_LIVE_LIMIT := 64

static var _cache: Dictionary = {}


static func max_live() -> int:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return int(_cache["max_live"])


static func reload() -> void:
	_cache = {}


static func load_from(path: String) -> Dictionary:
	var text: Variant = SettingsStore.read_text_file(path)
	if text == null:
		push_error("ZoneConfig: could not open '%s'; using defaults" % path)
		return DEFAULTS.duplicate(true)
	var parsed: Variant = JSON.parse_string(String(text))
	var problems := validate(parsed)
	if not problems.is_empty():
		push_error("ZoneConfig: '%s' invalid: %s; using defaults" % [path, "; ".join(problems)])
		return DEFAULTS.duplicate(true)
	return parsed as Dictionary


## Human-readable problems; empty means valid.
static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("not a JSON object")
		return errors
	var dict: Dictionary = data
	var value: Variant = dict.get("max_live")
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		errors.append("max_live must be a number")
	elif is_nan(float(value)) or float(value) < 1.0 or float(value) > float(MAX_LIVE_LIMIT) or float(value) != floorf(float(value)):
		errors.append("max_live must be a whole number from 1 to %d" % MAX_LIVE_LIMIT)
	for key: Variant in dict.keys():
		if String(key) != "max_live":
			errors.append("%s is not a known key" % str(key))
	return errors
