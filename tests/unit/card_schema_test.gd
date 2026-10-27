class_name CardSchemaTest
extends GdUnitTestSuite
## Validates against real data/slot_types.json and data/pools.json - that's
## the point of this schema (does a card reference a real slot/pool), so
## using the real project data here is correct, not a test smell.


func _valid_card() -> Dictionary:
	return {
		"id": "test_quick_slash",
		"name": "Quick, I Guess",
		"slot_type": "attack_single",
		"pool": "rogue",
		"cooldown_modifier": -0.3,
		"flavor_text": "Fine, I'll stab it.",
		"effects": [
			{"template": "cone", "params": {"damage": 6, "damage_type": "physical", "range": 2.0, "half_angle_degrees": 45}},
		],
	}


func test_valid_card_has_no_errors() -> void:
	assert_array(CardSchema.validate(_valid_card())).is_empty()


func test_missing_id_is_an_error() -> void:
	var card := _valid_card()
	card.erase("id")
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_empty_name_is_an_error() -> void:
	var card := _valid_card()
	card["name"] = ""
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_unknown_slot_type_is_an_error() -> void:
	var card := _valid_card()
	card["slot_type"] = "attack_ultra_mega"
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_unknown_pool_is_an_error() -> void:
	var card := _valid_card()
	card["pool"] = "water"
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_non_numeric_cooldown_modifier_is_an_error() -> void:
	var card := _valid_card()
	card["cooldown_modifier"] = "fast"
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_empty_effects_array_is_an_error() -> void:
	var card := _valid_card()
	card["effects"] = []
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_unknown_effect_template_is_an_error() -> void:
	var card := _valid_card()
	card["effects"] = [{"template": "nuke_the_moon", "params": {}}]
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_effect_missing_a_required_param_is_an_error() -> void:
	var card := _valid_card()
	card["effects"] = [{"template": "cone", "params": {"damage": 6}}]
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_effect_with_all_required_params_is_valid() -> void:
	var card := _valid_card()
	card["effects"] = [{"template": "heal", "params": {"amount": 10}}]
	assert_array(CardSchema.validate(card)).is_empty()
