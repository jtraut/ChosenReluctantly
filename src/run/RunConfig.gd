class_name RunConfig
extends RefCounted
## data/run.json: the shape of a run (Milestone 3a). Room mix and placement rules, the finite wave lists per
## room type, elite and boss tier stats, rest healing, the reject allowance, the starting deck and the
## placeholder run UI text. Pure loader and validator: `validate` takes plain data so tests feed it anything.
## Run code reads cards only as ids; the deck list is checked against the card database and the deck rules.

const PATH := "res://data/run.json"
const ROOM_TYPES: Array[String] = ["combat", "elite", "rest", "boss"]
## Room types that fight (they need a wave list); `rest` has none.
## MAP3-B: the act-end mini-boss is a fight with its own wave lists (`rooms.mini_boss`) and tier, but no `composition` entry: only a map makes one.
const FIGHT_TYPES: Array[String] = ["combat", "elite", "boss", "mini_boss"]
## The relic room (BD2-B) is added by RunGenerator when relics are on; it is not a composition key. No fight, like rest.
const RELIC_ROOM := "relic_room"
## The merchant node of a map run (MAP2-B): no fight either. Only the map makes one, so it is not in ALL_ROOM_TYPES.
const MERCHANT_ROOM := "merchant"
## Every room type a generated run can hold (ROOM_TYPES plus the relic room).
const ALL_ROOM_TYPES: Array[String] = ["combat", "elite", "rest", "boss", "relic_room"]
const TIER_IDS: Array[String] = ["elite", "boss"]
## Tiers that may be left out of a config (fixtures from before MAP3-B): `mini_boss` is checked like the others when present.
const OPTIONAL_TIER_IDS: Array[String] = ["mini_boss"]
## data/run.json `acts`: per-act enemy HP and damage multipliers and a gold multiplier ({"1": {...}, "2": {...}}); absent = every act is x1.
const ACT_SCALE_KEYS: Array[String] = ["hp", "damage", "gold"]
## BD3a (D45 = B): `acts.start_heal` is the fraction of max HP healed at the start of act 2 and later (0 = none, the MAP3 behaviour; a missing key reads 0).
const ACT_START_HEAL_KEY := "start_heal"

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
	errors.append_array(_validate_gold(config.get("gold")))
	errors.append_array(MerchantConfig.validate_block(config.get("merchant")))
	errors.append_array(_validate_tiers(config.get("tiers")))
	if config.has("acts"):
		errors.append_array(_validate_act_scale(config["acts"]))
	errors.append_array(_validate_rooms(config, known_enemies, total))
	errors.append_array(_validate_ui(config.get("ui")))
	errors.append_array(RelicConfig.validate_block(config.get("relics")))
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
	# BD3a (D43 = B): the offer lean. Both optional: absent reads as off (0) and a cap of 3.
	if r.has("status_lean") and (not _is_number(r["status_lean"]) or float(r["status_lean"]) < 0.0 or float(r["status_lean"]) > 10.0):
		errors.append("rewards.status_lean must be a number in [0, 10] (0 turns the lean off)")
	if r.has("status_lean_max") and (not _is_number(r["status_lean_max"]) or float(r["status_lean_max"]) < 1.0 or float(r["status_lean_max"]) > 100.0):
		errors.append("rewards.status_lean_max must be a number in [1, 100]")
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


## MAP1-B `gold`: {fight node type: [low, high]} paid when a fight node is won (a map run only; the boss pays nothing). Required, but may be empty.
static func _validate_gold(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("'gold' must be an object {node type: [low, high]}")
		return errors
	for key: Variant in (value as Dictionary).keys():
		var entry: Variant = (value as Dictionary)[key]
		if not ["combat", "elite", "mini_boss"].has(String(key)):
			errors.append("gold: '%s' is not a fight node type that pays gold (combat, elite, mini_boss)" % str(key))
		elif typeof(entry) != TYPE_ARRAY or (entry as Array).size() != 2 or not _is_whole((entry as Array)[0]) or not _is_whole((entry as Array)[1]) 				or int((entry as Array)[0]) < 0 or int((entry as Array)[0]) > int((entry as Array)[1]) or int((entry as Array)[1]) > 9999:
			errors.append("gold.%s must be [low, high], whole numbers with 0 <= low <= high <= 9999" % str(key))
	return errors


## MAP1-B `ui.map`: the strings the pick-next-node screen reads. Optional as a block (a straight-run fixture needs none), but every part is checked when present.
static func _validate_map_text(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if value == null:
		return errors
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("ui.map must be an object")
		return errors
	var m: Dictionary = value
	for key: String in ["title", "line", "gold_label", "gold_format", "gold_earned", "start_hint"]:
		if typeof(m.get(key)) != TYPE_STRING:
			errors.append("ui.map.%s must be a string" % key)
	for key: String in ["gold_format", "gold_earned"]:
		if typeof(m.get(key)) == TYPE_STRING and String(m[key]).count("%d") != 1:
			errors.append("ui.map.%s must be a format string with one %%d" % key)
	var chest_names: Variant = m.get("chest_names")
	var chest_notes: Variant = m.get("chest_notes")
	for size_id: String in MapConfig.CHEST_SIZES:
		if typeof(chest_names) != TYPE_DICTIONARY or typeof((chest_names as Dictionary).get(size_id)) != TYPE_STRING:
			errors.append("ui.map.chest_names.%s must be a string" % size_id)
		if typeof(chest_notes) != TYPE_DICTIONARY or typeof((chest_notes as Dictionary).get(size_id)) != TYPE_STRING:
			errors.append("ui.map.chest_notes.%s must be a string" % size_id)
	var hover: Variant = m.get("hover")
	var hover_ids: Array[String] = MapConfig.NODE_TYPES.duplicate()
	hover_ids.append(MapConfig.BOSS)
	for type_id: String in hover_ids:
		if typeof(hover) != TYPE_DICTIONARY or typeof((hover as Dictionary).get(type_id)) != TYPE_STRING:
			errors.append("ui.map.hover.%s must be a string" % type_id)
	return errors


static func _validate_tiers(tiers: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(tiers) != TYPE_DICTIONARY:
		errors.append("'tiers' must be an object {elite, boss}")
		return errors
	var checked: Array[String] = TIER_IDS.duplicate()
	for optional_id: String in OPTIONAL_TIER_IDS:
		if (tiers as Dictionary).has(optional_id):
			checked.append(optional_id)
	for tier_id: String in checked:
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


static func _validate_act_scale(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("'acts' must be an object {act number: {hp, damage, gold}}")
		return errors
	for key: Variant in (value as Dictionary).keys():
		var entry: Variant = (value as Dictionary)[key]
		if String(key) == ACT_START_HEAL_KEY:
			if not _is_number(entry) or is_nan(float(entry)) or float(entry) < 0.0 or float(entry) > 1.0:
				errors.append("acts.%s must be a number from 0 to 1 (the fraction of max HP healed when act 2 and later begin)" % ACT_START_HEAL_KEY)
			continue
		if not String(key).is_valid_int() or str(String(key).to_int()) != String(key) or String(key).to_int() < 1 or String(key).to_int() > RunState.MAX_ACTS:
			errors.append("acts: '%s' must be an act number from 1 to %d" % [str(key), RunState.MAX_ACTS])
		elif typeof(entry) != TYPE_DICTIONARY:
			errors.append("acts.%s must be an object {hp, damage, gold}" % str(key))
		else:
			for scale_key: Variant in (entry as Dictionary).keys():
				if not ACT_SCALE_KEYS.has(String(scale_key)):
					errors.append("acts.%s: unknown key '%s'" % [str(key), str(scale_key)])
			for scale_key: String in ACT_SCALE_KEYS:
				var multiplier: Variant = (entry as Dictionary).get(scale_key)
				if not _is_number(multiplier) or float(multiplier) < 0.1 or float(multiplier) > 20.0:
					errors.append("acts.%s.%s must be a number in [0.1, 20]" % [str(key), scale_key])
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
			if v.has("acts"):
				var act_list: Variant = v["acts"]
				var acts_ok: bool = typeof(act_list) == TYPE_ARRAY and not (act_list as Array).is_empty()
				if acts_ok:
					for act_value: Variant in (act_list as Array):
						if not _is_whole(act_value) or int(act_value) < 1 or int(act_value) > RunState.MAX_ACTS:
							acts_ok = false
				if not acts_ok:
					errors.append("%s: 'acts' must be a non-empty list of act numbers from 1 to %d" % [label, RunState.MAX_ACTS])
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


## Every room position of a type must have at least one wave list that allows its index. MAP3-B: that holds in every act a type has lists for.
## The mini-boss has no `composition` entry (only a map makes one), so its lists are checked for the last room of the act, like the boss.
static func _validate_variant_coverage(config: Dictionary, total: int) -> Array[String]:
	var errors: Array[String] = []
	if total < 1 or typeof(config.get("rooms")) != TYPE_DICTIONARY or typeof(config.get("composition")) != TYPE_DICTIONARY:
		return errors
	for room_type: String in FIGHT_TYPES:
		var variants: Variant = (config["rooms"] as Dictionary).get(room_type)
		var wanted: Variant = (config["composition"] as Dictionary).get(room_type, 0)
		if typeof(variants) != TYPE_ARRAY or ((not _is_whole(wanted) or int(wanted) <= 0) and room_type != "mini_boss"):
			continue
		var only_last: bool = room_type == "mini_boss" or room_type == "boss"
		for act_number in lists_acts(variants as Array):
			for index in range(total - 1 if only_last else 0, total):
				if variants_for(index, variants as Array, act_number).is_empty():
					errors.append("rooms.%s: no act %d wave list allows room index %d" % [room_type, act_number, index])
					break
	return errors


## The acts that `variants` has at least one wave list for.
static func lists_acts(variants: Array) -> Array[int]:
	var found: Array[int] = []
	for variant: Variant in variants:
		if typeof(variant) == TYPE_DICTIONARY:
			for act_value: Variant in _acts_of(variant as Dictionary):
				if not found.has(int(act_value)):
					found.append(int(act_value))
	found.sort()
	return found


## The acts a wave list is for: its `acts` list, else [1] (a list without the field is an act 1 list, so today's lists keep their act).
static func _acts_of(variant: Dictionary) -> Array[int]:
	var found: Array[int] = []
	var listed: Variant = variant.get("acts")
	if typeof(listed) != TYPE_ARRAY:
		found.append(1)
		return found
	for act_value: Variant in (listed as Array):  # JSON numbers are floats: compare as whole numbers
		found.append(int(act_value))
	return found


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
	errors.append_array(_validate_relic_text(u.get("relic")))
	errors.append_array(_validate_map_text(u.get("map")))
	errors.append_array(_validate_merchant_text(u.get("merchant")))
	errors.append_array(_validate_effect_text(u.get("effect")))
	if typeof(u.get("next_line")) != TYPE_STRING or String(u["next_line"]).count("%d") != 2 or String(u["next_line"]).count("%s") != 1:
		errors.append("ui.next_line must be a format string with two %d and one %s")
	return errors


## ui.merchant strings the merchant choices need (MAP2-B). Required: a merchant node is reachable the moment the map holds one.
const MERCHANT_TEXT_KEYS: Array[String] = ["title", "line", "item_format", "removal_format", "removal_detail", "reroll_label", "reroll_detail", "leave_label", "leave_detail", "back_label", "remove_title", "remove_line"]
const MERCHANT_REASON_CODES: Array[String] = ["sold", "too_expensive", "not_for_sale", "none_removable", "removal_blocked", "no_rerolls"]


static func _validate_merchant_text(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("ui.merchant must be an object")
		return errors
	var m: Dictionary = value
	for key: String in MERCHANT_TEXT_KEYS:
		if typeof(m.get(key)) != TYPE_STRING:
			errors.append("ui.merchant.%s must be a string" % key)
	for key: String in ["line", "removal_format", "removal_detail", "reroll_detail", "remove_line"]:
		if typeof(m.get(key)) == TYPE_STRING and String(m[key]).count("%d") != 1:
			errors.append("ui.merchant.%s must be a format string with one %%d" % key)
	if typeof(m.get("item_format")) == TYPE_STRING and (String(m["item_format"]).count("%s") != 1 or String(m["item_format"]).count("%d") != 1):
		errors.append("ui.merchant.item_format must be a format string with one %s and one %d")
	var reasons: Variant = m.get("reasons")
	if typeof(reasons) != TYPE_DICTIONARY:
		errors.append("ui.merchant.reasons must be an object {reason code: text}")
	else:
		for code: String in MERCHANT_REASON_CODES:
			if typeof((reasons as Dictionary).get(code)) != TYPE_STRING:
				errors.append("ui.merchant.reasons.%s must be a string" % code)
	return errors


## ui.relic strings the relic choices need (BD2-B).
const RELIC_TEXT_KEYS: Array[String] = ["title", "line", "room_title", "room_line", "skip_label", "skip_detail", "swap_title", "swap_line", "cancel_label", "none_giveable", "label", "owned_title", "none_owned"]


static func _validate_relic_text(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("ui.relic must be an object")
		return errors
	var r: Dictionary = value
	for key: String in RELIC_TEXT_KEYS:
		if typeof(r.get(key)) != TYPE_STRING:
			errors.append("ui.relic.%s must be a string" % key)
	if typeof(r.get("swap_line")) == TYPE_STRING and (String(r["swap_line"]).count("%d") != 1 or String(r["swap_line"]).count("%s") != 1):
		errors.append("ui.relic.swap_line must be a format string with one %d and one %s")
	# The singular text for a cap of 1 is optional (RunRelics falls back to swap_line), but when present it takes the same two arguments.
	if r.has("swap_line_one") and (typeof(r["swap_line_one"]) != TYPE_STRING or String(r["swap_line_one"]).count("%d") != 1 or String(r["swap_line_one"]).count("%s") != 1):
		errors.append("ui.relic.swap_line_one must be a format string with one %d and one %s")
	var tiers: Variant = r.get("tier_names")
	if typeof(tiers) != TYPE_DICTIONARY:
		errors.append("ui.relic.tier_names must be an object")
	else:
		for tier: String in RelicSchema.RARITIES:
			if typeof((tiers as Dictionary).get(tier)) != TYPE_STRING:
				errors.append("ui.relic.tier_names.%s must be a string" % tier)
	return errors


## ui.effect strings the synergy text needs (BD1): condition wording, the primed-buff wording and the buff stat sentences.
const EFFECT_TEXT_GROUPS: Dictionary = {
	"condition": ["target_has_status", "cast_within_slot", "cast_within_tag", "zone_active"],
	"buff_stats": ["slot_cooldown_skip", "status_damage_mult"],
}


static func _validate_effect_text(effect: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(effect) != TYPE_DICTIONARY:
		errors.append("ui.effect must be an object")
		return errors
	var e: Dictionary = effect
	for key: String in ["condition_line", "within"]:
		if typeof(e.get(key)) != TYPE_STRING:
			errors.append("ui.effect.%s must be a string" % key)
	for group: String in EFFECT_TEXT_GROUPS:
		if typeof(e.get(group)) != TYPE_DICTIONARY:
			errors.append("ui.effect.%s must be an object" % group)
			continue
		for key: String in (EFFECT_TEXT_GROUPS[group] as Array):
			if typeof((e[group] as Dictionary).get(key)) != TYPE_STRING:
				errors.append("ui.effect.%s.%s must be a string" % [group, key])
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


## The wave lists that allow room `index` (min_index/max_index are inclusive) in act `act` (a list's `acts`, default [1]).
static func variants_for(index: int, variants: Array, act: int = 1) -> Array:
	var out: Array = []
	for variant: Variant in variants:
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = variant
		if index < int(v.get("min_index", 0)) or index > int(v.get("max_index", 9999)):
			continue
		if not _acts_of(v).has(act):
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


## MAP1-B: the gold ranges {node type: [low, high]} (empty when the file has none).
static func gold() -> Dictionary:
	return get_config().get("gold", {})


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


## The enemy and gold multipliers of act `act` ({hp, damage, gold}); x1 for an act the file does not list (and for every act when it has no `acts`).
static func act_scale(act: int) -> Dictionary:
	var entry: Variant = (get_config().get("acts", {}) as Dictionary).get(str(act))
	if typeof(entry) != TYPE_DICTIONARY:
		return {"hp": 1.0, "damage": 1.0, "gold": 1.0}
	return {"hp": float(entry["hp"]), "damage": float(entry["damage"]), "gold": float(entry["gold"])}


## The fraction of max HP the player recovers at the start of act 2 and each later act (D45 = B), 0 to 1; 0 when the file has none.
static func act_start_heal() -> float:
	var value: Variant = (get_config().get("acts", {}) as Dictionary).get(ACT_START_HEAL_KEY)
	if not _is_number(value):
		return 0.0
	return clampf(float(value), 0.0, 1.0)


static func tier(tier_id: String) -> Dictionary:
	return (get_config().get("tiers", {}) as Dictionary).get(tier_id, {})


static func ui() -> Dictionary:
	return get_config().get("ui", {})


## Test hook: drop the cache so the next call re-reads the file.
static func reset_cache() -> void:
	_cache = {}
	_loaded = false
	_load_problems = []
