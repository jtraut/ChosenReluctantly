class_name StatusDatabase
extends RefCounted
## data/statuses.json: status effect definitions (Burn, and later Chill,
## Soaked, ...). Validated once on first use: every problem is push_error'd and
## an invalid entry is treated as missing (get_status returns {}), so a typo
## cannot silently turn into a zero-damage or invisible status.

## damage_over_time: Burn, Bleed. heal_over_time: Regeneration. lifesteal: while active, the
## owner heals a fraction of the damage it deals (see StatusEffectManager.on_damage_dealt).
const EFFECT_TYPES: Array[String] = ["damage_over_time", "heal_over_time", "lifesteal", "stun"]
## Enemy ranks a stun rule must cover (see EnemyConfig.RANKS, which owns the list).
const RANKS: Array[String] = ["normal", "elite", "boss"]
## Allowed "visual.kind" values (see StatusEffectManager._ensure_flame).
const VISUAL_KINDS: Array[String] = ["flame", "stars"]
const MAX_VISUAL_SIZE := 5.0
## "stars" visual: how many, how wide they circle, how fast. field -> [min, max, min_inclusive].
const STARS_RULES: Dictionary = {
	"count": [1.0, 8.0, true],
	"orbit_radius": [0.0, 3.0, false],
	"orbit_hz": [0.0, 10.0, false],
}

## Per effect_type required numbers. field -> [min, max, min_inclusive].
const NUMBER_RULES_BY_TYPE: Dictionary = {
	"damage_over_time": {
		"damage_per_tick": [0.0, 100000.0, true],
		"tick_interval": [0.0, 3600.0, false],
	},
	"heal_over_time": {
		"heal_per_tick": [0.0, 100000.0, false],
		"tick_interval": [0.0, 3600.0, false],
	},
	"lifesteal": {
		"fraction": [0.0, 1.0, false],
		"max_heal_per_hit": [0.0, 100000.0, false],
	},
	"stun": {
		"base_duration": [0.0, 60.0, false],
	},
}
## Diminishing-returns block of a stun: field -> [min, max, min_inclusive].
const DR_RULES: Dictionary = {
	"window": [0.0, 3600.0, false],
	"multiplier": [0.0, 1.0, false],
	"immune_after": [1.0, 100.0, true],
}

static var _table := JsonDataTable.new("res://data/statuses.json")
static var _bad_ids: Dictionary = {}
static var _validated: bool = false


static func get_status(status_id: String) -> Dictionary:
	_ensure_validated()
	if _bad_ids.has(status_id):
		return {}
	return _table.get_entry(status_id)


static func has_status(status_id: String) -> bool:
	_ensure_validated()
	return _table.has(status_id) and not _bad_ids.has(status_id)


## Returns human-readable problems; empty means valid.
static func validate_entry(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var effect_type: Variant = entry.get("effect_type")
	var type_ok: bool = typeof(effect_type) == TYPE_STRING and EFFECT_TYPES.has(String(effect_type))
	if not type_ok:
		errors.append("'effect_type' must be one of %s" % str(EFFECT_TYPES))
	var required_strings: Array[String] = ["display_name"]
	if not type_ok or String(effect_type) == "damage_over_time":
		required_strings.append("damage_type")
	for key: String in required_strings:
		if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).strip_edges().is_empty():
			errors.append("'%s' must be a non-empty string" % key)
	var rules: Dictionary = NUMBER_RULES_BY_TYPE[String(effect_type)] if type_ok else NUMBER_RULES_BY_TYPE["damage_over_time"]
	errors.append_array(_check_numbers(entry, rules, ""))
	if type_ok and String(effect_type) == "stun":
		errors.append_array(_validate_stun(entry))
	if entry.has("visual"):
		errors.append_array(_validate_visual(entry["visual"]))
	return errors


static func _check_numbers(block: Dictionary, rules: Dictionary, prefix: String) -> Array[String]:
	var errors: Array[String] = []
	for key: String in rules.keys():
		var value: Variant = block.get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			errors.append("'%s%s' must be a number" % [prefix, key])
			continue
		var rule: Array = rules[key]
		var number: float = float(value)
		if is_nan(number) or is_inf(number):
			errors.append("'%s%s' must be finite" % [prefix, key])
		elif number > float(rule[1]) or number < float(rule[0]) or (number == float(rule[0]) and not bool(rule[2])):
			errors.append("'%s%s' out of range (%s)" % [prefix, key, str(number)])
	return errors


## Stun: diminishing returns (a repeat within `window` seconds multiplies the
## duration by `multiplier`; after `immune_after` stuns in the window, immune) and
## a duration multiplier per enemy rank (0 = immune). Every rank must be listed.
static func _validate_stun(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var dr: Variant = entry.get("diminishing_returns")
	if typeof(dr) != TYPE_DICTIONARY:
		errors.append("'diminishing_returns' must be an object")
	else:
		errors.append_array(_check_numbers(dr, DR_RULES, "diminishing_returns."))
	var ranks: Variant = entry.get("rank_multipliers")
	if typeof(ranks) != TYPE_DICTIONARY:
		errors.append("'rank_multipliers' must be an object")
	else:
		for rank: String in RANKS:
			var value: Variant = (ranks as Dictionary).get(rank)
			if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or is_nan(float(value)) or float(value) < 0.0 or float(value) > 1.0:
				errors.append("'rank_multipliers.%s' must be a number 0..1 (0 = immune)" % rank)
		for rank: String in (ranks as Dictionary).keys():
			if not RANKS.has(rank):
				errors.append("'rank_multipliers.%s' is not a known rank %s" % [rank, str(RANKS)])
	return errors


static func _validate_visual(visual: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(visual) != TYPE_DICTIONARY:
		errors.append("'visual' must be an object")
		return errors
	var block: Dictionary = visual
	if typeof(block.get("kind")) != TYPE_STRING or not VISUAL_KINDS.has(String(block["kind"])):
		errors.append("'visual.kind' must be one of %s" % str(VISUAL_KINDS))
	var size: Variant = block.get("size")
	if typeof(size) != TYPE_FLOAT and typeof(size) != TYPE_INT:
		errors.append("'visual.size' must be a number")
	elif is_nan(float(size)) or float(size) <= 0.0 or float(size) > MAX_VISUAL_SIZE:
		errors.append("'visual.size' must be > 0 and <= %s" % str(MAX_VISUAL_SIZE))
	# Optional color override (the flame currently takes its color from the element).
	if block.has("color") and not (typeof(block["color"]) == TYPE_STRING and Color.html_is_valid(String(block["color"]))):
		errors.append("'visual.color' must be a hex color like #ff7a1a")
	if typeof(block.get("kind")) == TYPE_STRING and block["kind"] == "stars":
		errors.append_array(_check_numbers(block, STARS_RULES, "visual."))
	# Optional body tint while the status is active (desaturates toward tint_color).
	if block.has("tint_color") != block.has("tint_amount"):
		errors.append("'visual.tint_color' and 'visual.tint_amount' go together")
	elif block.has("tint_color"):
		if not (typeof(block["tint_color"]) == TYPE_STRING and Color.html_is_valid(String(block["tint_color"]))):
			errors.append("'visual.tint_color' must be a hex color")
		errors.append_array(_check_numbers(block, {"tint_amount": [0.0, 1.0, true]}, "visual."))
	return errors


## Body tint of a status as {color: Color, amount: float}, or {} when it has none.
static func body_tint(status_id: String) -> Dictionary:
	var visual: Variant = get_status(status_id).get("visual")
	if typeof(visual) != TYPE_DICTIONARY or not (visual as Dictionary).has("tint_color"):
		return {}
	return {"color": Color.html(String(visual["tint_color"])), "amount": float(visual["tint_amount"])}


## Validates a whole statuses table (id -> entry).
static func validate_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for status_id: String in table.keys():
		if typeof(table[status_id]) != TYPE_DICTIONARY:
			errors.append("%s: entry must be an object" % status_id)
			continue
		for problem: String in validate_entry(table[status_id]):
			errors.append("%s: %s" % [status_id, problem])
	return errors


static func _ensure_validated() -> void:
	if _validated:
		return
	_validated = true
	var table: Dictionary = {}
	for status_id: String in _table.ids():
		table[status_id] = _table.get_entry(status_id)
	for problem: String in validate_table(table):
		push_error("StatusDatabase: " + problem)
	for status_id: String in table.keys():
		if typeof(table[status_id]) != TYPE_DICTIONARY or not validate_entry(table[status_id]).is_empty():
			_bad_ids[status_id] = true
