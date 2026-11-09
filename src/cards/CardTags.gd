class_name CardTags
extends RefCounted
## Tags of a card: derived from its effects (nobody writes them by hand, so they cannot drift) plus its authored
## `keywords`. Pure functions. Tags and keywords share one Capitalised spelling.
##
## Rules (BUILD_DEPTH 3.1): Projectile (a projectile effect), Melee (a cone, or a dash with damage), Area (an aoe),
## Zone (a zone), Dash (a dash or pass_through), Heal (a heal effect, or a status whose effect_type is heal_over_time
## or lifesteal), Burn / Bleed (an apply_status or a zone's status of that id), Buff (a buff effect).
## A dash with damage is both Melee and Dash. Conditional effects count the same as unconditional ones.

const PROJECTILE := "Projectile"
const MELEE := "Melee"
const AREA := "Area"
const ZONE := "Zone"
const DASH := "Dash"
const HEAL := "Heal"
const BURN := "Burn"
const BLEED := "Bleed"
const BUFF := "Buff"

## Canonical order of the derived tags (derive() returns them in this order).
const DERIVED: Array[String] = [PROJECTILE, MELEE, AREA, ZONE, DASH, HEAL, BURN, BLEED, BUFF]

## status id -> the tag applying it grants.
const STATUS_TAGS: Dictionary = {"burn": BURN, "bleed": BLEED}
const HEAL_STATUS_EFFECT_TYPES: Array[String] = ["heal_over_time", "lifesteal"]


## The derived tags of a card dictionary, in DERIVED order, no duplicates.
static func derive(card: Dictionary) -> Array[String]:
	var found: Dictionary = {}
	var effects: Variant = card.get("effects", [])
	if typeof(effects) == TYPE_ARRAY:
		for effect: Variant in (effects as Array):
			if typeof(effect) == TYPE_DICTIONARY:
				_add_effect_tags(effect as Dictionary, found)
	var result: Array[String] = []
	for tag: String in DERIVED:
		if found.has(tag):
			result.append(tag)
	return result


## Derived tags then authored keywords (unknown or repeated keywords dropped), keywords after the derived ones.
static func all_tags(card: Dictionary) -> Array[String]:
	var result := derive(card)
	var keywords: Variant = card.get("keywords", [])
	if typeof(keywords) == TYPE_ARRAY:
		for keyword: Variant in (keywords as Array):
			if typeof(keyword) == TYPE_STRING and not result.has(String(keyword)):
				result.append(String(keyword))
	return result


## The authored keywords of a card (as written, strings only).
static func keywords_of(card: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var keywords: Variant = card.get("keywords", [])
	if typeof(keywords) == TYPE_ARRAY:
		for keyword: Variant in (keywords as Array):
			if typeof(keyword) == TYPE_STRING:
				result.append(String(keyword))
	return result


## True when `tag` is a derived tag or a known keyword (what a condition or buff may name).
static func is_known_tag(tag: String) -> bool:
	return DERIVED.has(tag) or KeywordDatabase.has(tag)


## Problems with a card's `keywords` field (empty = fine or absent).
static func validate_keywords(card: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not card.has("keywords"):
		return errors
	var keywords: Variant = card["keywords"]
	if typeof(keywords) != TYPE_ARRAY:
		errors.append("'keywords' must be an array of keyword ids")
		return errors
	var seen: Dictionary = {}
	for keyword: Variant in (keywords as Array):
		if typeof(keyword) != TYPE_STRING or not KeywordDatabase.has(String(keyword)):
			errors.append("unknown keyword '%s' (known: %s)" % [str(keyword), KeywordDatabase.known_ids()])
		elif seen.has(keyword):
			errors.append("keyword '%s' is listed twice" % String(keyword))
		else:
			seen[keyword] = true
	return errors


static func _add_effect_tags(effect: Dictionary, found: Dictionary) -> void:
	var params: Dictionary = effect["params"] if typeof(effect.get("params")) == TYPE_DICTIONARY else {}
	match String(effect.get("template", "")):
		"cone":
			found[MELEE] = true
		"aoe":
			found[AREA] = true
		"zone":
			found[ZONE] = true
			_add_status_tags(String(params.get("status_id", "")), found)
		"projectile":
			found[PROJECTILE] = true
			_add_status_tags(String(params.get("status_id", "")), found)
		"dash":
			found[DASH] = true
			if params.has("damage"):
				found[MELEE] = true
			_add_status_tags(String(params.get("status_id", "")), found)
		"pass_through":
			found[DASH] = true
		"heal":
			found[HEAL] = true
		"apply_status", "detonate_status":
			_add_status_tags(String(params.get("status_id", "")), found)
		"buff":
			found[BUFF] = true


static func _add_status_tags(status_id: String, found: Dictionary) -> void:
	if status_id.is_empty():
		return
	if STATUS_TAGS.has(status_id):
		found[String(STATUS_TAGS[status_id])] = true
	var effect_type: String = String(StatusDatabase.get_status(status_id).get("effect_type", ""))
	if HEAL_STATUS_EFFECT_TYPES.has(effect_type):
		found[HEAL] = true
