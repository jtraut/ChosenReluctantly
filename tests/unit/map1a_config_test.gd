class_name Map1aConfigTest
extends GdUnitTestSuite
## MAP1-A item 1 and 6: the data/map.json validator (pass and fail cases), the shipped file, and the run.json swap_line_one check.


func _good() -> Dictionary:
	return MapConfig.get_config().duplicate(true)


func _problems(config: Variant) -> Array[String]:
	return MapConfig.validate(config)


func _has(problems: Array[String], fragment: String) -> bool:
	for problem: String in problems:
		if problem.contains(fragment):
			return true
	return false


func test_shipped_file_is_valid_and_ships_switched_on() -> void:
	MapConfig.reset_cache()
	assert_bool(MapConfig.is_valid()).is_true()
	assert_array(MapConfig.load_problems()).is_empty()
	assert_bool(MapConfig.enabled()).is_true()  # MAP1 ux turned the map on
	var config: Dictionary = MapConfig.get_config()
	var merchant_on: bool = MerchantSwitch.shipped_is_on()  # MAP2-B: the merchant ships off until ux flips it; either state is valid
	assert_array((config["path_rules"] as Dictionary)["relic_route"]).contains_exactly([6.0, 8.0] if merchant_on else [5.0, 7.0])
	assert_float(float(config["types"]["merchant"]["weight"])).is_equal(8.0 if merchant_on else 0.0)
	assert_array(config["types"]["relic_room"]["rooms"]).contains_exactly([3.0, 8.0])


func test_validate_passes_the_shipped_data() -> void:
	assert_array(_problems(_good())).is_empty()


func test_not_an_object_is_rejected() -> void:
	assert_bool(_has(_problems([1, 2]), "must be an object")).is_true()


func test_unknown_keys_are_rejected_at_every_level() -> void:
	for level: String in ["top", "type", "rules", "estimate", "gold"]:
		var config := _good()
		match level:
			"top": config["bogus"] = 1
			"type": (config["types"]["elite"] as Dictionary)["bogus"] = 1
			"rules": (config["path_rules"] as Dictionary)["bogus"] = 1
			"estimate": (config["estimate"] as Dictionary)["bogus"] = 1
			"gold": (config["estimate"]["gold_mean"] as Dictionary)["bogus"] = 1
		assert_bool(_has(_problems(config), "bogus")).override_failure_message("no problem for an unknown key at level %s" % level).is_true()


func test_missing_keys_are_reported() -> void:
	for key: String in MapConfig.TOP_KEYS:
		var config := _good()
		config.erase(key)
		assert_array(_problems(config)).override_failure_message("missing %s not reported" % key).is_not_empty()


func test_unknown_type_is_rejected() -> void:
	var config := _good()
	config["types"]["wizard_tower"] = {"weight": 1, "rooms": [3, 4]}
	assert_bool(_has(_problems(config), "unknown node type 'wizard_tower'")).is_true()
	config = _good()
	config["types"]["boss"] = {"weight": 1, "rooms": [3, 4]}
	assert_bool(_has(_problems(config), "unknown node type 'boss'")).is_true()


func test_windows_must_sit_inside_the_rooms() -> void:
	for window: Array in [[0, 5], [3, 11], [6, 4], [3], [3, 4, 5], ["a", 4], [2.5, 4]]:
		var config := _good()
		config["types"]["elite"]["rooms"] = window
		assert_array(_problems(config)).override_failure_message("window %s accepted" % str(window)).is_not_empty()
	var ok := _good()
	ok["types"]["elite"]["rooms"] = [1, 10]
	assert_array(_problems(ok)).is_empty()


func test_weights_must_be_zero_or_more() -> void:
	for weight: Variant in [-1, "heavy", null, 1001, INF]:
		var config := _good()
		config["types"]["rest"]["weight"] = weight
		assert_bool(_has(_problems(config), "weight")).override_failure_message("weight %s accepted" % str(weight)).is_true()
	var zero := _good()
	zero["types"]["rest"]["weight"] = 0
	assert_array(_problems(zero)).is_empty()


func test_all_weights_zero_is_rejected() -> void:
	var config := _good()
	for entry: Variant in (config["types"] as Dictionary).values():
		(entry as Dictionary)["weight"] = 0
	assert_bool(_has(_problems(config), "every weight is 0")).is_true()


func test_path_rules_are_range_checked() -> void:
	var bad: Dictionary = {
		"min_fights": [-1, 11, 2.5, "six"], "max_elite_like": [-1, 11], "max_merchants": [-2], "min_rest": [-1, 11, 1.5], "max_rest": [11],
		"ignore_route_max": [-1, 100], "min_branching": [-0.1, 1.5, "most"],
		"relic_route": [[7, 5], [-1, 5], [1], [1, 2, 3], [0, 100], ["a", "b"]],
	}
	for key: String in bad:
		for value: Variant in (bad[key] as Array):
			var config := _good()
			config["path_rules"][key] = value
			assert_bool(_has(_problems(config), key)).override_failure_message("%s = %s accepted" % [key, str(value)]).is_true()


func test_rooms_columns_walks_and_attempts_are_range_checked() -> void:
	for case: Array in [["rooms", 2], ["rooms", 17], ["rooms", 10.5], ["columns", 1], ["columns", 9], ["walks", 1], ["walks", 17], ["max_attempts", 0], ["max_attempts", "many"], ["enabled", "yes"]]:
		var config := _good()
		config[case[0]] = case[1]
		assert_bool(_has(_problems(config), "map.%s" % case[0])).override_failure_message("%s = %s accepted" % [case[0], str(case[1])]).is_true()


func test_fixed_entries_are_checked() -> void:
	for room: String in ["0", "11", "x", "1.5", "01"]:
		var config := _good()
		config["fixed"][room] = "combat"
		assert_bool(_has(_problems(config), "map.fixed")).override_failure_message("fixed room %s accepted" % room).is_true()
	var config := _good()
	config["fixed"]["3"] = "dragon"
	assert_bool(_has(_problems(config), "unknown type")).is_true()
	config = _good()
	config["fixed"].erase("10")
	assert_bool(_has(_problems(config), "must put the boss")).is_true()
	config = _good()
	config["fixed"]["9"] = "boss"
	assert_bool(_has(_problems(config), "boss belongs on the last room")).is_true()
	config = _good()
	config["fixed"]["10"] = "combat"
	assert_array(_problems(config)).is_not_empty()
	config = _good()
	config["fixed"] = []
	assert_bool(_has(_problems(config), "map.fixed must be an object")).is_true()


func test_estimate_numbers_are_checked() -> void:
	var cases: Array = [["merchant_prices", []], ["merchant_prices", [0]], ["merchant_prices", ["sixty"]], ["merchant_prices", 60], ["merchant_prices", [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]], ["gold_mean", {"combat": -1}], ["gold_mean", {"nope": 1}], ["gold_mean", []]]
	for case: Array in cases:
		var config := _good()
		config["estimate"][case[0]] = case[1]
		assert_bool(_has(_problems(config), String(case[0]))).override_failure_message("%s = %s accepted" % [case[0], str(case[1])]).is_true()


# --- BD2 carry-over: ui.relic.swap_line_one -------------------------------------------------------

func _run_config() -> Dictionary:
	return RunConfig.get_config().duplicate(true)


func test_shipped_run_json_validates_with_swap_line_one() -> void:
	assert_bool((_run_config()["ui"]["relic"] as Dictionary).has("swap_line_one")).is_true()
	assert_array(RunConfig.validate(_run_config(), [], [])).is_empty()


func test_swap_line_one_needs_one_number_and_one_name() -> void:
	for text: Variant in ["no placeholders", "%d only", "%s only", "%d %d %s", "%d %s %s", 7, null]:
		var config := _run_config()
		config["ui"]["relic"]["swap_line_one"] = text
		var problems: Array[String] = RunConfig.validate(config, [], [])
		assert_bool(_has(problems, "ui.relic.swap_line_one")).override_failure_message("swap_line_one %s accepted" % str(text)).is_true()
	var good := _run_config()
	good["ui"]["relic"]["swap_line_one"] = "You hold %d relic. Give it up to take %s."
	assert_array(RunConfig.validate(good, [], [])).is_empty()


# --- the file path: a broken map.json fails loudly and loads nothing -------------------------------

const FIXTURES := "res://tests/fixtures/map_bad/"


func test_load_from_the_shipped_file_gives_the_config_and_no_problems() -> void:
	var result: Dictionary = MapConfig.load_from(MapConfig.PATH)
	assert_array(result["problems"]).is_empty()
	assert_bool((result["config"] as Dictionary).is_empty()).is_false()


func test_broken_files_give_no_config_and_a_reason() -> void:
	var expected: Dictionary = {"not_json.json": "missing, empty or not a JSON object", "array.json": "missing, empty or not a JSON object", "unknown_key.json": "unknown key 'bogus'", "bad_window.json": "map.types.elite.rooms", "does_not_exist.json": "missing, empty or not a JSON object"}
	for file_name: String in expected:
		var result: Dictionary = MapConfig.load_from(FIXTURES + file_name)
		assert_bool((result["config"] as Dictionary).is_empty()).override_failure_message("%s loaded" % file_name).is_true()
		assert_bool(_has(result["problems"], String(expected[file_name]))).override_failure_message("%s: %s" % [file_name, str(result["problems"])]).is_true()
