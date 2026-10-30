class_name AttackMeter
extends Control
## Small HUD meter for one auto/manual attack (light or heavy). Reads the
## Player each frame; draws a label ("LMB"/"RMB") and a fill bar. Ready = full
## bar, bright border and "READY" text (shape + text, not colour alone); a
## short pulse plays on `attack_ready`. Display only; ignores the mouse.

var attack_id: StringName = &"light"
var label_text: String = ""
var is_prominent: bool = false

var _cfg: Dictionary = {}
var _scale: float = 1.0
var _player: Player = null
var _progress: float = 0.0
var _ready_now: bool = true
var _winding_up: bool = false
var _pulse: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pure: bar fill fraction from the player's progress value.
static func fill_fraction(progress: float) -> float:
	return clampf(progress, 0.0, 1.0)


## Pure: state name used for drawing and tests: &"ready", &"windup" or &"cooling".
static func state_for(ready_now: bool, winding_up: bool) -> StringName:
	if winding_up:
		return &"windup"
	return &"ready" if ready_now else &"cooling"


func configure(id: StringName, text: String, prominent: bool, cfg: Dictionary, s: float) -> void:
	attack_id = id
	label_text = text
	is_prominent = prominent
	_cfg = cfg
	_scale = s
	queue_redraw()


## The word shown while this attack winds up: from data (hud.meter_windup_words) by the shape of the attack the player
## has now, so a swing says SWING and a targeted ground blast says CAST.
func windup_word() -> String:
	var words: Dictionary = _cfg.get("meter_windup_words", {})
	var shape: String = ""
	if _player != null and _player.attacks != null:
		shape = String(_player.attacks.get_def(attack_id).get("shape", ""))
	return String(words.get(shape, words.get("default", "SWING")))


func state() -> StringName:
	return state_for(_ready_now, _winding_up)


func progress_value() -> float:
	return _progress


func pulse_value() -> float:
	return _pulse


func set_player(p: Player) -> void:
	if _player != null and _player.attack_ready.is_connected(_on_attack_ready):
		_player.attack_ready.disconnect(_on_attack_ready)
	_player = p
	if _player != null:
		_player.attack_ready.connect(_on_attack_ready)


func _on_attack_ready(id: StringName) -> void:
	# Only the prominent (heavy) meter pulses; light cycles too fast to pulse.
	if id == attack_id and is_prominent:
		_pulse = 1.0


func _process(delta: float) -> void:
	if _player == null or _player.attacks == null:
		return
	_progress = fill_fraction(_player.get_attack_progress(attack_id))
	_ready_now = _player.is_attack_ready(attack_id)
	_winding_up = _player.attacks.is_winding_up(attack_id)
	var dur := maxf(float(_cfg.get("meter_pulse_duration", 0.4)), 0.01)
	_pulse = maxf(_pulse - delta / dur, 0.0)
	queue_redraw()


func _draw() -> void:
	if _cfg.is_empty():
		return
	var s := _scale
	var base := Color.html(String(_cfg["heavy_meter_color" if is_prominent else "light_meter_color"]))
	var alpha := 1.0 if is_prominent else float(_cfg["meter_light_alpha"])
	var st := state()
	var label_w := float(_cfg["meter_label_width"]) * s
	var bar := Rect2(Vector2(label_w, 0.0), Vector2(maxf(size.x - label_w, 1.0), size.y))
	var font := get_theme_default_font()
	var fsize := roundi(float(_cfg["meter_font_size"]) * s)
	var text_col := Color.html(String(_cfg["meter_text_color"]))
	text_col.a = 1.0 if is_prominent else 0.9
	var outline_col := Color.html(String(_cfg["meter_text_outline_color"]))
	var outline := maxi(2, roundi(2.0 * s))

	# Label, vertically centred on the bar.
	var ty := (size.y + font.get_ascent(fsize) - font.get_descent(fsize)) * 0.5
	draw_string_outline(font, Vector2(0.0, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, label_w, fsize, outline, outline_col)
	draw_string(font, Vector2(0.0, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, label_w, fsize, text_col)

	var back := Color.html(String(_cfg["meter_back_color"]))
	back.a = 0.85 if is_prominent else 0.6
	draw_rect(bar, back)
	var fill_col := base
	fill_col.a = alpha
	if st == &"cooling" or st == &"windup":
		fill_col = fill_col.darkened(0.35)
		fill_col.a = alpha
	var fill := Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y))
	draw_rect(fill, fill_col)

	var border_col := Color.html(String(_cfg["meter_border_color"]))
	var bw := float(maxi(1, roundi(1.0 * s)))
	if st == &"ready":
		# Ready = bright, thicker border. Light stays subtle; heavy gets a full one.
		bw = float(maxi(2, roundi((2.0 if is_prominent else 1.0) * s)))
		border_col.a = 1.0 if is_prominent else 0.7
	else:
		border_col.a = 0.45 if is_prominent else 0.25
	draw_rect(bar, border_col, false, bw)

	if _pulse > 0.0:
		var glow := Color(1.0, 1.0, 1.0, 0.55 * _pulse)
		draw_rect(bar, glow)
		draw_rect(bar.grow(3.0 * s * _pulse), glow, false, maxf(2.0 * s, 1.0))

	if is_prominent:
		var word := ""
		if st == &"ready":
			word = String(_cfg.get("meter_ready_word", "READY"))
		elif st == &"windup":
			word = windup_word()
		if word != "":
			var wsz := font.get_string_size(word, HORIZONTAL_ALIGNMENT_CENTER, -1.0, fsize)
			var pos := Vector2(bar.position.x + (bar.size.x - wsz.x) * 0.5, ty)
			draw_string_outline(font, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, outline, outline_col)
			draw_string(font, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color.WHITE)
