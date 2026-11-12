class_name BossRules
extends RefCounted
## Pure rules of the boss fight (Milestone 3c), over the plain dictionaries of data/bosses.json: which phase an HP
## fraction is in, which attacks a phase may pick and how, how big each telegraph is (all sizes come from VfxSizing, the
## same numbers the hit queries use), and the fairness check that every attack can be escaped by walking or by the dodge.
## No scene needed, so tests and the sim can call it directly.

## HP fractions compare with this slack, so a threshold reached exactly counts as reached.
const EPSILON := 0.0001
## A shot leaves this far in front of the caster (EffectTemplates.PROJECTILE_MUZZLE_OFFSET).
const MUZZLE := 0.6


## The HP fractions at which the next phase begins (phases 2..N), descending.
static func thresholds(phases: Array) -> Array[float]:
	var out: Array[float] = []
	for index in range(1, phases.size()):
		out.append(float((phases[index] as Dictionary)["enters_at"]))
	return out


## The phase (0-based) an HP fraction belongs to: the last phase whose threshold has been reached.
static func phase_for_fraction(phases: Array, fraction: float) -> int:
	var result: int = 0
	for index in range(phases.size()):
		if fraction <= float((phases[index] as Dictionary)["enters_at"]) + EPSILON:
			result = index
	return result


## HP (absolute) the boss may not drop below until the transition into phase `next_index` has run. 0 for the last phase.
static func floor_hp(phases: Array, next_index: int, max_health: float) -> float:
	if next_index >= phases.size():
		return 0.0
	return float((phases[next_index] as Dictionary)["enters_at"]) * max_health


## The phase's weighted attack entries whose distance window contains `distance`, as [{id, weight}].
static func eligible(phase: Dictionary, attacks: Dictionary, distance: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in (phase["attacks"] as Array):
		var e: Dictionary = entry
		var attack: Dictionary = attacks[String(e["id"])]
		if float(e["weight"]) > 0.0 and distance >= float(attack["min_range"]) and distance <= float(attack["max_range"]):
			out.append({"id": String(e["id"]), "weight": float(e["weight"])})
	return out


## A weighted pick from `entries` ([{id, weight}]) using `rng`; "" when there are none. One rng draw per call.
static func pick(entries: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	if entries.is_empty():
		return ""
	var total: float = 0.0
	for e: Dictionary in entries:
		total += float(e["weight"])
	var roll: float = rng.randf() * total
	for e: Dictionary in entries:
		roll -= float(e["weight"])
		if roll < 0.0:
			return String(e["id"])
	return String((entries[entries.size() - 1] as Dictionary)["id"])


## Seconds of wind-up (the telegraph) of an attack in a phase.
static func windup(attack: Dictionary, phase: Dictionary) -> float:
	return float(attack["windup"]) * float(phase.get("windup_scale", 1.0))


## The yaw offsets (degrees) of a volley's shots: evenly across the spread, centred on the aim.
static func volley_angles(count: int, spread_degrees: float) -> Array[float]:
	var out: Array[float] = []
	if count <= 1:
		out.append(0.0)
		return out
	for index in range(count):
		out.append(-spread_degrees * 0.5 + spread_degrees * float(index) / float(count - 1))
	return out


# ---- Telegraph sizes (what is drawn == what hits the player) ----

## Cone: how far the wedge is drawn, and so how far the hit reaches the player's capsule.
static func cone_reach(attack: Dictionary) -> float:
	return VfxSizing.lateral_reach_vs_player(float(attack["range"]))


## Ground disc: the radius drawn.
static func aoe_reach(attack: Dictionary) -> float:
	return VfxSizing.lateral_reach_vs_player(float(attack["radius"]))


## MB1: where the discs of one aoe cast land. The first sits on `first` (the player's spot when the wind-up starts); each of the
## other `count - 1` sits within `scatter` metres of it, at least a third of that away so the discs spread out, inside +-`limit`
## on both ground axes. A count of 1 returns just `first` and never draws from `rng` (so a single-disc attack keeps its random stream).
static func aoe_centers(first: Vector3, count: int, scatter: float, rng: RandomNumberGenerator, limit: float, min_dist: float = -1.0) -> Array[Vector3]:
	var out: Array[Vector3] = [Vector3(first.x, 0.0, first.z)]
	var near: float = scatter * 0.35 if min_dist < 0.0 else minf(min_dist, scatter)
	for index in range(1, count):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(near, scatter)
		var spot: Vector3 = Vector3.ZERO
		# MAP3b: a wall clamp must not pull a disc back under the player; turn a quarter at a time until one holds the gap.
		for turn in range(4):
			var turned: float = angle + float(turn) * PI * 0.5
			spot = Vector3(clampf(first.x + cos(turned) * dist, -limit, limit), 0.0, clampf(first.z + sin(turned) * dist, -limit, limit))
			if Vector2(spot.x - first.x, spot.z - first.z).length() >= near - 0.0001:
				break
		out.append(spot)
	return out


## MB1: the index of the first disc (radius `reach`) that contains the ground point, or -1. A cast hurts a player once however many discs hold them.
static func disc_containing(centers: Array[Vector3], reach: float, point: Vector3) -> int:
	for index in range(centers.size()):
		if Vector2(point.x - centers[index].x, point.z - centers[index].z).length() <= reach:
			return index
	return -1


## MB1 blink: how close (metres, ground) a landing may be to the player's centre. Over the two body radii (0.55 + 0.4) with a margin, so the
## boss never lands on top of the player.
const BLINK_MIN_GAP := 1.2
## The landing marker's radius is the boss's body plus this much, so the marker is bigger than the boss that will stand in it.
const BLINK_MARKER_EXTRA := 0.45


## MB1 blink: where the boss lands. `behind` metres past the player along the boss-to-player line, held inside +-`limit` on both ground axes;
## when the arena edge (or the clamp) leaves that closer to the player than BLINK_MIN_GAP, it moves to the boss's side of the player instead
## (the same distance, toward the boss), so it is never inside a wall nor on top of the player. Ground coordinates; y is 0.
static func blink_landing(boss_pos: Vector3, player_pos: Vector3, behind: float, limit: float, min_gap: float = BLINK_MIN_GAP) -> Vector3:
	var player_flat := Vector3(player_pos.x, 0.0, player_pos.z)
	var out_dir := Vector3(player_pos.x - boss_pos.x, 0.0, player_pos.z - boss_pos.z)
	out_dir = out_dir.normalized() if out_dir.length() > 0.001 else Vector3(0.0, 0.0, 1.0)
	var spot: Vector3 = _clamp_ground(player_flat + out_dir * behind, limit)
	if _ground_distance(spot, player_flat) >= min_gap:
		return spot
	spot = _clamp_ground(player_flat - out_dir * maxf(behind, min_gap), limit)
	if _ground_distance(spot, player_flat) >= min_gap:
		return spot
	# Cornered both ways (the player is in a corner of a tiny arena): any direction that holds the gap and the arena.
	for step_index in range(16):
		var angle: float = TAU * float(step_index) / 16.0
		var candidate: Vector3 = _clamp_ground(player_flat + Vector3(cos(angle), 0.0, sin(angle)) * min_gap, limit)
		if _ground_distance(candidate, player_flat) >= min_gap - 0.0001:
			return candidate
	return spot


static func _clamp_ground(point: Vector3, limit: float) -> Vector3:
	return Vector3(clampf(point.x, -limit, limit), 0.0, clampf(point.z, -limit, limit))


static func _ground_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## MB1 blink: radius of the landing marker for a boss body of `body_radius`.
static func blink_marker_radius(body_radius: float) -> float:
	return body_radius + BLINK_MARKER_EXTRA


## Volley: half width of each shot's lane.
static func volley_half_width(attack: Dictionary) -> float:
	return VfxSizing.lateral_reach_vs_player(float(attack["hit_radius"]))


## Charge: half width of the lane the boss sweeps, and its drawn length.
static func charge_half_width(attack: Dictionary) -> float:
	return VfxSizing.charge_lane_half_width(float(attack["hit_radius"]))


static func charge_length(attack: Dictionary) -> float:
	return VfxSizing.charge_lane_length(float(attack["distance"]), float(attack["hit_radius"]))


# ---- Fairness ----

## Can a player at the worst spot inside the attack's area leave it before it lands?
## Returns {kind, required (m to leave, worst case), time (s before it lands), walk_ok, dodge_ok, ok}.
## A walker covers walk_speed x time. The dodge covers dodge_distance in one go but needs its cooldown, so an attack
## that needs the dodge (walk_ok false) is fair only when the gap between attack starts is at least the dodge cooldown;
## `fair` also folds that in (pass the smallest windup + recover + gap the boss can have).
static func escape(attack: Dictionary, windup_seconds: float, walk_speed: float, dodge_distance: float, min_gap_between_starts: float, dodge_cooldown: float) -> Dictionary:
	var required: float = 0.0
	var time: float = windup_seconds
	var walk_ok: bool = true
	match String(attack["kind"]):
		"cone":
			required = cone_reach(attack)
		"aoe":
			# MB1: a multi-disc cast can chain discs, so the worst spot is a disc radius plus the scatter from the clear ground.
			required = aoe_reach(attack) + (BossConfig.aoe_scatter(attack) if BossConfig.aoe_count(attack) > 1 else 0.0)
		"charge":
			required = charge_half_width(attack)
		"blink":
			required = 0.0  # MB1: a blink never hurts, so there is nothing to leave (the backstab it chains into is checked as its own cone)
		"volley":
			# Leaving the fan sideways. The lateral distance to clear grows with range; so does the time a shot takes to get there.
			var half_spread: float = deg_to_rad(float(attack["spread_degrees"]) * 0.5)
			var half_width: float = volley_half_width(attack)
			var speed: float = float(attack["speed"])
			for r: float in [MUZZLE, float(attack["shot_range"])]:
				var need: float = r * tan(half_spread) + half_width
				var have_time: float = windup_seconds + (r - MUZZLE) / speed
				if need > walk_speed * have_time:
					walk_ok = false
				required = maxf(required, need)
	if String(attack["kind"]) != "volley":
		walk_ok = required <= walk_speed * time
	var dodge_ok: bool = required <= dodge_distance and min_gap_between_starts >= dodge_cooldown
	return {"kind": String(attack["kind"]), "required": required, "time": time, "walk_ok": walk_ok, "dodge_ok": dodge_ok, "ok": walk_ok or dodge_ok}
