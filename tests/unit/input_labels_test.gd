class_name InputLabelsTest
extends GdUnitTestSuite
## K1: key text follows the live InputMap; the binding validator; slot name + key exposure.

const TEMP_ACTION: StringName = &"k1_test_action"
const SHIPPED := "res://data/input_bindings.json"

var _slot_5_events: Array[InputEvent] = []


func before_test() -> void:
	_slot_5_events = InputMap.action_get_events(&"slot_5")


func after_test() -> void:
	if InputMap.has_action(TEMP_ACTION):
		InputMap.erase_action(TEMP_ACTION)
	InputMap.action_erase_events(&"slot_5")
	for event: InputEvent in _slot_5_events:
		InputMap.action_add_event(&"slot_5", event)


func _key(code: Key, shift: bool = false, ctrl: bool = false, alt: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	return e


func _bind(event: InputEvent) -> void:
	if InputMap.has_action(TEMP_ACTION):
		InputMap.action_erase_events(TEMP_ACTION)
	else:
		InputMap.add_action(TEMP_ACTION)
	InputMap.action_add_event(TEMP_ACTION, event)


# --- Label helper ---------------------------------------------------------------------------------------

func test_plain_key_and_digit_labels() -> void:
	_bind(_key(KEY_Q))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("Q")
	_bind(_key(KEY_1))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("1")
	_bind(_key(KEY_2))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("2")


func test_modifier_combos() -> void:
	_bind(_key(KEY_Q, true))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("Shift+Q")
	_bind(_key(KEY_R, false, true))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("Ctrl+R")
	_bind(_key(KEY_F, true, false, true))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("Alt+Shift+F")


func test_mouse_buttons() -> void:
	for pair: Array in [[MOUSE_BUTTON_LEFT, "LMB"], [MOUSE_BUTTON_RIGHT, "RMB"], [MOUSE_BUTTON_MIDDLE, "MMB"]]:
		var e := InputEventMouseButton.new()
		e.button_index = pair[0]
		_bind(e)
		assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal(pair[1])


func test_unbound_and_unknown_actions_show_a_question_mark() -> void:
	_bind(_key(KEY_Q))
	InputMap.action_erase_events(TEMP_ACTION)
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("?")
	assert_str(InputLabels.for_action(&"no_such_action_k1")).is_equal("?")


func test_label_follows_a_rebind_with_no_stale_cache() -> void:
	assert_str(InputLabels.for_action(&"slot_5")).is_equal("R")
	InputMap.action_erase_events(&"slot_5")
	InputMap.action_add_event(&"slot_5", _key(KEY_F))
	assert_str(InputLabels.for_action(&"slot_5")).is_equal("F")
	assert_str(InputLabels.slot_key("recovery")).is_equal("F")


func test_first_binding_is_used() -> void:
	_bind(_key(KEY_Q))
	InputMap.action_add_event(TEMP_ACTION, _key(KEY_E))
	assert_str(InputLabels.for_action(TEMP_ACTION)).is_equal("Q")


func test_load_bindings_emits_bindings_changed() -> void:
	var fired: Array[int] = [0]
	var cb := func() -> void: fired[0] += 1
	InputBindings.bindings_changed.connect(cb)
	InputBindings.load_bindings(SHIPPED)
	InputBindings.bindings_changed.disconnect(cb)
	assert_int(fired[0]).is_equal(1)
	assert_array(InputBindings.last_conflicts).is_empty()


# --- Validator ------------------------------------------------------------------------------------------

func test_shipped_bindings_have_no_conflicts() -> void:
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHIPPED))
	assert_array(InputLabels.find_conflicts(bindings)).is_empty()


func test_validator_rejects_duplicate_key_and_modifiers() -> void:
	var bindings := {
		"a": [{"type": "key", "keycode": "R"}],
		"b": [{"type": "key", "keycode": "R"}],
		"c": [{"type": "key", "keycode": "Q", "shift": true}],
		"d": [{"type": "key", "keycode": "Q", "shift": true}],
	}
	assert_array(InputLabels.find_conflicts(bindings)).has_size(2)


func test_validator_rejects_duplicate_mouse_button() -> void:
	var bindings := {
		"a": [{"type": "mouse_button", "button": "LEFT"}],
		"b": [{"type": "mouse_button", "button": "LEFT"}],
	}
	assert_array(InputLabels.find_conflicts(bindings)).has_size(1)


func test_plain_r_and_shift_r_are_not_a_conflict() -> void:
	var bindings := {
		"slot_5": [{"type": "key", "keycode": "R"}],
		"dead_card_swap_5": [{"type": "key", "keycode": "R", "shift": true}],
		"lmb": [{"type": "mouse_button", "button": "LEFT"}],
		"rmb": [{"type": "mouse_button", "button": "RIGHT"}],
	}
	assert_array(InputLabels.find_conflicts(bindings)).is_empty()


# --- Slot exposure --------------------------------------------------------------------------------------

func test_slot_name_and_key_come_from_data_and_the_input_map() -> void:
	assert_str(InputLabels.slot_name("recovery")).is_equal("Recovery")
	assert_str(InputLabels.slot_key("recovery")).is_equal("R")
	assert_str(InputLabels.slot_label("recovery")).is_equal("Recovery (R)")
	assert_str(InputLabels.slot_swap_key("recovery")).is_equal("Shift+R")
	assert_str(InputLabels.slot_label("movement")).is_equal("Movement (2)")
	assert_str(InputLabels.slot_label_at(0)).is_equal("Attack: Single (Q)")


func test_every_slot_index_has_a_name_and_a_key() -> void:
	for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		assert_str(InputLabels.slot_name_at(i)).is_not_empty()
		assert_str(InputLabels.slot_key_at(i)).is_not_equal("?")
		assert_str(InputLabels.slot_swap_key_at(i)).starts_with("Shift+")


func test_unknown_slot_type_is_safe() -> void:
	assert_str(InputLabels.slot_key("nope")).is_equal("?")
	assert_str(InputLabels.slot_swap_key("nope")).is_equal("?")
	assert_str(InputLabels.slot_name_at(99)).is_equal("")
