class_name UserJson
extends RefCounted
## Tiny JSON file helper for the player's own files (profile, loadouts). Never crashes and never pushes an error: a missing, unreadable or
## malformed file comes back as a result with a `problem`, and the caller decides what to do. Writes go through a temp file.


## {ok: bool, exists: bool, data: Dictionary, problem: String}. A missing file is ok with exists false. A file that is not a JSON object is not ok.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "exists": false, "data": {}, "problem": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "exists": true, "data": {}, "problem": "could not open '%s'" % path}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()  # not JSON.parse_string: that prints an engine error for bad JSON, and a bad player file is expected, not an error
	var parsed: Variant = parser.data if parser.parse(text) == OK else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "exists": true, "data": {}, "problem": "'%s' is not a JSON object" % path}
	return {"ok": true, "exists": true, "data": parsed, "problem": ""}


## Writes `data` as JSON through path + ".tmp". False when it could not.
static func write(path: String, data: Dictionary) -> bool:
	var temp: String = path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "    "))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if dir.rename(temp, path) == OK:
		return true
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
		return dir.rename(temp, path) == OK
	return false


## Copies the file at `path` to path + ".bak" (replacing an older backup). Used before a save overwrites a file that could not be read.
static func backup(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var text: String = FileAccess.get_file_as_string(path)
	var file := FileAccess.open(path + ".bak", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func is_whole(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return not is_nan(number) and not is_inf(number) and number == floorf(number)
