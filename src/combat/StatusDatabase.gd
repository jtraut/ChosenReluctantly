class_name StatusDatabase
extends RefCounted
## data/statuses.json: status effect definitions (Burn, and later Chill,
## Soaked, ...).

static var _table := JsonDataTable.new("res://data/statuses.json")


static func get_status(status_id: String) -> Dictionary:
	return _table.get_entry(status_id)


static func has_status(status_id: String) -> bool:
	return _table.has(status_id)
