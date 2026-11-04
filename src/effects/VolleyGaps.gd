class_name VolleyGaps
extends RefCounted
## Look only: where the gaps between the lanes of a fan are wide enough to stand in. The drawn lanes are already the
## true hit area against the player's body (VfxSizing.lateral_reach_vs_player), so a point between two lanes is safe.
## Two lanes whose directions differ by `delta` are `r * sin(delta / 2)` from the bisector at distance r from the boss,
## so the clear half width there is `r * sin(delta / 2) - lane_half_width`. A gap is drawn only from the distance where
## that reaches `min_half_width` (data/vfx.json "boss_volley_gap_min_half_width"), in short segments each as wide as
## the clear width at its near end (never wider than the real gap). Up close there is none: only the dodge helps there.


## The gap segments for a fan: [{angle, start, length, half_width}] with `angle` the bisector in degrees from the aim,
## `start` metres from the boss. Empty for fewer than two lanes, or when no gap reaches the minimum inside `max_length`.
static func segments(angles: Array[float], lane_half_width: float, min_half_width: float, segment_length: float, max_length: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if angles.size() < 2 or segment_length <= 0.0 or lane_half_width < 0.0:
		return out
	for i in range(angles.size() - 1):
		var delta: float = deg_to_rad(absf(angles[i + 1] - angles[i]))
		var sine: float = sin(delta * 0.5)
		if sine <= 0.0001:
			continue
		var first: float = (lane_half_width + maxf(min_half_width, 0.0)) / sine
		var at: float = first
		while at < max_length:
			var length: float = minf(segment_length, max_length - at)
			out.append({"angle": (angles[i] + angles[i + 1]) * 0.5, "start": at, "length": length, "half_width": at * sine - lane_half_width})
			at += segment_length
	return out


## The distance from the boss at which the gaps first open to `min_half_width`, or INF with no gap (a single lane).
static func first_safe_distance(angles: Array[float], lane_half_width: float, min_half_width: float) -> float:
	if angles.size() < 2:
		return INF
	var delta: float = deg_to_rad(absf(angles[1] - angles[0]))
	var sine: float = sin(delta * 0.5)
	return INF if sine <= 0.0001 else (lane_half_width + maxf(min_half_width, 0.0)) / sine
