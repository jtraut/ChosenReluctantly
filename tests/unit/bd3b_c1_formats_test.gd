class_name Bd3bC1FormatsTest
extends GdUnitTestSuite
## BD3b sitting A, engine 1: the exact data shapes sitting C1 will write, run through the real validators and the real executor, so the
## examples in the hand-back cannot drift from what the engine accepts. These are fixtures, not shipped cards.


func before_test() -> void:
	CombatEvents.reset()


func after_test() -> void:
	CombatEvents.reset()


func _caster(hp: float = 100.0) -> RelayTarget:
	var target := RelayTarget.new("player", hp)
	add_child(target)
	auto_free(target)
	return target


func _context(caster: Node3D, deck: Array[String] = []) -> EffectContext:
	var context := EffectContext.new(caster, self, "player")
	context.deck_card_ids = deck
	return context


func _valid(effect: Dictionary) -> void:
	var errors: Array[String] = []
	CardSchema.validate_effect_entry(effect, 0, errors)
	assert_array(errors).is_empty()


func _give_charge() -> Dictionary:
	return {"template": "apply_status", "params": {"status_id": "charge", "duration": 4.0, "target": "self"}}


func test_thesis_defense_payoff_effect_validates_and_scales_and_consumes() -> void:
	var effect: Dictionary = {"template": "projectile", "params": {"damage": 7.0, "damage_type": "neutral", "speed": 14.0, "max_range": 12.0, "hit_radius": 0.5},
			"scale": {"by": "self_stacks", "status_id": "charge", "per": 1.5, "consume": true}}
	_valid(effect)
	var caster := _caster()
	for i in range(4):
		EffectTemplates.execute("apply_status", (_give_charge()["params"] as Dictionary), _context(caster))
	var scaled: Dictionary = EffectScale.apply(effect["scale"], "projectile", effect["params"], _context(caster))
	assert_float(float(scaled["damage"])).is_equal_approx(13.0, 0.0001)
	assert_bool(caster.status_manager.has_status("charge")).is_false()


func test_a_primer_gives_two_charge_with_two_self_apply_status_effects() -> void:
	var effects: Array = [{"template": "projectile", "params": {"damage": 1.8, "damage_type": "neutral", "speed": 14.0, "max_range": 12.0, "hit_radius": 0.4, "hits": 4, "hit_interval": 0.1}},
			_give_charge(), _give_charge()]
	for i in range(effects.size()):
		var errors: Array[String] = []
		CardSchema.validate_effect_entry(effects[i], i, errors)
		assert_array(errors).is_empty()
	var caster := _caster()
	for effect: Dictionary in [effects[1], effects[2]]:
		EffectTemplates.execute("apply_status", effect["params"], _context(caster))
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(2)


func test_citation_needed_scales_with_projectile_cards_up_to_six() -> void:
	var effect: Dictionary = {"template": "projectile", "params": {"damage": 6.0, "damage_type": "neutral", "speed": 14.0, "max_range": 12.0, "hit_radius": 0.5},
			"scale": {"by": "deck_count", "tag": "Projectile", "per": 0.5, "max": 6}}
	_valid(effect)


func test_hostile_feedback_adds_a_conditional_second_hit_below_half_hp() -> void:
	var base: Dictionary = {"template": "aoe", "params": {"damage": 12.0, "damage_type": "neutral", "radius": 2.5}}
	var extra: Dictionary = {"template": "aoe", "params": {"damage": 8.0, "damage_type": "neutral", "radius": 2.5, "knockback_strength": 6.0},
			"condition": {"type": "hp_below", "fraction": 0.5}}
	_valid(base)
	_valid(extra)


func test_reading_list_validates_as_a_data_only_relic_and_raises_the_charge_cap() -> void:
	var relic: Dictionary = {"id": "reading_list", "name": "Reading List", "pool": "wizard", "rarity": "tier2", "sources": ["elite", "relic_room", "merchant"],
			"keywords": [], "modifiers": [{"stat": "status_max_stacks.charge", "modifier_type": "additive", "value": 5}], "triggers": [],
			"rule_text": "Your Charge stacks to 15.", "flavor_text": "Required reading. Optional comprehension."}
	assert_array(RelicSchema.validate(relic, "reading_list")).is_empty()
	var caster := _caster()
	var source := StatSource.new()
	add_child(source)
	auto_free(source)
	source.stat_modifiers.add_modifier("status_max_stacks.charge", "relic:reading_list", StatModifiers.ADDITIVE, 5.0)
	for i in range(20):
		caster.status_manager.apply_status("charge", StatusDatabase.get_status("charge"), 4.0, source, "card:test")
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(15)


func test_a_relic_effect_may_carry_a_scale_and_a_bad_one_fails_the_relic_schema() -> void:
	var relic: Dictionary = {"id": "fixture_relic", "name": "Fixture", "pool": "neutral", "rarity": "tier1", "sources": ["elite"], "keywords": [], "modifiers": [],
			"triggers": [{"event": "card_cast", "filter": {}, "at": "player", "internal_cooldown": 0.0,
					"effects": [{"template": "heal", "params": {"amount": 2.0}, "scale": {"by": "deck_count", "tag": "Burn", "per": 0.5, "max": 4}}]}],
			"rule_text": "Heal 2 plus 0.5 per Burn card.", "flavor_text": "x"}
	var good_errors: Array[String] = RelicSchema.validate(relic, "fixture_relic")
	assert_array(good_errors).is_empty()
	((relic["triggers"] as Array)[0]["effects"] as Array)[0]["scale"]["per"] = 0.0
	assert_bool(RelicSchema.validate(relic, "fixture_relic").is_empty()).is_false()
