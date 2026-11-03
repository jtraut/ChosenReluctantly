class_name PlayerConfig
extends RefCounted
## data/player.json: player tuning that is not a card or attack. Today the dodge roll.
## dodge.speed x dodge.duration is the roll distance in metres (20 x 0.25 = 5.0 m). A missing or
## invalid file push_errors and falls back to DEFAULTS (never a crash).

const PATH := "res://data/player.json"
const DEFAULTS: Dictionary = {
	"dodge": {"enabled": false, "speed": 20.0, "duration": 0.25, "cooldown": 1.2, "block_ticks_after_pause": 2, "charges": 3, "min_charges": 0, "max_charges": 4},
	"body": {"collide_with_enemies": true},
}
## body keys (all booleans). collide_with_enemies: player and enemy bodies block each other (both ways).
## false = bodies pass through each other, as before C1-c. A missing "body" block means the defaults.
const BODY_KEYS: Array[String] = ["collide_with_enemies"]
## key -> [min, max, must_be_integer]
const DODGE_RULES: Dictionary = {
	"speed": [0.1, 200.0, false],
	"duration": [0.02, 5.0, false],
	"cooldown": [0.0, 60.0, false],
	"block_ticks_after_pause": [0.0, 30.0, true],
	"charges": [0.0, 10.0, true],
	"min_charges": [0.0, 10.0, true],
	"max_charges": [0.0, 10.0, true],
}
## H2 dodge-off trial: dodge.enabled (boolean) is the one switch. false = the dodge never fires and its charges do not tick; all the
## dodge code and tuning stays. It is optional in a file (a missing value reads as DEFAULTS["dodge"]["enabled"], false), and the shipped
## file states it. Turning it on also needs a key for the "dodge" action in data/input_bindings.json (see InputBindings).
## The stat name a passive or piece of equipment modifies to change the dodge charge count.
const CHARGES_STAT := "dodge_charges"

static var _cache: Dictionary = {}


## The validated dodge block: speed, duration, cooldown (floats; cooldown is the recharge time of ONE charge),
## block_ticks_after_pause (int) and the charge counts charges (default base), min_charges and max_charges (the hard clamp).
static func dodge() -> Dictionary:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return _cache["dodge"]


## True when the dodge is in play (data/player.json dodge.enabled; shipped false in the H2 trial). Player, the sims and the HUD read this.
static func dodge_enabled() -> bool:
	return bool(dodge()["enabled"])


## Tests and sims only: flips the switch in the loaded cache without touching the file. reload() restores the file's value.
static func set_dodge_enabled(value: bool) -> void:
	dodge()["enabled"] = value


## True when the player and enemy bodies collide (data/player.json body.collide_with_enemies).
static func collide_with_enemies() -> bool:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return bool(_cache["body"]["collide_with_enemies"])


static func reload() -> void:
	_cache = {}


static func load_from(path: String) -> Dictionary:
	var text: Variant = SettingsStore.read_text_file(path)
	if text == null:
		push_error("PlayerConfig: could not open '%s'; using defaults" % path)
		return DEFAULTS.duplicate(true)
	var parsed: Variant = JSON.parse_string(String(text))
	var problems := validate(parsed)
	if not problems.is_empty():
		push_error("PlayerConfig: '%s' invalid: %s; using defaults" % [path, "; ".join(problems)])
		return DEFAULTS.duplicate(true)
	var loaded: Dictionary = (parsed as Dictionary).duplicate(true)
	if not (loaded["dodge"] as Dictionary).has("enabled"):
		(loaded["dodge"] as Dictionary)["enabled"] = bool((DEFAULTS["dodge"] as Dictionary)["enabled"])
	if not loaded.has("body"):
		loaded["body"] = (DEFAULTS["body"] as Dictionary).duplicate()
	return loaded


## Human-readable problems; empty means valid.
static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("not a JSON object")
		return errors
	var block: Variant = (data as Dictionary).get("dodge")
	if typeof(block) != TYPE_DICTIONARY:
		errors.append("'dodge' must be an object")
		return errors
	for key: String in DODGE_RULES.keys():
		var value: Variant = (block as Dictionary).get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			errors.append("dodge.%s must be a number" % key)
			continue
		var rule: Array = DODGE_RULES[key]
		var number: float = float(value)
		if is_nan(number) or is_inf(number) or number < float(rule[0]) or number > float(rule[1]):
			errors.append("dodge.%s must be between %s and %s" % [key, rule[0], rule[1]])
		elif bool(rule[2]) and number != floorf(number):
			errors.append("dodge.%s must be a whole number" % key)
	if errors.is_empty():
		var low: int = int((block as Dictionary)["min_charges"])
		var high: int = int((block as Dictionary)["max_charges"])
		var base: int = int((block as Dictionary)["charges"])
		if low > high:
			errors.append("dodge.min_charges must not exceed dodge.max_charges")
		elif base < low or base > high:
			errors.append("dodge.charges must be between dodge.min_charges and dodge.max_charges")
	if (block as Dictionary).has("enabled") and typeof((block as Dictionary)["enabled"]) != TYPE_BOOL:
		errors.append("dodge.enabled must be true or false")
	for key: Variant in (block as Dictionary).keys():
		if String(key) != "enabled" and not DODGE_RULES.has(String(key)):
			errors.append("dodge.%s is not a known key" % key)
	if (data as Dictionary).has("body"):
		var body: Variant = (data as Dictionary)["body"]
		if typeof(body) != TYPE_DICTIONARY:
			errors.append("'body' must be an object")
		else:
			for key: String in BODY_KEYS:
				if typeof((body as Dictionary).get(key)) != TYPE_BOOL:
					errors.append("body.%s must be true or false" % key)
			for key: Variant in (body as Dictionary).keys():
				if not BODY_KEYS.has(String(key)):
					errors.append("body.%s is not a known key" % key)
	return errors
