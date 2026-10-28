class_name CastPreviewConfig
extends RefCounted
## data/cast_preview.json: how the held-key cast preview looks. Colour and alpha are data
## so ux-designer can restyle it without code. A missing or invalid file falls back to
## DEFAULTS with a push_error (never a crash).

const PATH := "res://data/cast_preview.json"
const DEFAULTS: Dictionary = {
	"enabled": true,
	"ground_offset": 0.04,
	"render_priority": -1,
	"fill_alpha": 0.14,
	"edge_alpha": 0.85,
	"edge_thickness": 0.09,
	"edge_lighten": 0.35,
	"default_color": "#f4ece8",
	"self_ring_enabled": true,
	"self_ring_radius": 0.9,
}
const BOOLS: Array[String] = ["enabled", "self_ring_enabled"]
const ALPHAS: Array[String] = ["fill_alpha", "edge_alpha", "edge_lighten"]

static var _cache: Dictionary = {}


static func get_config() -> Dictionary:
	if _cache.is_empty():
		_cache = load_from(PATH)
	return _cache


static func reload() -> void:
	_cache = {}


## Reads `path`; every problem is push_error'd and the defaults are used instead.
static func load_from(path: String) -> Dictionary:
	var text: Variant = SettingsStore.read_text_file(path)
	if text == null:
		push_error("CastPreviewConfig: could not open '%s'; using defaults" % path)
		return DEFAULTS.duplicate()
	var parsed: Variant = JSON.parse_string(String(text))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CastPreviewConfig: '%s' is not a JSON object; using defaults" % path)
		return DEFAULTS.duplicate()
	var merged: Dictionary = DEFAULTS.duplicate()
	merged.merge(parsed, true)
	var problems := validate(merged)
	if not problems.is_empty():
		push_error("CastPreviewConfig: '%s' invalid: %s; using defaults" % [path, "; ".join(problems)])
		return DEFAULTS.duplicate()
	return merged


static func validate(block: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in DEFAULTS.keys():
		if not block.has(key):
			problems.append("%s is missing" % key)
	for key: String in BOOLS:
		if typeof(block.get(key)) != TYPE_BOOL:
			problems.append("%s must be true or false" % key)
	var color: Variant = block.get("default_color")
	if typeof(color) != TYPE_STRING or not String(color).is_valid_html_color():
		problems.append("default_color must be a hex color")
	for key: String in ["ground_offset", "fill_alpha", "edge_alpha", "edge_thickness", "edge_lighten", "self_ring_radius"]:
		var value: Variant = block.get(key)
		if not (value is float or value is int) or is_nan(float(value)) or float(value) < 0.0:
			problems.append("%s must be a number >= 0" % key)
	for key: String in ALPHAS:
		var value: Variant = block.get(key)
		if (value is float or value is int) and float(value) > 1.0:
			problems.append("%s must be <= 1" % key)
	if not (block.get("render_priority") is int or block.get("render_priority") is float):
		problems.append("render_priority must be a number")
	return problems
