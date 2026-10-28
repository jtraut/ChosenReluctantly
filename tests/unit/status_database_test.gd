class_name StatusDatabaseTest
extends GdUnitTestSuite
## S4-3: data/statuses.json is validated (including the visual block) and fails loud.

const BAD_FIXTURE := "res://tests/fixtures/statuses_bad/statuses.json"


func _burn() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://data/statuses.json")) as Dictionary)["burn"]


func test_shipped_statuses_validate() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/statuses.json"))
	assert_array(StatusDatabase.validate_table(table)).is_empty()
	assert_bool(StatusDatabase.has_status("burn")).is_true()
	assert_float(float(StatusDatabase.get_status("burn")["visual"]["size"])).is_greater(0.0)


func test_every_bad_fixture_entry_is_rejected_with_its_own_message() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAD_FIXTURE))
	assert_int(table.size()).is_equal(6)
	for status_id: String in table.keys():
		var errors := StatusDatabase.validate_entry(table[status_id])
		assert_array(errors).override_failure_message("'%s' should be invalid" % status_id).is_not_empty()
	var all := StatusDatabase.validate_table(table)
	assert_bool(all.any(func(e: String) -> bool: return e.begins_with("typo_kind:") and e.contains("visual.kind"))).is_true()
	assert_bool(all.any(func(e: String) -> bool: return e.begins_with("string_size:") and e.contains("visual.size"))).is_true()
	assert_bool(all.any(func(e: String) -> bool: return e.begins_with("bad_color:") and e.contains("visual.color"))).is_true()


func test_visual_block_edge_cases() -> void:
	var good := _burn()
	assert_array(StatusDatabase.validate_entry(good)).is_empty()
	var cases: Array[Dictionary] = [
		{"visual": "flame"}, {"visual": {}}, {"visual": {"kind": "flame"}}, {"visual": {"kind": 3, "size": 0.2}},
		{"visual": {"kind": "flame", "size": -1.0}}, {"visual": {"kind": "flame", "size": 99.0}}, {"visual": {"kind": "flame", "size": null}},
		{"damage_per_tick": "2"}, {"damage_type": ""}, {"tick_interval": -1.0}, {"effect_type": 5},
	]
	for patch in cases:
		var entry := good.duplicate(true)
		entry.merge(patch, true)
		assert_array(StatusDatabase.validate_entry(entry)).override_failure_message("should reject %s" % str(patch)).is_not_empty()


func test_missing_visual_is_allowed_and_non_object_entry_is_reported() -> void:
	var entry := _burn()
	entry.erase("visual")
	assert_array(StatusDatabase.validate_entry(entry)).is_empty()
	assert_array(StatusDatabase.validate_table({"x": 5})).is_not_empty()
