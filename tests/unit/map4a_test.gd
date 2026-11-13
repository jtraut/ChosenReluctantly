class_name Map4aTest
extends GdUnitTestSuite
## MAP4 sitting A: the D49 prune/reject offer weights (RunState.offer_weights, RewardOffer), the forced relic offer at a mini-boss,
## and the "ready again" wording of a 60 s reduce_cooldown.

const BLEED_CARD := "rogue_bleed_slash"
const PLAIN_CARD := "rogue_brawl_clause"


func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


func _state(act: int = 1) -> RunState:
	var state: RunState = RunState.new_run(7, CharacterDatabase.starting_deck("rogue"), 3, "rogue")
	state.act = act
	state.acts_total = 3
	state.hp = 20.0
	state.max_hp = 30.0
	return state


func _rewards() -> Dictionary:
	return {"prune_reject_factor": 0.8, "prune_reject_floor": 0.4}


func test_each_discard_multiplies_the_status_weight_down_to_the_floor() -> void:
	var state: RunState = _state()
	state.discount_card_types(BLEED_CARD, _rewards())
	assert_float(float(state.offer_weights["bleed"])).is_equal_approx(0.8, 0.0001)
	state.discount_card_types(BLEED_CARD, _rewards())
	assert_float(float(state.offer_weights["bleed"])).is_equal_approx(0.64, 0.0001)
	for i in range(10):
		state.discount_card_types(BLEED_CARD, _rewards())
	assert_float(float(state.offer_weights["bleed"])).is_equal_approx(0.4, 0.0001)


func test_a_card_with_no_status_or_an_absent_factor_changes_nothing() -> void:
	var state: RunState = _state()
	state.discount_card_types(PLAIN_CARD, _rewards())
	state.discount_card_types(BLEED_CARD, {})
	state.discount_card_types("no_such_card", _rewards())
	assert_dict(state.offer_weights).is_empty()


func test_a_reject_discounts_only_offered_cards_not_in_the_deck() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.pending = RunState.PENDING_REWARD
	state.offer = [BLEED_CARD, PLAIN_CARD, "rogue_cut_corners"] as Array[String]
	var result: Dictionary = RunChoices.apply(state, "skip", ctx)
	assert_bool(bool(result["ok"])).is_true()
	assert_float(float(state.offer_weights["bleed"])).is_less(0.7)  # two bleed cards in the offer, neither owned: 0.8 x 0.8
	assert_bool(state.offer_weights.has("burn")).is_false()


func test_a_reject_leaves_owned_cards_at_full_weight() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.deck.append(BLEED_CARD)
	state.pending = RunState.PENDING_REWARD
	state.offer = [BLEED_CARD, PLAIN_CARD, "rogue_cut_corners"] as Array[String]
	RunChoices.apply(state, "skip", ctx)
	var only_other: RunState = _state()
	only_other.pending = RunState.PENDING_REWARD
	only_other.offer = ["rogue_cut_corners"] as Array[String]
	RunChoices.apply(only_other, "skip", ctx)
	assert_dict(state.offer_weights).is_equal(only_other.offer_weights)
	var owned_only: RunState = _state()
	owned_only.deck.append(BLEED_CARD)
	owned_only.pending = RunState.PENDING_REWARD
	owned_only.offer = [BLEED_CARD] as Array[String]
	RunChoices.apply(owned_only, "skip", ctx)
	assert_dict(owned_only.offer_weights).is_empty()
	assert_int(owned_only.rejects_remaining).is_equal(2)  # the reject is still spent


func test_the_weights_round_trip_and_a_bad_save_value_is_dropped() -> void:
	var state: RunState = _state()
	state.offer_weights = {"bleed": 0.64, "burn": 0.8}
	var back: RunState = RunState.from_json(state.to_json())
	assert_dict(back.offer_weights).is_equal({"bleed": 0.64, "burn": 0.8})
	var data: Dictionary = state.to_dict()
	data["offer_weights"] = {"bleed": 0.5, "burn": "x", "poison": -1.0, "fire": 7.0, "": 0.5}
	var repaired: RunState = RunState.from_dict(data)
	assert_dict(repaired.offer_weights).is_equal({"bleed": 0.5})
	data["offer_weights"] = [1, 2]
	assert_dict(RunState.from_dict(data).offer_weights).is_empty()
	data.erase("offer_weights")
	assert_dict(RunState.from_dict(data).offer_weights).is_empty()  # an old save


func test_a_lower_weight_makes_the_status_rarer_and_none_keeps_the_old_offers() -> void:
	var ctx: Dictionary = _ctx()
	var deck: Array = CharacterDatabase.starting_deck("rogue")
	var weights: Dictionary = {"bleed": 0.4}
	var plain: int = 0
	var cut: int = 0
	for run_seed in range(1, 301):
		var base: Array[String] = RewardOffer.generate(run_seed, 1, deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
		assert_array(RewardOffer.generate(run_seed, 1, deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"], [], [], 1, "", {})).is_equal(base)
		for id: String in base:
			plain += 1 if CardSummary.status_ids(CardDatabase.get_card(id)).has("bleed") else 0
		for id: String in RewardOffer.generate(run_seed, 1, deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"], [], [], 1, "", weights):
			cut += 1 if CardSummary.status_ids(CardDatabase.get_card(id)).has("bleed") else 0
	assert_int(cut).is_less(plain)


func test_prune_factor_takes_the_least_cut_status() -> void:
	var both: Dictionary = {"effects": [{"template": "apply_status", "params": {"status_id": "bleed"}}, {"template": "apply_status", "params": {"status_id": "burn"}}]}
	assert_float(RewardOffer.prune_factor_for(both, {"bleed": 0.4, "burn": 0.8})).is_equal_approx(0.8, 0.0001)
	assert_float(RewardOffer.prune_factor_for({"effects": []}, {"bleed": 0.4})).is_equal(1.0)


func test_a_forced_relic_offer_at_a_mini_boss_keeps_the_boss_relic_rules() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	RunSession.forced_relic_offer = ["the_micromanager"] as Array[String]
	assert_str(RunRelics.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_array(state.offer).is_equal(["the_micromanager"])
	assert_bool(RunRelics.is_boss_offer(state)).is_true()
	assert_array(RunSession.forced_relic_offer).is_empty()  # used once


func test_a_sixty_second_cooldown_cut_reads_as_ready_again() -> void:
	var text: String = CardSummary.effect_line(CardDatabase.get_card("rogue_knuckle_sandwich"))
	assert_bool(text.contains("60")).is_false()
	assert_str(text).contains("ready again")
