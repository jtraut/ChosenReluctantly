class_name CardSlotTest
extends GdUnitTestSuite


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_empty_slot_is_inert_not_crashing() -> void:
	var slot := CardSlot.new("attack_single", 1.0, [], 1.0, _rng())
	assert_bool(slot.has_cards()).is_false()
	assert_bool(slot.is_ready()).is_false()
	assert_str(slot.current_card_id).is_equal("")
	assert_str(slot.preview_card_id()).is_equal("")
	assert_str(slot.use_card(0.0)).is_equal("")
	assert_bool(slot.swap_card()).is_false()


func test_slot_with_cards_starts_ready() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b", "c"], 1.0, _rng())
	assert_bool(slot.is_ready()).is_true()
	assert_bool(["a", "b", "c"].has(slot.current_card_id)).is_true()


func test_using_a_card_draws_the_next_one_and_starts_cooldown() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b"], 1.0, _rng())
	var first_card := slot.current_card_id
	var used := slot.use_card(0.0)
	assert_str(used).is_equal(first_card)
	assert_bool(slot.is_ready()).is_false()
	assert_float(slot.cooldown_remaining).is_greater(0.0)
	assert_str(slot.current_card_id).is_not_equal(first_card)


func test_cooldown_equals_base_plus_card_modifier() -> void:
	var slot := CardSlot.new("attack_single", 2.0, ["a", "b"], 1.0, _rng())
	slot.use_card(0.5)
	assert_float(slot.cooldown_remaining).is_equal_approx(2.5, 0.001)


func test_negative_card_modifier_shortens_cooldown() -> void:
	var slot := CardSlot.new("attack_single", 2.0, ["a", "b"], 1.0, _rng())
	slot.use_card(-0.5)
	assert_float(slot.cooldown_remaining).is_equal_approx(1.5, 0.001)


func test_large_negative_modifier_is_floored_not_negative() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b"], 1.0, _rng())
	slot.use_card(-50.0)
	assert_float(slot.cooldown_remaining).is_equal_approx(CardSlot.MIN_COOLDOWN, 0.001)


func test_stat_modifiers_apply_on_top_of_base_plus_card_modifier() -> void:
	var slot := CardSlot.new("attack_single", 2.0, ["a", "b"], 1.0, _rng())
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "passive", StatModifiers.ADDITIVE, -0.5)
	# (base 2.0 + card -0.5) = 1.5, then stat modifier -0.5 additive -> 1.0
	slot.use_card(-0.5, mods)
	assert_float(slot.cooldown_remaining).is_equal_approx(1.0, 0.001)


func test_cooldown_ticks_down_and_slot_becomes_ready_again() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b"], 1.0, _rng())
	slot.use_card(0.0)
	assert_bool(slot.is_ready()).is_false()
	slot.advance(0.5)
	assert_bool(slot.is_ready()).is_false()
	slot.advance(0.6)
	assert_bool(slot.is_ready()).is_true()


func test_using_while_on_cooldown_does_nothing() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b"], 1.0, _rng())
	slot.use_card(0.0)
	var result := slot.use_card(0.0)
	assert_str(result).is_equal("")


func test_deck_cycles_through_every_card_before_repeating() -> void:
	var owned: Array[String] = ["a", "b", "c", "d"]
	var slot := CardSlot.new("attack_single", 0.1, owned, 1.0, _rng())
	var seen: Array[String] = []
	for i in range(4):
		seen.append(slot.use_card(0.0))
		slot.cooldown_remaining = 0.0  # isolate deck cycling from cooldown timing
	seen.sort()
	var expected := owned.duplicate()
	expected.sort()
	assert_array(seen).is_equal(expected)


func test_deck_reshuffles_automatically_once_exhausted() -> void:
	var owned: Array[String] = ["a", "b"]
	var slot := CardSlot.new("attack_single", 0.1, owned, 1.0, _rng())
	# Use through the whole deck (2 cards) and one more past the boundary.
	slot.use_card(0.0)
	slot.cooldown_remaining = 0.0
	slot.use_card(0.0)
	slot.cooldown_remaining = 0.0
	assert_bool(slot.has_cards()).is_true()
	assert_bool(["a", "b"].has(slot.current_card_id)).is_true()
	assert_str(slot.preview_card_id()).is_not_equal("")


func test_dead_card_swap_discards_and_applies_penalty_cooldown() -> void:
	# 3 cards so drawing the replacement doesn't immediately empty the draw
	# pile and reshuffle the just-discarded card straight back in - that
	# reshuffle-on_empty behavior is covered by its own test below.
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b", "c"], 2.5, _rng())
	var swapped_away := slot.current_card_id
	var ok := slot.swap_card()
	assert_bool(ok).is_true()
	assert_float(slot.cooldown_remaining).is_equal_approx(2.5, 0.001)
	assert_bool(slot.discard_pile.has(swapped_away)).is_true()


func test_swap_on_a_2_card_deck_immediately_reshuffles_the_discarded_card_back_in() -> void:
	# Swapping draws the deck's only other card, which empties the draw
	# pile and triggers the immediate reshuffle - the just-discarded card
	# goes straight back into the draw pile instead of sitting in discard.
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b"], 2.5, _rng())
	var swapped_away := slot.current_card_id
	slot.swap_card()
	assert_bool(slot.discard_pile.is_empty()).is_true()
	assert_str(slot.preview_card_id()).is_equal(swapped_away)


func test_swap_is_blocked_while_already_on_cooldown() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b"], 2.5, _rng())
	slot.use_card(0.0)
	var ok := slot.swap_card()
	assert_bool(ok).is_false()


func test_swap_on_a_single_card_deck_returns_the_same_card_without_crashing() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["only"], 1.0, _rng())
	assert_str(slot.current_card_id).is_equal("only")
	var ok := slot.swap_card()
	assert_bool(ok).is_true()
	assert_str(slot.current_card_id).is_equal("only")
	assert_str(slot.preview_card_id()).is_equal("")
