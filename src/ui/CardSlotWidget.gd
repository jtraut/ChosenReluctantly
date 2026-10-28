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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## Ready: full brightness, bright border, full green-ish bar. Cooling: dimmed,
## no border, partial grey-blue bar that fills as the cooldown elapses.
func _apply_state(is_ready: bool) -> void:
	_ready_state = is_ready
	var cfg := _cfg if not _cfg.is_empty() else UiConfig.hud()
	var dim := 1.0 if is_ready else float(cfg["slot_cooling_dim"])
	modulate = Color(dim, dim, dim, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(String(cfg["slot_ready_bar_color" if is_ready else "slot_cooling_bar_color"]))
	var back := StyleBoxFlat.new()
	back.bg_color = Color.html(String(cfg["slot_bar_back_color"]))
	cooldown_bar.add_theme_stylebox_override("fill", fill)
	cooldown_bar.add_theme_stylebox_override("background", back)
	queue_redraw()


func _draw() -> void:
	if not _ready_state or _cfg.is_empty():
		return
	var bw := float(maxi(1, roundi(float(_cfg["slot_ready_border_width"]) * _scale)))
	draw_rect(Rect2(Vector2.ZERO, size).grow(-bw * 0.5), Color.html(String(_cfg["slot_ready_border_color"])), false, bw)


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
	queue_redraw()
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
	if slot == null or not slot.has_cards():
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
