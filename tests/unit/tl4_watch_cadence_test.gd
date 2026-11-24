class_name Tl4WatchCadenceTest
extends GdUnitTestSuite
## TL4: watch-mode decision cadence. The windowed bot decides once per physics tick at any -Scale (the sim raises the tick
## rate by the scale, so a tick is 1/60 game second); the headless sim is unchanged and reports 60 decisions per game second.

const WAVE_SIM_SOURCE: String = "res://tools/wave_sim.gd"
const WAVE_SIM_RUNNER: String = "res://tools/run_wave_sim.ps1"


func test_headless_decision_log_reports_sixty_a_second() -> void:
	var output: Array = []
	var args: Array = ["--headless", "--fixed-fps", "60"] + ToolLog.args("tl4") + ["--path", ProjectSettings.globalize_path("res://"), "res://tools/WaveSim.tscn", "--", "--run", "--scale=1", "--seed=1", "--sim-acts=1", "--sim-route=first", "--decision-log", "--room-timeout=60"]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	assert_int(code).is_equal(0)
	var text: String = String(output[0])
	var regex: RegEx = RegEx.new()
	regex.compile("DECISIONS room ([0-9]+): ([0-9]+) decisions in ([0-9.]+) game s = ([0-9.]+) per game s [(]physics 60 Hz")
	var fights: int = 0
	for found: RegExMatch in regex.search_all(text):
		if float(found.get_string(3)) < 5.0:
			continue  # a reward, rest or shop room is cleared at once
		fights += 1
		assert_float(float(found.get_string(4))).is_between(59.0, 60.5)
	assert_int(fights).is_greater(0)


func test_decision_log_is_off_unless_asked_for() -> void:
	var output: Array = []
	var args: Array = ["--headless", "--fixed-fps", "60"] + ToolLog.args("tl4") + ["--path", ProjectSettings.globalize_path("res://"), "res://tools/WaveSim.tscn", "--", "--seed=1", "--seconds=2"]
	OS.execute(OS.get_executable_path(), args, output, true)
	assert_bool(String(output[0]).contains("DECISIONS room")).is_false()


func test_wrapper_and_sim_know_the_cadence_switches() -> void:
	var runner: String = FileAccess.get_file_as_string(WAVE_SIM_RUNNER)
	var source: String = FileAccess.get_file_as_string(WAVE_SIM_SOURCE)
	for pair: Array in [["DecisionLog", "--decision-log"], ["LegacyCadence", "--legacy-cadence"], ["NoVsync", "--disable-vsync"]]:
		assert_bool(runner.contains(String(pair[0]))).override_failure_message("run_wave_sim.ps1 lacks " + String(pair[0])).is_true()
		assert_bool(runner.contains(String(pair[1]))).is_true()
	assert_bool(source.contains("_watch_physics_rate")).is_true()


func test_watch_mode_raises_the_tick_rate_with_the_scale_and_only_there() -> void:
	# The rate change sits in the watch branch only (so headless is untouched) and 60 is restored at the run's end.
	var source: String = FileAccess.get_file_as_string(WAVE_SIM_SOURCE)
	assert_int(source.count("Engine.physics_ticks_per_second = ")).is_equal(2)  # the raise and the restore
	assert_bool(source.contains("Engine.physics_ticks_per_second = int(round(60.0 * _scale))")).is_true()
	assert_bool(source.contains("Engine.physics_ticks_per_second = 60")).is_true()


func test_watch_mode_sends_latched_input_without_frame_buffering() -> void:
	# Input.parse_input_event buffers to the next rendered frame unless use_accumulated_input is off; at -Scale 4 that is up to 3 ticks late.
	var source: String = FileAccess.get_file_as_string(WAVE_SIM_SOURCE)
	assert_bool(source.contains("Input.use_accumulated_input = false")).is_true()
	assert_bool(source.contains("Input.use_accumulated_input = true")).is_true()


func _ps(script: String) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	return {"code": code, "text": "".join(PackedStringArray(output)).strip_edges()}


func test_a_label_that_is_an_attack_id_is_not_listed_as_an_alias() -> void:
	var script: String = ". '%s'; $r = Resolve-BossAttack -Name 'leveraged_dash' -BossesFile '%s'; ('id=' + $r.Id + '|valid=' + ($r.Valid -join ','))" % [
			ProjectSettings.globalize_path("res://tools/boss_attack.ps1"), ProjectSettings.globalize_path("res://data/bosses.json")]
	var text: String = String(_ps(script)["text"])
	assert_str(text.get_slice("|", 0)).is_equal("id=leveraged_dash")
	assert_str(text).not_contains("(= leveraged_dash_2)")
	assert_str(text).contains("leveraged_dash_2")


func test_at_boss_attack_without_a_boss_exits_2_at_once() -> void:
	var script: String = "& '%s' -Scenario hp_bars -AtBossAttack smash -Out '%s' 2>&1; exit $LASTEXITCODE" % [
			ProjectSettings.globalize_path("res://tools/capture_screenshot.ps1"), OS.get_user_data_dir().path_join("tl4_never.png")]
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = _ps(script)
	assert_int(int(result["code"])).is_equal(2)
	assert_str(String(result["text"])).contains("needs a boss")
	assert_int(Time.get_ticks_msec() - started).is_less(20000)

