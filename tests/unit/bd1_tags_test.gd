class_name Bd1TagsTest
extends GdUnitTestSuite
## BD1-A item 1: derived tags, keywords.json, the keywords field, and the tag API. Uses test-only card dictionaries.


func _card(effects: Array, keywords: Variant = null) -> Dictionary:
	var card: Dictionary = {
		"id": "test_tag_card", "name": "Tag Card", "slot_type": "attack_single", "pool": "rogue",
		"cooldown_modifier": 0.0, "flavor_text": "x", "effects": effects,
	}
	if keywords != null:
		card["keywords"] = keywords
	return card


func _fx(template: String, params: Dictionary) -> Dictionary:
	return {"template": template, "params": params}


func test_projectile_tag() -> void:
	var tags := CardTags.derive(_card([_fx("projectile", {"damage": 5, "damage_type": "fire", "speed": 10, "max_range": 10, "hit_radius": 0.3})]))
	assert_array(tags).is_equal(["Projectile"])


func test_cone_is_melee() -> void:
	assert_array(CardTags.derive(_card([_fx("cone", {"damage": 5, "damage_type": "physical", "range": 2, "half_angle_degrees": 45})]))).is_equal(["Melee"])


func test_aoe_and_zone_tags() -> void:
	assert_array(CardTags.derive(_card([_fx("aoe", {"damage": 5, "damage_type": "fire", "radius": 2})]))).is_equal(["Area"])
	var zone := _fx("zone", {"shape": "circle", "radius": 2, "duration": 4, "tick_interval": 0.5, "damage": 2, "damage_type": "fire", "max_range": 6})
	assert_array(CardTags.derive(_card([zone]))).is_equal(["Zone"])


func test_dash_without_damage_is_dash_only_and_with_damage_is_melee_and_dash() -> void:
	assert_array(CardTags.derive(_card([_fx("dash", {"distance": 4, "speed": 20})]))).is_equal(["Dash"])
	var hurting := _fx("dash", {"distance": 4, "speed": 20, "damage": 3, "damage_type": "physical", "hit_radius": 1})
	assert_array(CardTags.derive(_card([hurting]))).is_equal(["Melee", "Dash"])


func test_pass_through_is_dash() -> void:
	assert_array(CardTags.derive(_card([_fx("pass_through", {"duration": 2})]))).is_equal(["Dash"])


func test_heal_and_buff_tags() -> void:
	assert_array(CardTags.derive(_card([_fx("heal", {"amount": 5})]))).is_equal(["Heal"])
	assert_array(CardTags.derive(_card([_fx("buff", {"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.2, "duration": 3})]))).is_equal(["Buff"])


func test_burn_and_bleed_come_from_apply_status() -> void:
	assert_array(CardTags.derive(_card([_fx("apply_status", {"status_id": "burn", "duration": 3})]))).is_equal(["Burn"])
	assert_array(CardTags.derive(_card([_fx("apply_status", {"status_id": "bleed", "duration": 3})]))).is_equal(["Bleed"])


func test_a_zone_status_counts() -> void:
	var zone := _fx("zone", {"shape": "circle", "radius": 2, "duration": 4, "tick_interval": 0.5, "damage": 2, "damage_type": "fire", "max_range": 6, "status_id": "burn", "status_duration": 3})
	assert_array(CardTags.derive(_card([zone]))).is_equal(["Zone", "Burn"])


func test_heal_over_time_and_lifesteal_statuses_are_heal() -> void:
	assert_array(CardTags.derive(_card([_fx("apply_status", {"status_id": "regeneration", "duration": 5, "target": "self"})]))).is_equal(["Heal"])
	assert_array(CardTags.derive(_card([_fx("apply_status", {"status_id": "leech", "duration": 5, "target": "self"})]))).is_equal(["Heal"])


func test_a_stun_status_adds_no_tag() -> void:
	assert_array(CardTags.derive(_card([_fx("apply_status", {"status_id": "stun", "duration": 1})]))).is_empty()


func test_tags_are_in_canonical_order_without_duplicates() -> void:
	var effects: Array = [
		_fx("apply_status", {"status_id": "burn", "duration": 3}),
		_fx("aoe", {"damage": 5, "damage_type": "fire", "radius": 2}),
		_fx("aoe", {"damage": 5, "damage_type": "fire", "radius": 2, "vfx": false}),
		_fx("projectile", {"damage": 5, "damage_type": "fire", "speed": 10, "max_range": 10, "hit_radius": 0.3}),
	]
	assert_array(CardTags.derive(_card(effects))).is_equal(["Projectile", "Area", "Burn"])


func test_conditional_effects_still_count() -> void:
	var effect := _fx("aoe", {"damage": 5, "damage_type": "fire", "radius": 2})
	effect["condition"] = {"type": "zone_active"}
	assert_array(CardTags.derive(_card([effect]))).is_equal(["Area"])


func test_keywords_follow_derived_tags() -> void:
	var card := _card([_fx("heal", {"amount": 1})], ["Primer", "Keystone"])
	assert_array(CardTags.all_tags(card)).is_equal(["Heal", "Primer", "Keystone"])
	assert_array(CardTags.keywords_of(card)).is_equal(["Primer", "Keystone"])


func test_keywords_json_has_the_three_keywords_with_text() -> void:
	for keyword_id: String in ["Primer", "Payoff", "Keystone"]:
		assert_bool(KeywordDatabase.has(keyword_id)).is_true()
		assert_str(KeywordDatabase.display_name(keyword_id)).is_not_empty()
		assert_str(KeywordDatabase.rule_text(keyword_id)).is_not_empty()
	assert_array(KeywordDatabase.validate_table()).is_empty()


func test_unknown_keyword_is_a_validation_error() -> void:
	var card := _card([_fx("heal", {"amount": 1})], ["Primer", "Bogus"])
	var errors := CardSchema.validate(card)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("Bogus")


func test_keywords_must_be_an_array_of_unique_strings() -> void:
	assert_array(CardSchema.validate(_card([_fx("heal", {"amount": 1})], "Primer"))).is_not_empty()
	assert_array(CardSchema.validate(_card([_fx("heal", {"amount": 1})], ["Primer", "Primer"]))).is_not_empty()
	assert_array(CardSchema.validate(_card([_fx("heal", {"amount": 1})], [3]))).is_not_empty()


func test_a_card_without_keywords_is_valid_and_a_known_keyword_passes() -> void:
	assert_array(CardSchema.validate(_card([_fx("heal", {"amount": 1})]))).is_empty()
	assert_array(CardSchema.validate(_card([_fx("heal", {"amount": 1})], ["Payoff"]))).is_empty()


func test_is_known_tag_accepts_derived_and_keywords_only() -> void:
	assert_bool(CardTags.is_known_tag("Burn")).is_true()
	assert_bool(CardTags.is_known_tag("Keystone")).is_true()
	assert_bool(CardTags.is_known_tag("burn")).is_false()
	assert_bool(CardTags.is_known_tag("Nope")).is_false()


func test_database_exposes_tags_for_shipped_cards() -> void:
	assert_bool(CardDatabase.has_tag("fire_fireball", "Area")).is_true()
	assert_bool(CardDatabase.has_tag("fire_fireball", "Zone")).is_false()
	assert_array(CardDatabase.tags_for("no_such_card")).is_empty()
	for card: Dictionary in CardDatabase.all_cards():
		assert_array(CardDatabase.tags_for(String(card["id"]))).is_equal(CardTags.all_tags(card))
