class_name CharacterPick
extends RefCounted
## Which character the next run is played as, and the remembered last pick (W1a). Pure state plus one tiny file.
##
## The last pick lives in memory for the process (Try again and New run keep it) and, in a real windowed game,
## in `user://last_class.json` so the next launch preselects it. The file is neither read nor written by headless
## runs, test runs (`-s`) or when `persist_override` is false, so tools, sims and the suite never depend on, or
## change, a player's file. `--class` never writes it (only a confirmed pick does, via `remember`).
##
## For the pick screen (ux): `CharacterDatabase.list()` is the class list with display names, `preselected()` is the
## entry to highlight, `RunController.confirm_class_pick(id)` confirms it and starts the run.

const DEFAULT_PATH := "user://last_class.json"

static var path: String = DEFAULT_PATH
## Tests set this to true/false to force file use on or off; null = decide from how the game was launched.
static var persist_override: Variant = null
static var _memory: String = ""
static var _file_read: bool = false


## True when the last pick may be read from and written to the file.
static func persistence_enabled() -> bool:
	if persist_override != null:
		return bool(persist_override)
	if DisplayServer.get_name() == "headless":
		return false
	var args: PackedStringArray = OS.get_cmdline_args()
	return not (args.has("-s") or args.has("--script"))


## The last confirmed pick (a known character id), else the default (Rogue).
static func last_pick() -> String:
	if _memory == "" and not _file_read and persistence_enabled():
		_file_read = true
		_memory = _read_file()
	return _memory if CharacterDatabase.has(_memory) else CharacterDatabase.DEFAULT_ID


## What a pick screen highlights first: the class chosen for the next run (a `--class`, else the last pick).
static func preselected() -> String:
	return RunSession.chosen_character()


## Remembers `character_id` as the last pick (memory, and the file when persistence is on). False for an unknown id.
static func remember(character_id: String) -> bool:
	if not CharacterDatabase.has(character_id):
		push_error("CharacterPick.remember: unknown character '%s'" % character_id)
		return false
	_memory = character_id
	if persistence_enabled():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("CharacterPick: could not write '%s'" % path)
			return false
		file.store_string(JSON.stringify({"last_class": character_id}))
	return true


## Test hook: forget the in-memory pick and re-read the file next time.
static func reset() -> void:
	_memory = ""
	_file_read = false
	path = DEFAULT_PATH
	persist_override = null


static func _read_file() -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if typeof(parsed) != TYPE_DICTIONARY or not CharacterDatabase.has(str((parsed as Dictionary).get("last_class", ""))):
		push_error("CharacterPick: '%s' is not a valid last-class file; ignoring it" % path)
		return ""
	return str((parsed as Dictionary)["last_class"])
