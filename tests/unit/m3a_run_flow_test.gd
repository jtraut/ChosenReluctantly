class_name M3aRunFlowTest
extends GdUnitTestSuite
## Milestone 3a, scene level: RunMain loads the run state, a won room waits for Continue, the next room is a
## fresh scene carrying HP and deck, win and lose end the run, Try again starts a new run, elites get their stats.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const MAIN_PATH := "res://scenes/main/Main.tscn"


func before_test() -> void:
	RunSession.clear()


func after_test() -> void:
	RunSession.clear()
	Juice.reset()
	GamePause.reset()


func _spawn(path: String = RUN_MAIN_PATH) -> Main:
	var main: Main = (load(path) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


## A one-enemy finite table that opens at once, so a test can win the room in a few steps.
func _tiny_room() -> Dictionary:
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	return table


func _win_room(main: Main) -> void:
	main.enemy_spawner.configure_room(_tiny_room(), 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await get_tree().process_frame
	await get_tree().process_frame


func _other_main(old_id: int) -> Main:
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			return child as Main
	return null


func test_plain_main_is_the_endless_arena_with_no_run_nodes() -> void:
	var main := _spawn(MAIN_PATH)
	await get_tree().process_frame
	assert_object(main.run_controller).is_null()
	assert_object(main.get_node_or_null("RunController")).is_null()
	assert_bool(RunSession.has_run()).is_false()
	assert_bool(main.enemy_spawner.plan.is_finished()).is_false()


func test_run_main_starts_room_one_with_the_starting_deck() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	var controller := main.run_controller
	assert_object(controller).is_not_null()
	assert_int(controller.room_number()).is_equal(1)
	assert_int(controller.room_total()).is_equal(8)
	assert_str(controller.room_type()).is_equal("combat")
	assert_str(controller.room_label()).is_equal("Room 1 of 8")
	var deck := main.player.card_slots.owned_card_ids()
	deck.sort()
	var expected := RunConfig.starting_deck()
	expected.sort()
	assert_array(deck).is_equal(expected)
	assert_bool(main.enemy_spawner.plan.config.get("finite", false)).is_true()
	assert_float(RunSession.current.max_hp).is_equal(main.player.health.max_health)
	assert_array(SceneSelfCheck.find_problems(main)).is_empty()


func test_room_is_won_only_when_waves_are_done_and_nothing_is_alive() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	main.enemy_spawner.configure_room(_tiny_room(), 1)
	# Nothing spawned yet: not cleared, even though nothing is alive.
	await get_tree().process_frame
	assert_bool(main.run_controller.is_cleared()).is_false()
	main.enemy_spawner._process(1.0)
	await get_tree().process_frame
	assert_int(main.enemy_spawner.alive_count()).is_equal(1)
	assert_bool(main.run_controller.is_cleared()).is_false()
	var cleared: Array[Dictionary] = []
	main.run_controller.room_cleared.connect(func(summary: Dictionary) -> void: cleared.append(summary))
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(main.run_controller.is_cleared()).is_true()
	assert_array(cleared).has_size(1)
	assert_int(RunSession.current.history.size()).is_equal(1)
	assert_bool(main.player.health.damage_immune).is_true()


func test_continue_loads_the_next_room_carrying_hp_and_deck() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	main.player.health.take_damage(7.0)
	var hp_before := main.player.health.current_health
	var max_before := main.player.health.max_health
	await _win_room(main)
	assert_bool(main.run_controller.is_cleared()).is_true()
	# A cooldown running in this room must not follow the player into the next one.
	main.player.card_slots.try_use("attack_single")
	assert_float(main.player.card_slots.get_slot("attack_single").cooldown_remaining).is_greater(0.0)
	var old_id := main.get_instance_id()
	main.run_controller.continue_to_next_room()
	await get_tree().process_frame
	await get_tree().process_frame
	var next := _other_main(old_id)
	assert_object(next).is_not_null()
	auto_free(next)
	assert_int(next.run_controller.room_number()).is_equal(2)
	assert_float(next.player.health.current_health).is_equal(hp_before)
	assert_float(next.player.health.max_health).is_equal(max_before)
	var deck := next.player.card_slots.owned_card_ids()
	deck.sort()
	var expected := RunConfig.starting_deck()
	expected.sort()
	assert_array(deck).is_equal(expected)
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		assert_float(next.player.card_slots.get_slot(slot_type).cooldown_remaining).is_equal(0.0)
	assert_bool(next.player.health.damage_immune).is_false()
	assert_int(RunSession.current.room_index).is_equal(1)


func test_rest_room_heals_thirty_percent_and_clears() -> void:
	var state := RunSession.begin_new_run(42)
	var rooms := RunGenerator.generate(state.seed_value, RunConfig.get_config())
	var rest_index := -1
	for room: Dictionary in rooms:
		if room["type"] == "rest":
			rest_index = room["index"]
	state.room_index = rest_index
	state.max_hp = 100.0
	state.hp = 40.0
	var main := _spawn()
	var summaries: Array[Dictionary] = []
	main.run_controller.room_cleared.connect(func(s: Dictionary) -> void: summaries.append(s))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(main.run_controller.is_cleared()).is_true()
	assert_float(main.player.health.current_health).is_equal_approx(70.0, 0.001)
	assert_float(RunSession.current.hp).is_equal_approx(70.0, 0.001)


func test_rest_heal_does_not_exceed_max() -> void:
	var state := RunSession.begin_new_run(42)
	var rooms := RunGenerator.generate(state.seed_value, RunConfig.get_config())
	for room: Dictionary in rooms:
		if room["type"] == "rest":
			state.room_index = room["index"]
	state.max_hp = 100.0
	state.hp = 95.0
	var main := _spawn()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(main.player.health.current_health).is_equal_approx(100.0, 0.001)


func test_last_room_won_ends_the_run_with_a_win() -> void:
	var state := RunSession.begin_new_run(42)
	state.room_index = 7
	var main := _spawn()
	await get_tree().process_frame
	var wins: Array[int] = []
	main.run_controller.run_won.connect(func() -> void: wins.append(1))
	assert_bool(main.run_controller.is_last_room()).is_true()
	assert_str(main.run_controller.room_type()).is_equal("boss")
	await _win_room(main)
	assert_array(wins).has_size(1)
	assert_str(RunSession.current.outcome).is_equal("won")
	var win_screen := main.get_node("WinScreen") as CanvasLayer
	assert_bool(win_screen.visible).is_true()
	assert_bool((main.get_node("RoomClearedScreen") as CanvasLayer).visible).is_false()


func test_death_ends_the_run_and_try_again_starts_a_new_one() -> void:
	var state := RunSession.begin_new_run(42)
	state.room_index = 2
	state.rejects_remaining = 1
	var old_seed := state.seed_value
	var main := _spawn()
	await get_tree().process_frame
	var lost: Array[int] = []
	main.run_controller.run_lost.connect(func() -> void: lost.append(1))
	main.player.health.take_damage(100000.0)
	assert_array(lost).has_size(1)
	assert_str(RunSession.current.outcome).is_equal("lost")
	var old_id := main.get_instance_id()
	main.restart_arena()
	await get_tree().process_frame
	await get_tree().process_frame
	var fresh := _other_main(old_id)
	assert_object(fresh).is_not_null()
	auto_free(fresh)
	var run := RunSession.current
	assert_object(run).is_not_same(state)
	assert_int(run.room_index).is_equal(0)
	assert_int(run.rejects_remaining).is_equal(3)
	assert_int(run.history.size()).is_equal(0)
	assert_str(run.outcome).is_equal("")
	assert_array(run.deck).is_equal(RunConfig.starting_deck())
	assert_bool(run.seed_value == old_seed).is_false()
	assert_int(fresh.run_controller.room_number()).is_equal(1)
	assert_float(fresh.player.health.current_health).is_equal(fresh.player.health.max_health)


func test_damage_after_a_win_cannot_kill_the_player() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	await _win_room(main)
	main.player.health.take_damage(100000.0)
	assert_bool(main.player.is_dead()).is_false()


# ---- Elites ----

func _tiered(enemy_scene: String) -> Enemy:
	var enemy: Enemy = (load(enemy_scene) as PackedScene).instantiate()
	add_child(enemy)
	auto_free(enemy)
	return enemy


func test_elite_golem_keeps_its_own_resistance_and_gets_hp() -> void:
	var golem := _tiered("res://scenes/enemies/FireResistantGolem.tscn")
	var base_hp := golem.health.max_health
	var own_fire := golem.health.get_resistance("fire")
	golem.apply_tier("elite", RunConfig.tier("elite"))
	assert_float(golem.health.max_health).is_equal(base_hp * 2.5)
	assert_float(golem.health.current_health).is_equal(golem.health.max_health)
	assert_float(golem.health.get_resistance("fire")).is_equal(minf(maxf(own_fire, 0.25), 0.5))
	assert_str(golem.tier).is_equal("elite")
	assert_bool(golem.is_elite()).is_true()
	assert_object(golem.get_node_or_null("TierMarker")).is_not_null()
	assert_str(golem.status_manager.rank).is_equal("elite")


func test_elite_chaser_gets_twenty_five_percent_fire_and_physical_is_untouched() -> void:
	var chaser := _tiered("res://scenes/enemies/MeleeChaser.tscn")
	chaser.apply_tier("elite", RunConfig.tier("elite"))
	assert_float(chaser.health.get_resistance("fire")).is_equal(0.25)
	var before := chaser.health.current_health
	chaser.health.take_damage(10.0, "physical")
	assert_float(before - chaser.health.current_health).is_equal(10.0)
	var before_fire := chaser.health.current_health
	chaser.health.take_damage(10.0, "fire")
	assert_float(before_fire - chaser.health.current_health).is_equal_approx(7.5, 0.001)


func test_spawner_applies_tiers_from_the_queued_spawn() -> void:
	var main := _spawn(MAIN_PATH)
	await get_tree().process_frame
	main.enemy_spawner.tier_configs = RunConfig.get_config()["tiers"]
	main.enemy_spawner._spawn_one("boss|melee_chaser")
	main.enemy_spawner._spawn_one("melee_chaser")
	var tiers: Array[String] = []
	for child in main.get_children():
		if child is Enemy:
			tiers.append((child as Enemy).tier)
	tiers.sort()
	assert_array(tiers).is_equal(["boss", "normal"])
