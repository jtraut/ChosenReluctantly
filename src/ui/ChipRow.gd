class_name ChipRow
extends Control
## A row of tag chips (BD1): keywords (Keystone, Primer, Payoff) first as filled light chips, then derived tags
## (Projectile, Burn, ...) as outlined chips. Fill versus outline carries the difference as well as the colour. Up to
## `max_count` chips; a chip that does not fit the width is dropped (from the end, so keywords always win) rather than
## clipped. Pure display: the owner calls `show_chips`. Used by the HUD slots, the reward offers and the removal grid.

var _cfg: Dictionary = {}
var _font_size: int = 12
var _pad: float = 4.0
var _gap: float = 3.0
var _max_count: int = 3
var _keywords_only: bool = false
var _side_margin: float = 0.0
var _centered: bool = true
var _chips: Array[Dictionary] = []
var _source: Array[String] = []
var _source_keywords: Array[String] = []


## Which chips fit: [{text, keyword, width}] in order, at most `max_count`, dropping from the end until the row fits
## `max_width`. The first chip is always kept (a lone chip that is too wide is better than none). Pure.
static func fit(texts: Array[String], keyword_flags: Array[bool], font: Font, font_size: int, max_width: float, max_count: int, pad: float, gap: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used: float = 0.0
	for i in range(mini(texts.size(), max_count)):
		var width: float = font.get_string_size(texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + 2.0 * pad
		var needed: float = width + (gap if not result.is_empty() else 0.0)
		if not result.is_empty() and used + needed > max_width:
			break
		used += needed
		result.append({"text": texts[i], "keyword": keyword_flags[i], "width": width})
	return result


## Splits a SlotSynergy chip list into display texts and keyword flags (keywords show their display name).
static func texts_for(chips: Array, keywords_only: bool = false) -> Dictionary:
	var texts: Array[String] = []
	var flags: Array[bool] = []
	for chip: Variant in chips:
		var tag: String = String(chip)
		var is_keyword: bool = KeywordDatabase.has(tag)
		if keywords_only and not is_keyword:
			continue
		texts.append(KeywordDatabase.display_name(tag) if is_keyword else tag)
		flags.append(is_keyword)
	return {"texts": texts, "flags": flags}


## `px` values are already scaled. `cfg` is the data/ui.json hud block (colours and counts).
func configure(cfg: Dictionary, font_px: int, height_px: float, pad_px: float, gap_px: float, width_px: float, max_count: int, keywords_only: bool = false, side_margin_px: float = 0.0, centered: bool = true) -> void:
	_cfg = cfg
	_font_size = font_px
	_pad = pad_px
	_gap = gap_px
	_max_count = max_count
	_keywords_only = keywords_only
	_side_margin = side_margin_px
	_centered = centered
	custom_minimum_size = Vector2(width_px, height_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refit()


## Sets the chips to show (a SlotSynergy `chips` array: keywords first, then tags).
func show_chips(chips: Array) -> void:
	var as_strings: Array[String] = []
	for chip: Variant in chips:
		as_strings.append(String(chip))
	if as_strings == _source:
		return
	_source = as_strings
	_refit()


## Chips as drawn now: [{text, keyword, width}] (tests).
func shown() -> Array[Dictionary]:
	return _chips


func _refit() -> void:
	if _cfg.is_empty():
		return
	var parts: Dictionary = texts_for(_source, _keywords_only)
	_chips = fit(parts["texts"], parts["flags"], get_theme_default_font(), _font_size, custom_minimum_size.x - 2.0 * _side_margin, _max_count, _pad, _gap)
	queue_redraw()


func _draw() -> void:
	if _cfg.is_empty() or _chips.is_empty():
		return
	var font: Font = get_theme_default_font()
	var h: float = custom_minimum_size.y
	var total: float = _gap * float(_chips.size() - 1)
	for chip: Dictionary in _chips:
		total += float(chip["width"])
	var x: float = maxf((custom_minimum_size.x - total) * 0.5, 0.0) if _centered else 0.0  # centred under a slot name; left-aligned on a card
	var line: float = maxf(1.0, roundf(h / 12.0))
	var baseline: float = (h + font.get_ascent(_font_size) - font.get_descent(_font_size)) * 0.5
	for chip: Dictionary in _chips:
		var rect := Rect2(x, 0.0, float(chip["width"]), h)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(maxi(2, roundi(h * 0.22)))
		var text_color: Color
		if bool(chip["keyword"]):
			box.bg_color = Color.html(String(_cfg["chip_keyword_color"]))
			text_color = Color.html(String(_cfg["chip_keyword_text_color"]))
		else:
			box.bg_color = Color(0.05, 0.03, 0.04, 0.55)
			box.border_color = Color.html(String(_cfg["chip_tag_border_color"]))
			box.set_border_width_all(int(line))
			text_color = Color.html(String(_cfg["chip_tag_text_color"]))
		draw_style_box(box, rect)
		draw_string(font, Vector2(x + _pad, baseline), String(chip["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, text_color)
		x += float(chip["width"]) + _gap
