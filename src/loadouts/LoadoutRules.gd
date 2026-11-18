class_name LoadoutRules
extends RefCounted
## data/loadouts.json: the loadout limits (3d, GDD section 9). Pure loader and validator: `validate` takes plain data so tests feed it anything.
## The deck minimum is not stored here; it comes from the deck rules (`deck_min`), so the two can never disagree.

const PATH := "res://data/loadouts.json"
const VERSION := 1
const KEYS: Array[String] = ["version", "slots_per_class", "max_copies", "deck_max", "name_max_length"]
## "At least 5 loadout slots per class" (director, 2026-11-02).
const MIN_SLOTS := 5

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Problems with a config; empty means valid. Unknown keys are rejected. `deck_min` (>0) also checks deck_max against it.
static func validate(config: Variant, deck_min: int = -1) -> Array[String]:
	var errors: Array[String] = []
	if typeof(config) != TYPE_DICTIONARY:
		errors.append("loadouts: the file must be a JSON object")
		return errors
	var table: Dictionary = config
	for key: Variant in table.keys():
		if not KEYS.has(String(key)):
			errors.append("loadouts: unknown key '%s' (known: %s)" % [str(key), KEYS])
	for key: String in KEYS:
		if not table.has(key):
			errors.append("loadouts: missing '%s'" % key)
		elif not UserJson.is_whole(table[key]) or int(table[key]) < 1:
			errors.append("loadouts.%s must be a whole number of at least 1" % key)
	if errors.is_empty():
		if int(table["version"]) != VERSION:
			errors.append("loadouts.version must be %d" % VERSION)
		if int(table["slots_per_class"]) < MIN_SLOTS:
			errors.append("loadouts.slots_per_class must be at least %d" % MIN_SLOTS)
		if deck_min > 0 and int(table["deck_max"]) < deck_min:
			errors.append("loadouts.deck_max %d is below the deck-rule minimum %d" % [int(table["deck_max"]), deck_min])
	return errors


## The shipped config. A bad file is a loud error (boot-time data error) and reads as the validated defaults' absence: callers get {} and must not run.
static func get_config() -> Dictionary:
	_ensure_loaded()
	return _cache


static func reset_cache() -> void:
	_cache = {}
	_loaded = false


static func slots_per_class() -> int:
	return int(get_config().get("slots_per_class", MIN_SLOTS))


static func max_copies() -> int:
	return int(get_config().get("max_copies", 2))


static func deck_max() -> int:
	return int(get_config().get("deck_max", 20))


static func name_max_length() -> int:
	return int(get_config().get("name_max_length", 24))


## The smallest legal deck: every slot's unique-card minimum added up (15 today), from the deck rules.
static func deck_min() -> int:
	var total: int = 0
	var config: Dictionary = DeckRules.shipped_config()
	for slot_type: Variant in SlotTypeDatabase.known_ids():
		total += DeckRules.min_for_slot(config, String(slot_type))
	return total


## Problems with the shipped file (including deck_max against the deck rules); empty means valid.
static func shipped_problems() -> Array[String]:
	var read: Dictionary = UserJson.read(PATH)
	if not bool(read["ok"]) or not bool(read["exists"]):
		var errors: Array[String] = ["loadouts: could not read %s" % PATH]
		return errors
	return validate(read["data"], deck_min())


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var read: Dictionary = UserJson.read(PATH)
	var problems: Array[String] = shipped_problems()
	if not problems.is_empty():
		for problem: String in problems:
			push_error("LoadoutRules: " + problem)
		_cache = {}
		return
	_cache = read["data"]
