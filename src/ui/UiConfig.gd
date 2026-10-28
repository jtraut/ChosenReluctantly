class_name UiConfig
extends RefCounted
## data/ui.json: UI tuning values. Missing keys fall back to DEFAULT_HP_BARS so
## a partial or absent file never breaks the HUD.

const DEFAULT_HP_BARS: Dictionary = {
	"visibility_mode": "always_alive",
	"width": 1.4,
	"height": 0.19,
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

static var _table := JsonDataTable.new("res://data/ui.json")


## The `hp_bars` block with defaults filled in (sub-dicts merged key by key).
static func hp_bars() -> Dictionary:
	return merge_with_defaults(DEFAULT_HP_BARS, _table.get_entry("hp_bars"))


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
