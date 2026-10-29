class_name M3bQaTest
extends GdUnitTestSuite
## qa adversarial tests for Milestone 3b: try to break the removal guard (fuzzed decks, duplicates, last copies),
## the reject cap, offer invariants over many seeds, real key events through the viewport during the arm delay,
## pause, a disabled option, and an audit that the forced continue is only used by tests and the soak tool.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	RunSession.clear()


func after_test() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	Juice.reset()
	GamePause.reset()


func _ctx() -> Dictionary:
	return RunChoices.shipped_context(["rogue", "fire", "neutral"])


func _all_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in CardDatabase.all_cards():
		ids.append(String(card["id"]))
	return ids


func _deck_ok(deck: Array, ctx: Dictionary) -> bool:
	return DeckRules.check(deck, ctx["deck_rules"], ctx["slot_of"], ctx["known_slots"], ctx["slot_names"]).is_ok()


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


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)


# ---- The removal guard: no sequence breaks a minimum ----

func test_fuzzed_decks_never_lose_a_minimum_through_any_removal_attempt() -> void:
	var ctx := _ctx()
	var all := _all_ids()
	var starter: Array[String] = RunConfig.starting_deck()
	assert_bool(_deck_ok(starter, ctx)).is_true()
	for seed_value in range(300):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 9000
		var state := RunState.new()
		state.deck = starter.duplicate()
		# Grow the deck with random picks (duplicates and new uniques), as rewards would.
		for i in range(rng.randi_range(0, 25)):
			state.deck.append(all[rng.randi() % all.size()])
		assert_bool(_deck_ok(state.deck, ctx)).is_true()
		state.pending = RunState.PENDING_REST_REMOVE
		var guard := 0
		while guard < 60:
			guard += 1
			var changed := false
			# Try EVERY listed option, enabled or not, in random order, plus ids that are not in the deck.
			var ids: Array[String] = []
			for o: Dictionary in RunChoices.options(state, ctx):
				ids.append(String(o["id"]))
			ids.append("remove:no_such_card")
			ids.append("remove:" + all[rng.randi() % all.size()])
			for i in range(ids.size()):
				var j := rng.randi() % ids.size()
				var t := ids[i]
				ids[i] = ids[j]
				ids[j] = t
			for id in ids:
				state.pending = RunState.PENDING_REST_REMOVE
				var before := state.deck.duplicate()
				var r := RunChoices.apply(state, id, ctx)
				if bool(r["ok"]) and id.begins_with("remove:"):
					changed = true
					assert_int(state.deck.size()).is_equal(before.size() - 1)
				elif not bool(r["ok"]):
					assert_array(state.deck).is_equal(before)
				if not _deck_ok(state.deck, ctx):
					fail("seed %d: removal '%s' broke a deck minimum; deck now %s" % [seed_value, id, str(state.deck)])
					return
				if state.deck.size() < 15:
					fail("seed %d: deck shrank below the starter size" % seed_value)
					return
				if changed:
					break
			if not changed:
				break
		# End state: every unique card still present is protected or has a spare copy.
		assert_bool(_deck_ok(state.deck, ctx)).is_true()


func test_removing_the_last_copy_of_a_needed_card_is_refused_but_a_spare_copy_goes() -> void:
	var ctx := _ctx()
	var state := RunState.new()
	state.deck = RunConfig.starting_deck()
	var card_id := "rogue_quick_slash"
	state.deck.append(card_id)  # now two copies
	state.pending = RunState.PENDING_REST_REMOVE
	assert_bool(RunChoices.apply(state, "remove:" + card_id, ctx)["ok"]).is_true()
	assert_int(state.deck.count(card_id)).is_equal(1)
	state.pending = RunState.PENDING_REST_REMOVE
	var refused := RunChoices.apply(state, "remove:" + card_id, ctx)
	assert_bool(refused["ok"]).is_false()
	assert_str(String(refused["reason"])).is_not_empty()
	assert_int(state.deck.count(card_id)).is_equal(1)
	assert_int(state.deck.size()).is_equal(15)


func test_remove_ids_are_refused_outside_the_removal_list() -> void:
	var ctx := _ctx()
	var state := RunState.new()
	state.deck = RunConfig.starting_deck()
	state.deck.append("rogue_quick_slash")
	for pending in [RunState.PENDING_REST, RunState.PENDING_REWARD, RunState.PENDING_NONE]:
		state.pending = pending
		state.offer.clear()
		if pending == RunState.PENDING_REWARD:
			state.offer.append("neutral_regeneration")
		var r := RunChoices.apply(state, "remove:rogue_quick_slash", ctx)
		assert_bool(r["ok"]).is_false()
		assert_int(state.deck.size()).is_equal(16)


func test_a_removal_for_a_card_not_in_the_deck_changes_nothing() -> void:
	var ctx := _ctx()
	var state := RunState.new()
	state.deck = RunConfig.starting_deck()
	state.pending = RunState.PENDING_REST_REMOVE
	var r := RunChoices.apply(state, "remove:fire_fireball", ctx)
	assert_bool(r["ok"]).is_false()
	assert_int(state.deck.size()).is_equal(15)


# ---- Reject cap ----

func test_rejects_never_go_below_zero_and_a_reject_at_zero_changes_nothing() -> void:
	var ctx := _ctx()
	var state := RunSession.begin_new_run(5)
	for i in range(5):
		state.pending = RunState.PENDING_REWARD
		state.offer.clear()
		state.offer.append_array(["neutral_regeneration", "fire_fireball", "rogue_nap_time"])
		var before_deck := state.deck.duplicate()
		var r := RunChoices.apply(state, "skip", ctx)
		if i < 3:
			assert_bool(r["ok"]).is_true()
			assert_array(state.deck).is_equal(before_deck)
		else:
			assert_bool(r["ok"]).is_false()
			assert_str(String(r["reason"])).is_not_empty()
			assert_bool(state.has_pending()).is_true()
		assert_int(state.rejects_remaining).is_equal(maxi(2 - i, 0))
	# A hand-edited negative count still counts as none left.
	state.rejects_remaining = -4
	state.pending = RunState.PENDING_REWARD
	assert_bool(RunChoices.apply(state, "skip", ctx)["ok"]).is_false()
	assert_int(state.rejects_remaining).is_equal(-4)


# ---- Offers over many seeds ----

func test_shipped_offers_are_distinct_in_pool_deterministic_and_prefer_unowned() -> void:
	var ctx := _ctx()
	var starter: Array[String] = RunConfig.starting_deck()
	var by_id: Dictionary = ctx["by_id"]
	var first_unowned := 0
	var total := 0
	for run_seed in range(1, 201):
		for room in range(0, 7):
			var a: Array[String] = RewardOffer.generate(run_seed, room, starter, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
			var b: Array[String] = RewardOffer.generate(run_seed, room, starter, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
			assert_array(a).is_equal(b)
			assert_int(a.size()).is_equal(3)
			var seen: Dictionary = {}
			for id in a:
				assert_bool(seen.has(id)).is_false()
				seen[id] = true
				assert_bool((ctx["pools"] as Array).has(String((by_id[id] as Dictionary)["pool"]))).is_true()
			total += 1
			if not starter.has(a[0]):
				first_unowned += 1
	# 9 unowned x4 vs 15 owned x1 -> about 70% of first slots are unowned.
	var share := float(first_unowned) / float(total)
	assert_float(share).is_between(0.6, 0.8)


func test_offer_ignores_the_global_rng_and_the_deck_changes_it() -> void:
	var ctx := _ctx()
	var starter: Array[String] = RunConfig.starting_deck()
	var a: Array[String] = RewardOffer.generate(11, 1, starter, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
	seed(12345)
	for i in range(50):
		randf()
	var b: Array[String] = RewardOffer.generate(11, 1, starter, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
	assert_array(b).is_equal(a)
	# The deck is an input: owning the three offered cards changes what is offered.
	var richer: Array[String] = starter.duplicate()
	richer.append_array(a)
	var c: Array[String] = RewardOffer.generate(11, 1, richer, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
	assert_bool(c == a and RewardOffer.generate(12, 1, richer, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"]) == a).is_false()


func test_boss_and_last_rooms_open_no_reward_and_rest_opens_the_menu() -> void:
	var ctx := _ctx()
	var state := RunSession.begin_new_run(3)
	assert_str(RunChoices.open_for_room(state, "boss", false, ctx)).is_equal(RunState.PENDING_NONE)
	assert_array(state.offer).is_empty()
	assert_str(RunChoices.open_for_room(state, "combat", true, ctx)).is_equal(RunState.PENDING_NONE)
	assert_str(RunChoices.open_for_room(state, "elite", true, ctx)).is_equal(RunState.PENDING_NONE)
	assert_str(RunChoices.open_for_room(state, "combat", false, ctx)).is_equal(RunState.PENDING_REWARD)
	assert_str(RunChoices.open_for_room(state, "rest", false, ctx)).is_equal(RunState.PENDING_REST)
	assert_array(state.offer).is_empty()


# ---- RunState ----

func test_run_state_v2_survives_a_real_json_string_round_trip_with_a_pending_reward() -> void:
	var state := RunSession.begin_new_run(77)
	state.hp = 12.5
	state.max_hp = 30.0
	state.room_index = 3
	state.pending = RunState.PENDING_REWARD
	state.offer.append_array(["fire_fireball", "neutral_regeneration", "rogue_nap_time"])
	state.log_choice("reject")
	state.log_choice("heal", "", 9.0)
	var back := RunState.from_json(state.to_json())
	assert_object(back).is_not_null()
	assert_bool(state.equals(back)).is_true()
	assert_str(back.pending).is_equal(RunState.PENDING_REWARD)
	assert_array(back.offer).is_equal(state.offer)
	assert_int(back.choice_log.size()).is_equal(2)


func test_a_version_1_save_loads_with_no_pending_choice() -> void:
	var v1 := {
		"version": 1, "seed": 5, "room_index": 2, "hp": 20.0, "max_hp": 30.0, "deck": ["rogue_quick_slash"],
		"rejects_remaining": 3, "history": [], "outcome": "",
	}
	var state := RunState.from_json(JSON.stringify(v1))
	assert_object(state).is_not_null()
	assert_bool(state.has_pending()).is_false()
	assert_array(state.offer).is_empty()
	assert_array(state.choice_log).is_empty()


# ---- Audit: the forced continue ----

func test_forced_continue_is_only_used_by_tests_and_the_soak_tool() -> void:
	var offenders: Array[String] = []
	for dir in ["res://src", "res://tools"]:
		_scan_for_force(dir, offenders)
	offenders.sort()
	assert_array(offenders).is_equal(["res://tools/reload_cycle.gd"])


func _scan_for_force(dir_path: String, offenders: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_for_force(dir_path + "/" + sub, offenders)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir_path + "/" + file)
		if text.contains("continue_to_next_room(true"):
			offenders.append(dir_path + "/" + file)


func test_continue_without_force_cannot_skip_an_open_choice() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	assert_bool(state.has_pending()).is_true()
	var rejects := state.rejects_remaining
	var room := state.room_index
	main.run_controller.continue_to_next_room()
	main.run_controller.continue_to_next_room()
	await _frames(2)
	assert_bool(state.has_pending()).is_true()
	assert_int(state.room_index).is_equal(room)
	assert_int(state.rejects_remaining).is_equal(rejects)


# ---- Input safety through the viewport ----

func test_mashed_real_keys_in_the_arm_window_cannot_pick() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.options_armed()).is_false()
	var deck_size := state.deck.size()
	var rejects := state.rejects_remaining
	# Mash everything a player might be holding: digits, Space, Enter, KP Enter. Real events via the viewport.
	for k: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ENTER]:
		_key(k)
		await get_tree().process_frame
	# LMB (a click) on every option while unarmed.
	for i in range(screen.options_box.get_child_count()):
		var b := screen.options_box.get_child(i) as Button
		if b != null:
			b.pressed.emit()
	# If the machine was slow enough for the window to close, the assertions below would be meaningless: fail loudly.
	assert_bool(screen.options_armed()).is_false()
	assert_bool(state.has_pending()).is_true()
	assert_int(state.deck.size()).is_equal(deck_size)
	assert_int(state.rejects_remaining).is_equal(rejects)


func test_after_arming_space_never_picks_but_enter_on_the_focused_option_does() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	await TestClock.wait_real(get_tree(), 0.6)
	assert_bool(screen.options_armed()).is_true()
	var deck_size := state.deck.size()
	for i in range(4):
		_key(KEY_SPACE)
		await get_tree().process_frame
	assert_bool(state.has_pending()).is_true()
	assert_int(state.deck.size()).is_equal(deck_size)
	# Digits only move the highlight.
	_key(KEY_2)
	await _frames(2)
	assert_bool(state.has_pending()).is_true()
	assert_bool((screen.options_box.get_child(1) as Button).has_focus()).is_true()
	var expected := state.offer[1]
	var old_id := main.get_instance_id()
	_key(KEY_ENTER)
	await _frames(3)
	assert_bool(state.deck.has(expected)).is_true()
	assert_int(state.deck.size()).is_equal(deck_size + 1)
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id:
			auto_free(child)


func test_pause_during_a_choice_blocks_picks_and_resume_allows_them() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	screen.disarm()
	GamePause.pause()
	await _frames(2)
	var deck_size := state.deck.size()
	var rejects := state.rejects_remaining
	for i in range(screen.options_box.get_child_count()):
		var b := screen.options_box.get_child(i) as Button
		if b != null:
			b.pressed.emit()
	_key(KEY_ENTER)
	await _frames(2)
	assert_bool(state.has_pending()).is_true()
	assert_int(state.deck.size()).is_equal(deck_size)
	assert_int(state.rejects_remaining).is_equal(rejects)
	GamePause.resume()
	await _frames(2)
	assert_bool(state.has_pending()).is_true()


func test_a_disabled_reject_cannot_be_chosen_by_signal_or_controller() -> void:
	var state := RunSession.begin_new_run(42)
	state.rejects_remaining = 0
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	screen.disarm()
	var reject_button: Button = null
	for i in range(screen.options_box.get_child_count()):
		var b := screen.options_box.get_child(i) as Button
		if b != null and b.disabled:
			reject_button = b
	assert_object(reject_button).is_not_null()
	reject_button.pressed.emit()  # even a forced signal must not spend or skip
	screen._on_option_pressed("skip")
	assert_bool(state.has_pending()).is_true()
	assert_int(state.rejects_remaining).is_equal(0)
	assert_bool(main.run_controller.choose("skip")["ok"]).is_false()


func test_full_deck_survives_try_again_and_the_full_deck_still_gets_offers() -> void:
	RunSession.full_deck = true
	var state := RunSession.begin_new_run(42)
	var full_size := CardDatabase.all_cards().size()
	assert_int(state.deck.size()).is_equal(full_size)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	assert_int(state.offer.size()).is_equal(3)  # all owned: duplicates are offered, not an empty reward
	var old_id := main.get_instance_id()
	main.restart_arena()
	await _frames()
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id:
			auto_free(child)
	assert_object(RunSession.current).is_not_same(state)
	assert_int(RunSession.current.deck.size()).is_equal(full_size)
