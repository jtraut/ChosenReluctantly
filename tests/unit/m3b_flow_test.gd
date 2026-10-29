class_name M3bFlowTest
extends GdUnitTestSuite
## Milestone 3b, scene level: a won room opens the reward on the generic prompt screen, a pick or reject loads
## the next room with the deck changed, a reload mid-reward reopens the same offer without replaying the room,
## and Try again leaves no reward state behind.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	RunSession.clear()


func after_test() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	Juice.reset()
	GamePause.reset()


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _other_main(old_id: int) -> Main:
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			return child as Main
	return null


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


func test_winning_a_combat_room_opens_the_reward_with_offers_and_a_reject() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	var models: Array[Dictionary] = []
	main.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _win_room(main)
	assert_int(models.size()).is_equal(1)
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
	assert_int(state.offer.size()).is_equal(RunConfig.offer_size())
	assert_str(models[0]["next_line"]).starts_with("Next: Room 2 of 8 - ")
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.options_box.get_child_count()).is_equal(RunConfig.offer_size() + 1)
	assert_bool(screen.button.visible).is_false()
	# The same offer comes from the same seed and deck.
	var again := RewardOffer.generate(state.seed_value, 0, state.deck, CardDatabase.all_cards(), main.player.owned_pools, {"fire": PoolDatabase.get_definition("fire")}, RunConfig.rewards())
	assert_array(again).is_equal(state.offer)


func test_picking_a_card_loads_the_next_room_with_it_in_the_deck() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var card_id: String = state.offer[0]
	var old_id := main.get_instance_id()
	var result: Dictionary = main.run_controller.choose("card:" + card_id)
	assert_bool(result["ok"]).is_true()
	await _frames()
	var next := _other_main(old_id)
	assert_object(next).is_not_null()
	auto_free(next)
	assert_int(RunSession.current.room_index).is_equal(1)
	assert_bool(RunSession.current.has_pending()).is_false()
	assert_array(next.player.card_slots.owned_card_ids()).contains([card_id])
	assert_int(next.player.card_slots.owned_card_ids().size()).is_equal(16)
	assert_int(RunSession.current.rejects_remaining).is_equal(3)


func test_rejecting_spends_a_reject_and_the_deck_stays() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var old_id := main.get_instance_id()
	assert_bool(main.run_controller.choose("skip")["ok"]).is_true()
	await _frames()
	auto_free(_other_main(old_id))
	assert_int(state.rejects_remaining).is_equal(2)
	assert_int(state.deck.size()).is_equal(15)


func test_a_disabled_option_does_nothing_and_a_closed_choice_refuses() -> void:
	var state := RunSession.begin_new_run(42)
	state.rejects_remaining = 0
	var main := _spawn()
	await _frames(1)
	assert_bool(main.run_controller.choose("skip")["ok"]).is_false()  # nothing open yet
	await _win_room(main)
	assert_bool(main.run_controller.choose("skip")["ok"]).is_false()  # no rejects left
	assert_bool(state.has_pending()).is_true()
	assert_bool(main.run_controller.is_cleared()).is_true()
	main.run_controller.continue_to_next_room()  # the Continue path cannot skip an open choice
	assert_int(state.room_index).is_equal(0)
	assert_bool(main.run_controller.choose("nonsense")["ok"]).is_false()


func test_reload_mid_reward_reopens_the_same_offer_without_replaying_the_room() -> void:
	var state := RunSession.begin_new_run(42)
	var first := _spawn()
	await _frames(1)
	await _win_room(first)
	var offer := state.offer.duplicate()
	var history_size := state.history.size()
	var hp := state.hp
	var snapshot := state.to_json()
	first.queue_free()
	await _frames()
	# A reload keeps the RunState (a static) and builds a fresh scene on top of it.
	assert_str(RunSession.current.to_json()).is_equal(snapshot)
	var second := _spawn()
	var models: Array[Dictionary] = []
	second.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames(3)
	assert_int(models.size()).is_equal(1)
	assert_array(state.offer).is_equal(offer)
	assert_int(state.history.size()).is_equal(history_size)  # the room was not recorded twice
	assert_float(state.hp).is_equal(hp)
	assert_int(second.enemy_spawner.alive_count()).is_equal(0)
	assert_bool(second.run_controller.is_cleared()).is_true()
	assert_bool(second.player.health.damage_immune).is_true()
	assert_bool((second.get_node("RoomClearedScreen") as RunPromptScreen).is_open()).is_true()
	# And the reopened reward still works.
	var old_id := second.get_instance_id()
	assert_bool(second.run_controller.choose("card:" + String(offer[0]))["ok"]).is_true()
	await _frames()
	auto_free(_other_main(old_id))
	assert_int(RunSession.current.deck.size()).is_equal(16)


func test_try_again_from_a_reward_state_starts_a_clean_run() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	assert_bool(state.has_pending()).is_true()
	var old_id := main.get_instance_id()
	main.restart_arena()  # what Try again / New run call
	await _frames()
	var fresh := _other_main(old_id)
	assert_object(fresh).is_not_null()
	auto_free(fresh)
	assert_object(RunSession.current).is_not_same(state)
	assert_bool(RunSession.current.has_pending()).is_false()
	assert_array(RunSession.current.offer).is_empty()
	assert_array(RunSession.current.choice_log).is_empty()
	assert_int(RunSession.current.rejects_remaining).is_equal(3)
	assert_array(RunSession.current.deck).is_equal(RunConfig.starting_deck())


func test_rest_room_shows_heal_and_remove_and_remove_is_greyed_with_the_reason() -> void:
	var state := RunSession.begin_new_run(42)
	for room: Dictionary in RunGenerator.generate(state.seed_value, RunConfig.get_config()):
		if room["type"] == "rest":
			state.room_index = room["index"]
	state.max_hp = 100.0
	state.hp = 60.0
	var main := _spawn()
	await _frames(3)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.options_box.get_child_count()).is_equal(2)
	var remove_button := screen.options_box.get_child(1) as Button
	assert_bool(remove_button.disabled).is_true()
	assert_str(remove_button.text).contains("Unavailable")
	assert_bool((screen.options_box.get_child(0) as Button).disabled).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_REST)
	assert_int(state.history.size()).is_equal(1)


func test_number_keys_move_the_highlight_and_do_not_pick() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	await _win_room(main)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	var offered_second: String = state.offer[1]
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	screen._input(key)
	assert_bool((screen.options_box.get_child(1) as Button).has_focus()).is_true()
	assert_bool(state.has_pending()).is_true()  # nothing was picked
	assert_int(state.deck.size()).is_equal(15)
	# Enter / click activates the focused option.
	var picked: Array[String] = []
	screen.option_chosen.connect(func(id: String) -> void: picked.append(id))
	var old_id := main.get_instance_id()
	assert_bool(screen.options_armed()).is_false()  # just opened: a press is ignored (Space, LMB, mashed keys)
	(screen.options_box.get_child(1) as Button).pressed.emit()
	assert_array(picked).is_empty()
	assert_bool(state.has_pending()).is_true()
	screen.disarm()
	(screen.options_box.get_child(1) as Button).pressed.emit()
	assert_array(picked).is_equal(["card:" + offered_second])
	await _frames()
	auto_free(_other_main(old_id))


func test_cleared_panel_without_a_choice_has_a_next_line_and_no_healed_zero() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	var rest_summary: Dictionary = {"index": 3, "type": "rest", "wave_id": "", "hp": 30.0, "max_hp": 30.0, "healed": 0.0, "seconds": 0.0}
	screen._show_cleared(rest_summary)
	assert_str(screen.hint_label.text).starts_with("Next: Room 2 of 8")
	assert_str(screen.line_label.text).not_contains("+0").not_contains("healed 0")
	for child in screen.stats.get_children():
		assert_str((child as Label).text).is_not_equal("+0")
