class_name CardDatabase
extends RefCounted
## Boot-time card loader: reads every *.json in a directory, validates each
## against CardSchema, and push_error()s + skips anything invalid rather than
## crashing the game. This is the one place card data errors should ever be
## logged - CardSchema itself never logs, so tests can feed it bad data
## without polluting a "zero errors" run.

const DEFAULT_CARDS_DIR := "res://data/cards"

static var _cards: Dictionary = {}
static var _loaded_dir: String = ""


static func load_all(dir_path: String = DEFAULT_CARDS_DIR) -> void:
	_cards.clear()
	_loaded_dir = dir_path
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("CardDatabase: could not open directory '%s'" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_card_file(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	if dir_path == DEFAULT_CARDS_DIR:
		for problem: String in CardDamageRule.check_shipped():
			push_error("CardDatabase: damage-card rule broken: " + problem)


static func get_card(card_id: String) -> Dictionary:
	_ensure_loaded()
	return _cards.get(card_id, {})


static func has_card(card_id: String) -> bool:
	_ensure_loaded()
	return _cards.has(card_id)


static func all_cards() -> Array:
	_ensure_loaded()
	return _cards.values()


static func cards_for_pool(pool_id: String) -> Array:
	_ensure_loaded()
	return _cards.values().filter(func(card: Dictionary) -> bool: return card.get("pool") == pool_id)


static func cards_for_slot_type(slot_type_id: String) -> Array:
	_ensure_loaded()
	return _cards.values().filter(func(card: Dictionary) -> bool: return card.get("slot_type") == slot_type_id)


static func _ensure_loaded() -> void:
	if _loaded_dir.is_empty():
		load_all()


static func _load_card_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: could not open '%s'" % file_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CardDatabase: '%s' did not parse to a JSON object" % file_path)
		return
	var card_data: Dictionary = parsed
	var errors := CardSchema.validate(card_data)
	if not errors.is_empty():
		push_error("CardDatabase: '%s' is invalid: %s" % [file_path, ", ".join(errors)])
		return
	for warning in CardSchema.warnings(card_data):
		push_warning("CardDatabase: '%s': %s" % [file_path, warning])
	var card_id: String = card_data["id"]
	if _cards.has(card_id):
		push_error("CardDatabase: duplicate card id '%s' (in '%s')" % [card_id, file_path])
		return
	_cards[card_id] = card_data
