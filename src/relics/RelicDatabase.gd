class_name RelicDatabase
extends RefCounted
## Boot-time relic loader: reads every *.json in data/relics (one relic per file, the id equals the file name), validates
## each with RelicSchema, and push_error()s + skips anything invalid, like CardDatabase does for cards. RelicSchema
## never logs; this is the one place a bad relic file is reported.
##
## An empty or missing data/relics is fine and means "no relics": git does not keep empty directories, so a fresh clone
## of a project with no relic files has no such directory, and that must not be an error.

const DEFAULT_DIR := "res://data/relics"

static var _relics: Dictionary = {}
static var _loaded_dir: String = ""
## Problems found by the last load (also pushed as errors), for tests and tools.
static var _problems: Array[String] = []


## Loads `dir_path` (replacing what was loaded) and returns the problems found; each is also push_error'd.
static func load_all(dir_path: String = DEFAULT_DIR) -> Array[String]:
	_relics.clear()
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
	files.sort()  # a stable order, whatever the file system lists
	for name: String in files:
		_load_file(dir_path.path_join(name))
	return _problems


static func problems() -> Array[String]:
	_ensure_loaded()
	return _problems


static func has_relic(relic_id: String) -> bool:
	_ensure_loaded()
	return _relics.has(relic_id)


static func get_relic(relic_id: String) -> Dictionary:
	_ensure_loaded()
	return _relics.get(relic_id, {})


## All relic ids, sorted.
static func ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for id: Variant in _relics.keys():
		result.append(String(id))
	result.sort()
	return result


static func all_relics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in ids():
		result.append(_relics[id])
	return result


static func is_empty() -> bool:
	_ensure_loaded()
	return _relics.is_empty()


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
	var errors: Array[String] = RelicSchema.validate(json.data, expected_id)
	if not errors.is_empty():
		_report("'%s' is invalid: %s" % [file_path, "; ".join(errors)])
		return
	var relic: Dictionary = json.data
	var relic_id: String = String(relic["id"])
	if _relics.has(relic_id):
		_report("duplicate relic id '%s' (in '%s')" % [relic_id, file_path])
		return
	_relics[relic_id] = relic


static func _report(problem: String) -> void:
	_problems.append(problem)
	push_error("RelicDatabase: " + problem)
