class_name Sim1BotSettingsTest
extends GdUnitTestSuite
## SIM1: the human-like bot settings. Defaults are off, presets load and validate (an unknown name is a clear error with a nonzero exit),
## and a seeded run with a preset on repeats exactly.

const TMP := "user://sim1_presets_test.json"


func after_test() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _write(data: Dictionary) -> void:
	var file := FileAccess.open(TMP, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _preset(delay: float, error: float, hesitation: float) -> Dictionary:
	return {"reaction_delay": delay, "aim_error_degrees": error, "cast_hesitation": hesitation, "aim_resample": 0.35}


func test_settings_default_to_off() -> void:
	assert_bool(BotSettings.new().is_active()).is_false()
	var loaded: Dictionary = BotSettings.load_named("")
	assert_array(loaded["problems"] as Array).is_empty()
	var settings: BotSettings = loaded["settings"]
	assert_str(settings.preset_name).is_equal("off")
	assert_bool(settings.is_active()).is_false()
	assert_float(settings.reaction_delay).is_equal(0.0)
	assert_float(settings.aim_error_degrees).is_equal(0.0)
	assert_float(settings.cast_hesitation).is_equal(0.0)


func test_shipped_file_is_valid_and_has_off_and_human() -> void:
	assert_array(BotSettings.validate_file(BotSettings._read(BotSettings.PATH))).is_empty()
	var names: Array[String] = BotSettings.names()
	assert_array(names).contains(["off", "human"])
	var human: BotSettings = BotSettings.load_named("human")["settings"]
	assert_bool(human.is_active()).is_true()


func test_unknown_preset_gives_a_clear_error() -> void:
	var loaded: Dictionary = BotSettings.load_named("nonsense")
	assert_object(loaded["settings"]).is_null()
	var text: String = "; ".join(loaded["problems"] as Array[String])
	assert_str(text).contains("unknown bot preset 'nonsense'")
	assert_str(text).contains("human")


func test_bad_values_are_rejected() -> void:
	_write({"default": "off", "presets": {"off": _preset(0, 0, 0), "bad": _preset(-1.0, 0, 0)}})
	assert_str("; ".join(BotSettings.load_named("off", TMP)["problems"] as Array[String])).contains("'reaction_delay' must be 0 or more")
	_write({"default": "off", "presets": {"off": _preset(0, 0, 0), "bad": _preset(0.2, 400.0, 0)}})
	assert_str("; ".join(BotSettings.load_named("off", TMP)["problems"] as Array[String])).contains("aim_error_degrees")
	_write({"default": "off", "presets": {"human": _preset(0.2, 5, 0)}})
	assert_str("; ".join(BotSettings.load_named("human", TMP)["problems"] as Array[String])).contains("'off' preset is required")
	var missing: Dictionary = _preset(0.2, 5, 0)
	missing.erase("cast_hesitation")
	missing["bogus"] = 1
	_write({"default": "off", "presets": {"off": _preset(0, 0, 0), "x": missing}})
	var text: String = "; ".join(BotSettings.load_named("off", TMP)["problems"] as Array[String])
	assert_str(text).contains("missing 'cast_hesitation'")
	assert_str(text).contains("unknown field 'bogus'")


func test_missing_file_is_an_error_not_a_default() -> void:
	var loaded: Dictionary = BotSettings.load_named("off", "user://sim1_no_such_file.json")
	assert_object(loaded["settings"]).is_null()
	assert_array(loaded["problems"] as Array).is_not_empty()


func _drive_filter(seed_value: int, settings: BotSettings) -> Array:
	var filter := HumanBotFilter.new()
	filter.reset(settings, seed_value)
	var trace: Array = []
	var me := Vector3.ZERO
	for frame in range(120):
		var now: float = float(frame) / 60.0
		filter.push_aim(now, Vector3(5.0, 0.0, float(frame) * 0.01))
		filter.push_move(now, Vector3(1.0, 0.0, 0.0))
		if frame % 20 == 0:
			filter.push_press(now, &"slot_1", true)
		var due: Dictionary = filter.due(now, me)
		trace.append([due["aim"], due["move"], (due["presses"] as Array).size()])
	return trace


func test_filter_with_the_same_seed_repeats_and_another_seed_differs() -> void:
	var settings: BotSettings = BotSettings.custom(0.2, 20.0, 0.3)
	var first: Array = _drive_filter(7, settings)
	assert_array(_drive_filter(7, settings)).is_equal(first)
	assert_array(_drive_filter(8, settings)).override_failure_message("another seed gave the same trace: the jitter is not seeded").is_not_equal(first)


func test_filter_lags_by_the_reaction_delay() -> void:
	var filter := HumanBotFilter.new()
	filter.reset(BotSettings.custom(0.25, 0.0), 1)
	filter.push_move(0.0, Vector3.RIGHT)
	filter.push_press(0.0, &"dodge", false)
	var early: Dictionary = filter.due(0.2, Vector3.ZERO)
	assert_object(early["move"]).is_null()
	assert_array(early["presses"] as Array).is_empty()
	var late: Dictionary = filter.due(0.25, Vector3.ZERO)
	assert_vector(late["move"] as Vector3).is_equal(Vector3.RIGHT)
	assert_array(late["presses"] as Array).is_equal([&"dodge"])


func test_move_stays_until_a_newer_one_falls_due() -> void:
	var filter := HumanBotFilter.new()
	filter.reset(BotSettings.custom(0.25, 0.0), 1)
	filter.push_move(0.0, Vector3.RIGHT)
	for frame in range(15, 40):
		var due: Dictionary = filter.due(float(frame) / 60.0, Vector3.ZERO)
		if frame >= 15:
			assert_vector(due["move"] as Vector3).override_failure_message("the move dropped at frame %d" % frame).is_equal(Vector3.RIGHT)
	filter.push_move(0.7, Vector3.LEFT)
	assert_vector(filter.due(0.8, Vector3.ZERO)["move"] as Vector3).is_equal(Vector3.RIGHT)
	assert_vector(filter.due(0.95, Vector3.ZERO)["move"] as Vector3).is_equal(Vector3.LEFT)


func test_aim_error_stays_inside_the_setting() -> void:
	var filter := HumanBotFilter.new()
	filter.reset(BotSettings.custom(0.0, 10.0), 3)
	var worst: float = 0.0
	for frame in range(600):
		var now: float = float(frame) / 60.0
		filter.push_aim(now, Vector3(0.0, 0.0, 6.0))
		var aim: Vector3 = filter.due(now, Vector3.ZERO)["aim"]
		worst = maxf(worst, rad_to_deg(absf(Vector3(0.0, 0.0, 6.0).signed_angle_to(aim, Vector3.UP))))
		assert_float(aim.length()).is_equal_approx(6.0, 0.001)
	assert_float(worst).is_less_equal(10.001)
	assert_float(worst).override_failure_message("the aim never moved: the error is vacuous").is_greater(1.0)


func test_filter_with_everything_off_passes_aim_through() -> void:
	var filter := HumanBotFilter.new()
	filter.reset(BotSettings.new(), 1)
	filter.push_aim(0.0, Vector3(3.0, 0.0, 4.0))
	assert_vector(filter.due(0.0, Vector3.ZERO)["aim"] as Vector3).is_equal(Vector3(3.0, 0.0, 4.0))


func _tool(args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var full: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	var code: int = OS.execute(OS.get_executable_path(), full, output, true)
	return {"code": code, "text": String(output[0]) if not output.is_empty() else ""}


func _result_line(text: String) -> String:
	for line: String in text.split("\n"):
		if line.contains("result: seed"):
			return line.strip_edges()
	return ""


func test_unknown_preset_exits_nonzero_in_both_sims() -> void:
	var wave: Dictionary = _tool(["res://tools/WaveSim.tscn", "--", "--seed=1", "--seconds=5", "--bot-preset=nonsense"])
	assert_int(wave["code"]).is_not_equal(0)
	assert_str(wave["text"]).contains("unknown bot preset 'nonsense'")
	var bot: Dictionary = _tool(["-s", "res://tools/bot_sim.gd", "--", "--rooms=2", "--bot-preset=nonsense"])
	assert_int(bot["code"]).is_not_equal(0)
	assert_str(bot["text"]).contains("unknown bot preset 'nonsense'")


func test_wave_sim_with_a_preset_repeats_and_differs_from_off() -> void:
	var args: PackedStringArray = ["res://tools/WaveSim.tscn", "--", "--seed=11", "--seconds=20", "--scale=1", "--bot-preset=human"]
	var first: String = _result_line(_tool(args)["text"])
	assert_str(first).override_failure_message("no result line: the sim did not run").contains("state_hash")
	assert_str(_result_line(_tool(args)["text"])).is_equal(first)
	var off_args: PackedStringArray = ["res://tools/WaveSim.tscn", "--", "--seed=11", "--seconds=20", "--scale=1"]
	assert_str(_result_line(_tool(off_args)["text"])).override_failure_message("the preset changed nothing").is_not_equal(first)
	var explicit_off: PackedStringArray = ["res://tools/WaveSim.tscn", "--", "--seed=11", "--seconds=20", "--scale=1", "--bot-preset=off"]
	assert_str(_result_line(_tool(explicit_off)["text"])).override_failure_message("preset off must equal no preset").is_equal(_result_line(_tool(off_args)["text"]))
