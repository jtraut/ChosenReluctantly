class_name CaptureArgs
extends RefCounted
## Parses the user command-line args (after `--`) that enable screenshot
## capture and scripted scenarios. Pure and static so it is unit-testable.
##
## Supported: --screenshot-after=3.0[,6.0,...]  --screenshot-out=<path>
##            --screenshot-count=N --screenshot-interval=S  --scenario=<id>
##            --press=<t>:<action>[:<hold>][,...]   scripted tap (or, with :<hold>, a hold of that many seconds) of an input action t seconds
##            after launch (for example 0.5:dodge, 1:move_forward:2); <t>:aim_nearest / <t>:aim_off make the aim follow the nearest enemy
##            --at-boss-attack=<attack id>   make the --screenshot-after times relative to the moment a boss starts winding up
##            that attack (for example volley), instead of to launch

const DEFAULT_OUT := "user://screenshot.png"
const DEFAULT_INTERVAL := 1.0
## --press pseudo-actions (not InputMap names): aim at the nearest live enemy, and stop.
const AIM_ACTIONS: Array[String] = ["aim_nearest", "aim_off"]
## Longest hold one --press step may ask for, seconds.
const MAX_HOLD := 120.0


## Returns {error: String, times: Array[float], out: String, scenario: String, presses: Array[Dictionary] ({at, action}),
## boss_attack: String}.
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

	var presses: Array[Dictionary] = []
	var press_error := ""
	if values.has("press"):
		for part: String in String(values["press"]).split(",", false):
			var step: Dictionary = parse_press_step(part)
			if step.is_empty():
				press_error = "invalid --press value '%s' (need <seconds>:<input action>[:<hold seconds>] or <seconds>:aim_nearest or <seconds>:aim_off, for example 0.5:dodge or 1:move_forward:2)" % part
			else:
				presses.append(step)
	if values.has("press") and String(values["press"]).strip_edges() == "":
		press_error = "--press needs a value, as --press=<seconds>:<input action>[:<hold seconds>][,...]"
	if press_error != "":
		error = press_error
	var boss_attack: String = String(values.get("at-boss-attack", ""))
	if error == "" and values.has("at-boss-attack") and (boss_attack == "" or not known_boss_attacks().has(boss_attack)):
		error = "invalid --at-boss-attack '%s' (need a boss attack id: %s)" % [boss_attack, ", ".join(known_boss_attacks())]
	if error == "" and (values.has("screenshot-after") or values.has("screenshot-count")) and times.is_empty():
		error = "--screenshot-after/--screenshot-count produced no valid capture times"
	if error == "" and values.has("scenario") and not Scenario.has_scenario(String(values["scenario"])):
		error = "unknown --scenario '%s'" % String(values["scenario"])
	return {
		"error": error,
		"times": times,
		"out": String(values.get("screenshot-out", DEFAULT_OUT)),
		"scenario": String(values.get("scenario", "")),
		"presses": presses,
		"press_error": press_error,
		"boss_attack": boss_attack,
	}


## One --press step: "<t>:<action>" (a tap), "<t>:<action>:<hold>" (hold the action for `hold` seconds, 0 < hold <= MAX_HOLD),
## "<t>:aim_nearest" (from t on, the aim target follows the nearest live enemy) or "<t>:aim_off" (back to the mouse).
## Returns {at: float, action: StringName, hold: float} (hold 0 = a tap), or {} when malformed.
static func parse_press_step(part: String) -> Dictionary:
	var fields: PackedStringArray = part.split(":")
	if fields.size() < 2 or fields.size() > 3:
		return {}
	var when: String = fields[0]
	var action: String = fields[1]
	if not when.is_valid_float() or when.to_float() < 0.0 or action == "":
		return {}
	var is_aim: bool = AIM_ACTIONS.has(action)
	if not is_aim and not InputMap.has_action(action):
		return {}
	var hold: float = 0.0
	if fields.size() == 3:
		if is_aim or not fields[2].is_valid_float() or fields[2].to_float() <= 0.0 or fields[2].to_float() > MAX_HOLD:
			return {}
		hold = fields[2].to_float()
	return {"at": when.to_float(), "action": StringName(action), "hold": hold}


## Every attack id any boss in data/bosses.json has.
static func known_boss_attacks() -> Array[String]:
	var ids: Array[String] = []
	var bosses: Dictionary = BossConfig.get_config().get("bosses", {})
	for boss: Variant in bosses.values():
		for id: Variant in ((boss as Dictionary).get("attacks", {}) as Dictionary).keys():
			if not ids.has(String(id)):
				ids.append(String(id))
	return ids


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
