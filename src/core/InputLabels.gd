class_name InputLabels
extends RefCounted
## Key text for the UI. Everything reads the live InputMap (and data/slot_types.json) on every call and
## caches nothing, so a rebind shows up the next time a label is built. Listen to
## InputBindings.bindings_changed to know when to rebuild.
##
## Also holds the pure binding validator (find_conflicts), run by InputBindings at startup.

const UNBOUND := "?"


## Display text for the first binding of an action: "Q", "Shift+Q", "LMB". "?" when unbound or unknown.
static func for_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return UNBOUND
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return UNBOUND
	return for_event(events[0])


static func for_event(event: InputEvent) -> String:
	var key_event := event as InputEventKey
	if key_event != null:
		var key_name := _key_name(key_event)
		if key_name == "":
			return UNBOUND
		var prefix := ""
		if key_event.ctrl_pressed:
			prefix += "Ctrl+"
		if key_event.alt_pressed:
			prefix += "Alt+"
		if key_event.shift_pressed:
			prefix += "Shift+"
		return prefix + key_name
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		return mouse_name(mouse_event.button_index)
	return UNBOUND


static func mouse_name(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_NONE:
			return UNBOUND
		_:
			return "Mouse %d" % int(button)


## Physical keys are shown as the user's layout names them; headless (no keyboard) shows the physical key.
static func _key_name(key_event: InputEventKey) -> String:
	var code: Key = KEY_NONE
	if key_event.physical_keycode != KEY_NONE:
		code = key_event.physical_keycode
		if DisplayServer.get_name() != "headless":
			var layout_code: Key = DisplayServer.keyboard_get_keycode_from_physical(code)
			if layout_code != KEY_NONE:
				code = layout_code
	elif key_event.keycode != KEY_NONE:
		code = key_event.keycode
	if code == KEY_NONE:
		return ""
	return OS.get_keycode_string(code)


# --- Slots -------------------------------------------------------------------------------------------------

## The InputMap action of a slot type ("slot_1".."slot_5"), from data/slot_types.json. &"" if unknown.
static func slot_action(slot_type: String) -> StringName:
	if not SlotTypeDatabase.has(slot_type):
		return &""
	return StringName(String(SlotTypeDatabase.get_definition(slot_type).get("input_action", "")))


## Slot display name from data/slot_types.json ("Recovery"). Falls back to the id for an unknown slot.
static func slot_name(slot_type: String) -> String:
	if not SlotTypeDatabase.has(slot_type):
		return slot_type
	return String(SlotTypeDatabase.get_definition(slot_type).get("display_name", slot_type))


## Key text of a slot type ("R"). "?" when the slot or its binding is missing.
static func slot_key(slot_type: String) -> String:
	var action := slot_action(slot_type)
	if action == &"":
		return UNBOUND
	return for_action(action)


## The slot's dead-card swap key text ("Shift+R"), from the slot's number in the action name
## (slot_5 -> dead_card_swap_5). "?" when missing.
static func slot_swap_key(slot_type: String) -> String:
	var action := String(slot_action(slot_type))
	if not action.begins_with("slot_"):
		return UNBOUND
	return for_action(StringName("dead_card_swap_" + action.trim_prefix("slot_")))


## "Recovery (R)".
static func slot_label(slot_type: String) -> String:
	return "%s (%s)" % [slot_name(slot_type), slot_key(slot_type)]


## Same four, by slot index (0..4, the HUD order = CardSlotController.SLOT_TYPE_ORDER).
static func slot_name_at(index: int) -> String:
	return slot_name(CardSlotController.slot_type_at_index(index))


static func slot_key_at(index: int) -> String:
	return slot_key(CardSlotController.slot_type_at_index(index))


static func slot_swap_key_at(index: int) -> String:
	return slot_swap_key(CardSlotController.slot_type_at_index(index))


static func slot_label_at(index: int) -> String:
	return slot_label(CardSlotController.slot_type_at_index(index))


# --- Validator ---------------------------------------------------------------------------------------------

## Pure. `bindings` is the parsed data/input_bindings.json. Returns one message per pair of actions that share
## the exact same key plus modifiers, or the same mouse button. Plain R and Shift+R are not a conflict.
static func find_conflicts(bindings: Dictionary) -> Array[String]:
	var conflicts: Array[String] = []
	var owners: Dictionary = {}  # signature -> first action that used it
	var action_names: Array = bindings.keys()
	action_names.sort()
	for action_name: String in action_names:
		var specs: Variant = bindings[action_name]
		if typeof(specs) != TYPE_ARRAY:
			continue
		for spec: Variant in specs as Array:
			if typeof(spec) != TYPE_DICTIONARY:
				continue
			var signature := _signature(spec as Dictionary)
			if signature == "":
				continue
			if owners.has(signature) and owners[signature] != action_name:
				conflicts.append("'%s' and '%s' are both bound to %s" % [owners[signature], action_name, signature_text(signature)])
			elif not owners.has(signature):
				owners[signature] = action_name
	return conflicts


## Pure. The "no binding" rule (H2): an action may map to an empty list, meaning it has no key (the dodge while it is
## switched off). That is never a conflict and never an error by itself. The only action that must have a key when its feature is
## on is "dodge" with dodge.enabled = true: returns one message for that case, else nothing. A missing "dodge" entry counts as unbound.
static func find_missing_required(bindings: Dictionary, dodge_enabled: bool) -> Array[String]:
	var problems: Array[String] = []
	if not dodge_enabled:
		return problems
	var specs: Variant = bindings.get("dodge")
	var has_key: bool = false
	if typeof(specs) == TYPE_ARRAY:
		for spec: Variant in specs as Array:
			if typeof(spec) == TYPE_DICTIONARY and _signature(spec as Dictionary) != "":
				has_key = true
	if not has_key:
		problems.append("dodge.enabled is true in data/player.json but the 'dodge' action has no key in data/input_bindings.json")
	return problems


static func signature_text(signature: String) -> String:
	return signature.get_slice(":", 1) if signature.begins_with("mouse:") else signature.get_slice(":", 1).replace("|", "+")


static func _signature(spec: Dictionary) -> String:
	match String(spec.get("type", "")):
		"key":
			var code := OS.find_keycode_from_string(String(spec.get("keycode", "")))
			if code == KEY_NONE:
				return ""
			var text := ""
			if bool(spec.get("ctrl", false)):
				text += "Ctrl|"
			if bool(spec.get("alt", false)):
				text += "Alt|"
			if bool(spec.get("shift", false)):
				text += "Shift|"
			return "key:" + text + OS.get_keycode_string(code)
		"mouse_button":
			return "mouse:" + String(spec.get("button", "LEFT"))
	return ""
