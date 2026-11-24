class_name Tl3bCaptureTest
extends GdUnitTestSuite
## TL3b: capture-tool gaps from the UX1b playtest: the act_transition preset, --run-hp, a timed raw key (any_key) and -AtBossAttack names.

const PRESETS_PATH := "res://tools/capture_presets.json"


func _presets() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH)) as Dictionary


func test_act_transition_takes_the_boss_relic_not_a_skip() -> void:
	# The boss relic screen has no skip option, so "relic_skip" never matched there and the preset stalled.
	for preset_id: String in ["act_transition", "act_transition_hurt"]:
		var extra: Array = (_presets()[preset_id] as Dictionary)["extra"]
		var chosen: String = ""
		for arg: Variant in extra:
			if String(arg).begins_with("--run-auto-choose="):
				chosen = String(arg)
		assert_str(chosen).override_failure_message(preset_id).contains("relic:")
		assert_str(chosen).override_failure_message(preset_id).not_contains("relic_skip")


func test_run_hp_parses_and_refuses_bad_values() -> void:
	assert_int(int(MapLaunch.resolve_hp(PackedStringArray(["--run-hp=8"]))["hp"])).is_equal(8)
	assert_int(int(MapLaunch.resolve_hp(PackedStringArray(["--run-seed=1"]))["hp"])).is_equal(-1)
	for bad: Array in [["--run-hp=0"], ["--run-hp=abc"], ["--run-hp"], ["--run-hp=-3"], ["--run-hp=1.5"], ["--run-hp=2", "--run-hp=3"]]:
		var result: Dictionary = MapLaunch.resolve_hp(PackedStringArray(bad))
		assert_int((result["errors"] as Array[String]).size()).override_failure_message(str(bad)).is_greater(0)
		assert_int(int(result["hp"])).is_equal(-1)


func test_run_hp_is_a_debug_flag() -> void:
	assert_bool(RunSave.args_suppress(PackedStringArray(["--run-hp=8"]))).is_true()


func test_the_hurt_preset_uses_run_hp() -> void:
	assert_array((_presets()["act_transition_hurt"] as Dictionary)["extra"] as Array).contains(["--run-hp=8"])


func test_run_hp_refusal_exits_2() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless"] + ToolLog.args("tl3b") + ["--path", ProjectSettings.globalize_path("res://"), "--", "--run-hp=abc"], output, true)
	assert_int(code).is_equal(2)
	assert_str("\n".join(PackedStringArray(output))).contains("--run-hp needs a whole number")


func test_any_key_is_a_press_step_without_hold() -> void:
	var step: Dictionary = CaptureArgs.parse_press_step("1.8:any_key")
	assert_str(String(step["action"])).is_equal("any_key")
	assert_float(float(step["hold"])).is_equal(0.0)
	assert_bool(CaptureArgs.parse_press_step("1.8:any_key:2").is_empty()).is_true()
	assert_bool(CaptureArgs.parse_press_step("1.8:any_keys").is_empty()).is_true()


func test_the_beat_skip_preset_presses_any_key() -> void:
	var preset: Dictionary = _presets()["map_beat_skip"]
	assert_bool(CaptureArgs.parse_press_step(String(preset["actions"])).is_empty()).is_false()


func test_any_key_sends_a_raw_key_event_the_map_beat_accepts() -> void:
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.1, "action": &"any_key", "hold": 0.0}]
	add_child(scripted)
	auto_free(scripted)
	var seen: Array[InputEventKey] = []
	var catcher := KeyCatcher.new()
	catcher.seen = seen
	add_child(catcher)
	auto_free(catcher)
	scripted._process(0.2)
	Input.flush_buffered_events()
	scripted._process(0.2)
	Input.flush_buffered_events()
	assert_int(seen.size()).is_greater_equal(1)
	assert_bool(seen[0].pressed).is_true()
	assert_bool(seen[0].echo).is_false()  # the map beat ignores held repeats

func test_act_transition_seed_1_still_offers_the_boss_relic_the_preset_takes() -> void:
	# The preset's --run-auto-choose=relic:burnout_syndrome only works while seed 1 at room 10 (--run-room=10 is room_index 9) offers it.
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var state: RunState = RunState.new_run(1, CharacterDatabase.starting_deck("rogue"), 3, "rogue")
	state.acts_total = 3
	state.room_index = 9
	assert_str(RunRelics.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_bool(RunRelics.is_boss_offer(state)).is_true()
	assert_array(state.offer).override_failure_message("seed 1 room 10 offers " + str(state.offer)).contains(["burnout_syndrome"])


func test_a_bound_action_pressed_at_a_scene_swap_fires_once() -> void:
	# Nit 1: the swapped-in Main builds a fresh ScriptedInput; it used to replay the whole script from t=0, so the tap fired once per scene.
	ScriptedInput.reset_carry()
	var presses: Array[Dictionary] = [{"at": 0.1, "action": &"dodge", "hold": 0.0}]
	var counter := ActionCounter.new()
	add_child(counter)
	auto_free(counter)
	var first := ScriptedInput.new()
	first.presses = presses
	first.carry_across_swaps = true
	add_child(first)
	first._process(0.2)  # the tap fires
	Input.flush_buffered_events()
	remove_child(first)  # the swap: Main leaves the tree ...
	first.free()
	var second := ScriptedInput.new()  # ... and the fresh Main builds its own
	second.presses = presses
	second.carry_across_swaps = true
	add_child(second)
	second._process(0.2)
	second._process(0.2)
	Input.flush_buffered_events()
	remove_child(second)
	second.free()
	Input.flush_buffered_events()
	ScriptedInput.reset_carry()
	assert_int(counter.pressed).is_equal(1)
	# Without carrying (the old behaviour, and what plain tests get) a fresh one starts over.
	var replay := ScriptedInput.new()
	replay.presses = presses
	add_child(replay)
	replay._process(0.2)
	Input.flush_buffered_events()
	remove_child(replay)
	replay.free()
	assert_int(counter.pressed).is_equal(2)


class ActionCounter extends Node:
	var pressed: int = 0

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed(&"dodge"):
			pressed += 1


class KeyCatcher extends Node:
	var seen: Array[InputEventKey] = []

	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			seen.append(event as InputEventKey)


func _boss_attack(name: String) -> Dictionary:
	var script: String = ". '%s'; $r = Resolve-BossAttack -Name '%s' -BossesFile '%s'; ('id=' + $r.Id + '|valid=' + ($r.Valid -join ','))" % [
			ProjectSettings.globalize_path("res://tools/boss_attack.ps1"), name, ProjectSettings.globalize_path("res://data/bosses.json")]
	var output: Array = []
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	var line: String = "".join(PackedStringArray(output)).strip_edges()
	return {"id": line.get_slice("|", 0).trim_prefix("id="), "valid": line.get_slice("|", 1).trim_prefix("valid=")}


func test_at_boss_attack_accepts_ground_pound_and_ids() -> void:
	assert_str(String(_boss_attack("ground_pound")["id"])).is_equal("slam")
	assert_str(String(_boss_attack("slam")["id"])).is_equal("slam")
	assert_str(String(_boss_attack("volley")["id"])).is_equal("volley")


func test_a_bad_boss_attack_name_lists_the_valid_names() -> void:
	var result: Dictionary = _boss_attack("bogus")
	assert_str(String(result["id"])).is_empty()
	assert_str(String(result["valid"])).contains("smash").contains("slam").contains("ground_pound")


func test_capture_script_uses_the_resolver() -> void:
	var text: String = FileAccess.get_file_as_string("res://tools/capture_screenshot.ps1")
	assert_str(text).contains("Resolve-BossAttack").contains("exit 2")
