class_name M3bRewardsTest
extends GdUnitTestSuite
## Milestone 3b logic: seeded reward offers (determinism, pools, requires, weighting), the choice model
## (pick, reject cap, rest heal-or-remove, the removal guard), RunState with the reward state, --full-deck.
## Pure logic runs on fixture cards; the removal guard and the starter deck use the shipped data.

const POOLS: Array = ["rogue", "fire", "neutral"]


func after_test() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.forced_seed = -1


func _card(id: String, pool: String, slot: String, extra: Dictionary = {}) -> Dictionary:
	var card: Dictionary = {
		"id": id, "name": id.capitalize(), "slot_type": slot, "pool": pool, "cooldown_modifier": 0.0,
		"flavor_text": "flavor", "effects": [{"template": "heal", "params": {"amount": 5}}],
	}
	card.merge(extra, true)
	return card


func _fixture_cards() -> Array:
	var cards: Array = []
	for i in range(10):
		cards.append(_card("rogue_%d" % i, "rogue", "attack_single"))
	for i in range(4):
		cards.append(_card("fire_%d" % i, "fire", "attack_aoe"))
	for i in range(3):
		cards.append(_card("wizard_%d" % i, "wizard", "attack_single"))
	return cards


func _rewards(size: int = 3, unowned: float = 4.0, owned: float = 1.0) -> Dictionary:
	return {"offer_size": size, "unowned_weight": unowned, "owned_weight": owned}


func _offer(seed_value: int, room: int, deck: Array, cards: Array, rewards: Dictionary = {}, pools: Array = POOLS) -> Array[String]:
	return RewardOffer.generate(seed_value, room, deck, cards, pools, {}, rewards if not rewards.is_empty() else _rewards())


# ---- Offers ----

func test_offer_is_deterministic_for_seed_room_and_deck() -> void:
	var cards := _fixture_cards()
	var deck: Array = ["rogue_0", "rogue_1"]
	var a := _offer(77, 2, deck, cards)
	var b := _offer(77, 2, deck, cards)
	assert_array(a).is_equal(b)
	assert_int(a.size()).is_equal(3)
	var different := false
	for room in range(8):
		if _offer(77, room, deck, cards) != a:
			different = true
	assert_bool(different).is_true()
	var other_seed := false
	for seed_value in range(1, 20):
		if _offer(seed_value, 2, deck, cards) != a:
			other_seed = true
	assert_bool(other_seed).is_true()


func test_offer_ignores_card_list_order() -> void:
	var cards := _fixture_cards()
	var reversed := cards.duplicate()
	reversed.reverse()
	assert_array(_offer(5, 1, [], cards)).is_equal(_offer(5, 1, [], reversed))


func test_offer_is_distinct_and_sized_by_data() -> void:
	var cards := _fixture_cards()
	for size in [1, 3, 5, 12]:
		for seed_value in range(1, 30):
			var offered := _offer(seed_value, seed_value % 6, ["rogue_0"], cards, _rewards(size))
			var seen: Dictionary = {}
			for id in offered:
				assert_bool(seen.has(id)).is_false()
				seen[id] = true
			assert_int(offered.size()).is_equal(mini(size, 14))  # 14 eligible cards in the owned pools


func test_offer_comes_only_from_the_owned_pools() -> void:
	var cards := _fixture_cards()
	for seed_value in range(1, 40):
		for id in _offer(seed_value, 1, [], cards, _rewards(6)):
			assert_bool(id.begins_with("wizard_")).is_false()
	for id in _offer(3, 1, [], cards, _rewards(12), ["fire"]):
		assert_bool(id.begins_with("fire_")).is_true()


func test_offer_shrinks_when_fewer_cards_are_eligible() -> void:
	var offered := _offer(1, 0, [], _fixture_cards(), _rewards(12), ["fire"])
	assert_int(offered.size()).is_equal(4)
	assert_array(_offer(1, 0, [], [], _rewards(3))).is_empty()


func test_unowned_cards_are_preferred_but_duplicates_are_allowed() -> void:
	var cards := _fixture_cards()
	var deck: Array = []
	for i in range(9):
		deck.append("rogue_%d" % i)
	deck.append_array(["fire_0", "fire_1", "fire_2", "fire_3"])  # everything but rogue_9 is owned
	var unowned_hits := 0
	var owned_hits := 0
	for room in range(300):
		var id: String = _offer(11, room, deck, cards, _rewards(1, 20.0, 1.0))[0]
		if id == "rogue_9":
			unowned_hits += 1
		else:
			owned_hits += 1
	# rogue_9 is 1 of 14 cards (7%) unweighted; at 20:1 it is 20/33 (about 60%).
	assert_int(unowned_hits).is_greater(120)
	assert_int(owned_hits).is_greater(20)  # duplicates still show up
	# With equal weights the unowned card is no more likely than any other.
	var flat := 0
	for room in range(300):
		if _offer(11, room, deck, cards, _rewards(1, 1.0, 1.0))[0] == "rogue_9":
			flat += 1
	assert_int(flat).is_less(60)


func test_zero_owned_weight_never_offers_a_duplicate() -> void:
	var cards := _fixture_cards()
	var deck: Array = ["rogue_0", "rogue_1", "rogue_2"]
	for room in range(60):
		for id in _offer(9, room, deck, cards, _rewards(3, 1.0, 0.0)):
			assert_bool(deck.has(id)).is_false()


func test_requires_filters_by_slot_type_pool_and_status_source() -> void:
	var cards: Array = [
		_card("plain", "rogue", "attack_single"),
		_card("needs_utility", "rogue", "attack_single", {"requires": {"slot_types": ["utility"]}}),
		_card("needs_wizard_pool", "rogue", "attack_single", {"requires": {"pools": ["wizard"]}}),
		_card("needs_burn", "rogue", "attack_single", {"requires": {"status_sources": ["burn"]}}),
		_card("utility_owned", "neutral", "utility"),
		_card("burner", "fire", "attack_aoe", {"effects": [{"template": "apply_status", "params": {"status_id": "burn", "duration": 3.0}}]}),
	]
	var no_deck: Array[Dictionary] = []
	var base: Array[String] = RewardOffer.candidate_ids(cards, POOLS, no_deck, {})
	assert_array(base).contains_exactly(["burner", "plain", "utility_owned"])
	# A utility card in the deck unlocks the slot-type requirement.
	var with_utility: Array[Dictionary] = [cards[4]]
	assert_array(RewardOffer.candidate_ids(cards, POOLS, with_utility, {})).contains(["needs_utility"])
	# A card that applies Burn unlocks the status requirement.
	var with_burner: Array[Dictionary] = [cards[5]]
	assert_array(RewardOffer.candidate_ids(cards, POOLS, with_burner, {})).contains(["needs_burn"])
	# So does an owned element pool whose status is Burn.
	var pool_defs: Dictionary = {"fire": {"kind": "element", "status": {"status_id": "burn", "base_chance": 0.2}}}
	assert_array(RewardOffer.candidate_ids(cards, POOLS, no_deck, pool_defs)).contains(["needs_burn"])
	# Owning the pool unlocks the pool requirement; a wizard card is still not in a rogue-fire-neutral pool list.
	assert_array(RewardOffer.candidate_ids(cards, POOLS + ["wizard"], no_deck, {})).contains(["needs_wizard_pool"])
	assert_array(base).not_contains(["needs_wizard_pool"])


func test_generate_applies_requires_through_the_deck() -> void:
	var cards: Array = [_card("plain", "rogue", "attack_single"), _card("gated", "rogue", "attack_single", {"requires": {"slot_types": ["utility"]}})]
	for room in range(20):
		assert_array(RewardOffer.generate(1, room, [], cards, POOLS, {}, _rewards(3))).contains_exactly(["plain"])


func test_card_schema_validates_requires() -> void:
	var good: Dictionary = {"slot_types": ["utility"], "pools": ["fire"], "status_sources": ["burn"]}
	assert_array(RewardOffer.validate_requires(good, SlotTypeDatabase.known_ids(), PoolDatabase.known_ids())).is_empty()
	for bad: Variant in [{"colour": ["red"]}, {"slot_types": ["nonsense"]}, {"pools": ["nonsense"]}, {"slot_types": []}, {"slot_types": "utility"}, "x", {"status_sources": [""]}]:
		assert_array(RewardOffer.validate_requires(bad, SlotTypeDatabase.known_ids(), PoolDatabase.known_ids())).is_not_empty()
	var card: Dictionary = CardDatabase.get_card("rogue_quick_slash").duplicate(true)
	card["requires"] = {"oops": ["x"]}
	assert_array(CardSchema.validate(card)).is_not_empty()
	card["requires"] = {"slot_types": ["utility"]}
	assert_array(CardSchema.validate(card)).is_empty()


func test_shipped_offers_use_shipped_pools_and_data_size() -> void:
	var state := RunState.new_run(123, RunConfig.starting_deck(), 3)
	var ctx := RunChoices.shipped_context(POOLS)
	var shipped_cards: Array[String] = RunConfig.cards_in_pools(POOLS)
	for room in range(8):
		state.room_index = room
		assert_str(RunChoices.open_for_room(state, "combat", false, ctx)).is_equal(RunState.PENDING_REWARD)
		assert_int(state.offer.size()).is_equal(RunConfig.offer_size())
		for id in state.offer:
			assert_bool(shipped_cards.has(id)).is_true()


# ---- Choice model ----

func _state_with_offer(rejects: int = 3) -> RunState:
	var state := RunState.new_run(42, RunConfig.starting_deck(), rejects)
	state.max_hp = 30.0
	state.hp = 20.0
	RunChoices.open_for_room(state, "combat", false, RunChoices.shipped_context(POOLS))
	return state


func test_pick_adds_the_card_and_closes_the_choice() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := _state_with_offer()
	var card_id: String = state.offer[1]
	var before := state.deck.size()
	var result := RunChoices.apply(state, "card:" + card_id, ctx)
	assert_bool(result["ok"]).is_true()
	assert_bool(result["finished"]).is_true()
	assert_int(state.deck.size()).is_equal(before + 1)
	assert_int(state.deck.count(card_id)).is_equal(RunConfig.starting_deck().count(card_id) + 1)
	assert_int(state.rejects_remaining).is_equal(3)
	assert_bool(state.has_pending()).is_false()
	assert_array(state.offer).is_empty()
	assert_str(state.choice_log[0]["kind"]).is_equal("pick")


func test_pick_must_be_in_the_offer() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := _state_with_offer()
	var not_offered := ""
	for id in RunConfig.cards_in_pools(POOLS):
		if not state.offer.has(id):
			not_offered = id
			break
	assert_bool(RunChoices.apply(state, "card:" + not_offered, ctx)["ok"]).is_false()
	assert_bool(state.has_pending()).is_true()


func test_options_follow_the_documented_format() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := _state_with_offer()
	var model := RunChoices.model(state, ctx)
	var options: Array[Dictionary] = model["options"]
	assert_int(options.size()).is_equal(RunConfig.offer_size() + 1)  # the cards and the reject option
	var keys: Array = ["id", "kind", "label", "detail", "flavor", "card_id", "slot_type", "slot_name", "count", "enabled", "reason", "costs_reject", "opens_list", "amount"]
	for option in options:
		for key in keys:
			assert_bool(option.has(key)).is_true()
		assert_bool(RunChoices.KINDS.has(option["kind"])).is_true()
	for i in range(RunConfig.offer_size()):
		assert_str(options[i]["kind"]).is_equal("card")
		assert_str(options[i]["label"]).is_not_empty()
		assert_str(options[i]["detail"]).is_not_empty()
		assert_str(options[i]["slot_name"]).is_not_empty()
	assert_str(options[options.size() - 1]["kind"]).is_equal("skip")
	assert_bool(options[options.size() - 1]["costs_reject"]).is_true()
	assert_int(model["rejects_remaining"]).is_equal(3)


func test_reject_spends_one_and_is_disabled_at_zero_with_the_reason() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := _state_with_offer(1)
	var deck_before := state.deck.duplicate()
	var result := RunChoices.apply(state, "skip", ctx)
	assert_bool(result["ok"]).is_true()
	assert_int(state.rejects_remaining).is_equal(0)
	assert_array(state.deck).is_equal(deck_before)  # a reject adds nothing
	assert_str(state.choice_log[0]["kind"]).is_equal("reject")
	# Next reward with 0 rejects: the option is there, disabled, with a reason, and does nothing.
	state.room_index = 1
	RunChoices.open_for_room(state, "combat", false, ctx)
	var options := RunChoices.options(state, ctx)
	var skip: Dictionary = options[options.size() - 1]
	assert_bool(skip["enabled"]).is_false()
	assert_str(skip["reason"]).is_not_empty()
	var refused := RunChoices.apply(state, "skip", ctx)
	assert_bool(refused["ok"]).is_false()
	assert_int(state.rejects_remaining).is_equal(0)
	assert_bool(state.has_pending()).is_true()


func test_no_reward_after_the_last_room_or_a_rest_room() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := RunState.new_run(42, RunConfig.starting_deck(), 3)
	assert_str(RunChoices.open_for_room(state, "combat", true, ctx)).is_equal("")
	assert_str(RunChoices.open_for_room(state, "boss", false, ctx)).is_equal("")  # boss is not a reward room in data
	assert_str(RunChoices.open_for_room(state, "elite", false, ctx)).is_equal(RunState.PENDING_REWARD)
	assert_str(RunChoices.open_for_room(state, "rest", false, ctx)).is_equal(RunState.PENDING_REST)
	assert_array(state.offer).is_empty()


func test_rest_offers_heal_or_remove_and_heal_is_thirty_percent() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := RunState.new_run(42, RunConfig.starting_deck(), 3)
	state.max_hp = 100.0
	state.hp = 40.0
	RunChoices.open_for_room(state, "rest", false, ctx)
	var options := RunChoices.options(state, ctx)
	assert_int(options.size()).is_equal(2)
	assert_str(options[0]["kind"]).is_equal("heal")
	assert_float(options[0]["amount"]).is_equal_approx(30.0, 0.001)
	assert_str(options[1]["kind"]).is_equal("remove")
	assert_bool(options[1]["opens_list"]).is_true()
	var result := RunChoices.apply(state, "heal", ctx)
	assert_bool(result["finished"]).is_true()
	assert_float(state.hp).is_equal_approx(70.0, 0.001)
	assert_bool(state.has_pending()).is_false()


func test_rest_heal_never_says_zero_and_never_overheals() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := RunState.new_run(42, RunConfig.starting_deck(), 3)
	state.max_hp = 100.0
	state.hp = 100.0
	RunChoices.open_for_room(state, "rest", false, ctx)
	var heal: Dictionary = RunChoices.options(state, ctx)[0]
	assert_bool(heal["enabled"]).is_true()  # the room must never be a dead end
	assert_str(heal["detail"]).not_contains("+0").not_contains(" 0 HP")
	assert_str(heal["detail"]).is_equal(String(RunConfig.ui()["rest"]["heal_full_detail"]))
	state.hp = 95.0
	assert_float(RunChoices.options(state, ctx)[0]["amount"]).is_equal_approx(5.0, 0.001)
	RunChoices.apply(state, "heal", ctx)
	assert_float(state.hp).is_equal_approx(100.0, 0.001)


func test_starter_cards_are_all_blocked_from_removal_with_a_reason() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := RunState.new_run(42, RunConfig.starting_deck(), 3)
	state.max_hp = 30.0
	state.hp = 30.0
	RunChoices.open_for_room(state, "rest", false, ctx)
	var menu: Dictionary = RunChoices.options(state, ctx)[1]
	assert_bool(menu["enabled"]).is_false()
	assert_str(menu["reason"]).is_not_empty()
	# The list itself still shows every card, greyed, each with the reason.
	state.pending = RunState.PENDING_REST_REMOVE
	var list := RunChoices.options(state, ctx)
	assert_int(list.size()).is_equal(RunConfig.starting_deck().size() + 1)  # 15 cards and Back
	for i in range(list.size() - 1):
		assert_str(list[i]["kind"]).is_equal("remove")
		assert_bool(list[i]["enabled"]).is_false()
		assert_str(list[i]["reason"]).contains("needs 3 unique")
	assert_str(list[list.size() - 1]["kind"]).is_equal("back")
	var refused := RunChoices.apply(state, list[0]["id"], ctx)
	assert_bool(refused["ok"]).is_false()
	assert_int(state.deck.size()).is_equal(15)


func test_a_duplicate_or_a_fourth_unique_card_can_be_removed_and_back_works() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := RunState.new_run(42, RunConfig.starting_deck(), 3)
	state.max_hp = 30.0
	state.hp = 30.0
	state.deck.append("rogue_quick_slash")  # a duplicate of a starter
	state.deck.append("rogue_flurry")  # a fourth unique attack_single card
	RunChoices.open_for_room(state, "rest", false, ctx)
	assert_bool(RunChoices.options(state, ctx)[1]["enabled"]).is_true()
	RunChoices.apply(state, "remove_menu", ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_REST_REMOVE)
	var back := RunChoices.apply(state, "back", ctx)
	assert_bool(back["ok"]).is_true()
	assert_bool(back["finished"]).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_REST)
	RunChoices.apply(state, "remove_menu", ctx)
	var enabled: Array[String] = []
	for option in RunChoices.options(state, ctx):
		if option["kind"] == "remove" and option["enabled"]:
			enabled.append(option["card_id"])
	# The fourth unique, and the starters of the same slot, which now have 4 unique cards to spare one.
	assert_array(enabled).contains(["rogue_flurry"])
	var result := RunChoices.apply(state, "remove:rogue_quick_slash", ctx)
	assert_bool(result["ok"]).is_true()
	assert_bool(result["finished"]).is_true()
	assert_int(state.deck.count("rogue_quick_slash")).is_equal(1)
	assert_str(state.choice_log[state.choice_log.size() - 1]["kind"]).is_equal("remove")


func test_no_sequence_of_removals_breaks_a_deck_minimum() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	for seed_value in range(1, 25):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var state := RunState.new_run(seed_value, RunConfig.starting_deck(), 3)
		state.max_hp = 30.0
		state.hp = 30.0
		var all_cards := RunConfig.cards_in_pools(POOLS)
		for step in range(60):
			if rng.randf() < 0.5:
				state.deck.append(all_cards[rng.randi_range(0, all_cards.size() - 1)])
			state.pending = RunState.PENDING_REST_REMOVE
			var list := RunChoices.options(state, ctx)
			var pick: Dictionary = list[rng.randi_range(0, list.size() - 1)]
			RunChoices.apply(state, pick["id"], ctx)  # blocked ones are refused; allowed ones remove
			state.pending = ""
			var check := DeckRules.check_shipped(state.deck)
			assert_array(check.problems).is_empty()


# ---- RunState ----

func test_run_state_round_trips_picks_removals_and_the_reward_state() -> void:
	var ctx := RunChoices.shipped_context(POOLS)
	var state := _state_with_offer()
	RunChoices.apply(state, "card:" + state.offer[0], ctx)
	state.room_index = 3
	RunChoices.open_for_room(state, "elite", false, ctx)
	state.log_choice("remove", "rogue_flurry")
	var copy := RunState.from_json(state.to_json())
	assert_object(copy).is_not_null()
	assert_bool(copy.equals(state)).is_true()
	assert_str(copy.pending).is_equal(RunState.PENDING_REWARD)
	assert_array(copy.offer).is_equal(state.offer)
	assert_int(copy.choice_log.size()).is_equal(2)
	assert_array(copy.deck).is_equal(state.deck)
	assert_int(copy.rejects_remaining).is_equal(state.rejects_remaining)
	# The reopened choice has the same options.
	assert_array(RunChoices.options(copy, ctx)).is_equal(RunChoices.options(state, ctx))


func test_a_3a_save_without_the_reward_keys_still_loads() -> void:
	var legacy: Dictionary = RunState.new_run(5, RunConfig.starting_deck(), 3).to_dict()
	for key in ["pending", "offer", "choice_log"]:
		legacy.erase(key)
	legacy["version"] = 1
	var state := RunState.from_dict(legacy)
	assert_object(state).is_not_null()
	assert_bool(state.has_pending()).is_false()
	assert_array(state.offer).is_empty()


func test_a_new_run_starts_clean() -> void:
	var state := _state_with_offer()
	state.rejects_remaining = 0
	RunSession.current = state
	var fresh := RunSession.begin_new_run(9)
	assert_bool(fresh.has_pending()).is_false()
	assert_array(fresh.offer).is_empty()
	assert_array(fresh.choice_log).is_empty()
	assert_int(fresh.rejects_remaining).is_equal(3)


# ---- Starter deck and --full-deck ----

func test_starter_deck_passes_the_deck_rules_and_is_a_subset_of_the_pool() -> void:
	var starter := RunConfig.starting_deck()
	assert_int(starter.size()).is_equal(15)
	assert_array(DeckRules.check_shipped(starter).problems).is_empty()
	var pool := RunConfig.cards_in_pools(RunConfig.character_pools())
	for id in starter:
		assert_bool(pool.has(id)).is_true()
	assert_array(RunConfig.deck_problems(RunConfig.get_config())).is_empty()


func test_full_deck_flag_starts_a_run_with_every_pool_card_and_is_off_by_default() -> void:
	var normal := RunSession.begin_new_run(4)
	assert_int(normal.deck.size()).is_equal(15)
	RunSession.full_deck = true
	var full := RunSession.begin_new_run(4)
	var expected := RunConfig.cards_in_pools(RunConfig.character_pools())
	var actual := full.deck.duplicate()
	actual.sort()
	assert_array(actual).is_equal(expected)
	assert_int(expected.size()).is_equal(CardDatabase.all_cards().size())
	assert_array(DeckRules.check_shipped(full.deck).problems).is_empty()
	RunSession.full_deck = false
	assert_int(RunSession.begin_new_run(4).deck.size()).is_equal(15)


func test_config_validation_rejects_bad_reward_data() -> void:
	var good: Dictionary = RunConfig.get_config().duplicate(true)
	var cards: Array[String] = []
	assert_array(RunConfig.validate(good, [], cards)).is_empty()
	var cases: Array[Dictionary] = [
		{"offer_size": 0, "unowned_weight": 1.0, "owned_weight": 1.0, "reward_room_types": ["combat"]},
		{"offer_size": 3, "unowned_weight": 0.0, "owned_weight": 0.0, "reward_room_types": ["combat"]},
		{"offer_size": 3, "unowned_weight": -1.0, "owned_weight": 1.0, "reward_room_types": ["combat"]},
		{"offer_size": 3, "unowned_weight": 1.0, "owned_weight": 1.0, "reward_room_types": ["rest"]},
		{"offer_size": 3, "unowned_weight": 1.0, "owned_weight": 1.0},
	]
	for bad in cases:
		var config: Dictionary = good.duplicate(true)
		config["rewards"] = bad
		assert_array(RunConfig.validate(config, [], cards)).is_not_empty()
	var missing: Dictionary = good.duplicate(true)
	missing.erase("rewards")
	assert_array(RunConfig.validate(missing, [], cards)).is_not_empty()
