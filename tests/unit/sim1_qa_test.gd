extends GdUnitTestSuite
## SIM1 sitting 2 (qa): regression for run_wave_sim.ps1 failing every run with -BotPreset human. The script's output filter
## (`-match "ERROR|WARNING"`, case-insensitive in PowerShell) caught the sim's own "Bot settings: ... aim_error ..." line and exited 1.

func _run_script(extra: PackedStringArray) -> Dictionary:
	var script: String = ProjectSettings.globalize_path("res://tools/run_wave_sim.ps1")
	var args: PackedStringArray = ["-NoProfile", "-File", script, "-Seed", "1", "-Seconds", "5"]
	args.append_array(extra)
	var output: Array = []
	var code: int = OS.execute("powershell", args, output, true)
	return {"code": code, "text": String(output[0]) if not output.is_empty() else ""}


func test_wave_sim_script_exits_zero_with_the_human_preset() -> void:
	var result: Dictionary = _run_script(["-BotPreset", "human"])
	assert_str(result["text"]).override_failure_message("the sim did not finish").contains("WAVE SIM OK")
	assert_str(result["text"]).override_failure_message("the script flagged its own settings line as an engine error").not_contains("Engine errors/warnings")
	assert_int(result["code"]).is_equal(0)


func test_wave_sim_script_exits_zero_with_the_sweep_overrides() -> void:
	var result: Dictionary = _run_script(["-BotDelay", "0.1", "-BotAimError", "10"])
	assert_str(result["text"]).contains("WAVE SIM OK")
	assert_int(result["code"]).is_equal(0)


func test_wave_sim_script_exits_zero_with_the_default() -> void:
	assert_int(_run_script([])["code"]).is_equal(0)
