class_name Map3aSaveTest
extends GdUnitTestSuite
## MAP3 sitting A, step 2: the run save file (RunSave). Pure round trips and bad files with an injected path, then the real RunController writing
## at the map screen and at a room's start, deleting on a win or a loss, and a quit-and-resume giving the same run and the same next room.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PATH := "user://tests/map3a_run_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()


## A map run `rooms` rooms in (first reachable node each time), at the map screen.
func _run_at_map(seed_value: int, rooms: int) -> RunState:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(seed_value)
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	for i in range(rooms):
		var next: Array[int] = RunNodes.reachable_ids(state)
		assert_bool(bool(RunNodes.apply(state, "node:%d" % next[0], ctx)["ok"])).is_true()
		state.hp = 20.0
		state.max_hp = 30.0
		state.gold += 17
		state.record_room({"index": state.room_index, "type": "combat", "wave_id": "combat_intro"}, 20.0, 12.5)
		RunNodes.open(state)
	return state


func _write_raw(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ---- the file ----

func test_save_then_resume_gives_an_equal_run_and_the_same_next_room() -> void:
	var state: RunState = _run_at_map(5, 3)
	assert_bool(RunSave.write(state)).is_true()
	assert_bool(RunSave.has_save()).is_true()
	RunSession.clear()  # quit
	assert_bool(RunSave.load_save()).is_true()
	var resumed: RunState = RunSession.current
	assert_bool(state.equals(resumed)).is_true()
	assert_array(RunNodes.reachable_ids(resumed)).is_equal(RunNodes.reachable_ids(state))
	assert_int(resumed.room_index).is_equal(state.room_index)
	assert_array(resumed.path).is_equal(state.path)
	assert_int(resumed.gold).is_equal(51)
	assert_str(resumed.pending).is_equal(RunState.PENDING_NODE)


func test_a_save_taken_at_a_rooms_start_round_trips_with_no_choice_open() -> void:
	var state: RunState = _run_at_map(6, 2)
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_bool(RunSave.autosave(state)).is_true()
	var back: RunState = RunSave.read_state()
	assert_bool(state.equals(back)).is_true()
	assert_array(back.path).is_equal(state.path)


func test_the_save_survives_relics_and_a_changed_deck() -> void:
	var state: RunState = _run_at_map(7, 2)
	state.add_relic("heavy_sigh")
	state.add_relic("pyre_insurance")
	state.give_up_relic("pyre_insurance")
	state.rejects_remaining = 1
	state.merchant_removals = 2
	assert_bool(RunSave.write(state)).is_true()
	assert_bool(state.equals(RunSave.read_state())).is_true()


func test_delete_save_removes_the_file_and_has_save_goes_false() -> void:
	RunSave.write(_run_at_map(5, 1))
	assert_bool(RunSave.has_save()).is_true()
	assert_bool(RunSave.delete_save()).is_true()
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	assert_bool(RunSave.has_save()).is_false()
	assert_bool(RunSave.delete_save()).is_true()  # nothing to delete is fine


func test_no_file_means_no_save_and_load_changes_nothing() -> void:
	assert_bool(RunSave.has_save()).is_false()
	assert_bool(RunSave.load_save()).is_false()
	assert_object(RunSession.current).is_null()


func test_autosave_only_at_a_boundary_of_a_live_map_run() -> void:
	var fresh: RunState = _run_at_map(5, 0)  # picked nothing yet
	assert_bool(RunSave.autosave(fresh)).is_false()
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	var live: RunState = _run_at_map(5, 2)
	live.pending = RunState.PENDING_REWARD
	live.offer = ["rogue_quick_slash"] as Array[String]
	assert_bool(RunSave.autosave(live)).is_false()
	live.pending = RunState.PENDING_NODE
	live.offer = []
	live.outcome = "won"
	assert_bool(RunSave.autosave(live)).is_false()
	live.outcome = ""
	assert_bool(RunSave.autosave(live)).is_true()
	var straight: RunState = RunState.new_run(3, ["rogue_quick_slash"] as Array[String], 3)
	assert_bool(RunSave.is_boundary(straight)).is_false()
	assert_bool(RunSave.is_boundary(null)).is_false()


func test_nothing_is_written_when_persistence_is_off() -> void:
	RunSave.persist_override = false
	assert_bool(RunSave.autosave(_run_at_map(5, 2))).is_false()
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	RunSave.persist_override = true
	RunSave.write(_run_at_map(5, 2))
	RunSave.persist_override = false
	assert_bool(RunSave.has_save()).is_false()
	assert_bool(RunSave.delete_save()).is_false()
	assert_bool(FileAccess.file_exists(PATH)).is_true()  # a tool or a sim never deletes a player's save


func test_debug_launch_flags_suppress_saving() -> void:
	for flag: String in ["--run-room=4", "--run-node=33", "--run-gold=200", "--full-deck", "--deck=fire-heavy-rogue", "--relics=a+b", "--scenario=hp_bars"]:
		assert_bool(RunSave.args_suppress(PackedStringArray([flag]))).override_failure_message(flag).is_true()
	for flag: String in ["--run-seed=7", "--class=wizard", "--map", "--no-map"]:
		assert_bool(RunSave.args_suppress(PackedStringArray([flag]))).override_failure_message(flag).is_false()
	assert_bool(RunSave.args_suppress(PackedStringArray())).is_false()
	RunSave.persist_override = null
	RunSave.suppressed = true
	assert_bool(RunSave.persistence_enabled()).is_false()


# ---- bad files: ignored with a warning, never a crash, left on disk ----

func _assert_ignored(label: String) -> void:
	assert_bool(RunSave.has_save()).override_failure_message(label + " was accepted").is_false()
	assert_bool(RunSave.load_save()).override_failure_message(label + " loaded").is_false()
	assert_object(RunSession.current).override_failure_message(label + " set a run").is_null()
	assert_str(RunSave.last_problem).override_failure_message(label + " gave no reason").is_not_empty()
	assert_bool(FileAccess.file_exists(PATH)).is_true()


func _good_wrapper() -> Dictionary:
	var run: Variant = JSON.parse_string(_run_at_map(5, 2).to_json())
	RunSession.clear()  # building the run made it the live one; a rejected file must leave the session empty
	return {"save_version": RunSave.SAVE_VERSION, "run": run}


func test_unreadable_or_wrongly_shaped_files_are_ignored() -> void:
	for text: String in ["", "garbage {{", "[1, 2, 3]", "\"text\"", "null", "{}", "{\"save_version\": 1}", "{\"save_version\": 1, \"run\": 5}", "{\"save_version\": 1, \"run\": {}}"]:
		_write_raw(text)
		_assert_ignored("file '%s'" % text)
		RunSession.clear()


func test_a_wrong_or_missing_version_is_ignored() -> void:
	for version: Variant in [null, 0, 2, "1", [1], {"a": 1}]:
		var wrapper: Dictionary = _good_wrapper()
		wrapper["save_version"] = version
		_write_raw(JSON.stringify(wrapper))
		_assert_ignored("save_version %s" % str(version))
	var no_version: Dictionary = _good_wrapper()
	no_version.erase("save_version")
	_write_raw(JSON.stringify(no_version))
	_assert_ignored("no version")


func test_a_damaged_run_inside_a_good_wrapper_is_ignored() -> void:
	var cases: Dictionary = {
		"deck of objects": func(run: Dictionary) -> void: run["deck"] = [{"a": 1}],
		"unknown card": func(run: Dictionary) -> void: run["deck"] = ["no_such_card"],
		"empty deck": func(run: Dictionary) -> void: run["deck"] = [],
		"unknown relic": func(run: Dictionary) -> void: run["relics"] = ["no_such_relic"],
		"relic held and given up": func(run: Dictionary) -> void:
			run["relics"] = ["heavy_sigh"]
			run["relics_given_up"] = ["heavy_sigh"],
		"unknown character": func(run: Dictionary) -> void: run["character"] = "bard",
		"map erased": func(run: Dictionary) -> void: run.erase("map"),
		"map damaged": func(run: Dictionary) -> void: run["map"] = {"nodes": "x", "edges": []},
		"path off the map": func(run: Dictionary) -> void: run["path"] = [999999],
		"path and room disagree": func(run: Dictionary) -> void: run["room_index"] = 7,
		"already won": func(run: Dictionary) -> void: run["outcome"] = "won",
		"already lost": func(run: Dictionary) -> void: run["outcome"] = "lost",
		"a reward left open": func(run: Dictionary) -> void:
			run["pending"] = "reward"
			run["offer"] = ["rogue_quick_slash"],
		"hp is text": func(run: Dictionary) -> void: run["hp"] = "full",
		"run format from the future": func(run: Dictionary) -> void: run["version"] = 99,
		"choice_log is text": func(run: Dictionary) -> void: run["choice_log"] = "x",
	}
	for label: String in cases:
		var wrapper: Dictionary = _good_wrapper()
		(cases[label] as Callable).call(wrapper["run"])
		_write_raw(JSON.stringify(wrapper))
		_assert_ignored(label)
		RunSession.clear()
	# the same wrapper, undamaged, loads
	_write_raw(JSON.stringify(_good_wrapper()))
	assert_bool(RunSave.has_save()).is_true()


func test_a_bad_file_does_not_stop_a_fresh_save_replacing_it() -> void:
	_write_raw("garbage")
	assert_bool(RunSave.has_save()).is_false()
	assert_bool(RunSave.write(_run_at_map(5, 2))).is_true()
	assert_bool(RunSave.has_save()).is_true()


# ---- through the real controller ----

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
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
	await _frames(2)


func _latest_main(except_id: int) -> Main:
	var found: Main = null
	for child in get_children():
		if child is Main and child.get_instance_id() != except_id and not child.is_queued_for_deletion():
			found = child as Main
	return found


func test_the_controller_saves_at_a_rooms_start_and_at_the_map_screen_and_resume_restarts_the_room() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	var main: Main = _spawn()
	var main_id: int = main.get_instance_id()
	await _frames()
	# the very first map screen is not saved: there is nothing to resume yet, and it must not overwrite an older save
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	var first_pick: int = main.run_controller.reachable_nodes()[0]
	main.run_controller.pick_node(first_pick)
	await _frames()
	var room_one: Main = _latest_main(main_id)
	# room 1 has started: saved with the node picked and no choice open
	var at_start: RunState = RunSave.read_state()
	assert_object(at_start).is_not_null()
	assert_str(at_start.pending).is_equal(RunState.PENDING_NONE)
	assert_array(at_start.path).is_equal([first_pick])
	assert_bool(at_start.equals(state)).is_true()
	# win it, take the reward: the map screen saves again
	await _win_room(room_one)
	room_one.run_controller.choose("skip")
	var at_map: RunState = RunSave.read_state()
	assert_str(at_map.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(at_map.equals(state)).is_true()
	assert_int(at_map.gold).is_greater(0)
	# quit and resume at the map screen: same run, same choices on offer
	var expected_next: Array[int] = RunNodes.reachable_ids(state)
	var expected_json: String = state.to_json()
	var gold: int = state.gold
	RunSession.clear()
	room_one.queue_free()
	await _frames()
	assert_bool(RunSave.load_save()).is_true()
	assert_str(RunSession.current.to_json()).is_equal(expected_json)
	var resumed: Main = _spawn()
	await _frames()
	assert_array(resumed.run_controller.reachable_nodes()).is_equal(expected_next)
	assert_int(resumed.run_controller.gold()).is_equal(gold)
	# pick the next room, then "quit mid-fight": the room-start save resumes into that same room, fight not yet won
	var second_pick: int = expected_next[0]
	var resumed_id: int = resumed.get_instance_id()
	resumed.run_controller.pick_node(second_pick)
	await _frames()
	var room_two: Main = _latest_main(resumed_id)
	assert_object(room_two).is_not_null()
	var saved_two: RunState = RunSave.read_state()
	assert_str(saved_two.pending).is_equal(RunState.PENDING_NONE)
	assert_array(saved_two.path).is_equal([first_pick, second_pick])
	var two_id: int = room_two.get_instance_id()
	RunSession.clear()
	room_two.queue_free()
	await _frames()
	assert_bool(RunSave.load_save()).is_true()
	var again: Main = _spawn()
	await _frames()
	assert_int(again.run_controller.current_node_id()).is_equal(second_pick)
	assert_bool(again.run_controller.has_choice()).is_false()
	assert_bool(again.run_controller.is_cleared()).is_false()
	assert_int(again.get_instance_id()).is_not_equal(two_id)


func test_losing_the_run_deletes_the_save() -> void:
	RunSession.map_override = 1
	RunSession.begin_new_run(31)
	var main: Main = _spawn()
	var main_id: int = main.get_instance_id()
	await _frames()
	main.run_controller.pick_node(main.run_controller.reachable_nodes()[0])
	await _frames()
	assert_bool(FileAccess.file_exists(PATH)).is_true()
	var room: Main = _latest_main(main_id)
	room.run_controller._on_player_died()
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	assert_bool(RunSave.has_save()).is_false()


func test_winning_the_run_deletes_the_save() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)  # the boss room, with the path laid along the first route
	var main: Main = _spawn()
	await _frames()
	assert_bool(FileAccess.file_exists(PATH)).is_true()  # a non-fresh scene saves at the room's start
	await _win_room(main)
	assert_str(state.outcome).is_equal("won")
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_a_fresh_launch_scene_never_overwrites_an_existing_save() -> void:
	var older: RunState = _run_at_map(9, 3)
	RunSave.write(older)
	var before: String = FileAccess.get_file_as_string(PATH)
	RunSession.clear()
	RunSession.map_override = 1
	var main: Main = _spawn()  # no live run: this is a fresh launch (the player has not pressed Continue)
	await _frames()
	assert_str(FileAccess.get_file_as_string(PATH)).is_equal(before)
	assert_bool(main.run_controller != null).is_true()
