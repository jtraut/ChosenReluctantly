class_name RelicProgress
extends RefCounted
## The "2/4" counter on a HUD relic chip (MAP1 ux, BD2 playtest carry-over): a relic whose trigger fires on every Nth match (Spite Knuckles: every
## 4th light attack that hits) shows how far along it is. The N comes from the relic's data (`filter.every_nth`); the progress comes from the
## room's RelicManager (`trigger_progress`). Display only.

const NO_PROGRESS := -1


## The N of the first every-Nth trigger of a relic (0 when it has none, or the relic is unknown).
static func nth_of(relic_id: String) -> int:
	var relic: Dictionary = RelicDatabase.get_relic(relic_id)
	for trigger: Variant in (relic.get("triggers", []) as Array):
		var filter: Variant = (trigger as Dictionary).get("filter", {})
		if filter is Dictionary and int((filter as Dictionary).get("every_nth", 0)) > 1:
			return int((filter as Dictionary)["every_nth"])
	return 0


## Matches counted so far for `relic_id` in the manager's room (`RelicManager.trigger_progress`), or NO_PROGRESS when there is no manager.
static func matches_of(manager: Node, relic_id: String) -> int:
	if manager == null or not is_instance_valid(manager):
		return NO_PROGRESS
	if manager.has_method("trigger_progress"):
		return int(manager.call("trigger_progress", relic_id))
	return NO_PROGRESS


## "2/4": how many of the N matches are done since the last firing (a firing happens on the Nth, so it reads 0/4 right after). "" with no progress.
static func text(matches: int, nth: int) -> String:
	if nth <= 1 or matches < 0:
		return ""
	return "%d/%d" % [matches % nth, nth]
