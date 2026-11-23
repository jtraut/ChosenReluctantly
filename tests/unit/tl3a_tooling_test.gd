class_name Tl3aToolingTest
extends GdUnitTestSuite
## TL3a: sim log isolation (--log-file keeps tool runs out of user://logs) and the four TL2 watch-log nits.

const RUNNERS: Array[String] = ["capture_screenshot", "run_bot_sim", "run_map_print", "run_offer_report", "run_reload_cycle", "run_tests", "run_wave_sim"]


func _user_logs() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(OS.get_user_data_dir().path_join("logs"))
	if dir == null:
		return PackedStringArray()
	var names: PackedStringArray = dir.get_files()
	names.sort()
	return names


func test_every_godot_runner_sends_its_log_to_its_own_file() -> void:
	for runner: String in RUNNERS:
		var text: String = FileAccess.get_file_as_string("res://tools/%s.ps1" % runner)
		assert_bool(text.contains("sim_log.ps1")).override_failure_message("%s does not load tools/sim_log.ps1" % runner).is_true()
		assert_bool(text.contains("Get-ToolLogArgs \"")).override_failure_message("%s launches Godot without Get-ToolLogArgs" % runner).is_true()
	assert_bool(FileAccess.get_file_as_string("res://.gitignore").contains("/logs/")).is_true()


func test_log_file_run_adds_nothing_to_user_logs() -> void:
	var before: PackedStringArray = _user_logs()
	var log_path: String = OS.get_user_data_dir().path_join("tl3a_probe.log")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--log-file", log_path, "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/map_print.gd"], output, true)
	assert_int(code).is_equal(0)
	assert_bool(FileAccess.file_exists(log_path)).is_true()
	assert_array(_user_logs()).is_equal(before)
	DirAccess.remove_absolute(log_path)


func test_sim_log_helper_names_a_file_under_logs_sim() -> void:
	var output: Array = []
	var script: String = ". '%s'; (Get-ToolLogArgs 'probe') -join '|'" % ProjectSettings.globalize_path("res://tools/sim_log.ps1")
	var code: int = OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	assert_int(code).is_equal(0)
	var text: String = String(output[0]).strip_edges().replace("\\", "/")
	assert_str(text).starts_with("--log-file|")
	assert_str(text).contains("/logs/sim/probe-")
	assert_str(text).ends_with(".log")


func test_bare_watch_shots_is_caught() -> void:
	assert_bool(WatchText.is_bare(["--run", "--watch-shots"])).is_true()
	assert_bool(WatchText.is_bare(["--watch-shots="])).is_true()
	assert_bool(WatchText.is_bare(["--watch-shots=out"])).is_false()
	assert_bool(WatchText.is_bare(["--run"])).is_false()


func test_bare_watch_shots_is_refused_with_a_message() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless"] + ToolLog.args("tl3a") + ["--path", ProjectSettings.globalize_path("res://"), "res://tools/WaveSim.tscn", "--", "--run", "--watch-shots"], output, true)
	assert_int(code).is_equal(2)
	assert_str(String(output[0])).contains("--watch-shots needs a folder")


func test_hp_at_end_is_current_on_a_loss() -> void:
	assert_str(WatchText.hp_at_end("lost", 47.0, 0.0, true)).is_equal("0.0")
	assert_str(WatchText.hp_at_end("lost", 47.0, 0.0, false)).is_equal("0.0")
	assert_str(WatchText.hp_at_end("won", 47.0, 12.0, true)).is_equal("47.0")


func test_room_text_shows_run_wide_and_act_local() -> void:
	assert_str(WatchText.room_text(12, 3)).is_equal("room 12 of the run (act room 3)")


func test_numbered_crowd_shots_do_not_collide() -> void:
	assert_str(WatchMode.shot_path("out", "rogue", 1, 4, "crowded-fight")).is_equal("out/rogue-seed1/04-crowded-fight.png")
	assert_str(WatchMode.shot_path("out", "rogue", 1, 9, "crowded-fight")).is_not_equal(WatchMode.shot_path("out", "rogue", 1, 4, "crowded-fight"))
