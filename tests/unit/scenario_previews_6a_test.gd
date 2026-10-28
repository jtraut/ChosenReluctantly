class_name ScenarioPreviews6aTest
extends GdUnitTestSuite
## Slice 6a: the "previews" scenario flag (held keys for captures) validates like the others.


func test_good_previews_are_valid() -> void:
	var def := {"previews": [
		{"at": 0.5, "slot": "attack_single", "card": "fire_ember_whatever", "release_at": 1.5},
		{"at": 2.0, "slot": "attack_aoe", "card": "fire_fine_burn_then"}]}
	assert_array(ScenarioSchema.validate("x", def)).is_empty()


func test_bad_previews_are_rejected() -> void:
	for bad: Variant in [
			7,
			[5],
			[{"slot": "attack_single", "card": "c"}],
			[{"at": -1, "slot": "attack_single", "card": "c"}],
			[{"at": 1, "card": "c"}],
			[{"at": 1, "slot": "attack_single", "card": ""}],
			[{"at": 2, "slot": "attack_single", "card": "c", "release_at": 1}],
			[{"at": 1, "slot": "attack_single", "card": "c", "release_at": "soon"}]]:
		assert_array(ScenarioSchema.validate("x", {"previews": bad})).override_failure_message("should reject %s" % str(bad)).is_not_empty()


func test_the_cast_preview_scenario_ships_and_is_valid() -> void:
	assert_bool(Scenario.has_scenario("cast_preview")).is_true()
	var def := Scenario.load_def("cast_preview")
	assert_bool(def.is_empty()).is_false()
	assert_bool(def.has("previews")).is_true()
