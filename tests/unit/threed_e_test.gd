class_name ThreeDETest
extends GdUnitTestSuite
## 3d sitting E (ux): the loadout editor's model (badges, tiles, chips, tabs, plan lines) and screen (keyboard and mouse paths, blocked saves, the unsaved-edit guard, the round trip
## from the start screen into a run).

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const LOADOUTS := "user://tests/threed_e_loadouts.json"


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
	return RunConfig.ui().get("loadout_editor", {})


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _editor(store: LoadoutStore = null) -> LoadoutEditorScreen:
	var use: LoadoutStore = store if store != null else LoadoutStore.new(LOADOUTS)
	var editor := LoadoutEditorScreen.new()
	editor.setup("rogue", use)
	add_child(editor)
	auto_free(editor)
	return editor


func _starter_not_in(deck: Array[String]) -> String:
	for id: String in LoadoutCollection.starter_cards("rogue"):
		if not deck.has(id):
			return id
	return ""


# ---- the model ----

func test_the_texts_are_data() -> void:
	for key: String in ["title", "badge_starter", "badge_reward", "badge_locked", "save", "back", "ok_line", "problems_title", "discard_warning", "hint"]:
		assert_str(String(_texts().get(key, ""))).override_failure_message("run.json ui.loadout_editor." + key).is_not_empty()


func test_badges_say_starter_reward_and_locked_with_the_condition_or_tbd() -> void:
	assert_str(String(LoadoutEditorScreen.badge_for({"availability": "starter"}, _texts())["text"])).is_equal("Starter")
	assert_str(String(LoadoutEditorScreen.badge_for({"availability": "reward"}, _texts())["text"])).is_equal("Reward")
	assert_str(String(LoadoutEditorScreen.badge_for({"availability": "locked", "unlock": "Beat act 2"}, _texts())["text"])).is_equal("Locked: Beat act 2")
	assert_str(String(LoadoutEditorScreen.badge_for({"availability": "locked", "unlock": ""}, _texts())["text"])).is_equal("Locked: TBD")
	assert_str(String(LoadoutEditorScreen.badge_for({"availability": "locked"}, _texts())["kind"])).is_equal("locked")


func test_a_locked_card_goes_to_the_plan_not_the_deck_in_the_tile_model() -> void:
	var draft: LoadoutDraft = LoadoutDraft.from_preset("rogue", 0)
	var plan_id: String = LoadoutCollection.plan_cards("rogue")[0]
	var fake: Array[Dictionary] = [{"slot_type": "movement", "slot_name": "Movement", "cards": [{"id": plan_id, "name": "Fake", "availability": "locked", "unlock": "", "rarity": "rare", "flavor": ""}]}]
	var tile: Dictionary = (LoadoutEditorScreen.tiles_for(draft, fake, _texts())[0]["cards"] as Array)[0]
	assert_str(String(tile["badge_text"])).is_equal("Locked: TBD")
	assert_bool(bool(tile["to_plan"])).is_true()
	assert_str(String(tile["action_text"])).is_equal("Add to plan")
	draft.add_card(plan_id)
	tile = (LoadoutEditorScreen.tiles_for(draft, fake, _texts())[0]["cards"] as Array)[0]
	assert_bool(bool(tile["on_plan"])).is_true()
	assert_bool(bool(tile["can_add"])).override_failure_message("one of each on the plan").is_false()
	assert_str(String(tile["action_text"])).is_equal("On plan")


func test_tiles_carry_copies_up_to_two_and_the_header_has_the_live_count() -> void:
	var draft: LoadoutDraft = LoadoutDraft.from_preset("rogue", 0)
	var groups: Array[Dictionary] = LoadoutDraft.collection_by_slot("rogue")
	var held: String = draft.deck[0]
	var tiles: Array[Dictionary] = LoadoutEditorScreen.tiles_for(draft, groups, _texts())
	var found: Dictionary = {}
	for group: Dictionary in tiles:
		assert_str(String(group["header"])).contains("%d/%d" % [int(group["count"]), int(group["required"])])
		for tile: Dictionary in (group["cards"] as Array):
			if String(tile["id"]) == held:
				found = tile
	assert_int(int(found["copies"])).is_equal(draft.copies(held))
	assert_int(int(found["max_copies"])).is_equal(2)
	while draft.copies(held) < 2:
		draft.add_card(held)
	for group: Dictionary in LoadoutEditorScreen.tiles_for(draft, groups, _texts()):
		for tile: Dictionary in (group["cards"] as Array):
			if String(tile["id"]) == held:
				assert_str(String(tile["action_text"])).is_equal("x2")
				assert_bool(bool(tile["can_add"])).is_false()


func test_chips_show_the_deck_size_and_each_slot_and_mark_short_ones() -> void:
	var draft: LoadoutDraft = LoadoutDraft.from_preset("rogue", 0)
	var chips: Array[Dictionary] = LoadoutEditorScreen.chips_for(draft, _texts())
	assert_str(String(chips[0]["label"])).contains("15").contains("20")
	assert_bool(bool(chips[0]["ok"])).is_true()
	assert_int(chips.size()).is_greater_equal(1 + SlotTypeDatabase.known_ids().size())
	draft.deck.clear()
	chips = LoadoutEditorScreen.chips_for(draft, _texts())
	assert_bool(bool(chips[0]["ok"])).is_false()
	assert_bool(chips.slice(1).all(func(c: Dictionary) -> bool: return not bool(c["ok"]))).override_failure_message("an empty deck is short in every slot").is_true()
	assert_str(String(chips[1]["label"])).contains("0/")


func test_tabs_name_saved_empty_and_skipped_slots() -> void:
	var store := LoadoutStore.new(LOADOUTS)
	var deck: Array[String] = []
	deck.assign(CharacterDatabase.starting_deck("rogue"))
	assert_array(store.save_entry("rogue", 1, LoadoutCheck.make_entry("Mine", deck))).is_empty()
	var tabs: Array[Dictionary] = LoadoutEditorScreen.tabs_for(store, "rogue", _texts())
	assert_int(tabs.size()).is_equal(5)
	assert_str(String(tabs[1]["title"])).is_equal("2. Mine")
	assert_str(String(tabs[1]["state"])).is_equal("saved")
	assert_str(String(tabs[0]["title"])).is_equal("1. Empty")


func test_default_names_are_class_and_slot() -> void:
	assert_str(LoadoutEditorScreen.default_name_for(_texts(), "rogue", 1)).is_equal("Rogue loadout 2")
	assert_str(LoadoutEditorScreen.default_name_for(_texts(), "wizard", 0)).is_equal("Wizard loadout 1")


func test_the_tab_of_a_filled_draft_shows_its_name_and_unsaved_state_never_empty() -> void:
	var store := LoadoutStore.new(LOADOUTS)
	var draft: LoadoutDraft = LoadoutDraft.from_preset("rogue", 0)
	draft.loadout_name = "Brawler"
	var tabs: Array[Dictionary] = LoadoutEditorScreen.tabs_for(store, "rogue", _texts(), draft, false)
	assert_str(String(tabs[0]["label"])).is_equal("1. Brawler")
	assert_str(String(tabs[0]["tag"])).is_equal("unsaved")
	assert_str(String(tabs[0]["state"])).is_equal("draft")
	assert_str(String(tabs[1]["title"])).is_equal("2. Empty")
	draft.loadout_name = ""
	assert_str(String(LoadoutEditorScreen.tabs_for(store, "rogue", _texts(), draft, false)[0]["label"])).is_equal("1. Rogue loadout 1")


func test_the_detail_strip_lists_keywords_and_the_decks_slot_mates() -> void:
	var draft: LoadoutDraft = LoadoutDraft.from_preset("rogue", 0)
	var card_id: String = draft.deck[0]
	var slot_type: String = String(CardDatabase.get_card(card_id)["slot_type"])
	var line: String = LoadoutEditorScreen.slot_mates_text(draft, card_id, _texts())
	assert_str(line).starts_with("In slot: ")
	assert_str(line).contains(String(CardDatabase.get_card(card_id)["name"]))
	assert_str(LoadoutEditorScreen.detail_chips_text(card_id)).is_equal(", ".join(PackedStringArray(SlotSynergy.chips(card_id))))
	draft.deck.clear()
	assert_str(LoadoutEditorScreen.slot_mates_text(draft, card_id, _texts())).is_equal("")
	assert_str(slot_type).is_not_empty()


# ---- the screen ----

func test_the_screen_lists_every_collection_card_once_with_a_badge() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	assert_int(editor.card_ids().size()).is_equal(LoadoutCollection.collection("rogue").size())
	for tile_group: Dictionary in editor.tiles():
		for tile: Dictionary in (tile_group["cards"] as Array):
			var row := editor.card_row(String(tile["id"])) as LoadoutEditorScreen.CardRow
			assert_str(row.badge_label.text).is_equal(String(tile["badge_text"]))
	assert_str(editor.focused_card_id()).override_failure_message("the editor opens with a card focused so the arrows work").is_not_empty()


func test_enter_on_a_row_adds_and_delete_removes() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	var id: String = _starter_not_in(editor.draft.deck)
	assert_str(id).is_not_empty()
	var row := editor.card_row(id)
	row.pressed.emit()  # Enter or a click
	assert_int(editor.draft.copies(id)).is_equal(1)
	assert_str((row as LoadoutEditorScreen.CardRow).action_label.text).is_equal("x1")
	assert_float((row as LoadoutEditorScreen.CardRow).minus.modulate.a).is_equal(1.0)
	var key := InputEventKey.new()
	key.keycode = KEY_DELETE
	key.pressed = true
	(row as LoadoutEditorScreen.CardRow)._on_gui_input(key)
	assert_int(editor.draft.copies(id)).is_equal(0)


func test_a_refusal_goes_to_the_status_line_and_never_replaces_the_checkers_reasons() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	var id: String = editor.draft.deck[0]
	while editor.draft.copies(id) < 2:
		editor.add(id)
	var refusal: String = editor.add(id)
	assert_str(refusal).is_not_empty()
	assert_str(editor.status_text()).is_equal(refusal)
	editor.draft.deck.clear()
	editor._refresh()
	assert_array(editor.shown_problems()).is_not_empty()
	assert_bool(editor.save_button().disabled).is_true()


func test_a_reward_card_goes_on_the_plan_and_shows_in_the_plan_section() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	var id: String = LoadoutCollection.plan_cards("rogue")[0]
	var deck_before: int = editor.draft.deck.size()
	editor.card_row(id).pressed.emit()
	assert_array(editor.draft.plan).contains([id])
	assert_int(editor.draft.deck.size()).is_equal(deck_before)
	var words: Array[String] = []
	for node in editor._plan_box.find_children("*", "Label", true, false):
		words.append((node as Label).text)
	assert_bool(words.any(func(w: String) -> bool: return w.contains(String(CardDatabase.get_card(id)["name"])))).is_true()


func test_saving_is_blocked_with_the_checkers_words_and_allowed_when_legal() -> void:
	var store := LoadoutStore.new(LOADOUTS)
	var editor: LoadoutEditorScreen = _editor(store)
	await _frames()
	assert_bool(editor.save_button().disabled).override_failure_message("the preset deck is legal").is_false()
	while editor.draft.deck.size() > 10:
		editor.remove(editor.draft.deck[0])
	assert_bool(editor.save_button().disabled).is_true()
	var shown: Array[String] = editor.shown_problems()
	assert_array(shown).is_equal(LoadoutCheck.entry_problems("rogue", editor.draft.entry()))
	assert_bool(shown.any(func(p: String) -> bool: return p.contains("at least 15"))).is_true()
	assert_array(editor.save()).is_not_empty()
	assert_array(store.usable_indices("rogue")).is_empty()


func test_the_name_field_is_capped_by_the_rules_data() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	assert_int(editor.name_edit().max_length).is_equal(LoadoutRules.name_max_length())
	editor.set_loadout_name("")
	assert_bool(editor.save_button().disabled).override_failure_message("BD3b-0: a blank name is filled with the default, so it never blocks Save").is_false()
	assert_array(editor.shown_problems()).is_empty()
	assert_array(editor.save()).is_empty()
	assert_str(editor.draft.loadout_name).is_equal(LoadoutEditorScreen.default_name_for(_texts(), "rogue", editor.draft.slot))


func test_the_relic_pick_has_none_plus_two_and_one_is_marked() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	assert_int(editor.relic_buttons().size()).is_equal(3)
	assert_float(editor.relic_buttons()[0].mark.modulate.a).is_equal(1.0)
	var relic: String = String(editor.relic_buttons()[1].get_meta("relic"))
	editor.relic_buttons()[1].pressed.emit()
	assert_str(editor.draft.starter_relic).is_equal(relic)
	assert_float(editor.relic_buttons()[1].mark.modulate.a).override_failure_message("the pick shows a check mark, not just a colour").is_equal(1.0)
	assert_float(editor.relic_buttons()[0].mark.modulate.a).is_equal(0.0)


func test_leaving_or_switching_with_unsaved_edits_asks_once_and_a_clean_draft_does_not() -> void:
	var editor: LoadoutEditorScreen = _editor()
	await _frames()
	assert_bool(editor.is_dirty()).is_false()
	var closed_count: Array[int] = [0]
	editor.closed.connect(func() -> void: closed_count[0] += 1)
	editor.remove(editor.draft.deck[0])
	assert_bool(editor.is_dirty()).is_true()
	editor.request_slot(2)
	assert_int(editor.draft.slot).override_failure_message("first press only warns").is_not_equal(2)
	assert_str(editor.status_text()).is_equal(String(_texts()["discard_warning"]))
	editor.request_slot(2)
	assert_int(editor.draft.slot).is_equal(2)
	assert_bool(editor.is_dirty()).is_false()
	editor.remove(editor.draft.deck[0])
	editor.request_close()
	assert_int(closed_count[0]).is_equal(0)
	editor.request_close()
	assert_int(closed_count[0]).is_equal(1)


func test_delete_asks_twice() -> void:
	var store := LoadoutStore.new(LOADOUTS)
	var editor: LoadoutEditorScreen = _editor(store)
	await _frames()
	assert_bool(editor.delete_button().disabled).override_failure_message("nothing saved here yet").is_true()
	assert_array(editor.save()).is_empty()
	assert_bool(editor.delete_button().disabled).is_false()
	editor.request_delete()
	assert_array(store.usable_indices("rogue")).is_equal([0])
	editor.request_delete()
	assert_array(store.usable_indices("rogue")).is_empty()


func test_escape_goes_back_and_ctrl_s_saves() -> void:
	var store := LoadoutStore.new(LOADOUTS)
	var editor: LoadoutEditorScreen = _editor(store)
	await _frames()
	var save_key := InputEventKey.new()
	save_key.keycode = KEY_S
	save_key.ctrl_pressed = true
	save_key.pressed = true
	editor._input(save_key)
	assert_array(store.usable_indices("rogue")).is_equal([0])
	var closed_count: Array[int] = [0]
	editor.closed.connect(func() -> void: closed_count[0] += 1)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	editor._input(esc)
	assert_int(closed_count[0]).is_equal(1)


# ---- the round trip ----

func test_build_save_then_start_a_run_with_it_from_the_start_screen() -> void:
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
	# a legal loadout: the preset plus a different starter card, a name and a starter relic
	editor.set_loadout_name("Round trip")
	var extra: String = _starter_not_in(editor.draft.deck)
	editor.add(extra)
	var relic: String = String(editor.relic_buttons()[2].get_meta("relic"))
	editor.relic_buttons()[2].pressed.emit()
	var saved_deck: Array[String] = editor.draft.deck.duplicate()
	assert_array(editor.save()).is_empty()
	assert_bool(FileAccess.file_exists(LOADOUTS)).override_failure_message("saved to the scratch file").is_true()
	editor.request_close()
	await _frames(2)
	assert_array(screen.choice_slots()).contains([0])
	screen.choose(0)
	var run: RunState = RunSession.current
	var started: Array[String] = run.deck.duplicate()
	started.sort()
	saved_deck.sort()
	assert_array(started).is_equal(saved_deck)
	assert_array(run.relics).contains([relic])
