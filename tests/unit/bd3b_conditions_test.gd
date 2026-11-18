class_name Bd3bConditionsTest
extends GdUnitTestSuite
## BD3b sitting A, engine 1: the conditions self_stacks_at_least, deck_count_at_least and hp_below (evaluator, validator, text,
## glow, bot). Fixtures only: no shipped card uses them yet.


func before_test() -> void:
	CombatEvents.reset()


func after_test() -> void:
	CombatEvents.reset()


func _target(hp: float = 100.0) -> RelayTarget:
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


func _payoff(condition: Dictionary) -> Dictionary:
	return {"id": "fixture", "effects": [{"template": "aoe", "params": {"damage": 5.0, "damage_type": "neutral", "radius": 2.0}, "condition": condition}]}


# --- evaluator ------------------------------------------------------------------------------

func test_self_stacks_at_least_is_false_true_and_false_again_after_decay() -> void:
	var caster := _target()
	var condition: Dictionary = {"type": "self_stacks_at_least", "status_id": "charge", "count": 3}
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_false()
	_stack_charge(caster, 2)
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_false()
	_stack_charge(caster, 1)
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_true()
	caster.status_manager._process(4.1)
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_false()


func test_deck_count_at_least_counts_copies_of_a_tag() -> void:
	var caster := _target()
	var condition: Dictionary = {"type": "deck_count_at_least", "tag": "Projectile", "count": 2}
	var projectile_id: String = ""
	for card: Variant in CardDatabase.all_cards():
		if CardDatabase.has_tag(String((card as Dictionary)["id"]), "Projectile"):
			projectile_id = String((card as Dictionary)["id"])
			break
	assert_str(projectile_id).is_not_empty()
	var none: Array[String] = []
	var one: Array[String] = [projectile_id]
	var two: Array[String] = [projectile_id, projectile_id]
	assert_bool(EffectCondition.caster_ok(condition, _context(caster, none))).is_false()
	assert_bool(EffectCondition.caster_ok(condition, _context(caster, one))).is_false()
	assert_bool(EffectCondition.caster_ok(condition, _context(caster, two))).is_true()


func test_hp_below_is_strict_and_reads_the_casters_fraction() -> void:
	var caster := _target(100.0)
	var condition: Dictionary = {"type": "hp_below", "fraction": 0.5}
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_false()
	caster.health.current_health = 50.0
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_false()  # exactly 50% is not below
	caster.health.current_health = 49.0
	assert_bool(EffectCondition.caster_ok(condition, _context(caster))).is_true()


func test_a_caster_without_a_hurtbox_has_no_stacks_and_full_hp() -> void:
	var bare := Node3D.new()
	add_child(bare)
	auto_free(bare)
	assert_int(CasterStats.self_stacks(bare, "charge")).is_equal(0)
	assert_float(CasterStats.hp_fraction(bare)).is_equal(1.0)


func test_a_failing_condition_skips_the_effect_and_a_passing_one_runs_it() -> void:
	var caster := _target()
	var params: Dictionary = {"status_id": "charge", "duration": 60.0, "target": "self"}
	var gated: Dictionary = {"type": "self_stacks_at_least", "status_id": "charge", "count": 1}
	EffectTemplates.execute("apply_status", params, _context(caster), gated)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(0)
	EffectTemplates.execute("apply_status", params, _context(caster))
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(1)
	EffectTemplates.execute("apply_status", params, _context(caster), gated)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(2)


func test_the_new_conditions_are_not_target_conditions() -> void:
	for type: String in ["self_stacks_at_least", "deck_count_at_least", "hp_below"]:
		assert_bool(EffectCondition.is_target_condition({"type": type})).is_false()


# --- validation -----------------------------------------------------------------------------

func test_good_new_conditions_validate_on_any_template() -> void:
	var good: Array[Dictionary] = [
		{"type": "self_stacks_at_least", "status_id": "charge", "count": 5},
		{"type": "deck_count_at_least", "tag": "Burn", "count": 6},
		{"type": "hp_below", "fraction": 0.5},
	]
	for condition: Dictionary in good:
		assert_array(EffectCondition.validate(condition, "heal")).is_empty()


func test_bad_new_conditions_fail_validation_loudly() -> void:
	var bad: Array[Dictionary] = [
		{"type": "self_stacks_at_least", "status_id": "nope", "count": 5},
		{"type": "self_stacks_at_least", "count": 5},
		{"type": "self_stacks_at_least", "status_id": "charge", "count": 0},
		{"type": "self_stacks_at_least", "status_id": "charge", "count": 2.5},
		{"type": "self_stacks_at_least", "status_id": "charge", "count": 3, "extra": 1},
		{"type": "deck_count_at_least", "tag": "NotATag", "count": 2},
		{"type": "deck_count_at_least", "count": 2},
		{"type": "deck_count_at_least", "tag": "Burn"},
		{"type": "hp_below", "fraction": 0.0},
		{"type": "hp_below", "fraction": 1.5},
		{"type": "hp_below"},
		{"type": "hp_below", "fraction": "half"},
	]
	for condition: Dictionary in bad:
		assert_bool(EffectCondition.validate(condition, "aoe").is_empty()).override_failure_message("accepted %s" % str(condition)).is_false()


func test_the_card_schema_accepts_a_good_new_condition_and_refuses_a_bad_one() -> void:
	var good: Dictionary = (_payoff({"type": "hp_below", "fraction": 0.5})["effects"] as Array)[0]
	var errors: Array[String] = []
	CardSchema.validate_effect_entry(good, 0, errors)
	assert_array(errors).is_empty()
	var bad: Dictionary = good.duplicate(true)
	bad["condition"] = {"type": "hp_below", "fraction": 7}
	CardSchema.validate_effect_entry(bad, 0, errors)
	assert_bool(errors.is_empty()).is_false()


# --- text, glow and bot ---------------------------------------------------------------------

func test_the_condition_text_reads_the_numbers() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	assert_str(CardSummary.condition_text({"type": "self_stacks_at_least", "status_id": "charge", "count": 5}, text)).is_equal("If you have 5 or more Charge")
	assert_str(CardSummary.condition_text({"type": "deck_count_at_least", "tag": "Burn", "count": 6}, text)).is_equal("If your deck has 6 or more Burn cards")
	assert_str(CardSummary.condition_text({"type": "hp_below", "fraction": 0.5}, text)).is_equal("While below 50% HP")


func test_the_short_slot_cue_reads_the_numbers() -> void:
	var texts: Dictionary = RunConfig.ui().get("slot_condition", {})
	assert_str(ConditionCue.short_text(_payoff({"type": "self_stacks_at_least", "status_id": "charge", "count": 5}), texts)).is_equal("Needs 5 Charge")
	assert_str(ConditionCue.short_text(_payoff({"type": "deck_count_at_least", "tag": "Burn", "count": 6}), texts)).is_equal("Needs 6 Burn cards")
	assert_str(ConditionCue.short_text(_payoff({"type": "hp_below", "fraction": 0.5}), texts)).is_equal("Below 50% HP")


func test_the_synergy_glow_follows_the_view() -> void:
	var stacks_card: Dictionary = _payoff({"type": "self_stacks_at_least", "status_id": "charge", "count": 3})
	assert_bool(SlotSynergy.is_live(stacks_card, {})).is_false()
	assert_bool(SlotSynergy.is_live(stacks_card, {"self_stacks": {"charge": 2}})).is_false()
	assert_bool(SlotSynergy.is_live(stacks_card, {"self_stacks": {"charge": 3}})).is_true()
	var deck_card: Dictionary = _payoff({"type": "deck_count_at_least", "tag": "Projectile", "count": 1})
	assert_bool(SlotSynergy.is_live(deck_card, {"deck_card_ids": []})).is_false()
	var hp_card: Dictionary = _payoff({"type": "hp_below", "fraction": 0.5})
	assert_bool(SlotSynergy.is_live(hp_card, {})).is_false()
	assert_bool(SlotSynergy.is_live(hp_card, {"hp_fraction": 0.4})).is_true()


func test_the_bot_keeps_an_hp_card_near_enemies_and_drops_a_deck_card_it_cannot_satisfy() -> void:
	var policy := PlanPolicy.new()
	var near: Dictionary = {"enemies": [{"pos": Vector3.ZERO, "statuses": []}]}
	var hp_card: Dictionary = _payoff({"type": "hp_below", "fraction": 0.5})
	assert_bool(policy.can_pay_off_soon(hp_card, "attack_aoe", {}, near)).is_true()
	assert_bool(policy.can_pay_off_soon(hp_card, "attack_aoe", {}, {})).is_false()
	var deck_card: Dictionary = _payoff({"type": "deck_count_at_least", "tag": "Projectile", "count": 1})
	assert_bool(policy.can_pay_off_soon(deck_card, "attack_aoe", {}, near)).is_false()
	var stacks_card: Dictionary = _payoff({"type": "self_stacks_at_least", "status_id": "charge", "count": 2})
	assert_bool(policy.can_pay_off_soon(stacks_card, "attack_aoe", {}, {"self_stacks": {"charge": 2}})).is_true()
	assert_bool(policy.can_pay_off_soon(stacks_card, "attack_aoe", {}, near)).is_false()


func test_run_json_carries_the_wording_for_every_new_condition() -> void:
	var effect: Dictionary = RunConfig.ui()["effect"]["condition"]
	var cue: Dictionary = RunConfig.ui()["slot_condition"]
	for type: String in ["self_stacks_at_least", "deck_count_at_least", "hp_below"]:
		assert_bool(effect.has(type)).is_true()
		assert_bool(cue.has(type)).is_true()
