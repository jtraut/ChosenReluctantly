class_name StatusDatabase
extends RefCounted
## Lazily-loaded, cached data/statuses.json. Pure data lookup; no validation
## side effects beyond push_error on a genuinely broken file, since this is a
## boot-time path, not something unit tests should exercise with bad data.

const STATUSES_PATH := "res://data/statuses.json"

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func get_status(status_id: String) -> Dictionary:
	_ensure_loaded()
	return _cache.get(status_id, {})


static func has_status(status_id: String) -> bool:
	_ensure_loaded()
	return _cache.has(status_id)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(STATUSES_PATH, FileAccess.READ)
	if file == null:
		push_error("StatusDatabase: could not open '%s'" % STATUSES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StatusDatabase: '%s' did not parse to a JSON object" % STATUSES_PATH)
		return
	_cache = parsed
