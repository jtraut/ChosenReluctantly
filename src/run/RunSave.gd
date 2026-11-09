class_name RunSave
extends RefCounted
## The run save (MAP3 sitting A, MAP.md section 8): one slot, one JSON file, written at every room boundary of a map run and deleted when the run is won or lost.
## Static, like CharacterPick (whose persistence rules it copies): `path` is injectable and the file is neither read nor written by headless runs,
## test runs (`-s`), or a launch whose debug flags change the run (`suppress`), so tools, sims and the suite never touch a player's save.
## Tests turn the file on with `persist_override = true` and a `user://tests/...` path, and call `reset()` afterwards.
##
## What is saved: the RunState (`RunState.to_dict`) wrapped as {save_version, run}. A boundary is (a) the pick-next-node choice (the map screen) and
## (b) the start of a room, right after a node was picked. So quitting mid-fight and resuming restarts that room from its start and cannot re-pick
## the node. A run is never saved before its first room (nothing to resume), and straight (no-map) runs are not saved. The one exception is the
## start of act 2 and later (MAP3-B): the act's map is made and no room is picked yet, and that map screen is a boundary too, so quitting right after an act ends resumes there.
##
## For the Continue button (ux): `has_save()` (true only when the file loads), `load_save()` (makes the saved run the live one, true on success; the
## caller then starts the run scene), `delete_save()`. A bad, old or unreadable file is ignored with a warning and left on disk; it never crashes.

const DEFAULT_PATH := "user://run_save.json"
const SAVE_VERSION := 1
## Launch flags that change the run into a debug run: their runs never save (or delete) the player's file.
const DEBUG_FLAG_PREFIXES: Array[String] = ["--run-room", "--run-node", "--run-gold", "--run-clear-after", "--run-offer", "--full-deck", "--deck", "--relics", "--relic-offer", "--relic-cap", "--acts", "--scenario", "--sim-"]

static var path: String = DEFAULT_PATH
## Tests set this to true/false to force file use on or off; null = decide from how the game was launched.
static var persist_override: Variant = null
## Set by a launch with debug flags (see `args_suppress`): no file use for the rest of the process.
static var suppressed: bool = false
## What the last failed read said ("" when it was fine or there was no file). Tests and tools read it; the warning is printed too.
static var last_problem: String = ""


## True when a launch's user args hold a flag that makes the run a debug run.
static func args_suppress(args: PackedStringArray) -> bool:
	for arg: String in args:
		for prefix: String in DEBUG_FLAG_PREFIXES:
			if arg == prefix or arg.begins_with(prefix):
				return true
	return false


static func persistence_enabled() -> bool:
	if persist_override != null:
		return bool(persist_override)
	if suppressed or DisplayServer.get_name() == "headless":
		return false
	var args: PackedStringArray = OS.get_cmdline_args()
	return not (args.has("-s") or args.has("--script"))


## Test hook: back to the real path and the launch rules.
static func reset() -> void:
	path = DEFAULT_PATH
	persist_override = null
	suppressed = false
	last_problem = ""


# ---- writing ----

## True when `state` is at a boundary worth saving: a live map run with at least one room picked, at the map screen or at a room's start.
static func is_boundary(state: RunState) -> bool:
	if state == null or state.is_over() or not RunNodes.active(state) or (state.path.is_empty() and state.act <= 1):
		return false
	return state.pending == RunState.PENDING_NODE or state.pending == RunState.PENDING_NONE


## Writes the save when persistence is on and the state is at a boundary. False when nothing was written.
static func autosave(state: RunState) -> bool:
	if not persistence_enabled() or not is_boundary(state):
		return false
	return write(state)


## Writes `state` to the slot (through a temp file, so a crash mid-write leaves the old save). No boundary or persistence checks.
static func write(state: RunState) -> bool:
	var text: String = JSON.stringify({"save_version": SAVE_VERSION, "run": state.to_dict()})
	var temp: String = path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("RunSave: could not write '%s'" % temp)
		return false
	file.store_string(text)
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null or dir.rename(temp, path) != OK:
		if dir != null and dir.file_exists(path.get_file()):
			dir.remove(path.get_file())
			if dir.rename(temp, path) == OK:
				return true
		push_warning("RunSave: could not move the save into '%s'" % path)
		return false
	return true


## Removes the save (a won or lost run, or the player starting over). True when there is none afterwards.
static func delete_save() -> bool:
	if not persistence_enabled():
		return false
	if not FileAccess.file_exists(path):
		return true
	var dir := DirAccess.open(path.get_base_dir())
	return dir != null and dir.remove(path.get_file()) == OK


# ---- reading ----

## True when a save exists and loads (the Continue button shows only then).
static func has_save() -> bool:
	return persistence_enabled() and read_state() != null


## Reads and validates the slot. Returns the RunState, or null for no file / a bad file (with a warning; the file is left alone).
static func read_state() -> RunState:
	last_problem = ""
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	var problem: String = ""
	var state: RunState = null
	if typeof(parsed) != TYPE_DICTIONARY:
		problem = "not a JSON object"
	elif not _is_number((parsed as Dictionary).get("save_version")) or int((parsed as Dictionary)["save_version"]) != SAVE_VERSION:
		problem = "save_version %s is not the supported %d" % [str((parsed as Dictionary).get("save_version")), SAVE_VERSION]
	elif typeof((parsed as Dictionary).get("run")) != TYPE_DICTIONARY:
		problem = "no 'run' object"
	else:
		var run_data: Dictionary = (parsed as Dictionary)["run"]
		problem = _data_problem(run_data)
		if problem.is_empty():
			state = RunState.from_dict(run_data)
			if state == null:
				problem = "the run data is damaged"
			else:
				problem = _state_problem(state)
	if not problem.is_empty():
		last_problem = problem
		push_warning("RunSave: ignoring '%s' (%s)" % [path, problem])
		return null
	return state


## What the Continue button says it resumes (MAP3 ux): {character, character_name, act, acts_total, room, room_total}, or {} when there is no usable save.
## `room` is the whole-run number of the room you will be in next: at the map screen the rooms picked so far plus one, and at a room start that room.
static func summary() -> Dictionary:
	if not persistence_enabled():
		return {}
	var state: RunState = read_state()
	return summary_of(state) if state != null else {}


## `summary()` for a given state (pure, so it is testable without a file).
static func summary_of(state: RunState) -> Dictionary:
	if state == null:
		return {}
	var per_act: int = state.rooms_per_act()
	var room: int = state.run_room_number()
	if state.pending == RunState.PENDING_NODE:
		room = (state.act - 1) * per_act + state.path.size() + 1  # at the map screen: the next room is the one still to pick
	return {
		"character": state.character_id, "character_name": CharacterDatabase.display_name(state.character_id),
		"act": state.act, "acts_total": state.acts_total, "room": room, "room_total": state.run_room_total(),
	}


## Makes the saved run the live one (`RunSession.current`). True on success; false (nothing changed) when there is no usable save.
static func load_save() -> bool:
	if not persistence_enabled():
		return false
	var state: RunState = read_state()
	if state == null:
		return false
	RunSession.current = state
	return true


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## Checks that need the raw dictionary (from_dict repairs some things quietly that a save should refuse).
static func _data_problem(data: Dictionary) -> String:
	if _is_number(data.get("version")) and int(data["version"]) != RunState.FORMAT_VERSION:
		return "run format version %d is not %d" % [int(data["version"]), RunState.FORMAT_VERSION]
	if not CharacterDatabase.has(str(data.get("character", ""))):
		return "unknown character"
	if typeof(data.get("map")) != TYPE_DICTIONARY or (data["map"] as Dictionary).is_empty():
		return "no map"
	return ""


## Checks on the rebuilt state: a live map run at a boundary, with cards that exist.
static func _state_problem(state: RunState) -> String:
	if state.is_over():
		return "the run is already over"
	if not RunNodes.active(state):
		return "the map did not load"
	if (state.path.is_empty() and state.act <= 1) or not RunNodes.consistent(state):
		return "the path does not fit the room"
	if state.pending != RunState.PENDING_NODE and state.pending != RunState.PENDING_NONE:
		return "saved with a choice open"
	if state.deck.is_empty():
		return "empty deck"
	for card_id: String in state.deck:
		if not CardDatabase.has_card(card_id):
			return "unknown card '%s'" % card_id
	if not state.has_hp():
		return "no HP"
	# A hand-edited file can carry values no run reaches: a dead or over-full player, or a reject count outside 0..rejects_per_run.
	if is_nan(state.hp) or state.hp <= 0.0 or state.hp > state.max_hp:
		return "hp %s is outside 0 to the max HP %s" % [str(state.hp), str(state.max_hp)]
	if state.rejects_remaining < 0 or state.rejects_remaining > RunConfig.rejects_per_run():
		return "rejects_remaining %d is outside 0 to %d" % [state.rejects_remaining, RunConfig.rejects_per_run()]
	return ""
