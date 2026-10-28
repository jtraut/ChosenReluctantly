class_name AttackDatabase
extends RefCounted
## data/attacks.json: the player's light and heavy attacks. Pure data access
## plus validation; AttackController and Player consume the entries.

const REQUIRED_IDS: Array[String] = ["light", "heavy"]

## field -> [min, max, min_inclusive]. All are numbers.
const NUMBER_RULES: Dictionary = {
	"interval": [0.0, 3600.0, false],
	"manual_min_gap": [-1.0, 3600.0, true],
	"damage": [0.0, 100000.0, false],
	"range": [0.0, 100.0, false],
	"half_angle_degrees": [0.0, 180.0, false],
	"wind_up": [0.0, 60.0, true],
	"knockback": [0.0, 1000.0, true],
	"hit_stop_duration": [0.0, 5.0, true],
	"hit_stop_scale": [0.0, 1.0, false],
	"shake_strength": [0.0, 10.0, true],
	"shake_duration": [0.0, 10.0, true],
	"flash_duration": [0.0, 10.0, true],
}

static var _table := JsonDataTable.new("res://data/attacks.json")


static func ids() -> Array:
	return _table.ids()


static func get_attack(attack_id: String) -> Dictionary:
	return _table.get_entry(attack_id)


## Returns human-readable problems; empty means valid.
static func validate_entry(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if typeof(entry.get("auto")) != TYPE_BOOL:
		errors.append("'auto' must be a boolean")
	for key: String in ["stat", "damage_type", "color"]:
		if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).strip_edges().is_empty():
			errors.append("'%s' must be a non-empty string" % key)
	if typeof(entry.get("color")) == TYPE_STRING and not Color.html_is_valid(String(entry["color"])):
		errors.append("'color' is not a valid color string")
	for key: String in NUMBER_RULES.keys():
		var value: Variant = entry.get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			errors.append("'%s' must be a number" % key)
			continue
		var rule: Array = NUMBER_RULES[key]
		var number: float = float(value)
		if is_nan(number) or is_inf(number):
			errors.append("'%s' must be finite" % key)
		elif number > float(rule[1]) or number < float(rule[0]) or (number == float(rule[0]) and not bool(rule[2])):
			errors.append("'%s' out of range (%s)" % [key, str(number)])
	return errors


## Validates a whole attacks table (id -> entry), including required ids.
static func validate_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for required_id: String in REQUIRED_IDS:
		if not table.has(required_id):
			errors.append("missing required attack '%s'" % required_id)
	for attack_id: String in table.keys():
		if typeof(table[attack_id]) != TYPE_DICTIONARY:
			errors.append("%s: entry must be an object" % attack_id)
			continue
		for problem: String in validate_entry(table[attack_id]):
			errors.append("%s: %s" % [attack_id, problem])
	return errors


## Valid entries only (StringName id -> entry); every problem is push_error'd.
static func load_valid() -> Dictionary:
	var table: Dictionary = {}
	for attack_id: String in _table.ids():
		table[attack_id] = _table.get_entry(attack_id)
	for problem: String in validate_table(table):
		push_error("AttackDatabase: " + problem)
	var valid: Dictionary = {}
	for attack_id: String in table.keys():
		if typeof(table[attack_id]) == TYPE_DICTIONARY and validate_entry(table[attack_id]).is_empty():
			valid[StringName(attack_id)] = table[attack_id]
	return valid
