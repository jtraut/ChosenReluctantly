class_name RelicArgs
extends RefCounted
## Parsing and checking of the relic launch arguments (`--relics`, `--relic-offer`), shared by the game and the sims.


## "a+b,c" -> ["a", "b", "c"] ("+" too, because capture_screenshot.ps1 splits its -Extra values on commas).
static func parse_ids(text: String) -> Array[String]:
	var ids: Array[String] = []
	for part: String in text.replace("+", ",").split(",", false):
		ids.append(part.strip_edges())
	return ids


## Problems with a list of relic ids (empty = fine): at least one, all known, none twice, and at most `max_count` when that is above 0.
static func id_problems(flag: String, ids: Array[String], max_count: int) -> Array[String]:
	var problems: Array[String] = []
	if ids.is_empty():
		problems.append("%s needs relic ids, as %s=<relic>+<relic> (known: %s)" % [flag, flag, ", ".join(RelicDatabase.ids())])
	if max_count > 0 and ids.size() > max_count:
		problems.append("%s lists %d relics but an offer holds %d" % [flag, ids.size(), max_count])
	var seen: Dictionary = {}
	for id: String in ids:
		if not RelicDatabase.has_relic(id):
			problems.append("%s: unknown relic '%s' (known: %s)" % [flag, id, ", ".join(RelicDatabase.ids())])
		elif seen.has(id):
			problems.append("%s: '%s' is listed twice" % [flag, id])
		seen[id] = true
	return problems
