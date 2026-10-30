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
	if _has_next:
		var sw := _px(float(_cfg["slot_next_swatch_width"]))
		var row := Rect2(preview_label.position, preview_label.size)
		_overlay.draw_rect(Rect2(Vector2(inset, row.position.y + sw), Vector2(sw, maxf(row.size.y - 2.0 * sw, 1.0))), _next_color)


func _px(value: float) -> float:
	return float(maxi(1, roundi(value * _scale)))


## Sizes every row from config; `s` is the viewport-height scale.
func apply_layout(cfg: Dictionary, s: float) -> void:
	_cfg = cfg
	_scale = s
	var size_arr: Array = cfg["slot_size"]
	var w := float(size_arr[0]) * s
	custom_minimum_size = Vector2(w, float(size_arr[1]) * s)
	add_theme_constant_override("separation", roundi(float(cfg["slot_row_separation"]) * s))
	_size_row(key_label, w, float(cfg["key_height"]) * s)
	key_label.add_theme_font_size_override("font_size", roundi(float(cfg["key_font_size"]) * s))
	_size_row(name_label, w, float(cfg["name_height"]) * s)
	name_label.max_lines_visible = int(cfg["name_max_lines"])
	_size_row(cooldown_bar, w, float(cfg["bar_height"]) * s)
	_size_row(preview_label, w, float(cfg["preview_height"]) * s)
	preview_label.max_lines_visible = int(cfg["preview_max_lines"])
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
