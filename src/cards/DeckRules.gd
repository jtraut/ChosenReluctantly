class_name DeckRules
extends RefCounted
## Unique-card minimums (GDD section 4): every slot needs N distinct card ids in the deck, and a
## named group of slots can carry a combined minimum. Pure logic over plain data, so tests
## feed it any config; the shipped one is data/deck_rules.json.
##
## Config shape:
##   {"min_unique_per_slot": 3,
##    "slots": {"utility": {"min_unique": 5}},                                       (optional overrides)
##    "slot_groups": [{"name": "Attack", "slots": [...], "min_unique_total": 10}]}   (optional)
## `slot_of` maps card id -> slot type (see slot_map_from_database()). Copies of a card are
## welcome in a deck but never count twice.

const DEFAULT_PATH := "res://data/deck_rules.json"


static var _shipped_config: Dictionary = {}


## The shipped config, read once and cached (the F3 overlay asks every frame).
static func shipped_config() -> Dictionary:
	if _shipped_config.is_empty():
		_shipped_config = load_config(DEFAULT_PATH)
	return _shipped_config


## Reads and parses a config file (uncached). Returns {} (and pushes an error) if unreadable.
static func load_config(path: String = DEFAULT_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DeckRules: could not open '%s'" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DeckRules: '%s' did not parse to a JSON object" % path)
		return {}
	return parsed


## Problems with the config itself; empty means valid. Never logs.
static func validate_config(config: Dictionary, known_slots: Array) -> Array[String]:
	var errors: Array[String] = []
	if not _is_positive_int(config.get("min_unique_per_slot")):
		errors.append("min_unique_per_slot must be a whole number > 0")
	var overrides: Variant = config.get("slots", {})
	if typeof(overrides) != TYPE_DICTIONARY:
		errors.append("'slots' must be an object")
		overrides = {}
	for slot_name: Variant in (overrides as Dictionary).keys():
		if not known_slots.has(slot_name):
			errors.append("slots: unknown slot '%s'" % str(slot_name))
			continue
		var entry: Variant = (overrides as Dictionary)[slot_name]
		if typeof(entry) != TYPE_DICTIONARY or not _is_positive_int((entry as Dictionary).get("min_unique")):
			errors.append("slots.%s.min_unique must be a whole number > 0" % str(slot_name))
	var groups: Variant = config.get("slot_groups", [])
	if typeof(groups) != TYPE_ARRAY:
		errors.append("'slot_groups' must be an array")
		return errors
	var seen_names: Array[String] = []
	for group: Variant in groups:
		if typeof(group) != TYPE_DICTIONARY:
			errors.append("slot_groups: each group must be an object")
			continue
		errors.append_array(_validate_group(group, config, known_slots, seen_names))
	return errors


## Minimum unique cards for one slot: its override, else the global value.
static func min_for_slot(config: Dictionary, slot_type: String) -> int:
	var overrides: Dictionary = config.get("slots", {})
	if overrides.has(slot_type):
		return int((overrides[slot_type] as Dictionary).get("min_unique", 0))
	return int(config.get("min_unique_per_slot", 0))


## Counts unique cards per slot and per group and records every shortfall.
static func check(card_ids: Array, config: Dictionary, slot_of: Dictionary, known_slots: Array, slot_names: Dictionary = {}) -> DeckCheck:
	var result := DeckCheck.new()
	var unique_by_slot: Dictionary = {}
	for slot_type: Variant in known_slots:
		unique_by_slot[slot_type] = {}
	for card_id: Variant in card_ids:
		var card_slot: Variant = slot_of.get(card_id)
		if card_slot != null and unique_by_slot.has(card_slot):
			(unique_by_slot[card_slot] as Dictionary)[card_id] = true
	for slot_type: Variant in known_slots:
		var count: int = (unique_by_slot[slot_type] as Dictionary).size()
		var required := min_for_slot(config, String(slot_type))
		var short := maxi(required - count, 0)
		var label := String(slot_names.get(slot_type, slot_type))
		result.slots.append({"slot_type": slot_type, "display_name": label, "count": count, "required": required, "short": short})
		if short > 0:
			result.problems.append("%s needs %d unique cards, deck has %d" % [label, required, count])
	for group: Variant in config.get("slot_groups", []):
		var group_dict: Dictionary = group
		var total := 0
		for member: Variant in group_dict.get("slots", []):
			if unique_by_slot.has(member):
				total += (unique_by_slot[member] as Dictionary).size()
		var required_total := int(group_dict.get("min_unique_total", 0))
		var short_total := maxi(required_total - total, 0)
		var group_name := String(group_dict.get("name", ""))
		result.groups.append({"name": group_name, "slots": group_dict.get("slots", []), "count": total, "required": required_total, "short": short_total})
		if short_total > 0:
			result.problems.append("%s group needs %d, has %d" % [group_name, required_total, total])
	return result


## check() over the live data: CardDatabase, SlotTypeDatabase and data/deck_rules.json.
static func check_shipped(card_ids: Array) -> DeckCheck:
	return check(card_ids, shipped_config(), slot_map_from_database(), SlotTypeDatabase.known_ids(), slot_names_from_database())


## Run-start gate (GDD section 4): "" when the deck may start a run, otherwise one loud message naming every
## shortfall. Pure, so tests feed it fixture decks. Main blocks the run on a non-empty result.
static func run_start_block_message(result: DeckCheck) -> String:
	if result.is_ok():
		return ""
	return "Run cannot start, the starting deck breaks a unique-card minimum: " + "; ".join(result.problems)


## Shortfalls that removing one copy of `card_id` would cause (empty = allowed).
## Only rules touching the card's slot (its slot minimum and any group holding it) can block,
## so an already-short unrelated slot never blocks a removal.
static func can_remove(card_ids: Array, card_id: String, config: Dictionary, slot_of: Dictionary, known_slots: Array, slot_names: Dictionary = {}) -> Array[String]:
	var remaining: Array = card_ids.duplicate()
	var index := remaining.find(card_id)
	if index < 0:
		return ["Card '%s' is not in the deck" % card_id]
	remaining.remove_at(index)
	return _blocking_problems(remaining, [slot_of.get(card_id)], config, slot_of, known_slots, slot_names)


## Shortfalls that swapping `remove_id` for `add_id` would cause (empty = allowed).
static func can_swap(card_ids: Array, remove_id: String, add_id: String, config: Dictionary, slot_of: Dictionary, known_slots: Array, slot_names: Dictionary = {}) -> Array[String]:
	var remaining: Array = card_ids.duplicate()
	var index := remaining.find(remove_id)
	if index < 0:
		return ["Card '%s' is not in the deck" % remove_id]
	remaining.remove_at(index)
	remaining.append(add_id)
	return _blocking_problems(remaining, [slot_of.get(remove_id), slot_of.get(add_id)], config, slot_of, known_slots, slot_names)


## Content validation: for each class + element pair (plus the neutral pool), the cards
## available must satisfy every rule. `pools` is {pool_id: {"kind": ...}}; `pool_of` maps
## card id -> pool id. Messages are prefixed with the combination, e.g. "rogue+fire+neutral".
static func validate_content(config: Dictionary, pools: Dictionary, pool_of: Dictionary, slot_of: Dictionary, known_slots: Array, slot_names: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	var classes: Array[String] = []
	var elements: Array[String] = []
	var neutrals: Array[String] = []
	for pool_id: Variant in pools.keys():
		match String((pools[pool_id] as Dictionary).get("kind", "")):
			"class":
				classes.append(String(pool_id))
			"element":
				elements.append(String(pool_id))
			"neutral":
				neutrals.append(String(pool_id))
	for class_id: String in classes:
		for element_id: String in elements:
			var included: Array[String] = [class_id, element_id]
			included.append_array(neutrals)
			var deck: Array[String] = []
			for card_id: Variant in pool_of.keys():
				if included.has(pool_of[card_id]):
					deck.append(String(card_id))
			var label := "+".join(included)
			for problem: String in check(deck, config, slot_of, known_slots, slot_names).problems:
				errors.append("%s: %s" % [label, problem])
	return errors


static func validate_shipped_content() -> Array[String]:
	var pools: Dictionary = {}
	for pool_id: Variant in PoolDatabase.known_ids():
		pools[pool_id] = PoolDatabase.get_definition(String(pool_id))
	var pool_of: Dictionary = {}
	for card: Variant in CardDatabase.all_cards():
		pool_of[(card as Dictionary)["id"]] = (card as Dictionary).get("pool", "")
	return validate_content(shipped_config(), pools, pool_of, slot_map_from_database(), SlotTypeDatabase.known_ids(), slot_names_from_database())


static func slot_map_from_database() -> Dictionary:
	var map: Dictionary = {}
	for card: Variant in CardDatabase.all_cards():
		map[(card as Dictionary)["id"]] = (card as Dictionary).get("slot_type", "")
	return map


static func slot_names_from_database() -> Dictionary:
	var names: Dictionary = {}
	for slot_type: Variant in SlotTypeDatabase.known_ids():
		names[slot_type] = SlotTypeDatabase.get_definition(String(slot_type)).get("display_name", slot_type)
	return names


static func _blocking_problems(deck: Array, touched_slots: Array, config: Dictionary, slot_of: Dictionary, known_slots: Array, slot_names: Dictionary) -> Array[String]:
	var result := check(deck, config, slot_of, known_slots, slot_names)
	var blocking: Array[String] = []
	for entry: Dictionary in result.slots:
		if int(entry["short"]) > 0 and touched_slots.has(entry["slot_type"]):
			blocking.append("%s needs %d unique cards, deck would have %d" % [entry["display_name"], entry["required"], entry["count"]])
	for entry: Dictionary in result.groups:
		if int(entry["short"]) > 0:
			for member: Variant in entry["slots"]:
				if touched_slots.has(member):
					blocking.append("%s group needs %d, would have %d" % [entry["name"], entry["required"], entry["count"]])
					break
	return blocking


static func _validate_group(group: Dictionary, config: Dictionary, known_slots: Array, seen_names: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var group_name := str(group.get("name", ""))
	if group_name.strip_edges().is_empty():
		errors.append("slot_groups: a group needs a non-empty 'name'")
	elif seen_names.has(group_name):
		errors.append("slot_groups: duplicate group name '%s'" % group_name)
	seen_names.append(group_name)
	var members: Variant = group.get("slots")
	var member_sum := 0
	if typeof(members) != TYPE_ARRAY or (members as Array).is_empty():
		errors.append("group '%s': 'slots' must be a non-empty array" % group_name)
	else:
		for member: Variant in members:
			if not known_slots.has(member):
				errors.append("group '%s': unknown slot '%s'" % [group_name, str(member)])
			else:
				member_sum += min_for_slot(config, String(member))
	var total: Variant = group.get("min_unique_total")
	if not _is_positive_int(total):
		errors.append("group '%s': min_unique_total must be a whole number > 0" % group_name)
	elif int(total) < member_sum:
		errors.append("group '%s': min_unique_total %d is below the sum of its slots' minimums (%d)" % [group_name, int(total), member_sum])
	return errors


static func _is_positive_int(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and number > 0.0 and number == floorf(number)
