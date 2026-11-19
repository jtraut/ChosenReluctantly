class_name Bd3bD2PlanTest
extends GdUnitTestSuite
## BD3b-D2: PlanPolicy plays Charge (primers first, the spender at 6+ stacks or before the stacks decay) and a triggered buff
## (Spiteful Ward) before contact. Decisions on fabricated slots and views; the rules key on card data, never a card id.


func before_test() -> void:
	CardDatabase.load_all()


func _slot(slot_type: String, cards: Array[String], ready_in: float = 0.0) -> CardSlot:
	var slot := CardSlot.new(slot_type, 3.0, cards, 1.0, null)
	slot.cooldown_remaining = ready_in
	slot.current_card_id = cards[0]
	return slot


func _slots(single: Array[String], aoe: Array[String], utility: Array[String] = ["wizard_ward"] as Array[String]) -> Dictionary:
	return {
		"attack_single": _slot("attack_single", single), "attack_aoe": _slot("attack_aoe", aoe),
		"utility": _slot("utility", utility), "movement": _slot("movement", ["wizard_sideways_blink"] as Array[String]),
		"recovery": _slot("recovery", ["neutral_healing_potion"] as Array[String]),
	}


func _view(enemies: Array, stacks: int = 0, decay_left: float = 4.0, now: float = 10.0, history: CastHistory = null) -> Dictionary:
	var self_stacks: Dictionary = {"charge": stacks} if stacks > 0 else {}
	var decay: Dictionary = {"charge": decay_left} if stacks > 0 else {}
	return {"now": now, "history": history, "zone_count": 0, "origin": Vector3.ZERO, "forward": Vector3(0, 0, -1), "aim_point": Vector3(0, 0, -2), "arena": Rect2(),
			"enemies": enemies, "self_stacks": self_stacks, "self_decay_left": decay}


func _enemy(z: float) -> Dictionary:
	return {"pos": Vector3(0, 0, z), "statuses": []}


func test_the_spender_is_found_by_its_scale_block_not_its_id() -> void:
	assert_str(String(PlanPolicy.spender_scale(CardDatabase.get_card("wizard_thesis_defense")).get("status_id", ""))).is_equal("charge")
	assert_bool(PlanPolicy.spender_scale(CardDatabase.get_card("wizard_citation_needed")).is_empty()).is_true()  # a deck_count scale is not a spender
	assert_bool(PlanPolicy.spender_scale(CardDatabase.get_card("wizard_footnotes")).is_empty()).is_true()


func test_the_keystone_fires_at_six_charge() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_thesis_defense", "wizard_footnotes"] as Array[String], ["wizard_literature_review"] as Array[String])
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 6), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 9), 1.0, false, true)).is_equal(PlanPolicy.CAST)


func test_the_keystone_waits_for_more_charge_while_a_primer_is_ready_and_stacks_are_not_decaying() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_thesis_defense", "wizard_footnotes"] as Array[String], ["wizard_literature_review"] as Array[String])
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 2, 3.5, 10.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)
	# Long after the hold limit it still waits: the Literature Review in the other slot keeps adding, and the decay rule bounds the wait.
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 2, 3.5, 14.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_the_keystone_fires_before_its_stacks_decay() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_thesis_defense", "wizard_footnotes"] as Array[String], ["wizard_literature_review"] as Array[String])
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 2, 0.8), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	# Out of reach it does not fire (the shot would be wasted); nothing hit means the stacks are not spent.
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-30.0)], 2, 0.8), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_with_no_charge_and_no_primer_coming_the_keystone_is_swapped_away_or_cast_after_the_hold() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_thesis_defense", "wizard_footnotes"] as Array[String], ["wizard_arcane_nova"] as Array[String])
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)]), 1.0, false, true)).is_equal(PlanPolicy.SWAP)
	policy.swap_locked = true
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 0, 4.0, 10.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)], 0, 4.0, 11.6), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	# A slot that holds only the keystone has nothing to swap to.
	var lone := PlanPolicy.new()
	var only := _slots(["wizard_thesis_defense"] as Array[String], ["wizard_arcane_nova"] as Array[String])
	assert_str(lone.decide("attack_single", only["attack_single"], only, _view([_enemy(-3.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_a_primer_is_cast_as_an_ordinary_attack() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_footnotes", "wizard_thesis_defense"] as Array[String], ["wizard_literature_review"] as Array[String])
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-3.0)]), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	assert_str(policy.decide("attack_aoe", slots["attack_aoe"], slots, _view([_enemy(-3.0)]), 1.0, false, true)).is_equal(PlanPolicy.CAST)


func test_spiteful_ward_goes_up_before_contact_and_not_while_it_runs() -> void:
	assert_bool(PlanPolicy.has_trigger_buff(CardDatabase.get_card("wizard_spiteful_ward"))).is_true()
	assert_bool(PlanPolicy.has_trigger_buff(CardDatabase.get_card("wizard_ward"))).is_false()
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_bolt_volley"] as Array[String], ["wizard_arcane_nova"] as Array[String], ["wizard_spiteful_ward"] as Array[String])
	assert_str(policy.decide("utility", slots["utility"], slots, _view([_enemy(-6.0)]), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	# Far away (inside the old 12 m rule, outside the contact range): not yet.
	assert_str(policy.decide("utility", slots["utility"], slots, _view([_enemy(-11.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)
	# Danger about to land overrides the range.
	assert_str(policy.decide("utility", slots["utility"], slots, _view([_enemy(-11.0)]), 1.0, true, true)).is_equal(PlanPolicy.CAST)
	# No enemy, nothing to do.
	assert_str(policy.decide("utility", slots["utility"], slots, _view([]), 1.0, true, true)).is_equal(PlanPolicy.WAIT)
	# Still up from a cast 2 s ago (it lasts 4 s): not recast.
	var history := CastHistory.new()
	history.record(8.0, "utility", "wizard_spiteful_ward", CardDatabase.tags_for("wizard_spiteful_ward"))
	assert_str(policy.decide("utility", slots["utility"], slots, _view([_enemy(-3.0)], 0, 4.0, 10.0, history), 1.0, true, true)).is_equal(PlanPolicy.WAIT)


func test_an_ordinary_utility_card_keeps_the_old_range() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["wizard_bolt_volley"] as Array[String], ["wizard_arcane_nova"] as Array[String], ["wizard_ward"] as Array[String])
	assert_str(policy.decide("utility", slots["utility"], slots, _view([_enemy(-11.0)]), 1.0, false, true)).is_equal(PlanPolicy.CAST)


func test_the_sim_caster_view_carries_the_decay_time() -> void:
	var caster: Node3D = auto_free(preload("res://tools/sim_caster.gd").new())
	add_child(caster)
	var controller := CardSlotController.new(caster, caster, "player", caster.stat_modifiers, ["wizard", "neutral"] as Array[String], RandomNumberGenerator.new())
	var def: Dictionary = StatusDatabase.get_status("charge")
	caster.status_manager.apply_status("charge", def, 4.0)
	caster.call("step", 1.0)
	var fields: Dictionary = caster.call("live_view_fields", controller)
	assert_int(int((fields["self_stacks"] as Dictionary)["charge"])).is_equal(1)
	assert_float(float((fields["self_decay_left"] as Dictionary)["charge"])).is_between(6.9, 7.1)
