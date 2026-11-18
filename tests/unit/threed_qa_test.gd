class_name ThreeDQaTest
extends GdUnitTestSuite
## 3d qa (2026-11-18): independent checks of the loadouts slice. Suite hygiene (the process-wide in-memory profile), `starter` relics in every offer source, an act 2+ merchant
## whose plan holds rare and legendary cards, Esc in the editor through the real viewport input path, and bad loadout files never blocking a run.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const LOADOUTS := "user://tests/threed_qa_loadouts.json"
const SUITE_DIR := "res://tests/unit"
## A suite that reaches any of these can finish a run, which counts it in the shared in-memory profile (LoadoutSession).
const RUN_ENDERS: Array[String] = ["run_lost", "run_won", "record_run_finished", "lose_run", "give_up", "player_died", ".died", "_lose", "defeat"]


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
	RunConfig.reset_cache()
	StartScreen.reset()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


func _wipe() -> void:
	for path: String in [LOADOUTS, LOADOUTS + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


# ---- carry-over 3: the shared in-memory profile ----

func test_a_finished_run_leaves_the_shared_profile_counting_until_reset() -> void:
	# Documents the hazard: the in-memory profile is process-wide, so a suite that ends a run must call LoadoutSession.reset().
	var state: RunState = RunSession.begin_new_run(3, "rogue")
	assert_bool(LoadoutSession.profile().is_first_run()).is_true()
	assert_bool(LoadoutSession.record_run_finished(state)).is_true()
	assert_bool(LoadoutSession.profile().is_first_run()).is_false()
	LoadoutSession.reset()
	assert_bool(LoadoutSession.profile().is_first_run()).override_failure_message("reset() must give the next suite run 1 again").is_true()


func test_every_suite_that_can_end_a_run_resets_the_session() -> void:
	var offenders: Array[String] = []
	var dir: DirAccess = DirAccess.open(SUITE_DIR)
	assert_object(dir).is_not_null()
	for file_name: String in dir.get_files():
		if not file_name.ends_with("_test.gd") or file_name == "threed_qa_test.gd":
			continue
		var text: String = FileAccess.get_file_as_string(SUITE_DIR + "/" + file_name)
		var can_end: bool = false
		for word: String in RUN_ENDERS:
			if text.contains(word):
				can_end = true
				break
		if can_end and not text.contains("LoadoutSession.reset()"):
			offenders.append(file_name)
	assert_array(offenders).override_failure_message("suites that can end a run but never reset LoadoutSession (add `func after() -> void: LoadoutSession.reset()`): %s" % str(offenders)).is_empty()


# ---- `starter` in offers ----
# Finding (3d qa): the four starter relics keep their ordinary sources (elite, relic_room, merchant) next to "starter" - data/relics/chasing_paper.json and the other three - so they CAN
# appear in ordinary offers, which BUILD_DEPTH 4.7 row 6 ("found nowhere else") does not say. sitting B's loadout_data_test pins that choice. What must hold either way: the source value
# "starter" is never asked for by any offer, and a starter relic the run already holds is never offered again (no duplicate).

func test_no_offer_source_in_the_code_is_starter_and_a_held_starter_relic_is_never_offered_again() -> void:
	var starters: Array[String] = []
	for entry: Variant in RelicDatabase.all_relics():
		if ((entry as Dictionary).get("sources", []) as Array).has("starter"):
			starters.append(String((entry as Dictionary)["id"]))
	assert_array(starters).has_size(4)
	var weights: Dictionary = {"tier1": 1.0, "tier2": 1.0, "tier3": 1.0, "boss": 1.0}
	var all_rarities: Array[String] = ["tier1", "tier2", "tier3", "boss"]
	var none: Array[String] = []
	for character: String in ["rogue", "wizard"]:
		var pools: Array[String] = CharacterDatabase.pools(character)
		var asked: Array[Dictionary] = RelicOffer.eligible("starter", weights, none, none, pools, RelicDatabase.all_relics(), all_rarities)
		assert_int(asked.size()).override_failure_message("sanity: the starter source itself holds the class's relics").is_equal(2)
		for held: String in starters:
			for source: String in ["elite", "relic_room", "merchant", "event", "mini_boss"]:
				var owned: Array[String] = [held]
				for relic: Dictionary in RelicOffer.eligible(source, weights, owned, none, pools, RelicDatabase.all_relics(), all_rarities):
					assert_str(String(relic["id"])).override_failure_message("held starter relic %s is eligible again for '%s'" % [held, source]).is_not_equal(held)
	for path: String in ["res://src"]:
		for file_path: String in _gd_files(path):
			var text: String = FileAccess.get_file_as_string(file_path)
			for call_name: String in ["RelicOffer.offer(", "RelicOffer.eligible("]:
				var at: int = text.find(call_name)
				while at >= 0:
					assert_str(text.substr(at, 40)).override_failure_message("%s asks an offer for the starter source" % file_path).not_contains("\"starter\"")
					at = text.find(call_name, at + 1)


func _gd_files(path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(path + "/" + file_name)
	for sub: String in dir.get_directories():
		found.append_array(_gd_files(path + "/" + sub))
	return found


func test_a_merchant_never_stocks_the_starter_relic_the_run_holds_over_many_seeds_and_acts() -> void:
	var starters: Array[String] = []
	for entry: Variant in RelicDatabase.all_relics():
		if ((entry as Dictionary).get("sources", []) as Array).has("starter"):
			starters.append(String((entry as Dictionary)["id"]))
	var drawn: int = 0
	for character: String in ["rogue", "wizard"]:
		var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
		for seed_value in range(1, 41):
			var state: RunState = RunSession.begin_new_run(seed_value, character)
			for held: String in starters:
				if CharacterDatabase.pools(character).has(String(RelicDatabase.get_relic(held).get("pool", ""))):
					state.add_relic(held)
					break
			for act in range(1, 4):
				state.act = act
				for node in [1, 2, 3, 7]:
					for relic_id: String in Merchant.draw_stock(state, node, 0, ctx, [] as Array[String], [] as Array[String])["relics"]:
						drawn += 1
						assert_bool(state.relics.has(relic_id)).override_failure_message("a held relic %s was stocked again (seed %d act %d)" % [relic_id, seed_value, act]).is_false()
	assert_int(drawn).override_failure_message("the sweep must actually draw relics").is_greater(100)


# ---- carry-over 4: an act 2+ merchant with a plan of rare and legendary cards ----

func test_an_act_two_merchant_flags_rare_and_legendary_plan_cards_and_the_tile_wears_the_badge() -> void:
	var plan: Array[String] = LoadoutCollection.plan_cards("rogue")
	assert_array(plan).is_not_empty()
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var flagged: int = 0
	var unflagged_plan_cards: int = 0
	var rarities_seen: Array[String] = []
	var badge_checked: bool = false
	for seed_value in range(1, 31):
		for act in [2, 3]:
			var state: RunState = RunSession.begin_new_run(seed_value, "rogue")
			state.act = act
			state.plan = plan.duplicate()
			state.gold = 999
			Merchant.open_visit(state, 3, ctx)
			state.pending = RunState.PENDING_MERCHANT
			for option: Dictionary in RunMerchant.options(state, ctx):
				if String(option.get("kind", "")) != "buy_card":
					continue
				var card_id: String = String(option["card_id"])
				var rarity: String = CardSchema.rarity_of(CardDatabase.get_card(card_id))
				var expect: bool = plan.has(card_id) and not state.deck.has(card_id)
				assert_bool(bool(option["on_plan"])).override_failure_message("%s (%s) in an act %d shop: on_plan should be %s" % [card_id, rarity, act, expect]).is_equal(expect)
				if expect:
					flagged += 1
					if not rarities_seen.has(rarity):
						rarities_seen.append(rarity)
					if not badge_checked:
						badge_checked = true
						var tile := RunOptionCard.new()
						add_child(tile)
						auto_free(tile)
						tile.setup(option, RunOptionCard.Look.SHOP, 268.0, UiConfig.run_ui(), 1.0, {"index": -1, "owned": 0, "texts": RunConfig.ui()["option"], "shop_texts": RunConfig.ui().get("merchant", {}), "gold": 999, "shop_name": String(option["label"])})
						assert_object(tile.plan_tag).override_failure_message("a plan card in an act %d shop has no badge" % act).is_not_null()
				elif plan.has(card_id):
					unflagged_plan_cards += 1
	assert_int(flagged).override_failure_message("no rare or legendary plan card ever reached an act 2/3 shop in 60 draws").is_greater(0)
	assert_bool(rarities_seen.has("common")).override_failure_message("the plan holds no commons, so only rare/legendary should be flagged").is_false()
	assert_int(unflagged_plan_cards).is_equal(0)


# ---- Esc through the real input path ----

func test_escape_in_the_editor_never_opens_the_pause_menu() -> void:
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	RunSession.begin_new_run(31, "rogue")
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_bool(screen.is_open()).is_true()
	screen.disarm()
	var rows: Array[Button] = screen.row_buttons()
	rows[rows.size() - 1].pressed.emit()
	await _frames(2)
	var editor: LoadoutEditorScreen = null
	for child in screen.get_children():
		if child is LoadoutEditorScreen:
			editor = child
	assert_object(editor).is_not_null()
	editor.add(_a_starter_not_in(editor.draft.deck))  # now dirty: the first Esc only asks, the second leaves
	assert_bool(editor.is_dirty()).is_true()
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	assert_bool(settings.is_open()).is_false()
	for press in range(2):
		await _tap_escape()
		assert_bool(settings.is_open()).override_failure_message("Esc number %d opened the pause menu" % (press + 1)).is_false()
		if press == 0:
			assert_bool(is_instance_valid(editor) and editor.is_inside_tree()).override_failure_message("the first Esc on a dirty draft only asks").is_true()
	assert_bool(is_instance_valid(editor) and editor.is_inside_tree()).override_failure_message("the second Esc should have left the editor").is_false()
	assert_bool(screen.is_open()).override_failure_message("back on the start screen").is_true()
	assert_bool(settings.is_open()).is_false()
	# Positive control: the same key press does open the pause menu once no screen is in the way, so the checks above could have failed.
	screen.choose(LoadoutStore.PRESET)
	await _frames(2)
	assert_bool(screen.is_open()).is_false()
	await _tap_escape()
	assert_bool(settings.is_open()).override_failure_message("control: Esc with no screen open must open the pause menu, or this probe proves nothing").is_true()


func _tap_escape() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.physical_keycode = KEY_ESCAPE
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _a_starter_not_in(deck: Array[String]) -> String:
	for id: String in LoadoutCollection.starter_cards("rogue"):
		if deck.count(id) == 0:
			return id
	return LoadoutCollection.starter_cards("rogue")[0]


# ---- bad files never block a run ----

func test_bad_loadout_files_never_block_a_run_and_the_preset_is_always_there() -> void:
	var bad_files: Array[String] = [
		"", "not json at all", "[]", "{}", "null", "{\"version\": 1}", "{\"version\": 99, \"classes\": {}}",
		"{\"version\": 1, \"classes\": 5}", "{\"version\": 1, \"classes\": {\"rogue\": {\"loadouts\": \"x\", \"last_used\": \"y\"}}}",
		"{\"version\": 1, \"classes\": {\"rogue\": {\"loadouts\": [null, 3, {\"name\": 4}], \"last_used\": 99}}}",
		"\u0001\u0002 garbage",
	]
	for text: String in bad_files:
		var file := FileAccess.open(LOADOUTS, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		LoadoutSession.reset()
		assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
		for character: String in ["rogue", "wizard"]:
			var choices: Dictionary = LoadoutChoices.start_choices(character)
			assert_int(int((choices["preset"] as Dictionary)["slot"])).override_failure_message("preset missing for file %s" % text.left(30)).is_equal(LoadoutStore.PRESET)
			var last_used: int = int(choices["last_used"])
			var usable: Array[int] = []
			for entry: Dictionary in choices["loadouts"]:
				usable.append(int(entry["slot"]))
			assert_bool(last_used == LoadoutStore.PRESET or usable.has(last_used)).override_failure_message("last_used %d is neither the preset nor a usable slot (file %s)" % [last_used, text.left(30)]).is_true()


func test_a_corrupt_loadouts_file_still_opens_the_start_screen_and_the_preset_starts_a_run() -> void:
	var file := FileAccess.open(LOADOUTS, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	RunSession.begin_new_run(31, "rogue")
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_bool(screen.is_open()).is_true()
	screen.disarm()
	screen.choose(LoadoutStore.PRESET)
	await _frames(2)
	assert_bool(screen.is_open()).is_false()
	var run: RunState = RunSession.current
	assert_int(run.deck.size()).is_equal(CharacterDatabase.starting_deck("rogue").size())
	assert_array(run.relics).is_empty()


# ---- item 5: the keyboard-only walk (scripted key events through the viewport; no mouse, no direct method calls except the arm-delay `disarm`) ----

func _press(keycode: Key, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.ctrl_pressed = ctrl
		key.pressed = pressed
		Input.parse_input_event(key)
		await _frames(2)


func test_a_keyboard_only_walk_builds_saves_and_starts_a_loadout_with_a_starter_relic() -> void:
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	RunSession.begin_new_run(31, "rogue")
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_bool(screen.is_open()).is_true()
	screen.disarm()  # the 0.x s arm delay only; every other step is a key press
	assert_int(screen.focused_slot()).override_failure_message("one Enter would start the preset: it is preselected").is_equal(LoadoutStore.PRESET)
	var row_count: int = screen.row_buttons().size()
	for i in range(row_count - 1):
		await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	await _frames(2)
	var editor: LoadoutEditorScreen = null
	for child in screen.get_children():
		if child is LoadoutEditorScreen:
			editor = child
	assert_object(editor).override_failure_message("Enter on the edit row did not open the editor").is_not_null()
	await _frames(2)
	assert_bool(editor.get_viewport().gui_get_focus_owner() != null).override_failure_message("the editor opens with a focused card row").is_true()
	# add a card with Enter, walking Down until one is accepted (a row already at 2 copies refuses)
	var before: int = editor.draft.deck.size()
	for step in range(12):
		await _press(KEY_ENTER)
		if editor.draft.deck.size() > before:
			break
		await _press(KEY_DOWN)
	assert_int(editor.draft.deck.size()).override_failure_message("no card could be added by keyboard").is_equal(before + 1)
	assert_bool(editor.is_dirty()).is_true()
	# Delete removes it again, Enter adds it back (the remove key works on the focused row)
	await _press(KEY_DELETE)
	assert_int(editor.draft.deck.size()).is_equal(before)
	await _press(KEY_ENTER)
	assert_int(editor.draft.deck.size()).is_equal(before + 1)
	# the starter relic: arrow across to the relic panel and press Enter on one
	var reached: bool = false
	for step in range(10):
		var owner: Control = editor.get_viewport().gui_get_focus_owner()
		if owner is LoadoutEditorScreen.ChoiceButton and editor.relic_buttons().has(owner):
			reached = true
			break
		await _press(KEY_RIGHT)
	assert_bool(reached).override_failure_message("Right never reached the relic panel").is_true()
	await _press(KEY_RIGHT)  # BD3b-0: the relics sit side by side, so Right (not Down) steps to the next one
	await _press(KEY_ENTER)
	var relic: String = editor.draft.starter_relic
	assert_str(relic).override_failure_message("Enter on a relic button did not pick it").is_not_empty()
	# save with Ctrl+S, leave with Esc
	var saved_deck: Array[String] = editor.draft.deck.duplicate()
	await _press(KEY_S, true)
	assert_array(LoadoutSession.store().usable_indices("rogue")).override_failure_message("Ctrl+S did not save a legal loadout").is_equal([0])
	await _press(KEY_ESCAPE)
	await _frames(2)
	assert_bool(is_instance_valid(editor) and editor.is_inside_tree()).override_failure_message("Esc after saving should leave the editor at once").is_false()
	assert_bool(main.get_node("SettingsScreen").call("is_open")).is_false()
	assert_bool(screen.is_open()).is_true()
	# back on the start screen: Down to the saved loadout, Enter starts the run with it
	await _frames(2)
	assert_array(screen.choice_slots()).contains([0])
	var guard: int = 0
	while screen.focused_slot() != 0 and guard < 8:
		await _press(KEY_DOWN)
		guard += 1
	assert_int(screen.focused_slot()).override_failure_message("could not reach the saved loadout row by keyboard").is_equal(0)
	await _press(KEY_ENTER)
	await _frames(3)
	var run: RunState = RunSession.current
	var started: Array[String] = run.deck.duplicate()
	started.sort()
	saved_deck.sort()
	assert_array(started).is_equal(saved_deck)
	assert_array(run.relics).contains([relic])
	assert_bool(LoadoutSession.store().last_used("rogue") == 0).is_true()
