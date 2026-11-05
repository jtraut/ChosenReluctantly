class_name SlotCues
extends RefCounted
## Pure math for the BD1 slot cues (no scene): the live-condition glow's easing and the primed marker's numbers.
## The glow must never flicker: a target condition can flip every frame as enemies cross the area's edge, so the
## level rises fast, is held for `hold` seconds after the condition drops, then fades over `release` seconds.


## One step of the glow. `state` is {level: 0..1, hold_left: seconds}. Returns the new state.
static func glow_step(state: Dictionary, live: bool, delta: float, attack: float, hold: float, release: float) -> Dictionary:
	var level: float = float(state.get("level", 0.0))
	var hold_left: float = float(state.get("hold_left", 0.0))
	if live:
		hold_left = hold
		level = 1.0 if attack <= 0.0 else minf(level + delta / attack, 1.0)
	elif hold_left > 0.0:
		hold_left = maxf(hold_left - delta, 0.0)
	else:
		level = 0.0 if release <= 0.0 else maxf(level - delta / release, 0.0)
	return {"level": level, "hold_left": hold_left}


## How much of the primed window is left, 0..1, for the drain bar. No time limit (-1) or no known duration is a full bar.
static func primed_fraction(time_left: float, duration: float) -> float:
	if time_left < 0.0 or duration <= 0.0:
		return 1.0
	return clampf(time_left / duration, 0.0, 1.0)


## One step of the "prime ended" mark (BD2 ux): when a slot goes from primed to not primed, `level` jumps to 1 and fades over `duration`.
## `used` says how it ended: true when a good part of the window was left (the player spent it), false when it ran out. `state` is
## {level: 0..1, used: bool}; `last_fraction` is the drain-bar fraction the frame before. A new prime clears the mark.
static func spent_step(state: Dictionary, was_primed: bool, is_primed: bool, last_fraction: float, delta: float, duration: float, expired_below: float) -> Dictionary:
	var level: float = float(state.get("level", 0.0))
	var used: bool = bool(state.get("used", true))
	if is_primed:
		return {"level": 0.0, "used": true}
	if was_primed:
		return {"level": 1.0, "used": last_fraction > expired_below}
	level = 0.0 if duration <= 0.0 else maxf(level - delta / duration, 0.0)
	return {"level": level, "used": used}


## The word on the ended mark ("USED" or "GONE"), from the two words.
static func spent_word(used: bool, used_word: String, expired_word: String) -> String:
	return used_word if used else expired_word


## "x2" when more than one charge is stored, else "" (one charge is the normal case and needs no number).
static func charges_text(charges: int) -> String:
	return "x%d" % charges if charges > 1 else ""
