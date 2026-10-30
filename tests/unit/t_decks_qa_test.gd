class_name TDecksQaTest
extends GdUnitTestSuite
## qa additions for T-decks: gaps left by t_decks_test.gd (list with a broken file, Try again after clear, pool limits,
## case sensitivity, malformed entries, description shape).

const DIR := "user://t_decks_qa_fixture"


func after_test() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunSession.forced_seed = -1
	if DirAccess.dir_exists_absolute(DIR):
		for file_name in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(file_name))
		DirAccess.remove_absolute(DIR)


func _presets() -> Dictionary:
	return DebugDecks.read_dir()["presets"]


func _write(preset_name: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR.path_join(preset_name + ".json"), FileAccess.WRITE)
	file.store_string(data if typeof(data) == TYPE_STRING else JSON.stringify(data))
	file.close()


func test_list_decks_with_a_broken_file_marks_it_invalid_and_exits_2() -> void:
	var good: Dictionary = _presets()["mixed-rogue"].duplicate(true)
	good["name"] = "fine"
	_write("fine", good)
	_write("broken", "{ this is not json")
	var launch := DebugDecks.resolve_launch(PackedStringArray(["--list-decks"]), DebugDecks.read_dir(DIR))
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	var text := " | ".join(PackedStringArray(launch["lines"]))
	assert_str(text).contains("fine - ")
	assert_str(text).contains("broken - INVALID")


func test_unreadable_folder_is_reported_not_silent() -> void:
	var directory := DebugDecks.read_dir("user://t_decks_no_such_folder")
	assert_array(directory["load_problems"]).is_not_empty()
	var launch := DebugDecks.resolve_launch(PackedStringArray(["--deck=mixed-rogue"]), directory)
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	assert_str(" | ".join(PackedStringArray(launch["errors"]))).contains("unknown debug deck")


func test_deck_names_are_case_sensitive_and_exact() -> void:
	for bad in ["--deck=Mixed-Rogue", "--deck=mixed-rogue.json", "--deck=mixed_rogue"]:
		var launch := DebugDecks.resolve_launch(PackedStringArray([bad]), DebugDecks.read_dir())
		assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
		assert_str(String(launch["deck"])).is_equal("")


func test_two_different_decks_is_an_error_and_names_none() -> void:
	var launch := DebugDecks.resolve_launch(PackedStringArray(["--deck=mixed-rogue", "--deck=physical-rogue"]), DebugDecks.read_dir())
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	assert_str(String(launch["deck"])).is_equal("")


func test_malformed_entries_are_reported_without_crashing() -> void:
	var slot_of := DeckRules.slot_map_from_database()
	var base: Dictionary = _presets()["mixed-rogue"].duplicate(true)
	var bad_type := base.duplicate(true)
	(bad_type["starter"] as Array)[0] = 42
	var text := " | ".join(PackedStringArray(DebugDecks.validate_preset("mixed-rogue", bad_type, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())))
	assert_str(text).contains("entries must be card id strings")
	var empty := base.duplicate(true)
	empty["starter"] = []
	text = " | ".join(PackedStringArray(DebugDecks.validate_preset("mixed-rogue", empty, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())))
	assert_str(text).contains("'starter' must be a non-empty array")
	var blank := base.duplicate(true)
	blank["description"] = "   "
	assert_array(DebugDecks.validate_preset("mixed-rogue", blank, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())).is_not_empty()


func test_full_deck_failing_the_rules_is_reported_separately_from_starter() -> void:
	var data: Dictionary = _presets()["mixed-rogue"].duplicate(true)
	data["full"] = (data["full"] as Array).filter(func(id: Variant) -> bool: return not String(id).begins_with("neutral_"))
	var text := " | ".join(PackedStringArray(DebugDecks.validate_preset("mixed-rogue", data, DeckRules.slot_map_from_database(), DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())))
	assert_str(text).contains("full breaks the deck rules")


func test_shipped_presets_use_only_the_characters_pools_and_one_line_descriptions() -> void:
	var pools: Array = RunConfig.character_pools()
	for preset_name: String in _presets():
		var preset: Dictionary = _presets()[preset_name]
		assert_bool(String(preset["description"]).contains("\n")).is_false()
		for key in ["starter", "full"]:
			for card_id: String in preset[key]:
				assert_bool(pools.has(String(CardDatabase.get_card(card_id).get("pool", "")))).override_failure_message("%s.%s: %s is outside the character's pools" % [preset_name, key, card_id]).is_true()


func test_fire_heavy_has_every_fire_card_and_physical_has_the_fewest_possible() -> void:
	var all_fire: Array = RunConfig.cards_in_pools(["fire"])
	var fire_starter: Array = (_presets()["fire-heavy-rogue"]["starter"] as Array)
	for card_id: String in all_fire:
		assert_bool(fire_starter.has(card_id)).override_failure_message("fire-heavy starter lacks " + card_id).is_true()
	# The non-Fire pool cannot supply 3 unique Utility or 3 unique AoE cards: count it from the data, not from the preset.
	var spare: Dictionary = {}
	for card_id: String in RunConfig.cards_in_pools(["rogue", "neutral"]):
		var slot: String = String(CardDatabase.get_card(card_id).get("slot_type", ""))
		spare[slot] = int(spare.get(slot, 0)) + 1
	var needed_fire: int = 0
	for slot: String in spare:
		needed_fire += maxi(0, 3 - int(spare[slot]))
	assert_int(needed_fire).is_equal(2)


func test_try_again_after_clear_keeps_the_preset_but_gets_a_new_seed() -> void:
	var preset: Dictionary = _presets()["physical-rogue"]
	RunSession.debug_deck = preset
	RunSession.forced_seed = 7
	var first := RunSession.begin_new_run()
	assert_int(first.seed_value).is_equal(7)
	RunSession.clear()
	var again := RunSession.ensure_run()
	assert_array(again.deck).is_equal(DebugDecks.deck_of(preset, false))
	assert_int(again.seed_value).is_not_equal(7)
