class_name KeywordDatabase
extends RefCounted
## data/keywords.json: the authored card keywords (Primer, Payoff, Keystone). Tags and keywords share one
## spelling (Capitalised) so a condition's `tag` or a buff's `consume_on_cast` can name either.

static var _table := JsonDataTable.new("res://data/keywords.json")


static func known_ids() -> Array:
	return _table.ids()


static func has(keyword_id: String) -> bool:
	return _table.has(keyword_id)


static func display_name(keyword_id: String) -> String:
	return String(_table.get_entry(keyword_id).get("display_name", keyword_id))


static func rule_text(keyword_id: String) -> String:
	return String(_table.get_entry(keyword_id).get("rule_text", ""))


## Problems with the file itself (each entry needs a non-empty display_name and rule_text, and the id may not
## collide with a derived tag). Empty means fine.
static func validate_table() -> Array[String]:
	var errors: Array[String] = []
	for keyword_id: String in known_ids():
		var entry: Variant = _table.get_entry(keyword_id)
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("keyword '%s' must be an object" % keyword_id)
			continue
		for field: String in ["display_name", "rule_text"]:
			if typeof((entry as Dictionary).get(field)) != TYPE_STRING or String((entry as Dictionary)[field]).is_empty():
				errors.append("keyword '%s' needs a non-empty '%s'" % [keyword_id, field])
		if CardTags.DERIVED.has(keyword_id):
			errors.append("keyword '%s' collides with a derived tag" % keyword_id)
	return errors
