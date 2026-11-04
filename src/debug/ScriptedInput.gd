class_name ScriptedInput
extends Node
## Capture tooling (--press=<t>:<action>): taps real input actions at scripted times after launch, through the same
## event path a key press takes, so a capture can show a state a player causes (for example the empty dodge pip).
## Added by Main only when --press is given.

## How long a scripted tap holds the action before releasing it.
const TAP_SECONDS := 0.1

## {at: float, action: StringName}, in any order.
var presses: Array[Dictionary] = []

var _elapsed: float = 0.0
var _next: int = 0
## {at: float, action: StringName} releases still to send.
var _releases: Array[Dictionary] = []


func _ready() -> void:
	presses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))


func _process(delta: float) -> void:
	_elapsed += delta
	while _next < presses.size() and _elapsed >= float(presses[_next]["at"]):
		var action: StringName = presses[_next]["action"]
		_send(action, true)
		print("ScriptedInput: t=%.2f press %s" % [_elapsed, action])
		_releases.append({"at": _elapsed + TAP_SECONDS, "action": action})
		_next += 1
	var pending: Array[Dictionary] = []
	for release: Dictionary in _releases:
		if _elapsed >= float(release["at"]):
			_send(release["action"], false)
		else:
			pending.append(release)
	_releases = pending


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
