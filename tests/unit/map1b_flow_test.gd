class_name Map1bFlowTest
extends GdUnitTestSuite
## MAP1-B: the map run flow. Node handling per type, gold rolls, chest sizes and their tier odds, --map / --no-map, --run-room along the first
## route, the mid-map round trip, the route bot policies, a straight run unchanged, and one scene-level pass through the real RunController.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	RunSession.acts_override = 1  # MAP3-B: these tests pin the one-act run (it ends in the boss); the three-act flow is map3b_acts_test
	RunSession.clear()
	RunSession.map_override = -1
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.acts_override = 0
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.start_relics = []
	RunSession.forced_relic_offer = []
	RunSession.relic_cap = 0
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false  # GamePause.reset() forgets its flag but not the tree; a class pick left open by a test must not leak a paused tree


func _ctx(character: String = "rogue") -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools(character))


## A map state positioned on the first node of `type_id` (seeds 1 up), with the path walked back to a room-1 node through the first predecessors.
func _state_on(type_id: String, first_seed: int = 1) -> RunState:
	for seed_value in range(first_seed, first_seed + 80):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != type_id:
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			return state
	return null


# --- node handling -------------------------------------------------------------------------------

func test_a_combat_node_offers_cards_and_pays_gold() -> void:
	var state: RunState = _state_on("combat", 1)
	var node: Dictionary = RunNodes.current_node(state)
	assert_str(RunRelics.open_for_room(state, "combat", false, _ctx())).is_equal(RunState.PENDING_REWARD)
	assert_int(state.offer.size()).is_equal(RunConfig.offer_size())
	var gold: int = RunNodes.roll_gold(state.seed_value, int(node["id"]), "combat", RunConfig.gold())
	assert_int(gold).is_between(24, 36)


func test_an_elite_node_offers_relics_and_pays_gold_and_falls_back_to_cards_with_none_eligible() -> void:
	var state: RunState = _state_on("elite", 1)
	var ctx: Dictionary = _ctx()
	assert_str(RunRelics.open_for_room(state, "elite", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_int(state.offer.size()).is_equal(3)
	assert_int(RunNodes.roll_gold(state.seed_value, int(RunNodes.current_node(state)["id"]), "elite", RunConfig.gold())).is_between(60, 80)
	var empty: RunState = _state_on("elite", 1)
	empty.relics_given_up = RelicDatabase.ids()  # every relic there is (13 since MAP2-B), so none is left to offer
	assert_str(RunRelics.open_for_room(empty, "elite", false, ctx)).is_equal(RunState.PENDING_REWARD)


func test_a_relic_stage_has_no_fight_pays_no_gold_and_offers_relics() -> void:
	var state: RunState = _state_on("relic_room", 1)
	var ctx: Dictionary = _ctx()
	var node: Dictionary = RunNodes.current_node(state)
	assert_str(RunRelics.open_for_room(state, "relic_room", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_int(state.offer.size()).is_greater(0)
	assert_int(RunNodes.roll_gold(state.seed_value, int(node["id"]), "relic_room", RunConfig.gold())).is_equal(0)
	var model: Dictionary = RunChoices.model(state, ctx, "relic_room")
	assert_str(String(model["title"])).is_equal(String(RunConfig.ui()["relic"]["room_title"]))


func test_a_rest_node_opens_the_rest_menu_and_the_boss_node_nothing() -> void:
	var rest: RunState = _state_on("rest", 1)
	assert_str(RunRelics.open_for_room(rest, "rest", false, _ctx())).is_equal(RunState.PENDING_REST)
	assert_int(RunNodes.roll_gold(rest.seed_value, int(RunNodes.current_node(rest)["id"]), "rest", RunConfig.gold())).is_equal(0)
	var boss: RunState = _state_on("boss", 1)
	assert_str(RunRelics.open_for_room(boss, "boss", true, _ctx())).is_equal(RunState.PENDING_NONE)
	assert_int(RunNodes.roll_gold(boss.seed_value, int(RunNodes.current_node(boss)["id"]), "boss", RunConfig.gold())).is_equal(0)


func test_a_relic_stage_with_relics_off_gives_a_card_offer() -> void:
	var state: RunState = _state_on("relic_room", 1)
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["enabled"] = false
	assert_str(RunRelics.open_for_room(state, "relic_room", false, ctx)).is_equal(RunState.PENDING_REWARD)


func test_the_pick_next_node_choice_lists_the_reachable_nodes_and_a_pick_moves_the_run_on() -> void:
	var state: RunState = _state_on("combat", 3)
	var ctx: Dictionary = _ctx()
	var here: int = RunNodes.current_node(state)["id"]
	var expected: Array[int] = MapGraph.next_ids(state.map, here)
	assert_str(RunNodes.open(state)).is_equal(RunState.PENDING_NODE)
	assert_array(RunNodes.reachable_ids(state)).is_equal(expected)
	var model: Dictionary = RunChoices.model(state, ctx, "combat")
	assert_str(String(model["choice"])).is_equal(RunState.PENDING_NODE)
	assert_str(String(model["title"])).is_equal(String(RunConfig.ui()["map"]["title"]))
	assert_int((model["options"] as Array).size()).is_equal(expected.size())
	for option: Dictionary in (model["options"] as Array):
		assert_str(String(option["kind"])).is_equal("node")
		assert_bool(String(option["id"]).begins_with("node:")).is_true()
		assert_str(String(option["detail"])).is_not_empty()
	# not reachable: refused, nothing changes
	var far: int = -1
	for entry: Dictionary in (state.map["nodes"] as Array):
		if not expected.has(int(entry["id"])):
			far = int(entry["id"])
	var refused: Dictionary = RunChoices.apply(state, "node:%d" % far, ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	var rooms_before: int = state.room_index
	var picked: Dictionary = RunChoices.apply(state, "node:%d" % expected[expected.size() - 1], ctx)
	assert_bool(bool(picked["ok"])).is_true()
	assert_bool(bool(picked["finished"])).is_true()
	assert_str(String(picked["kind"])).is_equal("node")
	assert_int(state.path[state.path.size() - 1]).is_equal(expected[expected.size() - 1])
	assert_int(state.room_index).is_equal(rooms_before + 1)
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_bool(RunNodes.consistent(state)).is_true()


func test_the_start_of_a_map_run_lists_the_room_one_nodes() -> void:
	RunSession.map_override = 0
	var state := RunSession.begin_new_run(7)
	assert_bool(state.map.is_empty()).is_true()  # the straight run
	RunSession.map_override = 1
	var mapped := RunSession.begin_new_run(7)
	assert_bool(RunNodes.active(mapped)).is_true()
	assert_str(mapped.pending).is_equal(RunState.PENDING_NODE)
	assert_array(mapped.path).is_empty()
	assert_array(RunNodes.reachable_ids(mapped)).is_equal(MapGraph.start_ids(mapped.map))
	assert_bool(RunNodes.consistent(mapped)).is_true()
	var result: Dictionary = RunChoices.apply(mapped, "node:%d" % MapGraph.start_ids(mapped.map)[1], _ctx())
	assert_bool(bool(result["ok"])).is_true()
	assert_int(mapped.room_index).is_equal(0)  # the first pick stays in room 1
	assert_int(mapped.path.size()).is_equal(1)


# --- gold ----------------------------------------------------------------------------------------

func test_gold_is_seeded_from_the_run_seed_and_the_node_and_stays_in_range() -> void:
	var gold: Dictionary = RunConfig.gold()
	assert_array(RunNodes.gold_range("combat", gold)).is_equal([24, 36])
	assert_array(RunNodes.gold_range("elite", gold)).is_equal([60, 80])
	var seen_low: bool = false
	var seen_high: bool = false
	for seed_value in range(1, 200):
		var a: int = RunNodes.roll_gold(seed_value, 13, "combat", gold)
		assert_int(a).is_equal(RunNodes.roll_gold(seed_value, 13, "combat", gold))
		assert_int(a).is_between(24, 36)
		seen_low = seen_low or a == 24
		seen_high = seen_high or a == 36
		assert_int(RunNodes.roll_gold(seed_value, 20, "elite", gold)).is_between(60, 80)
	assert_bool(seen_low and seen_high).is_true()
	var other_node: bool = false
	for node_id in range(0, 40):
		other_node = other_node or RunNodes.roll_gold(5, node_id, "combat", gold) != RunNodes.roll_gold(5, 13, "combat", gold)
	assert_bool(other_node).is_true()
	assert_int(RunNodes.roll_gold(5, 13, "boss", gold)).is_equal(0)
	assert_int(RunNodes.roll_gold(5, 13, "rest", gold)).is_equal(0)
	assert_int(RunNodes.roll_gold(5, 13, "combat", {})).is_equal(0)


func test_the_gold_block_validates() -> void:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	assert_array(RunConfig._validate_gold(config["gold"])).is_empty()
	assert_array(RunConfig._validate_gold({"combat": [18, 12]})).is_not_empty()
	assert_array(RunConfig._validate_gold({"combat": [1]})).is_not_empty()
	assert_array(RunConfig._validate_gold({"boss": [1, 2]})).is_not_empty()
	assert_array(RunConfig._validate_gold({"combat": [1.5, 2]})).is_not_empty()
	assert_array(RunConfig._validate_gold("lots")).is_not_empty()
	assert_array(RunConfig._validate_gold(null)).is_not_empty()  # required (m3a_qa_test removes every top-level key)
	assert_array(RunConfig._validate_gold({})).is_empty()
	assert_array(RunConfig._validate_map_text(config["ui"]["map"])).is_empty()
	var broken: Dictionary = (config["ui"]["map"] as Dictionary).duplicate(true)
	(broken["hover"] as Dictionary).erase("elite")
	assert_array(RunConfig._validate_map_text(broken)).is_not_empty()


# --- chests --------------------------------------------------------------------------------------

func test_chest_sizes_follow_the_data_weights() -> void:
	var chests: Dictionary = MapConfig.chests()
	var counts: Dictionary = {"small": 0, "medium": 0, "large": 0}
	var total: int = 4000
	for seed_value in range(1, total + 1):
		var size_id: String = MapGenerator.roll_chest(seed_value, 13, chests)
		counts[size_id] = int(counts[size_id]) + 1
		assert_str(MapGenerator.roll_chest(seed_value, 13, chests)).is_equal(size_id)
	assert_float(float(counts["small"]) / total).is_between(0.46, 0.54)
	assert_float(float(counts["medium"]) / total).is_between(0.31, 0.39)
	assert_float(float(counts["large"]) / total).is_between(0.12, 0.18)


func test_every_relic_stage_carries_a_chest_and_other_nodes_do_not() -> void:
	for seed_value in range(1, 25):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for entry: Dictionary in (map["nodes"] as Array):
			assert_bool(entry.has("chest")).is_equal(String(entry["type"]) == "relic_room")
			if entry.has("chest"):
				assert_bool(MapConfig.CHEST_SIZES.has(String(entry["chest"]))).is_true()
		assert_str(JSON.stringify(MapGenerator.generate(seed_value))).is_equal(JSON.stringify(map))  # deterministic


func test_chests_change_nothing_but_the_chest_key() -> void:
	var without: Dictionary = MapConfig.get_config().duplicate(true)
	without.erase("chests")
	for seed_value in [1, 2, 3, 9, 14]:
		var plain: Dictionary = MapGenerator.generate(seed_value, without)
		var chested: Dictionary = MapGenerator.generate(seed_value)
		for entry: Dictionary in (chested["nodes"] as Array):
			entry.erase("chest")
		assert_str(JSON.stringify(chested)).is_equal(JSON.stringify(plain))


func test_the_chest_data_validates() -> void:
	var base: Dictionary = MapConfig.get_config().duplicate(true)
	assert_array(MapConfig.validate(base)).is_empty()
	var no_chests: Dictionary = base.duplicate(true)
	no_chests.erase("chests")
	assert_array(MapConfig.validate(no_chests)).is_empty()  # optional
	var missing: Dictionary = base.duplicate(true)
	(missing["chests"] as Dictionary).erase("large")
	assert_array(MapConfig.validate(missing)).is_not_empty()
	var both: Dictionary = base.duplicate(true)
	both["chests"]["small"]["act"] = 2
	assert_array(MapConfig.validate(both)).is_not_empty()
	var zero: Dictionary = base.duplicate(true)
	for size_id: String in MapConfig.CHEST_SIZES:
		zero["chests"][size_id]["weight"] = 0
	assert_array(MapConfig.validate(zero)).is_not_empty()
	var tier: Dictionary = base.duplicate(true)
	tier["chests"]["large"]["min_tier"] = 4
	assert_array(MapConfig.validate(tier)).is_not_empty()
	var typo: Dictionary = base.duplicate(true)
	typo["chests"]["huge"] = typo["chests"]["large"]
	assert_array(MapConfig.validate(typo)).is_not_empty()


func test_a_chest_size_picks_its_tier_row() -> void:
	var chests: Dictionary = MapConfig.chests()
	var rows: Dictionary = RelicConfig.block()["tier_weights"]
	var small: Dictionary = RunNodes.chest_weights("small", 1, chests, rows)  # the act's own row
	assert_array([float(small["tier1"]), float(small["tier2"]), float(small["tier3"])]).is_equal([80.0, 20.0, 0.0])
	var medium: Dictionary = RunNodes.chest_weights("medium", 1, chests, rows)  # the next act's row
	assert_array([float(medium["tier1"]), float(medium["tier2"]), float(medium["tier3"])]).is_equal([15.0, 70.0, 15.0])
	var large: Dictionary = RunNodes.chest_weights("large", 1, chests, rows)  # the act 3 row; min_tier 2 (MAP3b), so tier 1 is zeroed
	assert_float(float(large["tier1"])).is_equal(0.0)
	assert_float(float(large["tier2"])).is_equal(25.0)
	assert_float(float(large["tier3"])).is_equal(70.0)
	var strict: Dictionary = chests.duplicate(true)  # the min_tier filter itself: a large chest at min_tier 2 never rolls tier 1 (it did before MAP1 ux)
	(strict["large"] as Dictionary)["min_tier"] = 2
	assert_float(float(RunNodes.chest_weights("large", 1, strict, rows)["tier1"])).is_equal(0.0)
	assert_float(float(RunNodes.chest_weights("large", 1, strict, rows)["tier2"])).is_equal(25.0)
	(strict["large"] as Dictionary)["min_tier"] = 3
	assert_float(float(RunNodes.chest_weights("large", 1, strict, rows)["tier2"])).is_equal(0.0)
	assert_str(JSON.stringify(RunNodes.chest_weights("large", 2, chests, rows))).is_equal(JSON.stringify(large))  # a fixed row whatever the act
	assert_float(float(RunNodes.chest_weights("medium", 3, chests, rows)["tier3"])).is_equal(70.0)  # past the last row: the highest row
	assert_dict(RunNodes.chest_weights("huge", 1, chests, rows)).is_empty()


func test_a_relic_stage_offers_from_its_chest_row() -> void:
	# A small chest never offers a tier 3 relic. A large one never offers tier 1 (min_tier 2 as shipped), so it only has to offer something.
	var ctx: Dictionary = _ctx()
	var by_id: Dictionary = (ctx["relics"] as Dictionary)["by_id"]
	for chest_size: String in MapConfig.CHEST_SIZES:
		var checked: int = 0
		for seed_value in range(1, 80):
			var state: RunState = _state_on("relic_room", seed_value)
			if state == null or RunNodes.chest_of(RunNodes.current_node(state)) != chest_size:
				continue
			RunRelics.open_for_room(state, "relic_room", false, ctx)
			checked += 1
			for relic_id: String in state.offer:
				var rarity: String = String((by_id[relic_id] as Dictionary)["rarity"])
				if chest_size == "small":
					assert_str(rarity).is_not_equal("tier3")
			if chest_size == "large":
				assert_int(state.offer.size()).is_greater(0)
		assert_int(checked).override_failure_message("no %s chest found in seeds 1-79" % chest_size).is_greater(0)


# --- launch flags --------------------------------------------------------------------------------

func test_map_and_no_map_flags() -> void:
	assert_int(int(MapLaunch.resolve(PackedStringArray([]))["override"])).is_equal(MapLaunch.OVERRIDE_NONE)
	assert_int(int(MapLaunch.resolve(PackedStringArray(["--map"]))["override"])).is_equal(MapLaunch.OVERRIDE_ON)
	assert_int(int(MapLaunch.resolve(PackedStringArray(["--no-map"]))["override"])).is_equal(MapLaunch.OVERRIDE_OFF)
	assert_array(MapLaunch.resolve(PackedStringArray(["--map", "--run-room=3", "--class=wizard"]))["errors"]).is_empty()
	for bad: Array in [["--map", "--no-map"], ["--map", "--map"], ["--no-map", "--no-map"], ["--map=1"], ["--no-map=yes"], ["--map=", "--no-map"]]:
		var result: Dictionary = MapLaunch.resolve(PackedStringArray(bad))
		assert_array(result["errors"]).override_failure_message("%s was accepted" % str(bad)).is_not_empty()
		assert_int(int(result["override"])).is_equal(MapLaunch.OVERRIDE_NONE)


func test_the_override_beats_the_data_switch_both_ways() -> void:
	assert_bool(MapConfig.enabled()).is_true()  # shipped data has the map on
	assert_bool(RunSession.map_on()).is_true()
	RunSession.map_override = 1
	assert_bool(RunSession.map_on()).is_true()
	assert_bool(RunNodes.active(RunSession.begin_new_run(3))).is_true()
	RunSession.map_override = 0
	assert_bool(RunSession.map_on()).is_false()
	assert_bool(RunNodes.active(RunSession.begin_new_run(3))).is_false()
	# with the data switch on, --no-map still gives the straight run
	var cache: Dictionary = MapConfig.get_config()
	cache["enabled"] = true
	RunSession.map_override = -1
	assert_bool(RunSession.map_on()).is_true()
	RunSession.map_override = 0
	assert_bool(RunSession.map_on()).is_false()
	cache["enabled"] = false


func test_run_room_jumps_along_the_first_route() -> void:
	RunSession.map_override = 1
	for room_index in [0, 1, 4, 8, 9]:
		var state := RunSession.begin_new_run(21)
		state.jump_to_room(room_index)
		var route: Array[int] = MapGraph.first_route(state.map)
		assert_int(state.room_index).is_equal(room_index)
		assert_array(state.path).is_equal(route.slice(0, room_index + 1))
		assert_str(state.pending).is_equal(RunState.PENDING_NONE)
		assert_bool(RunNodes.consistent(state)).is_true()
	var straight := RunState.new_run(21, CharacterDatabase.starting_deck("rogue"), 3)
	straight.jump_to_room(4)
	assert_int(straight.room_index).is_equal(4)
	assert_array(straight.path).is_empty()
	var past := RunSession.begin_new_run(21)
	past.jump_to_room(99)
	assert_int(past.room_index).is_equal(9)  # clamped to the boss


# --- restore -------------------------------------------------------------------------------------

func test_a_mid_map_state_round_trips_with_its_open_choice() -> void:
	var ctx: Dictionary = _ctx()
	# the pick-next-node choice
	var picking: RunState = _state_on("combat", 5)
	picking.gold = 61
	RunNodes.open(picking)
	var back: RunState = RunState.from_json(picking.to_json())
	assert_bool(back.equals(picking)).is_true()
	assert_str(back.pending).is_equal(RunState.PENDING_NODE)
	assert_array(back.path).is_equal(picking.path)
	assert_int(back.gold).is_equal(61)
	assert_array(RunNodes.reachable_ids(back)).is_equal(RunNodes.reachable_ids(picking))
	assert_str(JSON.stringify(RunChoices.options(back, ctx))).is_equal(JSON.stringify(RunChoices.options(picking, ctx)))
	# the start of a run (empty path)
	RunSession.map_override = 1
	var fresh := RunSession.begin_new_run(8)
	var fresh_back: RunState = RunState.from_json(fresh.to_json())
	assert_bool(fresh_back.equals(fresh)).is_true()
	assert_str(fresh_back.pending).is_equal(RunState.PENDING_NODE)
	assert_array(fresh_back.path).is_empty()
	# a relic offer in a chest room keeps its chest size and its offer
	var chest: RunState = _state_on("relic_room", 2)
	RunRelics.open_for_room(chest, "relic_room", false, ctx)
	var chest_back: RunState = RunState.from_json(chest.to_json())
	assert_bool(chest_back.equals(chest)).is_true()
	assert_array(chest_back.offer).is_equal(chest.offer)
	assert_str(RunNodes.chest_of(RunNodes.current_node(chest_back))).is_equal(RunNodes.chest_of(RunNodes.current_node(chest)))
	# a reward choice after a won combat node
	var reward: RunState = _state_on("combat", 4)
	RunRelics.open_for_room(reward, "combat", false, ctx)
	var reward_back: RunState = RunState.from_json(reward.to_json())
	assert_bool(reward_back.equals(reward)).is_true()
	assert_str(reward_back.pending).is_equal(RunState.PENDING_REWARD)


func test_a_state_whose_path_does_not_fit_its_room_is_dropped_to_a_straight_run() -> void:
	var state: RunState = _state_on("combat", 6)
	var data: Dictionary = state.to_dict()
	data["room_index"] = int(data["room_index"]) + 2
	var back: RunState = RunState.from_dict(data)
	assert_object(back).is_not_null()
	assert_bool(back.map.is_empty()).is_true()
	assert_array(back.path).is_empty()
	var no_map: Dictionary = state.to_dict()
	no_map["map"] = {}
	no_map["pending"] = "node"
	var lone: RunState = RunState.from_dict(no_map)
	assert_str(lone.pending).is_equal(RunState.PENDING_NONE)  # a node pick needs a map


func test_an_unreadable_choice_in_a_map_run_reopens_the_node_pick() -> void:
	var state: RunState = _state_on("combat", 6)
	state.record_room({"index": state.room_index, "type": "combat", "wave_id": "x"}, 20.0, 5.0)
	var data: Dictionary = state.to_dict()
	data["pending"] = "reward"
	data["offer"] = []
	var back: RunState = RunState.from_dict(data)
	assert_str(back.pending).is_equal(RunState.PENDING_NODE)
	assert_int(back.room_index).is_equal(state.room_index)  # the won room is not replayed and the run does not skip a room


# --- route bots ----------------------------------------------------------------------------------

func test_route_policies_pick_valid_routes_with_the_promised_scores() -> void:
	var cfg: Dictionary = MapConfig.get_config()
	for seed_value in range(1, 13):
		var map: Dictionary = MapGenerator.generate(seed_value)
		var paths: Array[Array] = MapGraph.all_paths(map)
		var first: Array[int] = RouteBot.plan(map, "first", cfg, seed_value)
		assert_array(first).is_equal(MapGraph.first_route(map))
		var relic: Array[int] = RouteBot.plan(map, "relic", cfg, seed_value)
		var safe: Array[int] = RouteBot.plan(map, "safe", cfg, seed_value)
		var random: Array[int] = RouteBot.plan(map, "random", cfg, seed_value)
		for route: Array[int] in [first, relic, safe, random]:
			assert_int(route.size()).is_equal(10)
			assert_bool(MapGraph.start_ids(map).has(route[0])).is_true()
			assert_int(route[9]).is_equal(MapGraph.boss_id(map))
			for i in range(9):
				assert_bool(MapGraph.next_ids(map, route[i]).has(route[i + 1])).is_true()
		var best: int = 0
		var fewest_elite: int = 99
		for path: Array in paths:
			best = maxi(best, MapRules.relic_estimate(map, path, cfg))
			fewest_elite = mini(fewest_elite, int(MapRules.path_stats(map, path, cfg)["elite_like"]))
		assert_int(MapRules.relic_estimate(map, relic, cfg)).is_equal(best)
		assert_int(int(MapRules.path_stats(map, safe, cfg)["elite_like"])).is_equal(fewest_elite)
		for path: Array in paths:  # among the fewest-elite paths the safe route has the most rests
			if int(MapRules.path_stats(map, path, cfg)["elite_like"]) == fewest_elite:
				assert_int(int(MapRules.path_stats(map, safe, cfg)["rest"])).is_greater_equal(int(MapRules.path_stats(map, path, cfg)["rest"]))
		assert_array(RouteBot.plan(map, "random", cfg, seed_value)).is_equal(random)  # seeded
	assert_array(RouteBot.plan(MapGenerator.generate(1), "nonsense", cfg, 1)).is_empty()


func test_the_random_route_varies_with_the_seed() -> void:
	var cfg: Dictionary = MapConfig.get_config()
	var map: Dictionary = MapGenerator.generate(4)
	var seen: Dictionary = {}
	for seed_value in range(1, 30):
		seen[str(RouteBot.plan(map, "random", cfg, seed_value))] = true
	assert_int(seen.size()).is_greater(2)


func test_the_route_summary_counts_fights_elites_and_chests() -> void:
	var map: Dictionary = MapGenerator.generate(1)
	var route: Array[int] = MapGraph.first_route(map)
	var info: Dictionary = RouteBot.summary(map, route)
	var fights: int = 0
	for id: int in route:
		if MapConfig.FIGHT_TYPES.has(String(MapGraph.node(map, id)["type"])):
			fights += 1
	assert_int(int(info["fights"])).is_equal(fights)
	assert_int((info["chests"] as Array).size()).is_equal(int(info["relic_nodes"]))


# --- the straight run is unchanged ---------------------------------------------------------------

func test_a_straight_run_has_no_map_gold_or_node_choice() -> void:
	RunSession.map_override = 0  # the shipped data has the map on
	var state := RunSession.begin_new_run(5)
	assert_bool(RunNodes.active(state)).is_false()
	assert_bool(state.map.is_empty()).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_int(state.gold).is_equal(0)
	assert_array(RunNodes.reachable_ids(state)).is_empty()
	assert_dict(RunNodes.weights_for_current_room(state, _ctx())).is_empty()
	# the straight relic room keeps the act 1 row (no chest)
	var rooms: Array[Dictionary] = RunGenerator.generate(5, RunConfig.get_config())
	var relic_index: int = -1
	for room: Dictionary in rooms:
		if String(room["type"]) == "relic_room":
			relic_index = int(room["index"])
	assert_int(relic_index).is_greater(0)
	state.room_index = relic_index
	var straight: RunState = RunState.new_run(5, CharacterDatabase.starting_deck("rogue"), 3)
	straight.room_index = relic_index
	RunRelics.open_for_room(straight, "relic_room", false, _ctx())
	var legacy: RunState = RunState.new_run(5, CharacterDatabase.starting_deck("rogue"), 3)
	legacy.room_index = relic_index
	var offer: Array[String] = RelicOffer.offer("relic_room", 3, RunRelics.offer_rng(5, relic_index), RelicConfig.tier_weights_for_act(1), legacy.relics, legacy.relics_given_up,
			CharacterDatabase.pools("rogue"), RelicDatabase.all_relics())
	assert_array(straight.offer).is_equal(offer)


func test_the_class_pick_comes_before_the_first_node_pick_and_only_there() -> void:
	ClassPickScreen.enabled_override = true
	RunSession.map_override = 1
	var state := RunSession.begin_new_run(12)
	assert_bool(ClassPickScreen.should_open(state)).is_true()  # the start of a map run
	RunChoices.apply(state, "node:%d" % MapGraph.start_ids(state.map)[0], _ctx())
	assert_bool(ClassPickScreen.should_open(state)).is_false()  # room 1 after the pick: no second class pick
	RunSession.map_override = 0
	assert_bool(ClassPickScreen.should_open(RunSession.begin_new_run(12))).is_true()  # a straight run is as before
	ClassPickScreen.enabled_override = null


# --- through the real controller -----------------------------------------------------------------

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _win_room(main: Main) -> void:
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await _frames()


func _latest_main(except_id: int) -> Main:
	var found: Main = null
	for child in get_children():
		if child is Main and child.get_instance_id() != except_id and not child.is_queued_for_deletion():
			found = child as Main
	return found


func test_a_map_run_walks_start_pick_fight_gold_reward_next_pick() -> void:
	RunSession.map_override = 1
	var state := RunSession.begin_new_run(31)
	var main := _spawn()
	var main_id: int = main.get_instance_id()
	var models: Array[Dictionary] = []
	main.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	var golds: Array[int] = []
	main.run_controller.gold_changed.connect(func(total: int, delta: int) -> void: golds.append(total * 1000 + delta))
	await _frames(3)
	var controller: RunController = main.run_controller
	# the start: no room played, the room-1 nodes on offer
	assert_bool(controller.map_on()).is_true()
	assert_int(controller.current_node_id()).is_equal(-1)
	assert_array(controller.reachable_nodes()).is_equal(MapGraph.start_ids(state.map))
	assert_int(main.enemy_spawner.alive_count()).is_equal(0)
	assert_int(models.size()).is_equal(1)
	assert_str(String(models[0]["choice"])).is_equal("node")
	assert_int(controller.room_total()).is_equal(10)
	assert_str(controller.node_info(controller.reachable_nodes()[0])["hover"]).is_not_empty()
	assert_int(controller.node_infos().size()).is_equal((state.map["nodes"] as Array).size())
	assert_bool(bool(controller.pick_node(9999)["ok"])).is_false()
	var first_pick: int = controller.reachable_nodes()[0]
	var picked: Dictionary = controller.pick_node(first_pick)
	assert_bool(bool(picked["ok"])).is_true()
	assert_array(state.path).is_equal([first_pick])
	assert_int(state.room_index).is_equal(0)
	await _frames(3)
	# room 1: a fresh scene fighting the node's wave list
	var room_one: Main = _latest_main(main_id)
	var room_one_id: int = room_one.get_instance_id()
	assert_object(room_one).is_not_null()
	var c1: RunController = room_one.run_controller
	assert_int(c1.current_node_id()).is_equal(first_pick)
	assert_str(c1.room_type()).is_equal("combat")
	assert_str(String(c1.current_room()["wave_id"])).is_equal(String(MapGraph.node(state.map, first_pick)["wave_id"]))
	var models_1: Array[Dictionary] = []
	c1.choice_requested.connect(func(m: Dictionary) -> void: models_1.append(m))
	var gold_signals: Array[int] = []
	c1.gold_changed.connect(func(total: int, delta: int) -> void: gold_signals.append(total * 1000 + delta))
	await _win_room(room_one)
	var expected_gold: int = RunNodes.roll_gold(state.seed_value, first_pick, "combat", RunConfig.gold())
	assert_int(state.gold).is_equal(expected_gold)
	assert_int(c1.gold()).is_equal(expected_gold)
	assert_array(gold_signals).is_equal([expected_gold * 1000 + expected_gold])
	assert_int(int(c1.last_summary()["gold"])).is_equal(expected_gold)
	# the card reward first, then the next-node pick
	assert_str(String(models_1[0]["choice"])).is_equal("reward")
	assert_str(String(models_1[0]["next_line"])).is_empty()  # the map shows what is next
	c1.choose("skip")
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_int(models_1.size()).is_equal(2)
	assert_str(String(models_1[1]["choice"])).is_equal("node")
	assert_array(c1.reachable_nodes()).is_equal(MapGraph.next_ids(state.map, first_pick))
	assert_array(models_1[1]["path"]).is_equal([first_pick])
	var next_pick: int = c1.reachable_nodes()[0]
	assert_bool(bool(c1.pick_node(next_pick)["ok"])).is_true()
	assert_int(state.room_index).is_equal(1)
	assert_array(state.path).is_equal([first_pick, next_pick])
	await _frames(3)
	var room_two: Main = _latest_main(room_one_id)
	assert_object(room_two).is_not_null()
	assert_int(room_two.run_controller.room_number()).is_equal(2)
	assert_int(room_two.run_controller.current_node_id()).is_equal(next_pick)
	assert_int(room_two.run_controller.gold()).is_equal(expected_gold)


func test_the_reward_panel_gives_way_to_the_map_screen_on_the_next_node_pick_after_a_reward_is_taken() -> void:
	# MAP1 ux: the pick-next-node choice is the map screen's now (it replaced the placeholder list in the prompt). The finished reward must not
	# leave its panel up behind the map.
	RunSession.map_override = 1
	var state := RunSession.begin_new_run(31)
	state.jump_to_room(1)  # room 2 is always a combat node
	var main := _spawn()
	await _frames(3)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	var map_screen := main.get_node("MapScreen") as MapScreen
	await _win_room(main)
	assert_bool(screen.is_open()).is_true()
	assert_bool(map_screen.is_open()).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
	screen.disarm()
	screen._on_option_pressed("skip")
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(screen.is_open()).is_false()
	assert_bool(map_screen.is_open()).is_true()
	assert_int(map_screen.mode()).is_equal(MapScreen.Mode.PICK)
	var pickable: int = 0
	for id: int in map_screen.canvas.buttons().keys():
		if map_screen.canvas.button_for(id).focus_mode == Control.FOCUS_ALL:
			pickable += 1
	assert_int(pickable).is_equal(RunNodes.reachable_ids(state).size())


func test_a_map_relic_stage_opens_its_offer_at_once_and_a_reload_mid_pick_reopens_the_map() -> void:
	RunSession.map_override = 1
	var state: RunState = _state_on("relic_room", 1)
	RunSession.current = state
	var main := _spawn()
	var models: Array[Dictionary] = []
	main.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames(3)
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("relic_room")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(main.enemy_spawner.alive_count()).is_equal(0)
	assert_int(state.gold).is_equal(0)  # a relic stage pays nothing
	assert_str(String(models[0]["room_type"])).is_equal("relic_room")
	var node: Dictionary = controller.node_info(controller.current_node_id())
	assert_str(String(node["chest"])).is_not_empty()
	controller.skip_relic_offer()
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_array(controller.reachable_nodes()).is_equal(MapGraph.next_ids(state.map, controller.current_node_id()))
	# "reload" the scene mid-pick: the same state reopens the same pick, the room is not fought again
	var reopened := _spawn()
	var models_2: Array[Dictionary] = []
	reopened.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models_2.append(m))
	await _frames(3)
	assert_int(reopened.enemy_spawner.alive_count()).is_equal(0)
	assert_int(models_2.size()).is_equal(1)
	assert_str(String(models_2[0]["choice"])).is_equal("node")
	assert_array(reopened.run_controller.reachable_nodes()).is_equal(controller.reachable_nodes())
