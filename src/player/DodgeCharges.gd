class_name DodgeCharges
extends RefCounted
## The dodge's charge pool (GDD section 3): `current` charges out of a `maximum` that the caller passes in each time
## (it changes with modifiers, so it is not stored). Each dodge spends one; while below the maximum one charge
## comes back every `cooldown` seconds, one at a time. Pure logic with no node or scene, so tests and the HUD use it
## directly. The Player owns one and exposes the state (see Player.get_dodge_state).

var cooldown: float
var current: int
var _recharge_left: float = 0.0


func _init(p_cooldown: float, start_charges: int) -> void:
	cooldown = maxf(p_cooldown, 0.0)
	current = maxi(start_charges, 0)


## The effective maximum: the base count through the modifier stack, rounded, then clamped to the hard limits.
static func effective_max(base: int, stat_modifiers: StatModifiers, stat_name: String, min_charges: int, max_charges: int) -> int:
	var raw: float = float(base)
	if stat_modifiers != null:
		raw = stat_modifiers.apply(stat_name, raw)
	return clampi(roundi(raw), min_charges, max_charges)


## Brings `current` down to a lowered maximum. Returns true when it changed.
func sync(maximum: int) -> bool:
	if current > maximum:
		current = maxi(maximum, 0)
		_recharge_left = 0.0
		return true
	return false


## Fills the pool (a new room, Try again).
func reset(maximum: int) -> void:
	current = maxi(maximum, 0)
	_recharge_left = 0.0


## Ticks the recharge. Returns true when `current` changed (a charge came back or the maximum fell).
func advance(delta: float, maximum: int) -> bool:
	var changed: bool = sync(maximum)
	if current >= maximum:
		_recharge_left = 0.0
		return changed
	if _recharge_left <= 0.0:
		_recharge_left = cooldown  # the maximum rose above current (or a spend left the pool below it)
	_recharge_left -= delta
	while _recharge_left <= 0.0 and current < maximum:
		current += 1
		changed = true
		_recharge_left = _recharge_left + cooldown if current < maximum else 0.0
	return changed


## Spends one charge. False (nothing changes) when none is left. The recharge starts now if it was not running.
func try_spend(maximum: int) -> bool:
	sync(maximum)
	if current <= 0:
		return false
	current -= 1
	if _recharge_left <= 0.0:
		_recharge_left = cooldown
	return true


func is_recharging(maximum: int) -> bool:
	return current < maximum


## Seconds until the next charge (0 when full).
func recharge_remaining(maximum: int) -> float:
	return maxf(_recharge_left, 0.0) if current < maximum else 0.0


## 0..1 fill of the recharging pip; 1.0 when the pool is full.
func recharge_progress(maximum: int) -> float:
	if current >= maximum:
		return 1.0
	if cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - _recharge_left / cooldown, 0.0, 1.0)
