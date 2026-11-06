class_name MerchantSwitch
extends RefCounted
## The merchant's on switch (MAP2-B). The shipped data has the merchant OFF (data/map.json `types.merchant.weight` 0, `path_rules.relic_route` [5, 7]) until
## ux ships the panel. data/merchant_on.json holds exactly what changes when it is ON, as a patch: `map` is merged into data/map.json and `run` into
## data/run.json (objects merge key by key, anything else replaces). `apply()` patches the loaded configs for this process only, so a sim, a tool, a
## test or a `--merchant` launch can play the merchant before the data is flipped. Flipping it for good means copying these values into the data files.
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
