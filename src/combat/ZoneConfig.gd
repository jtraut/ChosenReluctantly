class_name ZoneConfig
extends RefCounted
## data/zones.json: limits for the zone template. `max_live` is the most zones alive at once in a
## world; placing one more ends the oldest (like the effect pool's cap). A missing or invalid file
## push_errors and falls back to DEFAULTS (never a crash).

const PATH := "res://data/zones.json"
## `look` is how a zone is drawn (never what it hits: sizes come from VfxSizing). Alphas 0..1, times in seconds,
## fractions of the zone's life 0..1. fill_alpha -> fill_alpha_end fades over the life; tick_flash_* lights the fill on
## every damage tick; `timer_*` is the burn-down bar inside the zone (it empties as the zone runs out); during the last
## `ending_fraction` of the life the outline blinks at `ending_blink_hz`.
const LOOK_RULES: Dictionary = {
	"fill_alpha": [0.0, 1.0], "fill_alpha_end": [0.0, 1.0], "edge_alpha": [0.0, 1.0], "tick_flash_time": [0.01, 5.0], "tick_flash_boost": [0.0, 1.0],
	"timer_alpha": [0.0, 1.0], "timer_lighten": [0.0, 1.0], "timer_width": [0.02, 2.0], "timer_circle_scale": [0.05, 1.0],
	"ending_fraction": [0.0, 1.0], "ending_blink_hz": [0.1, 20.0], "ending_blink_min_alpha": [0.0, 1.0],
}
const DEFAULT_LOOK: Dictionary = {
	"fill_alpha": 0.3, "fill_alpha_end": 0.12, "edge_alpha": 0.85, "tick_flash_time": 0.12, "tick_flash_boost": 0.25,
	"timer_alpha": 0.6, "timer_lighten": 0.5, "timer_width": 0.12, "timer_circle_scale": 0.5,
	"ending_fraction": 0.25, "ending_blink_hz": 4.0, "ending_blink_min_alpha": 0.25,
}
const DEFAULTS: Dictionary = {"max_live": 6, "look": DEFAULT_LOOK}
const MAX_LIVE_LIMIT := 64

static var _cache: Dictionary = {}


static func max_live() -> int:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return int(_cache["max_live"])


## The zone look block (see LOOK_RULES), every key present.
static func look() -> Dictionary:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return _cache["look"]


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
	var loaded: Dictionary = (parsed as Dictionary).duplicate(true)
	var merged_look: Dictionary = DEFAULT_LOOK.duplicate()
	merged_look.merge(loaded.get("look", {}), true)
	loaded["look"] = merged_look
	return loaded


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
	if dict.has("look"):
		if typeof(dict["look"]) != TYPE_DICTIONARY:
			errors.append("look must be an object")
		else:
			var look_block: Dictionary = dict["look"]
			for key: Variant in look_block.keys():
				if not LOOK_RULES.has(String(key)):
					errors.append("look.%s is not a known key" % str(key))
					continue
				var number: Variant = look_block[key]
				var range_: Array = LOOK_RULES[String(key)]
				if (typeof(number) != TYPE_FLOAT and typeof(number) != TYPE_INT) or is_nan(float(number)) or float(number) < float(range_[0]) or float(number) > float(range_[1]):
					errors.append("look.%s must be a number from %s to %s" % [str(key), str(range_[0]), str(range_[1])])
	for key: Variant in dict.keys():
		if String(key) != "max_live" and String(key) != "look":
			errors.append("%s is not a known key" % str(key))
	return errors
