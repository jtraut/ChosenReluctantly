class_name Map3bActsTest
extends GdUnitTestSuite
## MAP3 sitting B, steps 1-6: three acts. Config, per-act generation and its 1000-seed sweep, the act-end mini-boss, RunState's act fields and their
## save round trip (also through the real RunController across an act boundary), per-act streams and tier odds, the interim mini-boss reward and
## the exhausted-pool fallback, the act scaling hooks, wave lists per act and the three-act prices.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PATH := "user://tests/map3b_run_save.json"
const SWEEP_SEEDS := 1000


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RunSession.forced_relic_offer = []
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()


## JSON numbers are floats; compare lists of whole numbers as ints.
func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for value: Variant in values:
		out.append(int(value))
	return out


func _walk_first_route(state: RunState, ctx: Dictionary) -> void:
	# Picks the first reachable node until the act's last room (no fights are played; only the position matters here).
	while RunNodes.reachable_ids(state).size() > 0:
		var next: Array[int] = RunNodes.reachable_ids(state)
		assert_bool(bool(RunNodes.apply(state, "node:%d" % next[0], ctx)["ok"])).is_true()
		state.hp = 20.0
		state.max_hp = 30.0
		state.gold += 11
		state.record_room({"index": state.room_index, "type": "combat", "wave_id": "x"}, 20.0, 9.0)
		RunNodes.open(state)


func _run_at_act_end(seed_value: int) -> RunState:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(seed_value)
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	_walk_first_route(state, ctx)
	return state


# ---- config ----

func test_the_shipped_data_has_three_acts_and_the_multi_act_rules() -> void:
	assert_bool(MapConfig.is_valid()).is_true()
	assert_int(MapConfig.acts()).is_equal(3)
	var cfg: Dictionary = MapConfig.get_config()
	assert_array(_ints(cfg["multi_act"]["path_rules"]["relic_route"] as Array)).is_equal([4, 6])
	assert_int(int(cfg["multi_act"]["path_rules"]["max_relic_rooms"])).is_equal(2)
	var act1: Dictionary = MapConfig.for_act(cfg, 1, 3)
	var act3: Dictionary = MapConfig.for_act(cfg, 3, 3)
	assert_str(String(act1["fixed"]["10"])).is_equal("mini_boss")
	assert_str(String(act3["fixed"]["10"])).is_equal("boss")
	assert_array(_ints(act1["path_rules"]["relic_route"] as Array)).is_equal([4, 6])
	# a one-act run keeps the MAP2 rules and the boss
	var single: Dictionary = MapConfig.for_act(cfg, 1, 1)
	assert_str(String(single["fixed"]["10"])).is_equal("boss")
	assert_array(_ints(single["path_rules"]["relic_route"] as Array)).is_equal([6, 8])
	assert_bool(single["path_rules"].has("max_relic_rooms")).is_false()


func test_map_config_validation_of_the_new_keys() -> void:
	var good: Dictionary = MapConfig.get_config().duplicate(true)
	assert_array(MapConfig.validate(good)).is_empty()
	var cases: Dictionary = {
		"acts 0": func(c: Dictionary) -> void: c["acts"] = 0,
		"acts text": func(c: Dictionary) -> void: c["acts"] = "three",
		"acts 1.5": func(c: Dictionary) -> void: c["acts"] = 1.5,
		"multi_act text": func(c: Dictionary) -> void: c["multi_act"] = "x",
		"multi_act unknown key": func(c: Dictionary) -> void: c["multi_act"]["bogus"] = 1,
		"multi_act rule unknown": func(c: Dictionary) -> void: c["multi_act"]["path_rules"]["min_fights"] = 3,
		"multi_act route reversed": func(c: Dictionary) -> void: c["multi_act"]["path_rules"]["relic_route"] = [6, 4],
		"multi_act estimate price 0": func(c: Dictionary) -> void: c["multi_act"]["estimate"]["merchant_prices"] = [0],
		"max_relic_rooms text": func(c: Dictionary) -> void: c["path_rules"]["max_relic_rooms"] = "two",
	}
	for label: String in cases:
		var broken: Dictionary = good.duplicate(true)
		(cases[label] as Callable).call(broken)
		assert_array(MapConfig.validate(broken)).override_failure_message(label + " was accepted").is_not_empty()


func test_a_file_without_acts_is_a_one_act_run() -> void:
	var cfg: Dictionary = MapConfig.get_config().duplicate(true)
	cfg.erase("acts")
	cfg.erase("multi_act")
	assert_array(MapConfig.validate(cfg)).is_empty()
	assert_int(MapConfig.acts(cfg)).is_equal(1)


# ---- generation ----

func test_each_act_is_its_own_deterministic_map() -> void:
	var first: Dictionary = MapGenerator.generate(7, {}, {}, 1, 3)
	var second: Dictionary = MapGenerator.generate(7, {}, {}, 2, 3)
	var third: Dictionary = MapGenerator.generate(7, {}, {}, 3, 3)
	assert_bool(JSON.stringify(first) != JSON.stringify(second)).is_true()
	assert_bool(JSON.stringify(second) != JSON.stringify(third)).is_true()
	assert_str(JSON.stringify(MapGenerator.generate(7, {}, {}, 2, 3))).is_equal(JSON.stringify(second))
	# the same seed with one act is the MAP2 map, and act 1 uses the run seed itself
	assert_str(JSON.stringify(MapGenerator.generate(7))).is_equal(JSON.stringify(MapGenerator.generate(7, {}, {}, 1, 1)))
	assert_int(RunState.act_seed(7, 1)).is_equal(7)
	assert_int(RunState.act_seed(7, 2)).is_not_equal(RunState.act_seed(7, 3))


func test_acts_before_the_last_end_in_a_mini_boss_and_the_last_in_the_boss() -> void:
	for act_number in [1, 2, 3]:
		var map: Dictionary = MapGenerator.generate(3, {}, {}, act_number, 3)
		var end_id: int = MapGraph.boss_id(map)
		assert_int(end_id).is_not_equal(-1)
		var end_node: Dictionary = MapGraph.node(map, end_id)
		assert_int(int(end_node["room"])).is_equal(10)
		assert_str(String(end_node["type"])).is_equal("mini_boss" if act_number < 3 else "boss")
		var expected_wave: String = ["mini_boss_act1", "mini_boss_act2", "boss_guardian"][act_number - 1]
		assert_str(String(end_node["wave_id"])).is_equal(expected_wave)
		# every other mini-boss-free node: no mini_boss anywhere else (the in-act mini-boss is switched off)
		for entry: Dictionary in (map["nodes"] as Array):
			if int(entry["id"]) != end_id:
				assert_str(String(entry["type"])).is_not_equal("mini_boss")


func test_wave_ids_come_from_lists_that_allow_the_act() -> void:
	var rooms: Dictionary = RunConfig.get_config()["rooms"]
	for act_number in [1, 2, 3]:
		var map: Dictionary = MapGenerator.generate(11, {}, {}, act_number, 3)
		for entry: Dictionary in (map["nodes"] as Array):
			var type_id: String = String(entry["type"])
			if not MapConfig.FIGHT_TYPES.has(type_id):
				continue
			var allowed: Array = RunConfig.variants_for(int(entry["room"]) - 1, rooms[type_id], act_number)
			var ids: Array[String] = []
			for list: Dictionary in allowed:
				ids.append(String(list["id"]))
			assert_bool(ids.has(String(entry["wave_id"]))).override_failure_message("act %d room %d %s: wave '%s' not in %s" % [act_number, int(entry["room"]), type_id, String(entry["wave_id"]), str(ids)]).is_true()


func test_every_act_has_enough_wave_lists() -> void:
	var rooms: Dictionary = RunConfig.get_config()["rooms"]
	for act_number in [2, 3]:
		var combat: int = 0
		var elite: int = 0
		for list: Variant in (rooms["combat"] as Array):
			var used: bool = false
			for index in range(10):
				used = used or RunConfig.variants_for(index, [list], act_number).size() > 0
			combat += 1 if used else 0
		for list: Variant in (rooms["elite"] as Array):
			var used_elite: bool = false
			for index in range(10):
				used_elite = used_elite or RunConfig.variants_for(index, [list], act_number).size() > 0
			elite += 1 if used_elite else 0
		assert_int(combat).override_failure_message("act %d combat lists" % act_number).is_greater_equal(4)
		assert_int(elite).override_failure_message("act %d elite lists" % act_number).is_greater_equal(2)
	# act 1 keeps today's lists, unchanged
	var act1_ids: Array[String] = []
	for list: Dictionary in RunConfig.variants_for(5, rooms["combat"], 1):
		act1_ids.append(String(list["id"]))
	assert_array(act1_ids).contains_exactly(["combat_mixed", "combat_swarm", "combat_stonewall"])
	var straight: Array[String] = []
	for list: Dictionary in RunConfig.variants_for(0, rooms["combat"], 1):
		straight.append(String(list["id"]))
	assert_array(straight).is_equal(["combat_intro"])


func test_the_per_act_sweep_has_no_failures() -> void:
	var base: Dictionary = MapConfig.get_config()
	var failures: Array[String] = []
	for act_number in [1, 2, 3]:
		var cfg: Dictionary = MapConfig.for_act(base, act_number, 3)
		for seed_value in range(1, SWEEP_SEEDS + 1):
			var result: Dictionary = MapGenerator.build(seed_value, base, {}, act_number, 3)
			if not bool(result["ok"]):
				failures.append("act %d seed %d: %s" % [act_number, seed_value, String(result["error"])])
				continue
			var problems: Array[String] = MapRules.check(result["map"], cfg)
			if not problems.is_empty():
				failures.append("act %d seed %d: %s" % [act_number, seed_value, "; ".join(problems)])
	assert_array(failures).override_failure_message("per-act sweep failures:\n" + "\n".join(failures.slice(0, 10))).is_empty()


func test_the_relic_stage_limit_and_the_end_node_budget_hold_on_every_path() -> void:
	var cfg: Dictionary = MapConfig.for_act(MapConfig.get_config(), 1, 3)
	for seed_value in range(1, 41):
		var map: Dictionary = MapGenerator.generate(seed_value, {}, {}, 1, 3)
		for path: Array in MapGraph.all_paths(map):
			var stages: int = 0
			var elites: int = 0
			for id: Variant in path:
				var type_id: String = String(MapGraph.node(map, int(id))["type"])
				stages += 1 if type_id == "relic_room" else 0
				elites += 1 if type_id == "elite" else 0
			assert_int(stages).is_less_equal(2)
			assert_int(elites).is_less_equal(int(cfg["path_rules"]["max_elite_like"]))


# ---- RunState ----

func test_a_new_three_act_run_is_act_one_of_three() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(21)
	assert_int(state.act).is_equal(1)
	assert_int(state.acts_total).is_equal(3)
	assert_bool(state.past_acts.is_empty()).is_true()
	assert_int(state.run_room_total()).is_equal(30)
	assert_int(state.rooms_per_act()).is_equal(10)
	RunSession.clear()
	RunSession.acts_override = 1
	var single: RunState = RunSession.begin_new_run(21)
	assert_int(single.acts_total).is_equal(1)
	assert_int(single.run_room_total()).is_equal(10)
	# the straight run has no acts at all
	RunSession.clear()
	RunSession.map_override = 0
	RunSession.acts_override = 0
	var straight: RunState = RunSession.begin_new_run(21)
	assert_int(straight.acts_total).is_equal(1)
	assert_bool(straight.map.is_empty()).is_true()


func test_advance_act_archives_the_act_and_carries_everything_else() -> void:
	var state: RunState = _run_at_act_end(9)
	state.add_relic("heavy_sigh")
	state.rejects_remaining = 2
	state.deck.append("rogue_flurry")
	var old_map: Dictionary = state.map
	var old_path: Array[int] = state.path.duplicate()
	var deck_before: Array[String] = state.deck.duplicate()
	var gold_before: int = state.gold
	assert_bool(RunNodes.at_act_end(state)).is_true()
	assert_bool(RunNodes.has_next_act(state)).is_true()
	assert_bool(RunNodes.advance_act(state)).is_true()
	assert_int(state.act).is_equal(2)
	assert_int(state.past_acts.size()).is_equal(1)
	assert_str(JSON.stringify(state.act_map(1))).is_equal(JSON.stringify(old_map))
	assert_array(state.act_path(1)).is_equal(old_path)
	assert_str(JSON.stringify(state.act_map(2))).is_equal(JSON.stringify(state.map))
	assert_bool(state.act_map(3).is_empty()).is_true()
	assert_bool(state.path.is_empty()).is_true()
	assert_int(state.room_index).is_equal(0)
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_array(state.deck).is_equal(deck_before)
	assert_int(state.gold).is_equal(gold_before)
	assert_array(state.relics).is_equal(["heavy_sigh"])
	assert_int(state.rejects_remaining).is_equal(2)
	assert_float(state.hp).is_equal(20.0)  # no free heal
	assert_int(state.run_room_number()).is_equal(11)
	assert_array(RunNodes.reachable_ids(state)).is_equal(MapGraph.start_ids(state.map))
	assert_bool(RunNodes.consistent(state)).is_true()


func test_the_last_act_has_no_next_act() -> void:
	var state: RunState = _run_at_act_end(9)
	assert_bool(RunNodes.advance_act(state)).is_true()
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	_walk_first_route(state, ctx)
	assert_bool(RunNodes.advance_act(state)).is_true()
	_walk_first_route(state, ctx)
	assert_int(state.act).is_equal(3)
	assert_bool(RunNodes.has_next_act(state)).is_false()
	assert_str(String(RunNodes.current_node(state)["type"])).is_equal("boss")
	assert_bool(RunNodes.advance_act(state)).is_false()  # loud, changes nothing
	assert_int(state.act).is_equal(3)
	assert_int(state.run_room_number()).is_equal(30)


func test_jump_to_room_counts_over_the_whole_run() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(4)
	state.jump_to_room(24)  # room 25 of 30
	assert_int(state.act).is_equal(3)
	assert_int(state.room_index).is_equal(4)
	assert_int(state.path.size()).is_equal(5)
	assert_int(state.past_acts.size()).is_equal(2)
	assert_int(state.run_room_number()).is_equal(25)
	assert_bool(RunNodes.consistent(state)).is_true()
	RunSession.clear()
	var mid: RunState = RunSession.begin_new_run(4)
	mid.jump_to_room(13)
	assert_int(mid.act).is_equal(2)
	assert_int(mid.room_index).is_equal(3)
	RunSession.clear()
	var last: RunState = RunSession.begin_new_run(4)
	last.jump_to_room(99)  # past the end clamps to the last room
	assert_int(last.run_room_number()).is_equal(30)
	RunSession.clear()
	RunSession.acts_override = 1
	var one_act: RunState = RunSession.begin_new_run(4)
	one_act.jump_to_room(99)
	assert_int(one_act.act).is_equal(1)
	assert_int(one_act.run_room_number()).is_equal(10)


func test_the_launch_flag_accepts_one_to_thirty_and_refuses_more() -> void:
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--run-room=30"]), 30)).is_empty()
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--run-room=1"]), 30)).is_empty()
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--run-room=31"]), 30)).is_not_empty()
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--run-seed=5"]), 30)).is_empty()
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--run-room=abc"]), 30)).is_empty()


func test_the_act_fields_round_trip_and_enter_equals() -> void:
	var state: RunState = _run_at_act_end(13)
	RunNodes.advance_act(state)
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
	var back: RunState = RunState.from_json(state.to_json())
	assert_object(back).is_not_null()
	assert_bool(state.equals(back)).is_true()
	assert_int(back.act).is_equal(2)
	assert_int(back.acts_total).is_equal(3)
	assert_int(back.past_acts.size()).is_equal(1)
	assert_array(back.act_path(1)).is_equal(state.act_path(1))
	assert_str(JSON.stringify(back.act_map(1))).is_equal(JSON.stringify(state.act_map(1)))
	# equals sees the act fields
	var other: RunState = RunState.from_json(state.to_json())
	other.act = 3
	assert_bool(state.equals(other)).is_false()
	var third: RunState = RunState.from_json(state.to_json())
	third.past_acts = []
	assert_bool(state.equals(third)).is_false()
	var fourth: RunState = RunState.from_json(state.to_json())
	(fourth.past_acts[0]["path"] as Array).pop_back()
	assert_bool(state.equals(fourth)).is_false()


func test_an_old_dict_without_act_fields_loads_as_act_one_of_one() -> void:
	var state: RunState = RunState.new_run(11, ["rogue_quick_slash"] as Array[String], 3)
	state.hp = 20.0
	state.max_hp = 30.0
	var data: Dictionary = JSON.parse_string(state.to_json()) as Dictionary
	data.erase("act")
	data.erase("acts_total")
	data.erase("past_acts")
	var loaded: RunState = RunState.from_dict(data)
	assert_object(loaded).is_not_null()
	assert_int(loaded.act).is_equal(1)
	assert_int(loaded.acts_total).is_equal(1)


func test_damaged_act_fields_are_refused_without_a_crash() -> void:
	var state: RunState = _run_at_act_end(15)
	RunNodes.advance_act(state)
	var good: Dictionary = JSON.parse_string(state.to_json()) as Dictionary
	assert_object(RunState.from_dict(good.duplicate(true))).is_not_null()
	var cases: Dictionary = {
		"act text": func(d: Dictionary) -> void: d["act"] = "two",
		"act null": func(d: Dictionary) -> void: d["act"] = null,
		"act 0": func(d: Dictionary) -> void: d["act"] = 0,
		"act above total": func(d: Dictionary) -> void: d["act"] = 4,
		"total 99": func(d: Dictionary) -> void: d["acts_total"] = 99,
		"fractional act": func(d: Dictionary) -> void: d["act"] = 1.5,
		"past_acts text": func(d: Dictionary) -> void: d["past_acts"] = "x",
		"past_acts empty in act 2": func(d: Dictionary) -> void: d["past_acts"] = [],
		"too many past acts": func(d: Dictionary) -> void: d["past_acts"] = [d["past_acts"][0], d["past_acts"][0]],
		"past act is a number": func(d: Dictionary) -> void: d["past_acts"] = [5],
		"past act without a map": func(d: Dictionary) -> void: d["past_acts"] = [{"path": [0]}],
		"past act map damaged": func(d: Dictionary) -> void: d["past_acts"][0]["map"] = {"nodes": 1, "edges": []},
		"past act path off its map": func(d: Dictionary) -> void: d["past_acts"][0]["path"] = [987654],
		"past act path text": func(d: Dictionary) -> void: d["past_acts"][0]["path"] = "abc",
		"past act path of objects": func(d: Dictionary) -> void: d["past_acts"][0]["path"] = [{"a": 1}],
	}
	for label: String in cases:
		var data: Dictionary = good.duplicate(true)
		(cases[label] as Callable).call(data)
		assert_object(RunState.from_dict(data)).override_failure_message(label + " was accepted").is_null()


func test_a_run_whose_map_was_dropped_is_a_straight_run_of_one_act() -> void:
	var state: RunState = _run_at_act_end(15)
	RunNodes.advance_act(state)
	var data: Dictionary = JSON.parse_string(state.to_json()) as Dictionary
	data["map"] = {"nodes": "x", "edges": []}
	data["path"] = []
	var loaded: RunState = RunState.from_dict(data)
	assert_object(loaded).is_not_null()
	assert_bool(loaded.map.is_empty()).is_true()
	assert_int(loaded.act).is_equal(1)
	assert_int(loaded.acts_total).is_equal(1)
	assert_bool(loaded.past_acts.is_empty()).is_true()


func test_choice_log_indexes_do_not_repeat_across_acts() -> void:
	var state: RunState = _run_at_act_end(17)
	state.log_choice("pick", "x")
	var in_act_one: int = int(state.choice_log[state.choice_log.size() - 1]["index"])
	RunNodes.advance_act(state)
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
	state.log_choice("pick", "x")
	var in_act_two: int = int(state.choice_log[state.choice_log.size() - 1]["index"])
	assert_int(in_act_one).is_equal(9)
	assert_int(in_act_two).is_equal(RunState.ACT_STRIDE)
	assert_int(state.stream_index()).is_equal(RunState.ACT_STRIDE)


# ---- streams, odds and gold ----

func test_acts_do_not_replay_each_others_offers_or_gold() -> void:
	var seed_value: int = 12
	var rng_a: RandomNumberGenerator = RunRelics.offer_rng(seed_value, 3)
	var rng_b: RandomNumberGenerator = RunRelics.offer_rng(seed_value, 3 + RunState.ACT_STRIDE)
	assert_int(rng_a.randi()).is_not_equal(rng_b.randi())
	var gold: Dictionary = RunConfig.gold()
	var different: int = 0
	for node_id in range(0, 30):
		var one: int = RunNodes.roll_gold(RunState.act_seed(seed_value, 1), node_id, "combat", gold)
		var two: int = RunNodes.roll_gold(RunState.act_seed(seed_value, 2), node_id, "combat", gold)
		different += 1 if one != two else 0
	assert_int(different).is_greater(10)
	assert_int(RunNodes.roll_gold(seed_value, 5, "combat", gold)).is_equal(RunNodes.roll_gold(RunState.act_seed(seed_value, 1), 5, "combat", gold))
	assert_int(RunNodes.roll_gold(seed_value, 5, "combat", gold, 2.0)).is_equal(RunNodes.roll_gold(seed_value, 5, "combat", gold) * 2)


func test_relic_offers_use_the_current_acts_tier_odds() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var relics: Dictionary = ctx["relics"]
	var state: RunState = RunState.new_run(1, ["rogue_quick_slash"] as Array[String], 3)
	var table: Dictionary = RelicConfig.block()["tier_weights"]
	assert_dict(RunRelics.weights_for(state, relics)).is_equal(table["1"])
	state.act = 2
	assert_dict(RunRelics.weights_for(state, relics)).is_equal(table["2"])
	state.act = 3
	assert_dict(RunRelics.weights_for(state, relics)).is_equal(table["3"])
	assert_dict(RunRelics.weights_for(state, relics, 1)).is_equal(table["3"])  # past the table: the last row
	state.act = 1
	assert_dict(RunRelics.weights_for(state, relics, 1)).is_equal(table["2"])  # the act 1 mini-boss draws act 2's odds
	# a context with no per-act table (a fixture) keeps its own row
	var fixture: Dictionary = {"weights": {"tier1": 1, "tier2": 0, "tier3": 0}}
	state.act = 3
	assert_dict(RunRelics.weights_for(state, fixture)).is_equal(fixture["weights"])


func test_chest_odds_follow_the_current_act() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var map: Dictionary = MapGenerator.generate(3, {}, {}, 2, 3)
	var state: RunState = RunState.new_run(3, ["rogue_quick_slash"] as Array[String], 3)
	state.map = map
	state.act = 2
	state.acts_total = 3
	state.past_acts = [{"map": map, "path": [] as Array[int]}] as Array[Dictionary]
	var chest_node: Dictionary = {}
	for entry: Dictionary in (map["nodes"] as Array):
		if String(entry["type"]) == "relic_room":
			chest_node = entry
			break
	assert_bool(chest_node.is_empty()).is_false()
	state.path = [int(chest_node["id"])] as Array[int]
	var weights: Dictionary = RunNodes.weights_for_current_room(state, ctx)
	var small: Dictionary = RunNodes.chest_weights(String(chest_node.get("chest", "small")), 2, ctx["nodes"]["chests"], ctx["nodes"]["tier_weights"])
	assert_dict(weights).is_equal(small)


# ---- the mini-boss reward and the exhausted pool ----

func _state_in_act(act_number: int) -> RunState:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(23)
	state.act = act_number
	state.room_index = 9
	return state


func test_the_mini_boss_offers_a_relic_then_a_card_offer() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var state: RunState = _state_in_act(1)
	state.act = 1
	assert_str(RunRelics.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_int(state.offer.size()).is_equal(3)
	var first: String = state.offer[0]
	var picked: Dictionary = RunRelics.apply(state, "relic:%s" % first, ctx)
	assert_bool(bool(picked["ok"])).is_true()
	assert_bool(state.has_relic(first)).is_true()
	assert_str(RunChoices.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_REWARD)
	assert_int(state.offer.size()).is_equal(3)


func test_the_mini_boss_relic_offer_can_be_skipped_for_free() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var state: RunState = _state_in_act(1)
	var rejects: int = state.rejects_remaining
	RunRelics.open_for_room(state, "mini_boss", false, ctx)
	var skipped: Dictionary = RunRelics.apply(state, "relic_skip", ctx)
	assert_bool(bool(skipped["ok"])).is_true()
	assert_int(state.rejects_remaining).is_equal(rejects)


func _own_every_relic_the_elite_can_offer(state: RunState, ctx: Dictionary) -> void:
	var pools: Array[String] = []
	for pool_id: Variant in (ctx["pools"] as Array):
		pools.append(String(pool_id))
	for relic: Dictionary in RelicOffer.eligible("elite", {"tier1": 1.0, "tier2": 1.0, "tier3": 1.0}, [] as Array[String], [] as Array[String], pools, RelicDatabase.all_relics()):
		state.add_relic(String(relic["id"]))


func test_an_exhausted_relic_pool_falls_back_to_one_card_offer() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	for act_number in [1, 2, 3]:
		for room_type in ["elite", "relic_room", "mini_boss"]:
			var state: RunState = _state_in_act(act_number)
			_own_every_relic_the_elite_can_offer(state, ctx)
			RunSession.forced_relic_offer = []
			var pending: String = RunRelics.open_for_room(state, room_type, false, ctx)
			assert_str(pending).override_failure_message("act %d %s: expected a card offer, got '%s'" % [act_number, room_type, pending]).is_equal(RunState.PENDING_REWARD)
			assert_int(state.offer.size()).is_greater(0)
			RunSession.clear()


func test_a_partly_exhausted_pool_offers_what_is_left() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var state: RunState = _state_in_act(2)
	var pools: Array[String] = []
	for pool_id: Variant in (ctx["pools"] as Array):
		pools.append(String(pool_id))
	var eligible: Array[Dictionary] = RelicOffer.eligible("elite", RelicConfig.tier_weights_for_act(2), [] as Array[String], [] as Array[String], pools, RelicDatabase.all_relics())
	for i in range(eligible.size() - 2):
		state.add_relic(String(eligible[i]["id"]))
	assert_str(RunRelics.open_for_room(state, "elite", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_int(state.offer.size()).is_equal(2)


# ---- act scaling ----

func test_act_scale_comes_from_data_and_defaults_to_one() -> void:
	var one: Dictionary = RunConfig.act_scale(1)
	assert_float(float(one["hp"])).is_equal(1.0)
	assert_float(float(one["damage"])).is_equal(1.0)
	var two: Dictionary = RunConfig.act_scale(2)
	var three: Dictionary = RunConfig.act_scale(3)
	assert_float(float(two["hp"])).is_greater(1.0)
	assert_float(float(three["hp"])).is_greater(float(two["hp"]))
	assert_float(float(three["damage"])).is_greater_equal(float(two["damage"]))
	assert_float(float(RunConfig.act_scale(9)["hp"])).is_equal(1.0)


func test_run_config_rejects_bad_act_scale_and_wave_acts() -> void:
	var good: Dictionary = RunConfig.get_config().duplicate(true)
	var known: Array[String] = EnemyConfig.enemy_ids()
	assert_array(RunConfig.validate(good, known, [] as Array[String])).is_empty()
	var cases: Dictionary = {
		"acts text": func(c: Dictionary) -> void: c["acts"] = "x",
		"act key zero": func(c: Dictionary) -> void: c["acts"]["0"] = {"hp": 1, "damage": 1, "gold": 1},
		"act entry missing hp": func(c: Dictionary) -> void: c["acts"]["2"].erase("hp"),
		"act hp text": func(c: Dictionary) -> void: c["acts"]["2"]["hp"] = "x",
		"act hp zero": func(c: Dictionary) -> void: c["acts"]["2"]["hp"] = 0,
		"act unknown key": func(c: Dictionary) -> void: c["acts"]["2"]["armor"] = 1,
		"wave acts empty": func(c: Dictionary) -> void: c["rooms"]["combat"][5]["acts"] = [],
		"wave acts text": func(c: Dictionary) -> void: c["rooms"]["combat"][5]["acts"] = "2",
		"wave acts zero": func(c: Dictionary) -> void: c["rooms"]["combat"][5]["acts"] = [0],
		"mini_boss tier missing marker": func(c: Dictionary) -> void: c["tiers"]["mini_boss"].erase("marker_color"),
		"mini_boss tier parity": func(c: Dictionary) -> void: c["tiers"]["mini_boss"]["armor"] = 99.0,
		"mini_boss list unknown enemy": func(c: Dictionary) -> void: c["rooms"]["mini_boss"][0]["stages"][0]["spawns"][0]["enemy"] = "nobody",
	}
	for label: String in cases:
		var broken: Dictionary = good.duplicate(true)
		(cases[label] as Callable).call(broken)
		assert_array(RunConfig.validate(broken, known, [] as Array[String])).override_failure_message(label + " was accepted").is_not_empty()
	# a config from before MAP3 (no acts, no mini_boss tier, no mini_boss lists) is still valid
	var old: Dictionary = good.duplicate(true)
	old.erase("acts")
	(old["tiers"] as Dictionary).erase("mini_boss")
	(old["rooms"] as Dictionary).erase("mini_boss")
	assert_array(RunConfig.validate(old, known, [] as Array[String])).is_empty()


func test_the_mini_boss_tier_is_in_data_and_the_wave_schema_allows_it() -> void:
	var tier: Dictionary = RunConfig.tier("mini_boss")
	assert_float(float(tier["hp_multiplier"])).is_equal(3.5)
	assert_float(float(tier["armor"])).is_equal(22.0)
	assert_float(float(tier["resistance_floor"])).is_equal(0.3)
	assert_float(float(tier["resistance_cap"])).is_equal(0.5)
	assert_bool(WaveConfig.TIERS.has("mini_boss")).is_true()
	var lists: Array = RunConfig.get_config()["rooms"]["mini_boss"]
	assert_int(lists.size()).is_equal(2)
	assert_str(String((lists[0] as Dictionary)["id"])).is_equal("mini_boss_act1")
	assert_str(String((lists[1] as Dictionary)["id"])).is_equal("mini_boss_act2")


func test_an_enemy_takes_its_acts_hp_and_damage_scale() -> void:
	var enemy: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	add_child(enemy)
	auto_free(enemy)
	var hp: float = enemy.health.max_health
	var damage: float = enemy.attack_damage
	enemy.apply_act_scale(1.0, 1.0)
	assert_float(enemy.health.max_health).is_equal(hp)
	enemy.apply_act_scale(1.35, 1.15)
	assert_float(enemy.health.max_health).is_equal_approx(hp * 1.35, 0.001)
	assert_float(enemy.health.current_health).is_equal_approx(hp * 1.35, 0.001)
	assert_float(enemy.damage_scale).is_equal(1.15)
	assert_float(enemy.attack_damage).is_equal(damage)  # the stat itself is untouched; the attack multiplies


# ---- prices ----

func test_three_act_prices_and_estimate() -> void:
	var prices: Dictionary = RelicConfig.block()["prices"]
	assert_int(int(prices["tier1"])).is_equal(80)
	assert_int(int(prices["tier2"])).is_equal(120)
	assert_int(int(prices["tier3"])).is_equal(170)
	var estimate: Dictionary = MapConfig.for_act(MapConfig.get_config(), 1, 3)["estimate"]
	assert_array(_ints(estimate["merchant_prices"] as Array)).is_equal([80, 80, 120])
	# the one-act estimate is unchanged
	assert_array(_ints(MapConfig.for_act(MapConfig.get_config(), 1, 1)["estimate"]["merchant_prices"] as Array)).is_equal([60, 60, 90])


# ---- save and resume across an act boundary ----

func test_the_act_start_map_screen_is_a_save_point_and_resumes_there() -> void:
	var state: RunState = _run_at_act_end(31)
	state.add_relic("heavy_sigh")
	assert_bool(RunSave.is_boundary(state)).is_true()
	assert_bool(RunNodes.advance_act(state)).is_true()
	assert_bool(state.path.is_empty()).is_true()
	assert_bool(RunSave.is_boundary(state)).is_true()  # act 2, map screen, nothing picked yet
	assert_bool(RunSave.autosave(state)).is_true()
	var expected_json: String = state.to_json()
	var expected_next: Array[int] = RunNodes.reachable_ids(state)
	RunSession.clear()  # quit
	assert_bool(RunSave.has_save()).is_true()
	assert_bool(RunSave.load_save()).is_true()
	assert_str(RunSession.current.to_json()).is_equal(expected_json)
	assert_array(RunNodes.reachable_ids(RunSession.current)).is_equal(expected_next)
	assert_int(RunSession.current.act).is_equal(2)
	assert_array(RunSession.current.relics).is_equal(["heavy_sigh"])
	# act 1's first map screen (nothing picked, act 1) is still not a save point
	RunSession.clear()
	RunSession.map_override = 1
	assert_bool(RunSave.is_boundary(RunSession.begin_new_run(31))).is_false()


func test_a_save_taken_mid_act_two_round_trips() -> void:
	var state: RunState = _run_at_act_end(32)
	RunNodes.advance_act(state)
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	for i in range(3):
		RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
		state.record_room({"index": state.room_index, "type": "combat", "wave_id": "a2_warmup"}, 18.0, 20.0)
		state.gold += 30
		RunNodes.open(state)
	assert_bool(RunSave.write(state)).is_true()
	var back: RunState = RunSave.read_state()
	assert_object(back).is_not_null()
	assert_bool(state.equals(back)).is_true()
	assert_int(back.act).is_equal(2)
	assert_int(back.path.size()).is_equal(3)
	assert_int(back.run_room_number()).is_equal(13)


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
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
	await _frames(2)


func _latest_main(except_id: int) -> Main:
	var found: Main = null
	for child in get_children():
		if child is Main and child.get_instance_id() != except_id and not child.is_queued_for_deletion():
			found = child as Main
	return found


func test_clearing_the_mini_boss_pays_relic_then_card_then_opens_act_two_and_saves_it() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)  # the act 1 mini-boss
	state.hp = 22.0
	state.max_hp = 30.0
	state.gold = 140
	var main: Main = _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("mini_boss")
	assert_int(controller.current_act()).is_equal(1)
	assert_int(controller.act_count()).is_equal(3)
	assert_int(controller.run_room_number()).is_equal(10)
	assert_int(controller.run_room_total()).is_equal(30)
	assert_str(controller.act_label()).is_equal("Act 1 of 3")
	assert_bool(controller.is_last_room()).is_true()
	var seen_acts: Array[int] = []
	controller.act_started.connect(func(act_number: int, _summary: Dictionary) -> void: seen_acts.append(act_number))
	var won: Array[bool] = [false]
	controller.run_won.connect(func() -> void: won[0] = true)
	await _win_room(main)
	assert_bool(won[0]).is_false()  # not the end of the run
	assert_int(state.gold).is_greater(140)  # the mini-boss paid gold
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(state.offer.size()).is_equal(3)
	controller.pick_relic(state.offer[0])
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)  # then the card offer
	assert_int(state.relics.size()).is_equal(1)
	var main_id: int = main.get_instance_id()
	var gold_after: int = state.gold
	controller.choose("skip")
	assert_array(seen_acts).is_equal([2])
	assert_int(state.act).is_equal(2)
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(state.path.is_empty()).is_true()
	assert_int(state.gold).is_equal(gold_after)
	assert_float(state.hp).is_equal(22.0)
	assert_int(controller.current_act()).is_equal(2)
	assert_int(controller.run_room_number()).is_equal(11)
	assert_str(controller.run_room_label()).is_equal("Room 11 of 30")
	var summary: Dictionary = controller.act_summary()
	assert_int(int(summary["act"])).is_equal(2)
	assert_int(int(summary["relic_count"])).is_equal(1)
	assert_int(int(summary["gold"])).is_equal(gold_after)
	assert_str(String(summary["title"])).is_equal("Act 2")
	assert_str(String(summary["line"])).contains("22 of 30").contains("%d gold" % gold_after).contains("relics: 1")
	var model: Dictionary = controller.current_choice()
	assert_int(int(model["act"])).is_equal(2)
	assert_int(int(model["run_room_total"])).is_equal(30)
	# the save at the act's start holds the same run: quit now and resume
	var saved: RunState = RunSave.read_state()
	assert_object(saved).is_not_null()
	assert_bool(saved.equals(state)).is_true()
	var expected_json: String = state.to_json()
	var expected_next: Array[int] = controller.reachable_nodes()
	RunSession.clear()
	main.queue_free()
	await _frames()
	assert_bool(RunSave.load_save()).is_true()
	assert_str(RunSession.current.to_json()).is_equal(expected_json)
	var resumed: Main = _spawn()
	await _frames()
	assert_array(resumed.run_controller.reachable_nodes()).is_equal(expected_next)
	assert_int(resumed.run_controller.current_act()).is_equal(2)
	# the first pick of act 2 loads a room that fights act 2's way
	var resumed_id: int = resumed.get_instance_id()
	resumed.run_controller.pick_node(expected_next[0])
	await _frames()
	var room: Main = _latest_main(resumed_id)
	assert_object(room).is_not_null()
	assert_int(room.run_controller.run_room_number()).is_equal(11)
	assert_float(float(room.enemy_spawner.act_scale["hp"])).is_equal(float(RunConfig.act_scale(2)["hp"]))
	assert_int(main_id).is_not_equal(room.get_instance_id())


func test_clearing_the_last_act_wins_the_run() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(33)
	state.jump_to_room(29)  # act 3, the boss
	assert_int(state.act).is_equal(3)
	var main: Main = _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("boss")
	var won: Array[bool] = [false]
	controller.run_won.connect(func() -> void: won[0] = true)
	controller._finish_room(0.0)
	assert_bool(won[0]).is_true()
	assert_str(state.outcome).is_equal("won")


func test_a_one_act_run_still_ends_at_the_boss() -> void:
	RunSession.map_override = 1
	RunSession.acts_override = 1
	var state: RunState = RunSession.begin_new_run(33)
	state.jump_to_room(9)
	var main: Main = _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("boss")
	assert_str(controller.act_label()).is_empty()
	assert_str(controller.run_room_label()).is_equal("Room 10 of 10")
	var won: Array[bool] = [false]
	controller.run_won.connect(func() -> void: won[0] = true)
	controller._finish_room(0.0)
	assert_bool(won[0]).is_true()


# ---- the launch flags and the capture presets ----

func test_the_acts_launch_flag_parses_and_refuses_bad_values() -> void:
	assert_int(int(MapLaunch.resolve_acts(PackedStringArray())["acts"])).is_equal(0)
	assert_int(int(MapLaunch.resolve_acts(PackedStringArray(["--acts=1"]))["acts"])).is_equal(1)
	assert_int(int(MapLaunch.resolve_acts(PackedStringArray(["--run-seed=3", "--acts=3"]))["acts"])).is_equal(3)
	for bad: String in ["--acts", "--acts=", "--acts=0", "--acts=-1", "--acts=10", "--acts=two", "--acts=1.5"]:
		var result: Dictionary = MapLaunch.resolve_acts(PackedStringArray([bad]))
		assert_array(result["errors"] as Array).override_failure_message(bad + " was accepted").is_not_empty()
		assert_int(int(result["acts"])).is_equal(0)
	assert_array(MapLaunch.resolve_acts(PackedStringArray(["--acts=1", "--acts=2"]))["errors"] as Array).is_not_empty()
	# a debug run never touches the player's save
	assert_bool(RunSave.args_suppress(PackedStringArray(["--acts=1"]))).is_true()


func test_map_run_capture_presets_pin_one_act_and_the_act_presets_do_not() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/capture_presets.json"))
	assert_int(typeof(parsed)).is_equal(TYPE_DICTIONARY)
	var presets: Dictionary = parsed
	for name: String in ["reward_screen", "boss_smash", "map_start", "map_mid", "map_room9", "map_chest_large", "map_chest_medium", "merchant_shop", "merchant_shop_poor", "merchant_removal"]:
		assert_bool((presets[name]["extra"] as Array).has("--acts=1")).override_failure_message(name + " lacks --acts=1").is_true()
	for name: String in ["mini_boss_act1", "final_boss_act3"]:
		assert_bool(presets.has(name)).is_true()
		assert_bool((presets[name]["extra"] as Array).has("--acts=1")).is_false()
	# the pinned one-act presets still put the boss at room 10; the act presets reach the mini-boss and the final boss
	assert_str(String(MapGraph.node(MapGenerator.generate(1, {}, {}, 1, 1), MapGraph.boss_id(MapGenerator.generate(1, {}, {}, 1, 1)))["type"])).is_equal("boss")
	RunSession.map_override = 1  # restored to -1 by after_test
	var run: RunState = RunSession.begin_new_run(1)
	run.jump_to_room(9)
	assert_str(String(RunNodes.current_node(run)["type"])).is_equal("mini_boss")
	run.jump_to_room(29)
	assert_str(String(RunNodes.current_node(run)["type"])).is_equal("boss")
