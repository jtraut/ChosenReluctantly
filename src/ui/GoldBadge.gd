class_name GoldBadge
extends Control
## The gold readout (MAP1): a coin shape, the total ("144") and, when gold was just earned, a "+16" that rises and fades beside it. The
## coin is a ringed disc (a shape, not only a colour). Used on the run HUD and in the map screen's header. Display only: it never
## touches the run. Text comes from data/run.json `ui.map` (`gold_format`, `gold_earned`).

var _total: int = 0
var _delta_text: String = ""
var _delta_left: float = 0.0
var _font_px: int = 20
var _hold: float = 1.6
var _rise: float = 26.0
var _color: Color = Color("#ffd23f")
var _text_color: Color = Color.WHITE
var _align_right: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Look: `font_px` text size, `hold` seconds the "+N" lives, `rise` pixels it climbs, colours, right-aligned (HUD) or left-aligned (map header).
func configure(font_px: int, hold: float, rise: float, color: Color, text_color: Color, align_right: bool) -> void:
	_font_px = font_px
	_hold = hold
	_rise = rise
	_color = color
	_text_color = text_color
	_align_right = align_right
	queue_redraw()


func set_total(total: int) -> void:
	if total == _total:
		return
	_total = total
	queue_redraw()


func total() -> int:
	return _total


## Gold was earned: shows "+N" for `hold` seconds. A second payout replaces the first (they are seconds apart).
func show_delta(delta: int) -> void:
	if delta <= 0:
		return
	_delta_text = String(RunConfig.ui().get("map", {}).get("gold_earned_short", "+%d")) % delta
	_delta_left = _hold
	set_process(true)
	queue_redraw()


func delta_text() -> String:
	return _delta_text if _delta_left > 0.0 else ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the "+N" keeps floating while a prompt pauses the room
	set_process(false)


func _process(delta: float) -> void:
	if _delta_left <= 0.0:
		set_process(false)
		return
	_delta_left = maxf(_delta_left - delta, 0.0)
	queue_redraw()


## Rise (pixels up) and alpha of the "+N" `left` seconds before it ends: it climbs the whole time and fades over the last 40 percent.
static func float_state(left: float, hold: float, rise: float) -> Dictionary:
	if hold <= 0.0 or left <= 0.0:
		return {"offset": rise, "alpha": 0.0}
	var done: float = clampf(1.0 - left / hold, 0.0, 1.0)
	var alpha: float = clampf(left / (hold * 0.4), 0.0, 1.0)
	return {"offset": rise * done, "alpha": alpha}


func total_text() -> String:
	var texts: Dictionary = RunConfig.ui().get("map", {})
	return String(texts.get("gold_format", "%d")) % _total


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var text: String = total_text()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_px)
	var coin_r: float = minf(size.y * 0.42, float(_font_px) * 0.6)
	var gap: float = coin_r * 0.6
	var content_w: float = coin_r * 2.0 + gap + text_size.x
	var x0: float = size.x - content_w if _align_right else 0.0
	var mid_y: float = size.y * 0.5
	var coin_c := Vector2(x0 + coin_r, mid_y)
	draw_circle(coin_c, coin_r, _color)
	draw_arc(coin_c, coin_r, 0.0, TAU, 20, Color(0.1, 0.06, 0.04, 1.0), maxf(coin_r * 0.18, 1.5), true)
	draw_arc(coin_c, coin_r * 0.55, 0.0, TAU, 16, Color(0.1, 0.06, 0.04, 0.8), maxf(coin_r * 0.14, 1.0), true)
	var base_y: float = mid_y + (font.get_ascent(_font_px) - font.get_descent(_font_px)) * 0.5
	var text_x: float = x0 + coin_r * 2.0 + gap
	draw_string_outline(font, Vector2(text_x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_px, 4, Color(0.05, 0.03, 0.04, 0.95))
	draw_string(font, Vector2(text_x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_px, _text_color)
	if _delta_left > 0.0 and _delta_text != "":
		var state: Dictionary = float_state(_delta_left, _hold, _rise)
		var color := Color(_color.lightened(0.35), float(state["alpha"]))
		var delta_w: float = font.get_string_size(_delta_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_px).x
		# Right-aligned (the HUD): the "+N" goes left of the coin so it never leaves the screen edge; left-aligned (the map): right of the total.
		var pos := Vector2(x0 - gap - delta_w if _align_right else text_x + text_size.x + gap, base_y - float(state["offset"]))
		draw_string_outline(font, pos, _delta_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_px, 4, Color(0.05, 0.03, 0.04, float(state["alpha"])))
		draw_string(font, pos, _delta_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_px, color)
