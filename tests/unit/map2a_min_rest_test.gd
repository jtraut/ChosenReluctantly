class_name Map2aMinRestTest
extends GdUnitTestSuite
## MAP2-A item 1 (D40 = A): the `min_rest` path rule is in data, validated, enforced on every path.


func _cfg() -> Dictionary:
	return MapConfig.get_config().duplicate(true)


func test_shipped_data_requires_one_rest_on_every_path() -> void:
	assert_int(int((_cfg()["path_rules"] as Dictionary)["min_rest"])).is_equal(1)


func test_min_rest_is_required_and_range_checked() -> void:
	var missing: Dictionary = _cfg()
	(missing["path_rules"] as Dictionary).erase("min_rest")
	assert_bool(" ".join(MapConfig.validate(missing)).contains("missing 'min_rest'")).is_true()
	var above: Dictionary = _cfg()
	(above["path_rules"] as Dictionary)["min_rest"] = 3  # max_rest is 2
	assert_bool(" ".join(MapConfig.validate(above)).contains("min_rest")).is_true()
	var negative: Dictionary = _cfg()
	(negative["path_rules"] as Dictionary)["min_rest"] = -1
	assert_bool(" ".join(MapConfig.validate(negative)).contains("min_rest")).is_true()


func test_a_path_without_a_rest_is_a_problem() -> void:
	var cfg: Dictionary = _cfg()
	var map: Dictionary = MapGenerator.generate(1, cfg)
	assert_array(MapRules.check(map, cfg)).is_empty()
	# Turn every rest node into a combat node: the rule must now fire on every path.
	for node: Variant in (map["nodes"] as Array):
		if String((node as Dictionary)["type"]) == "rest":
			(node as Dictionary)["type"] = "combat"
	var found: bool = false
	for problem: String in MapRules.path_problems(map, cfg):
		found = found or problem.contains("min_rest")
	assert_bool(found).override_failure_message("no min_rest problem on a map with no rest").is_true()


func test_every_generated_path_has_a_rest_over_100_seeds() -> void:
	var cfg: Dictionary = _cfg()
	for seed_value in range(1, 101):
		var map: Dictionary = MapGenerator.generate(seed_value, cfg)
		assert_bool(map.is_empty()).override_failure_message("seed %d has no map" % seed_value).is_false()
		var stats: MapRules.Extremes = MapRules.evaluate(map, cfg)
		assert_int(stats.min_rest).override_failure_message("seed %d has a path with no rest" % seed_value).is_greater_equal(1)


func test_the_one_pass_rest_count_matches_the_full_path_walk() -> void:
	var cfg: Dictionary = _cfg()
	for seed_value in range(1, 31):
		var map: Dictionary = MapGenerator.generate(seed_value, cfg)
		assert_int(MapRules.min_rest_over_paths(map)).override_failure_message("seed %d" % seed_value).is_equal(MapRules.evaluate(map, cfg).min_rest)
	# and on hand-made lanes with and without a rest
	var lane: Dictionary = {"nodes": [], "edges": []}
	var types: Array[String] = ["combat", "combat", "combat", "rest", "combat", "combat", "combat", "combat", "combat", "boss"]
	for i in range(types.size()):
		(lane["nodes"] as Array).append({"id": i, "room": i + 1, "column": 0, "type": types[i], "wave_id": ""})
		if i > 0:
			(lane["edges"] as Array).append([i - 1, i])
	assert_int(MapRules.min_rest_over_paths(lane)).is_equal(1)
	((lane["nodes"] as Array)[3] as Dictionary)["type"] = "combat"
	assert_int(MapRules.min_rest_over_paths(lane)).is_equal(0)


func test_the_straight_run_capture_presets_pin_no_map() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/capture_presets.json"))
	assert_int(typeof(parsed)).is_equal(TYPE_DICTIONARY)
	for name: String in ["removal_screen", "bd2_relic_elite", "bd2_relic_room", "bd2_relic_swap"]:
		var extra: Array = ((parsed as Dictionary)[name] as Dictionary)["extra"]
		assert_bool(extra.has("--no-map")).override_failure_message("%s lacks --no-map" % name).is_true()
