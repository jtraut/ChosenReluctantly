class_name PoolDatabase
extends RefCounted
## data/pools.json: the card pools (class/element/neutral) a character can
## draw from, per GDD §5. A new class or element is a data entry, not code.

static var _table := JsonDataTable.new("res://data/pools.json")


static func known_ids() -> Array:
	return _table.ids()


static func has(pool_id: String) -> bool:
	return _table.has(pool_id)


static func get_definition(pool_id: String) -> Dictionary:
	return _table.get_entry(pool_id)
