class_name ThreeDDTest
extends GdUnitTestSuite
## 3d sitting D (ux): the start screen's row model and screen, and the "On your plan" badge on card, shop and (not) other tiles.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const LOADOUTS := "user://tests/threed_d_loadouts.json"


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


func _texts() -> Dictionary:
	return RunConfig.ui().get("start_screen", {})


func _model(loadouts: Array, flagged: Array, last_used: int) -> Dictionary:
	return {"character": "rogue", "character_name": "Rogue", "preset": {"slot": LoadoutStore.PRESET, "name": "Preset deck", "deck_size": 15},
			"loadouts": loadouts, "flagged": flagged, "free_slots": [], "last_used": last_used, "messages": [], "rule_problems": []}


func _loadout(slot: int, plan: int = 0, relic: String = "", relic_name: String = "") -> Dictionary:
	return {"slot": slot, "name": "Mine %d" % slot, "deck_size": 16, "plan_size": plan, "starter_relic": relic, "starter_relic_name": relic_name}


func _save_loadout(slot: int) -> void:
	var deck: Array[String] = []
	deck.assign(CharacterDatabase.starting_deck("rogue"))
	var plan: Array[String] = []
	plan.assign(LoadoutCollection.plan_cards("rogue").slice(0, 2))
	var entry: Dictionary = LoadoutCheck.make_entry("Loadout %d" % (slot + 1), deck, plan, "")
	assert_array(LoadoutSession.store().save_entry("rogue", slot, entry)).is_empty()


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


# ---- the row model ----

func test_rows_list_the_preset_then_loadouts_then_flagged_then_the_edit_row() -> void:
	var model: Dictionary = _model([_loadout(0, 3, "x", "Heavy Sigh"), _loadout(2)], [{"slot": 1, "name": "", "message": "Too few cards."}], 2)
	var rows: Array[Dictionary] = StartScreen.rows_for(model, _texts())
	assert_array(rows.map(func(r: Dictionary) -> String: return String(r["kind"]))).is_equal(["preset", "loadout", "loadout", "flagged", "edit"])
	assert_array(rows.map(func(r: Dictionary) -> int: return int(r["slot"]))).is_equal([LoadoutStore.PRESET, 0, 2, LoadoutArgs.NO_SLOT, LoadoutArgs.NO_SLOT])
	assert_array(rows.map(func(r: Dictionary) -> bool: return bool(r["selectable"]))).is_equal([true, true, true, false, true])


func test_exactly_the_last_used_row_is_marked_and_the_edit_row_never_is() -> void:
	var rows: Array[Dictionary] = StartScreen.rows_for(_model([_loadout(0), _loadout(1)], [], 1), _texts())
	assert_array(rows.map(func(r: Dictionary) -> bool: return bool(r["last_used"]))).is_equal([false, false, true, false])
	rows = StartScreen.rows_for(_model([_loadout(0)], [], LoadoutStore.PRESET), _texts())
	assert_array(rows.map(func(r: Dictionary) -> bool: return bool(r["last_used"]))).is_equal([true, false, false])


func test_a_loadout_row_says_its_cards_plan_and_relic_and_skips_what_it_lacks() -> void:
	var rows: Array[Dictionary] = StartScreen.rows_for(_model([_loadout(0, 4, "r", "Heavy Sigh"), _loadout(1)], [], 0), _texts())
	var full: String = String(rows[1]["detail"])
	assert_str(full).contains("16").contains("4").contains("Heavy Sigh")
	var bare: String = String(rows[2]["detail"])
	assert_str(bare).contains("16")
	assert_bool(bare.contains("Plan")).override_failure_message("no plan, no plan line").is_false()
	assert_bool(bare.contains("Relic")).override_failure_message("no relic, no relic line").is_false()
	assert_str(String(rows[1]["title"])).starts_with("1.")


func test_a_flagged_row_carries_the_reason_and_cannot_be_chosen() -> void:
	var rows: Array[Dictionary] = StartScreen.rows_for(_model([], [{"slot": 3, "name": "", "message": "Too few cards."}], LoadoutStore.PRESET), _texts())
	var flagged: Dictionary = rows[1]
	assert_str(String(flagged["detail"])).is_equal("Too few cards.")
	assert_str(String(flagged["title"])).contains("4")
	assert_bool(bool(flagged["selectable"])).is_false()
	assert_int(int(flagged["slot"])).is_equal(LoadoutArgs.NO_SLOT)


func test_the_rows_of_the_real_model_match_its_usable_loadouts() -> void:
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	_save_loadout(0)
	_save_loadout(3)
	var model: Dictionary = LoadoutChoices.start_choices("rogue")
	var slots: Array = StartScreen.rows_for(model, _texts()).filter(func(r: Dictionary) -> bool: return String(r["kind"]) == "loadout").map(func(r: Dictionary) -> int: return int(r["slot"]))
	assert_array(slots).is_equal([0, 3])


# ---- the screen ----

func _write_loadouts_file(slots: Array, version: int = 1) -> void:
	var file := FileAccess.open(LOADOUTS, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": version, "classes": {"rogue": {"last_used": 1, "slots": slots}}}))
	file.close()


func _entry_dict(entry_name: String, deck: Array) -> Dictionary:
	var plan: Array[String] = []
	plan.assign(LoadoutCollection.plan_cards("rogue").slice(0, 2))
	return LoadoutCheck.make_entry(entry_name, deck, plan, "")


func test_the_screen_shows_a_skipped_loadout_with_its_reason_and_it_cannot_be_started() -> void:
	var good: Dictionary = _entry_dict("Fine", CharacterDatabase.starting_deck("rogue"))
	var bad: Dictionary = _entry_dict("Tiny", CharacterDatabase.starting_deck("rogue").slice(0, 3))
	_write_loadouts_file([good, good.duplicate(true), bad, null, null])
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_bool(screen.is_open()).is_true()
	assert_array(screen.choice_slots()).is_equal([LoadoutStore.PRESET, 0, 1])
	var flagged: Array[Dictionary] = screen.rows().filter(func(r: Dictionary) -> bool: return String(r["kind"]) == "flagged")
	assert_int(flagged.size()).is_equal(1)
	assert_str(String(flagged[0]["detail"])).is_not_empty()
	assert_str(String(flagged[0]["title"])).contains("3")
	assert_int(screen.row_buttons().size()).override_failure_message("preset, two loadouts and the edit row; the skipped one is no button").is_equal(4)
	assert_int(screen.focused_slot()).override_failure_message("last used (slot 1) is preselected").is_equal(1)
	var focused: StartScreen.StartRow = null
	for button in screen.row_buttons():
		if button.has_focus():
			focused = button as StartScreen.StartRow
	assert_object(focused).is_not_null()
	assert_object(focused.last_used_tag).override_failure_message("the preselected row wears the Last used tag").is_not_null()
	assert_float(focused.arrow.modulate.a).override_failure_message("the highlighted row shows its arrow").is_equal(1.0)
	assert_array(StartScreen.notes_for(screen.choices())).override_failure_message("a skipped loadout has its own row, not a note").is_empty()


func test_a_whole_file_problem_is_still_printed() -> void:
	_write_loadouts_file([], 99)
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	var notes: Array[String] = StartScreen.notes_for(LoadoutChoices.start_choices("rogue"))
	assert_int(notes.size()).is_equal(1)
	assert_str(notes[0]).contains("loadouts ignored")
	# a skipped-loadout message is not repeated as a note
	assert_array(StartScreen.notes_for({"messages": ["rogue loadout 3 'Tiny' skipped: too few cards", "rogue loadout 2 skipped: x"]})).is_empty()
	assert_array(StartScreen.notes_for({"messages": ["loadouts for unknown class 'bard' skipped"]})).has_size(1)


func test_down_moves_the_highlight_and_enter_on_the_preset_starts_it() -> void:
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	_save_loadout(0)
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	var state: RunState = RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	assert_int(screen.focused_slot()).is_equal(LoadoutStore.PRESET)
	var buttons: Array[Button] = screen.row_buttons()
	buttons[1].grab_focus()
	assert_int(screen.focused_slot()).is_equal(0)
	assert_float((buttons[1] as StartScreen.StartRow).arrow.modulate.a).is_equal(1.0)
	assert_float((buttons[0] as StartScreen.StartRow).arrow.modulate.a).override_failure_message("only the highlighted row shows the arrow").is_equal(0.0)
	buttons[0].grab_focus()
	screen.disarm()
	buttons[0].pressed.emit()  # what Enter or a click does to the focused button
	assert_bool(screen.is_open()).is_false()
	assert_bool(RunSession.current == state).is_true()


func test_the_edit_row_opens_the_editor() -> void:
	assert_array(LoadoutSession.apply_args(PackedStringArray(["--runs-finished=1", "--loadouts-path=" + LOADOUTS]))).is_empty()
	StartScreen.enabled_override = true
	ClassPickScreen.enabled_override = false
	RunSession.begin_new_run(31, "rogue")
	var main: Main = _spawn()
	await _frames(3)
	var screen := main.get_node("StartScreen") as StartScreen
	screen.disarm()
	var buttons: Array[Button] = screen.row_buttons()
	buttons[buttons.size() - 1].pressed.emit()
	await _frames(2)
	var editors: int = 0
	for child in screen.get_children():
		if child is LoadoutEditorScreen:
			editors += 1
	assert_int(editors).is_equal(1)


# ---- the badge ----

func _card_option(card_id: String, on_plan: bool) -> Dictionary:
	var card: Dictionary = CardDatabase.get_card(card_id)
	return {"kind": "card", "card_id": card_id, "label": String(card.get("name", card_id)), "detail": "x", "slot_type": String(card.get("slot_type", "")), "enabled": true, "on_plan": on_plan}


func _tile(opt: Dictionary, look: RunOptionCard.Look, width: float, extra: Dictionary) -> RunOptionCard:
	var button := RunOptionCard.new()
	add_child(button)
	auto_free(button)
	var full: Dictionary = {"index": -1, "owned": 0, "texts": RunConfig.ui()["option"], "shop_texts": RunConfig.ui().get("merchant", {}), "gold": 99}
	full.merge(extra, true)
	button.setup(opt, look, width, UiConfig.run_ui(), 1.0, full)
	return button


func test_the_plan_text_is_data() -> void:
	assert_str(String(RunConfig.ui()["option"].get("on_plan_tag", ""))).is_equal("On your plan")


func test_a_reward_card_on_the_plan_wears_the_badge_with_a_check_and_the_words() -> void:
	var card_id: String = LoadoutCollection.plan_cards("rogue")[0]
	var tile: RunOptionCard = _tile(_card_option(card_id, true), RunOptionCard.Look.CARD, 268.0, {})
	assert_object(tile.plan_tag).is_not_null()
	var words: Array[String] = []
	var marks: int = 0
	for node in tile.plan_tag.find_children("*", "", true, false):
		if node is Label:
			words.append((node as Label).text)
		if node is RunTypeIcon and (node as RunTypeIcon).shape == RunIcons.SHAPE_CHECK:
			marks += 1
	assert_array(words).is_equal(["On your plan"])
	assert_int(marks).override_failure_message("a check mark, so it is not colour alone").is_equal(1)
	assert_bool(tile.plan_tag.get_parent() == tile.get_child(0)).override_failure_message("it sits in the tile's column").is_true()


func test_a_card_off_the_plan_has_no_badge() -> void:
	var card_id: String = LoadoutCollection.plan_cards("rogue")[0]
	assert_object(_tile(_card_option(card_id, false), RunOptionCard.Look.CARD, 268.0, {}).plan_tag).is_null()
	var no_flag: Dictionary = _card_option(card_id, false)
	no_flag.erase("on_plan")
	assert_object(_tile(no_flag, RunOptionCard.Look.CARD, 268.0, {}).plan_tag).is_null()


func test_a_removal_cell_and_a_relic_never_show_the_badge() -> void:
	var card_id: String = LoadoutCollection.plan_cards("rogue")[0]
	assert_object(_tile(_card_option(card_id, true), RunOptionCard.Look.CELL, 214.0, {}).plan_tag).override_failure_message("the removal grid lists the deck: nothing is 'on the plan' there").is_null()
	var relic: Dictionary = {"kind": "relic", "relic_id": LoadoutCollection.starter_relics("rogue")[0], "label": "Relic", "detail": "x", "enabled": true, "on_plan": true}
	assert_object(_tile(relic, RunOptionCard.Look.RELIC, 268.0, {}).plan_tag).override_failure_message("a relic is never on the plan").is_null()


func test_a_merchant_card_on_the_plan_wears_the_badge_beside_its_slot_chip() -> void:
	var card_id: String = LoadoutCollection.plan_cards("rogue")[0]
	var opt: Dictionary = _card_option(card_id, true)
	opt["kind"] = "buy_card"
	opt.merge({"price": 40, "sold": false, "can_buy": true, "reason": "", "needs_giveup": false, "sacrifice_cost": 0}, true)
	var tile: RunOptionCard = _tile(opt, RunOptionCard.Look.SHOP, 268.0, {"shop_name": String(opt["label"])})
	assert_object(tile.plan_tag).is_not_null()
	opt["on_plan"] = false
	assert_object(_tile(opt, RunOptionCard.Look.SHOP, 268.0, {"shop_name": String(opt["label"])}).plan_tag).is_null()


func test_a_disabled_badge_is_greyed_not_green() -> void:
	var card_id: String = LoadoutCollection.plan_cards("rogue")[0]
	var opt: Dictionary = _card_option(card_id, true)
	opt["enabled"] = false
	opt["reason"] = "nope"
	var tile: RunOptionCard = _tile(opt, RunOptionCard.Look.CARD, 268.0, {})
	var style: StyleBoxFlat = tile.plan_tag.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(style).is_not_null()
	assert_bool(style.bg_color.is_equal_approx(Color.html(String(UiConfig.run_ui()["option_disabled_text_color"])))).is_true()
