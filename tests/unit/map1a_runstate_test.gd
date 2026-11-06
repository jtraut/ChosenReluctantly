class_name Map1aRunStateTest
extends GdUnitTestSuite
## MAP1-A item 3: RunState carries map, path, gold and xp_earned through to_dict / from_dict / to_json / equals.


func _state() -> RunState:
	var state := RunState.new_run(42, CharacterDatabase.starting_deck("rogue"), 3)
	state.map = MapGenerator.generate(42)
	state.path = MapGraph.first_route(state.map).slice(0, 4)
	state.gold = 47
	return state


func test_new_run_has_no_map() -> void:
	var state := RunState.new_run(1, CharacterDatabase.starting_deck("rogue"), 3)
	assert_bool(state.map.is_empty()).is_true()
	assert_array(state.path).is_empty()
	assert_int(state.gold).is_equal(0)
	assert_int(state.xp_earned).is_equal(0)


func test_dict_round_trip_keeps_map_path_and_gold() -> void:
	var state := _state()
	var back: RunState = RunState.from_dict(state.to_dict())
	assert_object(back).is_not_null()
	assert_bool(back.equals(state)).is_true()
	assert_str(JSON.stringify(back.map)).is_equal(JSON.stringify(state.map))
	assert_array(back.path).contains_exactly(state.path)
	assert_int(back.gold).is_equal(47)


func test_json_round_trip_survives_floats_and_stays_equal() -> void:
	# JSON turns whole numbers into floats; from_dict must cast ids, rooms, columns, edges, path and gold back to int.
	var state := _state()
	var back: RunState = RunState.from_json(state.to_json())
	assert_object(back).is_not_null()
	assert_bool(back.equals(state)).is_true()
	assert_int(typeof(back.gold)).is_equal(TYPE_INT)
	for node: Dictionary in (back.map["nodes"] as Array):
		assert_int(typeof(node["id"])).is_equal(TYPE_INT)
		assert_int(typeof(node["room"])).is_equal(TYPE_INT)
		assert_int(typeof(node["column"])).is_equal(TYPE_INT)
	for edge: Array in (back.map["edges"] as Array):
		assert_int(typeof(edge[0])).is_equal(TYPE_INT)
	assert_int(MapGraph.first_route(back.map).size()).is_equal(10)


func test_xp_earned_is_reserved_at_zero() -> void:
	var state := _state()
	assert_int(int(state.to_dict()["xp_earned"])).is_equal(0)
	assert_int(RunState.from_dict(state.to_dict()).xp_earned).is_equal(0)


func test_old_dict_without_map_keys_loads_as_no_map() -> void:
	var data: Dictionary = RunState.new_run(5, CharacterDatabase.starting_deck("rogue"), 3).to_dict()
	for key: String in ["map", "path", "gold", "xp_earned"]:
		data.erase(key)
	var state: RunState = RunState.from_dict(data)
	assert_object(state).is_not_null()
	assert_bool(state.map.is_empty()).is_true()
	assert_array(state.path).is_empty()
	assert_int(state.gold).is_equal(0)


func test_a_no_map_run_round_trips_equal() -> void:
	var plain := RunState.new_run(5, CharacterDatabase.starting_deck("rogue"), 3)
	assert_bool(RunState.from_json(plain.to_json()).equals(plain)).is_true()


func test_to_dict_copies_the_map() -> void:
	var state := _state()
	var data: Dictionary = state.to_dict()
	((data["map"]["nodes"] as Array)[0] as Dictionary)["type"] = "elite"
	assert_str(String(state.map["nodes"][0]["type"])).is_equal("combat")


func test_a_malformed_map_is_dropped_loudly_without_a_crash() -> void:
	var garbage: Array = [null, 7, "map", [], [1, 2], {"nodes": 5, "edges": []}, {"nodes": [], "edges": []}, {"nodes": [1], "edges": []},
		{"nodes": [{"id": 1}], "edges": []}, {"nodes": [{"id": 1, "room": 1, "column": 0, "type": "wizard", "wave_id": ""}], "edges": []},
		{"nodes": [{"id": 1, "room": 1, "column": 0, "type": "combat", "wave_id": ""}], "edges": [[1, 9]]},
		{"nodes": [{"id": 1, "room": 1, "column": 0, "type": "combat", "wave_id": ""}], "edges": [5]},
		{"nodes": [{"id": 1, "room": 1, "column": 0, "type": "combat", "wave_id": ""}, {"id": 1, "room": 2, "column": 0, "type": "combat", "wave_id": ""}], "edges": []},
		{"nodes": [{"id": "a", "room": 1, "column": 0, "type": "combat", "wave_id": ""}], "edges": []}]
	for value: Variant in garbage:
		var data: Dictionary = _state().to_dict()
		data["map"] = value
		var state: RunState = RunState.from_dict(data)
		assert_object(state).override_failure_message("from_dict returned null for map %s" % str(value)).is_not_null()
		assert_bool(state.map.is_empty()).override_failure_message("map %s was kept" % str(value)).is_true()
		assert_array(state.path).is_empty()  # a path with no map is dropped too


func test_a_bad_path_gold_or_xp_falls_back_without_a_crash() -> void:
	for value: Variant in [null, 7, "x", {}, [1, "a"], [999999], [null], [[1]]]:
		var data: Dictionary = _state().to_dict()
		data["path"] = value
		var state: RunState = RunState.from_dict(data)
		assert_object(state).is_not_null()
		assert_array(state.path).is_empty()
	for value: Variant in [null, "x", [], {}, true]:
		var data: Dictionary = _state().to_dict()
		data["gold"] = value
		data["xp_earned"] = value
		var state: RunState = RunState.from_dict(data)
		assert_object(state).is_not_null()
		assert_int(state.gold).is_equal(0)
		assert_int(state.xp_earned).is_equal(0)
