class_name Tl3bQaTest
extends GdUnitTestSuite
## qa review of TL3b: the raw F13 key of `any_key` matches no InputMap action (so it cannot fire a bound action), the older --press forms parse as before,
## and the --run-hp parser edge cases.


func test_f13_matches_no_input_action() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F13
	event.physical_keycode = KEY_F13
	event.pressed = true
	for action: StringName in InputMap.get_actions():
		assert_bool(InputMap.event_is_action(event, action, true)).override_failure_message("F13 matches action %s" % action).is_false()
		assert_bool(event.is_action(action)).override_failure_message("F13 is_action %s" % action).is_false()


func test_older_press_forms_are_unchanged() -> void:
	var tap: Dictionary = CaptureArgs.parse_press_step("0.5:dodge")
	assert_str(String(tap["action"])).is_equal("dodge")
	assert_float(float(tap["hold"])).is_equal(0.0)
	var hold: Dictionary = CaptureArgs.parse_press_step("1:move_forward:2.5")
	assert_float(float(hold["hold"])).is_equal(2.5)
	assert_bool(CaptureArgs.parse_press_step("0.5:aim_nearest").is_empty()).is_false()
	assert_bool(CaptureArgs.parse_press_step("0.5:not_an_action").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step("-1:dodge").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step(":dodge").is_empty()).is_true()


func test_run_hp_edge_cases() -> void:
	assert_int(int(MapLaunch.resolve_hp(PackedStringArray(["--run-seed=1"]))["hp"])).is_equal(-1)
	assert_int(int(MapLaunch.resolve_hp(PackedStringArray(["--run-hp=8"]))["hp"])).is_equal(8)
	assert_int(int(MapLaunch.resolve_hp(PackedStringArray(["--run-hp=999"]))["hp"])).is_equal(999)  # capped to max HP when applied, not here
	for bad: String in ["--run-hp", "--run-hp=", "--run-hp=0", "--run-hp=-1", "--run-hp=1.5", "--run-hp=abc", "--run-hp=0x10"]:
		var result: Dictionary = MapLaunch.resolve_hp(PackedStringArray([bad]))
		assert_int(int(result["hp"])).override_failure_message("hp for %s" % bad).is_equal(-1)
		assert_bool((result["errors"] as Array[String]).is_empty()).override_failure_message("no error for %s" % bad).is_false()
	assert_bool((MapLaunch.resolve_hp(PackedStringArray(["--run-hp=3", "--run-hp=4"]))["errors"] as Array[String]).is_empty()).is_false()
	# A different flag that merely starts with the same letters is not --run-hp.
	assert_bool((MapLaunch.resolve_hp(PackedStringArray(["--run-hpx=3"]))["errors"] as Array[String]).is_empty()).is_true()


func test_run_hp_never_saves() -> void:
	assert_bool(RunSave.DEBUG_FLAG_PREFIXES.has("--run-hp")).is_true()
