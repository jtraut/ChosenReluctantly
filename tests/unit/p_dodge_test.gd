class_name PDodgeTest
extends GdUnitTestSuite
## P-dodge (gameplay side): dodge charges (pure pool, clamp, modifiers, recharge timing, per-class counts), the Recovery
## cooldowns (D13: 12 s, Wizard 14 s), the pass-through concentric launch fix (f1 qa), and the rest-room immunity that made
## the reload soak flake (4a).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func after_test() -> void:
	PlayerConfig.reload()
	Enemy.set_player_body_suppressed(false)
	RunSession.clear()
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _spawn_main(character: String = "") -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	if character != "":
		(main.get_node("Player") as Player).character_id = character
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _tap_dodge() -> void:
	TestInput.press(&"dodge")
	await get_tree().physics_frame
	TestInput.release(&"dodge")


# ---- The pool, without a scene ----

func test_effective_max_clamps_at_both_ends() -> void:
	var stats := StatModifiers.new()
	assert_int(DodgeCharges.effective_max(3, stats, "dodge_charges", 0, 4)).is_equal(3)
	stats.add_modifier("dodge_charges", "boots", StatModifiers.ADDITIVE, 5.0)
	assert_int(DodgeCharges.effective_max(3, stats, "dodge_charges", 0, 4)).override_failure_message("upper clamp").is_equal(4)
	stats.add_modifier("dodge_charges", "boots", StatModifiers.ADDITIVE, -9.0)
	assert_int(DodgeCharges.effective_max(3, stats, "dodge_charges", 0, 4)).override_failure_message("lower clamp").is_equal(0)
	stats.add_modifier("dodge_charges", "boots", StatModifiers.ADDITIVE, 1.0)
	assert_int(DodgeCharges.effective_max(3, stats, "dodge_charges", 0, 4)).is_equal(4)
	assert_int(DodgeCharges.effective_max(3, null, "dodge_charges", 0, 4)).is_equal(3)


func test_each_dodge_spends_one_and_zero_is_unavailable() -> void:
	var pool := DodgeCharges.new(1.2, 3)
	assert_bool(pool.try_spend(3)).is_true()
	assert_bool(pool.try_spend(3)).is_true()
	assert_bool(pool.try_spend(3)).is_true()
	assert_int(pool.current).is_equal(0)
	assert_bool(pool.try_spend(3)).override_failure_message("a dodge at 0 charges").is_false()
	assert_int(pool.current).is_equal(0)


func test_charges_recharge_one_at_a_time_after_the_cooldown() -> void:
	var pool := DodgeCharges.new(1.2, 3)
	pool.try_spend(3)
	pool.try_spend(3)
	pool.try_spend(3)
	assert_float(pool.recharge_remaining(3)).is_equal_approx(1.2, 0.0001)
	assert_bool(pool.advance(1.19, 3)).is_false()
	assert_int(pool.current).is_equal(0)
	assert_bool(pool.advance(0.02, 3)).is_true()
	assert_int(pool.current).override_failure_message("first charge back at 1.2 s").is_equal(1)
	assert_float(pool.recharge_progress(3)).is_less(0.1)  # the next pip starts empty
	pool.advance(1.1, 3)
	assert_int(pool.current).is_equal(1)
	pool.advance(0.15, 3)
	assert_int(pool.current).is_equal(2)
	pool.advance(1.21, 3)
	assert_int(pool.current).is_equal(3)
	assert_float(pool.recharge_progress(3)).is_equal(1.0)
	assert_float(pool.recharge_remaining(3)).is_equal(0.0)


func test_a_spend_while_recharging_keeps_the_running_timer() -> void:
	var pool := DodgeCharges.new(1.2, 3)
	pool.try_spend(3)
	pool.advance(1.0, 3)
	pool.try_spend(3)
	assert_float(pool.recharge_remaining(3)).override_failure_message("the second spend must not restart the timer").is_equal_approx(0.2, 0.0001)
	pool.advance(0.21, 3)
	assert_int(pool.current).is_equal(2)


func test_a_big_step_returns_several_charges() -> void:
	var pool := DodgeCharges.new(1.2, 3)
	pool.try_spend(3)
	pool.try_spend(3)
	pool.advance(2.5, 3)
	assert_int(pool.current).is_equal(3)


func test_lowering_the_maximum_mid_run_clamps_current_down() -> void:
	var pool := DodgeCharges.new(1.2, 3)
	assert_bool(pool.advance(0.1, 1)).is_true()
	assert_int(pool.current).is_equal(1)
	assert_float(pool.recharge_remaining(1)).is_equal(0.0)
	assert_bool(pool.try_spend(0)).override_failure_message("maximum 0: nothing to spend").is_false()
	assert_int(pool.current).is_equal(0)


func test_raising_the_maximum_mid_run_recharges_toward_it() -> void:
	var pool := DodgeCharges.new(1.2, 2)
	pool.advance(0.5, 3)
	assert_int(pool.current).is_equal(2)
	pool.advance(0.8, 3)
	assert_int(pool.current).is_equal(3)


func test_reset_fills_the_pool() -> void:
	var pool := DodgeCharges.new(1.2, 3)
	pool.try_spend(3)
	pool.try_spend(3)
	pool.reset(3)
	assert_int(pool.current).is_equal(3)
	assert_float(pool.recharge_remaining(3)).is_equal(0.0)


func test_zero_cooldown_refills_at_once_without_looping_forever() -> void:
	var pool := DodgeCharges.new(0.0, 0)
	pool.advance(0.016, 3)
	assert_int(pool.current).is_equal(3)


# ---- Data ----

func test_shipped_charge_data() -> void:
	var dodge: Dictionary = PlayerConfig.dodge()
	assert_int(int(dodge["charges"])).is_equal(3)
	assert_int(int(dodge["min_charges"])).is_equal(0)
	assert_int(int(dodge["max_charges"])).is_equal(4)
	assert_float(float(dodge["cooldown"])).is_equal(1.2)
	assert_float(float(dodge["speed"]) * float(dodge["duration"])).is_equal_approx(5.0, 0.0001)
	assert_int(CharacterDatabase.dodge_charges("rogue", 99)).is_equal(3)
	assert_int(CharacterDatabase.dodge_charges("wizard", 99)).is_equal(2)
	assert_int(CharacterDatabase.dodge_charges("nobody", 7)).override_failure_message("falls back to the player.json default").is_equal(7)
	assert_array(CharacterDatabase.validate_shipped()).is_empty()


func test_validation_rejects_bad_charge_data() -> void:
	var good: Dictionary = {"dodge": {"speed": 20.0, "duration": 0.25, "cooldown": 1.2, "block_ticks_after_pause": 2, "charges": 3, "min_charges": 0, "max_charges": 4}}
	assert_array(PlayerConfig.validate(good)).is_empty()
	for bad: Dictionary in [
		{"charges": 5}, {"charges": -1}, {"charges": 2.5}, {"charges": "3"}, {"min_charges": 4, "max_charges": 3, "charges": 3},
		{"min_charges": 2, "charges": 1}, {"max_charges": 2, "charges": 3}, {"min_charges": -1}, {"max_charges": 99},
	]:
		var copy: Dictionary = good.duplicate(true)
		(copy["dodge"] as Dictionary).merge(bad, true)
		assert_array(PlayerConfig.validate(copy)).override_failure_message("accepted %s" % str(bad)).is_not_empty()
	for missing: String in ["charges", "min_charges", "max_charges"]:
		var copy: Dictionary = good.duplicate(true)
		(copy["dodge"] as Dictionary).erase(missing)
		assert_array(PlayerConfig.validate(copy)).override_failure_message("accepted a file without %s" % missing).is_not_empty()


func test_character_tuning_validation() -> void:
	var entry: Dictionary = (CharacterDatabase.get_entry("wizard") as Dictionary).duplicate(true)
	assert_array(CharacterDatabase.validate_entry("wizard", entry)).is_empty()
	for bad: Dictionary in [
		{"dodge_charges": 5}, {"dodge_charges": -1}, {"dodge_charges": 1.5}, {"dodge_charges": "2"},
		{"slot_base_cooldowns": "14"}, {"slot_base_cooldowns": {"nonsense": 5.0}}, {"slot_base_cooldowns": {"recovery": 0.0}},
		{"slot_base_cooldowns": {"recovery": "long"}},
	]:
		var copy: Dictionary = entry.duplicate(true)
		copy.merge(bad, true)
		assert_array(CharacterDatabase.validate_entry("wizard", copy)).override_failure_message("accepted %s" % str(bad)).is_not_empty()


# ---- On the player ----

func test_the_player_reads_its_class_charge_count() -> void:
	var rogue := _spawn_main("rogue")
	await _frames(2)
	assert_int(rogue.player.dodge_charges_max()).is_equal(3)
	assert_int(rogue.player.get_dodge_state()["current"]).is_equal(3)
	var wizard := _spawn_main("wizard")
	await _frames(2)
	assert_int(wizard.player.dodge_charges_max()).is_equal(2)
	var state: Dictionary = wizard.player.get_dodge_state()
	assert_int(int(state["current"])).is_equal(2)
	assert_int(int(state["max"])).is_equal(2)
	assert_bool(bool(state["recharging"])).is_false()
	assert_float(float(state["recharge_progress"])).is_equal(1.0)


func test_a_class_count_still_clamps_after_modifiers() -> void:
	var main := _spawn_main("wizard")
	await _frames(2)
	main.player.stat_modifiers.add_modifier("dodge_charges", "test", StatModifiers.ADDITIVE, 9.0)
	assert_int(main.player.dodge_charges_max()).is_equal(4)
	main.player.stat_modifiers.add_modifier("dodge_charges", "test", StatModifiers.ADDITIVE, -9.0)
	assert_int(main.player.dodge_charges_max()).is_equal(0)


func test_dodging_spends_charges_and_cannot_restart_during_the_roll() -> void:
	var main := _spawn_main("rogue")
	await _frames(3)
	var player := main.player
	var seen: Array[int] = []
	player.dodge_charges_changed.connect(func(current: int, _maximum: int) -> void: seen.append(current))
	await _tap_dodge()
	await _frames(2)
	assert_bool(player._forced_move_time_remaining > 0.0).is_true()
	assert_int(player.dodge_charges.current).is_equal(2)
	await _tap_dodge()  # inside the 0.25 s roll
	assert_int(player.dodge_charges.current).override_failure_message("a second dodge started during the roll").is_equal(2)
	await _frames(20)  # the roll is over
	assert_bool(player._forced_move_time_remaining > 0.0).is_false()
	await _tap_dodge()
	await _frames(20)
	await _tap_dodge()
	await _frames(2)
	assert_int(player.dodge_charges.current).is_equal(0)
	assert_bool(bool(player.get_dodge_state()["recharging"])).is_true()
	await _frames(20)
	await _tap_dodge()
	await _frames(2)
	assert_bool(player._forced_move_time_remaining > 0.0).override_failure_message("a dodge at 0 charges rolled").is_false()
	assert_int(player.dodge_charges.current).is_equal(0)
	assert_bool(seen.has(0)).override_failure_message("dodge_charges_changed emitted the spends").is_true()


func test_a_dodge_stays_five_metres() -> void:
	var main := _spawn_main("rogue")
	await _frames(3)
	var start: Vector3 = main.player.global_position
	var facing: Vector3 = main.player.get_aim_direction()
	await _tap_dodge()
	await _frames(40)
	assert_float((main.player.global_position - start).dot(facing)).is_equal_approx(5.0, 0.1)


func test_the_charge_comes_back_after_the_cooldown_on_the_player() -> void:
	var main := _spawn_main("wizard")
	await _frames(3)
	var player := main.player
	await _tap_dodge()
	await _frames(2)
	assert_int(player.dodge_charges.current).is_equal(1)
	await _frames(40)
	var mid: Dictionary = player.get_dodge_state()
	assert_float(float(mid["recharge_progress"])).is_between(0.2, 0.9)
	await _frames(20)
	assert_int(player.dodge_charges.current).override_failure_message("still 1 at about 1.1 s").is_equal(1)
	await _frames(40)
	assert_int(player.dodge_charges.current).is_equal(2)


func test_lowering_the_maximum_mid_run_clamps_the_player() -> void:
	var main := _spawn_main("rogue")
	await _frames(3)
	main.player.stat_modifiers.add_modifier("dodge_charges", "curse", StatModifiers.ADDITIVE, -2.0)
	await _frames(2)
	assert_int(main.player.dodge_charges.current).is_equal(1)
	assert_int(int(main.player.get_dodge_state()["max"])).is_equal(1)
	main.player.stat_modifiers.remove_modifier("dodge_charges", "curse")
	await _frames(160)
	assert_int(main.player.dodge_charges.current).override_failure_message("recharges to 3 after the curse is gone").is_equal(3)


func test_reset_dodge_charges_and_a_fresh_room_start_full() -> void:
	var main := _spawn_main("rogue")
	await _frames(3)
	await _tap_dodge()
	await _frames(2)
	assert_int(main.player.dodge_charges.current).is_equal(2)
	main.player.reset_dodge_charges()
	assert_int(main.player.dodge_charges.current).is_equal(3)
	var fresh := _spawn_main("rogue")
	await _frames(2)
	assert_int(fresh.player.dodge_charges.current).is_equal(3)


func test_a_dead_player_cannot_dodge() -> void:
	var main := _spawn_main("rogue")
	await _frames(3)
	main.player.health.take_damage(9999.0, "physical")
	await _frames(2)
	await _tap_dodge()
	await _frames(2)
	assert_int(main.player.dodge_charges.current).is_equal(3)


# ---- D13 and 4e: Recovery cooldowns ----

func test_recovery_base_is_twelve_and_the_wizard_overrides_it_to_fourteen() -> void:
	assert_float(float(SlotTypeDatabase.get_definition("recovery")["base_cooldown"])).is_equal(12.0)
	assert_float(float(CharacterDatabase.slot_base_cooldowns("wizard")["recovery"])).is_equal(14.0)
	assert_bool(CharacterDatabase.slot_base_cooldowns("rogue").is_empty()).is_true()
	var rogue := _spawn_main("rogue")
	var wizard := _spawn_main("wizard")
	await _frames(2)
	assert_float(rogue.player.card_slots.get_slot("recovery").base_cooldown).is_equal(12.0)
	assert_float(wizard.player.card_slots.get_slot("recovery").base_cooldown).is_equal(14.0)
	assert_float(wizard.player.card_slots.get_slot("utility").base_cooldown).override_failure_message("only Recovery is overridden").is_equal(4.0)
	assert_float(rogue.player.card_slots.get_slot("utility").base_cooldown).is_equal(4.0)


func test_the_wizard_override_survives_a_deck_swap_and_is_the_cooldown_used() -> void:
	var main := _spawn_main("wizard")
	await _frames(2)
	var controller: CardSlotController = main.player.card_slots
	controller.set_deck(CharacterDatabase.starting_deck("wizard"))
	assert_float(controller.get_slot("recovery").base_cooldown).is_equal(14.0)
	var slot: CardSlot = controller.get_slot("recovery")
	var modifier: float = float(CardDatabase.get_card(slot.current_card_id).get("cooldown_modifier", 0.0))
	slot.use_card(modifier)
	assert_float(slot.cooldown_remaining).is_equal_approx(14.0 + modifier, 0.0001)


func test_recovery_stays_the_longest_effective_cooldown_for_both_classes() -> void:
	for character: String in ["rogue", "wizard"]:
		var overrides: Dictionary = CharacterDatabase.slot_base_cooldowns(character)
		var pools: Array[String] = CharacterDatabase.pools(character)
		var shortest_recovery := INF
		var longest_other := 0.0
		for card: Dictionary in CardDatabase.all_cards():
			if not pools.has(String(card["pool"])):
				continue
			var slot_type: String = String(card["slot_type"])
			var base: float = float(overrides.get(slot_type, SlotTypeDatabase.get_definition(slot_type)["base_cooldown"]))
			var cooldown: float = base + float(card["cooldown_modifier"])
			if slot_type == "recovery":
				shortest_recovery = minf(shortest_recovery, cooldown)
			else:
				longest_other = maxf(longest_other, cooldown)
		assert_float(shortest_recovery).override_failure_message("%s: Recovery must be the longest" % character).is_greater(longest_other)


# ---- 4f: the concentric launch ----

func test_clearing_offset_is_zero_when_clear_and_nonzero_when_concentric() -> void:
	var main := _spawn_main("rogue")
	await _frames(2)
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = Vector3(3.0, 0.0, 0.0)
	main.add_child(enemy)
	await _frames(1)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	assert_vector(Enemy.clearing_offset(Vector3(0.0, 0.0, 0.0), 0.4, Vector3.BACK)).is_equal(Vector3.ZERO)
	var concentric: Vector3 = Enemy.clearing_offset(Vector3(3.0, 0.0, 0.0), 0.4, Vector3.BACK)
	assert_float(concentric.length()).is_greater(0.4)
	assert_float(concentric.y).is_equal(0.0)
	var off_centre: Vector3 = Enemy.clearing_offset(Vector3(3.2, 0.0, 0.0), 0.4, Vector3.BACK)
	assert_float(off_centre.x).override_failure_message("pushes away from the enemy centre").is_greater(0.0)
	var end_position: Vector3 = Vector3(3.0, 0.0, 0.0) + concentric
	assert_vector(Enemy.clearing_offset(end_position, 0.4, Vector3.BACK)).is_equal(Vector3.ZERO)


func test_pass_through_ending_on_an_enemy_centre_does_not_launch_the_player() -> void:
	var main := _spawn_main("rogue")
	await _frames(30)  # the player is settled on the floor
	var player := main.player
	var rest_y: float = player.global_position.y
	player.grant_pass_through(0.3)  # first, so the enemy appears inside the body without being pushed
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = player.global_position
	main.add_child(enemy)
	await _frames(1)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = player.global_position  # exactly concentric
	var max_y: float = player.global_position.y
	for i in range(280):  # the buff, then the restore wait (cap 3 s) until the nudge puts the body clear
		await _frames(1)
		max_y = maxf(max_y, player.global_position.y)
	assert_bool(player.is_pass_through()).override_failure_message("still ghosted after the cap").is_false()
	assert_float(max_y - rest_y).override_failure_message("launched %.2f m up" % (max_y - rest_y)).is_less(0.3)
	var flat: float = Vector2(player.global_position.x - enemy.global_position.x, player.global_position.z - enemy.global_position.z).length()
	assert_float(flat).override_failure_message("still inside the body (%.2f m)" % flat).is_greater_equal(0.8)


# ---- 4a: the soak's "immunity leak" ----

func _seed_with_room_type_at(index: int, room_type: String) -> int:
	for candidate in range(1, 400):
		var rooms: Array[Dictionary] = RunGenerator.generate(candidate, RunConfig.get_config())
		if String(rooms[index]["type"]) == room_type:
			return candidate
	return -1


func _run_room_after_frames(run_seed: int, room_index: int) -> Main:
	var state := RunSession.begin_new_run(run_seed)
	state.room_index = room_index
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	for i in range(10):
		await get_tree().process_frame
	return main


func test_a_new_combat_room_is_not_damage_immune_but_a_rest_room_is_by_design() -> void:
	var combat_seed: int = _seed_with_room_type_at(2, "combat")
	var rest_seed: int = _seed_with_room_type_at(2, "rest")
	assert_int(combat_seed).is_greater(0)
	assert_int(rest_seed).override_failure_message("room 3 can be a rest room (the rest window starts at index 2)").is_greater(0)
	var combat: Main = await _run_room_after_frames(combat_seed, 2)
	assert_str(combat.run_controller.room_type()).is_equal("combat")
	assert_bool(combat.player.health.damage_immune).override_failure_message("a combat room started with the player immune").is_false()
	var rest: Main = await _run_room_after_frames(rest_seed, 2)
	assert_str(rest.run_controller.room_type()).is_equal("rest")
	assert_bool(rest.run_controller.has_choice()).is_true()
	assert_bool(rest.player.health.damage_immune).override_failure_message("the open rest choice protects the player").is_true()
