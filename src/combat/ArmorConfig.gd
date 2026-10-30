class_name ArmorConfig
extends RefCounted
## Armor settings (GDD section 7, Armor), loaded once from data/armor.json:
## - `k`: the formula constant, reduction = armor / (armor + k). One value for every tier, enemy and the player.
## - `armor_reduction_cap`: the most damage armor can ever remove, however much armor stacks.
## - `non_elemental_types`: damage types that armor mitigates and resistance never touches. Anything not listed is
##   elemental (resistance only). A future non-elemental type is added here, not in code.
## Why its own file: tiers (run.json), the boss (bosses.json), enemies (enemies.json) and the player all share K and the
## cap, and none of those files is the natural owner.

const PATH := "res://data/armor.json"
const ARMOR_STAT := "armor"
const PENETRATION_STAT := "armor_penetration"
## Armor and resistance of the same tier must give reductions within this many points (0.02 = 2 percentage points).
const PARITY_TOLERANCE := 0.02
const DEFAULTS: Dictionary = {"k": 50.0, "armor_reduction_cap": 0.5, "non_elemental_types": ["physical", "neutral"]}

static var _loaded: bool = false
static var _cache: Dictionary = {}


static func validate(config: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(config) != TYPE_DICTIONARY:
		errors.append("armor config must be a JSON object")
		return errors
	var dict: Dictionary = config
	var k: Variant = dict.get("k")
	if (typeof(k) != TYPE_FLOAT and typeof(k) != TYPE_INT) or float(k) <= 0.0:
		errors.append("'k' is required and must be a number > 0")
	var cap: Variant = dict.get("armor_reduction_cap")
	if (typeof(cap) != TYPE_FLOAT and typeof(cap) != TYPE_INT) or float(cap) < 0.0 or float(cap) > 1.0:
		errors.append("'armor_reduction_cap' is required and must be a number in [0, 1]")
	var types: Variant = dict.get("non_elemental_types")
	if typeof(types) != TYPE_ARRAY or (types as Array).is_empty():
		errors.append("'non_elemental_types' must be a non-empty array of damage type ids")
	else:
		for t: Variant in types:
			if typeof(t) != TYPE_STRING or String(t).is_empty():
				errors.append("'non_elemental_types' entries must be non-empty strings")
	return errors


static func _data() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = DEFAULTS.duplicate(true)
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("ArmorConfig: could not open " + PATH)
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var errors := validate(parsed)
	if not errors.is_empty():
		push_error("ArmorConfig: invalid %s: %s" % [PATH, "; ".join(errors)])
		return _cache
	var dict: Dictionary = parsed
	_cache = {"k": float(dict["k"]), "armor_reduction_cap": float(dict["armor_reduction_cap"]), "non_elemental_types": (dict["non_elemental_types"] as Array).duplicate()}
	return _cache


static func k() -> float:
	return float(_data()["k"])


static func reduction_cap() -> float:
	return float(_data()["armor_reduction_cap"])


static func non_elemental_types() -> Array:
	return _data()["non_elemental_types"]


static func is_non_elemental(damage_type: String) -> bool:
	return non_elemental_types().has(damage_type)


## Armor points that give reduction `r` (GDD: armor = K * r / (1 - r)). Used by tests and validators.
static func armor_for_reduction(r: float, k_value: float) -> float:
	return k_value * r / (1.0 - r)


## Problems if `armor` and the tier's `resistance` do not give reductions within `tolerance` of each other.
static func parity_errors(label: String, armor: float, resistance: float, k_value: float, tolerance: float) -> Array[String]:
	var errors: Array[String] = []
	var armor_reduction: float = CombatMath.armor_reduction(armor, k_value, 1.0)
	if absf(armor_reduction - resistance) > tolerance:
		errors.append("%s: armor %s gives %d%% reduction but its resistance is %d%% (must be within %d points; armor %s would match)" % [
			label, str(armor), roundi(armor_reduction * 100.0), roundi(resistance * 100.0), roundi(tolerance * 100.0), str(snappedf(armor_for_reduction(resistance, k_value), 0.1))])
	return errors
