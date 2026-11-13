class_name EventDatabase
extends RefCounted
## Boot-time event loader: reads every *.json in data/events (one event per file, the id equals the file name), validates each with EventSchema, and
## push_error()s + skips anything invalid, like RelicDatabase. EventSchema never logs; this is the one place a bad event file is reported.
##
## A missing or empty data/events is fine and means "no events" (git does not keep empty directories; MAP4 sitting B1 ships no events, sitting D adds them).
## Tests point `load_all` at a fixture folder and call `load_all()` again afterwards.

const DEFAULT_DIR := "res://data/events"

static var _events: Dictionary = {}
static var _loaded_dir: String = ""
static var _problems: Array[String] = []


## Loads `dir_path` (replacing what was loaded) and returns the problems found; each is also push_error'd.
static func load_all(dir_path: String = DEFAULT_DIR) -> Array[String]:
	_events.clear()
	_problems = []
	_loaded_dir = dir_path
	if not DirAccess.dir_exists_absolute(dir_path):
		return _problems
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_report("could not open directory '%s'" % dir_path)
		return _problems
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for name: String in files:
		_load_file(dir_path.path_join(name))
	return _problems


static func problems() -> Array[String]:
	_ensure_loaded()
	return _problems


static func has_event(event_id: String) -> bool:
	_ensure_loaded()
	return _events.has(event_id)


static func get_event(event_id: String) -> Dictionary:
	_ensure_loaded()
	return _events.get(event_id, {})


## All event ids, sorted.
static func ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for id: Variant in _events.keys():
		result.append(String(id))
	result.sort()
	return result


## Id -> event dictionary of everything loaded (a copy of the table, the events themselves are shared and read-only).
static func catalog() -> Dictionary:
	_ensure_loaded()
	return _events.duplicate()


static func is_empty() -> bool:
	_ensure_loaded()
	return _events.is_empty()


static func _ensure_loaded() -> void:
	if _loaded_dir.is_empty():
		load_all()


static func _load_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_report("could not open '%s'" % file_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_report("'%s' is not valid JSON (line %d: %s)" % [file_path, json.get_error_line(), json.get_error_message()])
		return
	var expected_id: String = file_path.get_file().get_basename()
	var errors: Array[String] = EventSchema.validate(json.data, expected_id)
	if not errors.is_empty():
		_report("'%s' is invalid: %s" % [file_path, "; ".join(errors)])
		return
	var event: Dictionary = json.data
	var event_id: String = String(event["id"])
	if _events.has(event_id):
		_report("duplicate event id '%s' (in '%s')" % [event_id, file_path])
		return
	_events[event_id] = event


static func _report(problem: String) -> void:
	_problems.append(problem)
	push_error("EventDatabase: " + problem)
