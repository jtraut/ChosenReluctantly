class_name Sim2a1Test
extends GdUnitTestSuite
## SIM2a-1: the formulated bot's draft brain (DraftPolicy). It scores cards and relics from card DATA (tags, conditions, keywords), never ids.

const BURN_DECK: Array[String] = ["fire_ember_whatever", "fire_fine_burn_then", "fire_kindling", "fire_blaze_and_bail", "fire_scorched_earth", "rogue_quick_slash", "neutral_deep_sigh"]
const BLEED_DECK: Array[String] = ["rogue_bleed_slash", "rogue_open_a_vein", "rogue_paper_cuts", "rogue_cut_corners", "rogue_knife_drawer", "rogue_quick_slash", "neutral_deep_sigh"]


func _cards(ids: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card_id: String in ids:
		out.append(CardDatabase.get_card(card_id))
	return out


func _score(card_id: String, deck_ids: Array[String]) -> float:
	return DraftPolicy.score_card(CardDatabase.get_card(card_id), DraftPolicy.profile(_cards(deck_ids)))


func _offer(card_ids: Array[String], with_skip: bool = true) -> Array:
	var options: Array = []
	for card_id: String in card_ids:
		options.append({"id": "pick:" + card_id, "kind": "card", "card_id": card_id, "enabled": true})
	if with_skip:
		options.append({"id": "skip", "kind": "skip", "enabled": true})
	return options


func _bloated() -> Array[String]:
	var out: Array[String] = []
	for _i: int in range(12):
		out.append_array(BURN_DECK)
	return out


func test_a_burn_deck_prefers_a_burn_card_over_a_bleed_card() -> void:
	assert_float(_score("fire_slow_burn", BURN_DECK)).is_greater(_score("rogue_exsanguinate", BURN_DECK))
	var pick: String = DraftPolicy.reward_choice(_offer(["rogue_exsanguinate", "fire_slow_burn"]), BURN_DECK, 7)
	assert_str(pick).is_equal("pick:fire_slow_burn")


func test_a_bleed_deck_prefers_a_bleed_card_over_a_burn_card() -> void:
	assert_float(_score("rogue_exsanguinate", BLEED_DECK)).is_greater(_score("fire_slow_burn", BLEED_DECK))
	var pick: String = DraftPolicy.reward_choice(_offer(["fire_slow_burn", "rogue_exsanguinate"]), BLEED_DECK, 7)
	assert_str(pick).is_equal("pick:rogue_exsanguinate")


func test_a_payoff_whose_condition_the_deck_cannot_meet_scores_under_one_it_can() -> void:
	# Arterial Spray pays off against Bleed: live in the Bleed deck, dead in the Burn deck.
	assert_float(_score("rogue_arterial_spray", BLEED_DECK)).is_greater(_score("rogue_arterial_spray", BURN_DECK))


func test_a_primer_scores_higher_when_the_deck_has_the_burn_it_feeds() -> void:
	var plain: Array[String] = ["rogue_quick_slash", "neutral_deep_sigh", "rogue_nap_time"]
	assert_float(_score("fire_kindling", BURN_DECK)).is_greater(_score("fire_kindling", plain))


func test_the_scorer_never_reads_ids_a_renamed_card_scores_the_same() -> void:
	var card: Dictionary = CardDatabase.get_card("fire_slow_burn").duplicate(true)
	var renamed: Dictionary = card.duplicate(true)
	renamed["id"] = "zz_totally_different_id"
	renamed["name"] = "Something Else Entirely"
	var prof: Dictionary = DraftPolicy.profile(_cards(BURN_DECK))
	assert_float(DraftPolicy.score_card(renamed, prof)).is_equal(DraftPolicy.score_card(card, prof))
	# Renamed in the deck too (every deck card renamed consistently): the same score.
	var deck_renamed: Array[Dictionary] = []
	var index: int = 0
	for source: Dictionary in _cards(BURN_DECK):
		var copy: Dictionary = source.duplicate(true)
		copy["id"] = "renamed_%d" % index
		deck_renamed.append(copy)
		index += 1
	assert_float(DraftPolicy.score_card(card, DraftPolicy.profile(deck_renamed))).is_equal(DraftPolicy.score_card(card, prof))


func test_it_is_deterministic() -> void:
	var options: Array = _offer(["fire_slow_burn", "rogue_exsanguinate", "neutral_healing_potion"])
	var first: String = DraftPolicy.reward_choice(options, BURN_DECK, 7)
	for _i: int in range(5):
		assert_str(DraftPolicy.reward_choice(options, BURN_DECK, 7)).is_equal(first)


func test_it_skips_when_nothing_clears_a_threshold_that_grows_with_the_deck() -> void:
	assert_str(DraftPolicy.reward_choice(_offer(["rogue_exsanguinate"]), _bloated(), 7)).is_equal("skip")
	assert_float(DraftPolicy.skip_threshold(30, 15)).is_greater(DraftPolicy.skip_threshold(15, 15))


func test_with_the_skip_disabled_the_best_card_is_taken() -> void:
	var options: Array = _offer(["rogue_exsanguinate"])
	(options[1] as Dictionary)["enabled"] = false
	assert_str(DraftPolicy.reward_choice(options, _bloated(), 7)).is_equal("pick:rogue_exsanguinate")


func test_a_card_of_a_slot_the_deck_lacks_scores_above_the_same_card_in_a_covered_deck() -> void:
	var recovery_card: String = ""
	for card: Variant in CardDatabase.cards_for_slot_type("recovery"):
		recovery_card = String((card as Dictionary)["id"])
		break
	assert_str(recovery_card).is_not_empty()
	var covered: Array[String] = BURN_DECK.duplicate()
	for card: Variant in CardDatabase.cards_for_slot_type("recovery"):
		if covered.size() < BURN_DECK.size() + 3 and String((card as Dictionary)["id"]) != recovery_card:
			covered.append(String((card as Dictionary)["id"]))
	assert_float(_score(recovery_card, BURN_DECK)).is_greater(_score(recovery_card, covered))


func test_the_relic_scorer_prefers_a_relic_that_fits_the_deck() -> void:
	var burn_prof: Dictionary = DraftPolicy.profile(_cards(BURN_DECK))
	var bleed_prof: Dictionary = DraftPolicy.profile(_cards(BLEED_DECK))
	var pyre: Dictionary = RelicDatabase.get_relic("pyre_insurance")
	var serrated: Dictionary = RelicDatabase.get_relic("serrated_excuse")
	assert_float(DraftPolicy.score_relic(pyre, burn_prof, false)).is_greater(DraftPolicy.score_relic(serrated, burn_prof, false))
	assert_float(DraftPolicy.score_relic(serrated, bleed_prof, false)).is_greater(DraftPolicy.score_relic(pyre, bleed_prof, false))
	var options: Array = [{"id": "relic:serrated_excuse", "kind": "relic", "enabled": true}, {"id": "relic:pyre_insurance", "kind": "relic", "enabled": true}, {"id": "relic_skip", "kind": "relic_skip", "enabled": true}]
	assert_str(DraftPolicy.relic_choice(options, BURN_DECK)).is_equal("relic:pyre_insurance")
	assert_str(DraftPolicy.relic_choice(options, BLEED_DECK)).is_equal("relic:serrated_excuse")


func test_the_relic_giveup_drops_the_one_that_fits_least_and_keeps_the_confirm_step() -> void:
	var options: Array = [{"id": "giveup:pyre_insurance", "kind": "giveup", "enabled": true}, {"id": "giveup:serrated_excuse", "kind": "giveup", "enabled": true}, {"id": "giveup_cancel", "kind": "back", "enabled": true}]
	assert_str(DraftPolicy.giveup_choice(options, BURN_DECK)).is_equal("giveup:serrated_excuse")
	assert_str(DraftPolicy.giveup_choice(options, BLEED_DECK)).is_equal("giveup:pyre_insurance")
	options.append({"id": "confirm", "kind": "giveup_confirm", "enabled": true})
	assert_str(DraftPolicy.giveup_choice(options, BURN_DECK)).is_equal("confirm")
	assert_str(DraftPolicy.giveup_choice([{"id": "giveup_cancel", "kind": "back", "enabled": true}], BURN_DECK)).is_equal("giveup_cancel")


func test_the_deck_summary_names_the_dominant_status_and_its_share() -> void:
	var summary: Dictionary = DraftPolicy.deck_summary(BURN_DECK)
	assert_str(String(summary["dominant_status"])).is_equal("burn")
	assert_float(float(summary["share"])).is_greater(0.4)
	assert_str(String(DraftPolicy.deck_summary(BLEED_DECK)["dominant_status"])).is_equal("bleed")


func test_the_flag_off_policies_are_untouched() -> void:
	# The flag-off path still calls the old policy: the first relic whose keyword the deck carries three times.
	var options: Array = [{"id": "relic:a", "kind": "relic", "enabled": true, "keywords": ["Zone"]}, {"id": "relic:b", "kind": "relic", "enabled": true, "keywords": ["Burn"]}]
	assert_str(RelicPolicy.offer_choice(options, ["fire_ember_whatever", "fire_fine_burn_then", "fire_blaze_and_bail"] as Array[String])).is_equal("relic:b")
