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

static var _table := JsonDataTable.new("res://data/ui.json")


## The `hp_bars` block with defaults filled in (sub-dicts merged key by key).
static func hp_bars() -> Dictionary:
	return merge_with_defaults(DEFAULT_HP_BARS, _table.get_entry("hp_bars"))


static func merge_with_defaults(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	for key: Variant in overrides:
		if result.get(key) is Dictionary and overrides[key] is Dictionary:
			(result[key] as Dictionary).merge(overrides[key] as Dictionary, true)
		else:
			result[key] = overrides[key]
	return result
