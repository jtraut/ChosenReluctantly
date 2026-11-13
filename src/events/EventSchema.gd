class_name EventSchema
extends RefCounted
## Pure validation of one event file (data/events/<id>.json), BUILD_DEPTH 13: returns problems as strings (empty = valid) and never logs, so tests
## can feed it bad data (like CardSchema and RelicSchema). EventDatabase is the loader that logs.
##
## An event: {id, name, flavor, acts: [1..], weight?, choices: [2-3 of {label, requires?, outcomes: [...]}]}. `requires` is an object with exactly one
## key of REQUIREMENTS; an outcome is {type, ...params} with `type` in OUTCOMES (the closed 13.2 set). The schema knows every outcome name from
## MAP4 sitting B1 on, but the engine only executes the ones listed in EventEngine.IMPLEMENTED until B2 and C add the rest.

const TOP_KEYS: Array[String] = ["id", "name", "flavor", "acts", "weight", "choices"]
const CHOICE_KEYS: Array[String] = ["label", "requires", "outcomes"]
const MIN_CHOICES := 2
const MAX_CHOICES := 3
const MAX_ACT := 9
const MAX_WEIGHT := 1000.0
const MAX_AMOUNT := 100000
const MAX_RELIC_COUNT := 6
const OUTCOMES: Array[String] = ["lose_hp", "lose_max_hp", "heal", "gain_gold", "lose_gold", "gain_relic", "gain_curse", "remove_curse", "remove_card",
		"sacrifice_relic", "start_fight", "chance", "stat_mod", "merchant_discount"]
const REQUIREMENTS: Array[String] = ["gold_at_least", "has_curse", "owns_relic"]
## Params each outcome accepts (besides `type`). Required ones are checked below.
const PARAM_KEYS: Dictionary = {
	"lose_hp": ["fraction"], "lose_max_hp": ["fraction"], "heal": ["fraction"], "gain_gold": ["amount"], "lose_gold": ["amount"],
	"gain_relic": ["tier", "count", "skip"], "gain_curse": ["id"], "remove_curse": [], "remove_card": [],
	"sacrifice_relic": ["select", "min_tier", "max_tier"], "start_fight": ["tier"], "chance": ["p", "win", "lose"],
	"stat_mod": ["stat", "modifier_type", "value"], "merchant_discount": ["fraction"],
}
const TIER_MODES: Array[String] = ["act", "next_act", "sacrificed_plus_one"]
const SELECT_MODES: Array[String] = ["pick", "highest"]
const FIGHT_TIERS: Array[String] = ["elite"]


static func validate(data: Variant, expected_id: String = "") -> Array[String]:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("an event file must be a JSON object")
		return errors
	var event: Dictionary = data
	for key: Variant in event.keys():
		if not TOP_KEYS.has(String(key)):
			errors.append("unknown key '%s'" % str(key))
	var id: Variant = event.get("id")
	if typeof(id) != TYPE_STRING or String(id).is_empty():
		errors.append("'id' must be a non-empty string")
	elif expected_id != "" and String(id) != expected_id:
		errors.append("'id' is '%s' but the file name says '%s'" % [String(id), expected_id])
	elif not String(id).is_valid_identifier():
		errors.append("'id' must be letters, digits and underscores only")
	for field: String in ["name", "flavor"]:
		if typeof(event.get(field)) != TYPE_STRING or String(event[field]).strip_edges().is_empty():
			errors.append("'%s' must be a non-empty string" % field)
	_validate_acts(event, errors)
	if event.has("weight"):
		var weight: Variant = event["weight"]
		if not _is_number(weight) or float(weight) <= 0.0 or float(weight) > MAX_WEIGHT:
			errors.append("'weight' must be a number above 0 and at most %s" % str(MAX_WEIGHT))
	_validate_choices(event, errors)
	return errors


## Problems with one outcome dictionary on its own (RunState checks the saved queue with this).
static func validate_outcome(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	_validate_outcome(value, "outcome", false, errors)
	return errors


## A copy of a valid outcome with its whole-number params as ints (and the same inside a chance's lists). JSON round trips and data files hand back floats;
## the run save compares JSON text, so every outcome that enters RunState goes through here.
static func normalize_outcome(outcome: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in outcome.keys():
		var value: Variant = outcome[key]
		if ["amount", "count", "min_tier", "max_tier", "tier"].has(String(key)) and _is_whole(value):
			out[String(key)] = int(value)
		elif ["win", "lose"].has(String(key)) and typeof(value) == TYPE_ARRAY:
			var branch: Array = []
			for inner: Variant in (value as Array):
				branch.append(normalize_outcome(inner as Dictionary) if typeof(inner) == TYPE_DICTIONARY else inner)
			out[String(key)] = branch
		else:
			out[String(key)] = value
	return out


static func _validate_acts(event: Dictionary, errors: Array[String]) -> void:
	var acts: Variant = event.get("acts")
	if typeof(acts) != TYPE_ARRAY or (acts as Array).is_empty():
		errors.append("'acts' must be a non-empty list of act numbers")
		return
	var seen: Array[int] = []
	for act: Variant in (acts as Array):
		if not _is_whole(act) or int(act) < 1 or int(act) > MAX_ACT:
			errors.append("'acts' entries must be whole numbers from 1 to %d" % MAX_ACT)
		elif seen.has(int(act)):
			errors.append("'acts' lists act %d twice" % int(act))
		else:
			seen.append(int(act))


static func _validate_choices(event: Dictionary, errors: Array[String]) -> void:
	var choices: Variant = event.get("choices")
	if typeof(choices) != TYPE_ARRAY:
		errors.append("'choices' must be a list of %d to %d choices" % [MIN_CHOICES, MAX_CHOICES])
		return
	var list: Array = choices
	if list.size() < MIN_CHOICES or list.size() > MAX_CHOICES:
		errors.append("'choices' must hold %d to %d choices, found %d" % [MIN_CHOICES, MAX_CHOICES, list.size()])
	var free_choice: bool = false
	for i in range(list.size()):
		var label: String = "choices[%d]" % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			errors.append("%s must be an object {label, requires, outcomes}" % label)
			continue
		var choice: Dictionary = list[i]
		for key: Variant in choice.keys():
			if not CHOICE_KEYS.has(String(key)):
				errors.append("%s: unknown key '%s'" % [label, str(key)])
		if typeof(choice.get("label")) != TYPE_STRING or String(choice["label"]).strip_edges().is_empty():
			errors.append("%s.label must be a non-empty string" % label)
		if not choice.has("requires"):
			free_choice = true
		else:
			_validate_requires(choice["requires"], label + ".requires", errors)
		var outcomes: Variant = choice.get("outcomes")
		if typeof(outcomes) != TYPE_ARRAY:
			errors.append("%s.outcomes must be a list (empty for a choice that only leaves)" % label)
		else:
			for j in range((outcomes as Array).size()):
				_validate_outcome((outcomes as Array)[j], "%s.outcomes[%d]" % [label, j], false, errors)
	if list.size() >= MIN_CHOICES and not free_choice:
		errors.append("at least one choice must have no 'requires', so the event can always be finished")


static func _validate_requires(value: Variant, label: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).size() != 1:
		errors.append("%s must be an object with exactly one of: %s" % [label, ", ".join(REQUIREMENTS)])
		return
	var key: String = String((value as Dictionary).keys()[0])
	var param: Variant = (value as Dictionary)[(value as Dictionary).keys()[0]]
	match key:
		"gold_at_least":
			if not _is_whole(param) or int(param) < 1 or int(param) > MAX_AMOUNT:
				errors.append("%s.gold_at_least must be a whole number from 1 to %d" % [label, MAX_AMOUNT])
		"has_curse":
			if typeof(param) != TYPE_BOOL or not bool(param):
				errors.append("%s.has_curse must be true" % label)
		"owns_relic":
			if typeof(param) != TYPE_DICTIONARY:
				errors.append("%s.owns_relic must be an object {min_tier, max_tier}" % label)
				return
			for tier_key: Variant in (param as Dictionary).keys():
				if not ["min_tier", "max_tier"].has(String(tier_key)):
					errors.append("%s.owns_relic: unknown key '%s'" % [label, str(tier_key)])
				elif not _is_whole((param as Dictionary)[tier_key]) or int((param as Dictionary)[tier_key]) < 1 or int((param as Dictionary)[tier_key]) > 3:
					errors.append("%s.owns_relic.%s must be a whole number from 1 to 3" % [label, str(tier_key)])
			if _is_whole((param as Dictionary).get("min_tier")) and _is_whole((param as Dictionary).get("max_tier")) \
					and int((param as Dictionary)["min_tier"]) > int((param as Dictionary)["max_tier"]):
				errors.append("%s.owns_relic: min_tier is above max_tier" % label)
		_:
			errors.append("%s: unknown requirement '%s' (valid: %s)" % [label, key, ", ".join(REQUIREMENTS)])


static func _validate_outcome(value: Variant, label: String, inside_chance: bool, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be an object {type, ...}" % label)
		return
	var outcome: Dictionary = value
	var type_id: Variant = outcome.get("type")
	if typeof(type_id) != TYPE_STRING or not OUTCOMES.has(String(type_id)):
		errors.append("%s.type '%s' is not an outcome (valid: %s)" % [label, str(type_id), ", ".join(OUTCOMES)])
		return
	var type_name: String = String(type_id)
	var allowed: Array = PARAM_KEYS[type_name]
	for key: Variant in outcome.keys():
		if String(key) != "type" and not allowed.has(String(key)):
			errors.append("%s (%s): unknown param '%s'" % [label, type_name, str(key)])
	match type_name:
		"lose_hp", "heal":
			_require_fraction(outcome, "fraction", 1.0, label, errors)
		"lose_max_hp":
			_require_fraction(outcome, "fraction", 0.9, label, errors)
		"merchant_discount":
			_require_fraction(outcome, "fraction", 1.0, label, errors)
		"gain_gold", "lose_gold":
			if not _is_whole(outcome.get("amount")) or int(outcome["amount"]) < 1 or int(outcome["amount"]) > MAX_AMOUNT:
				errors.append("%s (%s): 'amount' must be a whole number from 1 to %d" % [label, type_name, MAX_AMOUNT])
		"gain_relic":
			_validate_relic_gain(outcome, label, errors)
		"gain_curse":
			if outcome.has("id") and (typeof(outcome["id"]) != TYPE_STRING or String(outcome["id"]).is_empty()):
				errors.append("%s (gain_curse): 'id' must be a card id (leave it out for a random curse)" % label)
		"sacrifice_relic":
			if not SELECT_MODES.has(String(outcome.get("select", "")) if typeof(outcome.get("select")) == TYPE_STRING else ""):
				errors.append("%s (sacrifice_relic): 'select' must be one of %s" % [label, ", ".join(SELECT_MODES)])
			for tier_key: String in ["min_tier", "max_tier"]:
				if outcome.has(tier_key) and (not _is_whole(outcome[tier_key]) or int(outcome[tier_key]) < 1 or int(outcome[tier_key]) > 3):
					errors.append("%s (sacrifice_relic): '%s' must be a whole number from 1 to 3" % [label, tier_key])
			if _is_whole(outcome.get("min_tier")) and _is_whole(outcome.get("max_tier")) and int(outcome["min_tier"]) > int(outcome["max_tier"]):
				errors.append("%s (sacrifice_relic): min_tier is above max_tier" % label)
		"start_fight":
			if typeof(outcome.get("tier")) != TYPE_STRING or not FIGHT_TIERS.has(String(outcome["tier"])):
				errors.append("%s (start_fight): 'tier' must be one of %s" % [label, ", ".join(FIGHT_TIERS)])
		"stat_mod":
			if typeof(outcome.get("stat")) != TYPE_STRING or String(outcome["stat"]).is_empty():
				errors.append("%s (stat_mod): 'stat' must be a stat id" % label)
			if typeof(outcome.get("modifier_type")) != TYPE_STRING or not [StatModifiers.ADDITIVE, StatModifiers.MULTIPLICATIVE].has(String(outcome["modifier_type"])):
				errors.append("%s (stat_mod): 'modifier_type' must be '%s' or '%s'" % [label, StatModifiers.ADDITIVE, StatModifiers.MULTIPLICATIVE])
			if not _is_number(outcome.get("value")):
				errors.append("%s (stat_mod): 'value' must be a number" % label)
		"chance":
			if inside_chance:
				errors.append("%s: a chance outcome cannot be nested inside another chance" % label)
			var p: Variant = outcome.get("p")
			if not _is_number(p) or float(p) <= 0.0 or float(p) >= 1.0:
				errors.append("%s (chance): 'p' must be a number above 0 and below 1" % label)
			for branch: String in ["win", "lose"]:
				if typeof(outcome.get(branch)) != TYPE_ARRAY:
					errors.append("%s (chance): '%s' must be a list of outcomes" % [label, branch])
					continue
				for k in range((outcome[branch] as Array).size()):
					_validate_outcome((outcome[branch] as Array)[k], "%s.%s[%d]" % [label, branch, k], true, errors)


static func _validate_relic_gain(outcome: Dictionary, label: String, errors: Array[String]) -> void:
	var tier: Variant = outcome.get("tier")
	var tier_ok: bool = (typeof(tier) == TYPE_STRING and TIER_MODES.has(String(tier))) or (_is_whole(tier) and int(tier) >= 1 and int(tier) <= 3)
	if not tier_ok:
		errors.append("%s (gain_relic): 'tier' must be %s or a whole number from 1 to 3" % [label, ", ".join(TIER_MODES)])
	if outcome.has("count") and (not _is_whole(outcome["count"]) or int(outcome["count"]) < 1 or int(outcome["count"]) > MAX_RELIC_COUNT):
		errors.append("%s (gain_relic): 'count' must be a whole number from 1 to %d" % [label, MAX_RELIC_COUNT])
	if outcome.has("skip") and typeof(outcome["skip"]) != TYPE_BOOL:
		errors.append("%s (gain_relic): 'skip' must be true or false" % label)


static func _require_fraction(outcome: Dictionary, key: String, high: float, label: String, errors: Array[String]) -> void:
	var value: Variant = outcome.get(key)
	if not _is_number(value) or float(value) <= 0.0 or float(value) > high:
		errors.append("%s (%s): '%s' must be a number above 0 and at most %s" % [label, String(outcome.get("type", "")), key, str(high)])


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))
