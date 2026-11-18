class_name LoadoutStoreTest
extends GdUnitTestSuite
## 3d sitting B: the profile and the loadout store. Every path is injected under user://tests/, so the real profile and loadouts are never touched.

const PROFILE_PATH := "user://tests/loadout_b_profile.json"
const STORE_PATH := "user://tests/loadout_b_loadouts.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RelicDatabase.load_all()
	_wipe()


func after_test() -> void:
	_wipe()


func _wipe() -> void:
	for base: String in [PROFILE_PATH, STORE_PATH]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(base + suffix)


func _put(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _entry(entry_name: String = "Mine", character_id: String = "rogue") -> Dictionary:
	return LoadoutCheck.make_entry(entry_name, CharacterDatabase.starting_deck(character_id))


func _store_with(raw: Dictionary) -> LoadoutStore:
	_put(STORE_PATH, JSON.stringify(raw))
	return LoadoutStore.new(STORE_PATH)


# ---- profile ----

func test_the_default_paths_are_the_user_folder_files() -> void:
	assert_str(PlayerProfile.DEFAULT_PATH).is_equal("user://profile.json")
	assert_str(LoadoutStore.DEFAULT_PATH).is_equal("user://loadouts.json")
	assert_str(PlayerProfile.new(PROFILE_PATH).path).is_equal(PROFILE_PATH)


func test_a_missing_profile_reads_zero_runs_and_is_run_one() -> void:
	var profile := PlayerProfile.new(PROFILE_PATH)
	profile.load_file()
	assert_int(profile.runs_finished).is_equal(0)
	assert_bool(profile.is_first_run()).is_true()
	assert_str(profile.problem).is_empty()
	assert_bool(FileAccess.file_exists(PROFILE_PATH)).is_false()  # reading never creates the file


func test_a_profile_round_trips_and_counts_each_finished_run() -> void:
	var profile := PlayerProfile.new(PROFILE_PATH)
	assert_bool(profile.record_run_finished()).is_true()
	assert_bool(profile.record_run_finished()).is_true()
	var again := PlayerProfile.new(PROFILE_PATH)
	again.load_file()
	assert_int(again.runs_finished).is_equal(2)
	assert_bool(again.is_first_run()).is_false()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	assert_int(int((parsed as Dictionary)["version"])).is_equal(1)


func test_a_bad_profile_reads_zero_flags_a_problem_and_is_kept_as_a_backup_on_write() -> void:
	for text: String in ["not json", "[1,2]", "{\"version\": 1}", "{\"version\": 1, \"runs_finished\": -2}", "{\"version\": 1, \"runs_finished\": 1.5}",
			"{\"version\": 2, \"runs_finished\": 4}", "{\"version\": 1, \"runs_finished\": 4, \"extra\": 1}", "{\"version\": \"1\", \"runs_finished\": 4}"]:
		_put(PROFILE_PATH, text)
		var profile := PlayerProfile.new(PROFILE_PATH)
		profile.load_file()
		assert_int(profile.runs_finished).override_failure_message(text).is_equal(0)
		assert_str(profile.problem).override_failure_message(text).is_not_empty()
	_put(PROFILE_PATH, "garbage")
	var broken := PlayerProfile.new(PROFILE_PATH)
	broken.load_file()
	assert_bool(broken.record_run_finished()).is_true()
	assert_str(FileAccess.get_file_as_string(PROFILE_PATH + ".bak")).is_equal("garbage")
	assert_str(broken.problem).is_empty()


func test_a_float_count_from_json_is_a_whole_number_so_an_existing_file_loads() -> void:
	_put(PROFILE_PATH, "{\"version\": 1, \"runs_finished\": 3}")
	var profile := PlayerProfile.new(PROFILE_PATH)
	profile.load_file()
	assert_int(profile.runs_finished).is_equal(3)
	assert_str(profile.problem).is_empty()


func test_a_faked_run_count_writes_nothing() -> void:
	var profile := PlayerProfile.new(PROFILE_PATH)
	profile.fake_runs_finished(5)
	assert_int(profile.runs_finished).is_equal(5)
	assert_bool(profile.record_run_finished()).is_false()
	assert_bool(FileAccess.file_exists(PROFILE_PATH)).is_false()


# ---- store ----

func test_a_missing_store_is_empty_with_the_preset_selected() -> void:
	var store := LoadoutStore.new(STORE_PATH)
	assert_array(store.flagged()).is_empty()
	assert_int(store.slot_count()).is_equal(5)
	assert_array(store.usable_indices("rogue")).is_empty()
	assert_array(store.free_indices("rogue")).is_equal([0, 1, 2, 3, 4])
	assert_int(store.last_used("rogue")).is_equal(LoadoutStore.PRESET)
	assert_bool(FileAccess.file_exists(STORE_PATH)).is_false()


func test_a_saved_loadout_round_trips_with_name_deck_plan_relic_and_last_used() -> void:
	var store := LoadoutStore.new(STORE_PATH)
	var plan: Array[String] = LoadoutCollection.plan_cards("rogue").slice(0, 2)
	var entry: Dictionary = LoadoutCheck.make_entry("Water Rogue", CharacterDatabase.starting_deck("rogue"), plan, "chasing_paper")
	assert_array(store.save_entry("rogue", 2, entry)).is_empty()
	assert_bool(store.set_last_used("rogue", 2)).is_true()
	var again := LoadoutStore.new(STORE_PATH)
	assert_array(again.flagged()).is_empty()
	assert_array(again.usable_indices("rogue")).is_equal([2])
	assert_int(again.last_used("rogue")).is_equal(2)
	var loaded: Dictionary = again.entry("rogue", 2)
	assert_str(String(loaded["name"])).is_equal("Water Rogue")
	assert_array(loaded["deck"]).is_equal(CharacterDatabase.starting_deck("rogue"))
	assert_array(loaded["plan"]).is_equal(plan)
	assert_str(String(loaded["starter_relic"])).is_equal("chasing_paper")
	assert_int(int((loaded["passive_allocation"] as Dictionary)["version"])).is_equal(1)
	assert_array(again.free_indices("rogue")).is_equal([0, 1, 3, 4])


func test_a_wizard_loadout_does_not_appear_under_the_rogue() -> void:
	var store := LoadoutStore.new(STORE_PATH)
	assert_array(store.save_entry("wizard", 0, _entry("Zap", "wizard"))).is_empty()
	assert_array(LoadoutStore.new(STORE_PATH).usable_indices("rogue")).is_empty()
	assert_array(LoadoutStore.new(STORE_PATH).usable_indices("wizard")).is_equal([0])
	assert_array(store.save_entry("rogue", 0, _entry("Zap", "wizard"))).is_not_empty()  # a wizard deck is not a legal rogue deck


func test_saving_refuses_a_rule_breaking_entry_and_changes_nothing() -> void:
	var store := LoadoutStore.new(STORE_PATH)
	var broken: Dictionary = _entry()
	(broken["deck"] as Array).pop_back()
	assert_array(store.save_entry("rogue", 0, broken)).is_not_empty()
	assert_array(store.usable_indices("rogue")).is_empty()
	assert_bool(FileAccess.file_exists(STORE_PATH)).is_false()
	assert_array(store.save_entry("rogue", 5, _entry())).is_not_empty()  # out of range
	assert_array(store.save_entry("rogue", -1, _entry())).is_not_empty()
	assert_array(store.save_entry("nobody", 0, _entry())).is_not_empty()


func test_delete_empties_a_slot_and_resets_last_used() -> void:
	var store := LoadoutStore.new(STORE_PATH)
	store.save_entry("rogue", 1, _entry())
	store.set_last_used("rogue", 1)
	assert_bool(store.delete_entry("rogue", 1)).is_true()
	var again := LoadoutStore.new(STORE_PATH)
	assert_array(again.usable_indices("rogue")).is_empty()
	assert_int(again.last_used("rogue")).is_equal(LoadoutStore.PRESET)
	assert_bool(store.set_last_used("rogue", 1)).is_false()  # an empty slot cannot be the last used


func test_a_corrupt_file_is_flagged_and_never_crashes() -> void:
	for text: String in ["not json at all", "[1]", "{}", "{\"version\": 9, \"classes\": {}}", "{\"version\": 1}", "{\"version\": 1, \"classes\": []}"]:
		_put(STORE_PATH, text)
		var store := LoadoutStore.new(STORE_PATH)
		assert_array(store.flagged()).override_failure_message(text).is_not_empty()
		assert_array(store.usable_indices("rogue")).is_empty()
		assert_int(store.last_used("rogue")).is_equal(LoadoutStore.PRESET)


func test_a_file_that_could_not_be_read_is_kept_as_a_backup_before_the_first_write() -> void:
	_put(STORE_PATH, "{\"version\": 9, \"classes\": {}}")
	var store := LoadoutStore.new(STORE_PATH)
	assert_str(store.file_problem).is_not_empty()
	assert_array(store.save_entry("rogue", 0, _entry())).is_empty()
	assert_str(FileAccess.get_file_as_string(STORE_PATH + ".bak")).is_equal("{\"version\": 9, \"classes\": {}}")
	assert_str(store.file_problem).is_empty()
	assert_array(LoadoutStore.new(STORE_PATH).usable_indices("rogue")).is_equal([0])


func test_a_bad_entry_is_flagged_and_skipped_and_the_good_ones_still_load() -> void:
	var good: Dictionary = _entry("Good")
	var short: Dictionary = _entry("Short")
	(short["deck"] as Array).pop_back()
	var curse: Dictionary = _entry("Cursed")
	(curse["deck"] as Array)[0] = "curse_property_damage"
	var non_starter: Dictionary = _entry("Greedy")
	(non_starter["deck"] as Array)[0] = LoadoutCollection.plan_cards("rogue")[0]
	var bad_relic: Dictionary = LoadoutCheck.make_entry("Relicky", CharacterDatabase.starting_deck("rogue"), [], "ergonomic_chair")
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": 0, "slots": [good, short, curse, non_starter, bad_relic]}}})
	assert_array(store.usable_indices("rogue")).is_equal([0])
	assert_int(store.flagged().size()).is_equal(4)
	for i in [1, 2, 3, 4]:
		assert_bool(store.is_flagged("rogue", i)).is_true()
		assert_str(store.flag_message("rogue", i)).is_not_empty()
		assert_dict(store.entry("rogue", i)).is_empty()
	assert_bool(" ".join(store.flagged()).contains("rogue slot 2 'Short' skipped")).is_true()
	assert_array(store.free_indices("rogue")).is_empty()  # a flagged slot still holds its bad entry
	assert_int(store.last_used("rogue")).is_equal(0)


func test_a_curse_in_the_plan_and_a_non_object_entry_are_flagged() -> void:
	var curse_plan: Dictionary = LoadoutCheck.make_entry("P", CharacterDatabase.starting_deck("rogue"), ["curse_property_damage"])
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": -1, "slots": [curse_plan, "text", 7, null, {}]}}})
	assert_array(store.usable_indices("rogue")).is_empty()
	assert_int(store.flagged().size()).is_equal(4)
	assert_array(store.free_indices("rogue")).is_equal([3])


func test_an_outdated_entry_missing_a_key_is_flagged() -> void:
	var old: Dictionary = _entry("Old")
	old.erase("passive_allocation")
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": -1, "slots": [old]}}})
	assert_bool(store.is_flagged("rogue", 0)).is_true()


func test_a_flagged_slot_survives_a_write_until_it_is_overwritten() -> void:
	var short: Dictionary = _entry("Short")
	(short["deck"] as Array).pop_back()
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": -1, "slots": [short]}}})
	assert_array(store.save_entry("rogue", 1, _entry("Fine"))).is_empty()
	var again := LoadoutStore.new(STORE_PATH)
	assert_bool(again.is_flagged("rogue", 0)).is_true()  # still there, still flagged
	assert_array(again.usable_indices("rogue")).is_equal([1])
	assert_array(again.save_entry("rogue", 0, _entry("Fixed"))).is_empty()
	assert_bool(LoadoutStore.new(STORE_PATH).is_flagged("rogue", 0)).is_false()


func test_a_stale_or_bad_last_used_falls_back_to_the_preset() -> void:
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": 3, "slots": [_entry()]}, "wizard": {"last_used": "two", "slots": []}}})
	assert_int(store.last_used("rogue")).is_equal(LoadoutStore.PRESET)  # slot 3 is empty
	assert_int(store.last_used("wizard")).is_equal(LoadoutStore.PRESET)
	assert_bool(" ".join(store.flagged()).contains("last_used")).is_true()


func test_unknown_classes_and_slots_past_the_limit_are_flagged_and_kept() -> void:
	var raw_slots: Array = []
	for i in range(6):
		raw_slots.append(_entry("L%d" % i))
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": -1, "slots": raw_slots}, "druid": {"last_used": -1, "slots": []}}})
	assert_array(store.usable_indices("rogue")).is_equal([0, 1, 2, 3, 4])
	assert_bool(" ".join(store.flagged()).contains("druid")).is_true()
	assert_bool(store.is_flagged("rogue", 5)).is_true()
	store.write()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORE_PATH))
	assert_bool((parsed["classes"] as Dictionary).has("druid")).is_true()
	assert_int(((parsed["classes"] as Dictionary)["rogue"]["slots"] as Array).size()).is_equal(6)


func test_a_json_float_passive_version_is_normalised_to_an_int() -> void:
	var store := _store_with({"version": 1, "classes": {"rogue": {"last_used": 0.0, "slots": [_entry("F")]}}})
	assert_array(store.usable_indices("rogue")).is_equal([0])
	assert_int(store.last_used("rogue")).is_equal(0)
	assert_int(typeof((store.entry("rogue", 0)["passive_allocation"] as Dictionary)["version"])).is_equal(TYPE_INT)


func test_the_real_user_files_are_never_touched_by_these_tests() -> void:
	var before_profile: bool = FileAccess.file_exists(PlayerProfile.DEFAULT_PATH)
	var before_store: bool = FileAccess.file_exists(LoadoutStore.DEFAULT_PATH)
	var profile := PlayerProfile.new(PROFILE_PATH)
	profile.record_run_finished()
	LoadoutStore.new(STORE_PATH).save_entry("rogue", 0, _entry())
	assert_bool(FileAccess.file_exists(PlayerProfile.DEFAULT_PATH)).is_equal(before_profile)
	assert_bool(FileAccess.file_exists(LoadoutStore.DEFAULT_PATH)).is_equal(before_store)
