class_name RunConfig
extends RefCounted
## data/run.json: the shape of a run (Milestone 3a). Room mix and placement rules, the finite wave lists per
## room type, elite and boss tier stats, rest healing, the reject allowance, the starting deck and the
## placeholder run UI text. Pure loader and validator: `validate` takes plain data so tests feed it anything.
## Run code reads cards only as ids; the deck list is checked against the card database and the deck rules.

const PATH := "res://data/run.json"
const ROOM_TYPES: Array[String] = ["combat", "elite", "rest", "boss"]
## Room types that fight (they need a wave list); `rest` has none.
const FIGHT_TYPES: Array[String] = ["combat", "elite", "boss"]
const TIER_IDS: Array[String] = ["elite", "boss"]

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _load_problems: Array[String] = []


## Human-readable problems; empty means valid. `known_enemies` skips its id check when empty (`_known_cards` is kept for callers; the starting deck lives in characters.json).
static func validate(config: Dictionary, known_enemies: Array[String], _known_cards: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var composition: Variant = config.get("composition")
	var total: int = 0
	if typeof(composition) != TYPE_DICTIONARY:
		errors.append("'composition' must be an object {combat, elite, rest, boss}")
	else:
		for key: Variant in (composition as Dictionary).keys():
			if not ROOM_TYPES.has(String(key)):
				errors.append("composition: unknown room type '%s'" % str(key))
		for room_type: String in ROOM_TYPES:
			var n: Variant = (composition as Dictionary).get(room_type, 0)
			if not _is_whole(n) or int(n) < 0 or int(n) > 50:
				errors.append("composition.%s must be a whole number in [0, 50]" % room_type)
			else:
				total += int(n)
		if _is_whole((composition as Dictionary).get("boss", 0)) and int((composition as Dictionary).get("boss", 0)) != 1:
			errors.append("composition.boss must be exactly 1 (the boss is the last room)")
		if total < 2:
			errors.append("a run needs at least 2 rooms")
	errors.append_array(_validate_placement(config, composition, total))
	var heal: Variant = config.get("rest_heal_fraction")
	if not _is_number(heal) or float(heal) < 0.0 or float(heal) > 1.0:
		errors.append("'rest_heal_fraction' must be a number in [0, 1]")
	var rejects: Variant = config.get("rejects_per_run")
	if not _is_whole(rejects) or int(rejects) < 0 or int(rejects) > 99:
		errors.append("'rejects_per_run' must be a whole number in [0, 99]")
	errors.append_array(_validate_rewards(config.get("rewards")))
	errors.append_array(_validate_tiers(config.get("tiers")))
	errors.append_array(_validate_rooms(config, known_enemies, total))
	errors.append_array(_validate_ui(config.get("ui")))
	return errors


static func _validate_placement(config: Dictionary, composition: Variant, total: int) -> Array[String]:
	var errors: Array[String] = []
	var placement: Variant = config.get("placement")
	if typeof(placement) != TYPE_DICTIONARY:
		errors.append("'placement' must be an object")
		return errors
	var p: Dictionary = placement
	if typeof(p.get("boss_last")) != TYPE_BOOL or not bool(p["boss_last"]):
		errors.append("placement.boss_last must be true")
	if typeof(p.get("first_room")) != TYPE_STRING or not ROOM_TYPES.has(String(p["first_room"])) or String(p["first_room"]) == "boss":
		errors.append("placement.first_room must be a non-boss room type")
	var ranges: Variant = p.get("ranges")
	if typeof(ranges) != TYPE_DICTIONARY:
		errors.append("placement.ranges must be an object {room type: [first index, last index]}")
		return errors
	if typeof(composition) != TYPE_DICTIONARY:
		return errors
	var comp: Dictionary = composition
	for room_type: String in ["elite", "rest"]:
		var count: int = int(comp.get(room_type, 0)) if _is_whole(comp.get(room_type, 0)) else 0
		if count == 0:
			continue
		var range_value: Variant = (ranges as Dictionary).get(room_type)
		if typeof(range_value) != TYPE_ARRAY or (range_value as Array).size() != 2 or not _is_whole((range_value as Array)[0]) or not _is_whole((range_value as Array)[1]):
			errors.append("placement.ranges.%s must be [first, last] whole indices" % room_type)
			continue
		var low: int = int((range_value as Array)[0])
		var high: int = int((range_value as Array)[1])
		# The boss takes the last index, so the usable window ends one before it.
		if low < 0 or high < low or high > total - 2:
			errors.append("placement.ranges.%s [%d, %d] must satisfy 0 <= first <= last <= %d" % [room_type, low, high, total - 2])
		elif high - low + 1 < count:
			errors.append("placement.ranges.%s holds %d rooms but the composition asks for %d" % [room_type, high - low + 1, count])
	if _is_whole(comp.get("elite", 0)) and _is_whole(comp.get("rest", 0)) and total > 1:
		if int(comp.get("elite", 0)) + int(comp.get("rest", 0)) > total - 1:
			errors.append("not enough non-boss rooms for the elite and rest rooms")
	return errors


## The card reward block: offer size, the unowned/owned weights and which room types give a reward.
static func _validate_rewards(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("'rewards' must be an object {offer_size, unowned_weight, owned_weight, reward_room_types}")
		return errors
	var r: Dictionary = value
	if not _is_whole(r.get("offer_size")) or int(r["offer_size"]) < 1 or int(r["offer_size"]) > 12:
		errors.append("rewards.offer_size must be a whole number in [1, 12]")
	for key: String in ["unowned_weight", "owned_weight"]:
		if not _is_number(r.get(key)) or float(r[key]) < 0.0 or float(r[key]) > 1000.0:
			errors.append("rewards.%s must be a number in [0, 1000]" % key)
	if _is_number(r.get("unowned_weight")) and _is_number(r.get("owned_weight")) and float(r["unowned_weight"]) + float(r["owned_weight"]) <= 0.0:
		errors.append("rewards: unowned_weight and owned_weight cannot both be 0")
	var types: Variant = r.get("reward_room_types")
	if typeof(types) != TYPE_ARRAY:
		errors.append("rewards.reward_room_types must be an array of room types")
	else:
		for t: Variant in (types as Array):
			if typeof(t) != TYPE_STRING or not FIGHT_TYPES.has(String(t)):
				errors.append("rewards.reward_room_types: '%s' is not a fighting room type (combat, elite, boss)" % str(t))
	return errors


static func _validate_tiers(tiers: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(tiers) != TYPE_DICTIONARY:
		errors.append("'tiers' must be an object {elite, boss}")
		return errors
	for tier_id: String in TIER_IDS:
		var tier_value: Variant = (tiers as Dictionary).get(tier_id)
		if typeof(tier_value) != TYPE_DICTIONARY:
			errors.append("tiers.%s must be an object" % tier_id)
			continue
		var t: Dictionary = tier_value
		var mult: Variant = t.get("hp_multiplier")
		if not _is_number(mult) or float(mult) < 1.0 or float(mult) > 50.0:
			errors.append("tiers.%s.hp_multiplier must be a number in [1, 50]" % tier_id)
		var floor_value: Variant = t.get("resistance_floor")
		var cap_value: Variant = t.get("resistance_cap")
		if not _is_number(floor_value) or float(floor_value) < 0.0 or float(floor_value) > 1.0:
			errors.append("tiers.%s.resistance_floor must be a number in [0, 1]" % tier_id)
		if not _is_number(cap_value) or float(cap_value) < 0.0 or float(cap_value) > 1.0:
			errors.append("tiers.%s.resistance_cap must be a number in [0, 1]" % tier_id)
		elif _is_number(floor_value) and float(floor_value) > float(cap_value):
			errors.append("tiers.%s.resistance_floor is above resistance_cap" % tier_id)
		var armor_value: Variant = t.get("armor")
		if not _is_number(armor_value) or float(armor_value) < 0.0 or float(armor_value) > 1000.0:
			errors.append("tiers.%s.armor is required and must be a number in [0, 1000]" % tier_id)
		elif _is_number(floor_value):
			errors.append_array(ArmorConfig.parity_errors("tiers." + tier_id, float(armor_value), float(floor_value), ArmorConfig.k(), ArmorConfig.PARITY_TOLERANCE))
		if typeof(t.get("rank")) != TYPE_STRING or not ["normal", "elite", "boss"].has(String(t["rank"])):
			errors.append("tiers.%s.rank must be normal, elite or boss" % tier_id)
		var scale_value: Variant = t.get("scale")
		if not _is_number(scale_value) or float(scale_value) < 0.5 or float(scale_value) > 4.0:
			errors.append("tiers.%s.scale must be a number in [0.5, 4]" % tier_id)
		if typeof(t.get("marker_color")) != TYPE_STRING or not String(t["marker_color"]).is_valid_html_color():
			errors.append("tiers.%s.marker_color must be an html color" % tier_id)
	return errors


static func _validate_rooms(config: Dictionary, known_enemies: Array[String], total: int) -> Array[String]:
	var errors: Array[String] = []
	var rooms: Variant = config.get("rooms")
	if typeof(rooms) != TYPE_DICTIONARY:
		errors.append("'rooms' must be an object {combat, elite, boss: [wave lists]}")
		return errors
	var composition: Variant = config.get("composition")
	var base: Dictionary = WaveConfig.get_config()
	var seen_ids: Array[String] = []
	for room_type: String in FIGHT_TYPES:
		var wanted: int = 0
		if typeof(composition) == TYPE_DICTIONARY and _is_whole((composition as Dictionary).get(room_type, 0)):
			wanted = int((composition as Dictionary).get(room_type, 0))
		var variants: Variant = (rooms as Dictionary).get(room_type)
		if typeof(variants) != TYPE_ARRAY or (variants as Array).is_empty():
			if wanted > 0:
				errors.append("rooms.%s must be a non-empty array of wave lists" % room_type)
			continue
		for i in range((variants as Array).size()):
			var variant: Variant = (variants as Array)[i]
			var label: String = "rooms.%s[%d]" % [room_type, i]
			if typeof(variant) != TYPE_DICTIONARY:
				errors.append("%s must be an object" % label)
				continue
			var v: Dictionary = variant
			var id_value: Variant = v.get("id")
			if typeof(id_value) != TYPE_STRING or String(id_value) == "":
				errors.append("%s: 'id' must be a non-empty string" % label)
			elif seen_ids.has(String(id_value)):
				errors.append("%s: duplicate room id '%s'" % [label, String(id_value)])
			else:
				seen_ids.append(String(id_value))
			for key: String in ["min_index", "max_index"]:
				if v.has(key) and (not _is_whole(v[key]) or int(v[key]) < 0 or int(v[key]) >= maxi(total, 1)):
					errors.append("%s: '%s' must be a room index in [0, %d]" % [label, key, total - 1])
			errors.append_array(_validate_wave_list(label, v, base, known_enemies))
	errors.append_array(_validate_variant_coverage(config, total))
	return errors


## The room's wave list is checked with the shared wave schema: the global numbers come from data/waves.json.
static func _validate_wave_list(label: String, variant: Dictionary, base: Dictionary, known_enemies: Array[String]) -> Array[String]:
	var table: Dictionary = room_wave_config(variant, base)
	var errors: Array[String] = []
	for problem: String in WaveConfig.validate(table, known_enemies):
		errors.append("%s: %s" % [label, problem])
	return errors


## Every room position of a type must have at least one wave list that allows its index.
static func _validate_variant_coverage(config: Dictionary, total: int) -> Array[String]:
	var errors: Array[String] = []
	if total < 1 or typeof(config.get("rooms")) != TYPE_DICTIONARY or typeof(config.get("composition")) != TYPE_DICTIONARY:
		return errors
	for room_type: String in FIGHT_TYPES:
		var variants: Variant = (config["rooms"] as Dictionary).get(room_type)
		var wanted: Variant = (config["composition"] as Dictionary).get(room_type, 0)
		if typeof(variants) != TYPE_ARRAY or not _is_whole(wanted) or int(wanted) <= 0:
			continue
		for index in range(total):
			if variants_for(index, variants as Array).is_empty():
				errors.append("rooms.%s: no wave list allows room index %d" % [room_type, index])
				break
	return errors


static func _validate_ui(ui_value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(ui_value) != TYPE_DICTIONARY:
		errors.append("'ui' must be an object")
		return errors
	var u: Dictionary = ui_value
	if typeof(u.get("room_label")) != TYPE_STRING or String(u["room_label"]).count("%d") != 2:
		errors.append("ui.room_label must be a format string with two %d")
	var names: Variant = u.get("type_names")
	if typeof(names) != TYPE_DICTIONARY:
		errors.append("ui.type_names must be an object")
	else:
		for room_type: String in ROOM_TYPES:
			if typeof((names as Dictionary).get(room_type)) != TYPE_STRING:
				errors.append("ui.type_names.%s must be a string" % room_type)
	for key: String in ["room_cleared", "win", "reward", "rest"]:
		if typeof(u.get(key)) != TYPE_DICTIONARY:
			errors.append("ui.%s must be an object" % key)
	if typeof(u.get("next_line")) != TYPE_STRING or String(u["next_line"]).count("%d") != 2 or String(u["next_line"]).count("%s") != 1:
		errors.append("ui.next_line must be a format string with two %d and one %s")
	return errors


## The full wave table for one room: the global numbers from `base` (data/waves.json), this room's stages,
## finite. Per-room `first_wave_delay` overrides the base one.
static func room_wave_config(variant: Dictionary, base: Dictionary) -> Dictionary:
	var table: Dictionary = base.duplicate(true)
	table["stages"] = (variant.get("stages", []) as Array).duplicate(true)
	table["loop_from_stage"] = 0
	table["finite"] = true
	if variant.has("first_wave_delay"):
		table["first_wave_delay"] = variant["first_wave_delay"]
	return table


## The wave lists that allow room `index` (min_index/max_index are inclusive).
static func variants_for(index: int, variants: Array) -> Array:
	var out: Array = []
	for variant: Variant in variants:
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = variant
		if index < int(v.get("min_index", 0)) or index > int(v.get("max_index", 9999)):
			continue
		out.append(v)
	return out


## The wave list with `id` in the config, or {}.
static func variant_by_id(config: Dictionary, room_type: String, wave_id: String) -> Dictionary:
	var rooms: Dictionary = config.get("rooms", {})
	for variant: Variant in (rooms.get(room_type, []) as Array):
		if typeof(variant) == TYPE_DICTIONARY and String((variant as Dictionary).get("id", "")) == wave_id:
			return variant
	return {}


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value))


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))


# ---- Shipped config ----

## The validated shipped config, or {} when missing or invalid (push_error, never a crash; `is_valid()` tells).
static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_load_problems = ["could not open " + PATH]
		push_error("RunConfig: " + _load_problems[0])
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_load_problems = [PATH + " is not a JSON object"]
		push_error("RunConfig: " + _load_problems[0])
		return _cache
	var problems: Array[String] = validate(parsed, EnemyConfig.enemy_ids(), _card_ids())
	if not problems.is_empty():
		_load_problems = problems
		push_error("RunConfig: invalid %s: %s" % [PATH, "; ".join(problems)])
		return _cache
	_cache = (parsed as Dictionary).duplicate(true)
	return _cache


static func is_valid() -> bool:
	return not get_config().is_empty()


static func load_problems() -> Array[String]:
	get_config()
	return _load_problems


static func _card_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: Variant in CardDatabase.all_cards():
		ids.append(String((card as Dictionary)["id"]))
	return ids


## A character's 15-card starter (data/characters.json). Defaults to the Rogue's, so callers that do not care
## which class is playing keep working; a run uses `RunSession.character_id`.
static func starting_deck(character_id: String = CharacterDatabase.DEFAULT_ID) -> Array[String]:
	return CharacterDatabase.starting_deck(character_id)


static func rejects_per_run() -> int:
	return int(get_config().get("rejects_per_run", 3))


static func rest_heal_fraction() -> float:
	return float(get_config().get("rest_heal_fraction", 0.3))


## The pools a character draws cards from (data/characters.json); the Rogue's by default.
static func character_pools(character_id: String = CharacterDatabase.DEFAULT_ID) -> Array[String]:
	return CharacterDatabase.pools(character_id)


static func rewards() -> Dictionary:
	return get_config().get("rewards", {})


static func offer_size() -> int:
	return int(rewards().get("offer_size", 3))


## True when a won room of this type is followed by a card reward (the last room never is; the caller checks that).
static func rewards_after(room_type: String) -> bool:
	return (rewards().get("reward_room_types", []) as Array).has(room_type)


## Every card id in the given pools, sorted: the `--full-deck` debug deck and the reward candidate list.
static func cards_in_pools(pool_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for pool_id: Variant in pool_ids:
		for card: Variant in CardDatabase.cards_for_pool(String(pool_id)):
			var id: String = String((card as Dictionary)["id"])
			if not out.has(id):
				out.append(id)
	out.sort()
	return out


static func tier(tier_id: String) -> Dictionary:
	return (get_config().get("tiers", {}) as Dictionary).get(tier_id, {})


static func ui() -> Dictionary:
	return get_config().get("ui", {})


## Test hook: drop the cache so the next call re-reads the file.
static func reset_cache() -> void:
	_cache = {}
	_loaded = false
	_load_problems = []
