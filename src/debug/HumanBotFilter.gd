class_name HumanBotFilter
extends RefCounted
## SIM1: sits between the sim bot's decisions and the game. Everything the bot decides (aim, move, button presses) is queued with the
## time it was decided and handed out once `reaction_delay` has passed; the aim gets a random angular error, and card presses an extra
## random hesitation. All randomness comes from the seed given to `reset`, so a seed repeats exactly. Pure logic, no scene.

var settings: BotSettings = BotSettings.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _aims: Array[Dictionary] = []
var _moves: Array[Dictionary] = []
var _presses: Array[Dictionary] = []
var _aim_target: Variant = null
var _error_radians: float = 0.0
var _next_resample: float = 0.0


func reset(new_settings: BotSettings, seed_value: int) -> void:
	settings = new_settings
	_rng.seed = seed_value
	_aims.clear()
	_moves.clear()
	_presses.clear()
	_aim_target = null
	_error_radians = 0.0
	_next_resample = 0.0


func push_aim(now: float, target: Vector3) -> void:
	_aims.append({"due": now + settings.reaction_delay, "value": target})


func push_move(now: float, direction: Vector3) -> void:
	_moves.append({"due": now + settings.reaction_delay, "value": direction})


func push_press(now: float, action: StringName, is_card: bool) -> void:
	var due: float = now + settings.reaction_delay
	if is_card and settings.cast_hesitation > 0.0:
		due += _rng.randf() * settings.cast_hesitation
	_presses.append({"due": due, "value": action})


## What is due at `now`: {"aim": Vector3 or null (the aim point to use now, error applied, from the player at `me`),
## "move": Vector3 or null (the latest due move direction), "presses": Array[StringName] (in the order they fell due)}.
func due(now: float, me: Vector3) -> Dictionary:
	var latest_move: Variant = null
	while not _moves.is_empty() and float(_moves[0]["due"]) <= now:
		latest_move = _moves[0]["value"]
		_moves.remove_at(0)
	while not _aims.is_empty() and float(_aims[0]["due"]) <= now:
		_aim_target = _aims[0]["value"]
		_aims.remove_at(0)
	var kept: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for press: Dictionary in _presses:
		if float(press["due"]) <= now:
			ready.append(press)
		else:
			kept.append(press)
	_presses = kept
	ready.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["due"]) < float(b["due"]))
	var presses: Array[StringName] = []
	for press: Dictionary in ready:
		presses.append(press["value"] as StringName)
	var aim: Variant = null
	if _aim_target != null:
		aim = _apply_error(_aim_target as Vector3, me, now)
	return {"aim": aim, "move": latest_move, "presses": presses}


func _apply_error(target: Vector3, me: Vector3, now: float) -> Vector3:
	if settings.aim_error_degrees <= 0.0:
		return target
	if now >= _next_resample:
		_error_radians = deg_to_rad(_rng.randf_range(-settings.aim_error_degrees, settings.aim_error_degrees))
		_next_resample = now + settings.aim_resample
	var offset: Vector3 = target - me
	var flat: Vector3 = Vector3(offset.x, 0.0, offset.z).rotated(Vector3.UP, _error_radians)
	return me + flat + Vector3(0.0, offset.y, 0.0)
