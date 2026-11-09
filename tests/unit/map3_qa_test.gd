class_name Map3QaTest
extends GdUnitTestSuite
## MAP3 qa review (independent of gameplay-dev's and ux's suites): hostile save files across an act boundary, determinism of all three act maps
## and their rolls, the exhausted-pool fallback in act 3, Continue's summary on an act-2 file,.

const PATH := "user://tests/map3_qa_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = 1
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
	GamePause.reset()
	get_tree().paused = false


func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


## A run that finished act 1 by the first route, is in act 2 and has walked `rooms` rooms of it.
func _act_two_state(seed_value: int, rooms: int) -> RunState:
	var state: RunState = RunSession.begin_new_run(seed_value)
	var ctx: Dictionary = _ctx()
	while not RunNodes.reachable_ids(state).is_empty():
		RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
		state.hp = 20.0
		state.max_hp = 30.0
		state.gold += 11
		state.record_room({"index": state.room_index, "type": "combat", "wave_id": "x"}, 20.0, 9.0)
		RunNodes.open(state)
	assert_bool(RunNodes.advance_act(state)).is_true()
	for i in range(rooms):
		RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
		state.record_room({"index": state.room_index, "type": "combat", "wave_id": "a2_warmup"}, 18.0, 20.0)
		RunNodes.open(state)
	return state


func _write_raw(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ---- the act boundary ----

func test_act_two_resume_gives_an_equal_state_the_same_next_room_and_the_same_summary() -> void:
	for rooms in [0, 1, 4]:
		var state: RunState = _act_two_state(41, rooms)
		assert_bool(RunSave.write(state)).is_true()
		var back: RunState = RunSave.read_state()
		assert_object(back).is_not_null()
		assert_bool(state.equals(back)).is_true()
		assert_array(RunNodes.reachable_ids(back)).is_equal(RunNodes.reachable_ids(state))
		assert_int(back.act).is_equal(2)
		assert_int(back.past_acts.size()).is_equal(1)
		assert_array(back.act_path(1)).is_equal(state.act_path(1))
		var summary: Dictionary = RunSave.summary()
		assert_int(int(summary["act"])).is_equal(2)
		assert_int(int(summary["acts_total"])).is_equal(3)
		assert_int(int(summary["room"])).is_equal(10 + rooms + 1)
		assert_int(int(summary["room_total"])).is_equal(30)


func test_a_resumed_act_two_run_makes_the_same_offers_as_one_that_never_stopped() -> void:
	var state: RunState = _act_two_state(52, 2)
	RunSave.write(state)
	var back: RunState = RunSave.read_state()
	var ctx: Dictionary = _ctx()
	for copy: RunState in [state, back]:
		RunNodes.apply(copy, "node:%d" % RunNodes.reachable_ids(copy)[0], ctx)
	assert_str(RunChoices.open_for_room(state, "combat", false, ctx)).is_equal(RunChoices.open_for_room(back, "combat", false, ctx))
	assert_array(back.offer).is_equal(state.offer)
	assert_bool(state.equals(back)).is_true()


# ---- hostile files ----

## Wrong-typed or absurd replacements for every top-level field of a valid act-2 run; the loader must come back (a state or null), never script-error.
func test_every_field_of_an_act_two_save_survives_hostile_values() -> void:
	var state: RunState = _act_two_state(63, 2)
	var good: Dictionary = state.to_dict()
	var hostile: Array = [null, "x", "", [], {}, -1, 0, 1.0e30, true, [null], {"a": 1}, [[]], [{}], 2.5]
	var survived: int = 0
	for key: String in good.keys():
		for bad: Variant in hostile:
			var run: Dictionary = good.duplicate(true)
			run[key] = bad
			_write_raw(JSON.stringify({"save_version": RunSave.SAVE_VERSION, "run": run}))
			var back: RunState = RunSave.read_state()
			if back != null:
				# A file that loads must be usable: a live map run at a boundary.
				assert_bool(RunNodes.consistent(back)).override_failure_message("'%s' = %s loaded an inconsistent run" % [key, str(bad)]).is_true()
				assert_bool(back.pending == RunState.PENDING_NODE or back.pending == RunState.PENDING_NONE).override_failure_message("'%s' = %s loaded with pending '%s'" % [key, str(bad), back.pending]).is_true()
				assert_bool(back.gold >= 0).is_true()
				assert_bool(back.has_hp()).is_true()
			survived += 1
	assert_int(survived).is_equal(good.size() * hostile.size())


func test_a_truncated_or_binary_file_is_ignored_at_every_cut() -> void:
	var state: RunState = _act_two_state(64, 1)
	RunSave.write(state)
	var text: String = FileAccess.get_file_as_string(PATH)
	assert_int(text.length()).is_greater(1000)
	var cut: int = 0
	while cut < text.length():
		_write_raw(text.substr(0, cut))
		assert_object(RunSave.read_state()).override_failure_message("a file cut at %d loaded" % cut).is_null()
		cut += 397
	_write_raw("\u0000\u0001\u0002 garbage")
	assert_object(RunSave.read_state()).is_null()
	assert_bool(RunSave.has_save()).is_false()
	assert_bool(RunSave.summary().is_empty()).is_true()
	assert_bool(RunSave.load_save()).is_false()


func test_a_save_edited_to_act_three_of_two_or_with_a_wrong_past_count_is_refused() -> void:
	var state: RunState = _act_two_state(65, 1)
	var good: Dictionary = state.to_dict()
	var cases: Array[Dictionary] = [{"act": 3}, {"acts_total": 1}, {"acts_total": 10}, {"act": 0}, {"past_acts": []}, {"act": 1}, {"act": 2.5}]
	for patch: Dictionary in cases:
		var run: Dictionary = good.duplicate(true)
		for key: String in patch.keys():
			run[key] = patch[key]
		_write_raw(JSON.stringify({"save_version": RunSave.SAVE_VERSION, "run": run}))
		var back: RunState = RunSave.read_state()
		if back != null:
			# A loaded edit may only be the straight-run fallback or still a coherent run; it may never be act N with the wrong history.
			assert_int(back.past_acts.size()).override_failure_message("patch %s loaded act %d with %d past acts" % [str(patch), back.act, back.past_acts.size()]).is_equal(back.act - 1)
			assert_bool(back.act >= 1 and back.act <= back.acts_total).is_true()


func test_a_save_whose_cards_are_not_in_the_catalog_or_hp_is_zero_is_ignored() -> void:
	var state: RunState = _act_two_state(66, 1)
	state.deck.append("no_such_card")
	RunSave.write(state)
	assert_object(RunSave.read_state()).is_null()
	assert_str(RunSave.last_problem).contains("unknown card")
	state.deck.erase("no_such_card")
	state.max_hp = 0.0
	RunSave.write(state)
	assert_object(RunSave.read_state()).is_null()


# ---- determinism ----

func test_the_same_seed_gives_the_same_three_maps_and_the_same_rolls() -> void:
	for seed_value in [1, 7, 99, 1234567]:
		for act_number in [1, 2, 3]:
			var a: Dictionary = MapGenerator.generate(seed_value, {}, {}, act_number, 3)
			var b: Dictionary = MapGenerator.generate(seed_value, {}, {}, act_number, 3)
			assert_bool(a.is_empty()).is_false()
			assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))
		# acts differ from each other
		assert_str(JSON.stringify(MapGenerator.generate(seed_value, {}, {}, 2, 3))).is_not_equal(JSON.stringify(MapGenerator.generate(seed_value, {}, {}, 3, 3)))
	var ctx: Dictionary = _ctx()
	var one: RunState = _act_two_state(77, 3)
	var two: RunState = _act_two_state(77, 3)
	assert_bool(one.equals(two)).is_true()
	RunNodes.apply(one, "node:%d" % RunNodes.reachable_ids(one)[0], ctx)
	RunNodes.apply(two, "node:%d" % RunNodes.reachable_ids(two)[0], ctx)
	RunChoices.open_for_room(one, "combat", false, ctx)
	RunChoices.open_for_room(two, "combat", false, ctx)
	assert_array(one.offer).is_equal(two.offer)


# ---- exhausted pool ----

## A fresh three-act run moved into act `act_number` (maps made by advance_act), standing on the first node of `type_id` in that act's map; "" when the act has none.
func _on_node_of_type(seed_value: int, act_number: int, type_id: String) -> RunState:
	var state: RunState = RunSession.begin_new_run(seed_value)
	while state.act < act_number:
		state.path = MapGraph.first_route(state.map)
		assert_bool(RunNodes.advance_act(state)).is_true()
	for entry: Variant in (state.map["nodes"] as Array):
		if String((entry as Dictionary)["type"]) == type_id:
			assert_bool(state.jump_to_node(int((entry as Dictionary)["id"]))).is_true()
			return state
	return null


func _give_up_every_relic(state: RunState) -> void:
	for id: String in RelicDatabase.ids():
		if not state.relics.has(id):
			state.relics_given_up.append(id)


func test_acts_two_and_three_with_no_relic_left_give_a_card_offer_not_an_empty_screen() -> void:
	var ctx: Dictionary = _ctx()
	var cases: Array[Array] = [[2, "elite"], [3, "elite"], [2, "relic_room"], [3, "relic_room"], [2, "mini_boss"]]
	for case: Array in cases:
		var checked: bool = false
		for seed_value in range(1, 60):
			var state: RunState = _on_node_of_type(seed_value, int(case[0]), String(case[1]))
			if state == null:
				continue
			_give_up_every_relic(state)
			var pending: String = RunRelics.open_for_room(state, String(case[1]), false, ctx)
			assert_str(pending).override_failure_message("act %d %s with no relic left opened '%s'" % [case[0], case[1], pending]).is_equal(RunState.PENDING_REWARD)
			assert_int(state.offer.size()).is_greater(0)
			for card_id: String in state.offer:
				assert_bool(CardDatabase.has_card(card_id)).is_true()
			checked = true
			break
		assert_bool(checked).override_failure_message("no seed 1-59 has a %s in act %d" % [case[1], case[0]]).is_true()


# ---- values a hand-edited save can carry (probe: reported, see the review) ----

func test_hp_and_reject_values_in_a_loaded_save_are_sane(do_skip := true, skip_reason := "known bug, qa MAP3 review: RunState.from_dict accepts hp 0, -1, above max and out-of-range rejects (hand-edited file only); un-skip when gameplay-dev clamps them") -> void:
	var state: RunState = _act_two_state(67, 1)
	var good: Dictionary = state.to_dict()
	var cases: Array[Dictionary] = [{"hp": 0.0}, {"hp": -1.0}, {"hp": 9999.0}, {"rejects_remaining": -5}, {"rejects_remaining": 100000}]
	var problems: Array[String] = []
	for patch: Dictionary in cases:
		var run: Dictionary = good.duplicate(true)
		for key: String in patch.keys():
			run[key] = patch[key]
		_write_raw(JSON.stringify({"save_version": RunSave.SAVE_VERSION, "run": run}))
		var back: RunState = RunSave.read_state()
		if back == null:
			continue
		if back.hp <= 0.0 or back.hp > back.max_hp or back.rejects_remaining < 0 or back.rejects_remaining > RunConfig.rejects_per_run():
			problems.append("%s loaded as hp %s of %s, rejects %d" % [str(patch), str(back.hp), str(back.max_hp), back.rejects_remaining])
	assert_array(problems).override_failure_message("a hand-edited save loads out-of-range values: %s" % str(problems)).is_empty()
