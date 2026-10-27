class_name SlotTypeDatabase
extends RefCounted
## data/slot_types.json: the 5 card-slot types, data-driven per GDD §4 so
## adding/changing a slot never requires a code change.

static var _table := JsonDataTable.new("res://data/slot_types.json")


static func known_ids() -> Array:
	return _table.ids()


static func has(slot_type_id: String) -> bool:
	return _table.has(slot_type_id)


static func get_definition(slot_type_id: String) -> Dictionary:
	return _table.get_entry(slot_type_id)
