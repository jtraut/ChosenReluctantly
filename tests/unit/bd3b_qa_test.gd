class_name BD3bQaTest
extends GdUnitTestSuite
## BD3b slice review (qa): the BD3b-0 carry-overs that had no test (the keyboard walk across the one-row relic buttons, a 24-character
## name in a tab) and listener hygiene on the CombatEvents autoload.

const LOADOUTS := "user://tests/bd3b_qa_loadouts.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	_wipe()
	LoadoutSession.reset()
	RunSession.clear()
	RunConfig.reset_cache()
	CardDatabase.load_all()
	RelicDatabase.load_all()
	LoadoutRules.reset_cache()


func after_test() -> void:
	_wipe()
	LoadoutSession.reset()
	RunSession.clear()
	RunConfig.reset_cache()
	get_tree().paused = false


func _wipe() -> void:
	for path: String in [LOADOUTS, LOADOUTS + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _editor(class_id: String) -> LoadoutEditorScreen:
	var editor := LoadoutEditorScreen.new()
	editor.setup(class_id, LoadoutStore.new(LOADOUTS))
	add_child(editor)
	auto_free(editor)
	return editor


## Left and Right (the engine's own neighbour search, the one the arrow keys use) walk the one-row relic buttons in order, both ways, and
## no relic button is a focus trap: Up or Down gets out of the row.
func test_the_arrow_keys_walk_the_relic_buttons_in_order_and_do_not_trap_focus() -> void:
	var editor: LoadoutEditorScreen = _editor("wizard")
	await _frames(3)
	var buttons: Array[LoadoutEditorScreen.ChoiceButton] = editor.relic_buttons()
	assert_int(buttons.size()).is_equal(3)
	assert_object(buttons[0].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(buttons[1])
	assert_object(buttons[1].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(buttons[2])
	assert_object(buttons[2].find_valid_focus_neighbor(SIDE_LEFT)).is_same(buttons[1])
	assert_object(buttons[1].find_valid_focus_neighbor(SIDE_LEFT)).is_same(buttons[0])
	for button: LoadoutEditorScreen.ChoiceButton in buttons:
		var up: Control = button.find_valid_focus_neighbor(SIDE_TOP)
		var down: Control = button.find_valid_focus_neighbor(SIDE_BOTTOM)
		assert_bool(up != null and not buttons.has(up) or down != null and not buttons.has(down)).override_failure_message("a relic button is a focus trap (no way out by Up or Down)").is_true()


## A 24-character name (the longest allowed) must not widen its tab or push the state word out: the title clips, the tag stays.
func test_a_24_character_name_does_not_widen_its_tab_or_hide_the_unsaved_tag() -> void:
	var editor: LoadoutEditorScreen = _editor("wizard")
	await _frames(3)
	var tab: LoadoutEditorScreen.ChoiceButton = editor.tab_buttons()[0]
	var width_before: float = tab.size.x
	var long_name: String = "W".repeat(LoadoutRules.name_max_length())
	assert_int(long_name.length()).is_equal(24)
	editor.set_loadout_name(long_name)
	await _frames(3)
	assert_str(editor.draft.loadout_name).is_equal(long_name)
	assert_float(tab.size.x).override_failure_message("the tab grew with the name").is_equal(width_before)
	assert_bool(tab.tag_label.visible).override_failure_message("the unsaved tag is gone").is_true()
	assert_bool(tab.title_label.clip_text).is_true()
	# the tab still sits inside the screen
	assert_bool(tab.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x + 0.5).is_true()


## Every shipped test must leave the CombatEvents autoload with the connections it started with. This suite's own checks first, then
## a static scan of the BD3b-era test files for a connect on the autoload with no matching disconnect.
func test_the_autoload_signals_have_no_stray_test_listeners_from_this_suite() -> void:
	var before: int = CombatEvents.dash_passed_through.get_connections().size()
	var on_pass := func(_card_id: String, _count: int, _at: Vector3) -> void: pass
	CombatEvents.dash_passed_through.connect(on_pass)
	CombatEvents.dash_passed_through.disconnect(on_pass)
	assert_int(CombatEvents.dash_passed_through.get_connections().size()).is_equal(before)


func test_no_test_file_connects_a_lambda_to_a_combat_events_signal_without_disconnecting() -> void:
	var offenders: Array[String] = []
	var dir := DirAccess.open("res://tests/unit")
	assert_object(dir).is_not_null()
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://tests/unit/" + file_name)
		for line: String in text.split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("CombatEvents.") and ".connect(func" in stripped:
				offenders.append("%s: %s" % [file_name, stripped.left(80)])
	assert_array(offenders).override_failure_message("an anonymous lambda connected to the CombatEvents autoload can never be disconnected").is_empty()
