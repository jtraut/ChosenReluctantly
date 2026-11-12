class_name Map3bContentTest
extends GdUnitTestSuite
## MAP3b sitting B (BUILD_DEPTH 12.6): the shipped rare and legendary cards, the tier 1-3 relics and the boss relics meet the
## counting rule for each class's eligible set, validate, and never leak into a starting or pool-filled deck.

const CLASSES: Array[String] = ["rogue", "wizard"]


func before_test() -> void:
	RelicDatabase.load_all()


func _pools(character_id: String) -> Array[String]:
	return CharacterDatabase.pools(character_id)


func _cards(character_id: String, rarity: String) -> Array[String]:
	var found: Array[String] = []
	for entry: Variant in CardDatabase.all_cards():
		var card: Dictionary = entry
		if _pools(character_id).has(String(card.get("pool", ""))) and CardSchema.rarity_of(card) == rarity:
			found.append(String(card["id"]))
	return found


func _relics(character_id: String, rarity: String, source: String) -> Array[String]:
	var found: Array[String] = []
	for relic: Dictionary in RelicDatabase.all_relics():
		if _pools(character_id).has(String(relic["pool"])) and String(relic["rarity"]) == rarity and (relic["sources"] as Array).has(source):
			found.append(String(relic["id"]))
	return found


func test_every_relic_and_card_loads_clean() -> void:
	assert_array(RelicDatabase.problems()).is_empty()
	assert_int(CardDatabase.all_cards().size()).is_greater(60)


func test_each_class_sees_enough_top_tier_cards() -> void:
	for character_id: String in CLASSES:
		assert_int(_cards(character_id, "rare").size()).is_greater_equal(5)
		assert_int(_cards(character_id, "legendary").size()).is_greater_equal(4)


func test_class_pool_supplies_at_least_half_of_the_top_tier() -> void:
	for character_id: String in CLASSES:
		var class_pool: String = CharacterDatabase.class_pool(character_id)
		for rarity: String in ["rare", "legendary"]:
			var all: Array[String] = _cards(character_id, rarity)
			var own: int = 0
			for id: String in all:
				if String(CardDatabase.get_card(id)["pool"]) == class_pool:
					own += 1
			assert_bool(own * 2 >= all.size()).is_true()


func test_shipped_card_counts_by_rarity() -> void:
	var counts: Dictionary = {"common": 0, "rare": 0, "legendary": 0}
	for entry: Variant in CardDatabase.all_cards():
		counts[CardSchema.rarity_of(entry as Dictionary)] += 1
	assert_int(int(counts["rare"])).is_equal(9)
	assert_int(int(counts["legendary"])).is_equal(8)


func test_each_class_sees_six_boss_relics_and_about_22_standard_relics() -> void:
	for character_id: String in CLASSES:
		assert_int(_relics(character_id, "boss", "mini_boss").size()).is_greater_equal(6)
		var standard: int = 0
		for rarity: String in ["tier1", "tier2", "tier3"]:
			standard += _relics(character_id, rarity, "elite").size()
		assert_int(standard).is_between(21, 25)
		assert_int(_relics(character_id, "tier3", "elite").size()).is_greater_equal(5)


func test_boss_relics_are_mini_boss_only_and_rule_text_fits() -> void:
	for relic: Dictionary in RelicDatabase.all_relics():
		assert_int(String(relic["rule_text"]).length()).is_less_equal(120)
		if String(relic["rarity"]) == "boss":
			assert_array(relic["sources"] as Array).is_equal(["mini_boss"])


func test_card_trigger_relics_use_the_player() -> void:
	for relic: Dictionary in RelicDatabase.all_relics():
		for trigger: Dictionary in (relic["triggers"] as Array):
			if ["card_cast", "player_damaged"].has(String(trigger["event"])):
				assert_str(String(trigger.get("at", "player"))).is_equal("player")


func test_no_rare_or_legendary_card_in_any_starting_deck() -> void:
	for character_id: String in CLASSES:
		for id: String in CharacterDatabase.starting_deck(character_id):
			assert_str(CardSchema.rarity_of(CardDatabase.get_card(id))).is_equal("common")
	var dir := DirAccess.open("res://data/debug_decks")
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var preset: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/debug_decks/" + file_name))
		for id: Variant in ((preset as Dictionary)["starter"] as Array):
			assert_str(CardSchema.rarity_of(CardDatabase.get_card(String(id)))).is_equal("common")


func test_card_prices_sit_below_the_matching_relic_tier() -> void:
	var cards: Dictionary = (MerchantConfig.block() as Dictionary).get("card_prices", {})
	var relics: Dictionary = (RelicConfig.block() as Dictionary).get("prices", {})
	assert_bool(float(cards["common"]) < float(relics["tier1"])).is_true()
	assert_bool(float(cards["rare"]) < float(relics["tier2"])).is_true()
	assert_bool(float(cards["legendary"]) < float(relics["tier3"])).is_true()

