class_name CardSchema
extends RefCounted
## Pure validation: returns errors as data (an array of strings, empty if
## valid). Never push_error()s - that belongs to the boot-time loader
## (CardDatabase), not here, so this can be tested against malformed data
## without polluting a "zero errors" run.

## MAP3b: card rarity, lowest first (`rarity` is optional and defaults to common). Read by RewardOffer, the merchant and the pool-fill rule.
const RARITY_COMMON := "common"
const RARITIES: Array[String] = ["common", "rare", "legendary"]


static func rarity_of(card_data: Variant) -> String:
	if typeof(card_data) != TYPE_DICTIONARY:
		return RARITY_COMMON
	var value: Variant = (card_data as Dictionary).get("rarity", RARITY_COMMON)
	return String(value) if typeof(value) == TYPE_STRING and RARITIES.has(String(value)) else RARITY_COMMON


## MAP4-C: a curse card (`"curse": true`, BUILD_DEPTH 13.4). It sits in its own fixed slot type, belongs to the neutral pool, may have no effects at all, and
## is never offered or filled in by a pool (RewardOffer, the merchant, the pool-filled deck). Anything that is not exactly `true` is not a curse.
const CURSE_POOL := "neutral"


static func is_curse(card_data: Variant) -> bool:
	return typeof(card_data) == TYPE_DICTIONARY and typeof((card_data as Dictionary).get("curse", false)) == TYPE_BOOL and bool((card_data as Dictionary).get("curse", false))


## 3d-B (GDD section 9, D23, D52 = A): where a card may be found. `starter` can go in a loadout's starting deck, `reward` is found only as a run reward,
## `locked` waits for an unlock condition (`unlock` text, "TBD" until the rules exist). Every non-curse card has the field; a curse must not.
const AVAILABILITY_STARTER := "starter"
const AVAILABILITY_REWARD := "reward"
const AVAILABILITY_LOCKED := "locked"
const AVAILABILITIES: Array[String] = ["starter", "reward", "locked"]
const UNLOCK_TBD := "TBD"


## A card's availability. A curse (or anything unreadable) has none and returns "".
static func availability_of(card_data: Variant) -> String:
	if typeof(card_data) != TYPE_DICTIONARY or is_curse(card_data):
		return ""
	var value: Variant = (card_data as Dictionary).get("availability", "")
	return String(value) if typeof(value) == TYPE_STRING and AVAILABILITIES.has(String(value)) else ""


## The unlock condition text of a locked card ("TBD" when it carries none); "" for any other card.
static func unlock_text_of(card_data: Variant) -> String:
	if availability_of(card_data) != AVAILABILITY_LOCKED:
		return ""
	var value: Variant = (card_data as Dictionary).get("unlock", UNLOCK_TBD)
	return String(value) if typeof(value) == TYPE_STRING and not String(value).strip_edges().is_empty() else UNLOCK_TBD


static func validate(card_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	_require_non_empty_string(card_data, "id", errors)
	_require_non_empty_string(card_data, "name", errors)
	_require_string(card_data, "flavor_text", errors)
	_validate_slot_type(card_data, errors)
	_validate_pool(card_data, errors)
	_validate_cooldown_modifier(card_data, errors)
	if card_data.has("rarity") and (typeof(card_data["rarity"]) != TYPE_STRING or not RARITIES.has(String(card_data["rarity"]))):
		errors.append("rarity must be one of %s" % [RARITIES])
	if card_data.has("curse"):
		if typeof(card_data["curse"]) != TYPE_BOOL:
			errors.append("curse must be true or false")
		elif bool(card_data["curse"]) and card_data.get("pool") != CURSE_POOL:
			errors.append("a curse card must be in the '%s' pool" % CURSE_POOL)
	_validate_availability(card_data, errors)
	_validate_effects(card_data, errors)
	errors.append_array(CardTags.validate_keywords(card_data))
	if card_data.has("requires"):
		errors.append_array(RewardOffer.validate_requires(card_data["requires"], SlotTypeDatabase.known_ids(), PoolDatabase.known_ids()))

	return errors


## Non-fatal advisories (never part of validate()'s errors). Currently: card
## names longer than data/ui.json hud.name_warn_length risk being shrunk or
## truncated in the HUD slot widgets.
static func warnings(card_data: Dictionary, max_name_length: int = -1) -> Array[String]:
	var result: Array[String] = []
	var limit := max_name_length if max_name_length >= 0 else int(UiConfig.hud()["name_warn_length"])
	var card_name: Variant = card_data.get("name")
	if typeof(card_name) == TYPE_STRING and (card_name as String).length() > limit:
		result.append("name is %d characters (over %d); the HUD will shrink or truncate it" % [(card_name as String).length(), limit])
	return result


static func _validate_availability(card_data: Dictionary, errors: Array[String]) -> void:
	if is_curse(card_data):
		if card_data.has("availability") or card_data.has("unlock"):
			errors.append("a curse card must not carry 'availability' or 'unlock' (curses are not in the collection)")
		return
	var value: Variant = card_data.get("availability")
	if typeof(value) != TYPE_STRING or not AVAILABILITIES.has(String(value)):
		errors.append("availability must be one of %s" % [AVAILABILITIES])
		return
	var has_unlock: bool = card_data.has("unlock")
	if String(value) == AVAILABILITY_LOCKED:
		if not has_unlock or typeof(card_data["unlock"]) != TYPE_STRING or String(card_data["unlock"]).strip_edges().is_empty():
			errors.append("a locked card needs 'unlock' text (or \"%s\")" % UNLOCK_TBD)
	elif has_unlock:
		errors.append("'unlock' is only for a locked card")


static func _validate_slot_type(card_data: Dictionary, errors: Array[String]) -> void:
	var slot_type: Variant = card_data.get("slot_type")
	if typeof(slot_type) != TYPE_STRING or not SlotTypeDatabase.has(slot_type):
		errors.append("slot_type must be one of %s" % [SlotTypeDatabase.known_ids()])


static func _validate_pool(card_data: Dictionary, errors: Array[String]) -> void:
	var pool: Variant = card_data.get("pool")
	if typeof(pool) != TYPE_STRING or not PoolDatabase.has(pool):
		errors.append("pool must be one of %s" % [PoolDatabase.known_ids()])


static func _validate_cooldown_modifier(card_data: Dictionary, errors: Array[String]) -> void:
	var cooldown_modifier: Variant = card_data.get("cooldown_modifier")
	if typeof(cooldown_modifier) != TYPE_FLOAT and typeof(cooldown_modifier) != TYPE_INT:
		errors.append("cooldown_modifier must be a number")


static func _validate_effects(card_data: Dictionary, errors: Array[String]) -> void:
	var effects: Variant = card_data.get("effects")
	if typeof(effects) == TYPE_ARRAY and (effects as Array).is_empty() and is_curse(card_data):
		return  # MAP4-C: only a curse may do nothing when cast
	if typeof(effects) != TYPE_ARRAY or (effects as Array).is_empty():
		errors.append("effects must be a non-empty array (only a curse card may be empty)")
		return
	var effects_array: Array = effects
	for i in range(effects_array.size()):
		_validate_effect(effects_array[i], i, errors)


## Checks one effect entry ({template, params, condition?}) the way a card's effects are checked. Relics reuse it, so a
## relic effect and a card effect can never be validated differently. Problems read "effects[<index>] ...".
static func validate_effect_entry(effect: Variant, index: int, errors: Array[String]) -> void:
	_validate_effect(effect, index, errors, true)


static func _validate_effect(effect: Variant, index: int, errors: Array[String], in_trigger: bool = false) -> void:
	if typeof(effect) != TYPE_DICTIONARY:
		errors.append("effects[%d] must be an object" % index)
		return
	var effect_dict: Dictionary = effect
	var template_id: Variant = effect_dict.get("template")
	if typeof(template_id) != TYPE_STRING or not EffectTemplates.is_known_template(template_id):
		errors.append("effects[%d].template must be one of %s" % [index, EffectTemplates.REQUIRED_PARAMS.keys()])
		return
	var params: Variant = effect_dict.get("params")
	if typeof(params) != TYPE_DICTIONARY:
		errors.append("effects[%d].params must be an object" % index)
		return
	var params_dict: Dictionary = params
	for required_param: String in EffectTemplates.required_params(template_id):
		if not params_dict.has(required_param):
			errors.append("effects[%d] (%s) missing required param '%s'" % [index, template_id, required_param])
	for problem: String in EffectTemplates.validate_params(template_id, params_dict):
		errors.append("effects[%d] (%s): %s" % [index, template_id, problem])
	if effect_dict.has("condition"):
		for problem: String in EffectCondition.validate(effect_dict["condition"], template_id):
			errors.append("effects[%d] (%s): %s" % [index, template_id, problem])
	if effect_dict.has("scale"):
		for problem: String in EffectScale.validate(effect_dict["scale"], template_id, params_dict):
			errors.append("effects[%d] (%s): %s" % [index, template_id, problem])
		if not in_trigger and typeof(effect_dict["scale"]) == TYPE_DICTIONARY and String((effect_dict["scale"] as Dictionary).get("by", "")) == EffectScale.EVENT_AMOUNT:
			errors.append("effects[%d] (%s): a scale by event_amount is for relic triggers only" % [index, template_id])


static func _require_non_empty_string(card_data: Dictionary, field: String, errors: Array[String]) -> void:
	var value: Variant = card_data.get(field)
	if typeof(value) != TYPE_STRING or (value as String).is_empty():
		errors.append("'%s' must be a non-empty string" % field)


static func _require_string(card_data: Dictionary, field: String, errors: Array[String]) -> void:
	var value: Variant = card_data.get(field)
	if typeof(value) != TYPE_STRING:
		errors.append("'%s' must be a string" % field)
