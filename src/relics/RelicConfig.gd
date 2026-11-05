class_name RelicConfig
extends RefCounted
## The `relics` block of data/run.json: whether relics are on, the cap, the tier odds per act and the offer size.
## `validate_block` is pure (tests feed it anything); the accessors read the shipped config through RunConfig.
##
## Tier odds are weights (not percentages) over tier1/tier2/tier3, one row per act. The boss tier is never in them:
## boss relics come only from a mini-boss and are drawn uniformly (RelicOffer).

const TIER_KEYS: Array[String] = ["tier1", "tier2", "tier3"]
const MAX_OWNED_LIMIT := 99
const MAX_OFFER_COUNT := 12
const MAX_ACT := 9
const MAX_WEIGHT := 1000.0


## Human-readable problems with a `relics` block; empty means valid.
static func validate_block(block: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(block) != TYPE_DICTIONARY:
		errors.append("'relics' must be an object {enabled, max_owned, tier_weights, offer_count, relic_room}")
		return errors
	var b: Dictionary = block
	for key: Variant in b.keys():
		if not ["enabled", "max_owned", "tier_weights", "offer_count", "relic_room"].has(String(key)):
			errors.append("relics: unknown key '%s'" % str(key))
	if typeof(b.get("enabled")) != TYPE_BOOL:
		errors.append("relics.enabled must be true or false")
	if not _is_whole(b.get("max_owned")) or int(b["max_owned"]) < 1 or int(b["max_owned"]) > MAX_OWNED_LIMIT:
		errors.append("relics.max_owned must be a whole number in [1, %d]" % MAX_OWNED_LIMIT)
	if not _is_whole(b.get("offer_count")) or int(b["offer_count"]) < 1 or int(b["offer_count"]) > MAX_OFFER_COUNT:
		errors.append("relics.offer_count must be a whole number in [1, %d]" % MAX_OFFER_COUNT)
	errors.append_array(_validate_tier_weights(b.get("tier_weights")))
	errors.append_array(_validate_relic_room(b.get("relic_room")))
	return errors


## The straight run's relic room (BD2-B): how many (0 = none), and the first and last room index it may take (0-based, like
## `placement.ranges`: index 2 is "Room 3 of 10"; the shipped 2 to 8 is the brief's "rooms 2-8" read like the rest room's [2, 8],
## see DECISIONS "BD2-B"). The boss is the last room, so `last` is checked against the run length by RunGenerator.
static func _validate_relic_room(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("relics.relic_room must be an object {count, first, last}")
		return errors
	var room: Dictionary = value
	for key: Variant in room.keys():
		if not ["count", "first", "last"].has(String(key)):
			errors.append("relics.relic_room: unknown key '%s'" % str(key))
	for key: String in ["count", "first", "last"]:
		if not _is_whole(room.get(key)) or int(room[key]) < 0 or int(room[key]) > 99:
			errors.append("relics.relic_room.%s must be a whole number in [0, 99]" % key)
	if _is_whole(room.get("first")) and _is_whole(room.get("last")) and int(room["first"]) > int(room["last"]):
		errors.append("relics.relic_room.first is after last")
	if _is_whole(room.get("first")) and int(room["first"]) < 1:
		errors.append("relics.relic_room.first must be at least 1 (the first room is always a fight)")
	return errors


static func _validate_tier_weights(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		errors.append("relics.tier_weights must be an object {act number: {tier1, tier2, tier3}}")
		return errors
	var rows: Dictionary = value
	if not rows.has("1"):
		errors.append("relics.tier_weights needs a row for act \"1\" (single-act runs use it)")
	for act_key: Variant in rows.keys():
		var act_text: String = String(act_key)
		if not act_text.is_valid_int() or int(act_text) < 1 or int(act_text) > MAX_ACT or str(int(act_text)) != act_text:
			errors.append("relics.tier_weights: act key '%s' must be a whole number from 1 to %d" % [act_text, MAX_ACT])
			continue
		var row: Variant = rows[act_key]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("relics.tier_weights.%s must be an object {tier1, tier2, tier3}" % act_text)
			continue
		var total: float = 0.0
		for tier: Variant in (row as Dictionary).keys():
			if not TIER_KEYS.has(String(tier)):
				errors.append("relics.tier_weights.%s: unknown tier '%s' (boss relics are not weighted)" % [act_text, str(tier)])
		for tier: String in TIER_KEYS:
			var weight: Variant = (row as Dictionary).get(tier)
			if not _is_number(weight) or float(weight) < 0.0 or float(weight) > MAX_WEIGHT:
				errors.append("relics.tier_weights.%s.%s must be a number in [0, %s]" % [act_text, tier, str(MAX_WEIGHT)])
			else:
				total += float(weight)
		if total <= 0.0:
			errors.append("relics.tier_weights.%s: the weights cannot all be 0" % act_text)
	return errors


static func block() -> Dictionary:
	return RunConfig.get_config().get("relics", {})


## True when the run offers and applies relics at all (data/run.json relics.enabled).
static func enabled() -> bool:
	return bool(block().get("enabled", false))


static func max_owned() -> int:
	return int(block().get("max_owned", 20))


static func offer_count() -> int:
	return int(block().get("offer_count", 3))


## The relic room settings {count, first, last} of a run config's `relics` block ({} when relics are off or the block is absent).
static func relic_room_settings(config: Dictionary) -> Dictionary:
	var relics: Variant = config.get("relics")
	if typeof(relics) != TYPE_DICTIONARY or not bool((relics as Dictionary).get("enabled", false)):
		return {}
	var room: Variant = (relics as Dictionary).get("relic_room")
	return room if typeof(room) == TYPE_DICTIONARY and int((room as Dictionary).get("count", 0)) > 0 else {}


## The tier weights for `act` (1-based) as {tier1, tier2, tier3}: the row for that act, else the highest row below it.
static func tier_weights_for_act(act: int, weights_block: Dictionary = {}) -> Dictionary:
	var rows: Dictionary = weights_block if not weights_block.is_empty() else block().get("tier_weights", {})
	var best: int = 0
	for key: Variant in rows.keys():
		var row_act: int = int(String(key))
		if row_act <= act and row_act > best:
			best = row_act
	if best == 0:
		return {}
	return rows[str(best)]


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))
