class_name WatchText
extends RefCounted
## TL3a: the pure wording and argument rules for the TL2 watch log's four nits, kept under tools/ (WatchMode is game-side code).

## True when --watch-shots was given with no folder: "--watch-shots" alone or "--watch-shots=".
static func is_bare(args: Array) -> bool:
	for arg: Variant in args:
		var text: String = String(arg)
		if text == "--watch-shots":
			return true
		if text.begins_with(WatchMode.ARG_PREFIX):
			return WatchMode.parse_dir(args) == ""
	return false


## "room 12 of the run (act 2 room 3)": the run-wide number first, the act-local one beside it.
static func room_text(run_room: int, act_room: int) -> String:
	return "room %d of the run (act room %d)" % [run_room, act_room]


## The HP the log's RESULT line shows: on a loss the player's own current HP (the run state still holds the HP the last room started
## with), else the run state's recorded HP.
static func hp_at_end(outcome: String, recorded: float, live: float, live_valid: bool) -> String:
	if outcome == "lost":
		return str(snappedf(live if live_valid else 0.0, 0.1))
	return str(recorded)
