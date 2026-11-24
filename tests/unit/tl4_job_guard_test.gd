class_name Tl4JobGuardTest
extends GdUnitTestSuite
## TL4: the tool wrappers join a kill-on-close Job Object (tools/job_guard.ps1), so a hard-killed wrapper does not orphan Godot, while the
## launch stays a plain `&` call and a refused launch still exits non-zero (an owned Start-Process child lost the exit code on PowerShell 5.1).


func _powershell(args: Array[String]) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass"] + args, output, true)
	return {"code": code, "text": "".join(PackedStringArray(output))}


func test_killing_the_wrapper_kills_its_child() -> void:
	var pid_file: String = OS.get_cache_dir().path_join("cr_job_guard_pid.txt")
	var result: Dictionary = _powershell(["-File", ProjectSettings.globalize_path("res://tests/support/job_guard_check.ps1"), "-PidFile", pid_file])
	assert_str(String(result["text"])).contains("CHILD_KILLED")


func test_the_wrappers_join_the_job_and_keep_the_plain_launch() -> void:
	for path: String in ["res://tools/capture_screenshot.ps1", "res://tools/run_wave_sim.ps1"]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_str(text).override_failure_message(path).contains("job_guard.ps1").contains("Add-KillOnCloseJob").contains("& $godot").contains("exit $LASTEXITCODE" if path.contains("capture") else "exit $code")
		assert_bool(text.contains("Start-Process")).override_failure_message(path + " must keep the & launch").is_false()


func test_a_refused_launch_still_exits_nonzero_through_the_wrapper() -> void:
	# --run-hp=abc is refused by the game itself (exit 2); the wrapper must pass that code on.
	var command: String = "$env:GODOT_BIN = '%s'; & '%s' -Scenario '' -Out '%s' -Extra '--run-hp=abc'; exit $LASTEXITCODE" % [
			OS.get_executable_path(), ProjectSettings.globalize_path("res://tools/capture_screenshot.ps1"), OS.get_cache_dir().path_join("cr_refused.png")]
	var result: Dictionary = _powershell(["-Command", command])
	assert_int(int(result["code"])).is_equal(2)
