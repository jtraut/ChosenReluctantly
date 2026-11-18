class_name ThreeDATest
extends GdUnitTestSuite
## 3d sitting A: the curse swap penalty (data), the --run-curse-first tooling, the debug flag list, and Try again after a run lost with the player still alive.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const CURSE := "curse_mandatory_training"


func before_test() -> void:
	RunSession.map_override = 0
	RunSession.clear()
	RunSession.curse_first = ""
	RunConfig.reset_cache()


func after_test() -> void:
	RunSession.map_override = -1
	RunSession.clear()
	RunSession.curse_first = ""
	RunConfig.reset_cache()
	Juice.reset()
	GamePause.reset()


func test_the_swap_penalties_come_from_run_json() -> void:
	var block: Dictionary = RunConfig.get_config()["curses"]
	assert_float(RunConfig.swap_penalty()).is_equal(float(block["swap_penalty"]))
	assert_float(RunConfig.curse_swap_penalty()).is_equal(float(block["curse_swap_penalty"]))
	assert_float(RunConfig.swap_penalty()).is_equal(1.0)
	assert_float(RunConfig.curse_swap_penalty()).is_equal(2.0)


func test_a_shipped_curse_costs_the_curse_penalty_to_swap_past_and_another_card_costs_the_ordinary_one() -> void:
	assert_bool(CardSchema.is_curse(CardDatabase.get_card(CURSE))).is_true()
	var slot_type: String = String(CardDatabase.get_card(CURSE).get("slot_type", ""))
	var caster: Node3D = auto_free(Node3D.new())
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), ["neutral"] as Array[String], RandomNumberGenerator.new())
	var deck: Array[String] = [CURSE]
	for card_id: String in CharacterDatabase.starting_deck("rogue"):
		deck.append(card_id)
	controller.set_deck(deck)
	assert_bool(controller.reveal_first(CURSE)).is_true()
	var slot: CardSlot = controller.get_slot(slot_type)
	assert_str(slot.current_card_id).is_equal(CURSE)
	assert_float(slot.current_swap_penalty()).is_equal(2.0)
	assert_bool(controller.try_swap(slot_type)).is_true()
	assert_float(slot.cooldown_remaining).is_equal(2.0)
	assert_float(slot.last_cooldown_duration).is_equal(2.0)
	assert_str(slot.current_card_id).is_not_equal(CURSE)
	slot.cooldown_remaining = 0.0
	assert_float(slot.current_swap_penalty()).is_equal(1.0)  # an ordinary card now
	assert_bool(controller.try_swap(slot_type)).is_true()
	assert_float(slot.cooldown_remaining).is_equal(1.0)


func test_reveal_first_swaps_places_and_reports_a_card_the_slot_does_not_hold() -> void:
	var slot := CardSlot.new("attack_single", 1.0, ["a", "b", "c"] as Array[String], 1.0, RandomNumberGenerator.new())
	assert_bool(slot.reveal_first("zzz")).is_false()
	var target: String = "a" if slot.current_card_id != "a" else "b"
	assert_bool(slot.reveal_first(target)).is_true()
	assert_str(slot.current_card_id).is_equal(target)
	assert_int(slot.draw_pile.size() + 1).is_equal(3)
	assert_bool(slot.draw_pile.has(target)).is_false()


func test_the_new_tooling_flags_make_a_run_a_debug_run() -> void:
	assert_bool(RunSave.args_suppress(PackedStringArray(["--run-curse-first=" + CURSE]))).is_true()
	assert_bool(RunSave.args_suppress(PackedStringArray(["--run-auto-choose=relic:x"]))).is_true()
	assert_bool(RunSave.DEBUG_FLAG_PREFIXES.has("--run-curse-first")).is_true()
	assert_bool(RunSave.DEBUG_FLAG_PREFIXES.has("--run-auto-choose")).is_true()
	assert_bool(RunSave.args_suppress(PackedStringArray(["--class=rogue"]))).is_false()


func test_a_run_started_with_curse_first_holds_the_curse_and_reveals_it() -> void:
	RunSession.curse_first = CURSE
	var state: RunState = RunSession.begin_new_run(7, "rogue")
	assert_array(state.deck).contains([CURSE])
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var slot_type: String = String(CardDatabase.get_card(CURSE).get("slot_type", ""))
	assert_str((main.player.card_slots.get_slot(slot_type) as CardSlot).current_card_id).is_equal(CURSE)


func _other_main(old_id: int) -> Main:
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			return child as Main
	return null


func test_try_again_after_a_run_lost_with_the_player_alive_starts_a_fresh_run() -> void:
	var state: RunState = RunSession.begin_new_run(11, "rogue")
	var old_seed: int = state.seed_value
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var announced: Array[int] = []
	main.game_over_ready.connect(func() -> void: announced.append(1))
	state.outcome = "lost"
	main.run_controller.run_lost.emit()  # what an act-change map failure does: a loss with no death
	assert_bool(main.player.is_dead()).is_false()
	assert_array(announced).has_size(1)
	assert_bool(main.is_game_over()).is_true()
	main.run_controller.run_lost.emit()
	assert_array(announced).has_size(1)  # never twice
	var old_id: int = main.get_instance_id()
	main.restart_arena()  # what the Game Over screen's Try again calls
	await get_tree().process_frame
	await get_tree().process_frame
	var fresh: Main = _other_main(old_id)
	assert_object(fresh).is_not_null()
	auto_free(fresh)
	assert_bool(fresh.is_game_over()).is_false()
	assert_str(RunSession.current.outcome).is_equal("")
	assert_bool(RunSession.current.seed_value == old_seed).is_false()
	assert_int(RunSession.current.room_index).is_equal(0)
	assert_int(fresh.run_controller.room_number()).is_equal(1)
	assert_float(fresh.player.health.current_health).is_equal(fresh.player.health.max_health)
