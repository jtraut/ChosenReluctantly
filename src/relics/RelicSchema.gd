class_name RelicSchema
extends RefCounted
## Pure validation of one relic file (data/relics/<id>.json), BUILD_DEPTH 4.2: returns problems as strings (empty =
## valid) and never logs, so tests can feed it bad data. RelicDatabase is the loader that logs.
##
## Also the single place that knows the relay events a trigger can listen to, what each carries, and which filter keys
## each event understands (EVENTS). RelicManager reads the same table, so the validator and the matcher cannot drift.

const RARITIES: Array[String] = ["tier1", "tier2", "tier3", "boss"]
const SOURCES: Array[String] = ["elite", "relic_room", "merchant", "mini_boss", "curse_room", "buff_room", "boss", "starter", "event", "altar"]
const BOSS_SOURCE := "mini_boss"
const TOP_KEYS: Array[String] = ["id", "name", "pool", "rarity", "sources", "keywords", "modifiers", "triggers", "rule_text", "flavor_text", "sacrifice_cost"]
const TRIGGER_KEYS: Array[String] = ["event", "filter", "at", "internal_cooldown", "effects"]
const MODIFIER_KEYS: Array[String] = ["stat", "modifier_type", "value"]
const AT_PLAYER := "player"
const AT_EVENT_POSITION := "event_position"
const AT_EVENT_TARGET := "event_target"
const AT_VALUES: Array[String] = [AT_PLAYER, AT_EVENT_POSITION, AT_EVENT_TARGET]
const MAX_INTERNAL_COOLDOWN := 600.0
const MAX_EVERY_NTH := 100
const MAX_RULE_TEXT_LENGTH := 120
const MIN_SACRIFICE_COST := 1
const MAX_SACRIFICE_COST := 2
const KINDS: Array[String] = ["hit", "echo", "dot"]
const TEAMS: Array[String] = ["enemy", "player"]
const ATTACK_IDS: Array[String] = ["light", "heavy"]

## What a filter key means (the value type), shared by the events that accept it.
##   string_list: a string or an array of strings, any of which may match.
const FILTER_KINDS: Dictionary = {
	"origin": "origin", "damage_type": "string_list", "kind": "kind", "target_team": "team", "target_has_status": "status",
	"status_id": "status", "reason": "reason", "slot_type": "slot_type", "card_id": "string_list", "tag": "tag",
	"attack_id": "attack", "shape": "shape", "room_type": "string_list", "min_amount": "number",
	"allow_relic_origin": "bool", "every_nth": "nth",
}

## Per event: `filter` (accepted filter keys), `position` (it has a place an effect can happen at) and `target` (it names a
## combatant the effect can be aimed at). `allow_relic_origin` and `every_nth` are accepted by every event.
const EVENTS: Dictionary = {
	"hit_landed": {"filter": ["origin", "damage_type", "kind", "target_team", "target_has_status", "min_amount"], "position": true, "target": true, "origin": true},
	"enemy_killed": {"filter": ["origin", "target_has_status"], "position": true, "target": true, "origin": true},
	"status_applied": {"filter": ["origin", "status_id", "target_team"], "position": true, "target": true, "origin": true},
	"status_ended": {"filter": ["origin", "status_id", "reason", "target_team"], "position": true, "target": true, "origin": true},
	"card_cast": {"filter": ["slot_type", "card_id", "tag"], "position": false, "target": false, "origin": false},
	"attack_fired": {"filter": ["attack_id"], "position": true, "target": false, "origin": false},
	"dash_ended": {"filter": ["card_id"], "position": true, "target": false, "origin": false},
	"player_damaged": {"filter": ["origin", "min_amount"], "position": false, "target": false, "origin": true},
	"zone_started": {"filter": ["shape"], "position": true, "target": false, "origin": false},
	"zone_ended": {"filter": ["shape"], "position": true, "target": false, "origin": false},
	"room_started": {"filter": ["room_type"], "position": false, "target": false, "origin": false},
	"room_cleared": {"filter": ["room_type"], "position": false, "target": false, "origin": false},
}

static var _origin_pattern: RegEx = null


static func event_ids() -> Array:
	return EVENTS.keys()


static func is_known_event(event_id: String) -> bool:
	return EVENTS.has(event_id)


## True when the event carries an origin (so the recursion guard applies to it).
static func event_has_origin(event_id: String) -> bool:
	return bool((EVENTS.get(event_id, {}) as Dictionary).get("origin", false))


static func validate(data: Variant, expected_id: String = "") -> Array[String]:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("a relic file must be a JSON object")
		return errors
	var relic: Dictionary = data
	for key: Variant in relic.keys():
		if not TOP_KEYS.has(String(key)):
			errors.append("unknown key '%s'" % str(key))
	_validate_identity(relic, expected_id, errors)
	_validate_pool(relic, errors)
	_validate_rarity_and_sources(relic, errors)
	if relic.has("sacrifice_cost"):
		var cost: Variant = relic["sacrifice_cost"]
		if not _is_whole(cost) or int(cost) < MIN_SACRIFICE_COST or int(cost) > MAX_SACRIFICE_COST:
			errors.append("sacrifice_cost must be a whole number from %d to %d" % [MIN_SACRIFICE_COST, MAX_SACRIFICE_COST])
	_validate_keywords(relic, errors)
	var modifiers_count: int = _validate_modifiers(relic, errors)
	var triggers_count: int = _validate_triggers(relic, errors)
	if modifiers_count == 0 and triggers_count == 0 and not _has_problem_in(errors, "modifiers") and not _has_problem_in(errors, "triggers"):
		errors.append("a relic needs at least one modifier or trigger")
	return errors


static func _has_problem_in(errors: Array[String], prefix: String) -> bool:
	for error: String in errors:
		if error.begins_with(prefix):
			return true
	return false


static func _validate_identity(relic: Dictionary, expected_id: String, errors: Array[String]) -> void:
	var id: Variant = relic.get("id")
	if typeof(id) != TYPE_STRING or String(id).is_empty():
		errors.append("'id' must be a non-empty string")
	elif expected_id != "" and String(id) != expected_id:
		errors.append("'id' is '%s' but the file name says '%s'" % [String(id), expected_id])
	elif not String(id).is_valid_identifier():
		errors.append("'id' must be letters, digits and underscores only")
	for field: String in ["name"]:
		if typeof(relic.get(field)) != TYPE_STRING or String(relic[field]).is_empty():
			errors.append("'%s' must be a non-empty string" % field)
	if typeof(relic.get("flavor_text")) != TYPE_STRING:
		errors.append("'flavor_text' must be a string")
	# The plain rule in one line, for the HUD chip and the pause list (BD2-B). Required: a relic with no stated rule is unreadable.
	var rule: Variant = relic.get("rule_text")
	if typeof(rule) != TYPE_STRING or String(rule).strip_edges().is_empty():
		errors.append("'rule_text' must be a non-empty string (the rule in one plain line)")
	elif String(rule).contains("
") or String(rule).length() > MAX_RULE_TEXT_LENGTH:
		errors.append("'rule_text' must be one line of at most %d characters" % MAX_RULE_TEXT_LENGTH)


static func _validate_pool(relic: Dictionary, errors: Array[String]) -> void:
	var pool: Variant = relic.get("pool")
	if typeof(pool) != TYPE_STRING or not PoolDatabase.has(String(pool)):
		errors.append("pool must be one of %s" % [PoolDatabase.known_ids()])


static func _validate_rarity_and_sources(relic: Dictionary, errors: Array[String]) -> void:
	var rarity: Variant = relic.get("rarity")
	var rarity_ok: bool = typeof(rarity) == TYPE_STRING and RARITIES.has(String(rarity))
	if not rarity_ok:
		errors.append("rarity must be one of %s" % [RARITIES])
	var sources: Variant = relic.get("sources")
	if typeof(sources) != TYPE_ARRAY or (sources as Array).is_empty():
		errors.append("sources must be a non-empty array of %s" % [SOURCES])
		return
	var seen: Dictionary = {}
	for source: Variant in (sources as Array):
		if typeof(source) != TYPE_STRING or not SOURCES.has(String(source)):
			errors.append("unknown source '%s' (known: %s)" % [str(source), SOURCES])
		elif seen.has(source):
			errors.append("source '%s' is listed twice" % String(source))
		else:
			seen[source] = true
	if rarity_ok and String(rarity) == "boss":
		for source: Variant in seen.keys():
			if String(source) != BOSS_SOURCE:
				errors.append("a boss-rarity relic can only have the source '%s', not '%s'" % [BOSS_SOURCE, String(source)])


static func _validate_keywords(relic: Dictionary, errors: Array[String]) -> void:
	if not relic.has("keywords"):
		return
	var keywords: Variant = relic["keywords"]
	if typeof(keywords) != TYPE_ARRAY:
		errors.append("'keywords' must be an array of tags")
		return
	var seen: Dictionary = {}
	for keyword: Variant in (keywords as Array):
		if typeof(keyword) != TYPE_STRING or not CardTags.is_known_tag(String(keyword)):
			errors.append("unknown keyword '%s'" % str(keyword))
		elif seen.has(keyword):
			errors.append("keyword '%s' is listed twice" % String(keyword))
		else:
			seen[keyword] = true


## Returns how many modifiers there are (problems go to `errors`).
static func _validate_modifiers(relic: Dictionary, errors: Array[String]) -> int:
	if not relic.has("modifiers"):
		return 0
	var modifiers: Variant = relic["modifiers"]
	if typeof(modifiers) != TYPE_ARRAY:
		errors.append("modifiers must be an array")
		return 0
	var list: Array = modifiers
	for i in range(list.size()):
		var entry: Variant = list[i]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("modifiers[%d] must be an object {stat, modifier_type, value}" % i)
			continue
		var modifier: Dictionary = entry
		for key: Variant in modifier.keys():
			if not MODIFIER_KEYS.has(String(key)):
				errors.append("modifiers[%d]: unknown key '%s' (a relic modifier has no duration or charges)" % [i, str(key)])
		var stat: Variant = modifier.get("stat")
		if typeof(stat) != TYPE_STRING or String(stat).is_empty():
			errors.append("modifiers[%d].stat must be a non-empty string" % i)
		if typeof(modifier.get("modifier_type")) != TYPE_STRING or not [StatModifiers.ADDITIVE, StatModifiers.MULTIPLICATIVE].has(String(modifier["modifier_type"])):
			errors.append("modifiers[%d].modifier_type must be '%s' or '%s'" % [i, StatModifiers.ADDITIVE, StatModifiers.MULTIPLICATIVE])
		if not _is_number(modifier.get("value")):
			errors.append("modifiers[%d].value must be a number" % i)
		elif typeof(stat) == TYPE_STRING:
			# The same buff rules cards follow (the status_damage_mult floor, the cooldown-skip shape), with a stand-in duration.
			var as_buff: Dictionary = {"stat": stat, "modifier_type": modifier.get("modifier_type", ""), "value": modifier["value"], "duration": 1.0}
			for problem: String in EffectTemplates.validate_params("buff", as_buff):
				errors.append("modifiers[%d]: %s" % [i, problem])
	return list.size()


## Returns how many triggers there are (problems go to `errors`).
static func _validate_triggers(relic: Dictionary, errors: Array[String]) -> int:
	if not relic.has("triggers"):
		return 0
	var triggers: Variant = relic["triggers"]
	if typeof(triggers) != TYPE_ARRAY:
		errors.append("triggers must be an array")
		return 0
	var list: Array = triggers
	for i in range(list.size()):
		var entry: Variant = list[i]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("triggers[%d] must be an object" % i)
			continue
		_validate_trigger(entry, i, errors)
	return list.size()


static func _validate_trigger(trigger: Dictionary, index: int, errors: Array[String]) -> void:
	var label: String = "triggers[%d]" % index
	for key: Variant in trigger.keys():
		if not TRIGGER_KEYS.has(String(key)):
			errors.append("%s: unknown key '%s'" % [label, str(key)])
	var event_id: Variant = trigger.get("event")
	var event_known: bool = typeof(event_id) == TYPE_STRING and EVENTS.has(String(event_id))
	if not event_known:
		errors.append("%s.event must be one of %s" % [label, EVENTS.keys()])
	var filter: Variant = trigger.get("filter", {})
	if typeof(filter) != TYPE_DICTIONARY:
		errors.append("%s.filter must be an object" % label)
	elif event_known:
		_validate_filter(filter, String(event_id), label, errors)
	if trigger.has("at"):
		var at: Variant = trigger["at"]
		if typeof(at) != TYPE_STRING or not AT_VALUES.has(String(at)):
			errors.append("%s.at must be one of %s" % [label, AT_VALUES])
		elif event_known:
			var spec: Dictionary = EVENTS[String(event_id)]
			if String(at) == AT_EVENT_POSITION and not bool(spec["position"]):
				errors.append("%s: the event '%s' has no position, so 'at' cannot be event_position" % [label, String(event_id)])
			if String(at) == AT_EVENT_TARGET and not bool(spec["target"]):
				errors.append("%s: the event '%s' has no target, so 'at' cannot be event_target" % [label, String(event_id)])
	if trigger.has("internal_cooldown"):
		var cooldown: Variant = trigger["internal_cooldown"]
		if not _is_number(cooldown) or float(cooldown) < 0.0 or float(cooldown) > MAX_INTERNAL_COOLDOWN:
			errors.append("%s.internal_cooldown must be a number from 0 to %s" % [label, str(MAX_INTERNAL_COOLDOWN)])
	var effects: Variant = trigger.get("effects")
	if typeof(effects) != TYPE_ARRAY or (effects as Array).is_empty():
		errors.append("%s.effects must be a non-empty array" % label)
		return
	var effect_errors: Array[String] = []
	for j in range((effects as Array).size()):
		CardSchema.validate_effect_entry((effects as Array)[j], j, effect_errors)
	for problem: String in effect_errors:
		errors.append("%s: %s" % [label, problem])


static func _validate_filter(filter: Dictionary, event_id: String, label: String, errors: Array[String]) -> void:
	var allowed: Array = (EVENTS[event_id] as Dictionary)["filter"]
	for key: Variant in filter.keys():
		var name: String = String(key)
		if name == "allow_relic_origin" or name == "every_nth":
			if name == "allow_relic_origin" and not event_has_origin(event_id):
				errors.append("%s.filter: '%s' means nothing for the event '%s' (it carries no origin)" % [label, name, event_id])
		elif not allowed.has(name):
			errors.append("%s.filter: unknown key '%s' for the event '%s' (known: %s)" % [label, name, event_id, allowed + ["allow_relic_origin", "every_nth"]])
			continue
		for problem: String in _filter_value_problems(name, filter[key]):
			errors.append("%s.filter.%s: %s" % [label, name, problem])


## Problems with one filter value (empty = fine).
static func _filter_value_problems(key: String, value: Variant) -> Array[String]:
	var errors: Array[String] = []
	var kind: String = String(FILTER_KINDS.get(key, ""))
	match kind:
		"bool":
			if typeof(value) != TYPE_BOOL:
				errors.append("must be true or false")
		"number":
			if not _is_number(value) or float(value) < 0.0:
				errors.append("must be a number from 0")
		"nth":
			if not _is_whole(value) or int(value) < 2 or int(value) > MAX_EVERY_NTH:
				errors.append("must be a whole number from 2 to %d" % MAX_EVERY_NTH)
		_:
			var items: Array = []
			if typeof(value) == TYPE_STRING:
				items = [value]
			elif typeof(value) == TYPE_ARRAY and not (value as Array).is_empty():
				items = value
			if items.is_empty():
				errors.append("must be a text value or a non-empty list of them")
				return errors
			for item: Variant in items:
				if typeof(item) != TYPE_STRING or String(item).is_empty():
					errors.append("'%s' is not a text value" % str(item))
				elif not _known_value(kind, String(item)):
					errors.append("'%s' is not a known %s" % [String(item), kind])
	return errors


static func _known_value(kind: String, value: String) -> bool:
	match kind:
		"origin":
			return origin_pattern().search(value) != null
		"kind":
			return KINDS.has(value)
		"team":
			return TEAMS.has(value)
		"status":
			return StatusDatabase.has_status(value)
		"reason":
			return CombatEventsRelay.STATUS_END_REASONS.has(value)
		"slot_type":
			return SlotTypeDatabase.has(value)
		"tag":
			return CardTags.is_known_tag(value)
		"attack":
			return ATTACK_IDS.has(value)
	return true


## An origin filter: light, heavy, enemy, or card:/status:/relic: followed by an id or * (any).
static func origin_pattern() -> RegEx:
	if _origin_pattern == null:
		_origin_pattern = RegEx.new()
		_origin_pattern.compile("^(light|heavy|enemy|(card|status|relic):(\\*|[A-Za-z0-9_]+))$")
	return _origin_pattern


## True when `origin` (an event's) matches `pattern` (a filter's): equal, or "card:*" style for any id of that prefix.
static func origin_matches(pattern: String, origin: String) -> bool:
	if pattern == origin:
		return true
	if pattern.ends_with(":*"):
		return origin.begins_with(pattern.trim_suffix("*"))
	return false


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))
