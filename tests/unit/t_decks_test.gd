class_name TDecksTest
extends GdUnitTestSuite
## T-decks: debug preset decks (data/debug_decks), launch-arg resolution, and how a new run takes the preset.

const SHIPPED: Array[String] = ["fire-heavy-rogue", "mixed-rogue", "physical-rogue"]


func after_test() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunSession.forced_seed = -1


func _problems(file_name: String, data: Variant) -> Array[String]:
	return DebugDecks.validate_preset(file_name, data, DeckRules.slot_map_from_database(), DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())


func _good() -> Dictionary:
	return (DebugDecks.read_dir()["presets"] as Dictionary)["mixed-rogue"].duplicate(true)


func _resolve(args: Array[String]) -> Dictionary:
	return DebugDecks.resolve_launch(PackedStringArray(args), DebugDecks.read_dir())


func _joined(list: Array) -> String:
	return " | ".join(PackedStringArray(list))


# ---- Shipped presets ----

func test_every_shipped_preset_loads_and_starter_is_a_subset_of_full() -> void:
	var directory := DebugDecks.read_dir()
	assert_array(directory["load_problems"]).is_empty()
	assert_dict(directory["problems"]).is_empty()
	for preset_name in SHIPPED:
		assert_bool((directory["presets"] as Dictionary).has(preset_name)).is_true()
		var preset: Dictionary = (directory["presets"] as Dictionary)[preset_name]
		assert_str(String(preset["name"])).is_equal(preset_name)
		assert_array(DeckRules.check_shipped(preset["starter"]).problems).is_empty()
		assert_array(DeckRules.check_shipped(preset["full"]).problems).is_empty()
		assert_array(DebugDecks.subset_problems(preset["starter"], preset["full"])).is_empty()
		assert_int((preset["starter"] as Array).size()).is_between(12, 18)


func test_mixed_rogue_is_the_current_starter_and_the_whole_pool() -> void:
	var preset: Dictionary = (DebugDecks.read_dir()["presets"] as Dictionary)["mixed-rogue"]
	assert_array(DebugDecks.deck_of(preset, false)).is_equal(RunConfig.starting_deck())
	var full := DebugDecks.deck_of(preset, true)
	full.sort()
	assert_array(full).is_equal(RunConfig.cards_in_pools(RunConfig.character_pools()))


func test_preset_family_shapes() -> void:
	var presets: Dictionary = DebugDecks.read_dir()["presets"]
	var fire: Dictionary = presets["fire-heavy-rogue"]
	assert_int(int(DebugDecks.pool_counts(fire["starter"]).get("fire", 0))).is_equal(7)  # every Fire card there is
	var physical: Dictionary = presets["physical-rogue"]
	# The deck rules need exactly Hot Head (utility) and one Fire AoE: the fewest possible Fire cards.
	assert_int(int(DebugDecks.pool_counts(physical["starter"]).get("fire", 0))).is_equal(2)
	assert_int(int(DebugDecks.pool_counts(physical["full"]).get("fire", 0))).is_equal(2)


func test_physical_rogue_cannot_have_fewer_fire_cards_and_still_pass_the_rules() -> void:
	# Drop every Fire card that is left in the starter, one at a time: each removal breaks a slot minimum.
	var preset: Dictionary = (DebugDecks.read_dir()["presets"] as Dictionary)["physical-rogue"]
	for fire_card in ["fire_hot_head", "fire_fine_burn_then"]:
		var smaller: Array = (preset["starter"] as Array).duplicate()
		smaller.erase(fire_card)
		assert_array(DeckRules.check_shipped(smaller).problems).is_not_empty()


# ---- Validation ----

func test_invalid_card_id_names_the_card() -> void:
	var data := _good()
	(data["starter"] as Array)[0] = "not_a_card"
	var text := _joined(_problems("mixed-rogue", data))
	assert_str(text).contains("invalid card id 'not_a_card'")


func test_deck_rule_failure_names_the_slot_and_shortfall() -> void:
	var data := _good()
	data["starter"] = (data["starter"] as Array).filter(func(id: Variant) -> bool: return id != "neutral_deep_sigh" and id != "rogue_not_my_problem")
	var text := _joined(_problems("mixed-rogue", data))
	assert_str(text).contains("starter breaks the deck rules")
	assert_str(text).contains("Utility needs 3 unique cards, deck has 1")


func test_starter_not_a_subset_of_full_is_reported() -> void:
	var data := _good()
	data["full"] = (data["full"] as Array).filter(func(id: Variant) -> bool: return id != "rogue_quick_slash")
	var text := _joined(_problems("mixed-rogue", data))
	assert_str(text).contains("starter is not a subset of full: 'rogue_quick_slash'")


func test_copies_count_in_the_subset_check() -> void:
	assert_array(DebugDecks.subset_problems(["a", "a"], ["a", "b"])).is_not_empty()
	assert_array(DebugDecks.subset_problems(["a", "a"], ["a", "a", "b"])).is_empty()


func test_name_must_match_file_and_description_and_lists_must_exist() -> void:
	var data := _good()
	data["name"] = "other"
	assert_str(_joined(_problems("mixed-rogue", data))).contains("'name' must be the file name 'mixed-rogue'")
	data = _good()
	data.erase("description")
	assert_str(_joined(_problems("mixed-rogue", data))).contains("'description'")
	data = _good()
	data.erase("full")
	assert_str(_joined(_problems("mixed-rogue", data))).contains("'full' must be a non-empty array")
	assert_array(_problems("x", "not an object")).is_not_empty()


func test_a_bad_preset_file_in_a_folder_is_reported_and_refuses_that_deck() -> void:
	var dir_path := "user://t_decks_fixture"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var good := _good()
	good["name"] = "good-one"
	var bad := _good()
	bad["name"] = "bad-one"
	(bad["starter"] as Array)[1] = "no_such_card"
	for pair: Array in [["good-one", good], ["bad-one", bad]]:
		var file := FileAccess.open(dir_path.path_join(String(pair[0]) + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(pair[1]))
		file.close()
	var directory := DebugDecks.read_dir(dir_path)
	assert_bool((directory["presets"] as Dictionary).has("good-one")).is_true()
	assert_bool((directory["presets"] as Dictionary).has("bad-one")).is_false()
	var launch := DebugDecks.resolve_launch(PackedStringArray(["--deck=bad-one"]), directory)
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	assert_str(_joined(launch["errors"])).contains("debug deck 'bad-one' is invalid")
	assert_str(_joined(launch["errors"])).contains("no_such_card")
	assert_int(int(DebugDecks.resolve_launch(PackedStringArray(["--deck=good-one"]), directory)["exit"])).is_equal(DebugDecks.EXIT_CONTINUE)
	for file_name in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)


# ---- Launch args ----

func test_unknown_name_refuses_and_lists_the_valid_names() -> void:
	var launch := _resolve(["--deck=nope"])
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	var text := _joined(launch["errors"])
	assert_str(text).contains("unknown debug deck 'nope'")
	for preset_name in SHIPPED:
		assert_str(text).contains(preset_name)


func test_deck_given_twice_is_an_error_even_for_the_same_name() -> void:
	var launch := _resolve(["--deck=mixed-rogue", "--deck=mixed-rogue"])
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	assert_str(_joined(launch["errors"])).contains("2 times")


func test_deck_without_a_name_is_an_error() -> void:
	assert_int(int(_resolve(["--deck="])["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	assert_int(int(_resolve(["--deck"])["exit"])).is_equal(DebugDecks.EXIT_REFUSED)


func test_a_known_deck_continues_and_combines_with_the_other_run_args() -> void:
	var launch := _resolve(["--run-seed=3", "--deck=physical-rogue", "--full-deck", "--run-room=8"])
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_CONTINUE)
	assert_str(String(launch["deck"])).is_equal("physical-rogue")
	assert_array(launch["errors"]).is_empty()


func test_no_deck_arg_changes_nothing() -> void:
	var cases: Array = [[], ["--full-deck"], ["--run-seed=2", "--run-room=8"]]
	for args: Array in cases:
		var typed: Array[String] = []
		typed.assign(args)
		var launch := _resolve(typed)
		assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_CONTINUE)
		assert_str(String(launch["deck"])).is_equal("")
		assert_array(launch["errors"]).is_empty()
		assert_array(launch["lines"]).is_empty()


func test_list_decks_prints_every_name_and_description_and_exits() -> void:
	var launch := _resolve(["--list-decks"])
	assert_int(int(launch["exit"])).is_equal(DebugDecks.EXIT_OK)
	var text := _joined(launch["lines"])
	var presets: Dictionary = DebugDecks.read_dir()["presets"]
	for preset_name in SHIPPED:
		assert_str(text).contains(preset_name + " - " + String((presets[preset_name] as Dictionary)["description"]))


# ---- How a run takes the deck ----

func test_a_new_run_with_no_preset_is_unchanged() -> void:
	assert_array(RunSession.begin_new_run(1).deck).is_equal(RunConfig.starting_deck())
	RunSession.full_deck = true
	var full := RunSession.begin_new_run(1).deck.duplicate()
	full.sort()
	assert_array(full).is_equal(RunConfig.cards_in_pools(RunConfig.character_pools()))


func test_preset_gives_starter_or_full_with_full_deck_and_survives_try_again() -> void:
	var preset: Dictionary = (DebugDecks.read_dir()["presets"] as Dictionary)["fire-heavy-rogue"]
	RunSession.debug_deck = preset
	assert_array(RunSession.begin_new_run(5).deck).is_equal(DebugDecks.deck_of(preset, false))
	assert_array(RunSession.begin_new_run().deck).is_equal(DebugDecks.deck_of(preset, false))  # Try again
	RunSession.full_deck = true
	assert_array(RunSession.begin_new_run(5).deck).is_equal(DebugDecks.deck_of(preset, true))
	assert_array(RunSession.begin_new_run().deck).is_equal(DebugDecks.deck_of(preset, true))


func test_every_preset_deck_loads_into_the_player_slots_and_passes_the_run_start_check() -> void:
	var presets: Dictionary = DebugDecks.read_dir()["presets"]
	for preset_name: String in presets:
		for full in [false, true]:
			var deck := DebugDecks.deck_of(presets[preset_name], full)
			var controller := CardSlotController.new(null, null, "player", StatModifiers.new(), ["rogue", "fire", "neutral"] as Array[String])
			assert_int(controller.set_deck(deck).size()).is_equal(deck.size())
			assert_str(DeckRules.run_start_block_message(controller.deck_check())).is_equal("")
