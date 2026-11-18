class_name LoadoutDataTest
extends GdUnitTestSuite
## 3d sitting B: card availability, the collection, starter relics, data/loadouts.json and the per-entry rule checks.

const RELICS_BY_CLASS: Dictionary = {
	"rogue": ["chasing_paper", "spite_knuckles"],
	"wizard": ["ergonomic_chair", "paperwork_fire"],
}


func before_test() -> void:
	CardDatabase.load_all()  # other suites load fixture card sets into the static database
	RelicDatabase.load_all()


func _card(overrides: Dictionary = {}) -> Dictionary:
	var card: Dictionary = {
		"id": "x", "name": "X", "flavor_text": "f", "slot_type": "utility", "pool": "neutral", "cooldown_modifier": 0.0,
		"availability": "starter",
		"effects": [{"template": "heal", "params": {"amount": 1.0}}],
	}
	card.merge(overrides, true)
	return card


# ---- availability ----

func test_the_shipped_cards_all_validate_with_availability() -> void:
	for card: Variant in CardDatabase.all_cards():
		assert_array(CardSchema.validate(card)).override_failure_message("%s: %s" % [(card as Dictionary).get("id"), CardSchema.validate(card)]).is_empty()


func test_d52_default_common_is_starter_rare_and_legendary_are_reward() -> void:
	for card: Variant in CardDatabase.all_cards():
		if CardSchema.is_curse(card):
			continue
		var expected: String = "starter" if CardSchema.rarity_of(card) == "common" else "reward"
		assert_str(CardSchema.availability_of(card)).override_failure_message(str((card as Dictionary)["id"])).is_equal(expected)


func test_a_non_curse_card_needs_a_known_availability() -> void:
	var missing: Dictionary = _card()
	missing.erase("availability")
	assert_array(CardSchema.validate(missing)).is_not_empty()
	assert_array(CardSchema.validate(_card({"availability": "free"}))).is_not_empty()
	assert_array(CardSchema.validate(_card({"availability": 3}))).is_not_empty()
	assert_array(CardSchema.validate(_card())).is_empty()
	assert_array(CardSchema.validate(_card({"availability": "reward"}))).is_empty()


func test_a_locked_card_carries_unlock_text_or_tbd_and_others_do_not() -> void:
	assert_array(CardSchema.validate(_card({"availability": "locked"}))).is_not_empty()
	assert_array(CardSchema.validate(_card({"availability": "locked", "unlock": ""}))).is_not_empty()
	assert_array(CardSchema.validate(_card({"availability": "locked", "unlock": "TBD"}))).is_empty()
	assert_array(CardSchema.validate(_card({"availability": "locked", "unlock": "Beat act 2"}))).is_empty()
	assert_array(CardSchema.validate(_card({"availability": "starter", "unlock": "x"}))).is_not_empty()
	assert_str(CardSchema.unlock_text_of(_card({"availability": "locked", "unlock": "Beat act 2"}))).is_equal("Beat act 2")
	assert_str(CardSchema.unlock_text_of(_card({"availability": "starter"}))).is_equal("")


func test_a_curse_that_carries_availability_fails_and_one_without_it_passes() -> void:
	var curse: Dictionary = _card({"curse": true, "effects": []})
	assert_array(CardSchema.validate(curse)).is_not_empty()
	curse.erase("availability")
	assert_array(CardSchema.validate(curse)).is_empty()
	assert_str(CardSchema.availability_of(curse)).is_equal("")


# ---- collection ----

func test_the_collection_has_no_curses_and_splits_into_starter_and_plan() -> void:
	for character_id: String in CharacterDatabase.ids():
		var all: Array[String] = LoadoutCollection.collection(character_id)
		var starters: Array[String] = LoadoutCollection.starter_cards(character_id)
		var plans: Array[String] = LoadoutCollection.plan_cards(character_id)
		assert_int(starters.size() + plans.size()).is_equal(all.size())
		for id: String in all:
			assert_bool(CardSchema.is_curse(CardDatabase.get_card(id))).is_false()
		for id: String in starters:
			assert_bool(plans.has(id)).is_false()
		assert_bool(all.has("curse_property_damage")).is_false()


func test_every_slot_keeps_at_least_three_unique_starter_cards_for_both_classes() -> void:
	for character_id: String in CharacterDatabase.ids():
		var check: DeckCheck = LoadoutCheck.deck_check(LoadoutCollection.starter_cards(character_id))
		assert_array(check.problems).override_failure_message("%s: %s" % [character_id, check.problems]).is_empty()


func test_the_shipped_starting_decks_are_loadout_legal() -> void:
	for character_id: String in CharacterDatabase.ids():
		assert_array(LoadoutCheck.deck_problems(character_id, CharacterDatabase.starting_deck(character_id))).is_empty()


# ---- starter relics ----

func test_each_class_has_exactly_its_two_starter_relics() -> void:
	for character_id: String in RELICS_BY_CLASS.keys():
		var found: Array[String] = LoadoutCollection.starter_relics(character_id)
		var want: Array = (RELICS_BY_CLASS[character_id] as Array).duplicate()
		want.sort()
		assert_array(found).is_equal(want)


func test_only_the_four_relics_carry_the_starter_source() -> void:
	var carriers: Array[String] = []
	for relic: Dictionary in RelicDatabase.all_relics():
		if (relic["sources"] as Array).has("starter"):
			carriers.append(String(relic["id"]))
	carriers.sort()
	assert_array(carriers).is_equal(["chasing_paper", "ergonomic_chair", "paperwork_fire", "spite_knuckles"])


func test_starter_is_never_a_source_a_room_asks_for() -> void:
	# Every real offer asks RelicOffer for one of these sources; "starter" is none of them, so the tag alone never puts a relic in an offer.
	for source: String in ["elite", "relic_room", "merchant", "mini_boss", "event"]:
		assert_bool(RelicSchema.SOURCES.has(source)).is_true()
	assert_str(RelicSchema.BOSS_SOURCE).is_not_equal("starter")
	var starter_only: Array[Dictionary] = RelicOffer.eligible("starter", RelicConfig.tier_weights_for_act(1), [], [], CharacterDatabase.pools("rogue"), RelicDatabase.all_relics())
	assert_int(starter_only.size()).is_equal(2)


func test_the_ordinary_offer_sets_are_unchanged_by_the_starter_source() -> void:
	# A relic's presence in an offer depends on its other sources only: removing "starter" from the four leaves every real source's eligible set identical.
	var stripped: Array = []
	for relic: Dictionary in RelicDatabase.all_relics():
		var copy: Dictionary = relic.duplicate(true)
		(copy["sources"] as Array).erase("starter")
		stripped.append(copy)
	for source: String in ["elite", "relic_room", "merchant", "mini_boss", "event"]:
		for character_id: String in CharacterDatabase.ids():
			var weights: Dictionary = RelicConfig.tier_weights_for_act(2)
			var none: Array[String] = []
			var rarities: Array[String] = RelicOffer.DEFAULT_RARITIES
			if source == "mini_boss":
				rarities = ["boss"]
			var with_tag: Array[Dictionary] = RelicOffer.eligible(source, weights, none, none, CharacterDatabase.pools(character_id), RelicDatabase.all_relics(), rarities)
			var without: Array[Dictionary] = RelicOffer.eligible(source, weights, none, none, CharacterDatabase.pools(character_id), stripped, rarities)
			assert_int(with_tag.size()).is_equal(without.size())


# ---- data/loadouts.json ----

func test_the_shipped_loadouts_file_is_valid() -> void:
	assert_array(LoadoutRules.shipped_problems()).is_empty()
	assert_int(LoadoutRules.slots_per_class()).is_equal(5)
	assert_int(LoadoutRules.max_copies()).is_equal(2)
	assert_int(LoadoutRules.deck_max()).is_equal(20)
	assert_int(LoadoutRules.deck_min()).is_equal(15)
	assert_int(LoadoutRules.name_max_length()).is_equal(24)


func test_loadouts_config_rejects_unknown_keys_missing_keys_and_bad_values() -> void:
	var good: Dictionary = {"version": 1, "slots_per_class": 5, "max_copies": 2, "deck_max": 20, "name_max_length": 24}
	assert_array(LoadoutRules.validate(good, 15)).is_empty()
	var extra: Dictionary = good.duplicate()
	extra["colour"] = "red"
	assert_array(LoadoutRules.validate(extra, 15)).is_not_empty()
	var missing: Dictionary = good.duplicate()
	missing.erase("max_copies")
	assert_array(LoadoutRules.validate(missing, 15)).is_not_empty()
	for key: String in ["version", "slots_per_class", "max_copies", "deck_max", "name_max_length"]:
		for bad: Variant in [0, -1, 2.5, "5", null]:
			var broken: Dictionary = good.duplicate()
			broken[key] = bad
			assert_array(LoadoutRules.validate(broken, 15)).override_failure_message("%s = %s" % [key, str(bad)]).is_not_empty()
	var few: Dictionary = good.duplicate()
	few["slots_per_class"] = 4
	assert_array(LoadoutRules.validate(few, 15)).is_not_empty()
	var small: Dictionary = good.duplicate()
	small["deck_max"] = 14
	assert_array(LoadoutRules.validate(small, 15)).is_not_empty()
	assert_array(LoadoutRules.validate([], 15)).is_not_empty()


# ---- entry checks ----

func _legal_deck(character_id: String) -> Array[String]:
	return CharacterDatabase.starting_deck(character_id)


func test_a_legal_entry_passes_for_both_classes() -> void:
	for character_id: String in CharacterDatabase.ids():
		var entry: Dictionary = LoadoutCheck.make_entry("Mine", _legal_deck(character_id))
		assert_array(LoadoutCheck.entry_problems(character_id, entry)).is_empty()


func test_deck_size_limits() -> void:
	var deck: Array[String] = _legal_deck("rogue")
	var short: Array[String] = deck.slice(0, 14)
	assert_array(LoadoutCheck.deck_problems("rogue", short)).is_not_empty()
	# 20 cards of starter cards with copies passes the size rule; 21 does not.
	var twenty: Array[String] = deck.duplicate()
	var extras: Array[String] = LoadoutCollection.starter_cards("rogue")
	for id: String in extras:
		if twenty.size() >= 20:
			break
		if twenty.count(id) == 0:
			twenty.append(id)
	assert_int(twenty.size()).is_equal(20)
	assert_array(LoadoutCheck.deck_problems("rogue", twenty)).is_empty()
	twenty.append(deck[0])
	assert_bool(" ".join(LoadoutCheck.deck_problems("rogue", twenty)).contains("at most 20")).is_true()


func test_copies_are_capped_at_max_copies() -> void:
	var deck: Array[String] = _legal_deck("rogue")
	deck.append(deck[0])
	assert_array(LoadoutCheck.deck_problems("rogue", deck)).is_empty()  # 2 copies, 16 cards
	deck.append(deck[0])
	assert_bool(" ".join(LoadoutCheck.deck_problems("rogue", deck)).contains("at most 2 copies")).is_true()


func test_a_deck_that_breaks_a_unique_card_rule_gets_the_checkers_message() -> void:
	var deck: Array[String] = _legal_deck("rogue")
	var movement: Array[String] = []
	for id: String in deck:
		if CardDatabase.get_card(id)["slot_type"] == "movement":
			movement.append(id)
	var broken: Array[String] = deck.duplicate()
	broken.erase(movement[0])
	broken.append(movement[1])  # same size, one unique movement card fewer
	var problems: Array[String] = LoadoutCheck.deck_problems("rogue", broken)
	var expected: Array[String] = LoadoutCheck.deck_check(broken).problems
	assert_array(expected).is_not_empty()
	for message: String in expected:
		assert_bool(problems.has(message)).is_true()
	assert_array(LoadoutCheck.deck_check(broken).summary_lines()).contains(["Movement 2/3  SHORT"])


func test_a_curse_or_unknown_or_foreign_or_non_starter_card_in_the_deck_is_refused() -> void:
	var deck: Array[String] = _legal_deck("rogue")
	for bad: String in ["curse_property_damage", "no_such_card", "wizard_bolt_volley"]:
		var changed: Array[String] = deck.duplicate()
		changed[0] = bad
		assert_array(LoadoutCheck.deck_problems("rogue", changed)).override_failure_message(bad).is_not_empty()
	var rare: String = ""
	for id: String in LoadoutCollection.plan_cards("rogue"):
		rare = id
		break
	assert_str(rare).is_not_empty()
	var with_reward: Array[String] = deck.duplicate()
	with_reward.append(rare)
	var text: String = " ".join(LoadoutCheck.deck_problems("rogue", with_reward))
	assert_bool(text.contains("not a starter card")).is_true()


func test_a_plan_holds_only_reward_or_locked_cards_once_each() -> void:
	var plan_cards: Array[String] = LoadoutCollection.plan_cards("rogue")
	assert_array(LoadoutCheck.plan_problems("rogue", plan_cards.slice(0, 3))).is_empty()
	assert_array(LoadoutCheck.plan_problems("rogue", [plan_cards[0], plan_cards[0]])).is_not_empty()
	assert_array(LoadoutCheck.plan_problems("rogue", ["curse_property_damage"])).is_not_empty()
	assert_array(LoadoutCheck.plan_problems("rogue", [_legal_deck("rogue")[0]])).is_not_empty()  # a starter card is not a plan card
	assert_array(LoadoutCheck.plan_problems("rogue", ["nope"])).is_not_empty()
	assert_array(LoadoutCheck.plan_problems("rogue", [3])).is_not_empty()


func test_the_starter_relic_must_be_none_or_one_of_the_classes_two() -> void:
	assert_array(LoadoutCheck.relic_problems("rogue", "")).is_empty()
	assert_array(LoadoutCheck.relic_problems("rogue", "chasing_paper")).is_empty()
	assert_array(LoadoutCheck.relic_problems("rogue", "ergonomic_chair")).is_not_empty()  # the other class's
	assert_array(LoadoutCheck.relic_problems("rogue", "no_such_relic")).is_not_empty()
	var non_starter: String = ""
	for relic: Dictionary in RelicDatabase.all_relics():
		if not (relic["sources"] as Array).has("starter") and String(relic["pool"]) == "rogue":
			non_starter = String(relic["id"])
			break
	assert_array(LoadoutCheck.relic_problems("rogue", non_starter)).is_not_empty()
	assert_array(LoadoutCheck.relic_problems("rogue", 4)).is_not_empty()


func test_name_rules() -> void:
	assert_array(LoadoutCheck.name_problems("Water Rogue")).is_empty()
	assert_array(LoadoutCheck.name_problems("")).is_not_empty()
	assert_array(LoadoutCheck.name_problems("   ")).is_not_empty()
	assert_array(LoadoutCheck.name_problems("x".repeat(24))).is_empty()
	assert_array(LoadoutCheck.name_problems("x".repeat(25))).is_not_empty()
	assert_array(LoadoutCheck.name_problems(7)).is_not_empty()


func test_entry_shape_problems() -> void:
	var good: Dictionary = LoadoutCheck.make_entry("A", _legal_deck("rogue"))
	assert_array(LoadoutCheck.entry_problems("rogue", "text")).is_not_empty()
	var extra: Dictionary = good.duplicate(true)
	extra["colour"] = 1
	assert_array(LoadoutCheck.entry_problems("rogue", extra)).is_not_empty()
	for key: String in LoadoutCheck.ENTRY_KEYS:
		var missing: Dictionary = good.duplicate(true)
		missing.erase(key)
		assert_array(LoadoutCheck.entry_problems("rogue", missing)).override_failure_message(key).is_not_empty()
	var bad_deck: Dictionary = good.duplicate(true)
	bad_deck["deck"] = "all of them"
	assert_array(LoadoutCheck.entry_problems("rogue", bad_deck)).is_not_empty()
	var bad_passive: Dictionary = good.duplicate(true)
	bad_passive["passive_allocation"] = {}
	assert_array(LoadoutCheck.entry_problems("rogue", bad_passive)).is_not_empty()
