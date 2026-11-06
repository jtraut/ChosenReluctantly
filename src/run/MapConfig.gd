class_name MapConfig
extends RefCounted
## data/map.json (MAP1-A, MAP.md section 6): the branching map's size, node types with their room windows and weights, the path rules
## and the relic estimate numbers. `validate` is pure (tests feed it anything); the accessors read the shipped file once through
## JsonDataTable, whose top-level keys are the "ids". A broken file gives {} plus a loud push_error; `is_valid()` tells.
## Unknown keys are rejected at every level, so a typo can't silently do nothing.

const PATH := "res://data/map.json"
## Node types a `types` entry may name (MAP.md section 2). `boss` is not one: it is only ever a `fixed` entry.
const NODE_TYPES: Array[String] = ["combat", "elite", "relic_room", "rest", "merchant", "mini_boss", "curse_room", "buff_room"]
const BOSS := "boss"
## Node types that start a fight (they get a wave id). The boss counts as a fight for the path rule `min_fights`.
const FIGHT_TYPES: Array[String] = ["combat", "elite", "mini_boss", "boss"]
## Elite-like nodes for `max_elite_like` (MAP.md section 3.3).
const ELITE_LIKE_TYPES: Array[String] = ["elite", "mini_boss"]
## Node types the relic estimate counts as one relic each (MAP.md section 4.1). The merchant is counted from gold instead.
const RELIC_TYPES: Array[String] = ["elite", "relic_room", "mini_boss", "curse_room", "buff_room"]
const TOP_KEYS: Array[String] = ["enabled", "rooms", "columns", "walks", "max_attempts", "fixed", "types", "path_rules", "estimate"]
## Keys a map file may leave out (MAP1-B): `chests`, the relic stage's chest sizes. Without it relic stages carry no chest and play as small.
const OPTIONAL_KEYS: Array[String] = ["chests"]
const CHEST_KEYS: Array[String] = ["weight", "act_offset", "act", "min_tier"]
const CHEST_SIZES: Array[String] = ["small", "medium", "large"]
const TYPE_KEYS: Array[String] = ["weight", "rooms", "no_repeat"]
const RULE_KEYS: Array[String] = ["min_fights", "max_elite_like", "max_merchants", "min_rest", "max_rest", "relic_route", "ignore_route_max", "min_branching"]
## `merchant_prices`: the price of each relic slot the merchant sells, cheapest first in the estimate (MAP2-A: 2 normal tier 1 slots and 1 shop-only tier 2 slot).
const ESTIMATE_KEYS: Array[String] = ["gold_mean", "merchant_prices"]
const MAX_ROOMS := 16  # paths are enumerated: 3^(rooms-2) at worst
const MAX_COLUMNS := 8
const MAX_WALKS := 16
const MAX_WEIGHT := 1000.0

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _load_problems: Array[String] = []


## Human-readable problems; empty means valid.
static func validate(config: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(config) != TYPE_DICTIONARY:
		errors.append("map config must be an object")
		return errors
	var c: Dictionary = config
	var known_keys: Array[String] = TOP_KEYS.duplicate()
	known_keys.append_array(OPTIONAL_KEYS)
	_unknown_keys(c, known_keys, "map", errors)
	for key: String in TOP_KEYS:
		if not c.has(key):
			errors.append("map: missing '%s'" % key)
	if c.has("enabled") and typeof(c["enabled"]) != TYPE_BOOL:
		errors.append("map.enabled must be true or false")
	var rooms: int = _whole_in(c, "rooms", 3, MAX_ROOMS, "map.rooms", errors)
	var columns: int = _whole_in(c, "columns", 2, MAX_COLUMNS, "map.columns", errors)
	_whole_in(c, "walks", 2, MAX_WALKS, "map.walks", errors)  # at least 2: the first two start in different columns
	_whole_in(c, "max_attempts", 1, 100000, "map.max_attempts", errors)
	if rooms > 0:
		_validate_fixed(c.get("fixed"), c.get("types"), rooms, errors)
		_validate_types(c.get("types"), rooms, errors)
		_validate_rules(c.get("path_rules"), rooms, errors)
	_validate_estimate(c.get("estimate"), errors)
	if c.has("chests"):
		_validate_chests(c["chests"], errors)
	if columns > 0 and rooms > 0 and c.has("types") and typeof(c["types"]) == TYPE_DICTIONARY:
		var any_weight: bool = false
		for entry: Variant in (c["types"] as Dictionary).values():
			if typeof(entry) == TYPE_DICTIONARY and _is_number((entry as Dictionary).get("weight")) and float((entry as Dictionary)["weight"]) > 0.0:
				any_weight = true
		if not any_weight:
			errors.append("map.types: every weight is 0, so no node could ever be picked")
	return errors


static func _validate_fixed(fixed: Variant, types: Variant, rooms: int, errors: Array[String]) -> void:
	if typeof(fixed) != TYPE_DICTIONARY:
		errors.append("map.fixed must be an object {room number: type}")
		return
	var seen_boss: bool = false
	for key: Variant in (fixed as Dictionary).keys():
		var room_text: String = String(key)
		if not room_text.is_valid_int() or str(int(room_text)) != room_text or int(room_text) < 1 or int(room_text) > rooms:
			errors.append("map.fixed: room '%s' must be a whole number from 1 to %d" % [room_text, rooms])
			continue
		var type_id: Variant = (fixed as Dictionary)[key]
		var known: bool = typeof(type_id) == TYPE_STRING and (String(type_id) == BOSS or (typeof(types) == TYPE_DICTIONARY and (types as Dictionary).has(String(type_id))))
		if not known:
			errors.append("map.fixed.%s: unknown type %s" % [room_text, str(type_id)])
			continue
		if String(type_id) == BOSS:
			seen_boss = true
			if int(room_text) != rooms:
				errors.append("map.fixed: the boss belongs on the last room (%d), found on room %s" % [rooms, room_text])
		elif int(room_text) == rooms:
			errors.append("map.fixed: the last room (%d) must be the boss" % rooms)
	if not seen_boss:
		errors.append("map.fixed must put the boss on room %d" % rooms)


static func _validate_types(types: Variant, rooms: int, errors: Array[String]) -> void:
	if typeof(types) != TYPE_DICTIONARY or (types as Dictionary).is_empty():
		errors.append("map.types must be an object {type: {weight, rooms, no_repeat}}")
		return
	for key: Variant in (types as Dictionary).keys():
		var type_id: String = String(key)
		if not NODE_TYPES.has(type_id):
			errors.append("map.types: unknown node type '%s'" % type_id)
			continue
		var entry: Variant = (types as Dictionary)[key]
		var label: String = "map.types.%s" % type_id
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s must be an object {weight, rooms, no_repeat}" % label)
			continue
		var e: Dictionary = entry
		_unknown_keys(e, TYPE_KEYS, label, errors)
		var weight: Variant = e.get("weight")
		if not _is_number(weight) or float(weight) < 0.0 or float(weight) > MAX_WEIGHT:
			errors.append("%s.weight must be a number in [0, %s]" % [label, str(MAX_WEIGHT)])
		var window: Variant = e.get("rooms")
		if typeof(window) != TYPE_ARRAY or (window as Array).size() != 2 or not _is_whole((window as Array)[0]) or not _is_whole((window as Array)[1]):
			errors.append("%s.rooms must be [first, last], two whole numbers" % label)
		else:
			var first: int = int((window as Array)[0])
			var last: int = int((window as Array)[1])
			if first < 1 or last > rooms or first > last:
				errors.append("%s.rooms [%d, %d] must satisfy 1 <= first <= last <= %d" % [label, first, last, rooms])
		if e.has("no_repeat") and typeof(e["no_repeat"]) != TYPE_BOOL:
			errors.append("%s.no_repeat must be true or false" % label)


static func _validate_rules(rules: Variant, rooms: int, errors: Array[String]) -> void:
	if typeof(rules) != TYPE_DICTIONARY:
		errors.append("map.path_rules must be an object")
		return
	var r: Dictionary = rules
	_unknown_keys(r, RULE_KEYS, "map.path_rules", errors)
	for key: String in RULE_KEYS:
		if not r.has(key):
			errors.append("map.path_rules: missing '%s'" % key)
	for key: String in ["min_fights", "max_elite_like", "max_merchants", "min_rest", "max_rest"]:
		_whole_in(r, key, 0, rooms, "map.path_rules." + key, errors)
	if _is_whole(r.get("min_rest")) and _is_whole(r.get("max_rest")) and int(r["min_rest"]) > int(r["max_rest"]):
		errors.append("map.path_rules.min_rest (%d) is above max_rest (%d)" % [int(r["min_rest"]), int(r["max_rest"])])
	_whole_in(r, "ignore_route_max", 0, 99, "map.path_rules.ignore_route_max", errors)
	var branching: Variant = r.get("min_branching")
	if r.has("min_branching") and (not _is_number(branching) or float(branching) < 0.0 or float(branching) > 1.0):
		errors.append("map.path_rules.min_branching must be a number in [0, 1]")
	var route: Variant = r.get("relic_route")
	if r.has("relic_route"):
		if typeof(route) != TYPE_ARRAY or (route as Array).size() != 2 or not _is_whole((route as Array)[0]) or not _is_whole((route as Array)[1]):
			errors.append("map.path_rules.relic_route must be [low, high], two whole numbers")
		elif int((route as Array)[0]) < 0 or int((route as Array)[1]) > 99 or int((route as Array)[0]) > int((route as Array)[1]):
			errors.append("map.path_rules.relic_route must satisfy 0 <= low <= high <= 99")


static func _validate_estimate(estimate: Variant, errors: Array[String]) -> void:
	if typeof(estimate) != TYPE_DICTIONARY:
		errors.append("map.estimate must be an object {gold_mean, merchant_prices}")
		return
	var e: Dictionary = estimate
	_unknown_keys(e, ESTIMATE_KEYS, "map.estimate", errors)
	for key: String in ESTIMATE_KEYS:
		if not e.has(key):
			errors.append("map.estimate: missing '%s'" % key)
	var gold: Variant = e.get("gold_mean")
	if e.has("gold_mean"):
		if typeof(gold) != TYPE_DICTIONARY:
			errors.append("map.estimate.gold_mean must be an object {type: number}")
		else:
			for key: Variant in (gold as Dictionary).keys():
				var value: Variant = (gold as Dictionary)[key]
				if not NODE_TYPES.has(String(key)):
					errors.append("map.estimate.gold_mean: unknown node type '%s'" % str(key))
				elif not _is_number(value) or float(value) < 0.0 or float(value) > 100000.0:
					errors.append("map.estimate.gold_mean.%s must be a number in [0, 100000]" % str(key))
	if e.has("merchant_prices"):
		var prices: Variant = e["merchant_prices"]
		if typeof(prices) != TYPE_ARRAY or (prices as Array).is_empty() or (prices as Array).size() > 9:
			errors.append("map.estimate.merchant_prices must be a list of 1 to 9 prices")
		else:
			for price: Variant in (prices as Array):
				if not _is_number(price) or float(price) <= 0.0 or float(price) > 100000.0:
					errors.append("map.estimate.merchant_prices: '%s' must be a number above 0" % str(price))


## `chests`: {small, medium, large: {weight, min_tier, and either act_offset (a row relative to the room's act) or act (a fixed row)}}.
## All three sizes are required once the block exists. `min_tier` 1-3: relics below that tier are not offered from this chest.
static func _validate_chests(chests: Variant, errors: Array[String]) -> void:
	if typeof(chests) != TYPE_DICTIONARY:
		errors.append("map.chests must be an object {small, medium, large}")
		return
	_unknown_keys(chests as Dictionary, CHEST_SIZES, "map.chests", errors)
	var total: float = 0.0
	for size_id: String in CHEST_SIZES:
		var entry: Variant = (chests as Dictionary).get(size_id)
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("map.chests.%s must be an object {weight, act_offset or act, min_tier}" % size_id)
			continue
		var e: Dictionary = entry
		_unknown_keys(e, CHEST_KEYS, "map.chests." + size_id, errors)
		if not _is_number(e.get("weight")) or float(e["weight"]) < 0.0 or float(e["weight"]) > MAX_WEIGHT:
			errors.append("map.chests.%s.weight must be a number in [0, %s]" % [size_id, str(MAX_WEIGHT)])
		else:
			total += float(e["weight"])
		if e.has("act_offset") == e.has("act"):
			errors.append("map.chests.%s needs exactly one of act_offset and act" % size_id)
		_whole_in(e, "act_offset", 0, 8, "map.chests.%s.act_offset" % size_id, errors)
		_whole_in(e, "act", 1, 9, "map.chests.%s.act" % size_id, errors)
		if not e.has("min_tier"):
			errors.append("map.chests.%s: missing 'min_tier'" % size_id)
		_whole_in(e, "min_tier", 1, 3, "map.chests.%s.min_tier" % size_id, errors)
	if total <= 0.0:
		errors.append("map.chests: every weight is 0, so no chest size could be picked")


## The chest block of a validated config ({} when the file has none).
static func chests(config: Dictionary = {}) -> Dictionary:
	var source: Dictionary = config if not config.is_empty() else get_config()
	return source.get("chests", {})


## Pushes a problem for every key of `dict` that is not in `allowed`.
static func _unknown_keys(dict: Dictionary, allowed: Array[String], label: String, errors: Array[String]) -> void:
	for key: Variant in dict.keys():
		if not allowed.has(String(key)):
			errors.append("%s: unknown key '%s'" % [label, str(key)])


## Reads `dict[key]` as a whole number in [low, high]. Returns it, or -1 after recording a problem (a missing key is reported by the caller).
static func _whole_in(dict: Dictionary, key: String, low: int, high: int, label: String, errors: Array[String]) -> int:
	if not dict.has(key):
		return -1
	var value: Variant = dict[key]
	if not _is_whole(value) or int(value) < low or int(value) > high:
		errors.append("%s must be a whole number in [%d, %d]" % [label, low, high])
		return -1
	return int(value)


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))


# ---- Shipped config ----

## Reads and validates one map file: {config, problems}. `config` is {} when the file is missing, not a JSON object, or breaks a rule
## (`problems` says why). Pure with respect to the shipped cache, so tests point it at fixtures.
static func load_from(path: String) -> Dictionary:
	var table := JsonDataTable.new(path)
	var raw: Dictionary = {}
	for key: Variant in table.ids():
		raw[String(key)] = table.get_raw(String(key))
	if raw.is_empty():
		return {"config": {}, "problems": ["%s is missing, empty or not a JSON object" % path] as Array[String]}
	var problems: Array[String] = validate(raw)
	if not problems.is_empty():
		return {"config": {}, "problems": problems}
	return {"config": raw, "problems": [] as Array[String]}


## The validated shipped config, or {} when missing or invalid (push_error, never a crash; `is_valid()` tells).
static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	var result: Dictionary = load_from(PATH)
	_load_problems = result["problems"]
	if not _load_problems.is_empty():
		push_error("MapConfig: invalid %s: %s" % [PATH, "; ".join(_load_problems)])
		return _cache
	_cache = result["config"]
	return _cache


static func is_valid() -> bool:
	return not get_config().is_empty()


static func load_problems() -> Array[String]:
	get_config()
	return _load_problems


## True when runs use the branching map (data/map.json `enabled`). False when the file is broken (the straight run is the safe fallback).
static func enabled() -> bool:
	return bool(get_config().get("enabled", false))


## Test hook: drop the cache so the next call re-reads the file.
static func reset_cache() -> void:
	_cache = {}
	_loaded = false
	_load_problems = []
