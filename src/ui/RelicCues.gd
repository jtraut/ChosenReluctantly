class_name RelicCues
extends RefCounted
## Pure rules for the floating relic cue (MAP1 ux, BD2 playtest carry-over: "which relic just fired?"): a ring and the relic's name at the point it
## triggered. With several relics firing at once the labels must stay readable, so one relic firing again soon and near the same spot is merged into
## the existing cue ("Pyre Insurance x3"), the number of cues is capped, and labels that would overlap are stacked upwards.
## A cue: {relic_id, name, world: Vector3, age: float, count: int, color: Color}.


## Folds a trigger into `cues`: merges into a live cue of the same relic within `merge_window` seconds and `merge_radius` metres (count + 1, age back
## to 0, spot kept), else appends a new cue, dropping the oldest beyond `max_cues`. Returns the cue list (the same array).
static func add(cues: Array[Dictionary], relic_id: String, relic_name: String, world: Vector3, color: Color, merge_window: float, merge_radius: float, max_cues: int) -> Array[Dictionary]:
	for cue: Dictionary in cues:
		if String(cue["relic_id"]) == relic_id and float(cue["age"]) <= merge_window and (cue["world"] as Vector3).distance_to(world) <= merge_radius:
			cue["count"] = int(cue["count"]) + 1
			cue["age"] = 0.0
			return cues
	cues.append({"relic_id": relic_id, "name": relic_name, "world": world, "age": 0.0, "count": 1, "color": color})
	while cues.size() > maxi(max_cues, 1):
		cues.remove_at(0)
	return cues


## Ages every cue by `delta` and drops those older than `life`.
static func step(cues: Array[Dictionary], delta: float, life: float) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for cue: Dictionary in cues:
		cue["age"] = float(cue["age"]) + delta
		if float(cue["age"]) < life:
			kept.append(cue)
	return kept


## "Pyre Insurance" or "Pyre Insurance x3".
static func label(cue: Dictionary) -> String:
	var count: int = int(cue["count"])
	return String(cue["name"]) if count <= 1 else "%s x%d" % [String(cue["name"]), count]


## Moves label rectangles up until none overlaps an earlier one (order = priority: the first keeps its place). Returns the shifted rects.
static func stack(rects: Array[Rect2], gap: float) -> Array[Rect2]:
	var placed: Array[Rect2] = []
	for rect: Rect2 in rects:
		var moved: Rect2 = rect
		var changed: bool = true
		var guard: int = 0
		while changed and guard < 32:
			changed = false
			guard += 1
			for other: Rect2 in placed:
				if moved.grow(gap * 0.5).intersects(other.grow(gap * 0.5)):
					moved.position.y = other.position.y - moved.size.y - gap
					changed = true
		placed.append(moved)
	return placed


## Ring radius (0..1 of the full radius, eased out) and alpha at `age`. The ring is quick (`ring_time`), the label lives the whole `life`.
static func ring_state(age: float, ring_time: float) -> Dictionary:
	if ring_time <= 0.0 or age >= ring_time:
		return {"radius": 1.0, "alpha": 0.0}
	var t: float = clampf(age / ring_time, 0.0, 1.0)
	return {"radius": 1.0 - (1.0 - t) * (1.0 - t), "alpha": 1.0 - t}


## Label alpha: full, then fading over the last `fade` seconds of `life`.
static func label_alpha(age: float, life: float, fade: float) -> float:
	if age >= life:
		return 0.0
	if fade <= 0.0:
		return 1.0
	return clampf((life - age) / fade, 0.0, 1.0)
