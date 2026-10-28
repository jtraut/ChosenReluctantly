class_name CaptureArgs
extends RefCounted
## Parses the user command-line args (after `--`) that enable screenshot
## capture and scripted scenarios. Pure and static so it is unit-testable.
##
## Supported: --screenshot-after=3.0[,6.0,...]  --screenshot-out=<path>
##            --screenshot-count=N --screenshot-interval=S  --scenario=<id>

const DEFAULT_OUT := "user://screenshot.png"
const DEFAULT_INTERVAL := 1.0


## Returns {error: String, times: Array[float], out: String, scenario: String}.
## A non-empty `error` means the args were malformed (caller should fail). Empty `times`
## means no capture; empty `scenario` means no scenario.
static func parse(args: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var eq := arg.find("=")
		if eq == -1:
			values[arg.substr(2)] = ""
		else:
			values[arg.substr(2, eq - 2)] = arg.substr(eq + 1)

	var times: Array[float] = []
	var error := ""
	if values.has("screenshot-after"):
		for part: String in String(values["screenshot-after"]).split(",", false):
			if part.is_valid_float() and part.to_float() >= 0.0:
				times.append(part.to_float())
			else:
				error = "invalid --screenshot-after value '%s' (need non-negative seconds, comma separated)" % part
	elif values.has("screenshot-count"):
		var count: int = String(values["screenshot-count"]).to_int()
		var interval: float = DEFAULT_INTERVAL
		if values.has("screenshot-interval") and String(values["screenshot-interval"]).is_valid_float():
			interval = maxf(String(values["screenshot-interval"]).to_float(), 0.0)
		for i in range(maxi(count, 0)):
			times.append(interval * float(i + 1))

	if error == "" and (values.has("screenshot-after") or values.has("screenshot-count")) and times.is_empty():
		error = "--screenshot-after/--screenshot-count produced no valid capture times"
	if error == "" and values.has("scenario") and not Scenario.has_scenario(String(values["scenario"])):
		error = "unknown --scenario '%s'" % String(values["scenario"])
	return {
		"error": error,
		"times": times,
		"out": String(values.get("screenshot-out", DEFAULT_OUT)),
		"scenario": String(values.get("scenario", "")),
	}


## Error message for malformed capture args, or "" if they are fine.
static func validate(args: PackedStringArray) -> String:
	return String(parse(args)["error"])


## Output path for capture `index` of `total`. A single capture uses `out`
## verbatim; several insert `_<index>` before the extension.
static func output_path(out: String, index: int, total: int) -> String:
	var path := out if out.get_extension() != "" else out.path_join("shot.png")
	if total <= 1:
		return path
	return "%s_%d.%s" % [path.get_basename(), index, path.get_extension()]
