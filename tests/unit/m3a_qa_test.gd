class_name M3aQaTest
extends GdUnitTestSuite
## qa review of Milestone 3a (run structure). Gaps found on top of the gameplay-dev and ux-designer suites:
## generator position coverage and wave-list rule, malformed-data fixtures for RunConfig and RunState, the
## coupling rule (no card ids in the run code), reset of shuffle bag / statuses / zones across a room swap,
## Continue spam, death in the same frame as the last kill, a quit-like free mid-transition, node counts across
## eight room swaps, and a check that the bot sim's N3 detectors fire on constructed bad cases (not vacuous).

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const WAVE_SIM_PATH := "res://tools/wave_sim.gd"


func before_test() -> void:
	RunSession.clear()


func after_test() -> void:
	RunSession.clear()
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0


func _shipped() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RunConfig.PATH))


func _cards() -> Array[String]:
	var ids: Array[String] = []
	for card: Variant in CardDatabase.all_cards():
		ids.append(String((card as Dictionary)["id"]))
	return ids


const KNOWN_ENEMIES: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem"]


func _problems(config: Dictionary) -> Array[String]:
	return RunConfig.validate(config, KNOWN_ENEMIES, _cards())


# ---- Generator ----

func test_generator_uses_every_legal_position_and_only_those() -> void:
	var config := _shipped()
	var elite_at: Dictionary = {}
	var rest_at: Dictionary = {}
	for seed_value in range(1, 1501):
		for room: Dictionary in RunGenerator.generate(seed_value, config):
			if room["type"] == "elite":
				elite_at[int(room["index"])] = true
			elif room["type"] == "rest":
				rest_at[int(room["index"])] = true
	var elite_keys: Array = elite_at.keys()
	var rest_keys: Array = rest_at.keys()
	elite_keys.sort()
	rest_keys.sort()
	assert_array(elite_keys).is_equal([3, 4, 5, 6])  # rooms 4-7 (index 3-6); never 0 and never the boss slot
	assert_array(rest_keys).is_equal([2, 3, 4, 5, 6])  # rooms 3-7


func test_generator_does_not_repeat_a_wave_list_when_another_fits() -> void:
	var config := _shipped()
	for seed_value in range(1, 600):
		var rooms := RunGenerator.generate(seed_value, config)
		var last_wave := ""
		for room: Dictionary in rooms:
			if room["type"] == "rest":
				continue
			var options := RunConfig.variants_for(int(room["index"]), (config["rooms"] as Dictionary)[room["type"]])
			var others := options.filter(func(v: Dictionary) -> bool: return String(v["id"]) != last_wave)
			if not others.is_empty():
				assert_str(String(room["wave_id"])).override_failure_message("seed %d room %d repeats '%s' although %d other list(s) fit" % [seed_value, int(room["index"]) + 1, last_wave, others.size()]).is_not_equal(last_wave)
			last_wave = String(room["wave_id"])


func test_generator_ignores_global_rng_state() -> void:
	var config := _shipped()
	var first := RunGenerator.generate(31337, config)
	seed(1)
	randi()
	randomize()
	var second := RunGenerator.generate(31337, config)
	assert_array(first).is_equal(second)


func test_generator_seed_zero_and_the_seed_limit_work() -> void:
	var config := _shipped()
	for seed_value in [0, RunState.SEED_LIMIT]:
		var rooms := RunGenerator.generate(seed_value, config)
		assert_int(rooms.size()).is_equal(8)
		assert_str(rooms[7]["type"]).is_equal("boss")


# ---- RunConfig: malformed data fails loud and never crashes ----

func test_validate_survives_every_top_level_key_missing_or_wrongly_typed() -> void:
	var keys: Array = _shipped().keys()
	for key: String in keys:
		var removed := _shipped()
		removed.erase(key)
		assert_array(_problems(removed)).override_failure_message("removing '%s' was not reported" % key).is_not_empty()
		for bad: Variant in ["text", 7, null, [], {}, true]:
			var swapped := _shipped()
			swapped[key] = bad
			# Some swaps are legal (an empty ui object is not; a number for a number is); the point is no crash.
			var problems := _problems(swapped)
			if typeof(bad) == TYPE_STRING or bad == null or typeof(bad) == TYPE_BOOL:
				assert_array(problems).override_failure_message("'%s' = %s was accepted" % [key, str(bad)]).is_not_empty()


func test_validate_rejects_an_empty_config_and_garbage_numbers() -> void:
	assert_array(_problems({})).is_not_empty()
	for path: Array in [["rest_heal_fraction"], ["rejects_per_run"], ["tiers", "elite", "hp_multiplier"], ["tiers", "boss", "scale"]]:
		for bad: Variant in [NAN, INF, -INF, "1", null, 1.0e30]:
			var config := _shipped()
			var node: Dictionary = config
			for i in range(path.size() - 1):
				node = node[path[i]]
			node[path[path.size() - 1]] = bad
			var problems := _problems(config)
			assert_array(problems).override_failure_message("%s = %s was accepted" % [str(path), str(bad)]).is_not_empty()


func test_validate_reports_a_stage_with_no_spawns_and_an_unreachable_wave_gate() -> void:
	var config := _shipped()
	config["rooms"]["combat"][0]["stages"][0]["spawns"] = []
	assert_array(_problems(config)).is_not_empty()
	config = _shipped()
	config["rooms"]["combat"][0]["stages"] = []
	assert_array(_problems(config)).is_not_empty()


func test_a_short_starting_deck_is_reported_with_the_shortfall() -> void:
	var config := _shipped()
	config["starting_deck"] = ["rogue_quick_slash", "rogue_flurry", "fire_fireball"]
	var problems := RunConfig.deck_problems(config)
	assert_array(problems).has_size(1)
	assert_str(problems[0]).contains("needs")


func test_a_run_with_an_invalid_config_falls_back_to_the_arena_instead_of_crashing() -> void:
	# The loader reports problems and returns {}; RunSession would then hand out an empty deck, so Main must refuse.
	# Pinned through the pure switch: the fallback branch is guarded by RunConfig.is_valid() in Main._setup_run_mode.
	var source := FileAccess.get_file_as_string("res://src/main/Main.gd")
	assert_bool(source.contains("if RunConfig.is_valid():")).is_true()
	assert_bool(source.contains("falling back to the endless arena")).is_true()


# ---- RunState: malformed save data is refused loudly ----

func test_run_state_from_dict_refuses_each_missing_key() -> void:
	var good := RunState.new_run(5, RunConfig.starting_deck(), 3).to_dict()
	for key: String in ["seed", "room_index", "hp", "max_hp", "deck", "rejects_remaining", "history"]:
		var broken: Dictionary = good.duplicate(true)
		broken.erase(key)
		assert_object(RunState.from_dict(broken)).override_failure_message("missing '%s' was accepted" % key).is_null()


func test_run_state_from_json_refuses_garbage() -> void:
	assert_object(RunState.from_json("not json")).is_null()
	assert_object(RunState.from_json("[1,2,3]")).is_null()
	assert_object(RunState.from_json("")).is_null()
	var good := RunState.new_run(5, RunConfig.starting_deck(), 3).to_dict()
	good["deck"] = "rogue_quick_slash"
	assert_object(RunState.from_dict(good)).is_null()
	good = RunState.new_run(5, RunConfig.starting_deck(), 3).to_dict()
	good["history"] = [1, 2]
	assert_object(RunState.from_dict(good)).is_null()


func test_run_state_round_trips_edge_values() -> void:
	var state := RunState.new_run(RunState.SEED_LIMIT, RunConfig.starting_deck(), 0)
	# Unset HP (-1) and an empty history survive; so does a finished run.
	var copy: RunState = RunState.from_json(state.to_json())
	assert_bool(state.equals(copy)).is_true()
	assert_bool(copy.has_hp()).is_false()
	state.outcome = "won"
	state.hp = 0.5
	state.max_hp = 30.0
	state.room_index = 7
	copy = RunState.from_json(state.to_json())
	assert_bool(state.equals(copy)).is_true()
	assert_str(copy.outcome).is_equal("won")
	assert_int(copy.seed_value).is_equal(RunState.SEED_LIMIT)
	assert_bool(copy.is_over()).is_true()


func test_new_run_seeds_stay_in_range_and_vary() -> void:
	var seen: Dictionary = {}
	for i in range(60):
		var state := RunSession.begin_new_run()
		assert_int(state.seed_value).is_between(0, RunState.SEED_LIMIT)
		seen[state.seed_value] = true
	assert_int(seen.size()).is_greater(50)


# ---- Coupling rule ----

func test_run_loop_code_names_no_card() -> void:
	var files: Array[String] = []
	for dir_path: String in ["res://src/run", "res://src/ui"]:
		for file_name in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".gd") and (dir_path == "res://src/run" or file_name.begins_with("Run")):
				files.append(dir_path + "/" + file_name)
	assert_int(files.size()).is_greater(8)
	var ids := _cards()
	assert_int(ids.size()).is_greater(20)
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		for card_id in ids:
			assert_bool(source.contains(card_id)).override_failure_message("%s names the card '%s'" % [path, card_id]).is_false()
		for pool_id in ["rogue", "wizard"]:
			assert_bool(source.contains("\"%s\"" % pool_id)).override_failure_message("%s names the pool '%s'" % [path, pool_id]).is_false()


# ---- Scene-level behaviour ----

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _tiny_room() -> Dictionary:
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	return table


func _spawn_tiny_room(main: Main) -> Array[Enemy]:
	main.enemy_spawner.configure_room(_tiny_room(), 1)
	main.enemy_spawner._process(1.0)
	var enemies: Array[Enemy] = []
	for child in main.get_children():
		if child is Enemy:
			enemies.append(child as Enemy)
	return enemies


func _kill(enemies: Array[Enemy]) -> void:
	for enemy in enemies:
		enemy.health.take_damage(100000.0)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _next_main(old_id: int) -> Main:
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			return child as Main
	return null


func _mains() -> int:
	var count := 0
	for child in get_children():
		if child is Main and not child.is_queued_for_deletion():
			count += 1
	return count


func test_a_room_swap_resets_the_bag_statuses_and_zones_and_keeps_nothing_alive() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	# Dirty the room: draw cards from every slot (bag mid-cycle), burn the player, put a zone down, leave an enemy.
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var slot := main.player.card_slots.get_slot(slot_type)
		slot.use_card(0.0)
		slot.cooldown_remaining = 0.0
		slot.use_card(0.0)
	main.player.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 5.0, null)
	assert_bool(main.player.status_manager.has_status("burn")).is_true()
	var wall: Dictionary = CardDatabase.get_card("fire_wall")
	var context := EffectContext.new(main.player, main, "player")
	context.rng = main.player.status_rng
	for effect: Dictionary in wall["effects"]:
		EffectTemplates.execute(effect["template"], effect["params"], context)
	assert_int(ZoneManager.for_world(main).live_count()).is_greater(0)
	var enemies := _spawn_tiny_room(main)
	assert_int(enemies.size()).is_equal(1)
	_kill(enemies)
	await _frames(3)
	assert_bool(main.run_controller.is_cleared()).is_true()
	var old_id := main.get_instance_id()
	main.run_controller.continue_to_next_room()
	await _frames(3)
	var next := _next_main(old_id)
	assert_object(next).is_not_null()
	auto_free(next)
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var slot := next.player.card_slots.get_slot(slot_type)
		var owned := slot.owned_card_ids.size()
		assert_int(slot.draw_pile.size()).override_failure_message("%s: bag not fresh (draw %d of %d)" % [slot_type, slot.draw_pile.size(), owned]).is_equal(owned - 1)
		assert_int(slot.discard_pile.size()).is_equal(0)
		assert_float(slot.cooldown_remaining).is_equal(0.0)
	assert_bool(next.player.status_manager.has_status("burn")).is_false()
	var zones := ZoneManager.for_world(next)
	assert_bool(zones == null or zones.live_count() == 0).is_true()
	var live_enemies := 0
	for child in next.get_children():
		if child is Enemy:
			live_enemies += 1
	assert_int(live_enemies).is_equal(0)
	assert_bool(next.player.health.damage_immune).is_false()
	assert_bool(next.run_controller.is_cleared()).is_false()
	assert_bool(next.player.is_dead()).is_false()


func test_continue_spam_swaps_exactly_once() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	_kill(_spawn_tiny_room(main))
	await _frames(3)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	assert_bool(screen.is_open()).is_true()
	var old_id := main.get_instance_id()
	for i in range(6):
		screen.button.pressed.emit()
		main.run_controller.continue_to_next_room()
	await _frames(4)
	assert_int(RunSession.current.room_index).is_equal(1)  # one step, not six
	assert_int(_mains()).is_equal(1)
	var next := _next_main(old_id)
	assert_object(next).is_not_null()
	auto_free(next)
	assert_int(next.run_controller.room_number()).is_equal(2)
	assert_int(RunSession.current.history.size()).is_equal(1)


func test_dying_in_the_frame_of_the_last_kill_is_a_loss_not_a_clear() -> void:
	for player_first in [true, false]:
		RunSession.clear()
		RunSession.begin_new_run(42)
		var main := _spawn()
		await _frames(1)
		var enemies := _spawn_tiny_room(main)
		var lost: Array[int] = []
		var cleared: Array[int] = []
		main.run_controller.run_lost.connect(func() -> void: lost.append(1))
		main.run_controller.room_cleared.connect(func(_s: Dictionary) -> void: cleared.append(1))
		if player_first:
			main.player.health.take_damage(100000.0)
			_kill(enemies)
		else:
			_kill(enemies)
			main.player.health.take_damage(100000.0)
		await _frames(4)
		assert_array(lost).override_failure_message("player_first=%s: no loss" % str(player_first)).has_size(1)
		assert_array(cleared).override_failure_message("player_first=%s: also reported a clear" % str(player_first)).is_empty()
		assert_str(RunSession.current.outcome).is_equal("lost")
		assert_int(RunSession.current.history.size()).is_equal(0)
		assert_bool((main.get_node("RoomClearedScreen") as RunPromptScreen).is_open()).is_false()
		assert_bool((main.get_node("WinScreen") as RunPromptScreen).is_open()).is_false()


func test_dying_on_the_last_room_in_the_frame_of_the_last_kill_does_not_win() -> void:
	var state := RunSession.begin_new_run(42)
	state.room_index = 7
	var main := _spawn()
	await _frames(1)
	var enemies := _spawn_tiny_room(main)
	var wins: Array[int] = []
	main.run_controller.run_won.connect(func() -> void: wins.append(1))
	_kill(enemies)
	main.player.health.take_damage(100000.0)
	await _frames(4)
	assert_array(wins).is_empty()
	assert_str(RunSession.current.outcome).is_equal("lost")
	assert_bool((main.get_node("WinScreen") as RunPromptScreen).is_open()).is_false()


func test_clearing_a_room_while_paused_shows_the_prompt_only_after_resume() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	var enemies := _spawn_tiny_room(main)
	GamePause.pause()
	_kill(enemies)
	await _frames(3)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	# The tree is paused, so the controller does not tick; nothing may be on screen over the pause.
	assert_bool(screen.is_open()).is_false()
	GamePause.resume()
	await _frames(4)
	assert_bool(main.run_controller.is_cleared()).is_true()
	assert_bool(screen.is_open()).is_true()


func test_freeing_the_scene_right_after_continue_is_safe() -> void:
	# Quitting during the deferred swap: the old scene is freed before the swap callback runs.
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	_kill(_spawn_tiny_room(main))
	await _frames(3)
	main.run_controller.continue_to_next_room()
	main.get_parent().remove_child(main)
	main.free()
	await _frames(4)
	assert_int(RunSession.current.room_index).is_equal(1)
	assert_bool(RunSession.current.is_over()).is_false()
	assert_int(_mains()).is_equal(0)  # nothing half-built was left behind


func test_eight_rooms_of_swaps_leave_no_nodes_behind() -> void:
	var state := RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(2)
	var baseline_nodes := -1
	var baseline_orphans := -1
	var rooms := 0
	while true:
		rooms += 1
		var controller := main.run_controller
		assert_object(controller).is_not_null()
		if controller.room_type() != "rest":
			_kill(_spawn_tiny_room(main))
		await _frames(4)
		assert_bool(controller.is_cleared()).override_failure_message("room %d never cleared" % rooms).is_true()
		if controller.is_last_room():
			break
		if rooms == 2:
			await _frames(2)
			baseline_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			baseline_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var old_id := main.get_instance_id()
		controller.continue_to_next_room()
		await _frames(4)
		main = _next_main(old_id)
		assert_object(main).is_not_null()
		auto_free(main)
	assert_int(rooms).is_equal(8)
	assert_str(state.outcome).is_equal("won")
	assert_int(state.history.size()).is_equal(8)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	# The test node itself keeps the dead scenes' siblings until after_test, so allow a small margin, not growth per room.
	assert_int(nodes - baseline_nodes).override_failure_message("node count grew from %d to %d over 6 swaps" % [baseline_nodes, nodes]).is_less(120)
	assert_int(orphans - baseline_orphans).is_less_equal(0)
	assert_int(Enemy._roster.size()).override_failure_message("enemy roster not empty after the run").is_equal(0)


# ---- The bot sim's N3 detectors fire on constructed bad cases ----

func _sim_with_player() -> Array:
	var main := _spawn()
	main.enemy_spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var sim: Node = (load(WAVE_SIM_PATH) as GDScript).new()
	sim._player = main.player
	auto_free(sim)
	return [sim, main]


func test_sim_flags_a_negative_cooldown() -> void:
	var pair := _sim_with_player()
	var sim: Node = pair[0]
	var slot: CardSlot = (pair[1] as Main).player.card_slots.get_slot("attack_single")
	slot.cooldown_remaining = -0.5
	sim._check_cooldowns(1, {"index": 0})
	assert_array(sim._issues).is_not_empty()
	assert_str(String(sim._issues[0])).contains("stuck/invalid cooldown")


func test_sim_flags_a_cooldown_longer_than_its_own_duration() -> void:
	var pair := _sim_with_player()
	var sim: Node = pair[0]
	var slot: CardSlot = (pair[1] as Main).player.card_slots.get_slot("utility")
	slot.last_cooldown_duration = 2.0
	slot.cooldown_remaining = 9.0
	sim._check_cooldowns(1, {"index": 0})
	assert_array(sim._issues).is_not_empty()


func test_sim_flags_a_cooldown_frozen_for_ten_seconds_and_not_a_running_one() -> void:
	var pair := _sim_with_player()
	var sim: Node = pair[0]
	var slot: CardSlot = (pair[1] as Main).player.card_slots.get_slot("movement")
	# A healthy, draining cooldown never trips it, however long it is watched.
	slot.last_cooldown_duration = 60.0
	for step in range(40):
		sim._sim_time = float(step)
		slot.cooldown_remaining = 50.0 - float(step)
		sim._check_cooldowns(1, {"index": 0})
	assert_array(sim._issues).is_empty()
	# A frozen one trips after 10 s.
	slot.last_cooldown_duration = 3.0
	for step in range(14):
		sim._sim_time = float(step)
		slot.cooldown_remaining = 3.0
		sim._check_cooldowns(1, {"index": 0})
	assert_array(sim._issues).is_not_empty()
	assert_str(String(sim._issues[0])).contains("frozen")


func test_sim_flags_an_empty_deck_and_an_empty_slot() -> void:
	var pair := _sim_with_player()
	var sim: Node = pair[0]
	var main: Main = pair[1]
	main.player.card_slots.set_deck([] as Array[String])
	sim._begin_run_room(1, {"index": 0})
	Engine.time_scale = 1.0
	var joined := "\n".join(sim._issues)
	assert_str(joined).contains("empty deck")
	assert_str(joined).contains("the deck is empty")


# ---- qa N5: transitions work with no current_scene (VpCapture hosts Main in a SubViewport) ----

func test_room_transition_and_try_again_work_inside_a_sub_viewport() -> void:
	RunSession.begin_new_run(42)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	add_child(viewport)
	auto_free(viewport)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	viewport.add_child(main)
	await _frames(2)
	assert_bool(get_tree().current_scene == main).is_false()  # the real VpCapture situation
	_kill(_spawn_tiny_room(main))
	await _frames(3)
	assert_bool(main.run_controller.is_cleared()).is_true()
	var old_id := main.get_instance_id()
	main.run_controller.continue_to_next_room()
	await _frames(4)
	var next: Main = null
	for child in viewport.get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			next = child as Main
	assert_object(next).is_not_null()
	assert_int(next.run_controller.room_number()).is_equal(2)
	# Death then Try again in the same host.
	var seed_before := RunSession.current.seed_value
	next.player.health.take_damage(100000.0)
	var dead_id := next.get_instance_id()
	next.restart_arena()
	await _frames(4)
	var third: Main = null
	for child in viewport.get_children():
		if child is Main and child.get_instance_id() != dead_id and not child.is_queued_for_deletion():
			third = child as Main
	assert_object(third).is_not_null()
	assert_int(third.run_controller.room_number()).is_equal(1)
	assert_bool(RunSession.current.seed_value == seed_before).is_false()
