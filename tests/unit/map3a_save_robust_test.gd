class_name Map3aSaveRobustTest
extends GdUnitTestSuite
## MAP3 sitting A, step 1: RunState.from_dict must refuse or repair damaged saves without a script error, and BossConfig.validate must report
## (not crash on) a non-object boss attack.

const KNOWN_ENEMIES: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian", "boss_brute", "boss_duelist"]


func before_test() -> void:
	RunSession.clear()
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.clear()


func _plain() -> Dictionary:
	var state: RunState = RunState.new_run(11, ["rogue_quick_slash"] as Array[String], 3)
	state.hp = 20.0
	state.max_hp = 30.0
	return JSON.parse_string(JSON.stringify(state.to_dict())) as Dictionary


func test_wrongly_typed_offer_entries_are_dropped_without_a_crash() -> void:
	for bad: Variant in [null, [1, 2], {"a": 1}, 5, true, ""]:
		var data: Dictionary = _plain()
		data["pending"] = RunState.PENDING_REWARD
		data["offer"] = ["rogue_quick_slash", bad]
		var loaded: RunState = RunState.from_dict(data)
		assert_object(loaded).is_not_null()
		assert_array(loaded.offer).is_equal(["rogue_quick_slash"])


func test_an_offer_that_is_not_an_array_leaves_no_open_reward() -> void:
	for bad: Variant in ["card", {"x": 1}, 7, null]:
		var data: Dictionary = _plain()
		data["pending"] = RunState.PENDING_REWARD
		data["offer"] = bad
		var loaded: RunState = RunState.from_dict(data)
		assert_object(loaded).is_not_null()
		assert_str(loaded.pending).is_equal(RunState.PENDING_NONE)
		assert_array(loaded.offer).is_empty()


func test_a_stale_offer_with_no_pending_choice_is_cleared() -> void:
	var data: Dictionary = _plain()
	data["pending"] = ""
	data["offer"] = ["rogue_quick_slash"]
	assert_array(RunState.from_dict(data).offer).is_empty()


func test_wrongly_typed_deck_or_choice_log_entries_are_refused_not_crashed_on() -> void:
	for bad: Variant in [null, [1], {"a": 1}, 5]:
		var deck_data: Dictionary = _plain()
		deck_data["deck"] = ["rogue_quick_slash", bad]
		assert_object(RunState.from_dict(deck_data)).is_null()
		var log_data: Dictionary = _plain()
		log_data["choice_log"] = [bad]
		if typeof(bad) == TYPE_DICTIONARY:
			assert_object(RunState.from_dict(log_data)).is_not_null()  # an object entry loads, with defaults
		else:
			assert_object(RunState.from_dict(log_data)).is_null()
	for bad: Variant in ["x", 5, null, {"a": 1}]:
		var data: Dictionary = _plain()
		data["choice_log"] = bad
		assert_object(RunState.from_dict(data)).is_null()


func test_choice_log_and_history_fields_of_the_wrong_type_become_defaults() -> void:
	var data: Dictionary = _plain()
	data["choice_log"] = [{"index": [1], "kind": {"a": 1}, "card_id": null, "amount": "x"}]
	data["history"] = [{"index": null, "type": [1], "wave_id": 5, "hp_end": "x", "seconds": {}}]
	var loaded: RunState = RunState.from_dict(data)
	assert_object(loaded).is_not_null()
	assert_str(String((loaded.choice_log[0] as Dictionary)["kind"])).is_equal("")
	assert_int(int((loaded.history[0] as Dictionary)["index"])).is_equal(0)


func test_scalars_of_the_wrong_type_are_refused() -> void:
	for key: String in ["seed", "room_index", "hp", "max_hp", "rejects_remaining"]:
		for bad: Variant in [null, "x", [1], {"a": 1}]:
			var data: Dictionary = _plain()
			data[key] = bad
			assert_object(RunState.from_dict(data)).override_failure_message("%s = %s loaded" % [key, str(bad)]).is_null()
	var data: Dictionary = _plain()
	data["outcome"] = ["won"]
	assert_object(RunState.from_dict(data)).is_null()


func test_negative_gold_is_clamped() -> void:
	var data: Dictionary = _plain()
	data["gold"] = -50
	data["xp_earned"] = -3
	var loaded: RunState = RunState.from_dict(data)
	assert_int(loaded.gold).is_equal(0)
	assert_int(loaded.xp_earned).is_equal(0)


func test_a_relic_both_held_and_given_up_is_refused() -> void:
	var data: Dictionary = _plain()
	data["relics"] = ["heavy_sigh"]
	data["relics_given_up"] = ["heavy_sigh"]
	assert_object(RunState.from_dict(data)).is_null()


func test_relics_over_the_cap_are_refused() -> void:
	var ids: Array = RelicDatabase.ids()
	var data: Dictionary = _plain()
	var many: Array = []
	for i in range(RelicConfig.max_owned() + 1):
		many.append(ids[i % ids.size()] if i < ids.size() else "x%d" % i)
	data["relics"] = many
	assert_object(RunState.from_dict(data)).is_null()


func test_unknown_relic_ids_are_refused() -> void:
	var data: Dictionary = _plain()
	data["relics"] = ["no_such_relic"]
	assert_object(RunState.from_dict(data)).is_null()
	var given: Dictionary = _plain()
	given["relics_given_up"] = ["no_such_relic"]
	assert_object(RunState.from_dict(given)).is_null()


func test_a_good_relic_state_still_round_trips() -> void:
	var state: RunState = RunState.new_run(3, ["rogue_quick_slash"] as Array[String], 3)
	state.add_relic("heavy_sigh")
	state.add_relic("pyre_insurance")
	state.give_up_relic("pyre_insurance")
	assert_bool(state.equals(RunState.from_json(state.to_json()))).is_true()


func test_a_node_pick_whose_map_fails_to_normalize_is_dropped() -> void:
	RunSession.map_override = 1
	var fresh: RunState = RunSession.begin_new_run(9)
	RunSession.map_override = -1
	assert_str(fresh.pending).is_equal(RunState.PENDING_NODE)
	var data: Dictionary = JSON.parse_string(fresh.to_json()) as Dictionary
	data["map"] = {"nodes": "x", "edges": []}
	var loaded: RunState = RunState.from_dict(data)
	assert_object(loaded).is_not_null()
	assert_bool(loaded.map.is_empty()).is_true()
	assert_str(loaded.pending).is_equal(RunState.PENDING_NONE)


func test_boss_config_reports_a_non_object_attack_instead_of_crashing() -> void:
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH)) as Dictionary
	assert_array(BossConfig.validate(shipped, KNOWN_ENEMIES)).is_empty()
	var attacks: Dictionary = ((shipped["bosses"] as Dictionary)["boss_guardian"] as Dictionary)["attacks"]
	var first_id: String = String(attacks.keys()[0])
	attacks[first_id] = "hit"
	var problems: Array[String] = BossConfig.validate(shipped, KNOWN_ENEMIES)
	assert_array(problems).is_not_empty()
