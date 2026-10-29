class_name PlayerConfig
extends RefCounted
## data/player.json: player tuning that is not a card or attack. Today the dodge roll.
## dodge.speed x dodge.duration is the roll distance in metres (20 x 0.25 = 5.0 m). A missing or
## invalid file push_errors and falls back to DEFAULTS (never a crash).

const PATH := "res://data/player.json"
const DEFAULTS: Dictionary = {
	"dodge": {"speed": 20.0, "duration": 0.25, "cooldown": 0.8, "block_ticks_after_pause": 2},
}
## key -> [min, max, must_be_integer]
const DODGE_RULES: Dictionary = {
	"speed": [0.1, 200.0, false],
	"duration": [0.02, 5.0, false],
	"cooldown": [0.0, 60.0, false],
	"block_ticks_after_pause": [0.0, 30.0, true],
}

static var _cache: Dictionary = {}


## The validated dodge block: speed, duration, cooldown (floats) and block_ticks_after_pause (int).
static func dodge() -> Dictionary:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return _cache["dodge"]


static func reload() -> void:
	_cache = {}


static func load_from(path: String) -> Dictionary:
	var text: Variant = SettingsStore.read_text_file(path)
	if text == null:
		push_error("PlayerConfig: could not open '%s'; using defaults" % path)
		return DEFAULTS.duplicate(true)
	var parsed: Variant = JSON.parse_string(String(text))
	var problems := validate(parsed)
	if not problems.is_empty():
		push_error("PlayerConfig: '%s' invalid: %s; using defaults" % [path, "; ".join(problems)])
		return DEFAULTS.duplicate(true)
	return parsed as Dictionary


## Human-readable problems; empty means valid.
static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("not a JSON object")
		return errors
	var block: Variant = (data as Dictionary).get("dodge")
	if typeof(block) != TYPE_DICTIONARY:
		errors.append("'dodge' must be an object")
		return errors
	for key: String in DODGE_RULES.keys():
		var value: Variant = (block as Dictionary).get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			errors.append("dodge.%s must be a number" % key)
			continue
		var rule: Array = DODGE_RULES[key]
		var number: float = float(value)
		if is_nan(number) or is_inf(number) or number < float(rule[0]) or number > float(rule[1]):
			errors.append("dodge.%s must be between %s and %s" % [key, rule[0], rule[1]])
		elif bool(rule[2]) and number != floorf(number):
			errors.append("dodge.%s must be a whole number" % key)
	for key: Variant in (block as Dictionary).keys():
		if not DODGE_RULES.has(String(key)):
			errors.append("dodge.%s is not a known key" % key)
	return errors
