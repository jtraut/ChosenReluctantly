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
	if typeof(effects) != TYPE_ARRAY or (effects as Array).is_empty():
		errors.append("effects must be a non-empty array")
		return
	var effects_array: Array = effects
	for i in range(effects_array.size()):
		_validate_effect(effects_array[i], i, errors)


## Checks one effect entry ({template, params, condition?}) the way a card's effects are checked. Relics reuse it, so a
## relic effect and a card effect can never be validated differently. Problems read "effects[<index>] ...".
static func validate_effect_entry(effect: Variant, index: int, errors: Array[String]) -> void:
	_validate_effect(effect, index, errors)


static func _validate_effect(effect: Variant, index: int, errors: Array[String]) -> void:
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


static func _require_non_empty_string(card_data: Dictionary, field: String, errors: Array[String]) -> void:
	var value: Variant = card_data.get(field)
	if typeof(value) != TYPE_STRING or (value as String).is_empty():
		errors.append("'%s' must be a non-empty string" % field)


static func _require_string(card_data: Dictionary, field: String, errors: Array[String]) -> void:
	var value: Variant = card_data.get(field)
	if typeof(value) != TYPE_STRING:
		errors.append("'%s' must be a string" % field)
