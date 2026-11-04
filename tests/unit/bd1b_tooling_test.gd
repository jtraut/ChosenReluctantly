class_name Bd1bToolingTest
extends GdUnitTestSuite
## BD1-B tooling and PL3 carry-overs: the scenario `--class` rules, the scenario `deck` field, the BD1 capture scenarios and
## capture presets, the forced reward offer, and the -StartRoom note. Pure checks where possible.


func after_test() -> void:
	RunSession.forced_offer = []
	RunSession.clear()


func test_a_bogus_class_with_a_scenario_is_one_clear_problem_and_a_good_class_is_none() -> void:
	var bogus: String = Scenario.class_problem(PackedStringArray(["--scenario=hp_bars", "--class=bogus"]))
	assert_str(bogus).contains("unknown class 'bogus'")
	assert_str(bogus).contains("rogue")
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=hp_bars", "--class=wizard"]))).is_empty()
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=hp_bars"]))).is_empty()
	assert_str(Scenario.class_problem(PackedStringArray(["--class=bogus"]))).is_empty()  # no scenario: the run path owns it
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=hp_bars", "--class"]))).contains("needs a name")
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=hp_bars", "--class=rogue", "--class=wizard"]))).contains("2 times")
	# class_arg itself no longer logs: a bad value is Main's one refusal, not an engine error twice.
	assert_str(Scenario.class_arg(PackedStringArray(["--scenario=hp_bars", "--class=bogus"]))).is_empty()


func test_a_scenario_with_its_own_character_refuses_a_different_class() -> void:
	# pl3_ward sets "character": "wizard". The rule: never a mixed player; a --class that disagrees is refused like --deck vs --class.
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=pl3_ward", "--class=rogue"]))).contains("must agree")
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=pl3_ward", "--class=wizard"]))).is_empty()
	assert_str(Scenario.class_problem(PackedStringArray(["--scenario=pl3_ward"]))).is_empty()


func test_every_scenario_validates_and_the_deck_field_is_checked() -> void:
	var file := FileAccess.open(Scenario.DATA_PATH, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	for id: String in parsed:
		assert_array(ScenarioSchema.validate(id, parsed[id])).override_failure_message("scenario " + id).is_empty()
	assert_array(ScenarioSchema.validate("t", {"deck": ["rogue_quick_slash", "no_such_card"]})).is_not_empty()
	assert_array(ScenarioSchema.validate("t", {"deck": "rogue_quick_slash"})).is_not_empty()
	assert_array(ScenarioSchema.validate("t", {"deck": ["rogue_quick_slash"]})).is_empty()


func test_the_pl3_scenarios_hold_the_card_they_cast_and_the_bd1_ones_exist() -> void:
	for id: String in ["pl3_ward", "pl3_bolts", "pl3_heavy_bolt"]:
		var def: Dictionary = Scenario.raw_def(id)
		var deck: Array = def["deck"]
		for cast: Dictionary in def["casts"]:
			assert_bool(deck.has(cast["card"])).override_failure_message("%s: the deck lacks %s" % [id, cast["card"]]).is_true()
	assert_bool((Scenario.raw_def("pl3_heavy_bolt")["deck"] as Array).has("wizard_overqualified_bolt")).is_true()
	assert_bool((Scenario.raw_def("bd1_glow_target")["deck"] as Array).has("fire_fan_the_flames")).is_true()
	assert_array(Scenario.raw_def("bd1_primed")["casts"]).is_not_empty()
	assert_bool(Scenario.has_scenario("bd1_primed")).is_true()


func test_the_capture_presets_file_is_valid() -> void:
	var file := FileAccess.open("res://tools/capture_presets.json", FileAccess.READ)
	var presets: Dictionary = JSON.parse_string(file.get_as_text())
	for required: String in ["reward_screen", "removal_screen", "boss_smash", "bd1_reward_keystone", "bd1_glow_target", "bd1_primed"]:
		assert_bool(presets.has(required)).override_failure_message(required).is_true()
	for id: String in presets:
		var entry: Dictionary = presets[id]
		var scenario: String = String(entry.get("scenario", ""))
		assert_bool(scenario == "" or Scenario.has_scenario(scenario)).override_failure_message("%s names an unknown scenario" % id).is_true()
		assert_bool(String(entry.get("class", "")) == "" or CharacterDatabase.has(String(entry["class"]))).is_true()
		assert_str(String(entry.get("description", ""))).is_not_empty()
		for part: String in String(entry.get("after", "")).split(",", false):
			assert_bool(part.is_valid_float()).is_true()
		var boss_attack: String = String(entry.get("at_boss_attack", ""))
		assert_bool(boss_attack == "" or CaptureArgs.known_boss_attacks().has(boss_attack)).override_failure_message(id + " boss attack").is_true()
		# A scenario preset and its class must agree (the launch would be refused otherwise).
		if scenario != "" and String(entry.get("class", "")) != "":
			assert_str(Scenario.class_problem(PackedStringArray(["--scenario=" + scenario, "--class=" + String(entry["class"])]))).override_failure_message(id).is_empty()
		for extra: String in (entry.get("extra", []) as Array):
			if extra.begins_with("--run-offer="):
				var ids: Array[String] = []
				for card_id: String in extra.substr(12).split("+", false):
					ids.append(card_id)
				assert_array(RunChoices.forced_offer_problems(ids, RunConfig.offer_size())).override_failure_message(id).is_empty()


func test_forced_offer_is_validated_and_used_once_by_the_first_reward() -> void:
	assert_array(RunChoices.forced_offer_problems(["fire_fan_the_flames", "rogue_drive_by"] as Array[String], 3)).is_empty()
	assert_array(RunChoices.forced_offer_problems([] as Array[String], 3)).is_not_empty()
	assert_array(RunChoices.forced_offer_problems(["a", "b", "c", "d"] as Array[String], 3)).is_not_empty()
	assert_array(RunChoices.forced_offer_problems(["nope"] as Array[String], 3)).is_not_empty()
	assert_array(RunChoices.forced_offer_problems(["rogue_drive_by", "rogue_drive_by"] as Array[String], 3)).is_not_empty()
	var ctx: Dictionary = RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state: RunState = RunSession.begin_new_run(3, "rogue")
	RunSession.forced_offer = ["fire_fan_the_flames", "rogue_drive_by", "fire_kindling"] as Array[String]
	RunChoices.open_for_room(state, "combat", false, ctx)
	assert_array(state.offer).is_equal(["fire_fan_the_flames", "rogue_drive_by", "fire_kindling"])
	assert_array(RunSession.forced_offer).is_empty()  # consumed
	RunChoices.open_for_room(state, "combat", false, ctx)
	assert_array(state.offer).is_not_equal(["fire_fan_the_flames", "rogue_drive_by", "fire_kindling"])  # the next offer is the seeded draw again


func test_a_keystone_reward_option_carries_the_condition_text_and_the_keyword() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var option: Dictionary = RunChoices.card_option("o", "card", "rogue_drive_by", ctx)
	assert_str(String(option["detail"])).contains("If you used your Movement slot in the last 2 s")
	assert_bool(CardDatabase.has_tag("rogue_drive_by", "Keystone")).is_true()  # ux shows the chip from this
