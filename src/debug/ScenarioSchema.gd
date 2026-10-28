class_name ScenarioSchema
extends RefCounted
## Schema for one scenario definition in data/scenarios.json (capture and test tooling).
## Pure functions: they return problem strings (empty = valid) and never touch the scene,
## so a bad flag fails loudly with a clear message instead of an index error mid-build.
## An unknown key is a problem too (it catches typos such as "aim_point_ofset").

const BOOLS: Array[String] = ["disable_spawner", "freeze_aim", "enemies_idle", "disable_auto_attack", "dense_waves"]
## key -> minimum (inclusive) for a finite number.
const NUMBERS: Dictionary = {
	"player_max_health": 1.0, "player_start_damage": 0.0, "aim_preview_distance": 0.0,
	"enemy_max_health": 1.0, "burn_duration": 0.01, "heavy_at": 0.0, "kill_player_at": 0.0,
	"stun_at": 0.0, "stun_duration": 0.01,
}
## key -> minimum (inclusive) for a whole number.
const INTS: Dictionary = {"columns": 1, "status_seed": -2147483647, "wave_seed": 0}
const STRINGS: Array[String] = ["heavy_class"]
## key -> exact number of finite numbers in the array.
const NUMBER_ARRAYS: Dictionary = {"origin_offset": 3, "spacing": 2, "aim_point_offset": 2}
const INDEX_ARRAYS: Array[String] = ["burn_indices", "stun_indices", "boss_indices"]


static func validate(scenario_id: String, def: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(def) != TYPE_DICTIONARY:
		problems.append("scenario '%s' must be an object" % scenario_id)
		return problems
	var dict: Dictionary = def
	for key: Variant in dict.keys():
		var name := String(key)
		var where := "scenario '%s' key '%s'" % [scenario_id, name]
		var value: Variant = dict[key]
		if BOOLS.has(name):
			if typeof(value) != TYPE_BOOL:
				problems.append("%s must be true or false" % where)
		elif NUMBERS.has(name):
			if not _is_number(value) or float(value) < float(NUMBERS[name]):
				problems.append("%s must be a finite number >= %s" % [where, NUMBERS[name]])
		elif INTS.has(name):
			if not _is_whole(value) or int(value) < int(INTS[name]):
				problems.append("%s must be a whole number >= %s" % [where, INTS[name]])
		elif STRINGS.has(name):
			if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
				problems.append("%s must be a non-empty string" % where)
		elif NUMBER_ARRAYS.has(name):
			problems.append_array(_number_array(where, value, int(NUMBER_ARRAYS[name])))
		elif INDEX_ARRAYS.has(name):
			problems.append_array(_index_array(where, value))
		elif name == "hp_fractions":
			problems.append_array(_fractions(where, value))
		elif name == "groups":
			problems.append_array(_groups(where, value))
		elif name == "late_hit":
			problems.append_array(_late_hit(where, value))
		elif name == "casts":
			problems.append_array(_casts(where, value))
		elif name == "previews":
			problems.append_array(_previews(where, value))
		else:
			problems.append("%s is not a known scenario flag" % where)
	return problems


static func _is_number(value: Variant) -> bool:
	var kind := typeof(value)
	return (kind == TYPE_FLOAT or kind == TYPE_INT) and is_finite(float(value))


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and is_equal_approx(float(value), roundf(float(value)))


static func _number_array(where: String, value: Variant, length: int) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s must be an array of %d numbers" % [where, length])
		return problems
	var values: Array = value
	if values.size() != length:
		problems.append("%s must have exactly %d numbers, got %d" % [where, length, values.size()])
	for item: Variant in values:
		if not _is_number(item):
			problems.append("%s has a non-number or non-finite entry" % where)
			break
	return problems


static func _index_array(where: String, value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s must be an array of enemy indexes" % where)
		return problems
	for item: Variant in value as Array:
		if not _is_whole(item) or int(item) < 0:
			problems.append("%s must hold whole numbers >= 0" % where)
			break
	return problems


static func _fractions(where: String, value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s must be an array of numbers from 0 to 1" % where)
		return problems
	for item: Variant in value as Array:
		if not _is_number(item) or float(item) < 0.0 or float(item) > 1.0:
			problems.append("%s must hold numbers from 0 to 1" % where)
			break
	return problems


static func _groups(where: String, value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s must be an array of {scene, count}" % where)
		return problems
	for group: Variant in value as Array:
		if typeof(group) != TYPE_DICTIONARY:
			problems.append("%s entries must be objects" % where)
			continue
		var entry: Dictionary = group
		if typeof(entry.get("scene")) != TYPE_STRING or not String(entry["scene"]).ends_with(".tscn"):
			problems.append("%s entry needs a 'scene' path ending in .tscn" % where)
		if entry.has("count") and (not _is_whole(entry["count"]) or int(entry["count"]) < 1):
			problems.append("%s entry 'count' must be a whole number >= 1" % where)
	return problems


static func _late_hit(where: String, value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		problems.append("%s must be an object {at, indices, amount}" % where)
		return problems
	var entry: Dictionary = value
	for key: String in ["at", "amount"]:
		if entry.has(key) and (not _is_number(entry[key]) or float(entry[key]) < 0.0):
			problems.append("%s '%s' must be a number >= 0" % [where, key])
	if entry.has("indices"):
		problems.append_array(_index_array(where + " 'indices'", entry["indices"]))
	return problems


## previews: [{at, slot, card, release_at?}] - a key held from `at` to `release_at` (never
## released when omitted), sent as real input events so the capture shows the live preview.
static func _previews(where: String, value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s must be an array of {at, slot, card, release_at}" % where)
		return problems
	for preview: Variant in value as Array:
		if typeof(preview) != TYPE_DICTIONARY:
			problems.append("%s entries must be objects" % where)
			continue
		var entry: Dictionary = preview
		if not _is_number(entry.get("at")) or float(entry["at"]) < 0.0:
			problems.append("%s entry needs 'at' (a number >= 0)" % where)
		elif entry.has("release_at") and (not _is_number(entry["release_at"]) or float(entry["release_at"]) < float(entry["at"])):
			problems.append("%s entry 'release_at' must be a number >= 'at'" % where)
		for key: String in ["slot", "card"]:
			if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).is_empty():
				problems.append("%s entry needs a non-empty string '%s'" % [where, key])
	return problems


static func _casts(where: String, value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s must be an array of {at, slot, card}" % where)
		return problems
	for cast: Variant in value as Array:
		if typeof(cast) != TYPE_DICTIONARY:
			problems.append("%s entries must be objects" % where)
			continue
		var entry: Dictionary = cast
		if not _is_number(entry.get("at")) or float(entry["at"]) < 0.0:
			problems.append("%s entry needs 'at' (a number >= 0)" % where)
		for key: String in ["slot", "card"]:
			if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).is_empty():
				problems.append("%s entry needs a non-empty string '%s'" % [where, key])
	return problems
