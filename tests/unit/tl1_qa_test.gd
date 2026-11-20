class_name Tl1QaTest
extends GdUnitTestSuite
## qa review of TL1 (--press holds and aim): gaps the author's suite did not cover.


func after_test() -> void:
	for action: String in ["move_forward", "move_left", "move_right", "move_back", "attack_light"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = false
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_every_press_step_is_a_debug_flag_launch_alongside_other_flags() -> void:
	assert_bool(RunSave.args_suppress(PackedStringArray(["--run-seed=3", "--press=0.5:aim_nearest"]))).is_true()
	assert_bool(RunSave.args_suppress(PackedStringArray(["--run-seed=3"]))).is_false()


func test_no_press_means_no_press_error_and_no_steps() -> void:
	var parsed: Dictionary = CaptureArgs.parse(PackedStringArray(["--run-seed=3", "--screenshot-after=1"]))
	assert_str(String(parsed["press_error"])).is_empty()
	assert_int((parsed["presses"] as Array).size()).is_equal(0)


func test_hold_boundaries() -> void:
	assert_bool(CaptureArgs.parse_press_step("1:move_forward:120").is_empty()).is_false()
	assert_bool(CaptureArgs.parse_press_step("1:move_forward:120.01").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step("-1:move_forward:2").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step("0:aim_off").is_empty()).is_false()
	assert_bool(CaptureArgs.parse_press_step("1:aim_off:2").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step("").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step("1:").is_empty()).is_true()


func test_aim_steps_without_a_player_do_nothing_and_do_not_crash() -> void:
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.0, "action": &"aim_nearest", "hold": 0.0}, {"at": 0.1, "action": &"aim_off", "hold": 0.0}]
	add_child(scripted)
	auto_free(scripted)
	scripted._process(0.2)
	assert_bool(scripted.player == null).is_true()


func test_a_plain_tap_still_releases_after_the_tap_time() -> void:
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.0, "action": &"attack_light", "hold": 0.0}]
	add_child(scripted)
	auto_free(scripted)
	scripted._process(0.01)
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"attack_light")).is_true()
	scripted._process(ScriptedInput.TAP_SECONDS + 0.05)
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"attack_light")).is_false()


## Regression (qa TL1-1): Main swaps itself for a fresh scene on every room change, Try again and reward pick
## (Main.swap_to_fresh_scene). A ScriptedInput freed in the middle of a hold must not leave the action held, or the
## next room's player walks on its own. Fails until ScriptedInput releases its held actions on _exit_tree.
func test_freeing_scripted_input_mid_hold_releases_the_action() -> void:
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.0, "action": &"move_forward", "hold": 5.0}]
	add_child(scripted)
	scripted._process(0.1)
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"move_forward")).is_true()
	remove_child(scripted)
	scripted.free()
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"move_forward")).is_false()
