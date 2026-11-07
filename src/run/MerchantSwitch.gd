class_name MerchantSwitch
extends RefCounted
## The merchant's on switch (MAP2-B). The shipped data now has the merchant ON (data/map.json `types.merchant.weight` above 0, `path_rules.relic_route` [6, 8]; ux
## switched it on in MAP2). data/merchant_on.json holds exactly what changes when it is ON, as a patch: `map` is merged into data/map.json and `run` into
## data/run.json (objects merge key by key, anything else replaces). With the data already on, `apply()` changes nothing (a `--merchant` launch is redundant); it
## is kept so a test or a tool can re-apply the patch, and because shipped_problems() checks that a half flip never ships: every patch value must equal the data.
## `apply()` patches the loaded configs for this process only. If the data is ever switched off again, the patch plays the merchant before a flip.
##
## The patched config is validated first, so a patch that breaks a rule fails loudly and changes nothing.

const PATH := "res://data/merchant_on.json"
const KEYS: Array[String] = ["map", "run"]


## The patch file: {map: Dictionary, run: Dictionary}, or {} (with a push_error) when it is missing or malformed.
static func patch() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var problems: Array[String] = patch_problems(parsed)
	if not problems.is_empty():
		push_error("MerchantSwitch: invalid %s: %s" % [PATH, "; ".join(problems)])
		return {}
	return parsed


static func patch_problems(value: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		problems.append("must be a JSON object {map, run}")
		return problems
	for key: Variant in (value as Dictionary).keys():
		if not KEYS.has(String(key)):
			problems.append("unknown key '%s' (want %s)" % [str(key), KEYS])
	for key: String in KEYS:
		if typeof((value as Dictionary).get(key)) != TYPE_DICTIONARY:
			problems.append("'%s' must be an object" % key)
	return problems


## `base` with `over` merged in: objects merge key by key (recursively), every other value in `over` replaces. Neither argument is changed.
static func merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key: Variant in over.keys():
		var value: Variant = over[key]
		if typeof(out.get(key)) == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY:
			out[key] = merged(out[key], value)
		elif typeof(value) == TYPE_DICTIONARY:
			out[key] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			out[key] = (value as Array).duplicate(true)
		else:
			out[key] = value
	return out


## The map config with the patch applied, validated: {config, problems}. `config` is {} when the patch is missing or breaks a rule.
static func patched_map(base: Dictionary = {}) -> Dictionary:
	var file: Dictionary = patch()
	var source: Dictionary = base if not base.is_empty() else MapConfig.get_config()
	if file.is_empty() or source.is_empty():
		return {"config": {}, "problems": ["the merchant patch or the map config could not be read"] as Array[String]}
	var config: Dictionary = merged(source, file["map"])
	var problems: Array[String] = MapConfig.validate(config)
	return {"config": config if problems.is_empty() else {}, "problems": problems}


## Patches the loaded map and run configs in place (this process only). True when applied; false (with a push_error, nothing changed) when the patch is
## unreadable or the patched config is invalid. Applying twice is harmless.
static func apply() -> bool:
	var file: Dictionary = patch()
	if file.is_empty():
		return false
	var map_result: Dictionary = patched_map()
	if (map_result["config"] as Dictionary).is_empty():
		push_error("MerchantSwitch: the patched map config is invalid: %s" % "; ".join(map_result["problems"]))
		return false
	var run_config: Dictionary = merged(RunConfig.get_config(), file["run"])
	var run_problems: Array[String] = RunConfig.validate(run_config, EnemyConfig.enemy_ids(), [] as Array[String])
	if not run_problems.is_empty():
		push_error("MerchantSwitch: the patched run config is invalid: %s" % "; ".join(run_problems))
		return false
	_replace(MapConfig.get_config(), map_result["config"])
	_replace(RunConfig.get_config(), run_config)
	return true


static func _replace(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	target.merge(source.duplicate(true))


## True when the shipped data/map.json has the merchant on (its type weight is above 0). Reads the file, not the loaded (possibly patched) config.
static func shipped_is_on() -> bool:
	var config: Dictionary = MapConfig.load_from(MapConfig.PATH)["config"]
	return not config.is_empty() and float(config["types"]["merchant"]["weight"]) > 0.0


## Problems when the shipped data is switched halfway. ON (merchant weight above 0) means every value in data/merchant_on.json equals the value in
## data/map.json and data/run.json, so a flip is all or nothing. OFF means weight 0 and nothing else is checked. Reads the files, not the loaded config.
static func shipped_problems() -> Array[String]:
	var problems: Array[String] = []
	if not shipped_is_on():
		return problems
	var file: Dictionary = patch()
	var map_config: Variant = JSON.parse_string(FileAccess.get_file_as_string(MapConfig.PATH))
	var run_config: Variant = JSON.parse_string(FileAccess.get_file_as_string(RunConfig.PATH))
	if file.is_empty() or typeof(map_config) != TYPE_DICTIONARY or typeof(run_config) != TYPE_DICTIONARY:
		problems.append("the patch, map.json or run.json could not be read")
		return problems
	_differences(file["map"], map_config, "map", problems)
	_differences(file["run"], run_config, "run", problems)
	return problems


static func _differences(want: Variant, have: Variant, path: String, problems: Array[String]) -> void:
	if typeof(want) == TYPE_DICTIONARY and typeof(have) == TYPE_DICTIONARY:
		for key: Variant in (want as Dictionary).keys():
			_differences((want as Dictionary)[key], (have as Dictionary).get(key), "%s.%s" % [path, str(key)], problems)
	elif str(want) != str(have):
		problems.append("%s is %s in the data but data/merchant_on.json says %s" % [path, str(have), str(want)])
