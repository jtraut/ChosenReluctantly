class_name CharacterDatabase
extends RefCounted
## data/characters.json: the playable characters (W1a). One entry per class id (rogue, wizard, ...):
##   display_name, description (one line for the pick screen), class_pool + element_pool (pool ids from pools.json),
##   pools (everything the character draws cards from: its class, its element and neutral), max_hp,
##   body_color (the placeholder body), attacks {light: "default" | a data/attacks.json light_variants name,
##   heavy: a data/attacks.json heavy class id}, and starting_deck (15 card ids, passes the deck rules).
## It replaces the old hardcoded Player.owned_pools and the run.json character_pools / starting_deck.
## A new class is a data entry (plus its pool and cards), not code. Pure access plus validation; `validate_table`
## takes plain data so tests can feed it anything.

const PATH := "res://data/characters.json"
const DEFAULT_ID := "rogue"

static var _table := JsonDataTable.new(PATH)
static var _checked: bool = false


# ---- Reading ----

## Character ids in file order (the pick screen's order).
static func ids() -> Array[String]:
	_check_once()
	var out: Array[String] = []
	for id: Variant in _table.ids():
		out.append(String(id))
	return out


static func has(character_id: String) -> bool:
	return _table.has(character_id)


static func get_entry(character_id: String) -> Dictionary:
	_check_once()
	return _table.get_entry(character_id)


## A known id, else the default one. Use for anything that arrives from a save or an argument.
static func resolve(character_id: String) -> String:
	return character_id if has(character_id) else DEFAULT_ID


static func display_name(character_id: String) -> String:
	return String(get_entry(character_id).get("display_name", character_id))


## For the pick screen: [{id, display_name, description, class_pool, element_pool, max_hp, body_color (Color)}] in file order.
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ids():
		var entry: Dictionary = get_entry(id)
		out.append({
			"id": id,
			"display_name": String(entry.get("display_name", id)),
			"description": String(entry.get("description", "")),
			"class_pool": String(entry.get("class_pool", "")),
			"element_pool": String(entry.get("element_pool", "")),
			"max_hp": float(entry.get("max_hp", 0.0)),
			"body_color": body_color(id),
		})
	return out


static func pools(character_id: String) -> Array[String]:
	return _strings(get_entry(character_id).get("pools", []))


static func class_pool(character_id: String) -> String:
	return String(get_entry(character_id).get("class_pool", ""))


static func element_pool(character_id: String) -> String:
	return String(get_entry(character_id).get("element_pool", ""))


static func starting_deck(character_id: String) -> Array[String]:
	return _strings(get_entry(character_id).get("starting_deck", []))


## Every card of the character's pools, sorted: the --full-deck deck.
static func full_deck(character_id: String) -> Array[String]:
	return RunConfig.cards_in_pools(pools(character_id))


static func max_hp(character_id: String) -> float:
	return float(get_entry(character_id).get("max_hp", 30.0))


static func body_color(character_id: String) -> Color:
	var text: String = String(get_entry(character_id).get("body_color", "#ffffff"))
	return Color.html(text) if Color.html_is_valid(text) else Color.WHITE


## The attacks.json light variant name ("default" for the plain light).
static func light_variant(character_id: String) -> String:
	return String((get_entry(character_id).get("attacks", {}) as Dictionary).get("light", AttackDatabase.DEFAULT_LIGHT))


## The attacks.json heavy key (a class id).
static func heavy_class(character_id: String) -> String:
	return String((get_entry(character_id).get("attacks", {}) as Dictionary).get("heavy", class_pool(character_id)))


## The character that owns a set of pools (the one whose class pool is among them), or "" when none does.
static func id_for_pools(owned: Array) -> String:
	for id: String in ids():
		if owned.has(class_pool(id)):
			return id
	return ""


static func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for entry: Variant in (value as Array):
			out.append(String(entry))
	return out


# ---- Validation ----

## Logs the problems of the shipped file once per process (fail loud, keep running).
static func _check_once() -> void:
	if _checked:
		return
	_checked = true
	for problem: String in validate_shipped():
		push_error("characters.json: " + problem)


static func validate_shipped() -> Array[String]:
	var table: Dictionary = {}
	for id: Variant in _table.ids():
		table[id] = _table.get_entry(String(id))
	return validate_table(table)


## Every problem in a characters table (id -> entry), checked against the shipped pools, cards, attacks and deck rules.
static func validate_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if table.is_empty():
		errors.append("no characters defined")
		return errors
	if not table.has(DEFAULT_ID):
		errors.append("missing the default character '%s'" % DEFAULT_ID)
	for id: Variant in table.keys():
		var entry: Variant = table[id]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s: must be an object" % str(id))
			continue
		for problem: String in validate_entry(String(id), entry as Dictionary):
			errors.append("%s: %s" % [str(id), problem])
	return errors


static func validate_entry(character_id: String, entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["display_name", "description"]:
		if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).strip_edges().is_empty():
			errors.append("'%s' must be a non-empty string" % key)
	var hp: Variant = entry.get("max_hp")
	if (typeof(hp) != TYPE_FLOAT and typeof(hp) != TYPE_INT) or is_nan(float(hp)) or float(hp) < 1.0 or float(hp) > 100000.0:
		errors.append("'max_hp' must be a number from 1 to 100000")
	if typeof(entry.get("body_color")) != TYPE_STRING or not Color.html_is_valid(String(entry["body_color"])):
		errors.append("'body_color' must be a color string like '#338ce6'")
	var owned: Array[String] = []
	var pools_value: Variant = entry.get("pools")
	if typeof(pools_value) != TYPE_ARRAY or (pools_value as Array).is_empty():
		errors.append("'pools' must be a non-empty array of pool ids")
	else:
		for pool_id: Variant in (pools_value as Array):
			if typeof(pool_id) != TYPE_STRING or not PoolDatabase.has(String(pool_id)):
				errors.append("pools: unknown pool '%s'" % str(pool_id))
			elif owned.has(String(pool_id)):
				errors.append("pools: '%s' is listed twice" % str(pool_id))
			else:
				owned.append(String(pool_id))
	errors.append_array(_pool_kind_problems(entry, owned))
	errors.append_array(_attack_problems(entry.get("attacks")))
	errors.append_array(_deck_problems(entry.get("starting_deck"), owned))
	return errors


## The class pool and element pool named must be owned, of the right kind, and be the only ones of that kind.
static func _pool_kind_problems(entry: Dictionary, owned: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	for pair: Array in [["class_pool", "class"], ["element_pool", "element"]]:
		var key: String = pair[0]
		var kind: String = pair[1]
		var pool_id: Variant = entry.get(key)
		if typeof(pool_id) != TYPE_STRING or not owned.has(String(pool_id)):
			errors.append("'%s' must be one of the character's pools" % key)
		elif String(PoolDatabase.get_definition(String(pool_id)).get("kind", "")) != kind:
			errors.append("'%s' (%s) is not a %s pool" % [key, str(pool_id), kind])
		var count: int = 0
		for owned_id: String in owned:
			if PoolDatabase.has(owned_id) and String(PoolDatabase.get_definition(owned_id).get("kind", "")) == kind:
				count += 1
		if count != 1:
			errors.append("pools must hold exactly one %s pool (found %d)" % [kind, count])
	return errors


static func _attack_problems(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("'attacks' must be an object {light, heavy}")
		return errors
	var attacks: Dictionary = value
	var light: Variant = attacks.get("light")
	if typeof(light) != TYPE_STRING or not AttackDatabase.has_light(String(light)):
		errors.append("attacks.light '%s' is not 'default' or a light_variants name in attacks.json" % str(light))
	var heavy: Variant = attacks.get("heavy")
	if typeof(heavy) != TYPE_STRING or not AttackDatabase.has_heavy(String(heavy)):
		errors.append("attacks.heavy '%s' is not a heavy class id in attacks.json" % str(heavy))
	return errors


## The starter must be real cards from the character's pools and pass the deck rules.
static func _deck_problems(deck: Variant, owned: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	if typeof(deck) != TYPE_ARRAY or (deck as Array).is_empty():
		errors.append("'starting_deck' must be a non-empty array of card ids")
		return errors
	var ids_in_deck: Array[String] = []
	for card_id: Variant in (deck as Array):
		if typeof(card_id) != TYPE_STRING or not CardDatabase.has_card(String(card_id)):
			errors.append("starting_deck: unknown card id '%s'" % str(card_id))
			continue
		var pool: String = String(CardDatabase.get_card(String(card_id)).get("pool", ""))
		if not owned.is_empty() and not owned.has(pool):
			errors.append("starting_deck: '%s' is a %s card, not in this character's pools" % [str(card_id), pool])
		ids_in_deck.append(String(card_id))
	if errors.is_empty():
		var message: String = DeckRules.run_start_block_message(DeckRules.check_shipped(ids_in_deck))
		if message != "":
			errors.append("starting_deck breaks the deck rules: " + message)
	return errors
