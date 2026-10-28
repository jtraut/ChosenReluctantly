class_name TestInput
extends RefCounted
## Test helper: sends a real InputEventAction through Input.parse_input_event so it
## reaches _unhandled_input like a key or click would (Input.action_press sets only
## the polled state and emits no event). Flushed at once so no frame wait is needed.


static func press(action: StringName) -> void:
	_send(action, true)


static func release(action: StringName) -> void:
	_send(action, false)


## Press then release in the same frame (one click or key tap).
static func tap(action: StringName) -> void:
	_send(action, true)
	_send(action, false)


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
