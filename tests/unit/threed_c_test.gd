class_name ThreeDCTest
extends GdUnitTestSuite
## 3d sitting C: profile isolation (the DF1 A save-guard pattern), run counting, the debug flags, run start with a loadout and a starter relic, the start screen flow and the
## placeholder editor model.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PROFILE := "user://tests/threed_c_profile.json"
const LOADOUTS := "user://tests/threed_c_loadouts.json"
const NEW_FLAGS: Array[String] = ["--runs-finished", "--profile-path", "--loadouts-path", "--loadout"]


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	_wipe()
	LoadoutSession.reset()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = 0
	RunSession.next_loadout = {}
	RunConfig.reset_cache()
	CardDatabase.load_all()
	RelicDatabase.load_all()
	LoadoutRules.reset_cache()
	StartScreen.reset()
	ClassPickScreen.reset()


func after_test() -> void:
	_wipe()
	LoadoutSession.reset()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.next_loadout = {}
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunConfig.reset_cache()
	StartScreen.reset()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


func _wipe() -> void:
	for path: String in [PROFILE, LOADOUTS, PROFILE + ".bak", LOADOUTS + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _real_files_snapshot() -> String:
	var parts: Array[String] = []
	for path: String in [PlayerProfile.DEFAULT_PATH, LoadoutStore.DEFAULT_PATH]:
		parts.append(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<absent>")
	return "|".join(PackedStringArray(parts))


func _legal_entry(entry_name: String = "Mine", relic: String = "") -> Dictionary:
	var deck: Array[String] = []
	deck.assign(CharacterDatabase.starting_deck("rogue"))
	return LoadoutCheck.make_entry(entry_name, deck, [], relic)


func _args(list: Array) -> PackedStringArray:
	return PackedStringArray(list)


# ---- the gate ----

func test_every_new_flag_is_a_debug_flag() -> void:
	for flag: String in NEW_FLAGS:
		assert_bool(RunSave.DEBUG_FLAG_PREFIXES.has(flag)).override_failure_message(flag + " must be in DEBUG_FLAG_PREFIXES").is_true()
	for arg: String in ["--runs-finished=1", "--profile-path=user://x.json", "--loadouts-path=user://x.json", "--loadout=2"]:
		assert_bool(RunSave.args_suppress(_args([arg]))).override_failure_message(arg).is_true()
	assert_bool(RunSave.args_suppress(_args(["--class=rogue"]))).is_false()


func test_every_debug_flag_gates_the_default_files() -> void:
	for prefix: String in RunSave.DEBUG_FLAG_PREFIXES:
		var resolved: Dictionary = LoadoutArgs.resolve(_args([prefix]), false, false)
		assert_bool(bool(resolved["use_default_files"])).override_failure_message(prefix + " must gate the profile and loadouts").is_false()
	assert_bool(bool(LoadoutArgs.resolve(_args([]), false, false)["use_default_files"])).is_true()
	assert_bool(bool(LoadoutArgs.resolve(_args(["--class=wizard"]), false, false)["use_default_files"])).is_true()
	assert_bool(bool(LoadoutArgs.resolve(_args([]), true, false)["use_default_files"])).override_failure_message("headless").is_false()
	assert_bool(bool(LoadoutArgs.resolve(_args([]), false, true)["use_default_files"])).override_failure_message("a -s script").is_false()


func test_a_gated_launch_gets_in_memory_files_and_creates_nothing() -> void:
	var before: String = _real_files_snapshot()
	LoadoutSession.profile_path = PROFILE  # stand-ins for the real paths: a gated launch must not touch even these
	LoadoutSession.loadouts_path = LOADOUTS
	LoadoutSession.suppressed = true  # a debug-flag launch
	var profile: PlayerProfile = LoadoutSession.profile()
	var store: LoadoutStore = LoadoutSession.store()
	assert_bool(profile.read_only).is_true()
	assert_bool(store.is_memory_only()).is_true()
	assert_int(profile.runs_finished).is_equal(0)
	profile.record_run_finished()
	assert_bool(store.set_last_used("rogue", LoadoutStore.PRESET)).is_true()
	assert_array(store.save_entry("rogue", 0, _legal_entry())).is_empty()
	assert_bool(FileAccess.file_exists(PROFILE)).override_failure_message("a gated launch wrote the profile").is_false()
	assert_bool(FileAccess.file_exists(LOADOUTS)).override_failure_message("a gated launch wrote the loadouts").is_false()
	assert_str(_real_files_snapshot()).is_equal(before)


func test_the_headless_suite_itself_is_gated_without_any_override() -> void:
	# No persist_override and no debug flag: the test run is headless, so it must still get in-memory files.
	var before: String = _real_files_snapshot()
	assert_bool(LoadoutSession.default_files_allowed()).is_false()
	LoadoutSession.record_run_finished(RunSession.begin_new_run(3, "rogue"))
	assert_str(_real_files_snapshot()).is_equal(before)


func test_a_scenario_and_a_sim_flag_gate_the_session() -> void:
	for arg: String in ["--scenario=anything", "--sim-run", "--run-room=3"]:
		LoadoutSession.reset()
		LoadoutSession.persist_override = null
		assert_array(LoadoutSession.apply_args(_args([arg]))).is_empty()
		assert_bool(LoadoutSession.suppressed).override_failure_message(arg).is_true()
		assert_bool(LoadoutSession.default_files_allowed()).is_false()


func test_a_named_scratch_file_is_used_even_in_a_gated_launch_and_nothing_else() -> void:
	var before: String = _real_files_snapshot()
	var errors: Array[String] = LoadoutSession.apply_args(_args(["--profile-path=" + PROFILE, "--loadouts-path=" + LOADOUTS]))
	assert_array(errors).is_empty()
	assert_bool(LoadoutSession.suppressed).is_true()
	LoadoutSession.record_run_finished(RunSession.begin_new_run(3, "rogue"))
	assert_bool(FileAccess.file_exists(PROFILE)).is_true()
	assert_int(PlayerProfile.new(PROFILE).runs_finished).is_equal(1)
	assert_array(LoadoutSession.store().save_entry("rogue", 1, _legal_entry())).is_empty()
	assert_bool(FileAccess.file_exists(LOADOUTS)).is_true()
	assert_array(LoadoutStore.new(LOADOUTS).usable_indices("rogue")).is_equal([1])
	assert_str(_real_files_snapshot()).is_equal(before)


func test_runs_finished_fakes_the_count_and_writes_nothing() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=4", "--profile-path=" + PROFILE]))).is_empty()
	var profile: PlayerProfile = LoadoutSession.profile()
	assert_int(profile.runs_finished).is_equal(4)
	assert_bool(profile.is_first_run()).is_false()
	LoadoutSession.record_run_finished(RunSession.begin_new_run(3, "rogue"))
	assert_int(profile.runs_finished).is_equal(5)  # in memory
	assert_bool(FileAccess.file_exists(PROFILE)).override_failure_message("--runs-finished must never write").is_false()


func test_flag_errors_are_refused_with_a_message() -> void:
	for bad: Array in [["--runs-finished=x"], ["--runs-finished=-1"], ["--profile-path="], ["--loadouts-path="], ["--loadout=0"], ["--loadout=99"], ["--loadout=abc"], ["--loadout=2"]]:
		var resolved: Dictionary = LoadoutArgs.resolve(_args(bad), true, false)
		assert_bool((resolved["errors"] as Array).is_empty()).override_failure_message(str(bad) + " should be refused").is_false()
	var ok: Dictionary = LoadoutArgs.resolve(_args(["--loadout=2", "--loadouts-path=user://x.json"]), true, false)
	assert_array(ok["errors"]).is_empty()
	assert_int(int(ok["slot"])).is_equal(1)
	assert_int(int(LoadoutArgs.resolve(_args(["--loadout=preset"]), true, false)["slot"])).is_equal(LoadoutStore.PRESET)
	assert_int(int(LoadoutArgs.resolve(_args([]), true, false)["slot"])).is_equal(LoadoutArgs.NO_SLOT)


# ---- counting ----

func test_a_finished_run_counts_once_per_run() -> void:
	LoadoutSession.persist_override = true
	LoadoutSession.profile_path = PROFILE
	var state: RunState = RunSession.begin_new_run(3, "rogue")
	assert_bool(LoadoutSession.profile().is_first_run()).is_true()
	assert_bool(LoadoutSession.record_run_finished(state)).is_true()
	assert_bool(LoadoutSession.record_run_finished(state)).override_failure_message("a double signal must not count twice").is_false()
	assert_int(LoadoutSession.profile().runs_finished).is_equal(1)
	assert_int(PlayerProfile.new(PROFILE).runs_finished).is_equal(1)
	assert_bool(LoadoutSession.record_run_finished(RunSession.begin_new_run(4, "rogue"))).is_true()
	assert_int(PlayerProfile.new(PROFILE).runs_finished).is_equal(2)


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func test_a_lost_run_in_the_real_controller_counts() -> void:
	LoadoutSession.persist_override = true
	LoadoutSession.profile_path = PROFILE
	RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames()
	main.run_controller._on_player_died()
	assert_int(PlayerProfile.new(PROFILE).runs_finished).is_equal(1)
	main.run_controller._on_player_died()  # a second death signal for the same run
	assert_int(PlayerProfile.new(PROFILE).runs_finished).is_equal(1)


# ---- run start ----

func _save_loadout(slot: int, relic: String = "") -> Dictionary:
	var entry: Dictionary = _legal_entry("Loadout %d" % (slot + 1), relic)
	var plan: Array[String] = []
	plan.assign(LoadoutCollection.plan_cards("rogue").slice(0, 2))
	entry["plan"] = plan
	assert_array(LoadoutSession.store().save_entry("rogue", slot, entry)).is_empty()
	return entry


func test_a_loadout_start_sets_deck_plan_and_the_starter_relic() -> void:
	LoadoutSession.persist_override = true
	LoadoutSession.loadouts_path = LOADOUTS
	var relic: String = LoadoutCollection.starter_relics("rogue")[0]
	var deck: Array[String] = ["rogue_light_attack_placeholder"]
	deck.clear()
	deck.assign(CharacterDatabase.starting_deck("rogue"))
	deck.pop_back()
	var extra: String = LoadoutCollection.starter_cards("rogue").filter(func(id: String) -> bool: return not CharacterDatabase.starting_deck("rogue").has(id))[0]
	deck.append(extra)
	var entry: Dictionary = LoadoutCheck.make_entry("Mine", deck, LoadoutCollection.plan_cards("rogue").slice(0, 2), relic)
	if not LoadoutCheck.entry_problems("rogue", entry).is_empty():
		return  # the preset-based deck breaks a minimum with that swap; the next test covers an exact copy
	RunSession.next_loadout = entry
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(state.deck).is_equal(deck)
	assert_array(state.plan).is_equal(LoadoutCollection.plan_cards("rogue").slice(0, 2))
	assert_array(state.relics).is_equal([relic])
	assert_dict(RunSession.next_loadout).override_failure_message("a loadout is for one run only").is_empty()
	var again: RunState = RunSession.begin_new_run(6, "rogue")
	assert_array(again.relics).is_empty()
	assert_array(again.plan).is_empty()


func test_the_preset_and_an_empty_relic_get_no_relic() -> void:
	var preset: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(preset.relics).is_empty()
	assert_array(preset.plan).is_empty()
	RunSession.next_loadout = _legal_entry("No relic", "")
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(state.relics).is_empty()


func test_the_starter_relic_round_trips_the_save_and_counts_toward_the_cap_and_duplicates() -> void:
	var relic: String = LoadoutCollection.starter_relics("rogue")[0]
	RunSession.next_loadout = _legal_entry("With relic", relic)
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(state.relics).is_equal([relic])
	var again: RunState = RunState.from_json(state.to_json())
	assert_array(again.relics).is_equal([relic])
	assert_bool(state.add_relic(relic)).override_failure_message("no duplicates").is_false()


func test_a_loadout_that_breaks_the_rules_now_starts_the_preset() -> void:
	var entry: Dictionary = _legal_entry("Broken")
	(entry["deck"] as Array).clear()  # too small: the file may have been fine when it was saved
	RunSession.next_loadout = entry
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(state.deck).is_equal(CharacterDatabase.starting_deck("rogue"))
	assert_array(state.plan).is_empty()
	assert_array(state.relics).is_empty()


func test_a_debug_deck_wins_over_a_loadout() -> void:
	RunSession.full_deck = true
	RunSession.next_loadout = _legal_entry("Ignored", LoadoutCollection.starter_relics("rogue")[0])
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(state.relics).is_empty()
	assert_array(state.deck).is_equal(CharacterDatabase.full_deck("rogue"))


func test_loadout_flag_starts_with_that_slot_every_run() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--loadouts-path=" + LOADOUTS, "--loadout=2"]))).is_empty()
	var relic: String = LoadoutCollection.starter_relics("rogue")[1]
	_save_loadout(1, relic)
	var first: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(first.relics).is_equal([relic])
	var second: RunState = RunSession.begin_new_run(6, "rogue")  # Try again keeps it for the launch
	assert_array(second.relics).is_equal([relic])
	assert_bool(LoadoutSession.start_screen_wanted(second)).override_failure_message("--loadout skips the start screen").is_false()


func test_loadout_flag_with_an_empty_slot_falls_back_to_the_preset() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--loadouts-path=" + LOADOUTS, "--loadout=3"]))).is_empty()
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_array(state.deck).is_equal(CharacterDatabase.starting_deck("rogue"))


# ---- the start screen decision ----

func test_the_start_screen_is_for_run_two_and_later_at_a_fresh_start() -> void:
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_bool(LoadoutSession.start_screen_wanted(state)).override_failure_message("run 1 starts straight away").is_false()
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=1"]))).is_empty()
	assert_bool(LoadoutSession.start_screen_wanted(state)).is_true()
	LoadoutSession.start_resolved(state)
	assert_bool(LoadoutSession.start_screen_wanted(state)).override_failure_message("asked once per run").is_false()
	var other: RunState = RunSession.begin_new_run(6, "rogue")
	assert_bool(LoadoutSession.start_screen_wanted(other)).is_true()
	other.history.append({"index": 0, "type": "combat", "wave_id": "x", "hp_end": 10.0, "seconds": 1.0})
	assert_bool(LoadoutSession.start_screen_wanted(other)).override_failure_message("never mid-run (Continue)").is_false()


func test_a_map_run_asks_only_before_its_first_node() -> void:
	RunSession.map_override = 1
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=2"]))).is_empty()
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_bool(LoadoutSession.start_screen_wanted(state)).is_true()
	state.act = 2
	assert_bool(LoadoutSession.start_screen_wanted(state)).is_false()


func test_a_debug_deck_skips_the_start_screen() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=2"]))).is_empty()
	RunSession.full_deck = true
	assert_bool(LoadoutSession.start_screen_wanted(RunSession.begin_new_run(5, "rogue"))).is_false()


func test_headless_and_scripted_launches_never_open_the_screen() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=2"]))).is_empty()
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	assert_bool(StartScreen.should_open(state)).override_failure_message("headless: no interactive game").is_false()
	StartScreen.enabled_override = true
	assert_bool(StartScreen.should_open(state)).is_true()


func test_start_choices_model_lists_usable_flagged_and_last_used() -> void:
	var store: LoadoutStore = LoadoutStore.new(LOADOUTS)
	assert_array(store.save_entry("rogue", 0, _legal_entry("First", LoadoutCollection.starter_relics("rogue")[0]))).is_empty()
	assert_array(store.save_entry("rogue", 2, _legal_entry("Third"))).is_empty()
	assert_bool(store.set_last_used("rogue", 2)).is_true()
	var broken: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOADOUTS))
	((broken["classes"]["rogue"]["slots"] as Array)[2] as Dictionary)["deck"] = ["not_a_card"]
	var file := FileAccess.open(LOADOUTS, FileAccess.WRITE)
	file.store_string(JSON.stringify(broken))
	file.close()
	var model: Dictionary = LoadoutChoices.start_choices("rogue", LoadoutStore.new(LOADOUTS))
	assert_int((model["loadouts"] as Array).size()).is_equal(1)
	assert_int(int(((model["loadouts"] as Array)[0] as Dictionary)["slot"])).is_equal(0)
	assert_str(String(((model["loadouts"] as Array)[0] as Dictionary)["starter_relic_name"])).is_not_empty()
	assert_int((model["flagged"] as Array).size()).is_equal(1)
	assert_int(int(((model["flagged"] as Array)[0] as Dictionary)["slot"])).is_equal(2)
	assert_str(String(((model["flagged"] as Array)[0] as Dictionary)["message"])).is_not_empty()
	assert_int(int(model["last_used"])).override_failure_message("a flagged last-used slot reads as the preset").is_equal(LoadoutStore.PRESET)
	assert_array(model["free_slots"]).is_equal([1, 3, 4])
	assert_int(int((model["preset"] as Dictionary)["slot"])).is_equal(LoadoutStore.PRESET)
	assert_array(model["rule_problems"]).is_empty()


# ---- the screen in a scene ----

func test_the_start_screen_opens_in_a_run_two_scene_preselects_the_last_used_and_starts_it() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	var relic: String = LoadoutCollection.starter_relics("rogue")[0]
	_save_loadout(1, relic)
	LoadoutSession.store().set_last_used("rogue", 1)
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	var state: RunState = RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_bool(screen.is_open()).is_true()
	assert_bool(main.get_tree().paused or GamePause.is_paused()).is_true()
	assert_array(screen.choice_slots()).is_equal([LoadoutStore.PRESET, 1])
	assert_int(screen.focused_slot()).override_failure_message("the last used choice is preselected").is_equal(1)
	screen.disarm()
	screen.choose(1)
	assert_array(RunSession.current.relics).is_equal([relic])
	assert_bool(RunSession.current == state).override_failure_message("a loadout rebuilds the run").is_false()
	assert_int(RunSession.current.seed_value).is_equal(state.seed_value)
	assert_int(LoadoutSession.store().last_used("rogue")).is_equal(1)
	await _frames(3)
	var fresh: Main = null
	for child in get_children():
		if child is Main and child != main and not child.is_queued_for_deletion():
			fresh = child
	assert_object(fresh).is_not_null()
	assert_bool((fresh.get_node("StartScreen") as StartScreen).is_open()).override_failure_message("the rebuilt scene must not ask again").is_false()
	assert_array(fresh.run_controller.state().relics).is_equal([relic])
	assert_array(fresh.player.card_slots.deck_check().problems).is_empty()


func test_choosing_the_preset_closes_the_screen_and_keeps_the_run() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=1"]))).is_empty()
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	var state: RunState = RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_bool(screen.is_open()).is_true()
	screen.choose(LoadoutStore.PRESET)  # before the arm delay: ignored
	assert_bool(screen.is_open()).is_true()
	screen.disarm()
	screen.choose(LoadoutStore.PRESET)
	assert_bool(screen.is_open()).is_false()
	assert_bool(RunSession.current == state).is_true()
	assert_array(state.relics).is_empty()
	assert_bool(LoadoutSession.start_screen_wanted(state)).is_false()


func test_a_slot_that_is_not_usable_is_refused() -> void:
	assert_array(LoadoutSession.apply_args(_args(["--runs-finished=1"]))).is_empty()
	RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames()
	assert_bool(main.run_controller.confirm_start_choice(3)).is_false()
	assert_bool(main.run_controller.confirm_start_choice(LoadoutStore.PRESET)).is_true()


# ---- the editor model ----

func test_a_draft_adds_to_the_deck_or_the_plan_and_blocks_saving_with_the_checker_messages() -> void:
	var draft: LoadoutDraft = LoadoutDraft.create("rogue", 0)
	draft.loadout_name = "Draft"
	assert_bool(draft.can_save()).is_false()
	assert_bool(draft.problems().is_empty()).is_false()
	var starter: String = LoadoutCollection.starter_cards("rogue")[0]
	assert_str(draft.add_card(starter)).is_empty()
	assert_str(draft.add_card(starter)).is_empty()
	assert_str(draft.add_card(starter)).override_failure_message("a third copy is refused").is_not_empty()
	assert_int(draft.copies(starter)).is_equal(2)
	var reward: String = LoadoutCollection.plan_cards("rogue")[0]
	assert_str(draft.add_card(reward)).is_empty()
	assert_bool(draft.in_plan(reward)).is_true()
	assert_int(draft.copies(reward)).is_equal(0)
	assert_str(draft.add_card(reward)).is_not_empty()
	assert_str(draft.remove_card(reward)).is_empty()
	assert_str(draft.remove_card(starter)).is_empty()
	assert_int(draft.copies(starter)).is_equal(1)
	assert_str(draft.add_card("nonsense")).is_not_empty()
	var rule_text: String = "\n".join(PackedStringArray(draft.problems()))
	assert_str(rule_text).contains("needs")
	var store: LoadoutStore = LoadoutStore.new(LOADOUTS)
	assert_array(draft.save(store)).is_not_empty()
	assert_bool(FileAccess.file_exists(LOADOUTS)).override_failure_message("a blocked save wrote a file").is_false()


func test_a_draft_from_the_preset_saves_and_reads_back() -> void:
	var draft: LoadoutDraft = LoadoutDraft.from_preset("rogue", 3)
	draft.loadout_name = "Preset copy"
	draft.starter_relic = LoadoutCollection.starter_relics("rogue")[0]
	assert_array(draft.problems()).is_empty()
	assert_str(draft.size_text()).contains("Deck")
	assert_int(draft.slot_counts().size()).is_equal(SlotTypeDatabase.known_ids().size())
	var store: LoadoutStore = LoadoutStore.new(LOADOUTS)
	assert_array(draft.save(store)).is_empty()
	var again: LoadoutDraft = LoadoutDraft.from_entry("rogue", 3, LoadoutStore.new(LOADOUTS).entry("rogue", 3))
	assert_str(again.loadout_name).is_equal("Preset copy")
	assert_array(again.deck).is_equal(draft.deck)
	assert_str(again.starter_relic).is_equal(draft.starter_relic)


func test_the_collection_is_grouped_by_slot_with_badges() -> void:
	var groups: Array[Dictionary] = LoadoutDraft.collection_by_slot("wizard")
	assert_int(groups.size()).is_equal(SlotTypeDatabase.known_ids().size())
	var total: int = 0
	for group: Dictionary in groups:
		for card: Dictionary in (group["cards"] as Array):
			total += 1
			assert_str(String(card["slot_type"])).is_equal(String(group["slot_type"]))
			assert_array(["starter", "reward", "locked"]).contains([String(card["availability"])])
	assert_int(total).is_equal(LoadoutCollection.collection("wizard").size())


func test_the_bare_editor_screen_saves_a_loadout_through_the_draft() -> void:
	var store: LoadoutStore = LoadoutStore.new(LOADOUTS)
	var editor := LoadoutEditorScreen.new()
	editor.setup("rogue", store)
	add_child(editor)
	auto_free(editor)
	await _frames()
	assert_int(editor.draft.slot).is_equal(0)
	assert_array(editor.save()).override_failure_message("an empty slot starts as the preset, so it is saveable").is_empty()
	assert_array(store.usable_indices("rogue")).is_equal([0])
	editor.remove(editor.draft.deck[0])
	editor.draft.deck.clear()
	assert_array(editor.save()).is_not_empty()
	assert_array(store.usable_indices("rogue")).is_equal([0])  # the earlier save is untouched
