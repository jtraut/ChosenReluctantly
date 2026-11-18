class_name Bd3bScaleTest
extends GdUnitTestSuite
## BD3b sitting A, engine 1: the `scale` resolver (self_stacks and deck_count), its validator, CardSummary text, the preview values and
## the CardDamageRule. Fixtures only: no shipped card uses `scale` yet.


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


func _stack_charge(caster: RelayTarget, times: int) -> void:
	for i in range(times):
		caster.status_manager.apply_status("charge", StatusDatabase.get_status("charge"), 60.0, caster, "card:test")


func _tagged(tag: String, copies: int) -> Array[String]:
	var found: String = ""
	for card: Variant in CardDatabase.all_cards():
		if CardDatabase.has_tag(String((card as Dictionary)["id"]), tag):
			found = String((card as Dictionary)["id"])
			break
	var ids: Array[String] = []
	for i in range(copies):
		ids.append(found)
	return ids


func _stacks_scale(extra: Dictionary = {}) -> Dictionary:
	var scale: Dictionary = {"by": "self_stacks", "status_id": "charge", "per": 1.5}
	scale.merge(extra, true)
	return scale


func _deck_scale(extra: Dictionary = {}) -> Dictionary:
	var scale: Dictionary = {"by": "deck_count", "tag": "Projectile", "per": 0.5}
	scale.merge(extra, true)
	return scale


const BASE: Dictionary = {"damage": 7.0, "damage_type": "neutral", "speed": 10.0, "max_range": 8.0, "hit_radius": 0.5}


# --- resolver: self_stacks ------------------------------------------------------------------

func test_self_stacks_adds_per_stack_to_the_base() -> void:
	var caster := _caster()
	_stack_charge(caster, 4)
	var params: Dictionary = EffectScale.apply(_stacks_scale(), "projectile", BASE, _context(caster))
	assert_float(float(params["damage"])).is_equal_approx(7.0 + 6.0, 0.0001)


func test_no_stacks_leaves_the_base_alone() -> void:
	var params: Dictionary = EffectScale.apply(_stacks_scale(), "projectile", BASE, _context(_caster()))
	assert_float(float(params["damage"])).is_equal(7.0)


func test_the_card_data_params_are_never_changed() -> void:
	var caster := _caster()
	_stack_charge(caster, 4)
	var original: Dictionary = BASE.duplicate()
	EffectScale.apply(_stacks_scale(), "projectile", original, _context(caster))
	assert_float(float(original["damage"])).is_equal(7.0)


func test_max_caps_the_count_not_the_bonus() -> void:
	var caster := _caster()
	_stack_charge(caster, 8)
	var params: Dictionary = EffectScale.apply(_stacks_scale({"max": 3}), "projectile", BASE, _context(caster))
	assert_float(float(params["damage"])).is_equal_approx(7.0 + 4.5, 0.0001)


func test_without_consume_the_stacks_stay() -> void:
	var caster := _caster()
	_stack_charge(caster, 4)
	EffectScale.apply(_stacks_scale(), "projectile", BASE, _context(caster))
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(4)


func test_consume_removes_the_status_once_even_stacks_above_max() -> void:
	var caster := _caster()
	_stack_charge(caster, 8)
	var ended: Array[String] = []
	caster.status_manager.status_expired.connect(func(id: String) -> void: ended.append(id))
	var params: Dictionary = EffectScale.apply(_stacks_scale({"max": 3, "consume": true}), "projectile", BASE, _context(caster))
	assert_float(float(params["damage"])).is_equal_approx(7.0 + 4.5, 0.0001)
	assert_bool(caster.status_manager.has_status("charge")).is_false()
	assert_array(ended).is_equal(["charge"])


func test_consume_with_no_stacks_does_nothing() -> void:
	var caster := _caster()
	var params: Dictionary = EffectScale.apply(_stacks_scale({"consume": true}), "projectile", BASE, _context(caster))
	assert_float(float(params["damage"])).is_equal(7.0)


func test_execute_scales_a_heal_and_consumes_once() -> void:
	var caster := _caster(100.0)
	caster.health.current_health = 10.0
	_stack_charge(caster, 4)
	var scale: Dictionary = _stacks_scale({"consume": true})
	EffectTemplates.execute("heal", {"amount": 5.0}, _context(caster), {}, scale)
	assert_float(caster.health.current_health).is_equal_approx(10.0 + 5.0 + 6.0, 0.001)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(0)


func test_a_failed_condition_neither_scales_nor_consumes() -> void:
	var caster := _caster(100.0)
	caster.health.current_health = 10.0
	_stack_charge(caster, 4)
	var condition: Dictionary = {"type": "hp_below", "fraction": 0.05}
	EffectTemplates.execute("heal", {"amount": 5.0}, _context(caster), condition, _stacks_scale({"consume": true}))
	assert_float(caster.health.current_health).is_equal(10.0)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(4)


# --- resolver: deck_count -------------------------------------------------------------------

func test_deck_count_with_a_max_stops_at_the_cap() -> void:
	var caster := _caster()
	var deck: Array[String] = _tagged("Projectile", 10)
	var params: Dictionary = EffectScale.apply(_deck_scale({"max": 6}), "projectile", BASE, _context(caster, deck))
	assert_float(float(params["damage"])).is_equal_approx(7.0 + 3.0, 0.0001)


func test_deck_count_below_the_max_counts_every_card() -> void:
	var deck: Array[String] = _tagged("Projectile", 4)
	var params: Dictionary = EffectScale.apply(_deck_scale({"max": 6}), "projectile", BASE, _context(_caster(), deck))
	assert_float(float(params["damage"])).is_equal_approx(7.0 + 2.0, 0.0001)


func test_deck_count_without_a_max_is_unbounded() -> void:
	var deck: Array[String] = _tagged("Projectile", 10)
	var params: Dictionary = EffectScale.apply(_deck_scale(), "projectile", BASE, _context(_caster(), deck))
	assert_float(float(params["damage"])).is_equal_approx(7.0 + 5.0, 0.0001)


func test_deck_count_ignores_cards_without_the_tag_and_an_empty_deck() -> void:
	var params: Dictionary = EffectScale.apply(_deck_scale(), "projectile", BASE, _context(_caster()))
	assert_float(float(params["damage"])).is_equal(7.0)


# --- validation -----------------------------------------------------------------------------

func test_good_scale_blocks_validate() -> void:
	assert_array(EffectScale.validate(_stacks_scale({"max": 10, "consume": true}), "projectile", BASE)).is_empty()
	assert_array(EffectScale.validate(_stacks_scale(), "aoe", {"damage": 3.0, "damage_type": "neutral", "radius": 2.0})).is_empty()
	assert_array(EffectScale.validate(_deck_scale({"max": 6}), "cone", {"damage": 3.0})).is_empty()
	assert_array(EffectScale.validate(_deck_scale(), "projectile", BASE)).is_empty()
	assert_array(EffectScale.validate({"by": "self_stacks", "status_id": "charge", "per": 2.0, "param": "amount"}, "heal", {"amount": 4.0})).is_empty()


func test_bad_scale_blocks_fail_validation_loudly() -> void:
	var bad: Array[Dictionary] = [
		{},
		{"by": "nope", "per": 1.0},
		{"by": "self_stacks", "per": 1.0},
		{"by": "self_stacks", "status_id": "nope", "per": 1.0},
		{"by": "self_stacks", "status_id": "charge"},
		{"by": "self_stacks", "status_id": "charge", "per": 0.0},
		{"by": "self_stacks", "status_id": "charge", "per": -1.0},
		{"by": "self_stacks", "status_id": "charge", "per": "1"},
		{"by": "self_stacks", "status_id": "charge", "per": 1.0, "max": 0},
		{"by": "self_stacks", "status_id": "charge", "per": 1.0, "max": 2.5},
		{"by": "self_stacks", "status_id": "charge", "per": 1.0, "consume": "yes"},
		{"by": "self_stacks", "status_id": "charge", "per": 1.0, "tag": "Burn"},
		{"by": "self_stacks", "status_id": "charge", "per": 1.0, "param": "radius"},
		{"by": "deck_count", "per": 0.5},
		{"by": "deck_count", "tag": "NotATag", "per": 0.5},
		{"by": "deck_count", "tag": "Burn", "per": 0.5, "consume": true},
		{"by": "deck_count", "tag": "Burn", "per": 0.5, "status_id": "charge"},
	]
	for scale: Dictionary in bad:
		assert_bool(EffectScale.validate(scale, "projectile", BASE).is_empty()).override_failure_message("accepted %s" % str(scale)).is_false()
	assert_bool(EffectScale.validate("x", "projectile", BASE).is_empty()).is_false()


func test_a_scale_needs_a_template_that_can_carry_it_and_a_base_param() -> void:
	assert_bool(EffectScale.validate(_stacks_scale(), "buff", {"stat": "x", "modifier_type": "additive", "value": 1.0, "duration": 2.0}).is_empty()).is_false()
	assert_bool(EffectScale.validate(_stacks_scale(), "apply_status", {"status_id": "burn", "duration": 3.0}).is_empty()).is_false()
	assert_bool(EffectScale.validate(_stacks_scale(), "projectile", {"damage_type": "neutral"}).is_empty()).is_false()


func test_the_card_and_relic_schema_check_scale_too() -> void:
	var effect: Dictionary = {"template": "projectile", "params": BASE.duplicate(), "scale": _stacks_scale()}
	var errors: Array[String] = []
	CardSchema.validate_effect_entry(effect, 0, errors)
	assert_array(errors).is_empty()
	effect["scale"] = {"by": "self_stacks", "status_id": "charge", "per": 0.0}
	CardSchema.validate_effect_entry(effect, 0, errors)
	assert_bool(errors.is_empty()).is_false()
	assert_str(" ".join(errors)).contains("scale")


# --- text, preview, damage rule -------------------------------------------------------------

func test_the_summary_words_a_scaled_effect() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	var card: Dictionary = {"id": "fixture", "effects": [{"template": "projectile", "params": BASE.duplicate(), "scale": _stacks_scale({"consume": true})}]}
	var line: String = CardSummary.effect_line(card, -1.0, text)
	assert_str(line).contains("7 neutral damage")
	assert_str(line).contains("+1.5 per Charge")
	assert_str(line).contains("uses up your Charge")
	var deck_card: Dictionary = {"id": "fixture", "effects": [{"template": "projectile", "params": BASE.duplicate(), "scale": _deck_scale({"max": 6})}]}
	var deck_line: String = CardSummary.effect_line(deck_card, -1.0, text)
	assert_str(deck_line).contains("+0.5 per Projectile card in your deck (up to +3)")


func test_the_preview_values_are_the_live_numbers_and_consume_nothing() -> void:
	var caster := _caster()
	_stack_charge(caster, 4)
	var card: Dictionary = {"id": "fixture", "effects": [{"template": "projectile", "params": BASE.duplicate(), "scale": _stacks_scale({"max": 3, "consume": true})}]}
	var values: Array[Dictionary] = EffectScale.preview_values(card, caster, [])
	assert_int(values.size()).is_equal(1)
	assert_float(float(values[0]["base"])).is_equal(7.0)
	assert_float(float(values[0]["value"])).is_equal_approx(11.5, 0.0001)
	assert_int(int(values[0]["count"])).is_equal(3)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(4)
	assert_array(EffectScale.preview_values({"id": "plain", "effects": [{"template": "projectile", "params": BASE.duplicate()}]}, caster, [])).is_empty()


func test_scaled_damage_does_not_count_for_the_card_damage_rule() -> void:
	var plain: Dictionary = {"id": "p", "slot_type": "attack_single", "effects": [{"template": "projectile", "params": BASE.duplicate()}]}
	var scaled: Dictionary = {"id": "s", "slot_type": "attack_single", "effects": [{"template": "projectile", "params": BASE.duplicate(), "scale": _stacks_scale({"max": 10})}]}
	assert_float(CardDamageRule.cast_damage(scaled, {}, 2.0)).is_equal(CardDamageRule.cast_damage(plain, {}, 2.0))
	assert_float(CardDamageRule.cast_damage(scaled, {}, 2.0)).is_equal(7.0)
