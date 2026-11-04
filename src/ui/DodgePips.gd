class_name DodgePips
extends Control
## Dodge charge indicator (P-dodge 3), under the RMB meter: a label with the live dodge key ("Space") and one pip per charge. A ready charge is a
## solid pip with a bright frame, an empty one is a hollow frame, and the charge that is coming back fills left to right.
## With nothing left to spend the frame goes red and the word EMPTY sits after the pips (shape and word, not colour alone);
## with no charges at all the word is NO DODGE. Reads Player.get_dodge_state() each frame; display only.

var _cfg: Dictionary = {}
var _scale: float = 1.0
var _player: Player = null
var _state: Dictionary = {"current": 0, "max": 0, "recharging": false, "recharge_progress": 1.0}
var _pulse: float = 0.0
var _last_current: int = -1


## Pure: the fill (0..1) of pip `index` (0-based, left to right): ready pips full, the next one the recharge progress.
static func pip_fill(index: int, current: int, maximum: int, recharging: bool, progress: float) -> float:
	if index < 0 or index >= maximum:
		return 0.0
	if index < current:
		return 1.0
	if index == current and recharging:
		return clampf(progress, 0.0, 1.0)
	return 0.0


## Pure: "" while a dodge is available, else the word to show: the none word with no pips at all, the empty word at 0 charges.
static func status_word(current: int, maximum: int, cfg: Dictionary) -> String:
	if maximum <= 0:
		return String(cfg["dodge_none_word"])
	if current <= 0:
		return String(cfg["dodge_empty_word"])
	return ""


## Pure: total width of `count` pips (pixels, unscaled pip width and gap passed in).
static func pips_width(count: int, pip_w: float, gap: float) -> float:
	return pip_w * count + gap * maxi(count - 1, 0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(cfg: Dictionary, s: float) -> void:
	_cfg = cfg
	_scale = s
	queue_redraw()


func set_player(p: Player) -> void:
	_player = p
	_last_current = -1


func pip_count() -> int:
	return int(_state["max"])


func ready_count() -> int:
	return int(_state["current"])


func word() -> String:
	return status_word(int(_state["current"]), int(_state["max"]), _cfg) if not _cfg.is_empty() else ""


## H2: the whole row (key label and pips) is hidden while the dodge is off, so no "?" key and no empty gap show.
## Hud's dodge row is the last in the top-left stack, so hiding it leaves nothing to re-flow.
func _process(delta: float) -> void:
	var on: bool = PlayerConfig.dodge_enabled()
	if visible != on:
		visible = on
	if _player == null or _player.dodge_charges == null:
		return
	_state = _player.get_dodge_state()
	var current: int = int(_state["current"])
	if _last_current >= 0 and current > _last_current:
		_pulse = 1.0
	_last_current = current
	_pulse = maxf(_pulse - delta / maxf(float(_cfg.get("dodge_pulse_duration", 0.3)), 0.01), 0.0)
	queue_redraw()


func _draw() -> void:
	if _cfg.is_empty():
		return
	var s := _scale
	var font := get_theme_default_font()
	var fsize := roundi(float(_cfg["meter_font_size"]) * s)
	var label := InputLabels.for_action(&"dodge")  # live; Hud rebuilds the layout on bindings_changed
	var label_w := HudLayout.key_label_width(font, label, fsize, float(_cfg["dodge_label_width"]) * s, 4.0 * s)
	var outline := maxi(2, roundi(2.0 * s))
	var outline_col := Color.html(String(_cfg["meter_text_outline_color"]))
	var text_col := Color.html(String(_cfg["meter_text_color"]))
	var ty := (size.y + font.get_ascent(fsize) - font.get_descent(fsize)) * 0.5
	draw_string_outline(font, Vector2(0.0, ty), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, fsize, outline, outline_col)
	draw_string(font, Vector2(0.0, ty), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, fsize, text_col)

	var current: int = int(_state["current"])
	var maximum: int = int(_state["max"])
	var recharging: bool = bool(_state["recharging"])
	var progress: float = float(_state["recharge_progress"])
	var pip_w := float(_cfg["dodge_pip_width"]) * s
	var gap := float(_cfg["dodge_pip_gap"]) * s
	var ready_col := Color.html(String(_cfg["dodge_ready_color"]))
	var recharge_col := Color.html(String(_cfg["dodge_recharge_color"]))
	var back := Color.html(String(_cfg["meter_back_color"]))
	back.a = 0.85
	var frame_col := Color.html(String(_cfg["meter_border_color"]))
	var empty := current <= 0
	if empty:
		frame_col = Color.html(String(_cfg["dodge_empty_color"]))
	var thin := float(maxi(1, roundi(1.0 * s)))
	var thick := float(maxi(2, roundi(2.0 * s)))
	for i in range(maximum):
		var r := Rect2(Vector2(label_w + i * (pip_w + gap), 0.0), Vector2(pip_w, size.y))
		draw_rect(r, back)
		var fill := pip_fill(i, current, maximum, recharging, progress)
		if fill >= 1.0:
			draw_rect(r, ready_col)
			draw_rect(r, frame_col, false, thick)
		else:
			if fill > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), recharge_col)
			var edge := frame_col
			edge.a = 1.0 if empty else 0.6
			draw_rect(r, edge, false, thick if empty else thin)
	if _pulse > 0.0 and current > 0:
		var idx := clampi(current - 1, 0, maxi(maximum - 1, 0))
		var pr := Rect2(Vector2(label_w + idx * (pip_w + gap), 0.0), Vector2(pip_w, size.y))
		# A charge came back: the pip floods white and a thick frame swells out of it, both fading over dodge_pulse_duration.
		var grow: float = float(_cfg.get("dodge_pulse_grow", 6.0)) * s
		draw_rect(pr, Color(1.0, 1.0, 1.0, 0.85 * _pulse))
		draw_rect(pr.grow(grow * (1.0 - _pulse) + 2.0 * s), Color(1.0, 1.0, 1.0, _pulse), false, thick * 1.5)
	var w := status_word(current, maximum, _cfg)
	if w != "":
		var x := label_w + pips_width(maximum, pip_w, gap) + 6.0 * s
		var wc := Color.html(String(_cfg["dodge_empty_color"]))
		draw_string_outline(font, Vector2(x, ty), w, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, outline, outline_col)
		draw_string(font, Vector2(x, ty), w, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, wc)
