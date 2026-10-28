class_name SettingsStoreTest
extends GdUnitTestSuite
## Slice 6a: the settings store. Every test uses its own temp path under user://tests/,
## never the real user://settings.cfg.

const TEST_DIR := "user://tests"
const DEFAULTS := "res://data/settings.json"

var _paths: Array[String] = []


func _temp_path() -> String:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var path := "%s/settings_%d_%d.cfg" % [TEST_DIR, Time.get_ticks_usec(), _paths.size()]
	_paths.append(path)
	return path


func after_test() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_paths.clear()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_defaults_file_is_valid_and_release_is_the_default() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS))
	assert_array(SettingsStore.validate_definitions(raw)).is_empty()
	var store := SettingsStore.new(DEFAULTS, _temp_path())
	assert_array(store.problems).is_empty()
	assert_str(store.get_string("cast_trigger")).is_equal("release")
	assert_array(store.keys()).contains(["cast_trigger"])
	assert_array(store.get_definition("cast_trigger")["options"]).is_equal(["release", "press"])


func test_set_value_validates_and_emits_changed_once() -> void:
	var store := SettingsStore.new(DEFAULTS, _temp_path())
	var seen: Array = []
	store.changed.connect(func(key: String, value: Variant) -> void: seen.append([key, value]))
	assert_bool(store.set_value("cast_trigger", "press")).is_true()
	assert_bool(store.set_value("cast_trigger", "press")).is_true()  # no change: no second signal
	assert_array(seen).is_equal([["cast_trigger", "press"]])
	assert_bool(store.set_value("cast_trigger", "hover")).is_false()
	assert_bool(store.set_value("cast_trigger", 3)).is_false()
	assert_bool(store.set_value("no_such_key", "x")).is_false()
	assert_str(store.get_string("cast_trigger")).is_equal("press")
	assert_array(seen).has_size(1)


func test_value_persists_through_save_and_load() -> void:
	var path := _temp_path()
	var store := SettingsStore.new(DEFAULTS, path)
	store.set_value("cast_trigger", "press")
	assert_bool(FileAccess.file_exists(path)).is_false()  # set_value never saves
	assert_bool(store.save()).is_true()
	var reloaded := SettingsStore.new(DEFAULTS, path)
	assert_array(reloaded.problems).is_empty()
	assert_str(reloaded.get_string("cast_trigger")).is_equal("press")


func test_missing_user_file_is_just_the_defaults() -> void:
	var store := SettingsStore.new(DEFAULTS, _temp_path())
	assert_array(store.problems).is_empty()
	assert_str(store.get_string("cast_trigger")).is_equal("release")


func test_bad_value_in_user_file_falls_back_and_reports() -> void:
	var path := _temp_path()
	_write(path, "[settings]\ncast_trigger=\"sometimes\"\n")
	var store := SettingsStore.new(DEFAULTS, path)
	assert_str(store.get_string("cast_trigger")).is_equal("release")
	assert_array(store.problems).has_size(1)
	assert_str(store.problems[0]).contains("sometimes")


func test_wrong_type_in_user_file_falls_back_and_reports() -> void:
	var path := _temp_path()
	_write(path, "[settings]\ncast_trigger=7\n")
	var store := SettingsStore.new(DEFAULTS, path)
	assert_str(store.get_string("cast_trigger")).is_equal("release")
	assert_array(store.problems).has_size(1)


func test_garbage_user_file_falls_back_and_reports() -> void:
	var path := _temp_path()
	_write(path, "this is not a config file\n{{{\n")
	var store := SettingsStore.new(DEFAULTS, path)
	assert_str(store.get_string("cast_trigger")).is_equal("release")
	assert_array(store.problems).has_size(1)
	assert_str(store.problems[0]).contains("unreadable")


func test_unknown_key_in_user_file_is_reported_and_ignored() -> void:
	var path := _temp_path()
	_write(path, "[settings]\nmystery=true\ncast_trigger=\"press\"\n")
	var store := SettingsStore.new(DEFAULTS, path)
	assert_str(store.get_string("cast_trigger")).is_equal("press")
	assert_array(store.problems).has_size(1)
	assert_str(store.problems[0]).contains("mystery")


func test_bad_definitions_are_caught() -> void:
	assert_array(SettingsStore.validate_definitions({"a": 5})).is_not_empty()
	assert_array(SettingsStore.validate_definitions({"a": {"type": "wat", "default": 1}})).is_not_empty()
	assert_array(SettingsStore.validate_definitions({"a": {"type": "enum", "default": "x", "options": ["y"]}})).is_not_empty()
	assert_array(SettingsStore.validate_definitions({"a": {"type": "enum", "default": "y", "options": []}})).is_not_empty()
	assert_array(SettingsStore.validate_definitions({"a": {"type": "bool", "default": "no"}})).is_not_empty()
	assert_array(SettingsStore.validate_definitions({"a": {"type": "bool", "default": false}})).is_empty()


func test_missing_defaults_file_reports_and_has_no_keys() -> void:
	var store := SettingsStore.new("res://data/nope_settings.json", _temp_path())
	assert_array(store.problems).is_not_empty()
	assert_array(store.keys()).is_empty()


func test_reset_to_defaults_emits_for_moved_keys_only() -> void:
	var store := SettingsStore.new(DEFAULTS, _temp_path())
	store.set_value("cast_trigger", "press")
	var seen: Array = []
	store.changed.connect(func(key: String, value: Variant) -> void: seen.append([key, value]))
	store.reset_to_defaults()
	assert_array(seen).is_equal([["cast_trigger", "release"]])
	assert_str(store.get_string("cast_trigger")).is_equal("release")


func test_autoload_forwards_changed_and_injection_is_hermetic() -> void:
	var original: SettingsStore = Settings.store
	var injected := SettingsStore.new(DEFAULTS, _temp_path())
	Settings.use_store(injected)
	var seen: Array = []
	Settings.changed.connect(func(key: String, value: Variant) -> void: seen.append([key, value]))
	assert_str(Settings.cast_trigger()).is_equal("release")
	assert_bool(Settings.casts_on_release()).is_true()
	assert_bool(Settings.set_value("cast_trigger", "press")).is_true()
	assert_bool(Settings.casts_on_release()).is_false()
	assert_array(seen).is_equal([["cast_trigger", "press"]])
	Settings.use_store(original)
	assert_bool(Settings.store == original).is_true()
