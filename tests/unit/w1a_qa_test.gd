class_name W1aQaTest
extends GdUnitTestSuite
## qa's W1a tests: the class pick screen driven by real key and mouse events (the ux tests called methods), what leaks
## through it while the room is held, and the Try again loop after a class change.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	_reset()


func after_test() -> void:
	GamePause.resume()
	for child in get_children():
		if child is Main:
			child.queue_free()
	_reset()
	Juice.reset()
	GamePause.reset()


func _reset() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunSession.selected_character = ""
	RunSession.character_forced = false
	RunSession.forced_seed = -1
	CharacterPick.reset()
	CharacterPick.persist_override = false
	ClassPickScreen.reset()


func _idle(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _run_with_pick() -> Main:
	ClassPickScreen.enabled_override = true
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _idle(3)
	return main


func _pick_of(main: Main) -> ClassPickScreen:
	return main.get_node("ClassPickScreen") as ClassPickScreen


func _other_main(old_id: int) -> Main:
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			return child as Main
	return null


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func test_a_real_enter_key_starts_the_run_as_the_preselected_class() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	_key(KEY_ENTER)
	await _idle(3)
	assert_bool(screen.is_open()).override_failure_message("Enter on the preselected class must start the run").is_false()
	assert_bool(GamePause.is_paused()).is_false()
	assert_str(RunSession.current.character_id).is_equal("rogue")


func test_a_real_enter_before_the_arm_delay_does_nothing() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	_key(KEY_ENTER)
	await _idle(2)
	assert_bool(screen.is_open()).is_true()
	assert_bool(GamePause.is_paused()).is_true()


func test_real_key_2_then_enter_restarts_as_the_wizard_with_the_same_seed() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	var seed_value: int = RunSession.current.seed_value
	var old_id: int = main.get_instance_id()
	_key(KEY_2)
	await _idle(1)
	assert_str(screen.highlighted_id()).is_equal("wizard")
	assert_bool(screen.is_open()).override_failure_message("2 only highlights").is_true()
	_key(KEY_ENTER)
	await _idle(5)
	var fresh := _other_main(old_id)
	assert_object(fresh).is_not_null()
	assert_int(RunSession.current.seed_value).is_equal(seed_value)
	assert_str(RunSession.current.character_id).is_equal("wizard")
	assert_float((fresh.get_node("Player") as Player).health.max_health).is_equal(26.0)
	assert_bool(_pick_of(fresh).is_open()).is_false()
	assert_bool(GamePause.is_paused()).override_failure_message("no screen and a paused game: stuck").is_false()


func test_a_real_mouse_click_on_the_wizard_card_picks_the_wizard() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	var old_id: int = main.get_instance_id()
	var card: ClassPickCard = screen.card_for("wizard")
	_click(card.get_global_rect().get_center())
	await _idle(5)
	assert_str(RunSession.current.character_id).override_failure_message("a click on the Wizard card must pick it").is_equal("wizard")
	assert_object(_other_main(old_id)).is_not_null()
	assert_bool(GamePause.is_paused()).is_false()


func test_esc_behind_the_pick_screen_neither_opens_settings_nor_unpauses() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	TestInput.tap(&"pause")
	await _idle(2)
	assert_bool(screen.is_open()).is_true()
	assert_bool(GamePause.is_paused()).is_true()
	var settings: Node = main.get_node_or_null("SettingsScreen")
	if settings != null:
		assert_bool(bool(settings.call("is_open"))).override_failure_message("settings opened over the pick screen").is_false()
	TestInput.tap(&"pause")
	await _idle(2)
	assert_bool(GamePause.is_paused()).override_failure_message("Esc must not release the hold").is_true()
	screen.confirm()
	assert_bool(GamePause.is_paused()).is_false()


func test_nothing_runs_or_fires_behind_the_pick_screen_and_no_press_is_stored_for_later() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	var start_pos: Vector3 = main.player.global_position
	for action in [&"slot_1", &"slot_2", &"slot_3", &"slot_4", &"slot_5", &"dodge", &"attack_light", &"attack_heavy"]:
		if InputMap.has_action(action):
			TestInput.tap(action)
	await TestClock.wait_real(get_tree(), 0.6)
	assert_bool(screen.is_open()).is_true()
	assert_vector(main.player.global_position).is_equal_approx(start_pos, Vector3(0.001, 0.001, 0.001))
	assert_int((main.get_node("EnemySpawner") as EnemySpawner).alive_count()).override_failure_message("a wave spawned behind the screen").is_equal(0)
	for slot_type: Variant in main.player.card_slots.slots:
		var slot: CardSlot = main.player.card_slots.slots[slot_type]
		assert_float(slot.cooldown_remaining).override_failure_message("%s cooled or cast behind the screen" % str(slot_type)).is_equal(0.0)
	screen.disarm()
	screen.confirm()
	await _idle(4)
	for slot_type: Variant in main.player.card_slots.slots:
		var slot: CardSlot = main.player.card_slots.slots[slot_type]
		assert_float(slot.cooldown_remaining).override_failure_message("a press behind the screen was replayed after it closed").is_equal(0.0)


func test_try_again_after_a_class_change_reopens_with_the_new_class_preselected() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	var old_id: int = main.get_instance_id()
	screen.confirm("wizard")
	await _idle(5)
	var wizard_main := _other_main(old_id)
	assert_object(wizard_main).is_not_null()
	wizard_main.restart_arena()  # Try again
	await _idle(5)
	var again: Main = null
	for child in get_children():
		if child is Main and child != wizard_main and child != main and not child.is_queued_for_deletion():
			again = child as Main
	assert_object(again).is_not_null()
	var second := _pick_of(again)
	assert_bool(second.is_open()).override_failure_message("Try again must show the pick screen").is_true()
	assert_str(second.highlighted_id()).is_equal("wizard")
	assert_bool(GamePause.is_paused()).is_true()


# ---- characters.json: missing and wrongly typed fields must be reported, never crash ----

func test_every_required_character_field_missing_or_wrongly_typed_is_reported_without_a_crash() -> void:
	var good: Dictionary = CharacterDatabase.get_entry("wizard").duplicate(true)
	var keys: Array = good.keys()
	assert_array(keys).contains(["display_name", "max_hp", "pools", "attacks", "starting_deck", "body_color", "class_pool", "element_pool"])
	for key: Variant in keys:
		var missing: Dictionary = good.duplicate(true)
		missing.erase(key)
		assert_array(CharacterDatabase.validate_entry("wizard", missing)).override_failure_message("missing '%s' was accepted" % str(key)).is_not_empty()
		for wrong: Variant in [null, true, [], {}]:  # never a valid value for any field
			var bad: Dictionary = good.duplicate(true)
			bad[key] = wrong
			var problems: Array[String] = CharacterDatabase.validate_entry("wizard", bad)
			assert_array(problems).override_failure_message("'%s' = %s was accepted" % [str(key), str(wrong)]).is_not_empty()
	# Strings where numbers belong, and numbers where strings belong.
	var text_hp: Dictionary = good.duplicate(true)
	text_hp["max_hp"] = "26"
	assert_array(CharacterDatabase.validate_entry("wizard", text_hp)).is_not_empty()
	var number_name: Dictionary = good.duplicate(true)
	number_name["display_name"] = 5
	assert_array(CharacterDatabase.validate_entry("wizard", number_name)).is_not_empty()


func test_a_table_with_a_non_object_entry_or_nan_hp_is_reported() -> void:
	var good: Dictionary = CharacterDatabase.get_entry("wizard").duplicate(true)
	var table: Dictionary = {"rogue": CharacterDatabase.get_entry("rogue").duplicate(true), "wizard": "oops"}
	assert_array(CharacterDatabase.validate_table(table)).is_not_empty()
	good["max_hp"] = NAN
	assert_array(CharacterDatabase.validate_entry("wizard", good)).is_not_empty()
	good["max_hp"] = INF
	assert_array(CharacterDatabase.validate_entry("wizard", good)).is_not_empty()
