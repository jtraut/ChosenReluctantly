extends GdUnitTestSuite
## SIM1 nits: a non-numeric --bot-delay / --bot-aim-error / --bot-hesitation is rejected (exit nonzero, clear message) instead of silently
## becoming 0; the bot sim never prints an empty preset name.

func _tool(args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var full: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	var code: int = OS.execute(OS.get_executable_path(), full, output, true)
	return {"code": code, "text": String(output[0]) if not output.is_empty() else ""}


func test_non_numeric_override_flags_are_rejected() -> void:
	for flag: String in ["--bot-delay", "--bot-aim-error", "--bot-hesitation"]:
		var result: Dictionary = _tool(["res://tools/WaveSim.tscn", "--", "--seed=1", "--seconds=5", flag + "=abc"])
		assert_int(result["code"]).override_failure_message(flag + "=abc must exit nonzero").is_not_equal(0)
		assert_str(result["text"]).contains(flag + " needs a number, got 'abc'")


func test_bot_sim_never_prints_an_empty_preset_name() -> void:
	var result: Dictionary = _tool(["-s", "res://tools/bot_sim.gd", "--", "--rooms=2", "--seed=3"])
	assert_str(result["text"]).not_contains("bot preset ''")
