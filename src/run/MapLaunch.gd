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
