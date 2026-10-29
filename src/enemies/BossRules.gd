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
			required = aoe_reach(attack)
		"charge":
			required = charge_half_width(attack)
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
