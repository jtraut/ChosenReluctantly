class_name Bd3bHousekeepingTest
extends GdUnitTestSuite
## BD3b sitting A, engine 1 housekeeping: the preset row title is data (N2), and the stun relics say the stun is halved on elites.


func test_the_preset_row_title_comes_from_run_json() -> void:
	var texts: Dictionary = RunConfig.ui().get("start_screen", {})
	assert_str(String(texts.get("preset_title", ""))).is_equal("Preset deck")
	var choices: Dictionary = LoadoutChoices.start_choices("rogue")
	assert_str(String((choices["preset"] as Dictionary)["name"])).is_equal(String(texts["preset_title"]))


func test_every_relic_that_stuns_says_halved_on_elites() -> void:
	var stunners: int = 0
	for relic_id: Variant in RelicDatabase.ids():
		var relic: Dictionary = RelicDatabase.get_relic(String(relic_id))
		var stuns: bool = JSON.stringify(relic.get("triggers", [])).contains("\"stun\"")
		if stuns:
			stunners += 1
			assert_str(String(relic["rule_text"])).override_failure_message("%s stuns but its rule_text does not say it is halved on elites" % relic_id).contains("halved on elites")
	assert_int(stunners).is_greater_equal(2)
