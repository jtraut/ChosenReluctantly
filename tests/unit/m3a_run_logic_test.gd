class_name M3aRunLogicTest
extends GdUnitTestSuite
## Milestone 3a, pure logic: run config validation, the seeded generator, RunState round-trip, tier maths,
## finite wave plans, and the Main run-mode switch. No scene needed.

const KNOWN_ENEMIES: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian"]


func _shipped() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RunConfig.PATH))


func _cards() -> Array[String]:
	var ids: Array[String] = []
	for card: Variant in CardDatabase.all_cards():
		ids.append(String((card as Dictionary)["id"]))
	return ids


func _problems(config: Dictionary) -> Array[String]:
	return RunConfig.validate(config, KNOWN_ENEMIES, _cards())


# ---- Config ----

func test_shipped_run_json_is_valid() -> void:
	assert_array(_problems(_shipped())).is_empty()
	assert_array(CharacterDatabase.validate_shipped()).is_empty()
	assert_bool(RunConfig.is_valid()).is_true()


func test_shipped_starting_deck_is_the_15_card_starter_with_3_per_slot() -> void:
	# 3b: the starter shrank from the full pool; the full pool is the --full-deck debug deck.
	var deck: Array[String] = RunConfig.starting_deck()
	assert_int(deck.size()).is_equal(15)
	var per_slot: Dictionary = {}
	for card_id: String in deck:
		assert_bool(CardDatabase.has_card(card_id)).is_true()
		var slot_type: String = String(CardDatabase.get_card(card_id)["slot_type"])
		per_slot[slot_type] = int(per_slot.get(slot_type, 0)) + 1
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		assert_int(int(per_slot.get(slot_type, 0))).is_equal(3)


func test_shipped_numbers_match_the_brief() -> void:
	var config := _shipped()
	assert_int(int(config["rejects_per_run"])).is_equal(3)
	assert_float(float(config["rest_heal_fraction"])).is_equal(0.3)
	var comp: Dictionary = config["composition"]
	assert_int(int(comp["combat"])).is_equal(5)
	assert_int(int(comp["elite"])).is_equal(1)
	assert_int(int(comp["rest"])).is_equal(1)
	assert_int(int(comp["boss"])).is_equal(1)
	assert_float(float(config["tiers"]["elite"]["resistance_floor"])).is_equal(0.25)
	assert_float(float(config["tiers"]["elite"]["resistance_cap"])).is_equal(0.5)


func test_validation_rejects_bad_data() -> void:
	var cases: Array[Dictionary] = [
		{"path": ["composition", "boss"], "value": 2},
		{"path": ["composition", "combat"], "value": -1},
		{"path": ["composition", "ghost"], "value": 1},
		{"path": ["placement", "ranges", "elite"], "value": [3, 7]},
		{"path": ["placement", "ranges", "elite"], "value": [5, 3]},
		{"path": ["placement", "ranges", "rest"], "value": "x"},
		{"path": ["placement", "boss_last"], "value": false},
		{"path": ["rest_heal_fraction"], "value": 1.5},
		{"path": ["rejects_per_run"], "value": -1},
		{"path": ["tiers", "elite", "hp_multiplier"], "value": 0.5},
		{"path": ["tiers", "elite", "resistance_floor"], "value": 0.9},
		{"path": ["tiers", "boss", "rank"], "value": "king"},
		{"path": ["tiers", "boss", "marker_color"], "value": "nope"},
		{"path": ["rooms", "combat"], "value": []},
		{"path": ["ui", "room_label"], "value": "Room"},
	]
	for c: Dictionary in cases:
		var config := _shipped()
		var node: Dictionary = config
		var path: Array = c["path"]
		for i in range(path.size() - 1):
			node = node[path[i]]
		node[path[path.size() - 1]] = c["value"]
		assert_array(_problems(config)).override_failure_message("expected a problem for %s" % str(c)).is_not_empty()


func test_validation_checks_the_wave_lists_with_the_shared_schema() -> void:
	var config := _shipped()
	config["rooms"]["combat"][0]["stages"][0]["spawns"][0]["enemy"] = "ghost_enemy"
	assert_array(_problems(config)).is_not_empty()
	config = _shipped()
	config["rooms"]["combat"][0]["stages"][0]["spawns"][0]["count"] = 30  # more than max_alive: could never finish
	assert_array(_problems(config)).is_not_empty()
	config = _shipped()
	config["rooms"]["elite"][0]["stages"][1]["spawns"][0]["tier"] = "emperor"
	assert_array(_problems(config)).is_not_empty()
	config = _shipped()
	config["rooms"]["combat"][1]["id"] = config["rooms"]["combat"][0]["id"]
	assert_array(_problems(config)).is_not_empty()


func test_validation_requires_a_wave_list_for_every_room_index() -> void:
	var config := _shipped()
	for variant: Dictionary in config["rooms"]["combat"]:
		variant["min_index"] = 7  # nothing allows indices 0-6 now
	assert_array(_problems(config)).is_not_empty()


# ---- Generator ----

func test_same_seed_same_sequence() -> void:
	var config := _shipped()
	for seed_value in [1, 2, 99, 123456789]:
		assert_array(RunGenerator.generate(seed_value, config)).is_equal(RunGenerator.generate(seed_value, config))


func test_every_seed_follows_the_rules() -> void:
	var config := _shipped()
	var ranges: Dictionary = config["placement"]["ranges"]
	for seed_value in range(1, 400):
		var rooms := RunGenerator.generate(seed_value, config)
		assert_int(rooms.size()).is_equal(8)
		var counts: Dictionary = {"combat": 0, "elite": 0, "rest": 0, "boss": 0}
		for room: Dictionary in rooms:
			counts[room["type"]] = int(counts[room["type"]]) + 1
			var index: int = room["index"]
			if room["type"] == "rest":
				assert_str(room["wave_id"]).is_empty()
			else:
				var variant := RunConfig.variant_by_id(config, room["type"], room["wave_id"])
				assert_bool(variant.is_empty()).is_false()
				assert_bool(index >= int(variant.get("min_index", 0)) and index <= int(variant.get("max_index", 99))).is_true()
			if room["type"] == "elite" or room["type"] == "rest":
				var window: Array = ranges[room["type"]]
				assert_bool(index >= int(window[0]) and index <= int(window[1])).is_true()
		assert_int(counts["combat"]).is_equal(5)
		assert_int(counts["elite"]).is_equal(1)
		assert_int(counts["rest"]).is_equal(1)
		assert_int(counts["boss"]).is_equal(1)
		assert_str(rooms[7]["type"]).is_equal("boss")
		assert_str(rooms[0]["type"]).is_equal("combat")


func test_different_seeds_give_different_sequences() -> void:
	var config := _shipped()
	var seen: Dictionary = {}
	for seed_value in range(1, 60):
		seen[str(RunGenerator.generate(seed_value, config))] = true
	assert_int(seen.size()).is_greater(10)


# ---- RunState ----

func test_run_state_round_trips_through_json() -> void:
	var state := RunState.new_run(2147000000, RunConfig.starting_deck(), 3)
	state.room_index = 4
	state.hp = 37.5
	state.max_hp = 100.0
	state.record_room({"index": 0, "type": "combat", "wave_id": "combat_intro"}, 80.25, 31.5)
	state.record_room({"index": 1, "type": "rest", "wave_id": ""}, 90.0, 0.0)
	var copy: RunState = RunState.from_json(state.to_json())
	assert_object(copy).is_not_null()
	assert_bool(state.equals(copy)).is_true()
	assert_int(copy.seed_value).is_equal(2147000000)
	assert_int(copy.room_index).is_equal(4)
	assert_float(copy.hp).is_equal(37.5)
	assert_array(copy.deck).is_equal(state.deck)
	assert_int(copy.rejects_remaining).is_equal(3)
	assert_int(copy.history.size()).is_equal(2)
	assert_str(copy.history[0]["wave_id"]).is_equal("combat_intro")


func test_new_run_takes_deck_and_rejects_from_data_and_masks_the_seed() -> void:
	var state := RunState.new_run(-1, RunConfig.starting_deck(), RunConfig.rejects_per_run())
	assert_int(state.rejects_remaining).is_equal(3)
	assert_array(state.deck).is_equal(RunConfig.starting_deck())
	assert_int(state.seed_value).is_between(0, RunState.SEED_LIMIT)
	assert_bool(state.has_hp()).is_false()
	assert_bool(state.is_over()).is_false()


func test_run_state_deck_is_a_copy() -> void:
	var deck := RunConfig.starting_deck()
	var state := RunState.new_run(5, deck, 3)
	deck.clear()
	assert_int(state.deck.size()).is_greater(0)


func test_begin_new_run_gives_a_fresh_state_and_consumes_a_forced_seed() -> void:
	RunSession.clear()
	RunSession.forced_seed = 777
	var first := RunSession.begin_new_run()
	assert_int(first.seed_value).is_equal(777)
	first.room_index = 5
	first.rejects_remaining = 0
	var second := RunSession.begin_new_run()
	assert_object(second).is_not_same(first)
	assert_int(second.room_index).is_equal(0)
	assert_int(second.rejects_remaining).is_equal(3)
	assert_bool(second.seed_value == 777).is_false()  # a forced seed is used once
	RunSession.clear()


# ---- Tiers ----

func test_elite_resistance_is_max_of_own_and_floor_capped() -> void:
	assert_float(TierRules.resistance(0.0, 0.25, 0.5)).is_equal(0.25)
	assert_float(TierRules.resistance(0.4, 0.25, 0.5)).is_equal(0.4)
	assert_float(TierRules.resistance(0.8, 0.25, 0.5)).is_equal(0.5)
	assert_float(TierRules.resistance(0.5, 0.25, 0.5)).is_equal(0.5)


func test_tier_resistances_cover_every_element_and_keep_unknown_keys() -> void:
	var table := TierRules.resistances({"fire": 0.5, "mystery": 0.9}, TierRules.element_ids(), 0.25, 0.5)
	assert_float(float(table["fire"])).is_equal(0.5)
	assert_float(float(table["mystery"])).is_equal(0.9)
	assert_array(TierRules.element_ids()).contains(["fire"])


# ---- Finite waves ----

func _finite_config() -> Dictionary:
	var config: Dictionary = WaveConfig.get_config().duplicate(true)
	config["stages"] = [
		{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 2}]},
		{"delay": 1.0, "spawns": [{"enemy": "fire_resistant_golem", "count": 1, "tier": "elite"}]},
	]
	config["first_wave_delay"] = 0.0
	config["finite"] = true
	return config


func test_finite_plan_spawns_everything_once_then_finishes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var plan := WavePlan.new(_finite_config(), rng)
	var spawned: Array[String] = []
	for i in range(400):
		var queued := plan.step_one(0.05, 0)
		if queued != "":
			spawned.append(queued)
	assert_array(spawned).has_size(3)
	assert_bool(plan.is_finished()).is_true()
	assert_int(plan.stages_started()).is_equal(2)
	assert_array(spawned.filter(func(q: String) -> bool: return q == "elite|fire_resistant_golem")).has_size(1)
	assert_str(WavePlan.decode("elite|fire_resistant_golem")["enemy"]).is_equal("fire_resistant_golem")
	assert_str(WavePlan.decode("elite|fire_resistant_golem")["tier"]).is_equal("elite")
	assert_str(WavePlan.decode("melee_chaser")["tier"]).is_equal("")


func test_endless_plan_never_finishes() -> void:
	var rng := RandomNumberGenerator.new()
	var plan := WavePlan.new(WaveConfig.get_config(), rng)
	for i in range(4000):
		plan.step_one(0.05, 0)
	assert_bool(plan.is_finished()).is_false()


# ---- Run-mode switch ----

func test_run_mode_switch() -> void:
	assert_bool(Main.uses_run_mode(true, PackedStringArray())).is_true()
	assert_bool(Main.uses_run_mode(false, PackedStringArray())).is_false()
	assert_bool(Main.uses_run_mode(true, PackedStringArray(["--scenario=hp_bars"]))).is_false()
	assert_bool(Main.uses_run_mode(true, PackedStringArray(["--screenshot-after=2", "--run-seed=5"]))).is_true()
	assert_bool(Main.uses_run_mode(false, PackedStringArray(["--scenario=hp_bars"]))).is_false()
