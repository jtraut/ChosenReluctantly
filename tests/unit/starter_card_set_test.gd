class_name StarterCardSetTest
extends GdUnitTestSuite
## Enumerates every real card in data/cards/ directly (not through
## CardDatabase, to avoid its push_error path) and validates each with
## CardSchema - the "every JSON card must load and validate" requirement.
## Malformed-data behavior itself is covered by card_schema_test.gd.

const CARDS_DIR := "res://data/cards"


func _all_card_file_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			paths.append(CARDS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return paths


func test_at_least_twelve_starter_cards_exist() -> void:
	assert_int(_all_card_file_paths().size()).is_greater_equal(12)


func test_every_real_card_file_loads_and_validates() -> void:
	var paths := _all_card_file_paths()
	assert_array(paths).is_not_empty()
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		assert_bool(file != null).override_failure_message("could not open %s" % path).is_true()
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		assert_bool(typeof(parsed) == TYPE_DICTIONARY).override_failure_message("%s is not a JSON object" % path).is_true()
		var card_data: Dictionary = parsed
		var errors := CardSchema.validate(card_data)
		assert_array(errors).override_failure_message("%s failed validation: %s" % [path, errors]).is_empty()


func test_no_duplicate_card_ids() -> void:
	var seen_ids: Array[String] = []
	for path: String in _all_card_file_paths():
		var file := FileAccess.open(path, FileAccess.READ)
		var card_data: Dictionary = JSON.parse_string(file.get_as_text())
		var card_id: String = card_data.get("id", "")
		assert_array(seen_ids).override_failure_message("duplicate card id '%s'" % card_id).not_contains(card_id)
		seen_ids.append(card_id)


func test_at_least_one_card_has_a_negative_cooldown_modifier() -> void:
	var found_fast_card := false
	for path: String in _all_card_file_paths():
		var file := FileAccess.open(path, FileAccess.READ)
		var card_data: Dictionary = JSON.parse_string(file.get_as_text())
		if float(card_data.get("cooldown_modifier", 0.0)) < 0.0:
			found_fast_card = true
			break
	assert_bool(found_fast_card).is_true()


func test_every_slot_type_has_at_least_one_card() -> void:
	CardDatabase.load_all(CARDS_DIR)
	for slot_type: String in SlotTypeDatabase.known_ids():
		assert_array(CardDatabase.cards_for_slot_type(slot_type)).override_failure_message("no cards for slot_type '%s'" % slot_type).is_not_empty()
