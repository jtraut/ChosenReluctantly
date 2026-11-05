extends VBoxContainer
class_name CardSlotWidget
## One of the 5 bottom-HUD slot widgets: key hint, revealed card name, a
## cooldown bar, and a preview of the next card. Pure display - reads a
## CardSlot each frame, writes nothing back.
## Fixed size: every row has a fixed height from data/ui.json `hud`, so long
## names never move the bar or the preview. Names follow TextFit's rule
## (wrap to max lines, shrink to min size, ellipsis last).

const UNSET: String = "\u0001unset"

@onready var key_label: Label = $KeyLabel
@onready var name_label: Label = $NameLabel
@onready var cooldown_bar: ProgressBar = $CooldownBar
@onready var preview_label: Label = $PreviewLabel

var _cfg: Dictionary = {}
var _scale: float = 1.0
var _name_text: String = UNSET
var _preview_text: String = UNSET
var _ready_state: bool = false
## Family colours (PoolDatabase) of the card in the slot and of the next one; the frame and the next-up swatch use them.
var _frame_color: Color = Color.GRAY
var _next_color: Color = Color.GRAY
var _has_next: bool = false
var _card_id: String = UNSET
var _next_id: String = UNSET
## Draws the frame above every child (a container paints its own _draw behind them, and the full-width bar would hide
## the frame's side lines). Top level, so the VBox does not lay it out; it follows this widget's rect.
var _overlay: Control = null
## BD1 synergy cues. The chip row is a fifth row between the cooldown bar and the Next line; the glow and the primed
## marker are drawn on the overlay, so they never change the layout.
var chip_row: ChipRow = null
var _glow: Dictionary = {"level": 0.0, "hold_left": 0.0}
var _live_target: bool = false
var _primed: bool = false
var _primed_fraction: float = 0.0
var _primed_charges: int = 0
var _condition_text: String = ""
## BD2 ux: the short dim reason on a conditional slot that is not lit ("Needs Burn"), and the "prime ended" mark.
var _condition_short: String = ""
var _condition_short_card: String = UNSET
var _spent: Dictionary = {"level": 0.0, "used": true}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = Control.new()
	_overlay.name = "FrameOverlay"
	_overlay.top_level = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_frame)
	add_child(_overlay)
	chip_row = ChipRow.new()
	chip_row.name = "ChipRow"
	add_child(chip_row)
	move_child(chip_row, preview_label.get_index())
	if _cfg.is_empty():
		apply_layout(UiConfig.hud(), 1.0)
	_apply_state(false)


## Pure: fraction of the slot cooldown elapsed, 0..1. 1.0 = ready.
static func cooldown_progress(remaining: float, duration: float) -> float:
	if remaining <= 0.0 or duration <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / duration, 0.0, 1.0)


func is_ready_state() -> bool:
	return _ready_state


## Ready: full-brightness text, a light plate behind the slot, a green bar. Cooling: the texts and bar dim, a dark plate,
## a grey-blue bar that fills as the cooldown elapses. The family frame is the same either way.
func _apply_state(is_ready: bool) -> void:
	_ready_state = is_ready
	var cfg := _cfg if not _cfg.is_empty() else UiConfig.hud()
	var dim := 1.0 if is_ready else float(cfg["slot_cooling_dim"])
	# Children only: dimming the whole widget would dim the family frame too, and a cooling slot must keep its colour.
	for child in [key_label, name_label, cooldown_bar, preview_label]:
		(child as CanvasItem).modulate = Color(dim, dim, dim, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(String(cfg["slot_ready_bar_color" if is_ready else "slot_cooling_bar_color"]))
	var back := StyleBoxFlat.new()
	back.bg_color = Color.html(String(cfg["slot_bar_back_color"]))
	cooldown_bar.add_theme_stylebox_override("fill", fill)
	cooldown_bar.add_theme_stylebox_override("background", back)
	queue_redraw()
	_redraw_frame()


## The family frame colour of the card in the slot (neutral grey when the slot is empty).
func frame_color() -> Color:
	return _frame_color


## The family colour of the next-up card, or grey when there is none.
func next_color() -> Color:
	return _next_color


## The plate behind the children: light while ready, dark while cooling (the ready-vs-cooling cue; the frame never changes).
func _draw() -> void:
	if _cfg.is_empty():
		return
	var key: String = "slot_plate_ready_color" if _ready_state else "slot_plate_cooling_color"
	draw_rect(Rect2(Vector2.ZERO, size), Color.html(String(_cfg[key])))


func _redraw_frame() -> void:
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


func _sync_overlay() -> void:
	if _overlay == null:
		return
	if _overlay.global_position != global_position:
		_overlay.global_position = global_position
	if _overlay.size != size:
		_overlay.size = size


## Frame (outermost in): a dark keyline, then the family colour. The ready cue is the plate behind the slot (see _draw).
## The next-up swatch is a short bar of the next card's family colour on the left of the preview row.
func _draw_frame() -> void:
	if _cfg.is_empty():
		return
	var r := Rect2(Vector2.ZERO, _overlay.size)
	var kw := _px(float(_cfg["slot_frame_keyline_width"]))
	var fw := _px(float(_cfg["slot_frame_width"]))
	_overlay.draw_rect(r.grow(-kw * 0.5), Color.html(String(_cfg["slot_frame_keyline_color"])), false, kw)
	_overlay.draw_rect(r.grow(-kw - fw * 0.5), _frame_color, false, fw)
	var inset := kw + fw
	_draw_live_glow(r)
	_draw_cues(r, inset)
	_draw_condition_line(inset)
	if _has_next:
		var sw := _px(float(_cfg["slot_next_swatch_width"]))
		var row := Rect2(preview_label.position, preview_label.size)
		_overlay.draw_rect(Rect2(Vector2(inset, row.position.y + sw), Vector2(sw, maxf(row.size.y - 2.0 * sw, 1.0))), _next_color)


## The live-condition glow: rings just outside the frame, thick corner brackets over it, and the word LIVE (shape,
## outline and text, not colour alone). Softer while the slot is cooling, so "lit" is never read as "cast it now".
func _draw_live_glow(r: Rect2) -> void:
	var level: float = float(_glow["level"])
	if level <= 0.01:
		return
	var strength: float = level * (1.0 if _ready_state else float(_cfg["live_cooling_strength"]))
	var color := Color.html(String(_cfg["live_color"]))
	var ring_w: float = _px(float(_cfg["live_ring_width"]))
	var rings: int = int(_cfg["live_ring_count"])
	for i in range(rings):
		var alpha: float = strength * (0.95 - 0.3 * float(i))
		_overlay.draw_rect(r.grow(ring_w * (float(i) + 0.5)), Color(color, clampf(alpha, 0.0, 1.0)), false, ring_w)
	var arm: float = _px(float(_cfg["live_bracket_length"]))
	var bw: float = _px(float(_cfg["live_ring_width"]))
	var bracket := Color(color, clampf(strength, 0.0, 1.0))
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx: float = 1.0 if corner.x <= r.position.x + 0.5 else -1.0
		var sy: float = 1.0 if corner.y <= r.position.y + 0.5 else -1.0
		_overlay.draw_line(corner + Vector2(0.0, bw * 0.5 * sy), corner + Vector2(arm * sx, bw * 0.5 * sy), bracket, bw)
		_overlay.draw_line(corner + Vector2(bw * 0.5 * sx, 0.0), corner + Vector2(bw * 0.5 * sx, arm * sy), bracket, bw)
	if level >= 0.5:
		var font_px: int = roundi(float(_cfg["cue_font_size"]) * _scale)
		_draw_pill(Vector2(r.end.x - _px(7.0), _px(7.0)), true, String(_cfg["live_word"]), font_px, color, Color.html(String(_cfg["live_text_color"])))


## A small filled pill with text. `anchor` is its top-right corner when `right_aligned`, else its top-left.
func _draw_pill(anchor: Vector2, right_aligned: bool, text: String, font_px: int, fill: Color, text_color: Color) -> void:
	var font: Font = key_label.get_theme_font("font")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px)
	var pad: float = _px(4.0)
	var pill := Rect2(Vector2.ZERO, Vector2(text_size.x + 2.0 * pad, text_size.y + _px(1.0)))
	pill.position = Vector2(anchor.x - pill.size.x if right_aligned else anchor.x, anchor.y)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(maxi(2, roundi(pill.size.y * 0.25)))
	_overlay.draw_style_box(box, pill)
	_overlay.draw_string(font, Vector2(pill.position.x + pad, pill.position.y + (pill.size.y + font.get_ascent(font_px) - font.get_descent(font_px)) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, text_color)


## The primed marker: a bolt (and "x2" when charges stack) at the left of the key row, and a drain bar along its foot.
func _draw_cues(r: Rect2, inset: float) -> void:
	var spent_level: float = float(_spent["level"])
	if not _primed and spent_level <= 0.01:
		return
	var alpha: float = 1.0 if _primed else spent_level
	var color := Color.html(String(_cfg["primed_color"]))
	color.a = alpha
	var back := Color.html(String(_cfg["primed_back_color"]))
	back.a = alpha
	# At 1024x600 the cue font scales down to 10 px, too small to read at a glance: it never goes below `cue_min_font_px`.
	var font_px: int = maxi(roundi(float(_cfg["cue_font_size"]) * _scale), int(_cfg.get("cue_min_font_px", 12)))
	var font: Font = key_label.get_theme_font("font")
	var charges: String = SlotCues.charges_text(_primed_charges) if _primed else SlotCues.spent_word(bool(_spent["used"]), String(_cfg.get("primed_spent_word", "USED")), String(_cfg.get("primed_expired_word", "GONE")))
	var h: float = float(font_px) + _px(2.0)
	var left: float = inset + _px(3.0)
	var top: float = inset + _px(1.0)
	var width: float = h * 0.9 + _px(5.0)
	if charges != "":
		width += font.get_string_size(charges, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x + _px(2.0)
	var box := StyleBoxFlat.new()
	box.bg_color = back
	box.border_color = color
	box.set_border_width_all(maxi(1, roundi(_scale)))
	box.set_corner_radius_all(maxi(2, roundi(h * 0.25)))
	_overlay.draw_style_box(box, Rect2(left, top, width, h))
	if not _primed:
		# The moment a prime ends: the frame flashes in the prime colour and fades with the word.
		_overlay.draw_rect(r.grow(-inset * 0.5), Color(color, spent_level * 0.9), false, _px(2.0))
	var bolt := PackedVector2Array([Vector2(0.62, 0.0), Vector2(0.12, 0.58), Vector2(0.48, 0.58), Vector2(0.30, 1.0), Vector2(0.9, 0.38), Vector2(0.53, 0.38)])
	var bolt_h: float = h * 0.8
	var origin := Vector2(left + _px(2.0), top + (h - bolt_h) * 0.5)
	var moved := PackedVector2Array()
	for p: Vector2 in bolt:
		moved.append(origin + p * bolt_h)
	_overlay.draw_colored_polygon(moved, color)
	if charges != "":
		var baseline: float = top + (h + font.get_ascent(font_px) - font.get_descent(font_px)) * 0.5
		_overlay.draw_string(font, Vector2(origin.x + bolt_h * 0.9 + _px(2.0), baseline), charges, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, color)
	if not _primed:
		return
	# Drain bar: the primed window left. Full and steady when the buff has no time limit.
	var bar_h: float = _px(float(_cfg["primed_bar_height"]))
	var kr := Rect2(key_label.position, key_label.size)
	var bar := Rect2(inset, kr.end.y - bar_h, maxf(r.size.x - 2.0 * inset, 1.0), bar_h)
	_overlay.draw_rect(bar, back)
	_overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _primed_fraction, bar.size.y)), color)


## The dim "why isn't it lit" line, on the left of the key row: short ("Needs Burn", "After Move"). Only while the slot holds a
## conditional card that is not lit and not primed, so it never fights the LIVE pill or the primed marker. It sits on the overlay,
## so it adds no row and the five-row fit is untouched.
func _draw_condition_line(inset: float) -> void:
	if _condition_short == "" or _primed or float(_glow["level"]) >= 0.5 or float(_spent["level"]) > 0.01:
		return
	var font: Font = key_label.get_theme_font("font")
	var base_px: int = maxi(roundi(float(_cfg.get("condition_font_size", 11)) * _scale), int(_cfg.get("condition_min_font_px", 10)))
	var key_w: float = font.get_string_size(key_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, key_label.get_theme_font_size("font_size")).x
	var left: float = inset + _px(3.0)
	var room: float = _overlay.size.x * 0.5 - key_w * 0.5 - _px(4.0) - left
	if room < 8.0:
		return
	var fit: Dictionary = TextFit.fit(_condition_short, font, room, 1, base_px, maxi(base_px - 2, 8))
	var color := Color.html(String(_cfg.get("condition_color", "#b9aeb5")))
	var shown_px: int = int(fit["font_size"])
	var kr := Rect2(key_label.position, key_label.size)
	var baseline: float = kr.position.y + (kr.size.y + font.get_ascent(shown_px) - font.get_descent(shown_px)) * 0.5 + _px(1.0)
	_overlay.draw_string(font, Vector2(left, baseline), String(fit["text"]), HORIZONTAL_ALIGNMENT_LEFT, room, shown_px, color)


func _px(value: float) -> float:
	return float(maxi(1, roundi(value * _scale)))


## Sizes every row from config; `s` is the viewport-height scale.
func apply_layout(cfg: Dictionary, s: float) -> void:
	_cfg = cfg
	_scale = s
	var size_arr: Array = cfg["slot_size"]
	var w := float(size_arr[0]) * s
	custom_minimum_size = Vector2(w, float(size_arr[1]) * s)
	var separation: int = roundi(float(cfg["slot_row_separation"]) * s)
	add_theme_constant_override("separation", separation)
	var row_scale: float = row_fit_scale(cfg, s, separation)
	_size_row(key_label, w, floorf(float(cfg["key_height"]) * s * row_scale))
	key_label.add_theme_font_size_override("font_size", roundi(float(cfg["key_font_size"]) * s))
	_size_row(name_label, w, floorf(float(cfg["name_height"]) * s * row_scale))
	name_label.max_lines_visible = int(cfg["name_max_lines"])
	_size_row(cooldown_bar, w, floorf(float(cfg["bar_height"]) * s * row_scale))
	if chip_row != null:
		chip_row.configure(cfg, roundi(float(cfg["chip_font_size"]) * s), floorf(float(cfg["chip_height"]) * s * row_scale), float(cfg["chip_pad_x"]) * s, float(cfg["chip_gap"]) * s, w, int(cfg["chip_max"]), false, float(cfg["fit_padding"]) * s * 0.5)
		chip_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_size_row(preview_label, w, floorf(float(cfg["preview_height"]) * s * row_scale))
	preview_label.max_lines_visible = int(cfg["preview_max_lines"])
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER  # a two-line "Next:" sits centred with air above and below, not hard on the frame
	# The fit width is the label width minus fit_padding, so the label itself keeps that margin too: without it a
	# name that fits on one line in the full width would run right up to the slot border.
	var margin := StyleBoxEmpty.new()
	margin.content_margin_left = float(cfg["fit_padding"]) * s * 0.5
	margin.content_margin_right = float(cfg["fit_padding"]) * s * 0.5
	var key_margin := StyleBoxEmpty.new()
	key_margin.content_margin_top = (float(cfg["slot_frame_width"]) + float(cfg["slot_frame_keyline_width"])) * s
	key_label.add_theme_stylebox_override("normal", key_margin)
	name_label.add_theme_stylebox_override("normal", margin)
	preview_label.add_theme_stylebox_override("normal", margin)
	_redraw_frame()
	# Force a refit at the new scale.
	var n := _name_text
	var p := _preview_text
	_name_text = UNSET
	_preview_text = UNSET
	_set_name(n if n != UNSET else "—")
	_set_preview(p if p != UNSET else "")


## Factor (at most 1) that shrinks the five rows so rows plus the whole-pixel separations fit the slot's height. Below 720 px the
## separation (at least 2 px) is bigger than its share of the scaled slot. A VBoxContainer also rounds every child's minimum
## height up to a whole pixel, so the row heights are floored (see apply_layout): together these were the old ~3 px overflow.
static func row_fit_scale(cfg: Dictionary, s: float, separation: int) -> float:
	var rows_ref: float = float(cfg["key_height"]) + float(cfg["name_height"]) + float(cfg["bar_height"]) + float(cfg["chip_height"]) + float(cfg["preview_height"])
	var available: float = float((cfg["slot_size"] as Array)[1]) * s - float(separation * 4)
	return clampf(available / (rows_ref * s), 0.5, 1.0)


func _size_row(c: Control, w: float, h: float) -> void:
	c.custom_minimum_size = Vector2(w, h)
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func set_key_hint(text: String) -> void:
	key_label.text = text


func update_from_slot(slot: CardSlot) -> void:
	_sync_overlay()
	if slot == null or not slot.has_cards():
		_set_frames("", "")
		_refresh_condition_short("")
		_set_name("—")
		_set_preview("")
		cooldown_bar.max_value = 1.0
		cooldown_bar.value = 0.0
		if _ready_state:
			_apply_state(false)
		return

	var card_data := CardDatabase.get_card(slot.current_card_id)
	_set_name(str(card_data.get("name", slot.current_card_id)))

	var preview_id := slot.preview_card_id()
	_set_frames(slot.current_card_id, preview_id)
	_refresh_condition_short(slot.current_card_id)
	if preview_id == "":
		_set_preview("Next: —")
	else:
		var preview_card := CardDatabase.get_card(preview_id)
		_set_preview("Next: %s" % str(preview_card.get("name", preview_id)))

	# Bar fills left to right as the cooldown elapses; full = ready.
	cooldown_bar.max_value = 1.0
	cooldown_bar.value = cooldown_progress(slot.cooldown_remaining, slot.last_cooldown_duration)
	var now_ready := slot.is_ready()
	if now_ready != _ready_state:
		_apply_state(now_ready)


## BD1: feeds one slot's SlotSynergyView info ({} when there is none) and the frame time. Chips follow the card; the
## live glow eases (rise fast, hold, fade) so a condition flipping at an area's edge does not flicker; the primed marker
## is a bolt plus a drain bar. Redraws only when something it draws has changed.
func update_synergy(info: Dictionary, delta: float) -> void:
	if chip_row != null:
		chip_row.show_chips(info.get("chips", []))
	_condition_text = String(info.get("condition_text", ""))
	_live_target = bool(info.get("condition_live", false))
	var before_level: float = float(_glow["level"])
	_glow = SlotCues.glow_step(_glow, _live_target, delta, float(_cfg.get("live_attack", 0.08)), float(_cfg.get("live_hold", 0.3)), float(_cfg.get("live_release", 0.25)))
	var primed: bool = bool(info.get("primed", false))
	var fraction: float = SlotCues.primed_fraction(float(info.get("primed_time_left", -1.0)), float(info.get("primed_duration", -1.0))) if primed else 0.0
	var charges: int = int(info.get("primed_charges", 0)) if primed else 0
	var before_spent: float = float(_spent["level"])
	_spent = SlotCues.spent_step(_spent, _primed, primed, _primed_fraction, delta, float(_cfg.get("primed_spent_duration", 0.6)), float(_cfg.get("primed_expired_below", 0.08)))
	var changed: bool = primed != _primed or charges != _primed_charges or not is_equal_approx(fraction, _primed_fraction) or not is_equal_approx(before_level, float(_glow["level"])) or not is_equal_approx(before_spent, float(_spent["level"]))
	_primed = primed
	_primed_fraction = fraction
	_primed_charges = charges
	if changed:
		_sync_overlay()
		_overlay.queue_redraw()


## Glow level 0..1 after easing (tests).
func glow_level() -> float:
	return float(_glow["level"])


func is_primed() -> bool:
	return _primed


## The "prime ended" mark's level 0..1 (tests) and whether it reads "used" (else "expired").
func spent_level() -> float:
	return float(_spent["level"])


func spent_used() -> bool:
	return bool(_spent["used"])


## The dim reason line of the card in the slot ("" for a card with no condition).
func condition_short() -> String:
	return _condition_short


func _refresh_condition_short(card_id: String) -> void:
	if card_id == _condition_short_card:
		return
	_condition_short_card = card_id
	_condition_short = ""
	if card_id != "":
		_condition_short = ConditionCue.short_text(CardDatabase.get_card(card_id), RunConfig.ui().get("slot_condition", {}))
	_redraw_frame()


func primed_fraction() -> float:
	return _primed_fraction


func primed_charges() -> int:
	return _primed_charges


func _set_frames(card_id: String, next_id: String) -> void:
	if card_id == _card_id and next_id == _next_id:
		return
	_card_id = card_id
	_next_id = next_id
	_frame_color = PoolDatabase.frame_color_for_card(card_id)
	_has_next = next_id != ""
	_next_color = PoolDatabase.frame_color_for_card(next_id)
	_redraw_frame()


func _set_name(text: String) -> void:
	if text == _name_text:
		return
	_name_text = text
	_fit(name_label, text, "name_font_size", "name_min_font_size", "name_max_lines")


func _set_preview(text: String) -> void:
	if text == _preview_text:
		return
	_preview_text = text
	_fit(preview_label, text, "preview_font_size", "preview_min_font_size", "preview_max_lines")


func _fit(label: Label, text: String, base_key: String, min_key: String, lines_key: String) -> void:
	if _cfg.is_empty():
		label.text = text
		return
	var font := label.get_theme_font("font")
	var width := label.custom_minimum_size.x - float(_cfg["fit_padding"]) * _scale
	var result := TextFit.fit(
		text, font, width, int(_cfg[lines_key]),
		roundi(float(_cfg[base_key]) * _scale), roundi(float(_cfg[min_key]) * _scale)
	)
	label.text = result["text"]
	label.add_theme_font_size_override("font_size", result["font_size"])
