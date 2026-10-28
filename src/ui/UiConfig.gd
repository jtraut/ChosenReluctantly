class_name UiConfig
extends RefCounted
## data/ui.json: UI tuning values. Missing keys fall back to DEFAULT_HP_BARS so
## a partial or absent file never breaks the HUD.

## Every valid `hp_bars.visibility_mode`. Lives here (not in EnemyHpBar) so a `-s` tool that reaches
## UiConfig does not compile EnemyHpBar -> Enemy -> the Juice autoload (S5-1). EnemyHpBar.MODES points here.
const HP_BAR_MODES: Array[String] = ["always_alive", "after_damage", "hidden_at_full", "elite_boss_always"]

const DEFAULT_HP_BARS: Dictionary = {
	"visibility_mode": "always_alive",
	"width": 1.2,
	"height": 0.16,
	"render_priority": 10,
	"border": 0.02,
	"resist_border": 0.04,
	"y_offset": 2.35,
	"ghost_enabled": true,
	"ghost_delay": 0.35,
	"ghost_drain_per_sec": 1.5,
	"burn_status_id": "burn",
	"colors": {
		"fill": "#e2483f",
		"ghost": "#ffd7a8",
		"back": "#1c1218",
		"frame": "#0d080b",
		"burn": "#ff9a1f",
	},
	"default_resistance_tint": "#cfd8dc",
	"resistance_tints": {"fire": "#ff8a3d", "water": "#4aa8ff"},
}

## Player death beat: slow_mo_scale in (0, 1], durations in real seconds > 0.
const DEFAULT_DEATH_BEAT: Dictionary = {
	"slow_mo_scale": 0.25,
	"slow_mo_duration": 0.9,
	"collapse_duration": 0.5,
}

## Ground aim indicator (reticle at the mouse point, fading dots along the
## facing direction). Sizes in world meters. Quiet on purpose: low alpha, below
## every attack/telegraph shape (see AimIndicator).
const DEFAULT_AIM: Dictionary = {
	"enabled": true,
	"color": "#f4ece8",
	"ground_offset": 0.03,
	"reticle_radius": 0.38,
	"reticle_alpha": 0.55,
	"center_dot_radius": 0.07,
	"dot_count": 8,
	"dot_radius": 0.06,
	"dot_spacing": 0.7,
	"dot_start_gap": 0.9,
	"dot_alpha_near": 0.5,
	"dot_alpha_far": 0.12,
	"max_length": 6.0,
}

## Game Over screen text and sizes. Font sizes and button_min_size are in pixels
## at `reference_height` and are scaled with the window height.
const DEFAULT_GAME_OVER: Dictionary = {
	"title": "Well. That went badly.",
	"line": "The world is still cheerful about it. You are not.",
	"button": "Try again",
	"hint": "Enter or Space",
	"reference_height": 720,
	"title_font_size": 56,
	"line_font_size": 24,
	"button_font_size": 40,
	"hint_font_size": 18,
	"button_min_size": [360, 90],
	"backdrop_color": "#0d080bcc",
	"title_color": "#ffd7a8",
	"line_color": "#e8dfe3",
}

## Bottom/top HUD layout. Sizes are pixels at `reference_height`, scaled by
## window height (same rule as Game Over). Heights are fixed so slots never shift.
const DEFAULT_HUD: Dictionary = {
	"reference_height": 720,
	"safe_margin": 16,
	"fit_padding": 2,
	"slot_size": [150, 118],
	"slot_gap": 12,
	"slot_row_separation": 2,
	"key_font_size": 13,
	"key_height": 20,
	"name_font_size": 15,
	"name_min_font_size": 11,
	"name_max_lines": 2,
	"name_height": 48,
	"bar_height": 10,
	"preview_font_size": 11,
	"preview_min_font_size": 10,
	"preview_max_lines": 2,
	"preview_height": 34,
	"flavor_min_font_size": 11,
	"flavor_max_lines": 3,
	"flavor_box_width": 260,
	"name_warn_length": 25,
	"health_size": [220, 48],
	"hp_label_font_size": 16,
	"hp_label_height": 22,
	"hp_bar_height": 22,
	"hp_fill_color": "#e2483f",
	"hp_back_color": "#1c1218",
	"hp_border_color": "#f4ece8",
	"hp_text_color": "#ffffff",
	"hp_text_outline_color": "#0d080b",
	"slot_cooling_dim": 0.7,
	"slot_ready_border_color": "#f4ece8",
	"slot_ready_border_width": 2,
	"slot_cooling_bar_color": "#8fa3b8",
	"slot_ready_bar_color": "#8fe388",
	"slot_bar_back_color": "#1c1218",
	"meter_top_gap": 8,
	"meter_row_gap": 4,
	"light_meter_size": [220, 12],
	"heavy_meter_size": [220, 22],
	"meter_label_width": 38,
	"meter_font_size": 12,
	"meter_light_alpha": 0.6,
	"meter_pulse_duration": 0.4,
	"light_meter_color": "#ffe27a",
	"heavy_meter_color": "#ff5a2a",
	"meter_back_color": "#1c1218",
	"meter_border_color": "#f4ece8",
	"meter_text_color": "#ffffff",
	"meter_text_outline_color": "#0d080b",
}

## Small floating words (not damage numbers). The "IMMUNE" popup when a stun bounces.
const DEFAULT_POPUPS: Dictionary = {
	"immune_text": "IMMUNE",
	"immune_color": "#cfd8dc",
	"immune_scale": 0.9,
	"immune_height": 3.3,
	"immune_cooldown": 1.5,
}

## Floating damage numbers (and the popup words that reuse the same label). Sizes: `pixel_size` is
## meters per font pixel, so a number's on-screen size follows the ortho camera (about 51 px per
## meter at 720p). Anti-spam: a new same-type hit within `merge_radius` (m, on the ground plane) of a
## number that has been idle less than `merge_window` (s) adds into it, and at most `max_alive` live.
const DEFAULT_DAMAGE_NUMBERS: Dictionary = {
	"font_size": 48,
	"pixel_size": 0.011,
	"outline_size": 14,
	"outline_color": "#0d080b",
	"color_lighten": 0.3,
	"spawn_height": 1.9,
	"rise_distance": 1.2,
	"duration": 0.8,
	"big_scale": 1.35,
	"merge_radius": 0.8,
	"merge_window": 0.3,
	"max_alive": 16,
	"render_priority": 20,
}

static var _table := JsonDataTable.new("res://data/ui.json")


## The `hp_bars` block with defaults filled in (sub-dicts merged key by key).
static func hp_bars() -> Dictionary:
	var merged := merge_with_defaults(DEFAULT_HP_BARS, _table.get_entry("hp_bars"))
	var problems := validate_hp_bars(merged)
	if problems.is_empty():
		return merged
	push_error("data/ui.json hp_bars invalid: " + "; ".join(problems))
	merged["visibility_mode"] = DEFAULT_HP_BARS["visibility_mode"]
	return merged


## Every key of DEFAULT_HP_BARS is checked (S5-2), so a typo in data/ui.json fails loud.
static func validate_hp_bars(block: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var mode: Variant = block.get("visibility_mode")
	if typeof(mode) != TYPE_STRING or not HP_BAR_MODES.has(String(mode)):
		problems.append("visibility_mode must be one of %s" % str(HP_BAR_MODES))
	for key: String in ["width", "height", "ghost_drain_per_sec"]:
		if not _is_number(block.get(key)) or float(block[key]) <= 0.0:
			problems.append("%s must be a number > 0" % key)
	for key: String in ["border", "resist_border", "y_offset", "ghost_delay"]:
		if not _is_number(block.get(key)) or float(block[key]) < 0.0:
			problems.append("%s must be a number >= 0" % key)
	var priority: Variant = block.get("render_priority")
	if typeof(priority) != TYPE_INT and not (typeof(priority) == TYPE_FLOAT and not is_nan(float(priority)) and float(priority) == floorf(float(priority))):
		problems.append("render_priority must be a whole number")
	elif float(priority) < -127.0 or float(priority) > 126.0:
		problems.append("render_priority must be in [-127, 126] (the IMMUNE word adds 1)")
	if typeof(block.get("ghost_enabled")) != TYPE_BOOL:
		problems.append("ghost_enabled must be true or false")
	var burn_id: Variant = block.get("burn_status_id")
	if typeof(burn_id) != TYPE_STRING or String(burn_id).strip_edges().is_empty():
		problems.append("burn_status_id must be a non-empty string")
	var tint: Variant = block.get("default_resistance_tint")
	if typeof(tint) != TYPE_STRING or not String(tint).is_valid_html_color():
		problems.append("default_resistance_tint must be a hex color")
	problems.append_array(_validate_color_map(block.get("colors"), "colors", DEFAULT_HP_BARS["colors"] as Dictionary))
	problems.append_array(_validate_color_map(block.get("resistance_tints"), "resistance_tints", {}))
	return problems


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value))


## A dictionary of name -> hex color; every key in `required` must be present.
static func _validate_color_map(value: Variant, label: String, required: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		problems.append("%s must be an object of hex colors" % label)
		return problems
	var map: Dictionary = value
	for key: Variant in required:
		if not map.has(key):
			problems.append("%s.%s is missing" % [label, str(key)])
	for key: Variant in map:
		if typeof(map[key]) != TYPE_STRING or not String(map[key]).is_valid_html_color():
			problems.append("%s.%s must be a hex color" % [label, str(key)])
	return problems


## The `death_beat` block, defaults filled in. Invalid values are reported with
## push_error and replaced by the default, so bad data fails loudly but safely.
static func death_beat() -> Dictionary:
	var merged := merge_with_defaults(DEFAULT_DEATH_BEAT, _table.get_entry("death_beat"))
	var problems := validate_death_beat(merged)
	if problems.is_empty():
		return merged
	push_error("data/ui.json death_beat invalid: " + "; ".join(problems))
	return DEFAULT_DEATH_BEAT.duplicate()


static func aim() -> Dictionary:
	var merged := merge_with_defaults(DEFAULT_AIM, _table.get_entry("aim"))
	var problems := validate_aim(merged)
	if problems.is_empty():
		return merged
	push_error("data/ui.json aim invalid: " + "; ".join(problems))
	return DEFAULT_AIM.duplicate()


static func validate_aim(block: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if typeof(block.get("enabled")) != TYPE_BOOL:
		problems.append("enabled must be true or false")
	var color: Variant = block.get("color")
	if typeof(color) != TYPE_STRING or not String(color).is_valid_html_color():
		problems.append("color must be a hex color")
	for key: String in DEFAULT_AIM:
		if key == "enabled" or key == "color":
			continue
		var value: Variant = block.get(key)
		if not (value is float or value is int) or is_nan(float(value)):
			problems.append("%s must be a number" % key)
		elif float(value) < 0.0:
			problems.append("%s must be >= 0" % key)
		elif key.ends_with("alpha") or key.contains("alpha_"):
			if float(value) > 1.0:
				problems.append("%s must be <= 1" % key)
	if block.get("dot_count") is float or block.get("dot_count") is int:
		if float(block["dot_count"]) > 32.0:
			problems.append("dot_count must be <= 32")
	return problems


static func popups() -> Dictionary:
	var merged := merge_with_defaults(DEFAULT_POPUPS, _table.get_entry("popups"))
	var problems := validate_popups(merged)
	if problems.is_empty():
		return merged
	push_error("data/ui.json popups invalid: " + "; ".join(problems))
	return DEFAULT_POPUPS.duplicate()


static func validate_popups(block: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if typeof(block.get("immune_text")) != TYPE_STRING or String(block["immune_text"]).strip_edges().is_empty():
		problems.append("immune_text must be a non-empty string")
	if typeof(block.get("immune_color")) != TYPE_STRING or not String(block["immune_color"]).is_valid_html_color():
		problems.append("immune_color must be a hex color")
	for key: String in ["immune_scale", "immune_height", "immune_cooldown"]:
		var value: Variant = block.get(key)
		if not (value is float or value is int) or is_nan(float(value)) or float(value) < 0.0:
			problems.append("%s must be a number >= 0" % key)
	return problems


static func damage_numbers() -> Dictionary:
	var merged := merge_with_defaults(DEFAULT_DAMAGE_NUMBERS, _table.get_entry("damage_numbers"))
	var problems := validate_damage_numbers(merged)
	if problems.is_empty():
		return merged
	push_error("data/ui.json damage_numbers invalid: " + "; ".join(problems))
	return DEFAULT_DAMAGE_NUMBERS.duplicate()


static func validate_damage_numbers(block: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var color: Variant = block.get("outline_color")
	if typeof(color) != TYPE_STRING or not String(color).is_valid_html_color():
		problems.append("outline_color must be a hex color")
	for key: String in DEFAULT_DAMAGE_NUMBERS:
		if key == "outline_color":
			continue
		var value: Variant = block.get(key)
		if not (value is float or value is int) or is_nan(float(value)) or float(value) <= 0.0:
			problems.append("%s must be a number > 0" % key)
		elif key == "color_lighten" and float(value) > 1.0:
			problems.append("color_lighten must be <= 1")
	return problems


static func game_over() -> Dictionary:
	return merge_with_defaults(DEFAULT_GAME_OVER, _table.get_entry("game_over"))


static func hud() -> Dictionary:
	return merge_with_defaults(DEFAULT_HUD, _table.get_entry("hud"))


static func validate_death_beat(block: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in DEFAULT_DEATH_BEAT:
		var value: Variant = block.get(key)
		if not (value is float or value is int):
			problems.append("%s must be a number" % key)
			continue
		var number: float = value
		if is_nan(number) or number <= 0.0:
			problems.append("%s must be > 0" % key)
		elif key == "slow_mo_scale" and number > 1.0:
			problems.append("slow_mo_scale must be <= 1")
	return problems


static func merge_with_defaults(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	for key: Variant in overrides:
		if result.get(key) is Dictionary and overrides[key] is Dictionary:
			(result[key] as Dictionary).merge(overrides[key] as Dictionary, true)
		else:
			result[key] = overrides[key]
	return result
