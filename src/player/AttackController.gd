class_name AttackController
extends RefCounted
## Timing logic for the player's data-driven attacks (light/heavy). Pure: no
## scene access. The owner supplies input presses and a target-query Callable
## each tick and reacts to signals; this class only decides when to swing.
##
## Rules:
## - Each attack has a cooldown ("interval") resolved through StatModifiers.
## - Auto attacks start when ready AND has_target(id) is true (never whiff).
## - A manual press starts an attack when ready, or (manual_min_gap >= 0)
##   whenever at least that long since the last start; it restarts the timer.
##   Manual is processed before auto, so a same-tick press + auto fires once.
## - While any attack is winding up, no other attack may start.
## - can_act false cancels any wind-up and blocks everything.

## Wind-up (or instant swing) begins. Fires for every attack.
signal attack_started(attack_id: StringName)
## Damage moment: instantly if wind_up is 0, else when the wind-up ends.
signal attack_fired(attack_id: StringName)
## Cooldown finished; the attack can start again.
signal attack_ready(attack_id: StringName)
## Wind-up aborted (death).
signal attack_cancelled(attack_id: StringName)

const MIN_INTERVAL := 0.05
const NEVER := 1000000.0


class State:
	var def: Dictionary = {}
	var remaining: float = 0.0
	var since_start: float = NEVER
	var windup_left: float = -1.0


var _states: Dictionary = {}
var _order: Array[StringName] = []
var _modifiers: StatModifiers


func _init(defs: Dictionary, modifiers: StatModifiers) -> void:
	_modifiers = modifiers
	for attack_id: StringName in defs.keys():
		var state := State.new()
		state.def = defs[attack_id]
		_states[attack_id] = state
		_order.append(attack_id)


func ids() -> Array[StringName]:
	return _order


func has_attack(attack_id: StringName) -> bool:
	return _states.has(attack_id)


## Turns automatic firing on or off for one attack (capture scenarios). Works on a
## private copy of the def, because the data table's dictionaries are cached and
## shared by everything in the process.
func set_auto(attack_id: StringName, enabled: bool) -> void:
	if not _states.has(attack_id):
		return
	var state: State = _states[attack_id]
	state.def = state.def.duplicate()
	state.def["auto"] = enabled


func get_def(attack_id: StringName) -> Dictionary:
	if not _states.has(attack_id):
		return {}
	return (_states[attack_id] as State).def


## Effective cooldown in seconds after StatModifiers (floored at MIN_INTERVAL).
func get_interval(attack_id: StringName) -> float:
	if not _states.has(attack_id):
		return 0.0
	var def: Dictionary = (_states[attack_id] as State).def
	return maxf(_modifiers.apply(String(def["stat"]), float(def["interval"])), MIN_INTERVAL)


## 0..1 fraction of the cooldown elapsed; 1.0 means ready.
func get_progress(attack_id: StringName) -> float:
	if not _states.has(attack_id):
		return 0.0
	var state: State = _states[attack_id]
	return clampf(1.0 - state.remaining / get_interval(attack_id), 0.0, 1.0)


func is_ready(attack_id: StringName) -> bool:
	return _states.has(attack_id) and (_states[attack_id] as State).remaining <= 0.0


func is_winding_up(attack_id: StringName) -> bool:
	return _states.has(attack_id) and (_states[attack_id] as State).windup_left >= 0.0


## 0..1 progress through the current wind-up (0 when not winding up).
func get_windup_progress(attack_id: StringName) -> float:
	if not is_winding_up(attack_id):
		return 0.0
	var state: State = _states[attack_id]
	var wind_up: float = float(state.def["wind_up"])
	if wind_up <= 0.0:
		return 1.0
	return clampf(1.0 - state.windup_left / wind_up, 0.0, 1.0)


func is_busy() -> bool:
	for attack_id: StringName in _order:
		if is_winding_up(attack_id):
			return true
	return false


## `manual`: attack id -> pressed this tick. `has_target`: Callable(id) -> bool.
func tick(delta: float, can_act: bool, manual: Dictionary, has_target: Callable) -> void:
	if not can_act:
		cancel_all()
		return
	for attack_id: StringName in _order:
		_advance(attack_id, delta)
	for attack_id: StringName in _order:
		if bool(manual.get(attack_id, false)) and _can_start_manual(attack_id):
			_start(attack_id)
	for attack_id: StringName in _order:
		var state: State = _states[attack_id]
		if bool(state.def["auto"]) and state.remaining <= 0.0 and not is_busy() and bool(has_target.call(attack_id)):
			_start(attack_id)


func cancel_all() -> void:
	for attack_id: StringName in _order:
		var state: State = _states[attack_id]
		if state.windup_left >= 0.0:
			state.windup_left = -1.0
			attack_cancelled.emit(attack_id)


func _advance(attack_id: StringName, delta: float) -> void:
	var state: State = _states[attack_id]
	state.since_start += delta
	if state.remaining > 0.0:
		state.remaining = maxf(state.remaining - delta, 0.0)
		if state.remaining <= 0.0:
			attack_ready.emit(attack_id)
	if state.windup_left >= 0.0:
		state.windup_left -= delta
		if state.windup_left <= 0.0:
			state.windup_left = -1.0
			attack_fired.emit(attack_id)


func _can_start_manual(attack_id: StringName) -> bool:
	if is_busy():
		return false
	var state: State = _states[attack_id]
	if state.remaining <= 0.0:
		return true
	var gap: float = float(state.def["manual_min_gap"])
	return gap >= 0.0 and state.since_start >= gap


func _start(attack_id: StringName) -> void:
	var state: State = _states[attack_id]
	state.remaining = get_interval(attack_id)
	state.since_start = 0.0
	attack_started.emit(attack_id)
	var wind_up: float = float(state.def["wind_up"])
	if wind_up > 0.0:
		state.windup_left = wind_up
	else:
		attack_fired.emit(attack_id)
