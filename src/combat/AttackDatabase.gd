class_name AttackDatabase
extends RefCounted
## data/attacks.json: the player's light and heavy attacks. Pure data access
## plus validation; AttackController and Player consume the entries.
##
## "light" is one entry. "heavy" is an object keyed by CLASS id (rogue, wizard,
## ...): the character's class picks which one it uses. A heavy has a "shape":
## "arc" (wide melee wedge) or "targeted_aoe" (disc at the aim point, capped at
## max_range). Both are built from the shared cone / aoe effect templates.

const SHAPES: Array[String] = ["arc", "targeted_aoe"]

## Fields every shape needs. field -> [min, max, min_inclusive]. All are numbers.
const COMMON_NUMBER_RULES: Dictionary = {
	"interval": [0.0, 3600.0, false],
	"manual_click_max_rate_ratio": [0.0, 100.0, true],
	"damage": [0.0, 100000.0, false],
	"wind_up": [0.0, 60.0, true],
	"knockback": [0.0, 1000.0, true],
	"hit_stop_duration": [0.0, 5.0, true],
	"hit_stop_scale": [0.0, 1.0, false],
	"shake_strength": [0.0, 10.0, true],
	"shake_duration": [0.0, 10.0, true],
	"flash_duration": [0.0, 10.0, true],
}

## Shape-specific fields, same format.
const SHAPE_NUMBER_RULES: Dictionary = {
	"arc": {
		"range": [0.0, 100.0, false],
		"half_angle_degrees": [0.0, 180.0, false],
	},
	"targeted_aoe": {
		"radius": [0.0, 100.0, false],
		"max_range": [0.0, 100.0, false],
	},
}

## Optional numbers (absent means the default noted in the comment).
const OPTIONAL_NUMBER_RULES: Dictionary = {
	# Move speed change while winding up: a fraction in [-0.999, 0]. -1 would be a root (never allowed). Default 0.
	"wind_up_move_slow": [-0.999, 0.0, true],
	# Multiplies the element's base status chance. Default 0 (no element status).
	"status_chance_multiplier": [0.0, 100.0, true],
	# Seconds the element status lasts; required when the multiplier is above 0.
	"element_status_duration": [0.0, 3600.0, false],
}

static var _table := JsonDataTable.new("res://data/attacks.json")


static func ids() -> Array:
	return _table.ids()


## The light attack, or {} for anything else. The heavy is per class: use get_heavy().
static func get_attack(attack_id: String) -> Dictionary:
	if attack_id == "heavy":
		push_error("AttackDatabase: heavy is per class, use get_heavy(class_id)")
		return {}
	return _table.get_entry(attack_id)


## Class ids that have a heavy definition (data keys under "heavy").
static func heavy_class_ids() -> Array:
	return _heavy_table().keys()


static func has_heavy(class_id: String) -> bool:
	return _heavy_table().has(class_id)


## The heavy definition for a class, or {} when that class has none.
static func get_heavy(class_id: String) -> Dictionary:
	var entry: Variant = _heavy_table().get(class_id)
	return entry if typeof(entry) == TYPE_DICTIONARY else {}


static func _heavy_table() -> Dictionary:
	var heavy: Variant = _table.get_entry("heavy")
	return heavy if typeof(heavy) == TYPE_DICTIONARY else {}


## Returns human-readable problems; empty means valid.
static func validate_entry(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var shape: Variant = entry.get("shape")
	if typeof(shape) != TYPE_STRING or not SHAPES.has(String(shape)):
		errors.append("'shape' must be one of %s" % str(SHAPES))
		return errors
	if typeof(entry.get("auto")) != TYPE_BOOL:
		errors.append("'auto' must be a boolean")
	elif bool(entry["auto"]) and String(shape) != "arc":
		errors.append("only an 'arc' attack can be automatic (auto attacks need a target in front)")
	for key: String in ["stat", "damage_type", "color"]:
		if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).strip_edges().is_empty():
			errors.append("'%s' must be a non-empty string" % key)
	if typeof(entry.get("color")) == TYPE_STRING and not Color.html_is_valid(String(entry["color"])):
		errors.append("'color' is not a valid color string")
	_check_numbers(entry, COMMON_NUMBER_RULES, true, errors)
	_check_numbers(entry, SHAPE_NUMBER_RULES[String(shape)], true, errors)
	_check_numbers(entry, OPTIONAL_NUMBER_RULES, false, errors)
	if float(entry.get("status_chance_multiplier", 0.0)) > 0.0 and not entry.has("element_status_duration"):
		errors.append("'element_status_duration' is required when 'status_chance_multiplier' > 0")
	if entry.has("on_hit_statuses"):
		errors.append_array(_validate_on_hit_statuses(entry["on_hit_statuses"]))
	return errors


static func _check_numbers(entry: Dictionary, rules: Dictionary, required: bool, errors: Array[String]) -> void:
	for key: String in rules.keys():
		if not required and not entry.has(key):
			continue
		var value: Variant = entry.get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			errors.append("'%s' must be a number" % key)
			continue
		var rule: Array = rules[key]
		var number: float = float(value)
		if is_nan(number) or is_inf(number):
			errors.append("'%s' must be finite" % key)
		elif number > float(rule[1]) or number < float(rule[0]) or (number == float(rule[0]) and not bool(rule[2])):
			errors.append("'%s' out of range (%s)" % [key, str(number)])


## Statuses applied to every enemy the attack hits (Stun on the Rogue heavy).
## Each entry: status_id (must exist in statuses.json), optional chance 0..1
## (default 1), optional duration > 0 (default: the status's own base_duration).
static func _validate_on_hit_statuses(list: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(list) != TYPE_ARRAY:
		errors.append("'on_hit_statuses' must be an array")
		return errors
	for item: Variant in (list as Array):
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("'on_hit_statuses' entries must be objects")
			continue
		var status: Dictionary = item
		if typeof(status.get("status_id")) != TYPE_STRING or not StatusDatabase.has_status(String(status["status_id"])):
			errors.append("on_hit_statuses: unknown status_id '%s'" % str(status.get("status_id")))
		if status.has("chance"):
			var chance: Variant = status["chance"]
			if (typeof(chance) != TYPE_FLOAT and typeof(chance) != TYPE_INT) or is_nan(float(chance)) or float(chance) < 0.0 or float(chance) > 1.0:
				errors.append("on_hit_statuses: 'chance' must be a number 0..1")
		if status.has("duration"):
			var duration: Variant = status["duration"]
			if (typeof(duration) != TYPE_FLOAT and typeof(duration) != TYPE_INT) or is_nan(float(duration)) or float(duration) <= 0.0 or float(duration) > 3600.0:
				errors.append("on_hit_statuses: 'duration' must be a number > 0")
	return errors


## Validates a whole attacks table: "light" (an arc entry) and "heavy" (class id -> entry).
static func validate_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not table.has("light"):
		errors.append("missing required attack 'light'")
	elif typeof(table["light"]) != TYPE_DICTIONARY:
		errors.append("light: entry must be an object")
	else:
		for problem: String in validate_entry(table["light"]):
			errors.append("light: " + problem)
		if String((table["light"] as Dictionary).get("shape", "arc")) != "arc":
			errors.append("light: shape must be 'arc'")
	if not table.has("heavy"):
		errors.append("missing required attack 'heavy' (an object keyed by class id)")
	elif typeof(table["heavy"]) != TYPE_DICTIONARY or (table["heavy"] as Dictionary).is_empty():
		errors.append("heavy: must be a non-empty object keyed by class id")
	else:
		for class_id: String in (table["heavy"] as Dictionary).keys():
			var entry: Variant = (table["heavy"] as Dictionary)[class_id]
			if class_id.strip_edges().is_empty():
				errors.append("heavy: class id must be non-empty")
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("heavy.%s: entry must be an object" % class_id)
				continue
			for problem: String in validate_entry(entry):
				errors.append("heavy.%s: %s" % [class_id, problem])
	return errors


## The attacks one character uses: {&"light": entry, &"heavy": that class's heavy}.
## Every problem is push_error'd. A class with no valid heavy is an error and
## falls back to the first valid heavy so the game still runs.
static func load_valid(class_id: String) -> Dictionary:
	var table: Dictionary = {}
	for attack_id: String in _table.ids():
		table[attack_id] = _table.get_entry(attack_id)
	for problem: String in validate_table(table):
		push_error("AttackDatabase: " + problem)
	var valid: Dictionary = {}
	if typeof(table.get("light")) == TYPE_DICTIONARY and validate_entry(table["light"]).is_empty():
		valid[&"light"] = table["light"]
	var heavy_entry: Dictionary = get_heavy(class_id)
	if heavy_entry.is_empty() or not validate_entry(heavy_entry).is_empty():
		push_error("AttackDatabase: class '%s' has no valid heavy attack" % class_id)
		heavy_entry = {}
		for other_id: String in heavy_class_ids():
			if validate_entry(get_heavy(other_id)).is_empty():
				heavy_entry = get_heavy(other_id)
				break
	if not heavy_entry.is_empty():
		valid[&"heavy"] = heavy_entry
	return valid
