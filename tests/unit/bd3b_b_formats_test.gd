class_name Bd3bBFormatsTest
extends GdUnitTestSuite
## BD3b sitting B, engine 2: the exact data shapes sitting C1 (Spiteful Ward's buff trigger) and C2 (Exit Strategy's relic) will write, as JSON text
## run through the real validators, and the bad buff `triggers` blocks that must fail loudly. Fixtures, not shipped data.

const WARD_JSON := '{"template": "buff", "params": {"stat": "armor", "modifier_type": "additive", "value": 25, "duration": 4.0, "triggers": [{"event": "player_damaged", "filter": {}, "at": "player", "internal_cooldown": 0.5, "effects": [{"template": "aoe", "params": {"damage": 6, "damage_type": "neutral", "radius": 2.5}}]}]}}'

const EXIT_STRATEGY_JSON := '{"id": "exit_strategy", "name": "Exit Strategy", "pool": "fire", "rarity": "tier1", "sources": ["elite", "relic_room", "merchant"], "keywords": ["Dash"], "modifiers": [], "triggers": [{"event": "dash_ended", "filter": {}, "at": "event_path", "effects": [{"template": "zone", "params": {"shape": "line", "length": 1.0, "width": 1.0, "duration": 2.0, "tick_interval": 0.5, "damage": 2, "damage_type": "fire", "max_range": 1.0}}]}], "rule_text": "Movement cards leave a 2 s line of fire along the path.", "flavor_text": "A fire exit, as the regulations require."}'


func _ward() -> Dictionary:
	return JSON.parse_string(WARD_JSON)


func _problems(effect: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	CardSchema.validate_effect_entry(effect, 0, errors)
	return errors


func _with_trigger(mutate: Callable) -> Dictionary:
	var effect: Dictionary = _ward()
	mutate.call(((effect["params"] as Dictionary)["triggers"] as Array)[0])
	return effect


func _expect_rejected(effect: Dictionary, fragment: String) -> void:
	var errors := _problems(effect)
	assert_bool(errors.any(func(e: String) -> bool: return e.contains(fragment))).override_failure_message("expected a problem mentioning '%s', got %s" % [fragment, errors]).is_true()


func test_spiteful_wards_buff_trigger_validates() -> void:
	assert_array(_problems(_ward())).is_empty()


func test_exit_strategys_relic_validates_through_the_relic_schema() -> void:
	var relic: Dictionary = JSON.parse_string(EXIT_STRATEGY_JSON)
	assert_array(RelicSchema.validate(relic, "exit_strategy")).is_empty()


func test_the_event_path_is_only_for_a_dash_end_and_only_lays_lines() -> void:
	var relic: Dictionary = JSON.parse_string(EXIT_STRATEGY_JSON)
	((relic["triggers"] as Array)[0] as Dictionary)["event"] = "hit_landed"
	assert_bool(RelicSchema.validate(relic, "exit_strategy").any(func(e: String) -> bool: return e.contains("has no path"))).is_true()
	relic = JSON.parse_string(EXIT_STRATEGY_JSON)
	var params: Dictionary = ((((relic["triggers"] as Array)[0] as Dictionary)["effects"] as Array)[0] as Dictionary)["params"]
	params.erase("length")
	params.erase("width")
	params["shape"] = "circle"
	params["radius"] = 2.0
	assert_bool(RelicSchema.validate(relic, "exit_strategy").any(func(e: String) -> bool: return e.contains("must be a line"))).is_true()


func _with_params(key: String, value: Variant) -> Dictionary:
	var effect: Dictionary = _ward()
	(effect["params"] as Dictionary)[key] = value
	return effect


func _set_trigger(key: String, value: Variant) -> Dictionary:
	return _with_trigger(func(t: Dictionary) -> void: t[key] = value)


func test_a_bad_buff_triggers_block_fails_validation() -> void:
	var too_many: Dictionary = _ward()
	var list: Array = (too_many["params"] as Dictionary)["triggers"]
	for i in range(4):
		list.append((list[0] as Dictionary).duplicate(true))
	var bad_effect: Dictionary = _with_trigger(func(t: Dictionary) -> void: ((t["effects"] as Array)[0] as Dictionary)["params"] = {"damage": 6})
	var cases: Array = [
		[_with_params("triggers", "player_damaged"), "'triggers' must be a non-empty array"],
		[_with_params("triggers", []), "'triggers' must be a non-empty array"],
		[_with_params("triggers", [5]), "must be an object"],
		[_set_trigger("event", "nope"), "event must be one of"],
		[_set_trigger("filter", {"colour": "red"}), "unknown key 'colour'"],
		[_set_trigger("cooldown", 1.0), "unknown key 'cooldown'"],
		[_set_trigger("internal_cooldown", -1.0), "internal_cooldown"],
		[_set_trigger("effects", []), "effects must be a non-empty array"],
		[bad_effect, "missing required param"],
		[_set_trigger("at", "event_target"), "has no target"],
		[_with_params("consume_on_cast", "attack_single"), "consume_on_cast"],
		[_set_trigger("effects", [_ward()]), "cannot carry 'triggers'"],
		[too_many, "at most"],
	]
	for entry: Array in cases:
		_expect_rejected(entry[0] as Dictionary, String(entry[1]))


func test_a_buff_without_triggers_validates_as_before() -> void:
	var effect: Dictionary = _ward()
	(effect["params"] as Dictionary).erase("triggers")
	assert_array(_problems(effect)).is_empty()
