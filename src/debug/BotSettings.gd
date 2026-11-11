class_name BotSettings
extends RefCounted
## SIM1: the sim bot's human-like settings, read from data/bot_presets.json. All zero = the perfect bot (the shipped sim hashes).
## `reaction_delay` (s) lags everything the bot does; `aim_error_degrees` is the half-width of a random aim offset, re-rolled every
## `aim_resample` s; `cast_hesitation` (s) is an extra random 0..value wait before a card slot press.

const PATH := "res://data/bot_presets.json"
const OFF := "off"
const FIELDS: Array[String] = ["reaction_delay", "aim_error_degrees", "cast_hesitation", "aim_resample"]
const MAX_DELAY := 2.0
const MAX_ERROR := 90.0

var preset_name: String = OFF
var reaction_delay: float = 0.0
var aim_error_degrees: float = 0.0
var cast_hesitation: float = 0.0
var aim_resample: float = 0.35


## True when any setting changes the bot (the off preset is inactive, so the sim takes its unchanged code path).
func is_active() -> bool:
	return reaction_delay > 0.0 or aim_error_degrees > 0.0 or cast_hesitation > 0.0


static func _read(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Problems with a whole presets file (empty = fine). Fails loudly: a bad number or a missing 'off' is an error, never a silent default.
static func validate_file(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not (data.get("presets") is Dictionary):
		problems.append("bot presets: missing the 'presets' object")
		return problems
	var presets: Dictionary = data["presets"]
	if not presets.has(OFF):
		problems.append("bot presets: the '%s' preset is required" % OFF)
	for key: Variant in presets.keys():
		if not (presets[key] is Dictionary):
			problems.append("bot presets: '%s' must be an object" % str(key))
			continue
		problems.append_array(validate_preset(str(key), presets[key] as Dictionary))
	var default_name: String = String(data.get("default", OFF))
	if default_name != "" and not presets.has(default_name):
		problems.append("bot presets: default '%s' is not a preset" % default_name)
	return problems


static func validate_preset(preset_id: String, preset: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in FIELDS:
		if not preset.has(field):
			problems.append("bot preset '%s': missing '%s'" % [preset_id, field])
			continue
		if not (preset[field] is float or preset[field] is int):
			problems.append("bot preset '%s': '%s' must be a number" % [preset_id, field])
			continue
		var value: float = float(preset[field])
		if is_nan(value) or value < 0.0:
			problems.append("bot preset '%s': '%s' must be 0 or more (got %s)" % [preset_id, field, str(value)])
		elif (field == "reaction_delay" or field == "cast_hesitation") and value > MAX_DELAY:
			problems.append("bot preset '%s': '%s' above %.1f s is not a human" % [preset_id, field, MAX_DELAY])
		elif field == "aim_error_degrees" and value > MAX_ERROR:
			problems.append("bot preset '%s': 'aim_error_degrees' above %.0f is not an aim" % [preset_id, MAX_ERROR])
		elif field == "aim_resample" and value <= 0.0:
			problems.append("bot preset '%s': 'aim_resample' must be above 0" % preset_id)
	for key: Variant in preset.keys():
		if not FIELDS.has(str(key)):
			problems.append("bot preset '%s': unknown field '%s'" % [preset_id, str(key)])
	return problems


## The preset names in the file, sorted.
static func names(path: String = PATH) -> Array[String]:
	var result: Array[String] = []
	var data: Dictionary = _read(path)
	if data.get("presets") is Dictionary:
		for key: Variant in (data["presets"] as Dictionary).keys():
			result.append(str(key))
	result.sort()
	return result


## Loads a preset by name ("" = the file's default). Returns {"settings": BotSettings or null, "problems": Array[String]}.
## An unknown name or a bad file gives a clear problem list and a null settings.
static func load_named(preset: String, path: String = PATH) -> Dictionary:
	var data: Dictionary = _read(path)
	var problems: Array[String] = validate_file(data)
	if not problems.is_empty():
		return {"settings": null, "problems": problems}
	var chosen: String = preset if preset != "" else String(data.get("default", OFF))
	var presets: Dictionary = data["presets"]
	if not presets.has(chosen):
		problems.append("unknown bot preset '%s' (valid: %s)" % [chosen, ", ".join(names(path))])
		return {"settings": null, "problems": problems}
	var values: Dictionary = presets[chosen]
	var settings := BotSettings.new()
	settings.preset_name = chosen
	settings.reaction_delay = float(values["reaction_delay"])
	settings.aim_error_degrees = float(values["aim_error_degrees"])
	settings.cast_hesitation = float(values["cast_hesitation"])
	settings.aim_resample = float(values["aim_resample"])
	return {"settings": settings, "problems": problems}


## Settings from explicit numbers (the sweep: --bot-delay= and --bot-aim-error= override the preset).
static func custom(delay: float, error_degrees: float, hesitation: float = 0.0) -> BotSettings:
	var settings := BotSettings.new()
	settings.preset_name = "custom"
	settings.reaction_delay = maxf(delay, 0.0)
	settings.aim_error_degrees = maxf(error_degrees, 0.0)
	settings.cast_hesitation = maxf(hesitation, 0.0)
	return settings
