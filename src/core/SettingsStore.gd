class_name SettingsStore
extends RefCounted
## Player settings: defaults from data/settings.json, user overrides from a ConfigFile
## (user://settings.cfg in play). Pure logic with injectable paths, so tests never touch
## the real user file. Validated: a bad defaults file or a bad user file is never fatal;
## every problem is collected in `problems` (the Settings autoload push_errors them) and
## the affected values fall back to the defaults.
##
## Definitions are data: {key: {type: "enum"|"bool", default, options (enum), label,
## option_labels}}. set_value() changes memory and emits `changed`; it never writes the
## file. Call save() when the player confirms (so a test or a tool cannot overwrite a
## real settings file by flipping a value).

signal changed(key: String, value: Variant)

const DEFAULTS_PATH := "res://data/settings.json"
const USER_PATH := "user://settings.cfg"
const SECTION := "settings"
const TYPES: Array[String] = ["enum", "bool"]

var defaults_path: String
var user_path: String
## Everything wrong with the files at the last load_all() (empty = clean).
var problems: Array[String] = []

var _definitions: Dictionary = {}
var _values: Dictionary = {}


func _init(p_defaults_path: String = DEFAULTS_PATH, p_user_path: String = USER_PATH) -> void:
	defaults_path = p_defaults_path
	user_path = p_user_path
	load_all()


## Reads the defaults then the user file. Returns the problems found (also kept in `problems`).
func load_all() -> Array[String]:
	problems = []
	_definitions = {}
	_values = {}
	var defs_text: Variant = read_text_file(defaults_path)
	if defs_text == null:
		problems.append("settings defaults '%s' could not be opened" % defaults_path)
		return problems
	var parsed: Variant = JSON.parse_string(String(defs_text))
	if typeof(parsed) != TYPE_DICTIONARY:
		problems.append("settings defaults '%s' is not a JSON object" % defaults_path)
		return problems
	var defs: Dictionary = parsed
	problems.append_array(validate_definitions(defs))
	for key: String in defs.keys():
		if _definition_problems(key, defs[key]).is_empty():
			_definitions[key] = defs[key]
			_values[key] = (defs[key] as Dictionary)["default"]
	_load_user_file()
	return problems


static func validate_definitions(defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in defs.keys():
		out.append_array(_definition_problems(key, defs[key]))
	return out


static func _definition_problems(key: String, def: Variant) -> Array[String]:
	var out: Array[String] = []
	var where := "settings key '%s'" % key
	if typeof(def) != TYPE_DICTIONARY:
		out.append("%s must be an object" % where)
		return out
	var d: Dictionary = def
	var type_id := String(d.get("type", ""))
	if not TYPES.has(type_id):
		out.append("%s has unknown type '%s' (use %s)" % [where, type_id, str(TYPES)])
		return out
	if not d.has("default"):
		out.append("%s has no default" % where)
		return out
	if type_id == "bool":
		if typeof(d["default"]) != TYPE_BOOL:
			out.append("%s default must be true or false" % where)
	else:
		var options: Variant = d.get("options")
		if typeof(options) != TYPE_ARRAY or (options as Array).is_empty():
			out.append("%s needs a non-empty options list" % where)
		else:
			for option: Variant in options:
				if typeof(option) != TYPE_STRING or String(option).is_empty():
					out.append("%s options must be non-empty strings" % where)
					break
			if not (options as Array).has(d["default"]):
				out.append("%s default '%s' is not one of its options" % [where, str(d["default"])])
	return out


## "" when `value` is acceptable for `key`, otherwise the reason.
func value_problem(key: String, value: Variant) -> String:
	if not _definitions.has(key):
		return "unknown setting '%s'" % key
	var def: Dictionary = _definitions[key]
	if def["type"] == "bool":
		return "" if typeof(value) == TYPE_BOOL else "setting '%s' must be true or false, got %s" % [key, str(value)]
	if typeof(value) == TYPE_STRING and (def["options"] as Array).has(value):
		return ""
	return "setting '%s' must be one of %s, got %s" % [key, str(def["options"]), str(value)]


func has_key(key: String) -> bool:
	return _definitions.has(key)


func keys() -> Array[String]:
	var out: Array[String] = []
	for key: String in _definitions.keys():
		out.append(key)
	return out


## The data definition (type, options, label, option_labels) for building UI. A copy.
func get_definition(key: String) -> Dictionary:
	return (_definitions.get(key, {}) as Dictionary).duplicate(true)


func get_default(key: String) -> Variant:
	return (_definitions[key] as Dictionary)["default"] if _definitions.has(key) else null


func get_value(key: String) -> Variant:
	if not _values.has(key):
		push_error("SettingsStore: unknown setting '%s'" % key)
		return null
	return _values[key]


func get_string(key: String) -> String:
	return String(get_value(key))


func get_bool(key: String) -> bool:
	return bool(get_value(key))


## Sets a value in memory and emits `changed` when it actually changes. Returns false
## (and changes nothing) for an unknown key or an invalid value. Does NOT save.
func set_value(key: String, value: Variant) -> bool:
	if not value_problem(key, value).is_empty():
		return false
	if _values[key] != value:
		_values[key] = value
		changed.emit(key, value)
	return true


## Back to the data defaults (in memory; emits changed per key that moved). Does not save.
func reset_to_defaults() -> void:
	for key: String in _definitions.keys():
		set_value(key, (_definitions[key] as Dictionary)["default"])


## Writes the current values to the user file. Returns false if it could not be written
## (the caller decides how loud to be).
func save() -> bool:
	var config := ConfigFile.new()
	for key: String in _values.keys():
		config.set_value(SECTION, key, _values[key])
	return config.save(user_path) == OK


func _load_user_file() -> void:
	var text: Variant = read_text_file(user_path)
	if text == null:
		return  # No user file yet: defaults.
	var config_problem := _config_text_problem(String(text))
	if not config_problem.is_empty():
		problems.append("settings file '%s' is unreadable (%s); using the defaults" % [user_path, config_problem])
		return
	var config := ConfigFile.new()
	if config.parse(String(text)) != OK:
		problems.append("settings file '%s' could not be parsed; using the defaults" % user_path)
		return
	if not config.has_section(SECTION):
		return
	for key: String in config.get_section_keys(SECTION):
		var value: Variant = config.get_value(SECTION, key)
		if not _definitions.has(key):
			problems.append("settings file '%s' has unknown setting '%s'; ignored" % [user_path, key])
			continue
		var reason := value_problem(key, value)
		if reason.is_empty():
			_values[key] = value
		else:
			problems.append("settings file '%s': %s; using the default" % [user_path, reason])


## ConfigFile.parse prints an engine error on garbage; this cheap line check finds the
## obvious cases first so a bad file is reported once, by us.
static func _config_text_problem(text: String) -> String:
	var line_number := 0
	for raw: String in text.split("\n"):
		line_number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			continue
		var equals := line.find("=")
		if equals > 0 and line.substr(0, equals).strip_edges().is_valid_identifier() and line.length() > equals + 1:
			continue
		return "line %d is not a section or key=value" % line_number
	return ""


static func read_text_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return file.get_as_text()
