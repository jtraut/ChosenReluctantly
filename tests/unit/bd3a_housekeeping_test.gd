class_name Bd3aHousekeepingTest
extends GdUnitTestSuite
## BD3a sitting A, housekeeping: RunSave refuses bad hp and reject counts, GamePause.reset() unpauses the tree, a straight (--no-map) run
## never deletes a saved map run, and --run-room refuses what it cannot use.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PATH := "user://tests/bd3a_run_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	Juice.reset()
	GamePause.reset()


func _saved_map_run() -> RunState:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(3)
	state.hp = 20.0
	state.max_hp = 30.0
	assert_bool(RunSave.write(state)).is_true()
	return state


func _write_run_patch(good: Dictionary, patch: Dictionary) -> void:
	var run: Dictionary = good.duplicate(true)
	for key: String in patch.keys():
		run[key] = patch[key]
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": RunSave.SAVE_VERSION, "run": run}))
	file.close()


# ---- RunSave ----

func test_a_save_with_bad_hp_or_rejects_is_refused_with_a_reason() -> void:
	var state: RunState = _saved_map_run()
	var good: Dictionary = state.to_dict()
	var cases: Array[Dictionary] = [{"hp": 0.0}, {"hp": -1.0}, {"hp": 9999.0}, {"rejects_remaining": -5}, {"rejects_remaining": 100000}]
	for patch: Dictionary in cases:
		_write_run_patch(good, patch)
		assert_object(RunSave.read_state()).override_failure_message("%s was accepted" % str(patch)).is_null()
		assert_str(RunSave.last_problem).is_not_empty()
		assert_bool(RunSave.has_save()).is_false()
	# the unedited values still load
	_write_run_patch(good, {})
	assert_object(RunSave.read_state()).is_not_null()
	assert_str(RunSave.last_problem).is_empty()


func test_hp_at_max_and_rejects_at_the_limits_are_fine() -> void:
	var state: RunState = _saved_map_run()
	var good: Dictionary = state.to_dict()
	for patch: Dictionary in [{"hp": 30.0}, {"hp": 0.5}, {"rejects_remaining": 0}, {"rejects_remaining": RunConfig.rejects_per_run()}]:
		_write_run_patch(good, patch)
		assert_object(RunSave.read_state()).override_failure_message("%s was refused" % str(patch)).is_not_null()


# ---- GamePause ----

func test_gamepause_reset_unpauses_the_tree() -> void:
	assert_bool(GamePause.pause()).is_true()
	assert_bool(get_tree().paused).is_true()
	GamePause.reset()
	assert_bool(GamePause.is_paused()).is_false()
	assert_bool(get_tree().paused).is_false()
	Juice.reset()


func test_gamepause_reset_when_not_paused_changes_nothing() -> void:
	GamePause.reset()
	assert_bool(get_tree().paused).is_false()


# ---- a straight run does not delete a saved map run ----

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func test_losing_a_straight_run_leaves_a_saved_map_run_alone() -> void:
	_saved_map_run()
	assert_bool(FileAccess.file_exists(PATH)).is_true()
	RunSession.clear()
	RunSession.map_override = 0  # --no-map
	RunSession.begin_new_run(7)
	var main: Main = _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_bool(RunNodes.active(RunSession.current)).is_false()
	controller._on_player_died()
	assert_str(RunSession.current.outcome).is_equal("lost")
	assert_bool(FileAccess.file_exists(PATH)).override_failure_message("a straight run's loss deleted the map run's save").is_true()


func test_losing_a_map_run_still_deletes_its_save() -> void:
	_saved_map_run()
	RunSession.clear()
	RunSession.map_override = 1
	RunSession.begin_new_run(31)
	var main: Main = _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_bool(RunNodes.active(RunSession.current)).is_true()
	controller._on_player_died()
	assert_bool(FileAccess.file_exists(PATH)).is_false()


# ---- --run-room ----

func test_run_room_refuses_what_it_cannot_use() -> void:
	for arg: String in ["--run-room=abc", "--run-room=", "--run-room", "--run-room=0", "--run-room=-3", "--run-room=1.5", "--run-room=31"]:
		assert_str(MapLaunch.run_room_problem(PackedStringArray([arg]), 30)).override_failure_message("%s was accepted" % arg).is_not_empty()


func test_run_room_accepts_one_to_the_limit() -> void:
	for arg: String in ["--run-room=1", "--run-room=11", "--run-room=30"]:
		assert_str(MapLaunch.run_room_problem(PackedStringArray([arg]), 30)).is_empty()
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--run-seed=3", "--class=wizard"]), 30)).is_empty()


func test_a_one_act_run_refuses_room_eleven() -> void:
	# --acts=1 --run-room=11: the limit is the one act's 10 rooms.
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--acts=1", "--run-room=11"]), 10)).is_not_empty()
	assert_str(MapLaunch.run_room_problem(PackedStringArray(["--acts=1", "--run-room=10"]), 10)).is_empty()
