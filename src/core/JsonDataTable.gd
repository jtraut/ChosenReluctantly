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


func get_entry(id: String) -> Dictionary:
	_ensure_loaded()
	return _cache.get(id, {})


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
