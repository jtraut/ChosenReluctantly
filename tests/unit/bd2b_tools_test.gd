class_name Bd2bToolsTest
extends GdUnitTestSuite
## BD2-B: the bot's relic policy, the capture scenario keys and presets that name relics, and the sim flag helpers.


func _option(id: String, kind: String, keywords: Array = []) -> Dictionary:
	return {"id": id, "kind": kind, "enabled": true, "keywords": keywords}


# --- RelicPolicy ----------------------------------------------------------------------------------

func test_the_bot_takes_the_first_relic_that_matches_the_deck_else_the_first_offered() -> void:
	var burn_deck: Array[String] = ["fire_ember_whatever", "fire_fine_burn_then", "fire_blaze_and_bail", "rogue_quick_slash"]
	var plain_deck: Array[String] = ["rogue_quick_slash", "rogue_overhand_whatever", "neutral_healing_potion"]
	var options: Array = [_option("relic:a", "relic", ["Zone"]), _option("relic:b", "relic", ["Burn"]), _option("relic:c", "relic", ["Burn"]), _option("relic_skip", "relic_skip")]
	assert_str(RelicPolicy.offer_choice(options, burn_deck)).is_equal("relic:b")  # the first that matches, not the first offered
	assert_str(RelicPolicy.offer_choice(options, plain_deck)).is_equal("relic:a")  # nothing matches: the first
	assert_str(RelicPolicy.offer_choice([_option("relic_skip", "relic_skip")], burn_deck)).is_equal("relic_skip")  # nothing offered
	assert_str(RelicPolicy.offer_choice([], burn_deck)).is_empty()


func test_a_keyword_needs_three_cards_before_it_counts_as_the_decks_plan() -> void:
	var two_burns: Array[String] = ["fire_ember_whatever", "fire_fine_burn_then", "rogue_quick_slash"]
	var counts: Dictionary = RelicPolicy.tag_counts(two_burns)
	assert_int(int(counts.get("Burn", 0))).is_equal(2)
	assert_bool(RelicPolicy.matches(["Burn"], counts)).is_false()
	var three: Array[String] = two_burns + (["fire_blaze_and_bail"] as Array[String])
	assert_bool(RelicPolicy.matches(["Burn"], RelicPolicy.tag_counts(three))).is_true()


func test_at_the_cap_the_bot_gives_up_the_first_giveable_relic() -> void:
	var options: Array = [_option("giveup:x", "giveup"), _option("giveup:y", "giveup"), _option("giveup_cancel", "back")]
	assert_str(RelicPolicy.giveup_choice(options)).is_equal("giveup:x")
	assert_str(RelicPolicy.giveup_choice([_option("giveup_cancel", "back")])).is_equal("giveup_cancel")


func test_the_policy_runs_through_the_real_choice_model_to_a_taken_relic_and_a_swap() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	(ctx["relics"] as Dictionary)["enabled"] = true
	(ctx["relics"] as Dictionary)["max_owned"] = 1
	var state := RunState.new_run(8, CharacterDatabase.starting_deck("rogue"), 3)
	state.room_index = 4
	state.relics = ["pyre_insurance"] as Array[String]
	RunRelics.open_for_room(state, "elite", false, ctx)
	var picked: String = RelicPolicy.offer_choice(RunChoices.options(state, ctx), state.deck)
	assert_bool(bool(RunChoices.apply(state, picked, ctx)["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	var gave: String = RelicPolicy.giveup_choice(RunChoices.options(state, ctx))
	assert_str(gave).is_equal("giveup:pyre_insurance")
	assert_bool(bool(RunChoices.apply(state, gave, ctx)["finished"])).is_true()
	assert_int(state.relics.size()).is_equal(1)
	assert_array(state.relics_given_up).is_equal(["pyre_insurance"])


# --- scenarios and capture presets ----------------------------------------------------------------

func test_a_scenario_may_name_relics_and_an_unknown_one_is_refused() -> void:
	var def: Dictionary = Scenario.load_def("bd2_pyre_explosion")
	assert_array(def.get("relics", [])).is_equal(["pyre_insurance"])
	assert_array(ScenarioSchema.validate("bd2_pyre_explosion", def)).override_failure_message(str(ScenarioSchema.validate("bd2_pyre_explosion", def))).is_empty()
	var bad: Dictionary = def.duplicate(true)
	bad["relics"] = ["no_such_relic"]
	assert_array(ScenarioSchema.validate("x", bad)).is_not_empty()
	bad["relics"] = []
	assert_array(ScenarioSchema.validate("x", bad)).is_not_empty()


func test_every_capture_preset_names_a_real_scenario_and_valid_relic_flags() -> void:
	var file := FileAccess.open("res://tools/capture_presets.json", FileAccess.READ)
	var presets: Dictionary = JSON.parse_string(file.get_as_text())
	for name: String in presets.keys():
		var preset: Dictionary = presets[name]
		var scenario: String = String(preset.get("scenario", ""))
		if scenario != "":
			assert_bool(Scenario.has_scenario(scenario)).override_failure_message("preset %s names scenario %s" % [name, scenario]).is_true()
		for arg: Variant in (preset.get("extra", []) as Array):
			var text: String = String(arg)
			if text.begins_with("--relics="):
				assert_array(RelicArgs.id_problems("--relics", RelicArgs.parse_ids(text.substr(9)), 0)).override_failure_message(name).is_empty()
			elif text.begins_with("--relic-offer="):
				assert_array(RelicArgs.id_problems("--relic-offer", RelicArgs.parse_ids(text.substr(14)), RelicConfig.offer_count())).override_failure_message(name).is_empty()
	for name: String in ["bd2_relic_elite", "bd2_relic_room", "bd2_relic_swap", "bd2_pyre_explosion"]:
		assert_bool(presets.has(name)).is_true()


func test_the_scenario_holds_its_relics_through_a_real_manager() -> void:
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	var scenario: Scenario = Scenario.setup(main, "bd2_pyre_explosion")
	assert_object(scenario).is_not_null()
	var manager := main.get_node_or_null("RelicManager") as RelicManager
	assert_object(manager).is_not_null()
	assert_array(manager.relic_ids()).is_equal(["pyre_insurance"])
	Juice.reset()
