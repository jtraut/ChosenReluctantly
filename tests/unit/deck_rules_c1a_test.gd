class_name DeckRulesC1aTest
extends GdUnitTestSuite
## C1-a: unique-card minimums (config validation, checker, remove/swap guards, content check)
## and the shuffle bag (no repeats inside a cycle, no back-to-back across a reshuffle).

const EXAMPLE := "res://tests/fixtures/deck_rules_example/deck_rules.json"
const SLOTS: Array = ["attack_single", "attack_aoe", "utility", "movement", "recovery"]
const NAMES: Dictionary = {"attack_single": "Attack: Single", "attack_aoe": "Attack: AoE", "utility": "Utility", "movement": "Movement", "recovery": "Recovery"}


## n cards in a slot, ids "<slot>_<i>".
func _cards(slot_type: String, n: int, slot_of: Dictionary, deck: Array) -> void:
	for i in range(n):
		var card_id := "%s_%d" % [slot_type, i]
		slot_of[card_id] = slot_type
		deck.append(card_id)


func _deck(counts: Dictionary) -> Array:
	var slot_of: Dictionary = {}
	var deck: Array = []
	for slot_type: String in counts:
		_cards(slot_type, int(counts[slot_type]), slot_of, deck)
	return [deck, slot_of]


# --- config validation ---------------------------------------------------------------------

func test_shipped_config_is_valid_with_no_overrides_or_groups() -> void:
	var config := DeckRules.load_config()
	assert_array(DeckRules.validate_config(config, SlotTypeDatabase.known_ids())).is_empty()
	assert_int(DeckRules.min_for_slot(config, "movement")).is_equal(3)
	assert_int((config["slots"] as Dictionary).size()).is_equal(0)
	assert_int((config["slot_groups"] as Array).size()).is_equal(0)


func test_example_fixture_is_valid() -> void:
	assert_array(DeckRules.validate_config(DeckRules.load_config(EXAMPLE), SLOTS)).is_empty()


func test_validation_rejects_group_below_sum_unknown_slot_and_non_positive_minimums() -> void:
	var low_group := {"min_unique_per_slot": 3, "slot_groups": [{"name": "A", "slots": ["attack_single", "attack_aoe"], "min_unique_total": 5}]}
	assert_str(" ".join(DeckRules.validate_config(low_group, SLOTS))).contains("below the sum")
	var unknown_override := {"min_unique_per_slot": 3, "slots": {"nope": {"min_unique": 3}}}
	assert_str(" ".join(DeckRules.validate_config(unknown_override, SLOTS))).contains("unknown slot 'nope'")
	var unknown_member := {"min_unique_per_slot": 3, "slot_groups": [{"name": "A", "slots": ["nope"], "min_unique_total": 3}]}
	assert_str(" ".join(DeckRules.validate_config(unknown_member, SLOTS))).contains("unknown slot 'nope'")
	for bad: Variant in [0, -1, 2.5, "3", null]:
		assert_array(DeckRules.validate_config({"min_unique_per_slot": bad}, SLOTS)).is_not_empty()
	assert_array(DeckRules.validate_config({"min_unique_per_slot": 3, "slots": {"utility": {"min_unique": 0}}}, SLOTS)).is_not_empty()
	var zero_group := {"min_unique_per_slot": 3, "slot_groups": [{"name": "A", "slots": ["utility"], "min_unique_total": 0}]}
	assert_array(DeckRules.validate_config(zero_group, SLOTS)).is_not_empty()


func test_group_sum_uses_per_slot_overrides() -> void:
	var config := {"min_unique_per_slot": 3, "slots": {"attack_single": {"min_unique": 6}}, "slot_groups": [{"name": "A", "slots": ["attack_single", "attack_aoe"], "min_unique_total": 8}]}
	assert_str(" ".join(DeckRules.validate_config(config, SLOTS))).contains("below the sum of its slots' minimums (9)")


# --- checker -------------------------------------------------------------------------------

func test_checker_reports_counts_shortfalls_and_messages_for_the_director_example() -> void:
	var config := DeckRules.load_config(EXAMPLE)
	var built := _deck({"attack_single": 5, "attack_aoe": 3, "utility": 4, "movement": 3, "recovery": 3})
	var result := DeckRules.check(built[0], config, built[1], SLOTS, NAMES)
	assert_bool(result.is_ok()).is_false()
	assert_array(result.problems).contains_exactly(["Utility needs 5 unique cards, deck has 4", "Attack group needs 10, has 8"])
	assert_int(int(result.groups[0]["count"])).is_equal(8)
	assert_int(int(result.groups[0]["short"])).is_equal(2)
	assert_array(result.summary_lines()).contains(["Utility 4/5  SHORT", "Movement 3/3", "Attack group 8/10  SHORT"])


func test_checker_passes_the_director_example_when_met() -> void:
	var built := _deck({"attack_single": 5, "attack_aoe": 5, "utility": 5, "movement": 3, "recovery": 3})
	assert_bool(DeckRules.check(built[0], DeckRules.load_config(EXAMPLE), built[1], SLOTS, NAMES).is_ok()).is_true()


func test_copies_never_count_toward_a_minimum() -> void:
	var built := _deck({"utility": 2})
	var deck: Array = built[0]
	deck.append_array(["utility_0", "utility_0", "utility_1"])
	var result := DeckRules.check(deck, {"min_unique_per_slot": 3}, built[1], ["utility"], NAMES)
	assert_int(int(result.slots[0]["count"])).is_equal(2)
	assert_array(result.problems).contains_exactly(["Utility needs 3 unique cards, deck has 2"])


func test_shipped_overlay_lines_have_no_group_line_when_no_group_exists() -> void:
	var lines := DeckRules.check_shipped([]).summary_lines()
	assert_int(lines.size()).is_equal(5)
	assert_bool(lines.any(func(line: String) -> bool: return line.contains("group"))).is_false()


# --- remove / swap guards ------------------------------------------------------------------

func test_can_remove_blocks_the_last_copy_that_would_break_a_rule_but_allows_extras() -> void:
	var config := {"min_unique_per_slot": 3}
	var built := _deck({"movement": 3, "recovery": 4})
	var deck: Array = built[0]
	assert_array(DeckRules.can_remove(deck, "recovery_0", config, built[1], SLOTS, NAMES)).is_empty()
	assert_array(DeckRules.can_remove(deck, "movement_0", config, built[1], SLOTS, NAMES)).is_not_empty()
	deck.append("movement_0")
	assert_array(DeckRules.can_remove(deck, "movement_0", config, built[1], SLOTS, NAMES)).is_empty()


func test_can_remove_checks_the_group_minimum() -> void:
	var config := DeckRules.load_config(EXAMPLE)
	var built := _deck({"attack_single": 5, "attack_aoe": 5, "utility": 5})
	var deck: Array = built[0]
	var blocked := DeckRules.can_remove(deck, "attack_single_0", config, built[1], SLOTS, NAMES)
	assert_str(" ".join(blocked)).contains("Attack group needs 10, would have 9")
	var bigger := _deck({"attack_single": 6, "attack_aoe": 5, "utility": 5})
	assert_array(DeckRules.can_remove(bigger[0], "attack_single_0", config, bigger[1], SLOTS, NAMES)).is_empty()


func test_can_swap_allows_same_slot_replacement_and_blocks_cross_slot_loss() -> void:
	var config := {"min_unique_per_slot": 3}
	var built := _deck({"movement": 3, "recovery": 3, "utility": 4})
	var slot_of: Dictionary = built[1]
	slot_of["movement_new"] = "movement"
	assert_array(DeckRules.can_swap(built[0], "movement_0", "movement_new", config, slot_of, SLOTS, NAMES)).is_empty()
	assert_array(DeckRules.can_swap(built[0], "movement_0", "utility_0", config, slot_of, SLOTS, NAMES)).is_not_empty()


# --- content validation --------------------------------------------------------------------

func test_content_validation_names_the_combination_and_the_shortfall() -> void:
	var pools := {"rogue": {"kind": "class"}, "fire": {"kind": "element"}, "water": {"kind": "element"}, "neutral": {"kind": "neutral"}}
	var slot_of: Dictionary = {}
	var pool_of: Dictionary = {}
	for i in range(3):
		slot_of["r%d" % i] = "movement"
		pool_of["r%d" % i] = "rogue"
	slot_of["w0"] = "movement"
	pool_of["w0"] = "water"
	var errors := DeckRules.validate_content({"min_unique_per_slot": 3}, pools, pool_of, slot_of, ["movement"], NAMES)
	assert_array(errors).is_empty()
	var strict := DeckRules.validate_content({"min_unique_per_slot": 4}, pools, pool_of, slot_of, ["movement"], NAMES)
	assert_array(strict).contains_exactly(["rogue+fire+neutral: Movement needs 4 unique cards, deck has 3"])


func test_shipped_content_meets_the_minimums() -> void:
	assert_array(DeckRules.validate_shipped_content()).is_empty()


func test_the_shipped_preset_deck_passes_the_run_start_gate_with_at_least_3_per_slot() -> void:
	var result := DeckRules.check_shipped(CardDatabase.all_cards().filter(func(c: Dictionary) -> bool: return ["rogue", "fire", "neutral"].has(String(c["pool"]))).map(func(c: Dictionary) -> String: return String(c["id"])))
	assert_str(DeckRules.run_start_block_message(result)).is_empty()
	for entry: Dictionary in result.slots:
		assert_int(int(entry["count"])).override_failure_message(str(entry["slot_type"])).is_greater_equal(3)


func test_run_start_gate_blocks_a_short_deck_with_every_shortfall_named() -> void:
	var short := _deck({"attack_single": 3, "attack_aoe": 3, "utility": 2, "movement": 3, "recovery": 1})
	var message := DeckRules.run_start_block_message(DeckRules.check(short[0], {"min_unique_per_slot": 3}, short[1], SLOTS, NAMES))
	assert_str(message).contains("Utility needs 3 unique cards, deck has 2").contains("Recovery needs 3 unique cards, deck has 1")
	var full := _deck({"attack_single": 3, "attack_aoe": 3, "utility": 3, "movement": 3, "recovery": 3})
	assert_str(DeckRules.run_start_block_message(DeckRules.check(full[0], {"min_unique_per_slot": 3}, full[1], SLOTS, NAMES))).is_empty()


## The director's example (attack group 10, utility 5, movement 3, recovery 3) is covered both ways by
## test_checker_reports_counts_shortfalls_and_messages_for_the_director_example (fails) and
## test_checker_passes_the_director_example_when_met (passes); the gate agrees with both.
func test_run_start_gate_agrees_with_the_director_example_fixture_both_ways() -> void:
	var config := DeckRules.load_config(EXAMPLE)
	var short := _deck({"attack_single": 5, "attack_aoe": 3, "utility": 4, "movement": 3, "recovery": 3})
	var message := DeckRules.run_start_block_message(DeckRules.check(short[0], config, short[1], SLOTS, NAMES))
	assert_str(message).contains("Utility needs 5 unique cards, deck has 4").contains("Attack group needs 10, has 8")
	var met := _deck({"attack_single": 5, "attack_aoe": 5, "utility": 5, "movement": 3, "recovery": 3})
	assert_str(DeckRules.run_start_block_message(DeckRules.check(met[0], config, met[1], SLOTS, NAMES))).is_empty()


# --- shuffle bag ---------------------------------------------------------------------------

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _play(slot: CardSlot, count: int) -> Array[String]:
	var played: Array[String] = []
	for i in range(count):
		slot.cooldown_remaining = 0.0
		played.append(slot.use_card(0.0))
	return played


func test_every_card_is_drawn_once_per_cycle_for_many_seeds_and_sizes() -> void:
	for size in [3, 4, 5, 7]:
		var ids: Array[String] = []
		for i in range(size):
			ids.append("c%d" % i)
		for seed_value in range(1, 25):
			var slot := CardSlot.new("attack_single", 1.0, ids, 1.0, _rng(seed_value))
			var played := _play(slot, size * 6)
			for cycle in range(6):
				var window: Array = played.slice(cycle * size, (cycle + 1) * size)
				window.sort()
				assert_array(window).override_failure_message("size %d seed %d cycle %d: %s" % [size, seed_value, cycle, window]).contains_exactly(ids)


func test_no_card_opens_a_cycle_as_the_last_one_of_the_previous_cycle() -> void:
	for size in [2, 3, 4, 6]:
		var ids: Array[String] = []
		for i in range(size):
			ids.append("c%d" % i)
		for seed_value in range(1, 60):
			var slot := CardSlot.new("attack_single", 1.0, ids, 1.0, _rng(seed_value))
			var played := _play(slot, size * 8)
			for i in range(1, played.size()):
				assert_str(played[i]).override_failure_message("back-to-back %s at %d (size %d seed %d)" % [played[i], i, size, seed_value]).is_not_equal(played[i - 1])


func test_swapping_across_a_reshuffle_never_shows_the_same_card_twice_in_a_row() -> void:
	for seed_value in range(1, 60):
		var slot := CardSlot.new("attack_single", 1.0, ["a", "b", "c"], 1.0, _rng(seed_value))
		var previous := slot.current_card_id
		for i in range(30):
			slot.cooldown_remaining = 0.0
			slot.swap_card()
			assert_str(slot.current_card_id).is_not_equal(previous)
			previous = slot.current_card_id


func test_one_card_and_duplicate_copy_decks_are_safe() -> void:
	var single := CardSlot.new("attack_single", 1.0, ["a"], 1.0, _rng(1))
	assert_array(_play(single, 4)).contains_exactly(["a", "a", "a", "a"])
	# Copies are separate bag entries: "a","a","b" -> each cycle holds both copies of a and one b.
	var copies := CardSlot.new("attack_single", 1.0, ["a", "a", "b"], 1.0, _rng(3))
	var played := _play(copies, 9)
	for cycle in range(3):
		var window: Array = played.slice(cycle * 3, cycle * 3 + 3)
		window.sort()
		assert_array(window).contains_exactly(["a", "a", "b"])


func test_preview_is_the_next_card_across_the_reshuffle_boundary() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b", "c"], 1.0, _rng(5))
	for i in range(20):
		var expected_next := slot.preview_card_id()
		assert_str(expected_next).is_not_equal("")
		slot.cooldown_remaining = 0.0
		slot.use_card(0.0)
		assert_str(slot.current_card_id).is_equal(expected_next)


# --- recovery has the longest cooldown (C1-a item 7) ---------------------------------------

func _effective_cooldowns(slot_type: String) -> Array[float]:
	var out: Array[float] = []
	var base: float = SlotTypeDatabase.get_definition(slot_type)["base_cooldown"]
	for card: Dictionary in CardDatabase.cards_for_slot_type(slot_type):
		out.append(base + float(card.get("cooldown_modifier", 0.0)))
	return out


func test_recovery_has_the_longest_base_and_effective_cooldown() -> void:
	var recovery_base: float = SlotTypeDatabase.get_definition("recovery")["base_cooldown"]
	var longest_other_effective := 0.0
	for slot_type: Variant in SlotTypeDatabase.known_ids():
		if slot_type == "recovery":
			continue
		assert_float(recovery_base).is_greater(float(SlotTypeDatabase.get_definition(String(slot_type))["base_cooldown"]))
		for cooldown in _effective_cooldowns(String(slot_type)):
			longest_other_effective = maxf(longest_other_effective, cooldown)
	for cooldown in _effective_cooldowns("recovery"):
		assert_float(cooldown).is_greater(longest_other_effective)
