class_name DodgeSwitch
extends RefCounted
## Test helper for the H2 dodge-off trial. The shipped data has dodge.enabled = false and no key on the "dodge" action. Suites that
## cover the dodge call enable() in before_test (the switch on, and a test-only key, F9, on the dodge action so a real key event can
## drive it) and reset() in after_test.

const TEST_KEY: Key = KEY_F9

static var _saved_events: Array[InputEvent] = []
static var _saved: bool = false


static func enable() -> void:
	PlayerConfig.set_dodge_enabled(true)
	if not _saved:
		_saved_events = InputMap.action_get_events(&"dodge")
		_saved = true
	var event := InputEventKey.new()
	event.physical_keycode = TEST_KEY
	InputMap.action_erase_events(&"dodge")
	InputMap.action_add_event(&"dodge", event)


static func reset() -> void:
	PlayerConfig.reload()
	# PL3 carry-over: a suite that pressed the dodge (a test-only key, a TestInput event or an Input.action_press) and ended before its
	# release left the action held for the rest of the run, so a later Input.is_action_just_pressed("dodge") was never true. Every dodge
	# suite resets here in after_test, so releasing the action here is the one teardown that covers them all.
	Input.action_release(&"dodge")
	if _saved:
		InputMap.action_erase_events(&"dodge")
		for event: InputEvent in _saved_events:
			InputMap.action_add_event(&"dodge", event)
		_saved = false
