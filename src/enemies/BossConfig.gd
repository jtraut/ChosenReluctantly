class_name BossConfig
extends RefCounted
## data/bosses.json (Milestone 3c): the boss fight as data. Per boss id (a key of data/enemies.json "enemies" whose
## rank is "boss"): name, HP, the resistance it has to every element, how much knockback it takes, the phase list with
## HP thresholds, the attack table and the transition and death-beat numbers. Pure loader and validator: `validate`
## takes plain data so tests feed it anything. A missing or invalid file is a push_error and no boss exists.
##
## Attack kinds (all built from the shared shapes, telegraphed for at least rules.min_telegraph):
##   cone    range, half_angle_degrees                          a wedge in front of the boss
##   aoe     radius, place ("self" | "target")                  a ground disc, on the boss or on where the player stood
##   volley  count, spread_degrees, speed, shot_range, hit_radius   a fan of projectile lanes
##   charge  distance, speed, hit_radius                        a run along a locked lane, boss not solid meanwhile
## Every attack also has: label, windup, recover, damage, damage_type, knockback, min_range, max_range (the distance to
## the player it may be picked at), shake, shake_duration, hit_stop.

const PATH := "res://data/bosses.json"
const KINDS: Array[String] = ["cone", "aoe", "volley", "charge"]
const COMMON_ATTACK_KEYS: Array[String] = ["kind", "label", "windup", "recover", "damage", "damage_type", "knockback", "min_range", "max_range", "shake", "shake_duration", "hit_stop"]
## Kind-specific keys (all required for their kind).
const KIND_KEYS: Dictionary = {
	"cone": ["range", "half_angle_degrees"],
	"aoe": ["radius", "place"],
	"volley": ["count", "spread_degrees", "speed", "shot_range", "hit_radius"],
	"charge": ["distance", "speed", "hit_radius"],
}
const PLACES: Array[String] = ["self", "target"]
const RULE_KEYS: Array[String] = ["min_telegraph", "max_transition", "max_adds_cap", "min_attacks"]
const BOSS_KEYS: Array[String] = ["display_name", "max_health", "resistance", "armor", "knockback_taken", "body_radius", "max_adds_alive", "spawn_grace", "transition", "death", "attacks", "phases"]
const TRANSITION_KEYS: Array[String] = ["duration", "shake", "shake_duration", "hit_stop", "ring_size"]
const DEATH_KEYS: Array[String] = ["beat_seconds", "slow_mo_scale", "shake", "shake_duration"]
const PHASE_KEYS: Array[String] = ["name", "enters_at", "move_speed", "attack_gap", "windup_scale", "attacks", "summon"]

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _problems: Array[String] = []


## Human-readable problems; empty means valid. `known_enemies` (enemy ids) skips the id checks when empty.
static func validate(config: Dictionary, known_enemies: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var rules: Dictionary = {}
	if typeof(config.get("rules")) != TYPE_DICTIONARY:
		errors.append("'rules' must be an object")
	else:
		rules = config["rules"]
		for key: Variant in rules.keys():
			if not RULE_KEYS.has(String(key)):
				errors.append("rules: unknown key '%s'" % str(key))
		_num(rules, "min_telegraph", 0.6, 10.0, "rules", errors)
		_num(rules, "max_transition", 0.1, 1.5, "rules", errors)
		_whole(rules, "max_adds_cap", 0, 10, "rules", errors)
		_whole(rules, "min_attacks", 3, 20, "rules", errors)
	if typeof(config.get("bosses")) != TYPE_DICTIONARY or (config["bosses"] as Dictionary).is_empty():
		errors.append("'bosses' must be a non-empty object (boss id -> definition)")
		return errors
	if not errors.is_empty():
		return errors  # the per-boss checks lean on the rules
	for boss_id: Variant in (config["bosses"] as Dictionary).keys():
		var id: String = String(boss_id)
		if not known_enemies.is_empty() and not known_enemies.has(id):
			errors.append("bosses.%s: not an enemy id in data/enemies.json" % id)
		var def: Variant = (config["bosses"] as Dictionary)[boss_id]
		if typeof(def) != TYPE_DICTIONARY:
			errors.append("bosses.%s must be an object" % id)
			continue
		errors.append_array(_validate_boss(id, def, rules, known_enemies))
	return errors


static func _validate_boss(id: String, def: Dictionary, rules: Dictionary, known_enemies: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var where: String = "bosses." + id
	for key: Variant in def.keys():
		if not BOSS_KEYS.has(String(key)):
			errors.append("%s: unknown key '%s'" % [where, str(key)])
	if typeof(def.get("display_name")) != TYPE_STRING or String(def["display_name"]).strip_edges().is_empty():
		errors.append("%s.display_name must be a non-empty string" % where)
	_num(def, "max_health", 1.0, 100000.0, where, errors)
	_num(def, "resistance", 0.0, 0.5, where, errors)  # GDD section 7: a resistance caps at 50%
	_num(def, "armor", 0.0, 1000.0, where, errors)  # required; GDD section 7 Armor (final boss 50 = 50% at K 50)
	if _is_num(def.get("armor")) and _is_num(def.get("resistance")):
		errors.append_array(ArmorConfig.parity_errors(where, float(def["armor"]), float(def["resistance"]), ArmorConfig.k(), ArmorConfig.PARITY_TOLERANCE))
	_num(def, "knockback_taken", 0.0, 1.0, where, errors)
	_num(def, "body_radius", 0.1, 5.0, where, errors)
	_whole(def, "max_adds_alive", 0, int(rules.get("max_adds_cap", 6)), where, errors)
	_num(def, "spawn_grace", 0.0, 10.0, where, errors)
	errors.append_array(_validate_block(where + ".transition", def.get("transition"), TRANSITION_KEYS, {
		"duration": [0.1, float(rules.get("max_transition", 1.5))], "shake": [0.0, 5.0], "shake_duration": [0.0, 5.0], "hit_stop": [0.0, 1.0], "ring_size": [0.5, 30.0]}))
	errors.append_array(_validate_block(where + ".death", def.get("death"), DEATH_KEYS, {
		"beat_seconds": [0.2, 5.0], "slow_mo_scale": [0.05, 1.0], "shake": [0.0, 5.0], "shake_duration": [0.0, 5.0]}))
	var attack_ids: Array[String] = []
	if typeof(def.get("attacks")) != TYPE_DICTIONARY:
		errors.append("%s.attacks must be an object (attack id -> definition)" % where)
	else:
		var attacks: Dictionary = def["attacks"]
		if attacks.size() < int(rules.get("min_attacks", 3)):
			errors.append("%s needs at least %d attacks" % [where, int(rules.get("min_attacks", 3))])
		for attack_id: Variant in attacks.keys():
			attack_ids.append(String(attack_id))
			if typeof(attacks[attack_id]) != TYPE_DICTIONARY:
				errors.append("%s.attacks.%s must be an object" % [where, str(attack_id)])
				continue
			errors.append_array(validate_attack("%s.attacks.%s" % [where, str(attack_id)], attacks[attack_id], float(rules.get("min_telegraph", 0.6))))
	errors.append_array(_validate_phases(where, def, attack_ids, rules, known_enemies))
	return errors


## One attack definition.
static func validate_attack(where: String, attack: Dictionary, min_telegraph: float) -> Array[String]:
	var errors: Array[String] = []
	var kind: String = String(attack.get("kind", "")) if typeof(attack.get("kind")) == TYPE_STRING else ""
	if not KINDS.has(kind):
		errors.append("%s.kind must be one of %s" % [where, str(KINDS)])
		return errors
	var allowed: Array[String] = COMMON_ATTACK_KEYS.duplicate()
	for kind_key: Variant in (KIND_KEYS[kind] as Array):
		allowed.append(String(kind_key))
	for key: Variant in attack.keys():
		if not allowed.has(String(key)):
			errors.append("%s: unknown key '%s' for a %s attack" % [where, str(key), kind])
	if typeof(attack.get("label")) != TYPE_STRING or String(attack["label"]).strip_edges().is_empty():
		errors.append("%s.label must be a non-empty string" % where)
	if typeof(attack.get("damage_type")) != TYPE_STRING or String(attack["damage_type"]).is_empty():
		errors.append("%s.damage_type must be a non-empty string" % where)
	_num(attack, "windup", min_telegraph, 10.0, where, errors)
	_num(attack, "recover", 0.0, 10.0, where, errors)
	_num(attack, "damage", 0.0, 1000.0, where, errors)
	_num(attack, "knockback", 0.0, 50.0, where, errors)
	_num(attack, "min_range", 0.0, 60.0, where, errors)
	_num(attack, "max_range", 0.1, 60.0, where, errors)
	_num(attack, "shake", 0.0, 5.0, where, errors)
	_num(attack, "shake_duration", 0.0, 5.0, where, errors)
	_num(attack, "hit_stop", 0.0, 1.0, where, errors)
	if _is_num(attack.get("min_range")) and _is_num(attack.get("max_range")) and float(attack["min_range"]) >= float(attack["max_range"]):
		errors.append("%s.min_range must be below max_range" % where)
	match kind:
		"cone":
			_num(attack, "range", 0.1, 30.0, where, errors)
			_num(attack, "half_angle_degrees", 1.0, 180.0, where, errors)
		"aoe":
			_num(attack, "radius", 0.1, 30.0, where, errors)
			if typeof(attack.get("place")) != TYPE_STRING or not PLACES.has(String(attack["place"])):
				errors.append("%s.place must be one of %s" % [where, str(PLACES)])
		"volley":
			_whole(attack, "count", 1, 15, where, errors)
			_num(attack, "spread_degrees", 0.0, 180.0, where, errors)
			_num(attack, "speed", 0.5, 60.0, where, errors)
			_num(attack, "shot_range", 1.0, 100.0, where, errors)
			_num(attack, "hit_radius", 0.05, 3.0, where, errors)
		"charge":
			_num(attack, "distance", 1.0, 40.0, where, errors)
			_num(attack, "speed", 1.0, 60.0, where, errors)
			_num(attack, "hit_radius", 0.1, 4.0, where, errors)
	return errors


static func _validate_phases(where: String, def: Dictionary, attack_ids: Array[String], rules: Dictionary, known_enemies: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var phases: Variant = def.get("phases")
	if typeof(phases) != TYPE_ARRAY or (phases as Array).size() < 2:
		errors.append("%s.phases must be an array of at least 2 phases" % where)
		return errors
	var previous: float = 2.0
	var min_telegraph: float = float(rules.get("min_telegraph", 0.6))
	var attacks: Dictionary = def.get("attacks", {}) if typeof(def.get("attacks")) == TYPE_DICTIONARY else {}
	var adds_cap: int = int(def.get("max_adds_alive", 0)) if _is_num(def.get("max_adds_alive")) else 0
	for index in range((phases as Array).size()):
		var phase_where: String = "%s.phases[%d]" % [where, index]
		var phase: Variant = (phases as Array)[index]
		if typeof(phase) != TYPE_DICTIONARY:
			errors.append("%s must be an object" % phase_where)
			continue
		var p: Dictionary = phase
		for key: Variant in p.keys():
			if not PHASE_KEYS.has(String(key)):
				errors.append("%s: unknown key '%s'" % [phase_where, str(key)])
		if typeof(p.get("name")) != TYPE_STRING or String(p["name"]).strip_edges().is_empty():
			errors.append("%s.name must be a non-empty string" % phase_where)
		_num(p, "enters_at", 0.0, 1.0, phase_where, errors)
		if _is_num(p.get("enters_at")):
			var enters: float = float(p["enters_at"])
			if index == 0 and not is_equal_approx(enters, 1.0):
				errors.append("%s.enters_at must be 1.0 for the first phase" % phase_where)
			if enters <= 0.0 or enters >= previous:
				errors.append("%s.enters_at must be above 0 and below the previous phase's (%s)" % [phase_where, str(previous)])
			if enters < previous:
				previous = enters
		_num(p, "move_speed", 0.0, 30.0, phase_where, errors)
		_num(p, "attack_gap", 0.0, 30.0, phase_where, errors)
		_num(p, "windup_scale", 0.1, 3.0, phase_where, errors)
		var attack_list: Variant = p.get("attacks")
		if typeof(attack_list) != TYPE_ARRAY or (attack_list as Array).is_empty():
			errors.append("%s.attacks must be a non-empty array of {id, weight}" % phase_where)
		else:
			for entry: Variant in (attack_list as Array):
				if typeof(entry) != TYPE_DICTIONARY or typeof((entry as Dictionary).get("id")) != TYPE_STRING:
					errors.append("%s.attacks entries must be {id, weight}" % phase_where)
					continue
				var e: Dictionary = entry
				for key: Variant in e.keys():
					if String(key) != "id" and String(key) != "weight":
						errors.append("%s.attacks: unknown key '%s'" % [phase_where, str(key)])
				if not attack_ids.has(String(e["id"])):
					errors.append("%s.attacks: unknown attack id '%s'" % [phase_where, String(e["id"])])
					continue
				_num(e, "weight", 0.0, 1000.0, phase_where + ".attacks." + String(e["id"]), errors)
				if _is_num(p.get("windup_scale")) and _is_num((attacks[String(e["id"])] as Dictionary).get("windup")):
					var effective: float = float((attacks[String(e["id"])] as Dictionary)["windup"]) * float(p["windup_scale"])
					if effective < min_telegraph - 0.0001:
						errors.append("%s: attack '%s' telegraphs %.2f s in this phase, under the %.2f s minimum" % [phase_where, String(e["id"]), effective, min_telegraph])
			if _total_weight(attack_list as Array) <= 0.0:
				errors.append("%s.attacks: the weights add up to 0" % phase_where)
		if p.has("summon"):
			var summon: Variant = p["summon"]
			if typeof(summon) != TYPE_DICTIONARY:
				errors.append("%s.summon must be {enemy, count}" % phase_where)
			else:
				var s: Dictionary = summon
				for key: Variant in s.keys():
					if String(key) != "enemy" and String(key) != "count":
						errors.append("%s.summon: unknown key '%s'" % [phase_where, str(key)])
				if typeof(s.get("enemy")) != TYPE_STRING or (not known_enemies.is_empty() and not known_enemies.has(String(s["enemy"]))):
					errors.append("%s.summon.enemy must be a known enemy id" % phase_where)
				_whole(s, "count", 1, 10, phase_where + ".summon", errors)
				if _is_num(s.get("count")) and int(s["count"]) > adds_cap:
					errors.append("%s.summon.count %d is above max_adds_alive %d" % [phase_where, int(s["count"]), adds_cap])
	return errors


static func _total_weight(list: Array) -> float:
	var total: float = 0.0
	for entry: Variant in list:
		if typeof(entry) == TYPE_DICTIONARY and _is_num((entry as Dictionary).get("weight")):
			total += float((entry as Dictionary)["weight"])
	return total


static func _validate_block(where: String, block: Variant, keys: Array[String], ranges: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if typeof(block) != TYPE_DICTIONARY:
		errors.append("%s must be an object" % where)
		return errors
	for key: Variant in (block as Dictionary).keys():
		if not keys.has(String(key)):
			errors.append("%s: unknown key '%s'" % [where, str(key)])
	for key: String in keys:
		var pair: Array = ranges[key]
		_num(block, key, float(pair[0]), float(pair[1]), where, errors)
	return errors


static func _is_num(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


static func _num(dict: Dictionary, key: String, low: float, high: float, where: String, errors: Array[String]) -> void:
	var value: Variant = dict.get(key)
	if not _is_num(value):
		errors.append("%s.%s must be a number" % [where, key])
	elif float(value) < low or float(value) > high:
		errors.append("%s.%s must be between %s and %s" % [where, key, str(low), str(high)])


static func _whole(dict: Dictionary, key: String, low: int, high: int, where: String, errors: Array[String]) -> void:
	var value: Variant = dict.get(key)
	if not _is_num(value) or float(value) != floorf(float(value)):
		errors.append("%s.%s must be a whole number" % [where, key])
	elif int(value) < low or int(value) > high:
		errors.append("%s.%s must be between %d and %d" % [where, key, low, high])


# ---- Loading ----

static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = {}
	_problems = []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_problems.append("could not open " + PATH)
		push_error("BossConfig: could not open " + PATH)
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_problems.append("%s is not a JSON object" % PATH)
		push_error("BossConfig: %s is not a JSON object" % PATH)
		return _cache
	_problems = validate(parsed, EnemyConfig.enemy_ids())
	if not _problems.is_empty():
		push_error("BossConfig: invalid %s: %s" % [PATH, "; ".join(_problems)])
		return _cache
	_cache = parsed
	return _cache


static func load_problems() -> Array[String]:
	get_config()
	return _problems


static func reset_cache() -> void:
	_cache = {}
	_loaded = false
	_problems = []


## True when `enemy_id` has a boss definition (the enemy is a boss).
static func has_boss(enemy_id: String) -> bool:
	return get_config().has("bosses") and ((get_config()["bosses"] as Dictionary).has(enemy_id))


## The (read-only by convention) definition of a boss, or {} if there is none.
static func boss(enemy_id: String) -> Dictionary:
	if not has_boss(enemy_id):
		return {}
	return (get_config()["bosses"] as Dictionary)[enemy_id]


static func rules() -> Dictionary:
	return get_config().get("rules", {})


static func boss_ids() -> Array[String]:
	var ids: Array[String] = []
	if get_config().has("bosses"):
		for key: Variant in (get_config()["bosses"] as Dictionary).keys():
			ids.append(String(key))
	return ids
