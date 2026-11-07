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
