class_name ScriptedInput
extends Node
## Capture tooling (--press=<t>:<action>[:<hold>]): sends real input actions at scripted times after launch, through the same
## event path a key press takes, so a capture can show a state a player causes (for example the empty dodge pip) and the
## playtester can play a fight: hold move_forward / move_left ... for N seconds (steps at the same time make a diagonal), keep the
## aim on the nearest live enemy (`<t>:aim_nearest`, until `<t>:aim_off`), and tap attack_light, attack_heavy, slot_1..slot_5, dodge.
## Added by Main only when --press is given. A debug flag (RunSave.DEBUG_FLAG_PREFIXES): it never touches the save, profile or loadouts.

## How long a scripted tap holds the action before releasing it.
const TAP_SECONDS := 0.1

## {at: float, action: StringName, hold: float}, in any order. hold 0 = a tap.
var presses: Array[Dictionary] = []
## The player the aim steps steer (set by Main). Null: aim steps do nothing.
var player: Player = null

var _elapsed: float = 0.0
var _next: int = 0
## {at: float, action: StringName} releases still to send.
var _releases: Array[Dictionary] = []
var _aiming: bool = false


func _ready() -> void:
	presses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))


## A scene swap (or quit) must not leave a scripted hold stuck down: release every pending hold.
func _exit_tree() -> void:
	for release: Dictionary in _releases:
		_send(release["action"], false)
	_releases.clear()


func _process(delta: float) -> void:
	_elapsed += delta
	while _next < presses.size() and _elapsed >= float(presses[_next]["at"]):
		_run_step(presses[_next])
		_next += 1
	var pending: Array[Dictionary] = []
	for release: Dictionary in _releases:
		if _elapsed >= float(release["at"]):
			_send(release["action"], false)
		else:
			pending.append(release)
	_releases = pending
	if _aiming:
		_aim_at_nearest()


func _run_step(step: Dictionary) -> void:
	var action: StringName = step["action"]
	if action == &"aim_nearest":
		_aiming = true
		print("ScriptedInput: t=%.2f aim_nearest" % _elapsed)
		return
	if action == &"aim_off":
		_aiming = false
		if player != null:
			player.aim_point_override = null
		print("ScriptedInput: t=%.2f aim_off" % _elapsed)
		return
	var hold: float = float(step.get("hold", 0.0))
	_send(action, true)
	print("ScriptedInput: t=%.2f press %s%s%s" % [_elapsed, action, (" hold %.2f" % hold) if hold > 0.0 else "", _player_note()])
	_releases.append({"at": _elapsed + (hold if hold > 0.0 else TAP_SECONDS), "action": action})


## " player=(x, z)" for the console log, so a run of the script shows where the player was; "" without a player.
func _player_note() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	return " player=(%.1f, %.1f)" % [player.global_position.x, player.global_position.z]


## Points the player's aim override at the nearest live enemy (kept at its last value when none is left).
func _aim_at_nearest() -> void:
	if player == null or not is_instance_valid(player) or player.get_parent() == null:
		return
	var points: Array[Vector3] = []
	for node: Node in player.get_parent().get_children():
		if node is Enemy and is_instance_valid(node) and (node as Enemy).health != null and not (node as Enemy).health.is_dead():
			points.append((node as Enemy).global_position)
	var target: Variant = nearest_point(player.global_position, points)
	if target != null:
		player.aim_point_override = target


## The point of `points` closest to `origin` on the ground plane (y ignored), or null when there are none. Pure.
static func nearest_point(origin: Vector3, points: Array[Vector3]) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	for point: Vector3 in points:
		var flat := Vector2(point.x - origin.x, point.z - origin.z)
		var distance: float = flat.length_squared()
		if distance < best_distance:
			best_distance = distance
			best = point
	return best


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
