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
## The button's own text stays empty: children draw the content (mouse ignored) and `_get_minimum_size` takes
## the height from them. The highlight is one state: keyboard focus, and hover moves focus here too.
## Not colour alone: the focus is a thick outline plus an "Enter to ..." line, disabled cards say why in words.

enum Look { CARD, REJECT, ACTION, CELL, BACK }

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
var number_badge: PanelContainer = null

var _inner: VBoxContainer = null
var _width: float = 0.0
var _pad: float = 0.0
var _cfg: Dictionary = {}
var _scale: float = 1.0
var _pips: Control = null
var _rejects_remaining: int = 0
var _rejects_max: int = 0


## 1-based HUD key of a slot type (the order of the five HUD slots); 0 when unknown.
static func slot_key_for(slot_type: String) -> int:
	return CardSlotController.SLOT_TYPE_ORDER.find(slot_type) + 1


## "You own 2" when the player already holds copies of the offered card, else "".
static func owned_text(count: int, format: String) -> String:
	return format % count if count > 0 else ""


## Card names contain commas, so the list is joined with a slash.
const SLOT_NOW_SEPARATOR: String = " / "


## "Slot 2 now: A / B / C": the distinct cards already held in the offered card's slot (data/run.json ui.option.slot_now).
## "" when the slot holds nothing yet or the slot is unknown.
static func slot_now_text(key: int, names: Array, format: String) -> String:
	if key <= 0 or names.is_empty():
		return ""
	var joined: PackedStringArray = PackedStringArray()
	for entry: Variant in names:
		joined.append(String(entry))
	return format % [key, SLOT_NOW_SEPARATOR.join(joined)]


## Builds the card. `extra`: index (0-based, -1 = no number), owned (int), rejects_remaining, rejects_max, texts (run.json ui.option).
func setup(opt: Dictionary, the_look: Look, width: float, cfg: Dictionary, s: float, extra: Dictionary) -> void:
	option = opt
	look = the_look
	_cfg = cfg
	_scale = s
	_pad = float(cfg["option_pad"]) * s * (0.7 if the_look == Look.CELL else 1.0)
	_width = width * s
	_rejects_remaining = int(extra.get("rejects_remaining", 0))
	_rejects_max = int(extra.get("rejects_max", 0))
	var texts: Dictionary = extra.get("texts", {})
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

	# Head row: number key (when numbered), name, copy count.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", roundi(8.0 * s))
	_inner.add_child(head)
	var glyph_room: float = 0.0
	if look == Look.ACTION or look == Look.REJECT:
		glyph_room = float(cfg["option_title_font_size"]) * 1.4 * s
	if index >= 0 and look != Look.BACK:
		number_badge = _badge(str(index + 1), small_size, enabled)
		head.add_child(number_badge)
	title_label = _label(String(opt.get("label", "")), title_size if look != Look.BACK else body_size, title_color, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size.x = inner_width - glyph_room - (float(small_size) * 2.2 if number_badge != null else 0.0) - (float(body_size) * 2.5 if look == Look.CELL else 0.0)
	if look == Look.CELL:
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
	var detail: String = String(opt.get("detail", ""))
	var cell_blocked: bool = look == Look.CELL and not enabled and String(opt.get("reason", "")) != ""
	tooltip_text = String(opt.get("reason", ""))
	if look == Look.CELL:
		tooltip_text = detail if enabled else "%s
%s" % [detail, String(opt.get("reason", ""))]
	if detail != "" and look != Look.BACK and not cell_blocked:  # a greyed list cell gives the room to its reason
		detail_label = _label(detail, small_size if look == Look.CELL else body_size, body_color, true)
		detail_label.custom_minimum_size.x = inner_width
		_inner.add_child(detail_label)
	if look == Look.REJECT:
		_pips = Control.new()
		_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.custom_minimum_size = Vector2(inner_width, 14.0 * s)
		_pips.draw.connect(_draw_pips)
		_inner.add_child(_pips)
	if look == Look.CARD:
		var now_text: String = slot_now_text(slot_key_for(String(opt.get("slot_type", ""))), opt.get("slot_contents", []), String(texts.get("slot_now", "Slot %d now: %s")))
		if now_text != "":
			slot_now_label = _label(now_text, small_size, body_color, true)
			slot_now_label.custom_minimum_size.x = inner_width
			_inner.add_child(slot_now_label)
	var flavor: String = String(opt.get("flavor", ""))
	if flavor != "" and look == Look.CARD:
		flavor_label = _label(flavor, small_size, _text_color(enabled, Color.html(String(cfg["option_flavor_color"]))), true)
		flavor_label.custom_minimum_size.x = inner_width
		_inner.add_child(flavor_label)
	if look == Look.CARD and int(extra.get("owned", 0)) > 0:
		owned_label = _label(owned_text(int(extra["owned"]), String(texts.get("owned", "You own %d"))), small_size, _text_color(enabled, Color.html(String(cfg["option_accent_color"]))), false)
		_inner.add_child(owned_label)
	var reason: String = String(opt.get("reason", ""))
	if not enabled and reason != "":
		reason_label = _label(String(texts.get("unavailable", "Unavailable: %s")) % reason, small_size, Color.html(String(cfg["option_warn_color"])), true)
		reason_label.custom_minimum_size.x = inner_width
		_inner.add_child(reason_label)
	if enabled and look in [Look.CARD, Look.ACTION, Look.REJECT]:
		var key: String = "pick_hint" if (look == Look.CARD) else ("remove_hint" if String(opt.get("kind", "")) == "remove" else "act_hint")
		hint_label = _label(String(texts.get(key, "Enter")), small_size, Color.html(String(cfg["option_focus_color"])), false)
		hint_label.modulate.a = 0.0
		_inner.add_child(hint_label)
	_inner.minimum_size_changed.connect(_sync_min_size)  # wrapped labels settle after the first layout pass
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	mouse_entered.connect(_on_hover)
	_sync_min_size()


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


## "Slot 2" in a dark outlined pill (the HUD's key hint for that slot) and the slot's name beside it.
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
		style.set_border_width_all(maxi(roundi(2.0 * _scale), 1))
		style.set_corner_radius_all(roundi(10.0 * _scale))
		style.content_margin_left = 8.0 * _scale
		style.content_margin_right = 8.0 * _scale
		style.content_margin_top = 1.0 * _scale
		style.content_margin_bottom = 1.0 * _scale
		pill.add_theme_stylebox_override("panel", style)
		pill.add_child(_label(String(texts.get("slot_key", "Slot %d")) % key, font_size, _text_color(enabled, Color.html(String(_cfg["prompt_value_color"]))), false))
		row.add_child(pill)
	var name_label := _label(slot_name, font_size, body_color, false)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	return holder


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
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color.html(String(_cfg["option_card_hover_color"]))
	var off := base.duplicate() as StyleBoxFlat
	off.bg_color = Color.html(String(_cfg["option_disabled_color"]))
	off.border_color = Color(off.border_color, 0.5)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(radius)
	focus.set_border_width_all(maxi(roundi(float(_cfg["option_focus_width"]) * _scale), 2))
	focus.border_color = Color.html(String(_cfg["option_focus_color"]))
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
