class_name M3cFollowupsTest
extends GdUnitTestSuite
## 3c follow-ups from 3b: RunState.from_dict rejects an unknown `pending`, and the choice model carries
## `owned`, `next_room_type` and (for card offers) the current contents of the offered card's slot.


func after_test() -> void:
	RunSession.clear()


func _base(extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"seed": 5, "room_index": 2, "hp": 20.0, "max_hp": 30.0, "deck": ["rogue_quick_slash"], "rejects_remaining": 3,
		"history": [{"index": 0, "type": "combat", "wave_id": "a", "hp_end": 20.0, "seconds": 5.0}, {"index": 1, "type": "combat", "wave_id": "b", "hp_end": 20.0, "seconds": 5.0}],
	}
	data.merge(extra, true)
	return data


func test_a_known_pending_value_loads_as_before() -> void:
	for value: String in [RunState.PENDING_NONE, RunState.PENDING_REST, RunState.PENDING_REST_REMOVE]:
		var state := RunState.from_dict(_base({"pending": value}))
		assert_object(state).is_not_null()
		assert_str(state.pending).is_equal(value)
		assert_int(state.room_index).is_equal(2)
	var reward := RunState.from_dict(_base({"pending": RunState.PENDING_REWARD, "offer": ["a", "b", "c"]}))
	assert_str(reward.pending).is_equal(RunState.PENDING_REWARD)
	assert_array(reward.offer).has_size(3)


func test_an_unknown_pending_falls_back_to_no_choice() -> void:
	for bad: Variant in ["bogus", "REWARD", "reward ", 5, 1.5, null, true, [], {}]:
		var state := RunState.from_dict(_base({"pending": bad, "offer": ["a"]}))
		assert_object(state).override_failure_message("rejected the whole save for %s" % str(bad)).is_not_null()
		assert_str(state.pending).override_failure_message("kept pending %s" % str(bad)).is_equal(RunState.PENDING_NONE)
		assert_bool(state.has_pending()).is_false()
		assert_array(state.offer).is_empty()


func test_a_dropped_choice_does_not_replay_a_won_room() -> void:
	# The history holds room index 2, so the room was won and recorded: moving on, not fighting it again.
	var data: Dictionary = _base({"pending": "bogus", "room_index": 1})
	var state := RunState.from_dict(data)
	assert_int(state.room_index).is_equal(2)
	assert_int(state.history.size()).is_equal(2)
	# A room that was never recorded keeps its index.
	var fresh := RunState.from_dict(_base({"pending": "bogus", "room_index": 2}))
	assert_int(fresh.room_index).is_equal(2)


func test_a_reward_with_no_offer_is_dropped_too() -> void:
	var state := RunState.from_dict(_base({"pending": RunState.PENDING_REWARD, "offer": []}))
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	var missing := RunState.from_dict(_base({"pending": RunState.PENDING_REWARD}))
	assert_str(missing.pending).is_equal(RunState.PENDING_NONE)


func test_a_non_array_offer_does_not_crash() -> void:
	var state := RunState.from_dict(_base({"pending": RunState.PENDING_REWARD, "offer": "nope"}))
	assert_object(state).is_not_null()
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)


func test_the_model_carries_owned_counts_and_next_room_type() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state := RunState.new_run(3, RunConfig.starting_deck(), 3)
	state.deck.append("rogue_quick_slash")
	state.pending = RunState.PENDING_REWARD
	state.offer = ["rogue_quick_slash", "fire_fireball"]
	var model: Dictionary = RunChoices.model(state, ctx)
	assert_bool(model.has("owned")).is_true()
	assert_bool(model.has("next_room_type")).is_true()
	assert_str(String(model["next_room_type"])).is_equal("")
	var owned: Dictionary = model["owned"]
	assert_int(int(owned["rogue_quick_slash"])).is_equal(2)
	assert_bool(owned.has("fire_fireball")).is_false()


func test_card_options_list_the_slot_contents_and_copies() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state := RunState.new_run(3, RunConfig.starting_deck(), 3)
	state.pending = RunState.PENDING_REWARD
	state.offer = ["rogue_quick_slash", "fire_fireball"]
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	var first: Dictionary = options[0]
	assert_int(int(first["owned"])).is_equal(1)
	var contents: Array = first["slot_contents"]
	assert_array(contents).contains(["Quick, I Guess", "Overhand, Whatever", "Ember, Whatever"])
	assert_int(contents.size()).is_equal(3)
	var second: Dictionary = options[1]
	assert_int(int(second["owned"])).is_equal(0)
	assert_int((second["slot_contents"] as Array).size()).is_equal(3)  # fireball is an aoe card: the three aoe starters
	# Every option always carries the keys, whatever its kind.
	for option: Dictionary in options:
		assert_bool(option.has("owned") and option.has("slot_contents")).is_true()


func test_the_controller_fills_next_room_type() -> void:
	var controller := RunController.new()
	auto_free(controller)
	assert_str(controller.next_room_type()).is_equal("")
