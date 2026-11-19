class_name PoolDatabase
extends RefCounted
## data/pools.json: the card pools (class/element/neutral) a character can
## draw from, per GDD §5. A new class or element is a data entry, not code.
##
## Element entries also carry the element's effect look ("visual": color and
## scale), so adding Water is a data entry only (see ElementVisuals).

const KINDS: Array[String] = ["class", "element", "neutral"]
const MIN_VISUAL_SCALE := 0.1
const MAX_VISUAL_SCALE := 5.0

static var _table := JsonDataTable.new("res://data/pools.json")


static func known_ids() -> Array:
	return _table.ids()


static func has(pool_id: String) -> bool:
	return _table.has(pool_id)


static func get_definition(pool_id: String) -> Dictionary:
	return _table.get_entry(pool_id)


## The card frame colour of a pool (data "frame_color"). Unknown pool: the
## neutral pool's colour.
static func frame_color_for_pool(pool_id: String) -> Color:
	var entry: Dictionary = get_definition(pool_id) if has(pool_id) else get_definition("neutral")
	return Color.html(String(entry.get("frame_color", "#9a9a9a")))


## THE accessor UI uses for a card's frame: card id -> its pool -> frame colour.
## Unknown card id: the neutral pool's colour.
static func frame_color_for_card(card_id: String) -> Color:
	return frame_color_for_pool(String(CardDatabase.get_card(card_id).get("pool", "neutral")))


## BD3b-D1: the tag every card of this pool carries (data "tag", for example the fire pool's "Fire"); "" when the pool has none or does not exist.
static func tag_for_pool(pool_id: String) -> String:
	if not has(pool_id):
		return ""
	return String(get_definition(pool_id).get("tag", ""))


## Every pool tag, in pools.json order.
static func all_pool_tags() -> Array[String]:
	var tags: Array[String] = []
	for pool_id: Variant in known_ids():
		var tag: String = tag_for_pool(String(pool_id))
		if not tag.is_empty():
			tags.append(tag)
	return tags


## Returns human-readable problems for one pool entry; empty means valid.
## An "element" must have a "visual"; other kinds may have one.
static func validate_entry(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var kind: Variant = entry.get("kind")
	if typeof(kind) != TYPE_STRING or not KINDS.has(kind):
		errors.append("'kind' must be one of %s" % [KINDS])
	var display_name: Variant = entry.get("display_name")
	if typeof(display_name) != TYPE_STRING or String(display_name).strip_edges().is_empty():
		errors.append("'display_name' must be a non-empty string")
	var frame: Variant = entry.get("frame_color")
	if typeof(frame) != TYPE_STRING or not Color.html_is_valid(String(frame)):
		errors.append("'frame_color' must be a valid color string like '#ff6a1f' (card frame colour, GDD section 4)")
	if entry.has("tag"):
		var tag: Variant = entry["tag"]
		if typeof(tag) != TYPE_STRING or String(tag).is_empty() or String(tag) != String(tag).strip_edges() or String(tag).contains(" "):
			errors.append("'tag' must be a non-empty string without spaces (the tag its cards carry, like 'Fire')")
		elif CardTags.DERIVED.has(String(tag)):
			errors.append("'tag' '%s' is already a derived card tag" % String(tag))
	if entry.has("visual"):
		errors.append_array(_validate_visual(entry["visual"]))
	elif kind == "element":
		errors.append("element needs a 'visual' ({color, scale})")
	if entry.has("status"):
		if kind != "element":
			errors.append("only an element can have a 'status'")
		errors.append_array(_validate_status(entry["status"]))
	return errors


## An element's flavor status: {status_id, base_chance 0..1}. Attacks scale the
## chance with their status_chance_multiplier (see AttackStatuses).
static func _validate_status(status: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(status) != TYPE_DICTIONARY:
		errors.append("'status' must be an object ({status_id, base_chance})")
		return errors
	var block: Dictionary = status
	if typeof(block.get("status_id")) != TYPE_STRING or not StatusDatabase.has_status(String(block["status_id"])):
		errors.append("status.status_id '%s' is not a status in statuses.json" % str(block.get("status_id")))
	var chance: Variant = block.get("base_chance")
	if (typeof(chance) != TYPE_FLOAT and typeof(chance) != TYPE_INT) or is_nan(float(chance)) or float(chance) < 0.0 or float(chance) > 1.0:
		errors.append("status.base_chance must be a number 0..1")
	return errors


## Validates a whole pools table (id -> entry); errors are prefixed with the id.
static func validate_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not table.has("neutral"):
		errors.append("missing required pool 'neutral' (physical damage uses its visual)")
	var tag_owner: Dictionary = {}
	for pool_id: Variant in table.keys():
		var entry: Variant = table[pool_id]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s: must be an object" % pool_id)
			continue
		var tag: Variant = (entry as Dictionary).get("tag")
		if typeof(tag) == TYPE_STRING and not String(tag).is_empty():
			if tag_owner.has(tag):
				errors.append("%s: tag '%s' is already used by pool '%s'" % [pool_id, tag, tag_owner[tag]])
			else:
				tag_owner[tag] = pool_id
		for message in validate_entry(entry):
			errors.append("%s: %s" % [pool_id, message])
	return errors


static func _validate_visual(visual: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(visual) != TYPE_DICTIONARY:
		errors.append("'visual' must be an object")
		return errors
	var visual_dict: Dictionary = visual
	var color: Variant = visual_dict.get("color")
	if typeof(color) != TYPE_STRING or not Color.html_is_valid(String(color)):
		errors.append("visual.color must be a valid color string like '#ff6a1f'")
	var scale: Variant = visual_dict.get("scale")
	if typeof(scale) != TYPE_FLOAT and typeof(scale) != TYPE_INT:
		errors.append("visual.scale must be a number")
	elif is_nan(float(scale)) or float(scale) < MIN_VISUAL_SCALE or float(scale) > MAX_VISUAL_SCALE:
		errors.append("visual.scale must be between %s and %s" % [MIN_VISUAL_SCALE, MAX_VISUAL_SCALE])
	return errors


## Whole-file check for startup/tests.
static func validate_all() -> Array[String]:
	var table: Dictionary = {}
	for pool_id: Variant in known_ids():
		table[pool_id] = get_definition(String(pool_id))
	return validate_table(table)
