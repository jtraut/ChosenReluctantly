class_name JsonDataTable
extends RefCounted
## Lazy-loaded, cached lookup over a JSON file shaped as {id: {...}}. One
## instance per data file; the owner keeps it in a `static var` so the file
## is parsed once no matter how many times entries are looked up.

var _path: String
var _cache: Dictionary = {}
var _loaded: bool = false


func _init(path: String) -> void:
	_path = path


## The entry as an object. An unknown id gives {}. An entry that exists but is not a JSON object is a data error: it is
## reported loudly (naming the file and the id) and gives {}; a validator that wants to report it as a problem
## reads `get_raw` instead and checks the type itself.
func get_entry(id: String) -> Dictionary:
	_ensure_loaded()
	var raw: Variant = _cache.get(id, {})
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("JsonDataTable: entry '%s' in '%s' must be an object, found %s" % [id, _path, type_string(typeof(raw))])
		return {}
	return raw


## The entry exactly as the file holds it (any JSON value), or null for an unknown id. For validators.
func get_raw(id: String) -> Variant:
	_ensure_loaded()
	return _cache.get(id)


func has(id: String) -> bool:
	_ensure_loaded()
	return _cache.has(id)


func ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		push_error("JsonDataTable: could not open '%s'" % _path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JsonDataTable: '%s' did not parse to a JSON object" % _path)
		return
	_cache = parsed
