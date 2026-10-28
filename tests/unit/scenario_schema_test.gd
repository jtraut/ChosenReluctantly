class_name ScenarioSchemaTest
extends GdUnitTestSuite
## S3B-6 / S4-4: scenario flags in data/scenarios.json are schema-validated and fail loudly.


func test_every_shipped_scenario_is_valid() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scenario.DATA_PATH))
	assert_int(parsed.size()).is_greater(5)
	for scenario_id: String in parsed:
		assert_array(ScenarioSchema.validate(scenario_id, parsed[scenario_id])).override_failure_message("scenario %s" % scenario_id).is_empty()
		assert_bool(Scenario.load_def(scenario_id).is_empty()).is_false()


func test_bad_fixture_file_is_rejected_with_clear_messages() -> void:
	var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/scenarios_bad/scenarios.json"))
	assert_int(bad.size()).is_greater(8)
	for scenario_id: String in bad:
		var problems := ScenarioSchema.validate(scenario_id, bad[scenario_id])
		assert_array(problems).override_failure_message("scenario '%s' should be rejected" % scenario_id).is_not_empty()
		assert_str(problems[0]).contains(scenario_id)


func test_messages_name_the_key_and_the_expected_shape() -> void:
	var one := ScenarioSchema.validate("s", {"aim_point_offset": [1.0]})
	assert_int(one.size()).is_equal(1)
	assert_str(one[0]).contains("aim_point_offset").contains("exactly 2")
	assert_str(ScenarioSchema.validate("s", {"aim_point_ofset": [1.0, 2.0]})[0]).contains("not a known scenario flag")
	assert_str(ScenarioSchema.validate("s", {"columns": 2.5})[0]).contains("whole number")


func test_valid_edge_values_pass() -> void:
	var good := {"aim_point_offset": [0, -6.6], "columns": 3.0, "boss_indices": [0, 8.0], "enemies_idle": true,
			"groups": [{"scene": "res://x.tscn"}], "late_hit": {"at": 1, "indices": []}, "hp_fractions": [0, 1, 0.5]}
	assert_array(ScenarioSchema.validate("s", good)).is_empty()
	assert_array(ScenarioSchema.validate("s", {})).is_empty()
