class_name Map1aGeneratorTest
extends GdUnitTestSuite
## MAP1-A item 2: the seeded map generator, the pure graph API and the relic estimate. The 1000-seed sweep is in map1a_sweep_test.gd.


func _cfg() -> Dictionary:
	return MapConfig.get_config().duplicate(true)


func _node(id: int, room: int, column: int, type_id: String) -> Dictionary:
	return {"id": id, "room": room, "column": column, "type": type_id, "wave_id": ""}


## A single straight lane of node types, one per room (the estimate and path-stat oracles).
func _lane(types: Array[String]) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var edges: Array = []
	for i in range(types.size()):
		nodes.append(_node(i, i + 1, 0, types[i]))
		if i > 0:
			edges.append([i - 1, i])
	return {"nodes": nodes, "edges": edges}


func _joined(problems: Array[String]) -> String:
	return "\n".join(problems)


func test_same_seed_gives_the_same_map() -> void:
	for seed_value in [1, 2, 99, 123456, 2147483647]:
		var a: Dictionary = MapGenerator.generate(seed_value)
		var b: Dictionary = MapGenerator.generate(seed_value)
		assert_bool(a.is_empty()).is_false()
		assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))


func test_different_seeds_give_different_maps() -> void:
	var seen: Dictionary = {}
	for seed_value in range(1, 13):
		seen[JSON.stringify(MapGenerator.generate(seed_value))] = true
	assert_int(seen.size()).is_greater_equal(10)


func test_map_has_the_documented_format() -> void:
	var map: Dictionary = MapGenerator.generate(5)
	assert_array(map.keys()).contains_exactly_in_any_order(["nodes", "edges"])
	var ids: Dictionary = {}
	for node: Dictionary in (map["nodes"] as Array):
		assert_array(node.keys()).contains_exactly_in_any_order(["id", "room", "column", "type", "wave_id"])
		assert_int(typeof(node["id"])).is_equal(TYPE_INT)
		ids[node["id"]] = true
	assert_int(ids.size()).is_equal((map["nodes"] as Array).size())
	for edge: Array in (map["edges"] as Array):
		assert_int(edge.size()).is_equal(2)
		assert_bool(ids.has(edge[0]) and ids.has(edge[1])).is_true()


func test_rooms_one_and_two_are_combat_and_room_ten_is_one_boss() -> void:
	for seed_value in range(1, 8):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for room in [1, 2]:
			for node: Dictionary in MapGraph.nodes_in_room(map, room):
				assert_str(String(node["type"])).is_equal("combat")
		var last: Array[Dictionary] = MapGraph.nodes_in_room(map, 10)
		assert_int(last.size()).is_equal(1)
		assert_str(String(last[0]["type"])).is_equal("boss")
		assert_int(MapGraph.boss_id(map)).is_equal(int(last[0]["id"]))


func test_fight_nodes_have_a_wave_id_from_a_list_that_allows_their_room() -> void:
	var run: Dictionary = RunConfig.get_config()
	for seed_value in range(1, 8):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for node: Dictionary in (map["nodes"] as Array):
			var type_id: String = String(node["type"])
			if MapConfig.FIGHT_TYPES.has(type_id):
				var ids: Array[String] = []
				for variant: Dictionary in RunConfig.variants_for(int(node["room"]) - 1, run["rooms"][type_id]):
					ids.append(String(variant["id"]))
				assert_array(ids).contains([String(node["wave_id"])])
			else:
				assert_str(String(node["wave_id"])).is_empty()


func test_a_fight_avoids_the_wave_just_before_it_when_another_fits() -> void:
	# Combat from room 4 has three lists to draw from, so a combat node right after a combat node never repeats it.
	var checked: int = 0
	for seed_value in range(1, 30):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for edge: Array in (map["edges"] as Array):
			var a: Dictionary = MapGraph.node(map, int(edge[0]))
			var b: Dictionary = MapGraph.node(map, int(edge[1]))
			# A node with several predecessors avoids all of their waves when it can, which three lists may not allow: test single-entry nodes.
			if String(a["type"]) == "combat" and String(b["type"]) == "combat" and int(b["room"]) >= 4 and MapGraph.prev_ids(map, int(b["id"])).size() == 1:
				checked += 1
				assert_str(String(b["wave_id"])).is_not_equal(String(a["wave_id"]))
	assert_int(checked).is_greater(20)


func test_the_generator_does_not_touch_the_run_generator_stream() -> void:
	var before: String = JSON.stringify(RunGenerator.generate(1, RunConfig.get_config()))
	MapGenerator.generate(1)
	assert_str(JSON.stringify(RunGenerator.generate(1, RunConfig.get_config()))).is_equal(before)


func test_unreachable_path_rules_fail_loudly_after_max_attempts() -> void:
	var cfg := _cfg()
	cfg["max_attempts"] = 5
	cfg["path_rules"]["relic_route"] = [20, 20]  # no path can hold 20 relics
	var result: Dictionary = MapGenerator.build(3, cfg)
	assert_bool(bool(result["ok"])).is_false()
	assert_int(int(result["attempts"])).is_equal(5)
	assert_str(String(result["error"])).contains("no valid map for seed 3 in 5 attempts")
	assert_str(String(result["error"])).contains("relic")
	assert_bool((result["map"] as Dictionary).is_empty()).is_true()


func test_unreachable_shape_rules_fail_loudly() -> void:
	var cfg := _cfg()
	cfg["path_rules"]["min_branching"] = 1.0
	var result: Dictionary = MapGenerator.build(3, cfg)
	assert_bool(bool(result["ok"])).is_false()
	assert_str(String(result["error"])).contains("shape rules")


# --- graph API ---------------------------------------------------------------------------------

func test_next_ids_are_lowest_column_first_and_first_route_follows_them() -> void:
	var map: Dictionary = MapGenerator.generate(7)
	var route: Array[int] = MapGraph.first_route(map)
	assert_int(route.size()).is_equal(10)
	assert_int(route[0]).is_equal(MapGraph.start_ids(map)[0])
	assert_int(route[9]).is_equal(MapGraph.boss_id(map))
	for i in range(9):
		var options: Array[int] = MapGraph.next_ids(map, route[i])
		assert_array(options).is_not_empty()
		assert_int(route[i + 1]).is_equal(options[0])
		var columns: Array[int] = []
		for id in options:
			columns.append(int(MapGraph.node(map, id)["column"]))
		var sorted_columns: Array[int] = columns.duplicate()
		sorted_columns.sort()
		assert_array(columns).contains_exactly(sorted_columns)


func test_all_paths_are_ten_rooms_start_to_boss_and_follow_edges() -> void:
	var map: Dictionary = MapGenerator.generate(11)
	var paths: Array[Array] = MapGraph.all_paths(map)
	assert_array(paths).is_not_empty()
	assert_int(paths.size()).is_equal(MapRules.evaluate(map, MapConfig.get_config()).paths)
	var starts: Array[int] = MapGraph.start_ids(map)
	for path: Array in paths:
		assert_int(path.size()).is_equal(10)
		assert_array(starts).contains([path[0]])
		assert_int(int(path[9])).is_equal(MapGraph.boss_id(map))
		for i in range(9):
			assert_array(MapGraph.next_ids(map, int(path[i]))).contains([path[i + 1]])
	var first: Array[int] = MapGraph.first_route(map)
	var found: bool = false
	for path: Array in paths:
		if path == first:
			found = true
	assert_bool(found).is_true()


func test_prev_ids_mirror_next_ids() -> void:
	var map: Dictionary = MapGenerator.generate(4)
	for edge: Array in (map["edges"] as Array):
		assert_array(MapGraph.prev_ids(map, int(edge[1]))).contains([int(edge[0])])


func test_edges_cross_rule() -> void:
	assert_bool(MapGraph.edges_cross(0, 2, 1, 1)).is_true()
	assert_bool(MapGraph.edges_cross(2, 0, 1, 1)).is_true()
	assert_bool(MapGraph.edges_cross(0, 1, 1, 2)).is_false()  # parallel
	assert_bool(MapGraph.edges_cross(1, 1, 1, 2)).is_false()  # shared start
	assert_bool(MapGraph.edges_cross(0, 1, 2, 1)).is_false()  # shared end
	var crossed: Dictionary = {"nodes": [_node(0, 1, 0, "combat"), _node(1, 1, 1, "combat"), _node(2, 2, 0, "combat"), _node(3, 2, 1, "combat")], "edges": [[0, 3], [1, 2]]}
	assert_bool(MapGraph.has_crossing(crossed)).is_true()
	crossed["edges"] = [[0, 2], [1, 3]]
	assert_bool(MapGraph.has_crossing(crossed)).is_false()


func test_to_text_prints_every_room() -> void:
	var text: String = MapGraph.to_text(MapGenerator.generate(7))
	assert_int(text.split("\n").size()).is_equal(10)
	assert_str(text).contains("BOSS")


# --- the relic estimate (MAP.md section 4.1 / 4.2 worked routes) ---------------------------------

func test_relic_hunter_route_estimates_seven() -> void:
	# C C E R* E C E R* M Boss: 150 gold on arrival at the merchant buys 2, plus 5 relic nodes.
	var map: Dictionary = _lane(["combat", "combat", "elite", "relic_room", "elite", "combat", "elite", "relic_room", "merchant", "boss"])
	assert_int(MapRules.relic_estimate(map, MapGraph.first_route(map), MapConfig.get_config())).is_equal(7)


func test_ignore_relics_route_estimates_two() -> void:
	# C C C C E C Rs M C Boss: 110 gold buys 1, plus the elite.
	var map: Dictionary = _lane(["combat", "combat", "combat", "combat", "elite", "combat", "rest", "merchant", "combat", "boss"])
	assert_int(MapRules.relic_estimate(map, MapGraph.first_route(map), MapConfig.get_config())).is_equal(2)


func test_merchant_stock_caps_the_estimate_and_gold_floors() -> void:
	var estimate: Dictionary = MapConfig.get_config()["estimate"]
	assert_int(MapRules.merchant_relics(0.0, estimate)).is_equal(0)
	assert_int(MapRules.merchant_relics(59.0, estimate)).is_equal(0)
	assert_int(MapRules.merchant_relics(60.0, estimate)).is_equal(1)
	assert_int(MapRules.merchant_relics(179.0, estimate)).is_equal(2)
	assert_int(MapRules.merchant_relics(100000.0, estimate)).is_equal(3)


func test_relic_node_types_count_one_each_and_the_boss_counts_zero() -> void:
	var map: Dictionary = _lane(["combat", "combat", "curse_room", "buff_room", "mini_boss", "rest", "combat", "combat", "combat", "boss"])
	assert_int(MapRules.relic_estimate(map, MapGraph.first_route(map), MapConfig.get_config())).is_equal(3)


func test_path_stats_counts_fights_elite_like_rest_and_merchants() -> void:
	var map: Dictionary = _lane(["combat", "combat", "elite", "mini_boss", "rest", "merchant", "relic_room", "rest", "combat", "boss"])
	var stats: Dictionary = MapRules.path_stats(map, MapGraph.first_route(map), MapConfig.get_config())
	assert_int(int(stats["fights"])).is_equal(6)
	assert_int(int(stats["elite_like"])).is_equal(2)
	assert_int(int(stats["rest"])).is_equal(2)
	assert_int(int(stats["merchants"])).is_equal(1)


# --- the rules catch a hand-made bad map --------------------------------------------------------

func test_path_rules_catch_each_violation() -> void:
	var cfg := _cfg()
	var elites: Array[String] = ["combat", "combat", "elite", "combat", "elite", "combat", "elite", "combat", "elite", "boss"]
	assert_str(_joined(MapRules.path_problems(_lane(elites), cfg))).contains("elite-like")
	var rests: Array[String] = ["combat", "combat", "combat", "combat", "rest", "combat", "rest", "combat", "rest", "boss"]
	assert_str(_joined(MapRules.path_problems(_lane(rests), cfg))).contains("rest nodes")
	var few_fights: Array[String] = ["combat", "combat", "relic_room", "rest", "relic_room", "rest", "relic_room", "combat", "relic_room", "boss"]
	assert_str(_joined(MapRules.path_problems(_lane(few_fights), cfg))).contains("fights")
	var merchants: Array[String] = ["combat", "combat", "combat", "merchant", "combat", "merchant", "combat", "combat", "combat", "boss"]
	assert_str(_joined(MapRules.path_problems(_lane(merchants), cfg))).contains("merchants")
	var no_relics: Array[String] = ["combat", "combat", "combat", "combat", "combat", "combat", "combat", "combat", "combat", "boss"]
	assert_str(_joined(MapRules.path_problems(_lane(no_relics), cfg))).contains("relic estimate")
	# On a single lane the best and the worst path are the same path, so a 5-relic lane breaks ignore_route_max (3).
	var rich: Array[String] = ["combat", "combat", "elite", "relic_room", "elite", "relic_room", "elite", "combat", "combat", "boss"]
	assert_str(_joined(MapRules.path_problems(_lane(rich), cfg))).contains("worst path")


func test_type_rules_catch_window_fixed_and_no_repeat() -> void:
	var cfg := _cfg()
	var bad_window: Array[String] = ["combat", "combat", "combat", "combat", "combat", "combat", "combat", "combat", "relic_room", "boss"]
	assert_str(_joined(MapRules.type_problems(_lane(bad_window), cfg))).contains("window")
	var bad_fixed: Array[String] = ["combat", "elite", "combat", "combat", "combat", "combat", "combat", "combat", "combat", "boss"]
	assert_str(_joined(MapRules.type_problems(_lane(bad_fixed), cfg))).contains("fixed")
	var repeat: Array[String] = ["combat", "combat", "combat", "elite", "elite", "combat", "combat", "combat", "combat", "boss"]
	assert_str(_joined(MapRules.type_problems(_lane(repeat), cfg))).contains("no_repeat")


func test_shape_rules_catch_a_thin_room() -> void:
	var cfg := _cfg()
	var lane: Array[String] = ["combat", "combat", "combat", "combat", "combat", "combat", "combat", "combat", "combat", "boss"]
	assert_str(_joined(MapRules.shape_problems(_lane(lane), cfg))).contains("nodes (needs 2 to 4)")
