class_name VfxConfig
extends RefCounted
## data/vfx.json: tuning for the pooled effect system. Missing or invalid values
## fall back to DEFAULTS (with a push_error for invalid ones, never a crash).

const PATH := "res://data/vfx.json"
const DEFAULTS: Dictionary = {
	"max_simultaneous": 64,
	"hurtbox_reach_radius": 0.45,
	"hurtbox_low_center_height": 0.45,
	"enemy_shot_lane_alpha": 0.3,
	"player_hurtbox_reach_radius": 0.4,
	"player_hurtbox_low_center_height": 0.4,
	"heal_color": "#7dff9a",
	"buff_color": "#ffd24a",
	"projectile_lane_alpha": 0.2,
	"projectile_lane_duration": 0.3,
	"dash_path_alpha": 0.28,
	"dash_path_duration": 0.3,
	"dash_path_half_width": 0.25,
	"team_tints": {"enemy": {"color": "#ff3d8b", "neutral_mix": 1.0, "element_mix": 0.4}},
}

## Ground marker tuning (4c): alpha 0..1, durations in seconds, half width in meters.
const MARKER_KEYS: Array[String] = ["enemy_shot_lane_alpha", "projectile_lane_alpha", "projectile_lane_duration",
		"dash_path_alpha", "dash_path_duration", "dash_path_half_width"]

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Returns human-readable problems; empty means valid.
static func validate(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var cap: Variant = config.get("max_simultaneous")
	if typeof(cap) != TYPE_INT and typeof(cap) != TYPE_FLOAT:
		errors.append("'max_simultaneous' must be a number")
	elif float(cap) < 1.0 or float(cap) > 512.0 or float(cap) != floorf(float(cap)):
		errors.append("'max_simultaneous' must be a whole number from 1 to 512")
	var reach: Variant = config.get("hurtbox_reach_radius")
	if typeof(reach) != TYPE_INT and typeof(reach) != TYPE_FLOAT:
		errors.append("'hurtbox_reach_radius' must be a number")
	elif float(reach) < 0.0 or float(reach) > 5.0:
		errors.append("'hurtbox_reach_radius' must be between 0 and 5")
	if config.has("hurtbox_low_center_height"):  # optional: DEFAULTS fill it in
		var low: Variant = config["hurtbox_low_center_height"]
		if typeof(low) != TYPE_INT and typeof(low) != TYPE_FLOAT:
			errors.append("'hurtbox_low_center_height' must be a number")
		elif is_nan(float(low)) or float(low) < 0.0 or float(low) > 5.0:
			errors.append("'hurtbox_low_center_height' must be between 0 and 5")
	for key: String in ["player_hurtbox_reach_radius", "player_hurtbox_low_center_height"]:
		if config.has(key):  # optional: DEFAULTS fill them in
			var value: Variant = config[key]
			if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or is_nan(float(value)) or float(value) < 0.0 or float(value) > 5.0:
				errors.append("'%s' must be a number between 0 and 5" % key)
	for key: String in ["heal_color", "buff_color"]:
		if config.has(key) and not (typeof(config[key]) == TYPE_STRING and String(config[key]).is_valid_html_color()):
			errors.append("'%s' must be a hex color like #7dff9a" % key)
	errors.append_array(validate_team_tints(config.get("team_tints", {})))
	for key: String in MARKER_KEYS:
		if not config.has(key):
			continue  # optional: DEFAULTS fill it in
		var value: Variant = config[key]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			errors.append("'%s' must be a number" % key)
		elif is_nan(float(value)) or float(value) <= 0.0:
			errors.append("'%s' must be > 0" % key)
		elif key.ends_with("_alpha") and float(value) > 1.0:
			errors.append("'%s' must be <= 1" % key)
	return errors


## Team tints: team name -> {color: hex, neutral_mix: 0..1, element_mix: 0..1}. The mix is how far a
## shot or wedge of that team is pulled toward the tint (neutral/physical vs elemental looks).
static func validate_team_tints(tints: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(tints) != TYPE_DICTIONARY:
		errors.append("'team_tints' must be an object (team -> {color, neutral_mix, element_mix})")
		return errors
	for team: Variant in (tints as Dictionary).keys():
		var entry: Variant = (tints as Dictionary)[team]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("team_tints.%s must be an object" % str(team))
			continue
		var dict: Dictionary = entry
		if typeof(dict.get("color")) != TYPE_STRING or not String(dict["color"]).is_valid_html_color():
			errors.append("team_tints.%s.color must be a hex color like #ff3d8b" % str(team))
		for key: String in ["neutral_mix", "element_mix"]:
			var value: Variant = dict.get(key)
			if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or is_nan(float(value)) or float(value) < 0.0 or float(value) > 1.0:
				errors.append("team_tints.%s.%s must be a number from 0 to 1" % [str(team), key])
	return errors


static func get_config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = DEFAULTS.duplicate()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("VfxConfig: could not open " + PATH)
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("VfxConfig: %s is not a JSON object" % PATH)
		return _cache
	var errors := validate(parsed)
	if not errors.is_empty():
		push_error("VfxConfig: invalid %s: %s" % [PATH, "; ".join(errors)])
		return _cache
	_cache.merge(parsed, true)
	return _cache


## How far past a hit query's range a target's centre can still be hit: the
## target hurtbox radius (MeleeChaser capsule, 0.45). See VfxSizing.
static func hurtbox_reach_radius() -> float:
	return float(get_config()["hurtbox_reach_radius"])


## Height of the lowest sphere centre of the target capsule above the floor.
static func hurtbox_low_center_height() -> float:
	return float(get_config()["hurtbox_low_center_height"])


## The tint for a team's shots and wedges, or an empty dictionary for a team with none (the player).
static func team_tint(team: String) -> Dictionary:
	var tints: Dictionary = get_config()["team_tints"]
	return tints.get(team, {})


## The player's own hurtbox capsule (Player.tscn), for enemy attack shapes drawn against the player.
static func player_hurtbox_reach_radius() -> float:
	return float(get_config()["player_hurtbox_reach_radius"])


static func player_hurtbox_low_center_height() -> float:
	return float(get_config()["player_hurtbox_low_center_height"])


static func max_simultaneous() -> int:
	return int(get_config()["max_simultaneous"])


## Template colors that no element owns (heal, buff). From data/vfx.json.
static func heal_color() -> Color:
	return Color.html(String(get_config()["heal_color"]))


static func buff_color() -> Color:
	return Color.html(String(get_config()["buff_color"]))


## Cast ground marker numbers (data/vfx.json), see TemplateVfx.projectile_lane / dash_path.
static func marker(key: String) -> float:
	return float(get_config()[key])

