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
	"cone_duration": 0.45,
	"cone_alpha": 0.6,
	"cone_blade_duration": 0.22,
	"cone_blade_alpha": 1.0,
	"cone_enemy_duration_scale": 0.55,
	"heal_sparkle_size": 0.14,
	"heal_sparkle_duration": 0.9,
	"heal_sparkle_rise": 1.6,
	"heal_ring_radius": 1.0,
	"heal_ring_alpha": 0.85,
	"heal_ring_duration": 0.6,
	"dash_trail_size": 0.4,
	"dash_trail_duration": 0.4,
	"dash_trail_alpha": 0.7,
	"dash_trail_lighten": 0.35,
	"projectile_trail_duration": 0.35,
	"projectile_trail_alpha": 0.8,
	"projectile_trail_scale": 1.0,
	"projectile_muzzle_scale": 1.6,
	"projectile_muzzle_alpha": 1.0,
	"windup_cancel_size": 0.9,
	"windup_cancel_duration": 0.3,
	"windup_cancel_alpha": 0.9,
	"ghost_body_alpha": 0.45,
	"ghost_ring_radius": 0.85,
	"ghost_ring_alpha": 0.7,
	"ghost_ring_pulse": 0.12,
	"ghost_ring_hz": 1.6,
	"ghost_color": "#b9c8ff",
	"heal_number_interval": 0.25,
	"heal_number_offset_x": 0.7,
	"drain_pulse_duration": 0.28,
	"drain_pulse_size": 0.17,
	"drain_pulse_alpha": 0.95,
	"drain_min_interval": 0.1,
	"drain_color": "#c64bd9",
	"bleed_drop_duration": 0.5,
	"bleed_drop_fall": 1.1,
	"bleed_drop_alpha": 0.95,
	"heal_mote_duration": 0.7,
	"heal_mote_rise": 1.1,
	"heal_mote_size": 0.1,
	"reticle_range_alpha": 0.35,
	"reticle_range_thickness": 0.05,
	"reticle_marker_size": 0.45,
	"reticle_marker_alpha": 0.9,
	"dash_arrow_length": 1.0,
	"dash_arrow_half_width": 0.55,
	"team_tints": {"enemy": {"color": "#ff3d8b", "neutral_mix": 1.0, "element_mix": 0.4}},
}

## Ground marker tuning (4c): alpha 0..1, durations in seconds, half width in meters.
const MARKER_KEYS: Array[String] = ["enemy_shot_lane_alpha", "projectile_lane_alpha", "projectile_lane_duration",
		"dash_path_alpha", "dash_path_duration", "dash_path_half_width",
		"cone_duration", "cone_alpha", "cone_blade_duration", "cone_blade_alpha", "cone_enemy_duration_scale",
		"heal_sparkle_size", "heal_sparkle_duration", "heal_sparkle_rise", "heal_ring_radius", "heal_ring_alpha", "heal_ring_duration",
		"dash_trail_size", "dash_trail_duration", "dash_trail_alpha", "dash_trail_lighten",
		"projectile_trail_duration", "projectile_trail_alpha", "projectile_trail_scale", "projectile_muzzle_scale", "projectile_muzzle_alpha",
		"windup_cancel_size", "windup_cancel_duration", "windup_cancel_alpha",
		"ghost_body_alpha", "ghost_ring_radius", "ghost_ring_alpha", "ghost_ring_pulse", "ghost_ring_hz",
		"heal_number_interval", "heal_number_offset_x", "drain_pulse_duration", "drain_pulse_size", "drain_pulse_alpha", "drain_min_interval",
		"bleed_drop_duration", "bleed_drop_fall", "bleed_drop_alpha", "heal_mote_duration", "heal_mote_rise", "heal_mote_size",
		"reticle_range_alpha", "reticle_range_thickness", "reticle_marker_size", "reticle_marker_alpha", "dash_arrow_length", "dash_arrow_half_width"]
## Colours of the cues that no element owns (hex strings).
const COLOR_KEYS: Array[String] = ["heal_color", "buff_color", "ghost_color", "drain_color"]

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
	for key: String in COLOR_KEYS:
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
		elif (key.ends_with("_alpha") or key == "dash_trail_lighten" or key == "cone_enemy_duration_scale") and float(value) > 1.0:
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


## Any of the COLOR_KEYS as a Color.
static func color_of(key: String) -> Color:
	return Color.html(String(get_config()[key]))


## Cast visual tuning numbers (data/vfx.json): ground markers (TemplateVfx.projectile_lane / dash_path)
## and the cone, heal, dash and projectile reads (alpha 0..1, durations in seconds, sizes in meters).
static func marker(key: String) -> float:
	return float(get_config()[key])

