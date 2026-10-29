class_name SeededSimRepeatTest
extends GdUnitTestSuite
## S6-4: a seeded wave sim or bot sim repeats exactly. Runs the real tools in child Godot processes
## (headless, --fixed-fps 60, the way tools/run_wave_sim.ps1 does) and compares their result lines.

func _run_tool(args: PackedStringArray) -> String:
	var output: Array = []
	var full: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	OS.execute(OS.get_executable_path(), full, output, true)
	return String(output[0]) if not output.is_empty() else ""


func _line(text: String, marker: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(marker):
			return line.strip_edges()
	return ""


func _wave(seed_value: int) -> String:
	var text := _run_tool(["res://tools/WaveSim.tscn", "--", "--seed=%d" % seed_value, "--seconds=25", "--scale=1"])
	return _line(text, "result: seed")


func test_same_seed_wave_sim_gives_identical_results_and_another_seed_differs() -> void:
	var first := _wave(300)
	var second := _wave(300)
	assert_str(first).override_failure_message("no result line: sim did not run").contains("state_hash")
	assert_str(second).is_equal(first)
	assert_str(_wave(301)).override_failure_message("a different seed gave the same run: the test is vacuous").is_not_equal(first)


func test_same_seed_bot_sim_gives_identical_checksum() -> void:
	var args: PackedStringArray = ["-s", "res://tools/bot_sim.gd", "--", "--rooms=6", "--seed=5"]
	var first := _line(_run_tool(args), "checksum")
	var second := _line(_run_tool(args), "checksum")
	assert_str(first).override_failure_message("no checksum line: bot-sim did not run").contains("checksum")
	assert_str(second).is_equal(first)
	var other: PackedStringArray = ["-s", "res://tools/bot_sim.gd", "--", "--rooms=6", "--seed=6"]
	assert_str(_line(_run_tool(other), "checksum")).is_not_equal(first)
