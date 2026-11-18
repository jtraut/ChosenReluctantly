class_name LoadoutArgs
extends RefCounted
## The launch flags of the loadout system (3d sitting C) and the one rule that keeps debug runs off the player's files. Pure: `resolve` takes the user args
## and whether the launch is a script or headless, so a test can check every combination without a window.
##
## Flags (after `--`; all are in `RunSave.DEBUG_FLAG_PREFIXES`, so each makes the launch a debug launch):
##   --runs-finished=N      fakes the finished-run count (N >= 0) for this process; nothing is written. `--runs-finished=1` reaches the run 2 start screen.
##   --profile-path=<file>  the profile file to use (a scratch file); the only profile file a debug launch may touch.
##   --loadouts-path=<file> the loadouts file to use (a scratch file); the only loadouts file a debug launch may touch.
##   --loadout=<n|preset>   starts every run of the launch with saved loadout n (1-based, as the screens say "loadout 2") or the preset. Needs --loadouts-path=,
##                          because a debug launch never reads the real loadouts file (it is refused with a message otherwise).
##
## The rule: `use_default_files` is true only for a real game: a window, no `-s` script, no debug flag. A gated launch uses in-memory profile and loadouts
## unless it names a scratch file itself.

const FLAG_RUNS := "--runs-finished="
const FLAG_PROFILE := "--profile-path="
const FLAG_LOADOUTS := "--loadouts-path="
const FLAG_LOADOUT := "--loadout="
## `slot` when `--loadout` was not given.
const NO_SLOT := -2


static func is_script_launch(cmdline_args: PackedStringArray) -> bool:
	return cmdline_args.has("-s") or cmdline_args.has("--script")


## {gated: bool, use_default_files: bool, runs_finished: int (-1 = not given), profile_path: String ("" = none given), loadouts_path: String ("" = none given),
## slot: int (NO_SLOT, LoadoutStore.PRESET or a 0-based slot), errors: Array[String]}.
static func resolve(args: PackedStringArray, headless: bool, script_launch: bool) -> Dictionary:
	var errors: Array[String] = []
	var runs_finished: int = -1
	var profile_path: String = ""
	var loadouts_path: String = ""
	var slot: int = NO_SLOT
	var slot_text: String = ""
	for arg: String in args:
		if arg.begins_with(FLAG_RUNS):
			var text: String = arg.substr(FLAG_RUNS.length())
			if text.is_valid_int() and text.to_int() >= 0:
				runs_finished = text.to_int()
			else:
				errors.append("--runs-finished needs a whole number from 0, as --runs-finished=1")
		elif arg.begins_with(FLAG_PROFILE):
			profile_path = arg.substr(FLAG_PROFILE.length())
			if profile_path.is_empty():
				errors.append("--profile-path needs a file, as --profile-path=user://scratch/profile.json")
		elif arg.begins_with(FLAG_LOADOUTS):
			loadouts_path = arg.substr(FLAG_LOADOUTS.length())
			if loadouts_path.is_empty():
				errors.append("--loadouts-path needs a file, as --loadouts-path=user://scratch/loadouts.json")
		elif arg.begins_with(FLAG_LOADOUT):
			slot_text = arg.substr(FLAG_LOADOUT.length())
			if slot_text == "preset":
				slot = LoadoutStore.PRESET
			elif slot_text.is_valid_int() and slot_text.to_int() >= 1 and slot_text.to_int() <= LoadoutRules.slots_per_class():
				slot = slot_text.to_int() - 1
			else:
				errors.append("--loadout needs a loadout number from 1 to %d, or 'preset', as --loadout=2" % LoadoutRules.slots_per_class())
	if slot >= 0 and loadouts_path.is_empty():
		errors.append("--loadout=%s needs --loadouts-path=<file>: a debug launch never reads the real loadouts file" % slot_text)
	var gated: bool = headless or script_launch or RunSave.args_suppress(args)
	return {"gated": gated, "use_default_files": not gated, "runs_finished": runs_finished, "profile_path": profile_path,
			"loadouts_path": loadouts_path, "slot": slot, "errors": errors}
