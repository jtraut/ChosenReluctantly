class_name MapLaunch
extends RefCounted
## The `--map` / `--no-map` launch flags (MAP1-B): which of the data switch (data/map.json `enabled`) and the branching map the run uses.
## Pure over the launch args, so the refusals are testable. Neither flag takes a value, and the two cannot be combined or repeated.

const OVERRIDE_NONE := -1
const OVERRIDE_OFF := 0
const OVERRIDE_ON := 1


## {override: OVERRIDE_NONE | OVERRIDE_OFF | OVERRIDE_ON, errors: Array[String]}. Any error means the launch is refused (exit 2).
static func resolve(args: PackedStringArray) -> Dictionary:
	var errors: Array[String] = []
	var on_count: int = 0
	var off_count: int = 0
	for arg: String in args:
		if arg == "--map":
			on_count += 1
		elif arg == "--no-map":
			off_count += 1
		elif arg.begins_with("--map=") or arg.begins_with("--no-map="):
			errors.append("%s takes no value; use --map to force the branching map or --no-map for the straight run" % arg.get_slice("=", 0))
	if on_count > 0 and off_count > 0:
		errors.append("--map and --no-map cannot be combined; give one of them")
	elif on_count > 1:
		errors.append("--map was given %d times; give it once" % on_count)
	elif off_count > 1:
		errors.append("--no-map was given %d times; give it once" % off_count)
	var override: int = OVERRIDE_NONE
	if errors.is_empty():
		if on_count == 1:
			override = OVERRIDE_ON
		elif off_count == 1:
			override = OVERRIDE_OFF
	return {"override": override, "errors": errors}


## `--acts=N` (MAP3-B, debug and capture): the run has N acts, 1 to RunState.MAX_ACTS (`--acts=1` is the MAP2 one-act run, whose last room is the boss). {acts: int, errors}; acts is 0 when
## the flag is absent. A value that is not a whole number in range, or a flag given twice, is refused (exit 2) instead of silently ignored.
static func resolve_acts(args: PackedStringArray) -> Dictionary:
	var errors: Array[String] = []
	var acts: int = 0
	var count: int = 0
	for arg: String in args:
		if arg == "--acts" or arg.begins_with("--acts="):
			count += 1
			var value: String = arg.substr(7) if arg.begins_with("--acts=") else ""
			if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > RunState.MAX_ACTS:
				errors.append("--acts needs a whole number from 1 to %d, as --acts=1 (got '%s')" % [RunState.MAX_ACTS, value])
			else:
				acts = value.to_int()
	if count > 1:
		errors.append("--acts was given %d times; give it once" % count)
	if not errors.is_empty():
		acts = 0
	return {"acts": acts, "errors": errors}


## `--run-room=N` counts rooms over the whole run (MAP3-B: 1 to `limit`, 30 for three acts of 10). "" when it is fine or absent, else why the launch is refused (exit 2).
## Only a value that is a whole number above `limit` is a problem here; the other malformed values keep their old behaviour (the flag is ignored).
static func run_room_problem(args: PackedStringArray, limit: int) -> String:
	for arg: String in args:
		if arg.begins_with("--run-room=") and arg.substr(11).is_valid_int() and arg.substr(11).to_int() > limit:
			return "--run-room=%s is past the last room; this run has %d rooms (1 to %d)" % [arg.substr(11), limit, limit]
	return ""


## `--run-node=N`, `--run-gold=N` and `--merchant` (MAP2-B debug flags): {node: int, gold: int, errors: Array[String]}; node and gold are -1 when not given.
## Each of the two numbers needs a whole number from 0 (`--run-node=33`) and may be given once; `--merchant` takes no value and may be given once.
## Any error means the launch is refused (exit 2) instead of a silently ignored flag.
static func resolve_run_args(args: PackedStringArray) -> Dictionary:
	var errors: Array[String] = []
	var node: int = -1
	var gold: int = -1
	var counts: Dictionary = {"--run-node": 0, "--run-gold": 0, "--merchant": 0}
	for arg: String in args:
		var flag: String = arg.get_slice("=", 0)
		if not counts.has(flag):
			continue
		counts[flag] = int(counts[flag]) + 1
		if flag == "--merchant":
			if arg != "--merchant":
				errors.append("--merchant takes no value; give it as --merchant")
			continue
		var value: String = arg.substr(flag.length() + 1) if arg.contains("=") else ""
		if not value.is_valid_int() or value.to_int() < 0:
			errors.append("%s needs a whole number from 0, as %s=33 (got '%s')" % [flag, flag, value])
		elif flag == "--run-node":
			node = value.to_int()
		else:
			gold = value.to_int()
	for flag: String in counts.keys():
		if int(counts[flag]) > 1:
			errors.append("%s was given %d times; give it once" % [flag, int(counts[flag])])
	if not errors.is_empty():
		node = -1
		gold = -1
	return {"node": node, "gold": gold, "errors": errors}
