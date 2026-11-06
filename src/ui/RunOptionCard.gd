class_name RunOptionCard
extends Button
## One option of a RunChoices model drawn as a card (Milestone 3b UX). Generic: it reads the option dict
## (see RunChoices) and never a card id. Five looks share one class so the highlight, disabled and reason
## rules are the same everywhere:
##   CARD    a reward card: number key, name, slot chip, effect line, flavor, "You own N", enter hint
##   REJECT  the reject tile: a different shape (narrow, dark, rose border, circle-slash glyph), cost and pips
##   ACTION  a rest-room choice (heal / remove a card) or any text option: title, detail, glyph
##   CELL    a compact removal-list cell: name and copy count, effect line, the deck-rule reason when greyed
##   BACK    a small footer button
##   RELIC   (BD2) a relic offer: square corners, a filled "Relic" band with a hexagon, the pool colour as the frame and an inner
##           line, so it cannot be mistaken for a card (rounded, one thick frame, a slot key chip)
##   RELIC_CELL  a compact relic for the give-one-up list: name, pool and tier, rule text
##   SKIP_FREE   the relic offer's Skip: no reject pips, a "Free" tag and an arrow, so it never reads as a cost
##   SHOP    (MAP2) a merchant tile: a band (relic: hexagon, tier, "Only sold here"; card: its slot key and slot), the name with a gold
##           price tag, the rule or effect line, and in words why it cannot be bought ("Need 15 more gold", "Sold"). Relics keep the square
##           double frame and cards the family frame, so a shop tile still tells its kind without colour.
## The button's own text stays empty: children draw the content (mouse ignored) and `_get_minimum_size` takes
## the height from them. The highlight is one state: keyboard focus, and hover moves focus here too.
## Not colour alone: the focus is a thick outline plus an "Enter to ..." line, disabled cards say why in words.

enum Look { CARD, REJECT, ACTION, CELL, BACK, RELIC, RELIC_CELL, SKIP_FREE, SHOP }

var option: Dictionary = {}
var look: Look = Look.CARD
var reason_label: Label = null
var title_label: Label = null
var hint_label: Label = null
var detail_label: Label = null
var flavor_label: Label = null
var owned_label: Label = null
var slot_chip: PanelContainer = null
var slot_now_label: Label = null
## BD1: tag chips (keywords first). CARD shows all of them; CELL (removal grid) shows keyword chips only, so a Keystone is
## recognised before it is thrown away. The keyword rules are in the tooltip (`keyword_rules_text`).
var chip_row: ChipRow = null
## The condition lines of the effect text ("If the target has Burn: ..."), apart from the plain effects.
var condition_label: Label = null
var number_badge: PanelContainer = null
## BD2 relic looks: the filled "Relic" band, the cap warning line, and the free-tag pill of the skip tile.
var relic_band: PanelContainer = null
var cap_note_label: Label = null
## BD1 carry-over: the note on a Movement-conditional card that the dodge does not count (D39 = A).
var dodge_note_label: Label = null
var free_tag: PanelContainer = null
## MAP2 shop tile parts (null on any other look): the price (or Sold / Free) tag, the band with the kind, and the "Only sold here" tag.
var price_tag: PanelContainer = null
var shop_band: Control = null
var shop_only_tag: PanelContainer = null

var _inner: VBoxContainer = null
var _width: float = 0.0
var _pad: float = 0.0
var _cfg: Dictionary = {}
var _scale: float = 1.0
var _pips: Control = null
var _rejects_remaining: int = 0
var _rejects_max: int = 0


## 1-based position of a slot type in the HUD order (used to order columns); 0 when unknown. NOT the key the
## player presses: that is InputLabels.slot_key().
static func slot_key_for(slot_type: String) -> int:
	return CardSlotController.SLOT_TYPE_ORDER.find(slot_type) + 1


## "You own 2" when the player already holds copies of the offered card, else "".
static func owned_text(count: int, format: String) -> String:
	return format % count if count > 0 else ""


## Card names contain commas, so the list is joined with a slash.
const SLOT_NOW_SEPARATOR: String = " / "


## "Utility (1) now: A / B / C": the distinct cards already held in the offered card's slot (data/run.json
## ui.option.slot_now, first %s = the slot's name and live key). "" when the slot holds nothing yet or is unknown.
static func slot_now_text(slot_type: String, names: Array, format: String) -> String:
	if slot_key_for(slot_type) <= 0 or names.is_empty():
		return ""
	var joined: PackedStringArray = PackedStringArray()
	for entry: Variant in names:
		joined.append(String(entry))
	# One %s: the chip above the line already names the slot and its key, so the line only lists the cards.
	if format.count("%s") < 2:
		return format % SLOT_NOW_SEPARATOR.join(joined)
	return format % [InputLabels.slot_label(slot_type), SLOT_NOW_SEPARATOR.join(joined)]


## Builds the card. `extra`: index (0-based, -1 = no number), owned (int), rejects_remaining, rejects_max, texts (run.json ui.option).
func setup(opt: Dictionary, the_look: Look, width: float, cfg: Dictionary, s: float, extra: Dictionary) -> void:
	option = opt
	look = the_look
	_cfg = cfg
	_scale = s
	_pad = float(cfg["option_pad"]) * s * (0.7 if (the_look == Look.CELL or the_look == Look.SHOP) else 1.0)
	_width = width * s
	_rejects_remaining = int(extra.get("rejects_remaining", 0))
	_rejects_max = int(extra.get("rejects_max", 0))
	var texts: Dictionary = extra.get("texts", {})
	var relic_texts: Dictionary = extra.get("relic_texts", {})
	var enabled: bool = bool(opt.get("enabled", true))
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	clip_text = false
	_apply_styles(enabled)
	_inner = VBoxContainer.new()
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_theme_constant_override("separation", roundi(4.0 * s))
	add_child(_inner)
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.offset_left = _pad
	_inner.offset_top = _pad
	_inner.offset_right = -_pad
	_inner.offset_bottom = -_pad
	var inner_width: float = _width - 2.0 * _pad
	var index: int = int(extra.get("index", -1))
	var title_color: Color = _text_color(enabled, Color.html("#ffffff"))
	var body_color: Color = _text_color(enabled, Color.html(String(cfg["prompt_text_color"])))
	var title_size: int = roundi(float(cfg["option_title_font_size"]) * s)
	var body_size: int = roundi(float(cfg["option_body_font_size"]) * s)
	var small_size: int = roundi(float(cfg["option_small_font_size"]) * s)

	if look == Look.SHOP:
		_build_shop(opt, extra, enabled, inner_width, [title_size, body_size, small_size])
		_connect_signals()
		return

	if look == Look.RELIC:
		relic_band = _relic_band(opt, relic_texts, small_size)
		_inner.add_child(relic_band)

	# Head row: number key (when numbered), name, copy count.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", roundi(8.0 * s))
	_inner.add_child(head)
	var glyph_room: float = 0.0
	if look == Look.ACTION or look == Look.REJECT or look == Look.SKIP_FREE or look == Look.RELIC_CELL:
		glyph_room = float(cfg["option_title_font_size"]) * 1.4 * s
	if index >= 0 and look != Look.BACK:  # callers pass -1 now; kept for a screen that wants a numbered list again
		number_badge = _badge(str(index + 1), small_size, enabled)
		head.add_child(number_badge)
	title_label = _label(String(opt.get("label", "")), title_size if look != Look.BACK else body_size, title_color, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size.x = inner_width - glyph_room - (float(small_size) * 2.2 if number_badge != null else 0.0) - (float(body_size) * 2.5 if look == Look.CELL else 0.0)
	if look == Look.CELL or look == Look.RELIC_CELL:
		title_label.add_theme_font_size_override("font_size", body_size)
	if look == Look.BACK:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if look == Look.REJECT:
		# The reject title is one line: it shrinks to fit (down to the small size) instead of wrapping into the glyph.
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var fit: Dictionary = TextFit.fit(title_label.text, title_label.get_theme_font("font"), title_label.custom_minimum_size.x, 1, title_size, small_size)
		title_label.text = String(fit["text"])
		title_label.add_theme_font_size_override("font_size", int(fit["font_size"]))
		title_label.clip_text = true
	head.add_child(title_label)
	if look == Look.CELL and int(opt.get("count", 0)) > 1:
		var copies := _label(String(texts.get("copies", "x%d")) % int(opt["count"]), body_size, _text_color(enabled, Color.html(String(cfg["option_accent_color"]))), false)
		head.add_child(copies)

	if look == Look.CARD:
		slot_chip = _slot_chip(opt, texts, small_size, enabled, body_color)
		if slot_chip != null:
			_inner.add_child(slot_chip)
	if look == Look.CARD or look == Look.CELL:
		chip_row = _chip_row(String(opt.get("card_id", "")), inner_width, enabled, small_size)
		if chip_row != null:
			_inner.add_child(chip_row)
	if look == Look.RELIC or look == Look.RELIC_CELL:
		_inner.add_child(_relic_pool_row(opt, relic_texts, small_size, body_color))
		if look == Look.RELIC:
			var keyword_chips: ChipRow = _relic_chips(opt, inner_width, small_size)
			if keyword_chips != null:
				chip_row = keyword_chips
				_inner.add_child(chip_row)
	var detail: String = keep_units(String(opt.get("detail", "")))
	var cell_blocked: bool = look == Look.CELL and not enabled and String(opt.get("reason", "")) != ""
	tooltip_text = String(opt.get("reason", ""))
	if look == Look.CELL:
		tooltip_text = detail if enabled else "%s
%s" % [detail, String(opt.get("reason", ""))]
	var rules: String = keyword_rules_text(String(opt.get("card_id", "")))
	if look == Look.RELIC_CELL:
		tooltip_text = detail + "\n" + String(opt.get("flavor", ""))
	if detail != "" and look != Look.BACK and not cell_blocked:  # a greyed list cell gives the room to its reason
		# BD1: CardSummary puts each condition on its own line after the plain effects; those lines wear the accent colour.
		var detail_lines: PackedStringArray = detail.split("
") if look in [Look.CARD, Look.CELL] else PackedStringArray([detail])
		detail_label = _label(detail_lines[0], small_size if (look == Look.CELL or look == Look.RELIC_CELL) else body_size, body_color, true)
		detail_label.custom_minimum_size.x = inner_width
		_inner.add_child(detail_label)
		if detail_lines.size() > 1:
			condition_label = _label("
".join(detail_lines.slice(1)), small_size if (look == Look.CELL or look == Look.RELIC_CELL) else body_size, _text_color(enabled, Color.html(String(cfg["option_accent_color"]))), true)
			condition_label.custom_minimum_size.x = inner_width
			_inner.add_child(condition_label)
	if look == Look.SKIP_FREE:
		free_tag = _free_tag(String(relic_texts.get("free_tag", "")), small_size)
		_inner.add_child(free_tag)
	if look == Look.REJECT:
		_pips = Control.new()
		_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.custom_minimum_size = Vector2(inner_width, 14.0 * s)
		_pips.draw.connect(_draw_pips)
		_inner.add_child(_pips)
	if look == Look.CARD:
		var now_text: String = slot_now_text(String(opt.get("slot_type", "")), opt.get("slot_contents", []), String(texts.get("slot_now", "%s now: %s")))
		if now_text != "":
			slot_now_label = _label(now_text, small_size, body_color, true)
			slot_now_label.custom_minimum_size.x = inner_width
			_inner.add_child(slot_now_label)
	if rules != "":  # The rule of each keyword is in the tooltip: a line per keyword made the reward cards too tall to fit at 1024x600.
		tooltip_text += ("
" if tooltip_text != "" else "") + rules
	var flavor: String = String(opt.get("flavor", ""))
	if flavor != "" and (look == Look.CARD or look == Look.RELIC):
		flavor_label = _label(flavor, small_size, _text_color(enabled, Color.html(String(cfg["option_flavor_color"]))), true)
		flavor_label.custom_minimum_size.x = inner_width
		_inner.add_child(flavor_label)
	if look == Look.RELIC and bool(opt.get("needs_swap", false)) and String(relic_texts.get("cap_note", "")) != "":
		cap_note_label = _label(String(relic_texts["cap_note"]), small_size, Color.html(String(cfg["option_warn_color"])), true)
		cap_note_label.custom_minimum_size.x = inner_width
		_inner.add_child(cap_note_label)
	if look == Look.CARD and ConditionCue.needs_dodge_note(CardDatabase.get_card(String(opt.get("card_id", ""))), texts.get("dodge_slots", []), PlayerConfig.dodge_counts_as_movement_cast()) and String(texts.get("dodge_hint", "")) != "":
		dodge_note_label = _label(String(texts["dodge_hint"]), small_size, _text_color(enabled, Color.html(String(cfg["option_flavor_color"]))), true)
		dodge_note_label.custom_minimum_size.x = inner_width
		_inner.add_child(dodge_note_label)
	if look == Look.CARD and int(extra.get("owned", 0)) > 0:
		owned_label = _label(owned_text(int(extra["owned"]), String(texts.get("owned", "You own %d"))), small_size, _text_color(enabled, Color.html(String(cfg["option_accent_color"]))), false)
		_inner.add_child(owned_label)
	var reason: String = String(opt.get("reason", ""))
	if not enabled and reason != "":
		reason_label = _label(String(texts.get("unavailable", "Unavailable: %s")) % reason, small_size, Color.html(String(cfg["option_warn_color"])), true)
		reason_label.custom_minimum_size.x = inner_width
		_inner.add_child(reason_label)
	if enabled and look in [Look.CARD, Look.ACTION, Look.REJECT, Look.RELIC, Look.RELIC_CELL, Look.SKIP_FREE]:
		var key: String = "pick_hint" if (look == Look.CARD) else ("remove_hint" if String(opt.get("kind", "")) == "remove" else "act_hint")
		var hint_text: String = String(texts.get(key, "Enter"))
		if look == Look.RELIC:
			hint_text = String(relic_texts.get("pick_hint", hint_text))
		elif look == Look.RELIC_CELL:
			hint_text = String(relic_texts.get("giveup_hint", hint_text))
		elif look == Look.SKIP_FREE:
			hint_text = String(relic_texts.get("skip_hint", hint_text))
		hint_label = _label(hint_text, small_size, Color.html(String(cfg["option_focus_color"])), false)
		hint_label.modulate.a = 0.0
		_inner.add_child(hint_label)
	_connect_signals()


func _connect_signals() -> void:
	_inner.minimum_size_changed.connect(_sync_min_size)  # wrapped labels settle after the first layout pass
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	mouse_entered.connect(_on_hover)
	_sync_min_size()


# --- MAP2: the merchant tile ------------------------------------------------------------------------------

## True for the shop's relic tiles (they wear the relic frame).
func _is_shop_relic() -> bool:
	return look == Look.SHOP and String(option.get("kind", "")) == "buy_relic"


## What a shop tile says about its price, as {text, mode}: mode "price" (buyable), "short" (too expensive), "sold" or "free". Pure, unit-tested.
## `gold` is what the player holds; `texts` is run.json ui.merchant.
static func shop_price_state(opt: Dictionary, gold: int, texts: Dictionary) -> Dictionary:
	var price: int = int(opt.get("price", 0))
	if bool(opt.get("sold", false)):
		return {"text": String(texts.get("sold_tag", "Sold")), "mode": "sold"}
	if String(opt.get("kind", "")) == "reroll":
		return {"text": String(texts.get("free_tag", "Free")), "mode": "free"}
	var text: String = String(texts.get("price_format", "%d")) % price
	if String(opt.get("reason_code", "")) == "too_expensive":
		return {"text": text, "mode": "short"}
	return {"text": text, "mode": "price"}


## The line under a shop tile's rule that says why it cannot be bought, "" when it can. "Need 15 more gold" beats "Not enough gold"; a sold tile
## needs no line (its tag says Sold); anything else is the reason from data.
static func shop_reason_line(opt: Dictionary, gold: int, texts: Dictionary) -> String:
	if bool(opt.get("enabled", true)) or bool(opt.get("sold", false)):
		return ""
	var code: String = String(opt.get("reason_code", ""))
	if code == "too_expensive":
		return String(texts.get("need_more", "%d")) % maxi(int(opt.get("price", 0)) - gold, 1)
	return String((texts.get("tile_reasons", {}) as Dictionary).get(code, opt.get("reason", "")))  # a short form for the tile; the tooltip has the full text


func _build_shop(opt: Dictionary, extra: Dictionary, enabled: bool, inner_width: float, sizes: Array) -> void:
	var title_size: int = int(sizes[0])
	var body_size: int = int(sizes[1])
	var small_size: int = int(sizes[2])
	var texts: Dictionary = extra.get("shop_texts", {})
	var gold: int = int(extra.get("gold", 0))
	var kind: String = String(opt.get("kind", ""))
	var sold: bool = bool(opt.get("sold", false))
	var state: Dictionary = shop_price_state(opt, gold, texts)
	var body_color: Color = _text_color(enabled, Color.html(String(_cfg["prompt_text_color"])))
	var name_text: String = String(extra.get("shop_name", opt.get("label", "")))
	tooltip_text = _shop_tooltip(opt, name_text)
	var tag: PanelContainer = _price_tag(String(state["text"]), String(state["mode"]), small_size)
	price_tag = tag
	# The kind chips: a relic's hexagon, tier and "Only sold here"; a card's slot key and slot. A service has none.
	var band := HBoxContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_constant_override("separation", roundi(6.0 * _scale))
	if kind == "buy_relic":
		var relic_texts: Dictionary = extra.get("relic_texts", {})
		var fill := PanelContainer.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = _relic_accent() if enabled else Color.html(String(_cfg["option_disabled_text_color"]))
		style.content_margin_left = 6.0 * _scale
		style.content_margin_right = 6.0 * _scale
		style.content_margin_top = 1.0 * _scale
		style.content_margin_bottom = 1.0 * _scale
		fill.add_theme_stylebox_override("panel", style)
		var inside := HBoxContainer.new()
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_theme_constant_override("separation", roundi(5.0 * _scale))
		fill.add_child(inside)
		var dark: Color = Color.html(String(_cfg.get("relic_band_text_color", "#1a1218")))
		var hex := RunTypeIcon.new()
		hex.shape = RunIcons.SHAPE_HEX
		hex.color = dark
		hex.custom_minimum_size = Vector2.ONE * float(small_size) * 1.0
		hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inside.add_child(hex)
		inside.add_child(_label(String(texts.get("relic_band", "%s, %s")) % [String(relic_texts.get("label", "Relic")), String(opt.get("tier_name", ""))], small_size, dark, false))
		shop_band = fill
		fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		band.add_child(fill)
		if bool(extra.get("shop_only", false)):
			shop_only_tag = _outlined_tag(String(texts.get("shop_only_tag", "")), small_size, enabled)
			band.add_child(shop_only_tag)
	elif kind == "buy_card":
		var chip: Control = _slot_chip(opt, extra.get("texts", {}), small_size, enabled, body_color)
		if chip != null:
			shop_band = chip
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			band.add_child(chip)
	# One header row: the kind chips, the name (it takes what is left and wraps if it must), the price tag on the right.
	title_label = _label(name_text, roundi(float(title_size) * 0.86), _text_color(enabled, Color.html("#ffffff")), true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var separation: float = 6.0 * _scale
	var left_w: float = band.get_combined_minimum_size().x + tag.get_combined_minimum_size().x + separation * float(band.get_child_count() + 1)
	title_label.custom_minimum_size.x = maxf(inner_width - left_w, float(small_size) * 5.0)
	band.add_child(title_label)
	band.add_child(tag)
	_inner.add_child(band)
	var detail: String = keep_units(String(opt.get("detail", "")))
	if detail != "":
		var lines: PackedStringArray = detail.split("\n")
		detail_label = _label(lines[0], body_size, body_color, true)
		detail_label.custom_minimum_size.x = inner_width
		_inner.add_child(detail_label)
		if lines.size() > 1:
			condition_label = _label("\n".join(lines.slice(1)), body_size, _text_color(enabled, Color.html(String(_cfg["option_accent_color"]))), true)
			condition_label.custom_minimum_size.x = inner_width
			_inner.add_child(condition_label)
	var reason_text: String = shop_reason_line(opt, gold, texts)
	if reason_text == "" and enabled and bool(opt.get("needs_swap", false)):
		cap_note_label = _label(String(texts.get("swap_note", "")), small_size, Color.html(String(_cfg["option_warn_color"])), true)
		cap_note_label.custom_minimum_size.x = inner_width
		_inner.add_child(cap_note_label)
	if reason_text != "":
		reason_label = _label(reason_text, small_size, Color.html(String(_cfg["option_warn_color"])), true)
		reason_label.custom_minimum_size.x = inner_width
		_inner.add_child(reason_label)
	if sold:
		modulate.a = 0.75


## The tooltip: the name, rule, keyword rules and flavor the tile has no room for, and the reason.
func _shop_tooltip(opt: Dictionary, name_text: String) -> String:
	var parts: PackedStringArray = PackedStringArray([name_text])
	var detail: String = String(opt.get("detail", ""))
	if detail != "":
		parts.append(detail)
	var rules: String = keyword_rules_text(String(opt.get("card_id", "")))
	if rules != "":
		parts.append(rules)
	var flavor: String = String(opt.get("flavor", ""))
	if flavor != "":
		parts.append(flavor)
	var reason: String = String(opt.get("reason", ""))
	if reason != "" and not bool(opt.get("enabled", true)):
		parts.append(reason)
	return "\n".join(parts)


## A small pill: gold with the price, green "Free", a red-brown outline when it costs too much, a grey outline "Sold". The word or number is always
## there, so the colour is never the only signal.
func _price_tag(word: String, mode: String, font_px: int) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(roundi(10.0 * _scale))
	style.content_margin_left = 8.0 * _scale
	style.content_margin_right = 8.0 * _scale
	style.content_margin_top = 1.0 * _scale
	style.content_margin_bottom = 1.0 * _scale
	var text_color: Color = Color.html("#1a1218")
	match mode:
		"price":
			style.bg_color = Color.html(String(_cfg.get("shop_gold_color", "#ffd23f")))
		"free":
			style.bg_color = Color.html(String(_cfg["option_accent_color"]))
		"short":
			style.bg_color = Color.html(String(_cfg["option_disabled_color"]))
			style.border_color = Color.html(String(_cfg["option_warn_color"]))
			style.set_border_width_all(maxi(roundi(2.0 * _scale), 1))
			text_color = Color.html(String(_cfg["option_warn_color"]))
		_:
			style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			style.border_color = Color.html(String(_cfg["option_disabled_text_color"]))
			style.set_border_width_all(maxi(roundi(2.0 * _scale), 1))
			text_color = Color.html(String(_cfg["option_disabled_text_color"]))
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(4.0 * _scale))
	pill.add_child(row)
	if mode == "price" or mode == "short":
		var coin := RunTypeIcon.new()  # a round coin, the shape the gold badge uses, so the number reads as gold
		coin.shape = RunIcons.SHAPE_CIRCLE
		coin.color = text_color if mode == "short" else Color.html("#8a5a00")
		coin.custom_minimum_size = Vector2.ONE * float(font_px) * 0.75
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(coin)
	row.add_child(_label(word, font_px, text_color, false))
	return pill


## An outlined pill (no fill): the "Only sold here" tag.
func _outlined_tag(word: String, font_px: int, enabled: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = _relic_accent() if enabled else Color.html(String(_cfg["option_disabled_text_color"]))
	style.set_border_width_all(maxi(roundi(2.0 * _scale), 1))
	style.set_corner_radius_all(roundi(3.0 * _scale))
	style.content_margin_left = 5.0 * _scale
	style.content_margin_right = 5.0 * _scale
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_child(_label(word, font_px, style.border_color, false))
	return pill


## Glues a number to its unit ("3 s" -> "3<no-break space>s") so a wrapped effect line never leaves a lone "s" at the start of the
## next line. Display only: the data text, the tooltip rules and the tests keep the plain space.
static func keep_units(text: String) -> String:
	var unit := RegEx.new()
	unit.compile("(\\d) (s|m)\\b")
	return unit.sub(text, "$1\u00a0$2", true)


## Relic accent (data run_ui.relic_accent_color): the "Relic" band, the inner line and the hexagon. Not the keyword chip colour.
func _relic_accent() -> Color:
	return Color.html(String(_cfg.get("relic_accent_color", "#c9a2ff")))


## The filled "Relic" band across the top of a relic offer: a hexagon, the word, and the tier on the right (shape and word, not colour alone).
func _relic_band(opt: Dictionary, relic_texts: Dictionary, font_size: int) -> PanelContainer:
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = _relic_accent()
	style.content_margin_left = 6.0 * _scale
	style.content_margin_right = 6.0 * _scale
	style.content_margin_top = 2.0 * _scale
	style.content_margin_bottom = 2.0 * _scale
	band.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(6.0 * _scale))
	band.add_child(row)
	var dark: Color = Color.html(String(_cfg.get("relic_band_text_color", "#1a1218")))
	var hex := RunTypeIcon.new()
	hex.shape = RunIcons.SHAPE_HEX
	hex.color = dark
	hex.custom_minimum_size = Vector2.ONE * float(font_size) * 1.1
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hex)
	var word := _label(String(relic_texts.get("label", "Relic")), font_size, dark, false)
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(word)
	row.add_child(_label(String(opt.get("tier_name", "")), font_size, dark, false))
	return band


## "[swatch] Fire": the relic's pool, a colour square in the pool's frame colour plus its name.
func _relic_pool_row(opt: Dictionary, relic_texts: Dictionary, font_size: int, body_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(6.0 * _scale))
	var swatch := ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.color = PoolDatabase.frame_color_for_pool(String(opt.get("pool", "")))
	swatch.custom_minimum_size = Vector2.ONE * float(font_size) * 0.8
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var text_value: String = String(opt.get("pool_name", ""))
	if look == Look.RELIC_CELL:
		text_value = String(relic_texts.get("cell_format", "%s, %s")) % [String(opt.get("pool_name", "")), String(opt.get("tier_name", ""))]
	row.add_child(_label(text_value, font_size, body_color, false))
	return row


## A relic's keywords as outlined chips (they are tags like Burn, never card keywords), or null.
func _relic_chips(opt: Dictionary, width: float, font_px: int) -> ChipRow:
	var tags: Array = opt.get("keywords", [])
	if tags.is_empty():
		return null
	var hud_cfg: Dictionary = UiConfig.hud()
	var row := ChipRow.new()
	row.configure(hud_cfg, font_px, roundf(float(font_px) * 1.45), 6.0 * _scale, 5.0 * _scale, width, int(hud_cfg["chip_max"]), false, 0.0, false)
	row.show_chips(tags)
	return row


## The "Free" pill on the skip tile.
func _free_tag(word: String, font_px: int) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(_cfg["option_accent_color"]))
	style.set_corner_radius_all(roundi(4.0 * _scale))
	style.content_margin_left = 7.0 * _scale
	style.content_margin_right = 7.0 * _scale
	style.content_margin_top = 1.0 * _scale
	style.content_margin_bottom = 1.0 * _scale
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(_label(word, font_px, Color.html("#1a1218"), false))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return pill


## "Keystone: The card a plan is built around." for each keyword the card carries (data/keywords.json), one per line; "" for none.
static func keyword_rules_text(card_id: String) -> String:
	if card_id == "":
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for keyword: String in CardTags.keywords_of(CardDatabase.get_card(card_id)):
		lines.append("%s: %s" % [KeywordDatabase.display_name(keyword), KeywordDatabase.rule_text(keyword)])
	return "
".join(lines)


## The chip row of a card: all chips for a reward offer, keywords only for a removal cell. Null when there is nothing to show.
func _chip_row(card_id: String, width: float, enabled: bool, font_px: int) -> ChipRow:
	if card_id == "":
		return null
	var hud_cfg: Dictionary = UiConfig.hud()
	var keywords_only: bool = look == Look.CELL
	var parts: Dictionary = ChipRow.texts_for(SlotSynergy.chips(card_id), keywords_only)
	if (parts["texts"] as Array).is_empty():
		return null
	var row := ChipRow.new()
	row.configure(hud_cfg, font_px, roundf(float(font_px) * 1.45), 6.0 * _scale, 5.0 * _scale, width, int(hud_cfg["chip_max"]), keywords_only, 0.0, false)
	row.show_chips(SlotSynergy.chips(card_id))
	if not enabled:
		row.modulate = Color(1.0, 1.0, 1.0, 0.55)
	return row


## A Button ignores its children when it sizes itself, so the height of the content becomes its custom minimum.
func _sync_min_size() -> void:
	if _inner == null:
		return
	custom_minimum_size = Vector2(_width, _inner.get_combined_minimum_size().y + 2.0 * _pad)


func _on_focus_changed(focused: bool) -> void:
	if hint_label != null:
		hint_label.modulate.a = 1.0 if focused else 0.0


## Hover moves the one highlight (the keyboard focus) here, so mouse and keys never show two selections.
func _on_hover() -> void:
	if not disabled and is_visible_in_tree():
		grab_focus()


func _text_color(enabled: bool, color: Color) -> Color:
	return color if enabled else Color.html(String(_cfg["option_disabled_text_color"]))


func _label(label_text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _badge(badge_text: String, font_size: int, enabled: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(_cfg["prompt_title_color"])) if enabled else Color.html(String(_cfg["option_disabled_text_color"]))
	style.set_corner_radius_all(roundi(4.0 * _scale))
	style.content_margin_left = 7.0 * _scale
	style.content_margin_right = 7.0 * _scale
	style.content_margin_top = 1.0 * _scale
	style.content_margin_bottom = 1.0 * _scale
	panel.add_theme_stylebox_override("panel", style)
	var label := _label(badge_text, font_size, Color.html("#1a1218"), false)
	panel.add_child(label)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return panel


## The slot's live key ("Key Q") in a dark outlined pill (the HUD's key hint for that slot) and the slot's name beside it.
func _slot_chip(opt: Dictionary, texts: Dictionary, font_size: int, enabled: bool, body_color: Color) -> PanelContainer:
	var slot_name: String = String(opt.get("slot_name", ""))
	var key: int = slot_key_for(String(opt.get("slot_type", "")))
	if slot_name == "" and key == 0:
		return null
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(8.0 * _scale))
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.add_child(row)
	if key > 0:
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color.html(String(_cfg["option_chip_color"]))
		style.border_color = Color.html(String(_cfg["option_chip_border_color"])) if enabled else Color.html(String(_cfg["option_disabled_text_color"]))
		# A key cap, not a pill: square corners, a thick bottom edge like a raised key.
		style.set_border_width_all(maxi(roundi(2.0 * _scale), 1))
		style.border_width_bottom = maxi(roundi(4.0 * _scale), 2)
		style.set_corner_radius_all(roundi(4.0 * _scale))
		style.content_margin_left = 8.0 * _scale
		style.content_margin_right = 8.0 * _scale
		style.content_margin_top = 1.0 * _scale
		style.content_margin_bottom = 0.0
		pill.custom_minimum_size.x = font_size * 1.6
		pill.add_theme_stylebox_override("panel", style)
		pill.add_child(_label(String(texts.get("slot_key", "%s")) % InputLabels.slot_key(String(opt.get("slot_type", ""))), font_size, _text_color(enabled, Color.html(String(_cfg["prompt_value_color"]))), false))
		row.add_child(pill)
	var name_label := _label(slot_name, font_size, body_color, false)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	return holder


## The card this option draws (a reward offer or a removal-list cell), else "": the id the frame colour comes from.
func frame_card_id() -> String:
	if look != Look.CARD and look != Look.CELL and not (look == Look.SHOP and String(option.get("kind", "")) == "buy_card"):
		return ""
	return String(option.get("card_id", ""))


## The frame colour this option's card wears (tests).
func frame_color() -> Color:
	if look == Look.RELIC or look == Look.RELIC_CELL or _is_shop_relic():
		return PoolDatabase.frame_color_for_pool(String(option.get("pool", "")))
	return PoolDatabase.frame_color_for_card(frame_card_id()) if frame_card_id() != "" else Color.html(String(_cfg["option_card_border_color"]))


## Pixel width of the focus ring at `scale` (data: option_focus_width). The family-card ring is drawn this far outside the
## card, so whatever clips the cards (the prompt's ScrollContainer) must leave this much room on every side.
static func focus_ring_width(cfg: Dictionary, scale: float) -> int:
	return maxi(roundi(float(cfg["option_focus_width"]) * scale), 2)


func _apply_styles(enabled: bool) -> void:
	var border_w: int = maxi(roundi(2.0 * _scale), 1)
	var radius: int = roundi(8.0 * _scale)
	var base := StyleBoxFlat.new()
	base.set_corner_radius_all(radius)
	base.set_border_width_all(border_w)
	base.bg_color = Color.html(String(_cfg["option_card_color"]))
	base.border_color = Color.html(String(_cfg["option_card_border_color"]))
	if look == Look.REJECT:
		base.bg_color = Color.html(String(_cfg["option_reject_color"]))
		base.border_color = Color.html(String(_cfg["option_reject_border_color"]))
		base.set_corner_radius_all(roundi(2.0 * _scale))  # square-cornered: a different shape from the cards
	elif look == Look.BACK:
		base.set_corner_radius_all(roundi(20.0 * _scale))
	# A card (reward offer, removal cell) wears its family colour as a thicker frame (GDD section 4, card frame colours).
	var relic: bool = look == Look.RELIC or look == Look.RELIC_CELL or _is_shop_relic()
	var family: bool = frame_card_id() != "" or relic
	if relic:
		base.set_corner_radius_all(0)  # square: a card is rounded
	if look == Look.SKIP_FREE:
		base.set_corner_radius_all(roundi(2.0 * _scale))
		base.border_color = Color.html(String(_cfg["option_accent_color"]))
	if family:
		base.set_border_width_all(maxi(roundi(float(_cfg["option_frame_width"]) * _scale), 2))
		base.border_color = frame_color()
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color.html(String(_cfg["option_card_hover_color"]))
	var off := base.duplicate() as StyleBoxFlat
	off.bg_color = Color.html(String(_cfg["option_disabled_color"]))
	off.border_color = Color(off.border_color, 0.5)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(0 if relic else radius)
	var focus_w: int = focus_ring_width(_cfg, _scale)
	focus.set_border_width_all(focus_w)
	focus.border_color = Color.html(String(_cfg["option_focus_color"]))
	if family:
		# The ring sits just outside the card, in white, so it never covers or blends into the family colour (bronze is
		# close to the shared peach focus colour).
		focus.border_color = Color.html(String(_cfg["option_card_focus_color"]))
		focus.set_expand_margin_all(float(focus_w))
	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("hover_pressed", hover)
	add_theme_stylebox_override("disabled", off)
	add_theme_stylebox_override("focus", focus)


func _draw() -> void:
	var kind: String = String(option.get("kind", ""))
	var size_px: float = float(_cfg.get("option_title_font_size", 22)) * 0.9 * _scale
	var center := Vector2(size.x - _pad - size_px * 0.6, _pad + size_px * 0.75)
	var color: Color = Color.html(String(_cfg["option_disabled_text_color"])) if disabled else Color.html(String(_cfg["option_accent_color"]))
	var outline: Color = Color(0.05, 0.03, 0.04, 1.0)
	var w: float = maxf(2.5 * _scale, 2.0)
	if look == Look.REJECT:
		var rose: Color = Color.html(String(_cfg["option_reject_border_color"])) if not disabled else color
		draw_arc(center, size_px * 0.5, 0.0, TAU, 24, rose, w)
		draw_line(center + Vector2(-0.35, 0.35) * size_px, center + Vector2(0.35, -0.35) * size_px, rose, w)
	elif look == Look.ACTION and kind == "heal":
		var pts := RunIcons.polygon(RunIcons.SHAPE_PLUS, size_px * 0.6)
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + center)
		draw_colored_polygon(moved, color)
		moved.append(moved[0])
		draw_polyline(moved, outline, maxf(1.0, _scale), true)
	elif look == Look.ACTION and kind == "remove":
		var warn: Color = Color.html(String(_cfg["option_warn_color"])) if not disabled else color
		draw_rect(Rect2(center + Vector2(-0.5, -0.12) * size_px, Vector2(size_px, size_px * 0.24)), warn)
	elif look == Look.SKIP_FREE:
		var green: Color = Color.html(String(_cfg["option_accent_color"]))
		var tip: Vector2 = center + Vector2(0.5, 0.0) * size_px
		draw_line(center + Vector2(-0.5, 0.0) * size_px, tip, green, w)
		draw_line(tip, tip + Vector2(-0.3, -0.3) * size_px, green, w)
		draw_line(tip, tip + Vector2(-0.3, 0.3) * size_px, green, w)
	elif look == Look.RELIC_CELL:
		var pts_hex := RunIcons.polygon(RunIcons.SHAPE_HEX, size_px * 0.5)
		var hex_moved := PackedVector2Array()
		for p in pts_hex:
			hex_moved.append(p + center)
		draw_colored_polygon(hex_moved, _relic_accent())
	elif look == Look.RELIC or _is_shop_relic():
		# The inner line of the double frame: a card has one thick frame, a relic has a second thin one inside it.
		var inset: float = float(maxi(roundi(float(_cfg["option_frame_width"]) * _scale), 2)) + maxf(2.0 * _scale, 2.0)
		draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0), _relic_accent(), false, maxf(_scale, 1.0))
	elif look == Look.BACK:
		return


func _draw_pips() -> void:
	if _pips == null or _rejects_max <= 0:
		return
	var r: float = 5.0 * _scale
	var rose: Color = Color.html(String(_cfg["option_reject_border_color"]))
	for i in range(_rejects_max):
		var c := Vector2(r + float(i) * r * 3.0, _pips.size.y * 0.5)
		if i < _rejects_remaining:
			_pips.draw_circle(c, r, rose)
		else:
			_pips.draw_arc(c, r - 1.0, 0.0, TAU, 16, rose, maxf(1.5 * _scale, 1.0))
