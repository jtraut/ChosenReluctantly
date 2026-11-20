class_name Tl1PressTest
extends GdUnitTestSuite
## TL1: --press holds an action for N seconds and aims at the nearest live enemy, so a scripted fight can be played.


func after_test() -> void:
	for action: String in ["move_forward", "move_left", "move_right", "move_back"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = false
		Input.parse_input_event(event)


func test_parse_hold_tap_and_aim_steps() -> void:
	var parsed: Dictionary = CaptureArgs.parse(PackedStringArray(["--press=0.5:dodge,1:move_forward:2.5,1:move_left:2.5,3:aim_nearest,9:aim_off"]))
	assert_str(String(parsed["error"])).is_empty()
	assert_str(String(parsed["press_error"])).is_empty()
	var presses: Array[Dictionary] = parsed["presses"]
	assert_int(presses.size()).is_equal(5)
	assert_float(float(presses[0]["hold"])).is_equal(0.0)  # a plain tap is unchanged
	assert_str(String(presses[1]["action"])).is_equal("move_forward")
	assert_float(float(presses[1]["hold"])).is_equal(2.5)
	assert_float(float(presses[1]["at"])).is_equal(1.0)
	assert_str(String(presses[3]["action"])).is_equal("aim_nearest")


func test_bad_press_values_are_reported() -> void:
	for bad: String in ["--press=1:move_forward:0", "--press=1:move_forward:-2", "--press=1:move_forward:x", "--press=1:move_forward:999",
			"--press=1:aim_nearest:2", "--press=1:a:b:c", "--press=1:aim_somewhere", "--press=", "--press"]:
		var parsed: Dictionary = CaptureArgs.parse(PackedStringArray([bad]))
		assert_str(String(parsed["press_error"])).override_failure_message(bad).is_not_empty()
		assert_str(String(parsed["error"])).override_failure_message(bad).is_not_empty()


func test_press_is_a_debug_flag() -> void:
	assert_bool(RunSave.args_suppress(PackedStringArray(["--press=1:move_forward:2"]))).is_true()
	assert_bool(RunSave.DEBUG_FLAG_PREFIXES.has("--press")).is_true()


func test_a_hold_presses_then_releases_after_n_seconds() -> void:
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.5, "action": &"move_forward", "hold": 1.0}, {"at": 0.5, "action": &"move_left", "hold": 0.4}]
	add_child(scripted)
	auto_free(scripted)
	scripted._process(0.4)
	Input.flush_buffered_events()  # parse_input_event is buffered until a frame; the game flushes it every frame
	assert_bool(Input.is_action_pressed(&"move_forward")).is_false()  # not yet
	scripted._process(0.2)  # t = 0.6: both down (a diagonal)
	Input.flush_buffered_events()  # parse_input_event is buffered until a frame; the game flushes it every frame
	assert_bool(Input.is_action_pressed(&"move_forward")).is_true()
	assert_bool(Input.is_action_pressed(&"move_left")).is_true()
	scripted._process(0.4)  # t = 1.0: the shorter hold (to 0.9) is over, the long one (to 1.5) is not
	Input.flush_buffered_events()  # parse_input_event is buffered until a frame; the game flushes it every frame
	assert_bool(Input.is_action_pressed(&"move_left")).is_false()
	assert_bool(Input.is_action_pressed(&"move_forward")).is_true()
	scripted._process(0.6)  # t = 1.6
	Input.flush_buffered_events()
	Input.flush_buffered_events()  # parse_input_event is buffered until a frame; the game flushes it every frame
	assert_bool(Input.is_action_pressed(&"move_forward")).is_false()


func test_nearest_point_ignores_height_and_handles_none() -> void:
	var points: Array[Vector3] = [Vector3(5, 0, 0), Vector3(1, 9, 1), Vector3(-3, 0, 0)]
	assert_vector(ScriptedInput.nearest_point(Vector3.ZERO, points) as Vector3).is_equal(Vector3(1, 9, 1))
	assert_object(ScriptedInput.nearest_point(Vector3.ZERO, [] as Array[Vector3])).is_null()


func test_aim_follows_the_nearest_live_enemy() -> void:
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	var player: Player = main.player
	player.global_position = Vector3.ZERO
	var near: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	var far: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	main.add_child(near)
	main.add_child(far)
	near.global_position = Vector3(2, 0, 0)
	far.global_position = Vector3(6, 0, 0)
	var scripted := ScriptedInput.new()
	scripted.player = player
	scripted.presses = [{"at": 0.0, "action": &"aim_nearest", "hold": 0.0}]
	main.add_child(scripted)
	scripted._process(0.0)
	assert_vector(player.get_aim_point() as Vector3).is_equal(near.global_position)
	near.health.take_damage(99999.0)
	scripted._process(0.1)
	assert_vector(player.get_aim_point() as Vector3).is_equal(far.global_position)  # the dead one is skipped
	scripted.presses = [{"at": 0.0, "action": &"aim_off", "hold": 0.0}]
	scripted._next = 0
	scripted._process(0.1)
	assert_object(player.aim_point_override).is_null()
