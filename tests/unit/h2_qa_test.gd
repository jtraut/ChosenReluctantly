class_name H2QaTest
extends GdUnitTestSuite
## H2 qa: the binding validator against the shipped file with the switch on, real duplicates, a malformed dodge entry, and a
## Space key event never reaching the unbound dodge action.


func after_test() -> void:
	PlayerConfig.reload()


func _shipped_bindings() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(InputBindings.BINDINGS_PATH)) as Dictionary


func test_the_shipped_file_with_the_switch_forced_on_is_rejected_for_the_missing_key_and_names_both_files() -> void:
	var problems: Array[String] = InputLabels.find_missing_required(_shipped_bindings(), true)
	assert_array(problems).has_size(1)
	assert_str(problems[0]).contains("player.json")
	assert_str(problems[0]).contains("input_bindings.json")
	assert_array(InputLabels.find_missing_required(_shipped_bindings(), false)).is_empty()


func test_a_dodge_key_that_duplicates_a_card_key_is_a_conflict_with_the_switch_on() -> void:
	for clash: Array in [["Space", false, "slot_4"], ["F", false, "slot_3"], ["Space", true, "dead_card_swap_4"], ["Q", false, "slot_1"]]:
		var bindings: Dictionary = _shipped_bindings()
		bindings["dodge"] = [{"type": "key", "keycode": clash[0], "shift": clash[1]}]
		var conflicts: Array[String] = InputLabels.find_conflicts(bindings)
		assert_array(conflicts).override_failure_message("dodge on %s (shift %s) should clash with %s" % [clash[0], clash[1], clash[2]]).is_not_empty()
		assert_str(" ".join(conflicts)).contains(clash[2])
		assert_str(" ".join(conflicts)).contains("dodge")
		# A real key is present, so the missing-key rule stays quiet: the duplicate is reported once, by find_conflicts.
		assert_array(InputLabels.find_missing_required(bindings, true)).is_empty()


func test_a_free_test_key_is_accepted_with_the_switch_on_and_shift_space_is_not_plain_space() -> void:
	var bindings: Dictionary = _shipped_bindings()
	bindings["dodge"] = [{"type": "key", "keycode": "F9"}]
	assert_array(InputLabels.find_conflicts(bindings)).is_empty()
	assert_array(InputLabels.find_missing_required(bindings, true)).is_empty()
	assert_array(InputLabels.find_conflicts(_shipped_bindings())).is_empty()


func test_a_malformed_dodge_entry_does_not_count_as_a_key() -> void:
	for bad: Variant in [[{}], [{"type": "key"}], [{"type": "key", "keycode": ""}], "Space", null, 7]:
		var bindings: Dictionary = {"dodge": bad}
		assert_array(InputLabels.find_missing_required(bindings, true)).override_failure_message("dodge = %s counted as a key" % str(bad)).has_size(1)
		assert_array(InputLabels.find_missing_required(bindings, false)).is_empty()


func test_the_real_startup_check_stays_quiet_on_the_shipped_pair() -> void:
	assert_bool(PlayerConfig.dodge_enabled()).is_false()
	assert_array(InputLabels.find_missing_required(_shipped_bindings(), PlayerConfig.dodge_enabled())).is_empty()
	assert_int(InputBindings.last_conflicts.size()).is_equal(0)


func test_space_and_f_key_events_match_their_card_actions_and_never_the_dodge_action() -> void:
	for pair: Array in [[KEY_SPACE, &"slot_4"], [KEY_F, &"slot_3"]]:
		var event := InputEventKey.new()
		event.physical_keycode = pair[0]
		event.keycode = pair[0]
		event.pressed = true
		assert_bool(event.is_action(pair[1])).override_failure_message("key %s should be %s" % [pair[0], pair[1]]).is_true()
		assert_bool(event.is_action(&"dodge")).override_failure_message("key %s must not be the dodge" % pair[0]).is_false()
		var shifted := event.duplicate() as InputEventKey
		shifted.shift_pressed = true
		assert_bool(shifted.is_action(&"dead_card_swap_%s" % str(pair[1]).trim_prefix("slot_"))).is_true()
