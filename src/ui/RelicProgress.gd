class_name RelicProgress
extends RefCounted
## The "2/4" counter on a HUD relic chip (MAP1 ux, BD2 playtest carry-over): a relic whose trigger fires on every Nth match (Spite Knuckles: every
## 4th light attack that hits) shows how far along it is. The N comes from the relic's data (`filter.every_nth`); the progress comes from the
## room's RelicManager. Display only.
##
## The manager does not expose its per-trigger match counter yet. `matches_of` asks for `RelicManager.trigger_progress(relic_id) -> int` (matches so far
## in this room) and, until that exists, reads the manager's `_triggers` list. That fallback is TEMPORARY and lives only here, so the day gameplay adds
## the accessor nothing else changes; if the field is renamed the counter hides instead of showing a wrong number (NO_PROGRESS).

const NO_PROGRESS := -1


## The N of the first every-Nth trigger of a relic (0 when it has none, or the relic is unknown).
static func nth_of(relic_id: String) -> int:
	var relic: Dictionary = RelicDatabase.get_relic(relic_id)
	for trigger: Variant in (relic.get("triggers", []) as Array):
		var filter: Variant = (trigger as Dictionary).get("filter", {})
		if filter is Dictionary and int((filter as Dictionary).get("every_nth", 0)) > 1:
			return int((filter as Dictionary)["every_nth"])
	return 0


## Matches counted so far for `relic_id` in the manager's room, or NO_PROGRESS when the manager can't say.
static func matches_of(manager: Node, relic_id: String) -> int:
	if manager == null or not is_instance_valid(manager):
		return NO_PROGRESS
	if manager.has_method("trigger_progress"):
		return int(manager.call("trigger_progress", relic_id))
	var triggers: Variant = manager.get("_triggers")
	if not (triggers is Array):
		return NO_PROGRESS
	for trigger: Variant in (triggers as Array):
		var entry: Dictionary = trigger
		if String(entry.get("relic_id", "")) == relic_id and int((entry.get("filter", {}) as Dictionary).get("every_nth", 0)) > 1:
			return int(entry.get("matches", 0))
	return NO_PROGRESS


## "2/4": how many of the N matches are done since the last firing (a firing happens on the Nth, so it reads 0/4 right after). "" with no progress.
static func text(matches: int, nth: int) -> String:
	if nth <= 1 or matches < 0:
		return ""
	return "%d/%d" % [matches % nth, nth]
