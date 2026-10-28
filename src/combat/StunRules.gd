class_name StunRules
extends RefCounted
## Pure stun math (no scene, no clock of its own): turns "a stun of base length X
## lands now on a target of this rank" into the real duration, using the status
## definition in data/statuses.json.
##
## - Rank: duration x rank_multipliers[rank]; a multiplier of 0 means immune (bosses).
## - Diminishing returns: every stun that took effect within the last `window`
##   seconds (sliding, measured from each stun's own start) counts as a repeat, and
##   each repeat multiplies the duration by `multiplier`. Once `immune_after` stuns
##   are inside the window the target is immune until the oldest one ages out.
## - An immune result is a true no-op: it is not recorded, so it never extends the
##   immunity.
## With the defaults (0.6 s, x0.5, window 1.5 s, immune after 3) a normal enemy gets
## 0.6, 0.3, 0.15, then immune.

var _times: Array[float] = []


## Real duration for a stun landing at time `now`, or 0.0 if the target is immune.
## When the result is above 0 the stun is recorded as a repeat for later calls.
func resolve(now: float, base_duration: float, rank: String, status_def: Dictionary) -> float:
	var duration: float = preview(now, base_duration, rank, status_def)
	if duration > 0.0:
		_times.append(now)
	return duration


## Same math as resolve() but records nothing.
func preview(now: float, base_duration: float, rank: String, status_def: Dictionary) -> float:
	var rank_multipliers: Dictionary = status_def.get("rank_multipliers", {})
	var rank_multiplier: float = float(rank_multipliers.get(rank, 1.0))
	if rank_multiplier <= 0.0 or base_duration <= 0.0:
		return 0.0
	var dr: Dictionary = status_def.get("diminishing_returns", {})
	var window: float = float(dr.get("window", 0.0))
	var repeats: int = _count_in_window(now, window)
	if repeats >= int(dr.get("immune_after", 1000000)):
		return 0.0
	return base_duration * rank_multiplier * pow(float(dr.get("multiplier", 1.0)), float(repeats))


func _count_in_window(now: float, window: float) -> int:
	var kept: Array[float] = []
	for time: float in _times:
		if now - time < window:
			kept.append(time)
	_times = kept
	return kept.size()


func clear() -> void:
	_times.clear()
