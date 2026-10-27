extends Node
## Autoload. Builds the project's InputMap actions from data/input_bindings.json
## so key remapping is a data edit, not a code change.

const BINDINGS_PATH := "res://data/input_bindings.json"


func _enter_tree() -> void:
	load_bindings(BINDINGS_PATH)


func load_bindings(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("InputBindings: could not open '%s'" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("InputBindings: '%s' did not parse to a JSON object" % path)
		return
	var bindings: Dictionary = parsed
	for action_name: String in bindings.keys():
		_apply_action(action_name, bindings[action_name])


func _apply_action(action_name: String, event_specs: Variant) -> void:
	if typeof(event_specs) != TYPE_ARRAY:
		push_error("InputBindings: action '%s' must map to an array of events" % action_name)
		return
	if InputMap.has_action(action_name):
		InputMap.action_erase_events(action_name)
	else:
		InputMap.add_action(action_name)
	for spec: Variant in event_specs as Array:
		if typeof(spec) != TYPE_DICTIONARY:
			push_error("InputBindings: event spec for '%s' must be an object" % action_name)
			continue
		var event := _build_event(spec as Dictionary)
		if event != null:
			InputMap.action_add_event(action_name, event)


func _build_event(spec: Dictionary) -> InputEvent:
	var event_type: String = spec.get("type", "")
	match event_type:
		"key":
			var key_event := InputEventKey.new()
			var key_name: String = spec.get("keycode", "")
			var keycode := OS.find_keycode_from_string(key_name)
			if keycode == KEY_NONE:
				push_error("InputBindings: unknown keycode '%s'" % key_name)
				return null
			key_event.physical_keycode = keycode
			key_event.ctrl_pressed = bool(spec.get("ctrl", false))
			key_event.shift_pressed = bool(spec.get("shift", false))
			key_event.alt_pressed = bool(spec.get("alt", false))
			return key_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			var button_name: String = spec.get("button", "LEFT")
			mouse_event.button_index = _mouse_button_from_string(button_name)
			return mouse_event
		_:
			push_error("InputBindings: unknown event type '%s'" % event_type)
			return null


func _mouse_button_from_string(button_name: String) -> MouseButton:
	match button_name:
		"LEFT":
			return MOUSE_BUTTON_LEFT
		"RIGHT":
			return MOUSE_BUTTON_RIGHT
		"MIDDLE":
			return MOUSE_BUTTON_MIDDLE
		_:
			push_error("InputBindings: unknown mouse button '%s'" % button_name)
			return MOUSE_BUTTON_NONE
