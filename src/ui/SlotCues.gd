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


## "x2" when more than one charge is stored, else "" (one charge is the normal case and needs no number).
static func charges_text(charges: int) -> String:
	return "x%d" % charges if charges > 1 else ""
