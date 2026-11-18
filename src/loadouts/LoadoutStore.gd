class_name LoadoutStore
extends RefCounted
## The saved loadouts (3d, acceptance 5): `user://loadouts.json` = {version, classes: {<class id>: {last_used, slots: [entry or null, ...]}}}.
## Each class holds `LoadoutRules.slots_per_class()` slots (5 today). A slot is an entry {name, deck, plan, starter_relic, passive_allocation}
## (see LoadoutCheck) or empty. Slot positions never shift: a bad entry keeps its slot, is flagged with a message and is not usable, and the
## player can overwrite or delete it. `last_used` is PRESET (-1, the preset deck) or a slot index.
##
## Never crashes and never blocks a run: a missing file is an empty store, an unreadable or outdated file is flagged (`file_problem`) and treated as
## empty (the next write keeps it as `<path>.bak`), and a bad class block or entry is flagged and skipped. The preset is always available.
## The path is injectable (`LoadoutStore.new(path)`). Rule checks are LoadoutCheck's, which go through DeckRules/DeckCheck only.
## Sitting C decides who may write (scenarios, sims and debug launches never do).

const DEFAULT_PATH := "user://loadouts.json"
const VERSION := 1
const PRESET := -1

var path: String
## "" when the file was fine or absent; otherwise why the whole file was ignored.
var file_problem: String = ""

var _slots: Dictionary = {}  # class id -> Array (raw: null or Dictionary, a bad one kept as read)
var _flags: Dictionary = {}  # class id -> {slot index: message}
var _last_used: Dictionary = {}  # class id -> int
var _flag_messages: Array[String] = []
var _extra_classes: Dictionary = {}  # class blocks of unknown classes, kept as read
var _backed_up: bool = false


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	load_file()


## (Re)reads the file and checks every entry against the rules.
func load_file() -> void:
	_slots = {}
	_flags = {}
	_last_used = {}
	_flag_messages = []
	_extra_classes = {}
	_backed_up = false
	file_problem = ""
	var read: Dictionary = UserJson.read(path)
	if not bool(read["ok"]):
		file_problem = "loadouts ignored: " + String(read["problem"])
		_flag_messages.append(file_problem)
		return
	if not bool(read["exists"]):
		return
	var data: Dictionary = read["data"]
	if not UserJson.is_whole(data.get("version")) or int(data["version"]) != VERSION:
		file_problem = "loadouts ignored: the file version is %s, this game reads version %d" % [str(data.get("version")), VERSION]
		_flag_messages.append(file_problem)
		return
	var classes: Variant = data.get("classes")
	if typeof(classes) != TYPE_DICTIONARY:
		file_problem = "loadouts ignored: 'classes' must be an object"
		_flag_messages.append(file_problem)
		return
	for class_key: Variant in (classes as Dictionary).keys():
		_load_class(String(class_key), (classes as Dictionary)[class_key])


# ---- reading ----

## Messages for everything that was skipped, for the start screen ("rogue slot 2 'Name': ...").
func flagged() -> Array[String]:
	return _flag_messages


func slot_count() -> int:
	return LoadoutRules.slots_per_class()


## The usable entry in a slot, or {} when it is empty, flagged or out of range. A copy: change it freely.
func entry(class_id: String, index: int) -> Dictionary:
	if index < 0 or index >= slot_count() or is_flagged(class_id, index):
		return {}
	var raw: Array = _raw_slots(class_id)
	if index >= raw.size() or typeof(raw[index]) != TYPE_DICTIONARY:
		return {}
	return (raw[index] as Dictionary).duplicate(true)


## True when the slot holds an entry that failed the rules (it is not usable).
func is_flagged(class_id: String, index: int) -> bool:
	return (_flags.get(class_id, {}) as Dictionary).has(index)


## Why a flagged slot is unusable; "" when it is not flagged.
func flag_message(class_id: String, index: int) -> String:
	return String((_flags.get(class_id, {}) as Dictionary).get(index, ""))


## Indices of the usable entries, ascending.
func usable_indices(class_id: String) -> Array[int]:
	var out: Array[int] = []
	for i in range(slot_count()):
		if not entry(class_id, i).is_empty():
			out.append(i)
	return out


## Indices of the empty slots (a new loadout may go there), ascending. A flagged slot is not empty.
func free_indices(class_id: String) -> Array[int]:
	var out: Array[int] = []
	var raw: Array = _raw_slots(class_id)
	for i in range(slot_count()):
		if i >= raw.size() or raw[i] == null:
			out.append(i)
	return out


## PRESET (-1) or the index of the last used usable loadout. A stale index (deleted, flagged, out of range) reads as the preset.
func last_used(class_id: String) -> int:
	var index: int = int(_last_used.get(class_id, PRESET))
	return index if index != PRESET and not entry(class_id, index).is_empty() else PRESET


# ---- writing ----

## Remembers the last used choice (PRESET or a usable slot) and writes. False for a slot that is not usable or when the write fails.
func set_last_used(class_id: String, index: int) -> bool:
	if not CharacterDatabase.has(class_id):
		return false
	if index != PRESET and entry(class_id, index).is_empty():
		return false
	_last_used[class_id] = index
	return write()


## Checks `new_entry` and, when it passes, stores it in the slot (empty, flagged or overwritten) and writes. Returns the problems; empty means saved.
## Nothing changes when there are problems. An overwritten flagged slot loses its flag.
func save_entry(class_id: String, index: int, new_entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not CharacterDatabase.has(class_id):
		problems.append("unknown class '%s'" % class_id)
		return problems
	if index < 0 or index >= slot_count():
		problems.append("slot %d is out of range (0 to %d)" % [index, slot_count() - 1])
		return problems
	problems = LoadoutCheck.entry_problems(class_id, new_entry)
	if not problems.is_empty():
		return problems
	var raw: Array = _raw_slots(class_id)
	while raw.size() <= index:
		raw.append(null)
	raw[index] = LoadoutCheck.normalised(new_entry)
	_slots[class_id] = raw
	_clear_flag(class_id, index)
	if not write():
		problems.append("could not write '%s'" % path)
	return problems


## Empties a slot (also a flagged one) and writes. False when the slot is out of range or the write fails.
func delete_entry(class_id: String, index: int) -> bool:
	if index < 0 or index >= slot_count():
		return false
	var raw: Array = _raw_slots(class_id)
	if index < raw.size():
		raw[index] = null
		_slots[class_id] = raw
	_clear_flag(class_id, index)
	if int(_last_used.get(class_id, PRESET)) == index:
		_last_used[class_id] = PRESET
	return write()


## Writes the file. A file that could not be read is kept as `<path>.bak` first (once). Flagged entries are written back as they were.
func write() -> bool:
	if not file_problem.is_empty() and not _backed_up:
		_backed_up = true
		UserJson.backup(path)
	var classes: Dictionary = _extra_classes.duplicate(true)
	var class_ids: Array = _slots.keys()
	for class_key: Variant in _last_used.keys():
		if not class_ids.has(class_key):
			class_ids.append(class_key)
	for class_key: Variant in class_ids:
		classes[String(class_key)] = {"last_used": int(_last_used.get(class_key, PRESET)), "slots": _raw_slots(String(class_key)).duplicate(true)}
	var ok: bool = UserJson.write(path, {"version": VERSION, "classes": classes})
	if ok:
		file_problem = ""
	return ok


# ---- internals ----

func _raw_slots(class_id: String) -> Array:
	return _slots.get(class_id, []) as Array


func _clear_flag(class_id: String, index: int) -> void:
	var flags: Dictionary = _flags.get(class_id, {})
	flags.erase(index)
	_flags[class_id] = flags


func _flag(class_id: String, index: int, entry_name: String, message: String) -> void:
	var flags: Dictionary = _flags.get(class_id, {})
	flags[index] = message
	_flags[class_id] = flags
	var label: String = "%s slot %d" % [class_id, index + 1]
	if not entry_name.is_empty():
		label += " '%s'" % entry_name
	_flag_messages.append("%s skipped: %s" % [label, message])


func _load_class(class_id: String, block: Variant) -> void:
	if not CharacterDatabase.has(class_id):
		_extra_classes[class_id] = block
		_flag_messages.append("loadouts for unknown class '%s' skipped" % class_id)
		return
	if typeof(block) != TYPE_DICTIONARY or typeof((block as Dictionary).get("slots")) != TYPE_ARRAY:
		_extra_classes[class_id] = block
		_flag_messages.append("loadouts for '%s' skipped: the class block needs a 'slots' list" % class_id)
		return
	var raw: Array = (block as Dictionary)["slots"]
	var kept: Array = []
	for i in range(raw.size()):
		var item: Variant = raw[i]
		if item == null:
			kept.append(null)
			continue
		kept.append(item)
		if i >= slot_count():
			_flag(class_id, i, "", "it is past the %d slots a class holds" % slot_count())
			continue
		var problems: Array[String] = LoadoutCheck.entry_problems(class_id, item)
		if problems.is_empty():
			kept[i] = LoadoutCheck.normalised(item)
		else:
			var entry_name: String = String((item as Dictionary).get("name", "")) if typeof(item) == TYPE_DICTIONARY and typeof((item as Dictionary).get("name")) == TYPE_STRING else ""
			_flag(class_id, i, entry_name, "; ".join(problems))
	_slots[class_id] = kept
	var last: Variant = (block as Dictionary).get("last_used", PRESET)
	if UserJson.is_whole(last):
		_last_used[class_id] = int(last)
	else:
		_flag_messages.append("%s: last_used must be a whole number, using the preset" % class_id)
